"""Replaceable async transport boundary."""

from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator, Mapping
from dataclasses import dataclass, field
from typing import Protocol

import httpx

from .errors import ApiError, AuthenticationError, TransportError


@dataclass(frozen=True, slots=True)
class Response:
    status_code: int
    headers: Mapping[str, str]
    content: bytes

    @property
    def text(self) -> str:
        return self.content.decode("utf-8", errors="replace")

    def json(self) -> object:
        import json

        return json.loads(self.content)


class AsyncTransport(Protocol):
    async def request(
        self,
        method: str,
        url: str,
        *,
        params: Mapping[str, object] | None = None,
        headers: Mapping[str, str] | None = None,
    ) -> Response: ...
    def stream(
        self, url: str, *, headers: Mapping[str, str] | None = None
    ) -> AsyncIterator[bytes]: ...
    async def close(self) -> None: ...


@dataclass(slots=True)
class HttpxTransport:
    timeout: float = 30.0
    retries: int = 2
    proxy: str | None = None
    _client: httpx.AsyncClient = field(init=False, repr=False)

    def __post_init__(self) -> None:
        self._client = httpx.AsyncClient(
            timeout=self.timeout,
            proxy=self.proxy,
            follow_redirects=True,
            headers={"User-Agent": "dakit/0.1"},
        )

    async def request(
        self,
        method: str,
        url: str,
        *,
        params: Mapping[str, object] | None = None,
        headers: Mapping[str, str] | None = None,
    ) -> Response:
        for attempt in range(self.retries + 1):
            try:
                result = await self._client.request(
                    method,
                    url,
                    params=params,  # type: ignore[arg-type]
                    headers=headers,
                )
                if result.status_code in (401, 403):
                    raise AuthenticationError(
                        "authentication required", status_code=result.status_code
                    )
                if result.status_code >= 400:
                    raise ApiError(
                        f"DeviantArt returned HTTP {result.status_code}",
                        status_code=result.status_code,
                    )
                return Response(result.status_code, result.headers, result.content)
            except (httpx.TimeoutException, httpx.TransportError) as exc:
                if attempt == self.retries:
                    raise TransportError(str(exc)) from exc
                await asyncio.sleep(0.5 * 2**attempt)
        raise AssertionError("unreachable")

    async def stream(
        self, url: str, *, headers: Mapping[str, str] | None = None
    ) -> AsyncIterator[bytes]:
        try:
            async with self._client.stream("GET", url, headers=headers) as result:
                if result.status_code >= 400:
                    raise ApiError(
                        f"asset download returned HTTP {result.status_code}",
                        status_code=result.status_code,
                    )
                async for chunk in result.aiter_bytes():
                    yield chunk
        except httpx.TransportError as exc:
            raise TransportError(str(exc)) from exc

    async def close(self) -> None:
        await self._client.aclose()
