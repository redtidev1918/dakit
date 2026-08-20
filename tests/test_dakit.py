from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator, Mapping
from pathlib import Path

import pytest

from dakit import (
    AssetQuality,
    Credentials,
    DeviantArtClient,
    DownloadService,
    FileSystemStore,
    JsonCredentialStore,
    OAuthConfig,
    Response,
)
from dakit.parser import parse_deviation


class FakeTransport:
    def __init__(self) -> None:
        self.closed = False

    async def request(
        self,
        method: str,
        url: str,
        *,
        params: Mapping[str, object] | None = None,
        headers: Mapping[str, str] | None = None,
        json: object | None = None,
        data: Mapping[str, object] | None = None,
    ) -> Response:
        import json as jsonlib

        if "_puppy" not in url:
            return Response(200, {}, b"<script>window.__CSRF_TOKEN__ = 'token-1';</script>")
        payload = {
            "results": [
                {
                    "deviationId": "42",
                    "title": "A/B",
                    "url": "https://da/art/42",
                    "author": {"username": "artist"},
                    "type": "image",
                    "media": {
                        "baseUri": "https://cdn/base.jpg",
                        "prettyName": "work",
                        "token": ["media-token"],
                        "types": [
                            {"t": "preview", "c": "/p/<prettyName>.jpg", "w": 400},
                            {"t": "fullview", "c": "/f/<prettyName>.jpg", "w": 1600},
                        ],
                    },
                }
            ],
            "hasMore": False,
        }
        return Response(200, {"content-type": "application/json"}, jsonlib.dumps(payload).encode())

    async def stream(
        self, url: str, *, headers: Mapping[str, str] | None = None
    ) -> AsyncIterator[bytes]:
        yield b"abc"
        yield b"def"

    async def close(self) -> None:
        self.closed = True


class FakeAuthTransport(FakeTransport):
    async def request(
        self,
        method: str,
        url: str,
        *,
        params: Mapping[str, object] | None = None,
        headers: Mapping[str, str] | None = None,
        json: object | None = None,
        data: Mapping[str, object] | None = None,
    ) -> Response:
        return Response(200, {}, b'{"isLoggedIn":true,"username":"alice"}')


@pytest.mark.asyncio
async def test_client_and_download_are_embeddable(tmp_path: Path) -> None:
    transport = FakeTransport()
    client = DeviantArtClient(transport=transport, credentials=Credentials("auth=x"))
    page = await client.gallery("artist")
    assert page.items[0].best_media(AssetQuality.FULL).url.endswith("token=media-token")
    result = await DownloadService(transport, FileSystemStore(tmp_path)).download(page.items[0])
    assert Path(result.location).read_bytes() == b"abcdef"
    assert result.bytes_written == 6
    await client.close()
    assert transport.closed is False
    assert client.artworks is not None
    assert client.browse is not None
    assert client.users is not None
    assert client.capabilities.comments is False
    assert client.capabilities.oauth_login is True


def test_parser_preserves_unknown_fields() -> None:
    item = parse_deviation({"deviationId": 1, "title": "x", "author": {}, "future": True})
    assert item.id == "1"
    assert item.raw["future"] is True


def test_store_contains_traversal(tmp_path: Path) -> None:
    async def chunks() -> AsyncIterator[bytes]:
        yield b"safe"

    location, _ = asyncio.run(FileSystemStore(tmp_path).write("../../outside.txt", chunks()))
    assert Path(location).parent == tmp_path


def test_video_selection_ignores_larger_cover() -> None:
    from dakit import Deviation, DeviationKind, MediaKind, MediaVariant

    item = Deviation(
        "1",
        "film",
        "https://example/art/1",
        "artist",
        DeviationKind.VIDEO,
        media=(
            MediaVariant("https://cdn/cover.jpg", AssetQuality.FULL, width=1000, height=1000),
            MediaVariant(
                "https://cdn/movie.mp4",
                AssetQuality.FULL,
                width=640,
                height=480,
                kind=MediaKind.VIDEO,
            ),
        ),
    )
    assert item.best_media().url.endswith(".mp4")


@pytest.mark.asyncio
async def test_literature_is_saved_as_text(tmp_path: Path) -> None:
    from dakit import Deviation, DeviationKind

    item = Deviation(
        "2",
        "story",
        "https://example/art/2",
        "writer",
        DeviationKind.LITERATURE,
        text_content="hello world",
    )
    result = await DownloadService(FakeTransport(), FileSystemStore(tmp_path)).download(item)
    assert Path(result.location).suffix == ".txt"
    assert Path(result.location).read_text() == "hello world"


@pytest.mark.asyncio
async def test_login_cookies_updates_and_persists_session(tmp_path: Path) -> None:
    from dakit import DAKit

    store = JsonCredentialStore(tmp_path / "session.json")
    client = DAKit(transport=FakeAuthTransport(), credential_store=store)
    state = await client.auth.login_cookies("auth=secret")
    assert state.authenticated is True
    assert state.username is None
    assert store.load() is not None
    assert (store.path.stat().st_mode & 0o777) == 0o600
    await client.auth.logout()
    assert store.load() is None


def test_oauth_authorization_url_contains_state_and_scopes() -> None:
    from dakit import DAKit

    client = DAKit(transport=FakeTransport())
    config = OAuthConfig("client", "secret", "http://127.0.0.1:8765/callback")
    url = client.auth.authorization_url(config, state="csrf-state")
    assert "response_type=code" in url
    assert "client_id=client" in url
    assert "state=csrf-state" in url
    assert "scope=basic+browse" in url
