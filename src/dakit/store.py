"""Replaceable storage boundary for downloaded assets."""

from __future__ import annotations

import os
import re
from collections.abc import AsyncIterable
from pathlib import Path
from typing import Protocol


class AssetStore(Protocol):
    async def write(self, key: str, chunks: AsyncIterable[bytes]) -> tuple[str, int]: ...


class FileSystemStore:
    def __init__(self, root: str | Path) -> None:
        self.root = Path(root).expanduser().resolve()

    async def write(self, key: str, chunks: AsyncIterable[bytes]) -> tuple[str, int]:
        path = self.root / _safe_key(key)
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_name(path.name + ".part")
        written = 0
        try:
            with temporary.open("wb") as stream:
                async for chunk in chunks:
                    stream.write(chunk)
                    written += len(chunk)
            os.replace(temporary, path)
        except BaseException:
            temporary.unlink(missing_ok=True)
            raise
        return str(path), written


def _safe_key(key: str) -> Path:
    parts = []
    for part in Path(key).parts:
        if part in ("", ".", "..", os.sep):
            continue
        cleaned = re.sub(r"[\\/:*?\"<>|\x00-\x1f]", "_", part).strip(" .")
        parts.append(cleaned or "untitled")
    if not parts:
        raise ValueError("asset key must contain a filename")
    return Path(*parts)
