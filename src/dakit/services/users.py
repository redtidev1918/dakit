"""User profile APIs."""

from __future__ import annotations

from collections.abc import Mapping
from typing import Any

from ..errors import ParseError
from ..models import User
from ..parser import parse_initial_state
from ..session import ClientSession


class UserService:
    def __init__(self, session: ClientSession) -> None:
        self.session = session

    async def get(self, username: str) -> User:
        response = await self.session.request("GET", f"/{username}")
        state = parse_initial_state(response.text)
        entities = state.get("@@entities", {})
        users = entities.get("user", {}) if isinstance(entities, Mapping) else {}
        if not isinstance(users, Mapping):
            raise ParseError("user entities were missing")
        for value in users.values():
            if (
                isinstance(value, Mapping)
                and str(value.get("username", "")).lower() == username.lower()
            ):
                return _user(value)
        raise ParseError(f"user '{username}' was not present in the page")


def _user(data: Mapping[str, Any]) -> User:
    stats = data.get("stats", {})
    return User(
        id=str(data.get("userId", "")),
        username=str(data.get("username", "")),
        url=f"https://www.deviantart.com/{data.get('username', '')}",
        avatar_url=str(data["usericon"]) if data.get("usericon") else None,
        display_name=str(data["displayName"]) if data.get("displayName") else None,
        bio=str(data["bio"]) if data.get("bio") else None,
        is_group=bool(data.get("isGroup", False)),
        is_watching=bool(data.get("isWatching", False)),
        watchers=_integer(stats.get("watchers")) if isinstance(stats, Mapping) else None,
        deviations=_integer(stats.get("deviations")) if isinstance(stats, Mapping) else None,
        raw=dict(data),
    )


def _integer(value: object) -> int | None:
    try:
        return int(str(value)) if value is not None else None
    except (TypeError, ValueError):
        return None
