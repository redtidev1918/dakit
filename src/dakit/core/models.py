"""Immutable domain values independent from remote payloads."""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Generic, TypeVar

T = TypeVar("T")


class ArtworkKind(str, Enum):
    IMAGE = "image"
    VIDEO = "video"
    LITERATURE = "literature"
    UNKNOWN = "unknown"


class MediaKind(str, Enum):
    IMAGE = "image"
    VIDEO = "video"
    TEXT = "text"


@dataclass(frozen=True, slots=True)
class Media:
    url: str
    kind: MediaKind
    mime_type: str | None = None
    width: int | None = None
    height: int | None = None
    original: bool = False


@dataclass(frozen=True, slots=True)
class Artwork:
    id: str
    title: str
    url: str
    author: str
    kind: ArtworkKind
    media: tuple[Media, ...] = ()
    text: str | None = None
    mature: bool = False


@dataclass(frozen=True, slots=True)
class User:
    id: str
    username: str
    avatar_url: str | None = None
    profile_url: str | None = None


@dataclass(frozen=True, slots=True)
class Page(Generic[T]):
    items: tuple[T, ...]
    cursor: str | None = None

    @property
    def has_more(self) -> bool:
        return self.cursor is not None


@dataclass(frozen=True, slots=True)
class TokenSet:
    access_token: str
    refresh_token: str = ""
    expires_at: float | None = None


@dataclass(frozen=True, slots=True)
class AuthState:
    authenticated: bool
    username: str | None = None
