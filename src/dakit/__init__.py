"""Public API for DAKit."""

from .auth import Credentials
from .client import DeviantArtClient
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
    AssetQuality,
    Deviation,
    DeviationKind,
    DownloadedAsset,
    MediaVariant,
    Page,
)
from .store import AssetStore, FileSystemStore
from .transport import AsyncTransport, HttpxTransport, Response

__all__ = [
    "ApiError",
    "AssetQuality",
    "AssetStore",
    "AsyncTransport",
    "AuthenticationError",
    "Credentials",
    "DeviantArtClient",
    "DeviantArtError",
    "Deviation",
    "DeviationKind",
    "DownloadError",
    "DownloadService",
    "DownloadedAsset",
    "FileSystemStore",
    "HttpxTransport",
    "MediaVariant",
    "Page",
    "ParseError",
    "Response",
    "TransportError",
]

__version__ = "0.1.0"
