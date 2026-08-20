"""Small reference CLI; application logic remains in the SDK."""

from __future__ import annotations

import argparse
import asyncio
import os
from pathlib import Path

from .auth import Credentials
from .client import DeviantArtClient
from .downloads import DownloadService
from .models import AssetQuality
from .store import FileSystemStore


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="deviantart")
    parser.add_argument("--cookie", default=os.getenv("DEVIANTART_COOKIE", ""))
    parser.add_argument("--output", type=Path, default=Path("downloads"))
    sub = parser.add_subparsers(dest="command", required=True)
    gallery = sub.add_parser("gallery", help="download a user's gallery")
    gallery.add_argument("username")
    gallery.add_argument("--folder")
    gallery.add_argument("--quality", choices=[item.value for item in AssetQuality], default="full")
    gallery.add_argument("--limit", type=int)
    search = sub.add_parser("search", help="list search results")
    search.add_argument("query")
    search.add_argument("--username")
    search.add_argument("--limit", type=int, default=24)
    return parser


async def run(args: argparse.Namespace) -> int:
    async with DeviantArtClient(credentials=Credentials(args.cookie)) as client:
        if args.command == "search":
            page = await client.search(args.query, username=args.username, limit=args.limit)
            for item in page.items:
                print(f"{item.id}\t{item.author}\t{item.title}\t{item.url}")
            return 0
        service = DownloadService(client.transport, FileSystemStore(args.output))
        count = 0
        async for deviation in client.iter_gallery(args.username, folder_id=args.folder):
            result = await service.download(deviation, quality=AssetQuality(args.quality))
            print(result.location)
            count += 1
            if args.limit and count >= args.limit:
                break
        return 0


def main() -> int:
    return asyncio.run(run(build_parser().parse_args()))
