"""Small reference CLI; application logic remains in the SDK."""

from __future__ import annotations

import argparse
import asyncio
import os
from pathlib import Path

from .auth import Credentials, JsonCredentialStore, OAuthConfig
from .client import DAKit
from .downloads import DownloadService
from .errors import DeviantArtError
from .models import AssetQuality
from .store import FileSystemStore


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="dakit")
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
    url = sub.add_parser("url", help="download one artwork URL")
    url.add_argument("url")
    url.add_argument("--quality", choices=[item.value for item in AssetQuality], default="full")
    login = sub.add_parser("login", help="sign in with DeviantArt OAuth2")
    login.add_argument("--timeout", type=float, default=300)
    login.add_argument("--client-id", default=os.getenv("DAKIT_CLIENT_ID"))
    login.add_argument("--client-secret", default=os.getenv("DAKIT_CLIENT_SECRET"))
    login.add_argument("--redirect-uri", default=os.getenv("DAKIT_REDIRECT_URI"))
    sub.add_parser("status", help="show authentication status")
    sub.add_parser("logout", help="remove the saved session")
    return parser


async def run(args: argparse.Namespace) -> int:
    store = JsonCredentialStore()
    credentials = Credentials(args.cookie) if args.cookie else store.load()
    async with DAKit(credentials=credentials, credential_store=store) as client:
        if args.command == "login":
            if not all((args.client_id, args.client_secret, args.redirect_uri)):
                raise ValueError("login requires --client-id, --client-secret and --redirect-uri")
            state = await client.auth.login_oauth(
                OAuthConfig(args.client_id, args.client_secret, args.redirect_uri),
                timeout=args.timeout,
            )
            print(f"logged in as {state.username or 'authenticated user'}")
            return 0
        if args.command == "status":
            state = await client.auth.status()
            print(
                f"logged in as {state.username or 'authenticated user'}"
                if state.authenticated
                else "not logged in"
            )
            return 0 if state.authenticated else 1
        if args.command == "logout":
            await client.auth.logout()
            print("logged out")
            return 0
        if args.command == "search":
            page = await client.search(args.query, username=args.username, limit=args.limit)
            for item in page.items:
                print(f"{item.id}\t{item.author}\t{item.title}\t{item.url}")
            return 0
        service = DownloadService(client.transport, FileSystemStore(args.output))
        if args.command == "url":
            deviation = await client.deviation(args.url)
            result = await service.download(deviation, quality=AssetQuality(args.quality))
            print(result.location)
            return 0
        count = 0
        async for deviation in client.iter_gallery(args.username, folder_id=args.folder):
            try:
                deviation = await client.deviation(deviation.url)
                result = await service.download(deviation, quality=AssetQuality(args.quality))
                print(result.location)
            except DeviantArtError as exc:
                print(f"error: {deviation.id}: {exc}")
            count += 1
            if args.limit and count >= args.limit:
                break
        return 0


def main() -> int:
    try:
        return asyncio.run(run(build_parser().parse_args()))
    except (DeviantArtError, ValueError) as exc:
        print(f"error: {exc}")
        return 1
