"""Public API for DAKit."""

from .auth import AuthState, Credentials, CredentialStore, JsonCredentialStore, OAuthConfig
from .client import DAKit, DeviantArtClient
from .downloads import DownloadService
from .errors import (
    ApiError,
    AuthenticationError,
    DeviantArtError,
    DownloadError,
    MissingDependencyError,
    ParseError,
    TransportError,
)
from .models import (
    Artwork,
    AssetQuality,
    ClientCapabilities,
    Deviation,
    DeviationKind,
    DownloadedAsset,
    MediaKind,
    MediaVariant,
    Page,
    User,
)
from .store import AssetStore, FileSystemStore
from .transport import AsyncTransport, HttpxTransport, Response

__all__ = [
    "ApiError",
    "Artwork",
    "AssetQuality",
    "AssetStore",
    "AsyncTransport",
    "AuthState",
    "AuthenticationError",
    "ClientCapabilities",
    "CredentialStore",
    "Credentials",
    "DAKit",
    "DeviantArtClient",
    "DeviantArtError",
    "Deviation",
    "DeviationKind",
    "DownloadError",
    "DownloadService",
    "DownloadedAsset",
    "FileSystemStore",
    "HttpxTransport",
    "JsonCredentialStore",
    "MediaKind",
    "MediaVariant",
    "MissingDependencyError",
    "OAuthConfig",
    "Page",
    "ParseError",
    "Response",
    "TransportError",
    "User",
]

__version__ = "0.4.0"
