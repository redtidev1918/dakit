"""Storage-agnostic asset download service."""

from __future__ import annotations

from collections.abc import AsyncIterator
from pathlib import PurePath
from urllib.parse import urlparse

from .errors import ApiError, AuthenticationError, DownloadError
from .models import AssetQuality, Deviation, DeviationKind, DownloadedAsset, MediaKind, MediaVariant
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
        if deviation.kind is DeviationKind.LITERATURE:
            if not deviation.text_content:
                raise DownloadError(
                    f"literature text unavailable for {deviation.id}; load its page first"
                )
            content = deviation.text_content
            media = MediaVariant("text://content", quality, "text/plain", kind=MediaKind.DOCUMENT)
            filename = key or f"{deviation.author}/{deviation.title}-{deviation.id}.txt"

            async def text_chunks() -> AsyncIterator[bytes]:
                yield content.encode("utf-8")

            location, written = await self.store.write(filename, text_chunks())
            return DownloadedAsset(deviation, media, location, written)
        selected = deviation.best_media(quality)
        if selected is None:
            raise DownloadError(f"no {quality.value} asset available for {deviation.id}")
        media = selected
        if selected.restricted:
            raise AuthenticationError(
                f"{deviation.id} is restricted; provide authenticated cookies", status_code=403
            )
        filename = key or f"{deviation.author}/{_filename(deviation, media.url)}"
        try:
            location, written = await self.store.write(filename, self.transport.stream(media.url))
        except ApiError as exc:
            if quality is AssetQuality.ORIGINAL and exc.status_code in {401, 403, 404}:
                raise AuthenticationError(
                    f"original asset unavailable for {deviation.id}; "
                    "authenticated cookies may be required",
                    status_code=exc.status_code,
                ) from exc
            raise DownloadError(f"failed to download {deviation.id}: {exc}") from exc
        except DownloadError:
            raise
        except Exception as exc:
            raise DownloadError(f"failed to store {deviation.id}: {exc}") from exc
        return DownloadedAsset(deviation, media, location, written)


def _filename(deviation: Deviation, url: str) -> str:
    suffix = PurePath(urlparse(url).path).suffix or ".bin"
    if deviation.kind is DeviationKind.VIDEO:
        suffix = ".mp4"
    return f"{deviation.title}-{deviation.id}{suffix}"
