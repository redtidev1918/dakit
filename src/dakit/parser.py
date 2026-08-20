"""Translate unstable API payloads into stable domain objects."""

from __future__ import annotations

from collections.abc import Mapping
from typing import Any

from .errors import ParseError
from .models import AssetQuality, Deviation, DeviationKind, MediaVariant, Page


def parse_page(payload: object) -> Page:
    if not isinstance(payload, Mapping):
        raise ParseError("page response must be an object")
    raw_items = payload.get("results", payload.get("deviations", []))
    if not isinstance(raw_items, list):
        raise ParseError("page items must be a list")
    items = tuple(parse_deviation(item) for item in raw_items)
    cursor = payload.get("nextCursor")
    if cursor is None and payload.get("hasMore"):
        cursor = str(payload.get("nextOffset", len(items)))
    return Page(items, str(cursor) if cursor not in (None, "") else None)


def parse_deviation(value: object) -> Deviation:
    if not isinstance(value, Mapping):
        raise ParseError("deviation must be an object")
    data: Mapping[str, Any] = value.get("deviation", value)
    author_value = data.get("author", {})
    author = (
        author_value.get("username", "unknown") if isinstance(author_value, Mapping) else "unknown"
    )
    media_value = data.get("media", {})
    media = _parse_media(media_value) if isinstance(media_value, Mapping) else ()
    kind_value = str(data.get("type", "unknown")).lower()
    kind = {
        "image": DeviationKind.IMAGE,
        "deviation": DeviationKind.IMAGE,
        "video": DeviationKind.VIDEO,
        "film": DeviationKind.VIDEO,
        "literature": DeviationKind.LITERATURE,
    }.get(kind_value, DeviationKind.UNKNOWN)
    return Deviation(
        id=str(data.get("deviationId", data.get("deviationid", ""))),
        title=str(data.get("title", "Untitled")),
        url=str(data.get("url", "")),
        author=str(author),
        kind=kind,
        mature=bool(data.get("isMature", False)),
        downloadable=bool(data.get("isDownloadable", False)),
        media=media,
        raw=dict(data),
    )


def _parse_media(media: Mapping[str, Any]) -> tuple[MediaVariant, ...]:
    base = str(media.get("baseUri", ""))
    pretty = str(media.get("prettyName", "download"))
    tokens = media.get("token", [])
    token = str(tokens[0]) if isinstance(tokens, list) and tokens else ""
    result: list[MediaVariant] = []
    types = media.get("types", [])
    for item in types if isinstance(types, list) else []:
        if not isinstance(item, Mapping):
            continue
        quality = {
            "preview": AssetQuality.PREVIEW,
            "fullview": AssetQuality.FULL,
        }.get(str(item.get("t")))
        if item.get("t") == "video":
            quality = AssetQuality.FULL
        if quality is None:
            continue
        path = str(item.get("b") or item.get("c") or "").replace("<prettyName>", pretty)
        url = path if path.startswith("http") else base + path
        if token and url:
            url += ("&" if "?" in url else "?") + f"token={token}"
        if url:
            result.append(
                MediaVariant(
                    url,
                    quality,
                    width=_int(item.get("w")),
                    height=_int(item.get("h")),
                )
            )
    if not result and base:
        result.append(MediaVariant(base, AssetQuality.FULL))
    return tuple(result)


def _int(value: object) -> int | None:
    try:
        return int(str(value)) if value is not None else None
    except (TypeError, ValueError):
        return None
