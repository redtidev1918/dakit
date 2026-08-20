"""High-level, embeddable DeviantArt client."""

from __future__ import annotations

import re
from collections.abc import AsyncIterator

from .auth import Credentials
from .errors import ParseError
from .models import Deviation, Page
from .parser import parse_initial_state, parse_page, parse_state_deviations
from .transport import AsyncTransport, HttpxTransport


class DeviantArtClient:
    BASE_URL = "https://www.deviantart.com"

    def __init__(
        self, *, transport: AsyncTransport | None = None, credentials: Credentials | None = None
    ) -> None:
        self.transport = transport or HttpxTransport()
        self.credentials = credentials or Credentials()
        self._owns_transport = transport is None
        self._csrf_token: str | None = None

    async def __aenter__(self) -> DeviantArtClient:
        return self

    async def __aexit__(self, *_: object) -> None:
        await self.close()

    async def close(self) -> None:
        if self._owns_transport:
            await self.transport.close()

    async def gallery(
        self,
        username: str,
        *,
        folder_id: str | None = None,
        cursor: str | None = None,
        limit: int = 24,
    ) -> Page:
        token = await self._token(username)
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
    ) -> Page:
        token = await self._token(username)
        params = {
            "username": username,
            "type": "collection",
            "folderid": folder_id,
            "limit": limit,
            "offset": cursor or 0,
            "csrf_token": token,
        }
        return await self._page("/_puppy/dashared/gallection/contents", params)

    async def search(
        self, query: str, *, username: str | None = None, cursor: str | None = None, limit: int = 24
    ) -> Page:
        token = await self._token(username or "")
        if username:
            path = "/_puppy/dashared/gallection/search"
            params: dict[str, object] = {
                "username": username,
                "type": "gallery",
                "q": query,
                "limit": limit,
                "offset": cursor or 0,
                "csrf_token": token,
            }
        else:
            response = await self.transport.request(
                "GET",
                f"{self.BASE_URL}/search",
                params={"q": query},
                headers=self.credentials.headers(),
            )
            items = parse_state_deviations(parse_initial_state(response.text))
            return Page(items[:limit])
        return await self._page(path, params)

    async def deviation(self, url: str) -> Deviation:
        """Load a complete deviation, including original download and literature text."""
        if not url.startswith((f"{self.BASE_URL}/", "https://deviantart.com/")):
            raise ValueError("url must be a DeviantArt artwork URL")
        response = await self.transport.request("GET", url, headers=self.credentials.headers())
        items = parse_state_deviations(parse_initial_state(response.text))
        match = re.search(r"-(\d+)(?:[/?#]|$)", url)
        deviation_id = match.group(1) if match else None
        if deviation_id:
            for item in items:
                if item.id == deviation_id:
                    return item
        if items:
            return items[0]
        raise ParseError("deviation was not present in the page")

    async def iter_gallery(
        self, username: str, *, folder_id: str | None = None, limit: int = 24
    ) -> AsyncIterator[Deviation]:
        cursor: str | None = None
        while True:
            page = await self.gallery(username, folder_id=folder_id, cursor=cursor, limit=limit)
            for item in page.items:
                yield item
            if not page.has_more:
                break
            cursor = page.next_cursor

    async def _token(self, username: str) -> str:
        if self._csrf_token:
            return self._csrf_token
        response = await self.transport.request(
            "GET", f"{self.BASE_URL}/{username}", headers=self.credentials.headers()
        )
        match = re.search(r"window\.__CSRF_TOKEN__\s*=\s*['\"]([^'\"]+)", response.text)
        if not match:
            raise ParseError("CSRF token was not present in the page")
        self._csrf_token = match.group(1)
        return self._csrf_token

    async def _page(self, path: str, params: dict[str, object]) -> Page:
        response = await self.transport.request(
            "GET", self.BASE_URL + path, params=params, headers=self.credentials.headers()
        )
        try:
            return parse_page(response.json())
        except (ValueError, TypeError) as exc:
            raise ParseError("invalid JSON response") from exc
