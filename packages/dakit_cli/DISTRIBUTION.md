# DAKit CLI

`dakit` is a standalone command-line client for the official DeviantArt OAuth
API. It does not require Dart or Flutter after download.

Run `dakit --help` to see all commands. Before logging in, register a Public
OAuth application and whitelist `http://127.0.0.1:8765/callback`. Then run:

```text
dakit login --client-id YOUR_PUBLIC_CLIENT_ID
dakit whoami
dakit search "digital art" --limit 10 --dest downloads
```

The macOS archives are unsigned previews: they have no Apple Developer ID
signature and are not notarized. Gatekeeper may block their first launch.

DAKit is a community project and is not affiliated with or endorsed by
DeviantArt. See the repository README for security and proxy guidance.
