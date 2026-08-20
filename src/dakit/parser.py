"""Translate unstable website payloads into stable domain objects."""

from __future__ import annotations

import json
import re
from collections.abc import Mapping
from typing import Any

from .errors import ParseError
from .models import AssetQuality, Deviation, DeviationKind, MediaKind, MediaVariant, Page


def parse_initial_state(html: str) -> Mapping[str, Any]:
    match = re.search(r'window\.__INITIAL_STATE__\s*=\s*JSON\.parse\(("(?:\\.|[^"\\])*")\)', html)
    if not match:
        raise ParseError("initial state was not present in the page")
    try:
        value = json.loads(json.loads(match.group(1).replace("\\'", "'")))
    except (TypeError, ValueError) as exc:
        raise ParseError("initial state could not be decoded") from exc
    if not isinstance(value, Mapping):
        raise ParseError("initial state must be an object")
    return value


def parse_state_deviations(state: Mapping[str, Any]) -> tuple[Deviation, ...]:
    entities = state.get("@@entities", {})
    if not isinstance(entities, Mapping):
        return ()
    deviations = entities.get("deviation", {})
    if not isinstance(deviations, Mapping):
        return ()
    return tuple(_parse_state_item(item, entities) for item in deviations.values())


def parse_page(payload: object) -> Page[Deviation]:
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
    return _build(data)


def _parse_state_item(value: object, entities: Mapping[str, Any]) -> Deviation:
    if not isinstance(value, Mapping):
        raise ParseError("state deviation must be an object")
    data = dict(value)
    users = entities.get("user", {})
    author = data.get("author")
    if not isinstance(author, Mapping) and isinstance(users, Mapping):
        data["author"] = users.get(str(author), users.get(author, {}))
    extended_map = entities.get("deviationExtended", {})
    extended_id = data.get("extended")
    if isinstance(extended_map, Mapping):
        extended = extended_map.get(str(extended_id), extended_map.get(extended_id, {}))
        if isinstance(extended, Mapping):
            data["_extended"] = extended
    return _build(data)


def _build(data: Mapping[str, Any]) -> Deviation:
    author_value = data.get("author", {})
    author = (
        author_value.get("username", "unknown") if isinstance(author_value, Mapping) else "unknown"
    )
    kind_value = str(data.get("type", "unknown")).lower()
    kind = {
        "image": DeviationKind.IMAGE,
        "deviation": DeviationKind.IMAGE,
        "video": DeviationKind.VIDEO,
        "film": DeviationKind.VIDEO,
        "literature": DeviationKind.LITERATURE,
        "journal": DeviationKind.LITERATURE,
    }.get(kind_value, DeviationKind.UNKNOWN)
    media_value = data.get("media", {})
    media = list(_parse_media(media_value)) if isinstance(media_value, Mapping) else []
    extended = data.get("_extended", {})
    download = extended.get("download", {}) if isinstance(extended, Mapping) else {}
    if isinstance(download, Mapping) and download.get("url"):
        media.append(
            MediaVariant(
                str(download["url"]),
                AssetQuality.ORIGINAL,
                _mime(download.get("type")),
                _int(download.get("width")),
                _int(download.get("height")),
                _int(download.get("filesize")),
            )
        )
    return Deviation(
        id=str(data.get("deviationId", data.get("deviationid", ""))),
        title=str(data.get("title", "Untitled")),
        url=str(data.get("url", "")),
        author=str(author),
        kind=kind,
        mature=bool(data.get("isMature", False)),
        downloadable=bool(data.get("isDownloadable", False)),
        media=tuple(media),
        text_content=_text(data.get("textContent")),
        raw=dict(data),
    )


def _parse_media(media: Mapping[str, Any]) -> tuple[MediaVariant, ...]:
    base, pretty = str(media.get("baseUri", "")), str(media.get("prettyName", "download"))
    tokens = media.get("token", [])
    token = str(tokens[0]) if isinstance(tokens, list) and tokens else ""
    result: list[MediaVariant] = []
    types = media.get("types", [])
    for item in types if isinstance(types, list) else []:
        if not isinstance(item, Mapping):
            continue
        media_type = str(item.get("t"))
        quality = {
            "preview": AssetQuality.PREVIEW,
            "fullview": AssetQuality.FULL,
            "video": AssetQuality.FULL,
        }.get(media_type)
        if quality is None:
            continue
        path = str(item.get("b") or item.get("c") or "").replace("<prettyName>", pretty)
        if not path and media_type == "fullview":
            path = base
        url = path if path.startswith("http") else base + path
        if token and url and "token=" not in url:
            url += ("&" if "?" in url else "?") + f"token={token}"
        if url:
            kind = MediaKind.VIDEO if media_type == "video" else MediaKind.IMAGE
            result.append(
                MediaVariant(
                    url,
                    quality,
                    _mime("mp4" if kind is MediaKind.VIDEO else url),
                    _int(item.get("w")),
                    _int(item.get("h")),
                    _int(item.get("f")),
                    kind,
                    "blur_" in url,
                )
            )
    return tuple(result)


def _text(value: object) -> str | None:
    if not isinstance(value, Mapping):
        return None
    html = value.get("html", {})
    if isinstance(html, Mapping) and html.get("markup"):
        try:
            document = json.loads(str(html["markup"])).get("document", {})
            parts: list[str] = []

            def walk(node: object) -> None:
                if not isinstance(node, Mapping):
                    return
                if node.get("type") == "text":
                    parts.append(str(node.get("text", "")))
                children = node.get("content", [])
                for child in children if isinstance(children, list) else []:
                    walk(child)
                if node.get("type") in {"paragraph", "heading"}:
                    parts.append("\n")

            walk(document)
            return "".join(parts).strip()
        except (TypeError, ValueError):
            pass
    excerpt = value.get("excerpt")
    return str(excerpt) if excerpt else None


def _mime(value: object) -> str | None:
    text = str(value).lower().split("?")[0]
    for ext, mime in (
        ("mp4", "video/mp4"),
        ("gif", "image/gif"),
        ("png", "image/png"),
        ("jpeg", "image/jpeg"),
        ("jpg", "image/jpeg"),
        ("webp", "image/webp"),
    ):
        if ext in text:
            return mime
    return None


def _int(value: object) -> int | None:
    try:
        return int(str(value)) if value is not None else None
    except (TypeError, ValueError):
        return None
