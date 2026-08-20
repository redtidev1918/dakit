"""Artwork details, gallery and collection APIs."""

from __future__ import annotations

import re
from collections.abc import AsyncIterator

from ..errors import ParseError
from ..models import Artwork, Page
from ..parser import parse_initial_state, parse_page, parse_state_deviations
from ..session import ClientSession


class ArtworkService:
    def __init__(self, session: ClientSession) -> None:
        self.session = session

    async def get(self, url: str) -> Artwork:
        if not url.startswith((f"{self.session.BASE_URL}/", "https://deviantart.com/")):
            raise ValueError("url must be a DeviantArt artwork URL")
        response = await self.session.request("GET", url)
        items = parse_state_deviations(parse_initial_state(response.text))
        match = re.search(r"-(\d+)(?:[/?#]|$)", url)
        wanted = match.group(1) if match else None
        for item in items:
            if wanted is None or item.id == wanted:
                return item
        raise ParseError("artwork was not present in the page")

    async def gallery(
        self,
        username: str,
        *,
        folder_id: str | None = None,
        cursor: str | None = None,
        limit: int = 24,
    ) -> Page[Artwork]:
        token = await self.session.csrf_token(username)
        params: dict[str, object] = {
            "username": username,
            "type": "gallery",
            "limit": limit,
            "offset": cursor or 0,
            "csrf_token": token,
        }
        if folder_id:
            params["folderid"] = folder_id
        return await self._page("/_puppy/dashared/gallection/contents", params)

    async def favorites(
        self, username: str, folder_id: str, *, cursor: str | None = None, limit: int = 24
    ) -> Page[Artwork]:
        token = await self.session.csrf_token(username)
        params = {
            "username": username,
            "type": "collection",
            "folderid": folder_id,
            "limit": limit,
            "offset": cursor or 0,
            "csrf_token": token,
        }
        return await self._page("/_puppy/dashared/gallection/contents", params)

    async def iter_gallery(
        self, username: str, *, folder_id: str | None = None, limit: int = 24, hydrate: bool = False
    ) -> AsyncIterator[Artwork]:
        cursor: str | None = None
        while True:
            page = await self.gallery(username, folder_id=folder_id, cursor=cursor, limit=limit)
            for item in page.items:
                yield await self.get(item.url) if hydrate else item
            if not page.has_more:
                break
            cursor = page.next_cursor

    async def _page(self, path: str, params: dict[str, object]) -> Page[Artwork]:
        response = await self.session.request("GET", path, params=params)
        try:
            return parse_page(response.json())
        except (TypeError, ValueError) as exc:
            raise ParseError("invalid JSON response") from exc
