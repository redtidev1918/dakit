"""Storage-agnostic asset download service."""

from __future__ import annotations

from pathlib import PurePath
from urllib.parse import urlparse

from .errors import DownloadError
from .models import AssetQuality, Deviation, DownloadedAsset
from .store import AssetStore
from .transport import AsyncTransport


class DownloadService:
    def __init__(self, transport: AsyncTransport, store: AssetStore) -> None:
        self.transport = transport
        self.store = store

    async def download(
        self,
        deviation: Deviation,
        *,
        quality: AssetQuality = AssetQuality.FULL,
        key: str | None = None,
    ) -> DownloadedAsset:
        media = deviation.best_media(quality)
        if media is None:
            raise DownloadError(f"no {quality.value} asset available for {deviation.id}")
        filename = key or f"{deviation.author}/{_filename(deviation, media.url)}"
        try:
            location, written = await self.store.write(filename, self.transport.stream(media.url))
        except DownloadError:
            raise
        except Exception as exc:
            raise DownloadError(f"failed to store {deviation.id}: {exc}") from exc
        return DownloadedAsset(deviation, media, location, written)


def _filename(deviation: Deviation, url: str) -> str:
    suffix = PurePath(urlparse(url).path).suffix or ".bin"
    return f"{deviation.title}-{deviation.id}{suffix}"
