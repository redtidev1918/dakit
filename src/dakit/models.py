"""Stable domain models independent from remote payloads."""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Generic, TypeVar

T = TypeVar("T")


class DeviationKind(str, Enum):
    IMAGE = "image"
    VIDEO = "video"
    LITERATURE = "literature"
    UNKNOWN = "unknown"


class AssetQuality(str, Enum):
    ORIGINAL = "original"
    FULL = "full"
    PREVIEW = "preview"


class MediaKind(str, Enum):
    IMAGE = "image"
    VIDEO = "video"
    DOCUMENT = "document"


@dataclass(frozen=True, slots=True)
class MediaVariant:
    url: str
    quality: AssetQuality
    mime_type: str | None = None
    width: int | None = None
    height: int | None = None
    file_size: int | None = None
    kind: MediaKind = MediaKind.IMAGE
    restricted: bool = False


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
    text_content: str | None = None
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
            expected = MediaKind.VIDEO if self.kind is DeviationKind.VIDEO else MediaKind.IMAGE
            typed = [item for item in matches if item.kind is expected]
            if typed:
                matches = typed
            if matches:
                return max(matches, key=lambda item: (item.height or 0, item.width or 0))
        return None


@dataclass(frozen=True, slots=True)
class Page(Generic[T]):
    items: tuple[T, ...]
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


@dataclass(frozen=True, slots=True)
class User:
    id: str
    username: str
    url: str
    avatar_url: str | None = None
    display_name: str | None = None
    bio: str | None = None
    is_group: bool = False
    is_watching: bool = False
    watchers: int | None = None
    deviations: int | None = None
    raw: Mapping[str, Any] = field(default_factory=dict, repr=False, compare=False)


@dataclass(frozen=True, slots=True)
class ClientCapabilities:
    artwork_details: bool = True
    gallery: bool = True
    favorites: bool = True
    global_search: bool = True
    user_profiles: bool = True
    media_downloads: bool = True
    comments: bool = False
    social_writes: bool = False


Artwork = Deviation
