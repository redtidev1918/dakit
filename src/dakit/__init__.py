"""Stable public surface for DAKit 1.x."""

from .auth import AuthorizationRequest, PublicOAuth, PublicOAuthConfig
from .client import AdaptiveContent, DAKit
from .core import (
    Artwork,
    ArtworkKind,
    AuthenticationError,
    AuthState,
    DAKitError,
    Media,
    MediaKind,
    Page,
    RemoteError,
    SchemaChangedError,
    TokenSet,
    TransportError,
    User,
)
from .ports import ContentSource, TokenStore, Transport

__all__ = [
    "AdaptiveContent",
    "Artwork",
    "ArtworkKind",
    "AuthState",
    "AuthenticationError",
    "AuthorizationRequest",
    "ContentSource",
    "DAKit",
    "DAKitError",
    "Media",
    "MediaKind",
    "Page",
    "PublicOAuth",
    "PublicOAuthConfig",
    "RemoteError",
    "SchemaChangedError",
    "TokenSet",
    "TokenStore",
    "Transport",
    "TransportError",
    "User",
]

__version__ = "1.0.0a1"
