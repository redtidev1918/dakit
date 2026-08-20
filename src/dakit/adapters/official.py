"""DeviantArt's documented OAuth API adapter."""

from __future__ import annotations

from collections.abc import Callable, Mapping
from typing import Any

from ..core import Artwork, ArtworkKind, Media, MediaKind, Page, SchemaChangedError, User
from ..ports import Transport


class OfficialAPI:
    name = "official-api"
    BASE = "https://www.deviantart.com/api/v1/oauth2"

    def __init__(self, transport: Transport, access_token: Callable[[], str | None]) -> None:
        self._transport = transport
        self._access_token = access_token

    async def artwork(self, artwork_id: str, *, url: str | None = None) -> Artwork:
        payload = await self._get(f"/deviation/{artwork_id}", {})
        return _artwork(payload)

    async def user(self, username: str) -> User:
        payload = await self._get(f"/user/profile/{username}", {})
        if not isinstance(payload, Mapping) or not payload.get("username"):
            raise SchemaChangedError(self.name, "profile lacks username")
        return User(
            str(payload.get("userid", "")),
            str(payload["username"]),
            _optional(payload.get("usericon")),
            f"https://www.deviantart.com/{payload['username']}",
        )

    async def gallery(
        self, username: str, *, cursor: str | None = None, limit: int = 24
    ) -> Page[Artwork]:
        payload = await self._get(
            "/gallery/all",
            {"username": username, "offset": cursor or 0, "limit": limit, "mature_content": "true"},
        )
        return _page(payload, self.name)

    async def search(
        self, query: str, *, cursor: str | None = None, limit: int = 24
    ) -> Page[Artwork]:
        payload = await self._get(
            "/browse/newest",
            {"q": query, "offset": cursor or 0, "limit": limit, "mature_content": "true"},
        )
        return _page(payload, self.name)

    async def _get(self, path: str, params: Mapping[str, object]) -> object:
        token = self._access_token()
        headers = {"Authorization": f"Bearer {token}"} if token else None
        response = await self._transport.request(
            "GET", self.BASE + path, params=params, headers=headers
        )
        try:
            return response.json()
        except (TypeError, ValueError) as exc:
            raise SchemaChangedError(self.name, "response is not JSON") from exc


def _page(value: object, adapter: str) -> Page[Artwork]:
    if not isinstance(value, Mapping) or not isinstance(value.get("results"), list):
        raise SchemaChangedError(adapter, "page lacks results array")
    items = tuple(_artwork(item) for item in value["results"])
    offset = value.get("next_offset") if value.get("has_more") else None
    return Page(items, str(offset) if offset is not None else None)


def _artwork(value: object) -> Artwork:
    if not isinstance(value, Mapping) or not value.get("deviationid"):
        raise SchemaChangedError(OfficialAPI.name, "deviation lacks deviationid")
    author = value.get("author", {})
    username = str(author.get("username", "")) if isinstance(author, Mapping) else ""
    media = _media(value)
    kind = (
        ArtworkKind.VIDEO
        if any(item.kind is MediaKind.VIDEO for item in media)
        else ArtworkKind.IMAGE
    )
    return Artwork(
        str(value["deviationid"]),
        str(value.get("title", "Untitled")),
        str(value.get("url", "")),
        username,
        kind,
        media,
        mature=bool(value.get("is_mature", False)),
    )


def _media(value: Mapping[str, Any]) -> tuple[Media, ...]:
    result: list[Media] = []
    content = value.get("content")
    if isinstance(content, Mapping) and content.get("src"):
        result.append(
            Media(
                str(content["src"]),
                _kind(content),
                _optional(content.get("type")),
                _integer(content.get("width")),
                _integer(content.get("height")),
            )
        )
    videos = value.get("videos", [])
    for video in videos if isinstance(videos, list) else []:
        if isinstance(video, Mapping) and video.get("src"):
            result.append(
                Media(
                    str(video["src"]),
                    MediaKind.VIDEO,
                    "video/mp4",
                    _integer(video.get("width")),
                    _integer(video.get("height")),
                )
            )
    download = value.get("download")
    if isinstance(download, Mapping) and download.get("src"):
        result.append(
            Media(
                str(download["src"]),
                _kind(download),
                _optional(download.get("type")),
                _integer(download.get("width")),
                _integer(download.get("height")),
                True,
            )
        )
    return tuple(result)


def _kind(value: Mapping[str, Any]) -> MediaKind:
    return MediaKind.VIDEO if "video" in str(value.get("type", "")) else MediaKind.IMAGE


def _optional(value: object) -> str | None:
    return str(value) if value else None


def _integer(value: object) -> int | None:
    try:
        return int(str(value)) if value is not None else None
    except (TypeError, ValueError):
        return None
