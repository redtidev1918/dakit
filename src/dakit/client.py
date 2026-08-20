"""Composable client kernel and backwards-compatible facade."""

from __future__ import annotations

from collections.abc import AsyncIterator

from .auth import Credentials
from .downloads import DownloadService
from .models import Artwork, ClientCapabilities, Page
from .services import ArtworkService, BrowseService, UserService
from .session import ClientSession
from .store import AssetStore
from .transport import AsyncTransport


class DAKit:
    """Shared application kernel for building a third-party client."""

    capabilities = ClientCapabilities()

    def __init__(
        self, *, transport: AsyncTransport | None = None, credentials: Credentials | None = None
    ) -> None:
        self.session = ClientSession(transport, credentials)
        self.artworks = ArtworkService(self.session)
        self.browse = BrowseService(self.session)
        self.users = UserService(self.session)

    @property
    def transport(self) -> AsyncTransport:
        return self.session.transport

    @property
    def credentials(self) -> Credentials:
        return self.session.credentials

    def set_credentials(self, credentials: Credentials) -> None:
        self.session.set_credentials(credentials)

    def media(self, store: AssetStore) -> DownloadService:
        return DownloadService(self.transport, store)

    async def __aenter__(self) -> DAKit:
        return self

    async def __aexit__(self, *_: object) -> None:
        await self.close()

    async def close(self) -> None:
        await self.session.close()

    async def deviation(self, url: str) -> Artwork:
        return await self.artworks.get(url)

    async def gallery(
        self,
        username: str,
        *,
        folder_id: str | None = None,
        cursor: str | None = None,
        limit: int = 24,
    ) -> Page[Artwork]:
        return await self.artworks.gallery(
            username, folder_id=folder_id, cursor=cursor, limit=limit
        )

    async def favorites(
        self, username: str, folder_id: str, *, cursor: str | None = None, limit: int = 24
    ) -> Page[Artwork]:
        return await self.artworks.favorites(username, folder_id, cursor=cursor, limit=limit)

    async def search(
        self, query: str, *, username: str | None = None, cursor: str | None = None, limit: int = 24
    ) -> Page[Artwork]:
        return await self.browse.search(query, username=username, cursor=cursor, limit=limit)

    async def iter_gallery(
        self, username: str, *, folder_id: str | None = None, limit: int = 24
    ) -> AsyncIterator[Artwork]:
        async for item in self.artworks.iter_gallery(username, folder_id=folder_id, limit=limit):
            yield item


DeviantArtClient = DAKit
