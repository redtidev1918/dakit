"""Replaceable boundaries implemented by hosts and infrastructure adapters."""

from __future__ import annotations

from collections.abc import AsyncIterator, Mapping
from typing import Protocol

from .core import Artwork, Page, TokenSet, User


class Response(Protocol):
    status: int
    headers: Mapping[str, str]
    content: bytes

    def json(self) -> object: ...


class Transport(Protocol):
    async def request(
        self,
        method: str,
        url: str,
        *,
        params: Mapping[str, object] | None = None,
        headers: Mapping[str, str] | None = None,
        data: Mapping[str, object] | None = None,
    ) -> Response: ...

    def stream(
        self, url: str, *, headers: Mapping[str, str] | None = None
    ) -> AsyncIterator[bytes]: ...

    async def close(self) -> None: ...


class TokenStore(Protocol):
    def load(self) -> TokenSet | None: ...
    def save(self, tokens: TokenSet) -> None: ...
    def clear(self) -> None: ...


class ContentSource(Protocol):
    name: str

    async def artwork(self, artwork_id: str, *, url: str | None = None) -> Artwork: ...
    async def user(self, username: str) -> User: ...
    async def gallery(
        self, username: str, *, cursor: str | None = None, limit: int = 24
    ) -> Page[Artwork]: ...
    async def search(
        self, query: str, *, cursor: str | None = None, limit: int = 24
    ) -> Page[Artwork]: ...
