"""Authentication values and opt-in secure persistence."""

from __future__ import annotations

import json
import os
import time
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol


@dataclass(frozen=True, slots=True)
class Credentials:
    """Cookie credentials owned by the embedding application."""

    cookies: str = ""
    access_token: str = ""
    refresh_token: str = ""
    expires_at: float | None = None

    @classmethod
    def from_mapping(cls, cookies: Mapping[str, str]) -> Credentials:
        return cls("; ".join(f"{key}={value}" for key, value in cookies.items()))

    def headers(self) -> dict[str, str]:
        if self.access_token:
            return {"Authorization": f"Bearer {self.access_token}"}
        return {"Cookie": self.cookies} if self.cookies else {}

    @property
    def empty(self) -> bool:
        return not (self.cookies or self.access_token)

    @property
    def expired(self) -> bool:
        return self.expires_at is not None and time.time() >= self.expires_at


@dataclass(frozen=True, slots=True)
class OAuthConfig:
    client_id: str
    client_secret: str
    redirect_uri: str
    scopes: tuple[str, ...] = ("basic", "browse")


@dataclass(frozen=True, slots=True)
class AuthState:
    authenticated: bool
    username: str | None = None


class CredentialStore(Protocol):
    def load(self) -> Credentials | None: ...
    def save(self, credentials: Credentials) -> None: ...
    def clear(self) -> None: ...


class JsonCredentialStore:
    """Owner-readable credential file for CLI and desktop integrations."""

    def __init__(self, path: str | Path | None = None) -> None:
        self.path = Path(path or Path.home() / ".config" / "dakit" / "session.json")

    def load(self) -> Credentials | None:
        if not self.path.exists():
            return None
        try:
            value = json.loads(self.path.read_text(encoding="utf-8"))
            if not isinstance(value, dict):
                return None
            result = Credentials(
                str(value.get("cookies", "")),
                str(value.get("access_token", "")),
                str(value.get("refresh_token", "")),
                value.get("expires_at"),
            )
            return None if result.empty else result
        except (OSError, ValueError):
            return None

    def save(self, credentials: Credentials) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        temporary = self.path.with_suffix(".tmp")
        temporary.write_text(
            json.dumps(
                {
                    "cookies": credentials.cookies,
                    "access_token": credentials.access_token,
                    "refresh_token": credentials.refresh_token,
                    "expires_at": credentials.expires_at,
                }
            ),
            encoding="utf-8",
        )
        temporary.chmod(0o600)
        os.replace(temporary, self.path)
        self.path.chmod(0o600)

    def clear(self) -> None:
        self.path.unlink(missing_ok=True)
