"""Public API for DAKit."""

from .auth import Credentials
from .client import DAKit, DeviantArtClient
from .downloads import DownloadService
from .errors import (
    ApiError,
    AuthenticationError,
    DeviantArtError,
    DownloadError,
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
    "AuthenticationError",
    "ClientCapabilities",
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
    "MediaKind",
    "MediaVariant",
    "Page",
    "ParseError",
    "Response",
    "TransportError",
    "User",
]

__version__ = "0.3.0"
