# dakit_cli

A pure-Dart command-line client for DAKit: sign in with the official OAuth API and download single deviations, artist galleries, folders, favourites, or search results, plus account and connectivity diagnostics. It uses the official API (not web cookies/scraping), so it only exposes what the official API supports.

## Usage

From the repository root, short scripts let you run it without a full Dart path:

```shell
./dakit --help
./devart-dl artist USERNAME
```

Or run it directly:

```shell
dart run packages/dakit_cli/bin/dakit.dart login --client-id YOUR_PUBLIC_CLIENT_ID --proxy 127.0.0.1:7892
dart run packages/dakit_cli/bin/dakit.dart url ARTWORK_UUID --dest downloads
```

`login` opens the system browser; after authorizing, paste the full callback URL from the address bar back into the CLI. Credentials are stored at `~/.config/dakit/credentials.json` (Windows: `%APPDATA%`). Every command accepts `--verbose` / `-v`, which prints sanitized diagnostic events to `stderr`.

For the full command list and proxy notes, see the [root README](../../README.md#command-line-client).

DAKit is a community project and is not affiliated with or endorsed by DeviantArt.
