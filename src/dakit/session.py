"""Shared authenticated session used by every domain service."""

from __future__ import annotations

import re
from collections.abc import Mapping

from .auth import Credentials
from .errors import ParseError
from .transport import AsyncTransport, HttpxTransport, Response


class ClientSession:
    BASE_URL = "https://www.deviantart.com"

    def __init__(
        self, transport: AsyncTransport | None = None, credentials: Credentials | None = None
    ) -> None:
        self.transport = transport or HttpxTransport()
        self.credentials = credentials or Credentials()
        self._owns_transport = transport is None
        self._csrf_token: str | None = None

    @property
    def authenticated(self) -> bool:
        return bool(self.credentials.cookies)

    def set_credentials(self, credentials: Credentials) -> None:
        self.credentials = credentials
        self._csrf_token = None

    async def request(
        self,
        method: str,
        path_or_url: str,
        *,
        params: Mapping[str, object] | None = None,
        json: object | None = None,
        data: Mapping[str, object] | None = None,
    ) -> Response:
        url = path_or_url if path_or_url.startswith("http") else self.BASE_URL + path_or_url
        return await self.transport.request(
            method, url, params=params, headers=self.credentials.headers(), json=json, data=data
        )

    async def csrf_token(self, username: str = "") -> str:
        if self._csrf_token:
            return self._csrf_token
        response = await self.request("GET", f"/{username}")
        match = re.search(r"window\.__CSRF_TOKEN__\s*=\s*['\"]([^'\"]+)", response.text)
        if not match:
            raise ParseError("CSRF token was not present in the page")
        self._csrf_token = match.group(1)
        return self._csrf_token

    async def close(self) -> None:
        if self._owns_transport:
            await self.transport.close()
