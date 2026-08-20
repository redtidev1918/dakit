"""Narrow read-only fallback for public artwork pages.

This adapter deliberately exposes only operations with a defensible public-page
fallback. Unsupported calls fail explicitly so callers never receive fabricated data.
"""

from __future__ import annotations

import json
import re
from collections.abc import Mapping
from typing import Any

from ..core import (
    Artwork,
    ArtworkKind,
    Media,
    MediaKind,
    Page,
    RemoteError,
    SchemaChangedError,
    User,
)
from ..ports import Transport


class WebsiteFallback:
    name = "website-fallback"

    def __init__(self, transport: Transport) -> None:
        self._transport = transport

    async def artwork(self, artwork_id: str, *, url: str | None = None) -> Artwork:
        if not url:
            raise RemoteError("website fallback requires the canonical artwork URL")
        response = await self._transport.request("GET", url)
        state = _state(response.content.decode("utf-8", errors="replace"))
        entities = state.get("@@entities", {})
        deviations = entities.get("deviation", {}) if isinstance(entities, Mapping) else {}
        if not isinstance(deviations, Mapping):
            raise SchemaChangedError(self.name, "deviation entity map is missing")
        for value in deviations.values():
            if isinstance(value, Mapping) and str(value.get("deviationId", "")) == artwork_id:
                data = dict(value)
                users = entities.get("user", {})
                author = data.get("author")
                if not isinstance(author, Mapping) and isinstance(users, Mapping):
                    data["author"] = users.get(str(author), users.get(author, {}))
                return _artwork(data)
        raise SchemaChangedError(self.name, f"artwork {artwork_id} is absent")

    async def user(self, username: str) -> User:
        raise RemoteError("user profiles require the official API")

    async def gallery(
        self, username: str, *, cursor: str | None = None, limit: int = 24
    ) -> Page[Artwork]:
        raise RemoteError("galleries require the official API")

    async def search(
        self, query: str, *, cursor: str | None = None, limit: int = 24
    ) -> Page[Artwork]:
        raise RemoteError("search requires the official API")


def _state(html: str) -> Mapping[str, Any]:
    start = html.find("window.__INITIAL_STATE__")
    parse_start = html.find("JSON.parse(", start) if start >= 0 else -1
    if parse_start >= 0:
        # JavaScript accepts escaped apostrophes inside double-quoted strings;
        # JSON does not, so normalize that one JS-only escape before decoding.
        encoded = html[parse_start + len("JSON.parse(") :].lstrip().replace("\\'", "'")
        try:
            serialized, _ = json.JSONDecoder().raw_decode(encoded)
            value = json.loads(serialized)
            if isinstance(value, Mapping):
                return value
        except (TypeError, ValueError):
            pass
    match = re.search(r'<script[^>]+id="__NEXT_DATA__"[^>]*>(.*?)</script>', html, re.DOTALL)
    if match:
        try:
            value = json.loads(match.group(1))
            if isinstance(value, Mapping):
                return value
        except (TypeError, ValueError):
            pass
    raise SchemaChangedError(WebsiteFallback.name, "no supported state envelope found")


def _artwork(value: Mapping[str, Any]) -> Artwork:
    author = value.get("author", {})
    username = str(author.get("username", "")) if isinstance(author, Mapping) else ""
    media_value = value.get("media", {})
    media: list[Media] = []
    if isinstance(media_value, Mapping):
        base = str(media_value.get("baseUri", ""))
        pretty = str(media_value.get("prettyName", "download"))
        tokens = media_value.get("token", [])
        token = str(tokens[0]) if isinstance(tokens, list) and tokens else ""
        for item in media_value.get("types", []):
            if not isinstance(item, Mapping) or item.get("t") not in {
                "preview",
                "fullview",
                "video",
            }:
                continue
            path = str(item.get("b") or item.get("c") or "").replace("<prettyName>", pretty)
            asset = path if path.startswith("http") else base + path
            if token and asset:
                asset += ("&" if "?" in asset else "?") + f"token={token}"
            if asset:
                media_kind = MediaKind.VIDEO if item.get("t") == "video" else MediaKind.IMAGE
                media.append(
                    Media(
                        asset,
                        media_kind,
                        width=_integer(item.get("w")),
                        height=_integer(item.get("h")),
                        restricted="blur_" in asset,
                    )
                )
    artwork_kind = (
        ArtworkKind.VIDEO
        if any(item.kind is MediaKind.VIDEO for item in media)
        else ArtworkKind.IMAGE
    )
    unique = tuple({item.url: item for item in media}.values())
    return Artwork(
        str(value.get("deviationId", "")),
        str(value.get("title", "Untitled")),
        str(value.get("url", "")),
        username,
        artwork_kind,
        unique,
        mature=bool(value.get("isMature", False)),
    )


def _integer(value: object) -> int | None:
    try:
        return int(str(value)) if value is not None else None
    except (TypeError, ValueError):
        return None
