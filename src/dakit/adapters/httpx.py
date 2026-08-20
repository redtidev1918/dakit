"""HTTPX implementation of the transport port."""

from __future__ import annotations

import asyncio
import json
from collections.abc import AsyncIterator, Mapping
from dataclasses import dataclass, field

import httpx

from ..core import AuthenticationError, RemoteError, TransportError


@dataclass(frozen=True, slots=True)
class HttpResponse:
    status: int
    headers: Mapping[str, str]
    content: bytes

    def json(self) -> object:
        return json.loads(self.content)


@dataclass(slots=True)
class HttpxTransport:
    timeout: float = 30
    retries: int = 2
    proxy: str | None = None
    _client: httpx.AsyncClient = field(init=False, repr=False)

    def __post_init__(self) -> None:
        self._client = httpx.AsyncClient(
            timeout=self.timeout,
            proxy=self.proxy,
            follow_redirects=True,
            headers={"User-Agent": "dakit/1"},
        )

    async def request(
        self,
        method: str,
        url: str,
        *,
        params: Mapping[str, object] | None = None,
        headers: Mapping[str, str] | None = None,
        data: Mapping[str, object] | None = None,
    ) -> HttpResponse:
        for attempt in range(self.retries + 1):
            try:
                response = await self._client.request(
                    method,
                    url,
                    params=params,  # type: ignore[arg-type]
                    headers=headers,
                    data=data,
                )
                if response.status_code in {401, 403}:
                    raise AuthenticationError("authorization rejected", status=response.status_code)
                if response.status_code >= 400:
                    raise RemoteError(
                        f"remote returned HTTP {response.status_code}",
                        status=response.status_code,
                    )
                return HttpResponse(response.status_code, response.headers, response.content)
            except (httpx.TimeoutException, httpx.TransportError) as exc:
                if attempt == self.retries:
                    raise TransportError(str(exc)) from exc
                await asyncio.sleep(0.25 * 2**attempt)
        raise AssertionError("unreachable")

    async def stream(
        self, url: str, *, headers: Mapping[str, str] | None = None
    ) -> AsyncIterator[bytes]:
        try:
            async with self._client.stream("GET", url, headers=headers) as response:
                if response.status_code >= 400:
                    raise RemoteError("asset request failed", status=response.status_code)
                async for chunk in response.aiter_bytes():
                    yield chunk
        except httpx.TransportError as exc:
            raise TransportError(str(exc)) from exc

    async def close(self) -> None:
        await self._client.aclose()
