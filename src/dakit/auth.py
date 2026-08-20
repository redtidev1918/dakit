"""Authentication values with no persistence policy."""

from collections.abc import Mapping
from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class Credentials:
    """Cookie credentials supplied by the embedding application."""

    cookies: str = ""

    @classmethod
    def from_mapping(cls, cookies: Mapping[str, str]) -> "Credentials":
        return cls("; ".join(f"{key}={value}" for key, value in cookies.items()))

    def headers(self) -> dict[str, str]:
        return {"Cookie": self.cookies} if self.cookies else {}
