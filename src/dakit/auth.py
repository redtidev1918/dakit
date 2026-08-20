"""Public OAuth 2.0 Authorization Code + PKCE state machine."""

from __future__ import annotations

import base64
import hashlib
import secrets
import time
from dataclasses import dataclass
from urllib.parse import parse_qs, urlencode, urlparse

from .core import AuthenticationError, AuthState, SchemaChangedError, TokenSet
from .ports import TokenStore, Transport


@dataclass(frozen=True, slots=True)
class PublicOAuthConfig:
    client_id: str
    redirect_uri: str
    scopes: tuple[str, ...] = ("basic", "browse")


@dataclass(frozen=True, slots=True)
class AuthorizationRequest:
    url: str
    state: str
    verifier: str


class PublicOAuth:
    AUTHORIZE = "https://www.deviantart.com/oauth2/authorize"
    TOKEN = "https://www.deviantart.com/oauth2/token"
    WHOAMI = "https://www.deviantart.com/api/v1/oauth2/user/whoami"

    def __init__(
        self, transport: Transport, config: PublicOAuthConfig, store: TokenStore | None = None
    ) -> None:
        self._transport, self.config, self.store = transport, config, store
        self.tokens = store.load() if store else None

    def begin(self) -> AuthorizationRequest:
        verifier = secrets.token_urlsafe(64)
        digest = hashlib.sha256(verifier.encode("ascii")).digest()
        challenge = base64.urlsafe_b64encode(digest).rstrip(b"=").decode("ascii")
        state = secrets.token_urlsafe(32)
        query = urlencode(
            {
                "response_type": "code",
                "client_id": self.config.client_id,
                "redirect_uri": self.config.redirect_uri,
                "scope": " ".join(self.config.scopes),
                "state": state,
                "code_challenge": challenge,
                "code_challenge_method": "S256",
            }
        )
        return AuthorizationRequest(f"{self.AUTHORIZE}?{query}", state, verifier)

    async def complete(self, request: AuthorizationRequest, callback_url: str) -> AuthState:
        query = parse_qs(urlparse(callback_url).query)
        if query.get("state", [""])[0] != request.state:
            raise AuthenticationError("OAuth state mismatch")
        if query.get("error"):
            raise AuthenticationError(str(query["error"][0]))
        code = query.get("code", [""])[0]
        if not code:
            raise AuthenticationError("OAuth callback has no authorization code")
        self._activate(
            await self._token(
                {
                    "grant_type": "authorization_code",
                    "client_id": self.config.client_id,
                    "redirect_uri": self.config.redirect_uri,
                    "code": code,
                    "code_verifier": request.verifier,
                }
            )
        )
        return await self.status()

    async def refresh(self) -> TokenSet:
        if not self.tokens or not self.tokens.refresh_token:
            raise AuthenticationError("no refresh token is available")
        previous = self.tokens.refresh_token
        tokens = await self._token(
            {
                "grant_type": "refresh_token",
                "client_id": self.config.client_id,
                "refresh_token": previous,
            }
        )
        if not tokens.refresh_token:
            tokens = TokenSet(tokens.access_token, previous, tokens.expires_at)
        self._activate(tokens)
        return tokens

    async def status(self) -> AuthState:
        if not self.tokens or not self.tokens.access_token:
            return AuthState(False)
        if self.tokens.expires_at is not None and self.tokens.expires_at <= time.time():
            if not self.tokens.refresh_token:
                return AuthState(False)
            await self.refresh()
        response = await self._transport.request(
            "GET", self.WHOAMI, headers={"Authorization": f"Bearer {self.tokens.access_token}"}
        )
        payload = response.json()
        if not isinstance(payload, dict) or not payload.get("username"):
            raise SchemaChangedError("official-oauth", "whoami lacks username")
        return AuthState(True, str(payload["username"]))

    def access_token(self) -> str | None:
        return self.tokens.access_token if self.tokens else None

    def logout(self) -> None:
        self.tokens = None
        if self.store:
            self.store.clear()

    async def _token(self, data: dict[str, object]) -> TokenSet:
        payload = (await self._transport.request("POST", self.TOKEN, data=data)).json()
        if not isinstance(payload, dict) or not payload.get("access_token"):
            raise SchemaChangedError("official-oauth", "token response lacks access_token")
        lifetime = _number(payload.get("expires_in"))
        return TokenSet(
            str(payload["access_token"]),
            str(payload.get("refresh_token", "")),
            time.time() + lifetime if lifetime else None,
        )

    def _activate(self, tokens: TokenSet) -> None:
        self.tokens = tokens
        if self.store:
            self.store.save(tokens)


def _number(value: object) -> float:
    try:
        return float(str(value))
    except (TypeError, ValueError):
        return 0
