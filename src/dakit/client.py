"""Composition root and adaptive content gateway."""

from __future__ import annotations

import re
from collections.abc import Awaitable, Callable
from typing import TypeVar, cast

from .adapters import HttpxTransport, OfficialAPI, WebsiteFallback
from .auth import PublicOAuth, PublicOAuthConfig
from .core import Artwork, Page, RemoteError, User
from .ports import ContentSource, TokenStore, Transport

T = TypeVar("T")


class AdaptiveContent:
    """Official-first gateway with explicit, observable fallback."""

    def __init__(self, primary: ContentSource, fallbacks: tuple[ContentSource, ...] = ()) -> None:
        self.primary, self.fallbacks = primary, fallbacks
        self.last_adapter: str | None = None
        self.last_failures: tuple[str, ...] = ()

    async def artwork(self, artwork_id: str, *, url: str | None = None) -> Artwork:
        return await self._run(lambda source: source.artwork(artwork_id, url=url))

    async def artwork_url(self, url: str) -> Artwork:
        match = re.search(r"-(\d+)(?:[/?#]|$)", url)
        if not match:
            raise ValueError("artwork URL has no numeric identifier")
        return await self.artwork(match.group(1), url=url)

    async def user(self, username: str) -> User:
        return await self._run(lambda source: source.user(username))

    async def gallery(
        self, username: str, *, cursor: str | None = None, limit: int = 24
    ) -> Page[Artwork]:
        return await self._run(lambda source: source.gallery(username, cursor=cursor, limit=limit))

    async def search(
        self, query: str, *, cursor: str | None = None, limit: int = 24
    ) -> Page[Artwork]:
        return await self._run(lambda source: source.search(query, cursor=cursor, limit=limit))

    async def _run(self, operation: Callable[[ContentSource], Awaitable[T]]) -> T:
        failures: list[str] = []
        for source in (self.primary, *self.fallbacks):
            try:
                result = await operation(source)
                self.last_adapter, self.last_failures = source.name, tuple(failures)
                return result
            except RemoteError as exc:
                failures.append(f"{source.name}: {exc}")
        self.last_failures = tuple(failures)
        raise RemoteError("all content adapters failed: " + "; ".join(failures))


class DAKit:
    def __init__(
        self,
        oauth: PublicOAuthConfig,
        *,
        transport: Transport | None = None,
        token_store: TokenStore | None = None,
        sources: tuple[ContentSource, ...] | None = None,
    ) -> None:
        self._transport = transport or cast(Transport, HttpxTransport())
        self._owns_transport = transport is None
        self.auth = PublicOAuth(self._transport, oauth, token_store)
        if sources is None:
            sources = (
                OfficialAPI(self._transport, self.auth.access_token),
                WebsiteFallback(self._transport),
            )
        if not sources:
            raise ValueError("at least one content source is required")
        self.content = AdaptiveContent(sources[0], sources[1:])

    @property
    def transport(self) -> Transport:
        return self._transport

    async def close(self) -> None:
        if self._owns_transport:
            await self._transport.close()

    async def __aenter__(self) -> DAKit:
        return self

    async def __aexit__(self, *_: object) -> None:
        await self.close()
