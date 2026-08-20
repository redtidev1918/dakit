"""Official OAuth2 authentication and session lifecycle."""

from __future__ import annotations

import asyncio
import secrets
import time
import webbrowser
from urllib.parse import parse_qs, urlencode, urlparse

from ..auth import AuthState, Credentials, CredentialStore, OAuthConfig
from ..errors import AuthenticationError, ParseError
from ..session import ClientSession


class AuthenticationService:
    AUTHORIZE_URL = "https://www.deviantart.com/oauth2/authorize"
    TOKEN_URL = "https://www.deviantart.com/oauth2/token"
    WHOAMI_URL = "https://www.deviantart.com/api/v1/oauth2/user/whoami"

    def __init__(self, session: ClientSession, store: CredentialStore | None = None) -> None:
        self.session = session
        self.store = store

    def authorization_url(self, config: OAuthConfig, *, state: str) -> str:
        return (
            self.AUTHORIZE_URL
            + "?"
            + urlencode(
                {
                    "response_type": "code",
                    "client_id": config.client_id,
                    "redirect_uri": config.redirect_uri,
                    "scope": " ".join(config.scopes),
                    "state": state,
                }
            )
        )

    async def login_oauth(
        self,
        config: OAuthConfig,
        *,
        timeout: float = 300,
        open_browser: bool = True,
        persist: bool = True,
    ) -> AuthState:
        """Authorize in the system browser and receive the redirect on localhost."""
        parsed = urlparse(config.redirect_uri)
        if (
            parsed.scheme != "http"
            or parsed.hostname not in {"127.0.0.1", "localhost"}
            or not parsed.port
        ):
            raise ValueError("redirect_uri must be an HTTP localhost URL with an explicit port")
        state = secrets.token_urlsafe(32)
        result: asyncio.Future[str] = asyncio.get_running_loop().create_future()

        async def callback(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
            try:
                request_line = (await reader.readline()).decode("ascii", errors="replace")
                target = request_line.split(" ", 2)[1]
                query = parse_qs(urlparse(target).query)
                if query.get("state", [""])[0] != state:
                    raise AuthenticationError("OAuth state did not match")
                if "error" in query:
                    raise AuthenticationError(query["error"][0])
                code = query.get("code", [""])[0]
                if not code:
                    raise AuthenticationError("OAuth callback did not contain a code")
                if not result.done():
                    result.set_result(code)
                body = b"DAKit login completed. You may close this window."
                writer.write(
                    b"HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\n"
                    + f"Content-Length: {len(body)}\r\n\r\n".encode()
                    + body
                )
            except Exception as exc:
                if not result.done():
                    result.set_exception(exc)
            finally:
                await writer.drain()
                writer.close()
                await writer.wait_closed()

        server = await asyncio.start_server(callback, parsed.hostname, parsed.port)
        try:
            url = self.authorization_url(config, state=state)
            if open_browser:
                webbrowser.open(url)
            code = await asyncio.wait_for(result, timeout)
        finally:
            server.close()
            await server.wait_closed()
        credentials = await self._exchange(config, code)
        self.session.set_credentials(credentials)
        auth_state = await self.status()
        if not auth_state.authenticated:
            raise AuthenticationError("OAuth token was issued but whoami failed")
        if persist and self.store:
            self.store.save(credentials)
        return auth_state

    async def _exchange(self, config: OAuthConfig, code: str) -> Credentials:
        response = await self.session.request(
            "POST",
            self.TOKEN_URL,
            data={
                "grant_type": "authorization_code",
                "client_id": config.client_id,
                "client_secret": config.client_secret,
                "redirect_uri": config.redirect_uri,
                "code": code,
            },
        )
        try:
            payload = response.json()
        except (TypeError, ValueError) as exc:
            raise ParseError("OAuth token response was invalid") from exc
        if not isinstance(payload, dict) or not payload.get("access_token"):
            raise AuthenticationError("OAuth token response did not contain an access token")
        expires = float(payload.get("expires_in", 0))
        return Credentials(
            access_token=str(payload["access_token"]),
            refresh_token=str(payload.get("refresh_token", "")),
            expires_at=time.time() + expires if expires else None,
        )

    async def login_cookies(self, cookies: str, *, persist: bool = True) -> AuthState:
        self.session.set_credentials(Credentials(cookies=cookies))
        state = await self.status()
        if not state.authenticated:
            self.session.set_credentials(Credentials())
            raise AuthenticationError("cookies are not authenticated or have expired")
        if persist and self.store:
            self.store.save(self.session.credentials)
        return state

    async def status(self) -> AuthState:
        if not self.session.authenticated or self.session.credentials.expired:
            return AuthState(False)
        if self.session.credentials.access_token:
            response = await self.session.request("GET", self.WHOAMI_URL)
            try:
                payload = response.json()
            except (TypeError, ValueError) as exc:
                raise ParseError("whoami response was invalid") from exc
            username = payload.get("username") if isinstance(payload, dict) else None
            return AuthState(bool(username), str(username) if username else None)
        response = await self.session.request("GET", "/")
        authenticated = (
            '"isLoggedIn":true' in response.text or '\\"isLoggedIn\\":true' in response.text
        )
        return AuthState(authenticated)

    async def logout(self, *, clear_store: bool = True) -> None:
        self.session.set_credentials(Credentials())
        if clear_store and self.store:
            self.store.clear()
