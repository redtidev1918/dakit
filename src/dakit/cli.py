"""Thin development host for the embeddable kernel."""

from __future__ import annotations

import argparse
import asyncio
import os
import webbrowser

from .adapters import JsonTokenStore
from .auth import PublicOAuthConfig
from .client import DAKit
from .core import DAKitError

DEFAULT_CLIENT_ID = "75380"
DEFAULT_REDIRECT_URI = "dakit://oauth/callback"


def parser() -> argparse.ArgumentParser:
    value = argparse.ArgumentParser(prog="dakit")
    value.add_argument("--client-id", default=os.getenv("DAKIT_CLIENT_ID", DEFAULT_CLIENT_ID))
    value.add_argument(
        "--redirect-uri", default=os.getenv("DAKIT_REDIRECT_URI", DEFAULT_REDIRECT_URI)
    )
    commands = value.add_subparsers(dest="command", required=True)
    commands.add_parser("login")
    commands.add_parser("status")
    commands.add_parser("logout")
    artwork = commands.add_parser("artwork")
    artwork.add_argument("url")
    search = commands.add_parser("search")
    search.add_argument("query")
    search.add_argument("--limit", type=int, default=24)
    gallery = commands.add_parser("gallery")
    gallery.add_argument("username")
    gallery.add_argument("--limit", type=int, default=24)
    return value


async def run(args: argparse.Namespace) -> int:
    config = PublicOAuthConfig(args.client_id, args.redirect_uri)
    async with DAKit(config, token_store=JsonTokenStore()) as kit:
        if args.command == "login":
            request = kit.auth.begin()
            webbrowser.open(request.url)
            print("Authorize in your browser, then paste the complete callback URL.")
            callback = await asyncio.to_thread(input, "Callback URL: ")
            state = await kit.auth.complete(request, callback.strip())
            print(f"Authenticated as {state.username}")
        elif args.command == "status":
            state = await kit.auth.status()
            print(state.username if state.authenticated else "not authenticated")
        elif args.command == "logout":
            kit.auth.logout()
            print("logged out")
        elif args.command == "artwork":
            print(await kit.content.artwork_url(args.url))
        elif args.command == "search":
            page = await kit.content.search(args.query, limit=args.limit)
            for item in page.items:
                print(item.id, item.title)
        elif args.command == "gallery":
            page = await kit.content.gallery(args.username, limit=args.limit)
            for item in page.items:
                print(item.id, item.title)
    return 0


def main() -> None:
    try:
        raise SystemExit(asyncio.run(run(parser().parse_args())))
    except (DAKitError, ValueError) as exc:
        raise SystemExit(f"error: {exc}") from exc
