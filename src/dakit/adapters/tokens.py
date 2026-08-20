"""Local token persistence for CLI and development hosts."""

from __future__ import annotations

import json
import os
from pathlib import Path

from ..core import TokenSet


class JsonTokenStore:
    def __init__(self, path: str | Path | None = None) -> None:
        self.path = Path(path or Path.home() / ".config" / "dakit" / "tokens.json")

    def load(self) -> TokenSet | None:
        try:
            value = json.loads(self.path.read_text(encoding="utf-8"))
            token = str(value.get("access_token", ""))
            return (
                TokenSet(token, str(value.get("refresh_token", "")), value.get("expires_at"))
                if token
                else None
            )
        except (OSError, TypeError, ValueError):
            return None

    def save(self, tokens: TokenSet) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        temporary = self.path.with_suffix(".tmp")
        temporary.write_text(
            json.dumps(
                {
                    "access_token": tokens.access_token,
                    "refresh_token": tokens.refresh_token,
                    "expires_at": tokens.expires_at,
                }
            ),
            encoding="utf-8",
        )
        temporary.chmod(0o600)
        os.replace(temporary, self.path)

    def clear(self) -> None:
        self.path.unlink(missing_ok=True)
