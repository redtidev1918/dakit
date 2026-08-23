# dakit_cli

A pure-Dart command-line client for DAKit: sign in with the official OAuth API and download single deviations, artist galleries, folders, favourites, or search results, plus account and connectivity diagnostics. It uses the official API (not web cookies/scraping), so it only exposes what the official API supports.

## Usage

Download a standalone binary from
[GitHub Releases](https://github.com/redtidev1918/dakit/releases?q=dakit_cli).
Linux x64/ARM64, Windows x64, and macOS Intel/Apple Silicon archives are built
for every CLI tag, with checksums. Dart and Flutter are not required at runtime.

The macOS archives are unsigned previews without Apple Developer ID signing or
notarization.

From a source checkout, the short scripts remain available:

```shell
./dakit --help
./devart-dl artist USERNAME
```

Or run the Dart entry point directly:

```shell
dart run packages/dakit_cli/bin/dakit.dart login --client-id YOUR_PUBLIC_CLIENT_ID
dart run packages/dakit_cli/bin/dakit.dart url ARTWORK_UUID --dest downloads
```

Whitelist `http://127.0.0.1:8765/callback` on a Public OAuth application.
`login` opens the system browser and receives that local callback. Use
`--manual --no-open` only for headless systems. Credentials refresh
automatically and are stored under `~/.config/dakit/` (Windows: `%APPDATA%`).
Downloads stream to a `.part` file and preserve existing destinations unless
`--overwrite` is passed. Every network command accepts `--verbose` / `-v` for
sanitized diagnostics.

For the full command list and proxy notes, see the [root README](../../README.md#command-line-client).

DAKit is a community project and is not affiliated with or endorsed by DeviantArt.
