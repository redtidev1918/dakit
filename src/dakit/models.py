"""Stable domain models independent from remote payloads."""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass, field
from enum import Enum
from typing import Any


class DeviationKind(str, Enum):
    IMAGE = "image"
    VIDEO = "video"
    LITERATURE = "literature"
    UNKNOWN = "unknown"


class AssetQuality(str, Enum):
    ORIGINAL = "original"
    FULL = "full"
    PREVIEW = "preview"


@dataclass(frozen=True, slots=True)
class MediaVariant:
    url: str
    quality: AssetQuality
    mime_type: str | None = None
    width: int | None = None
    height: int | None = None
    file_size: int | None = None


@dataclass(frozen=True, slots=True)
class Deviation:
    id: str
    title: str
    url: str
    author: str
    kind: DeviationKind = DeviationKind.UNKNOWN
    mature: bool = False
    downloadable: bool = False
    media: tuple[MediaVariant, ...] = ()
    raw: Mapping[str, Any] = field(default_factory=dict, repr=False, compare=False)

    def best_media(self, quality: AssetQuality = AssetQuality.FULL) -> MediaVariant | None:
        order = {
            AssetQuality.PREVIEW: (AssetQuality.PREVIEW,),
            AssetQuality.FULL: (AssetQuality.FULL, AssetQuality.PREVIEW),
            AssetQuality.ORIGINAL: (
                AssetQuality.ORIGINAL,
                AssetQuality.FULL,
                AssetQuality.PREVIEW,
            ),
        }[quality]
        for candidate in order:
            matches = [item for item in self.media if item.quality is candidate]
            if matches:
                return max(matches, key=lambda item: (item.height or 0, item.width or 0))
        return None


@dataclass(frozen=True, slots=True)
class Page:
    items: tuple[Deviation, ...]
    next_cursor: str | None = None

    @property
    def has_more(self) -> bool:
        return self.next_cursor is not None


@dataclass(frozen=True, slots=True)
class DownloadedAsset:
    deviation: Deviation
    media: MediaVariant
    location: str
    bytes_written: int
