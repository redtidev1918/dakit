from __future__ import annotations

import json
from collections.abc import AsyncIterator, Mapping
from dataclasses import dataclass

import pytest

from dakit import (
    Artwork,
    ArtworkKind,
    AuthState,
    DAKit,
    Page,
    PublicOAuthConfig,
    RemoteError,
    TokenSet,
    User,
)


@dataclass
class FakeResponse:
    status: int
    payload: object
    headers: Mapping[str, str] = None  # type: ignore[assignment]

    @property
    def content(self) -> bytes:
        return json.dumps(self.payload).encode()

    def json(self) -> object:
        return self.payload


class FakeTransport:
    def __init__(self) -> None:
        self.requests: list[tuple[str, str, Mapping[str, object] | None]] = []

    async def request(
        self,
        method: str,
        url: str,
        *,
        params: Mapping[str, object] | None = None,
        headers: Mapping[str, str] | None = None,
        data: Mapping[str, object] | None = None,
    ) -> FakeResponse:
        self.requests.append((method, url, data))
        if url.endswith("/oauth2/token"):
            return FakeResponse(
                200, {"access_token": "token", "refresh_token": "refresh", "expires_in": 3600}
            )
        if url.endswith("/user/whoami"):
            return FakeResponse(200, {"username": "alice"})
        return FakeResponse(200, {})

    async def stream(
        self, url: str, *, headers: Mapping[str, str] | None = None
    ) -> AsyncIterator[bytes]:
        yield b"data"

    async def close(self) -> None:
        return None


@pytest.mark.asyncio
async def test_public_oauth_is_pkce_only() -> None:
    transport = FakeTransport()
    kit = DAKit(PublicOAuthConfig("public", "dakit://oauth/callback"), transport=transport)
    request = kit.auth.begin()
    assert "code_challenge_method=S256" in request.url
    state = await kit.auth.complete(
        request, f"dakit://oauth/callback?code=abc&state={request.state}"
    )
    assert state == AuthState(True, "alice")
    token_data = transport.requests[0][2]
    assert token_data is not None and token_data["code_verifier"] == request.verifier
    assert "client_secret" not in token_data


class Source:
    def __init__(self, name: str, *, fails: bool = False) -> None:
        self.name, self.fails = name, fails

    async def artwork(self, artwork_id: str, *, url: str | None = None) -> Artwork:
        if self.fails:
            raise RemoteError("changed")
        return Artwork(artwork_id, "title", url or "", "artist", ArtworkKind.IMAGE)

    async def user(self, username: str) -> User:
        if self.fails:
            raise RemoteError("changed")
        return User("1", username)

    async def gallery(
        self, username: str, *, cursor: str | None = None, limit: int = 24
    ) -> Page[Artwork]:
        if self.fails:
            raise RemoteError("changed")
        return Page(())

    async def search(
        self, query: str, *, cursor: str | None = None, limit: int = 24
    ) -> Page[Artwork]:
        if self.fails:
            raise RemoteError("changed")
        return Page(())


@pytest.mark.asyncio
async def test_adaptive_gateway_reports_fallback() -> None:
    kit = DAKit(
        PublicOAuthConfig("public", "dakit://oauth/callback"),
        transport=FakeTransport(),
        sources=(Source("official", fails=True), Source("fallback")),
    )
    item = await kit.content.artwork("42")
    assert item.id == "42"
    assert kit.content.last_adapter == "fallback"
    assert kit.content.last_failures and "official" in kit.content.last_failures[0]


def test_url_identifier_is_required() -> None:
    kit = DAKit(
        PublicOAuthConfig("public", "dakit://oauth/callback"),
        transport=FakeTransport(),
        sources=(Source("source"),),
    )
    with pytest.raises(ValueError):
        __import__("asyncio").run(kit.content.artwork_url("https://example.invalid/no-id"))


class Store:
    def __init__(self) -> None:
        self.value: TokenSet | None = None

    def load(self) -> TokenSet | None:
        return self.value

    def save(self, tokens: TokenSet) -> None:
        self.value = tokens

    def clear(self) -> None:
        self.value = None


def test_logout_clears_host_store() -> None:
    store = Store()
    store.save(TokenSet("x"))
    kit = DAKit(
        PublicOAuthConfig("public", "dakit://oauth/callback"),
        transport=FakeTransport(),
        token_store=store,
        sources=(Source("source"),),
    )
    kit.auth.logout()
    assert store.value is None


def test_restricted_media_is_explicit() -> None:
    from dakit import Media, MediaKind

    media = Media("https://example/blur_30/image.jpg", MediaKind.IMAGE, restricted=True)
    assert media.restricted is True
