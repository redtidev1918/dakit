# DAKit — DeviantArt Client SDK

<p align="center">
  <img src="docs/icon.png" alt="DAKit" width="160" />
</p>

[![GitHub stars](https://img.shields.io/github/stars/redtidev1918/dakit?style=flat&color=yellow)](https://github.com/redtidev1918/dakit/stargazers)
[![GitHub license](https://img.shields.io/github/license/redtidev1918/dakit?style=flat)](LICENSE)
[![pub.dev](https://img.shields.io/pub/v/dakit_flutter?label=dakit_flutter&style=flat)](https://pub.dev/packages/dakit_flutter)
[![pub.dev](https://img.shields.io/pub/v/dakit_api?label=dakit_api&style=flat)](https://pub.dev/packages/dakit_api)
[![pub.dev](https://img.shields.io/pub/v/dakit_core?label=dakit_core&style=flat)](https://pub.dev/packages/dakit_core)

**Language:** English · [中文](README.md)

DAKit is a modular DeviantArt client SDK for Dart and Flutter. It provides
authentication, the official HTTP API, domain models, diagnostics, and
background transfers for Android, macOS, and Windows apps. You can use it to
build a full third-party client or as a single building block.

This project is maintained independently by the community and is not affiliated
with or endorsed by DeviantArt. "DeviantArt" is used only to name the service
the SDK connects to.

> **Reference app**: [DAViewer](https://github.com/redtidev1918/daviewer) is a
> complete third-party DeviantArt client built on DAKit — born because
> DeviantArt abandoned its official app — and is the best example of DAKit in
> real use.

## What it can do

- Sign in with Authorization Code + PKCE through the system browser;
- Persist the OAuth session securely and resume callbacks after a restart;
- Read the current account, user profiles and relationships, artwork details and
  text, home/search, daily deviations, and the watched feed;
- Browse tags, tag autocomplete, topic navigation, and gallery/favourites folder
  listings and contents;
- Read the "More Like This" preview without one malformed/deleted entry
  discarding valid siblings;
- Read/post artwork comments, favourite/unfavourite artworks, watch/unwatch
  users;
- Read notifications, feedback, and mentions, and expand or delete message
  stacks;
- Resolve the original file from its dedicated endpoint, never passing a
  thumbnail off as the original;
- Queue, resume, pause, cancel, and safely delete background transfers on
  Flutter while retaining records when file removal fails;
- Configure API and media proxies separately, and diagnose DNS, TCP, TLS, HTTP,
  OAuth, parsing, and storage failures;
- Swap the network, sign-in, storage, or transfer layers behind stable domain
  interfaces.

Not yet implemented: submission/editing of artworks, Notes (private messages),
and a local database. Private website endpoints or page scraping are not part of
the stable API.

## Before you start

Before running any sign-in, download, or diagnostics flow:

- You need a DeviantArt developer application. Client-style programs (the sample
  client, CLI, and Android/macOS/Windows apps) must choose **Public**; choose
  **Confidential** only when credentials are kept safely on a server.
- A Public app only needs `client_id`; do not use or store `client_secret`.
  DAKit's client sign-in flow never accepts a secret.
- The callback URI must be added verbatim to the app's OAuth2 Redirect URI
  Whitelist:
  - Flutter sample client / desktop: `dakit://oauth/callback`
  - CLI: `http://127.0.0.1:8765/callback`
- Sign-in needs a `client_id`; downloads also need an artwork UUID (not the
  slug/numeric id in a web URL).

## Package layout

| Package | Purpose | Flutter dependency |
| --- | --- | --- |
| `dakit_core` | Models, errors, repository contracts, pagination, diagnostics, transfer contracts | none |
| `dakit_api` | OAuth PKCE, network config, connectivity checks, official API implementation | none |
| `dakit_flutter` | System browser, deep links, secure storage, background transfers | yes |
| `dakit_cli` | Pure-Dart CLI for sign-in, downloads, and diagnostics | none |
| `example_client` | Android/macOS/Windows integration and diagnostics client | app |

Dependency direction is fixed: `dakit_flutter → dakit_api → dakit_core`.
Business apps depend only on the layer they need; use `dakit_flutter` for full
Flutter integration.

## Install

The packages are published to pub.dev. A full Flutter integration only needs
`dakit_flutter`, which transitively resolves `dakit_api` and `dakit_core`:

```yaml
dependencies:
  dakit_flutter: ^0.1.8
```

If you only need pure-Dart capabilities, declare them individually:

```yaml
dependencies:
  dakit_core: ^0.1.11
  dakit_api: ^0.1.18
```

Then read [Getting started](docs/en/GETTING_STARTED.md). To run the built-in
sign-in flow on mobile or desktop, register a **Public** OAuth app and configure
the exact callback `dakit://oauth/callback`.

## Command-line client

No Dart or Flutter installation is required. Download the archive matching your
OS and CPU from
[DAKit CLI Releases](https://github.com/redtidev1918/dakit/releases?q=dakit_cli):
Linux x64/ARM64, Windows x64, or macOS Intel/Apple Silicon. macOS binaries are
explicitly marked **unsigned previews**: they have no Apple Developer ID
signature or notarization, so Gatekeeper can block the first launch. Every
release includes `SHA256SUMS`.

```text
dakit --help
dakit status --proxy 127.0.0.1:7892
dakit login --client-id YOUR_PUBLIC_CLIENT_ID
dakit whoami
dakit url ARTWORK_UUID --dest downloads
dakit artist USERNAME --limit 24 --delay 0
dakit gallery USERNAME [GALLERY_ID]
dakit fav USERNAME [FOLDER_ID]
dakit search "digital art" --limit 24
dakit logout
```

Before login, register a **Public** DeviantArt OAuth app and whitelist
`http://127.0.0.1:8765/callback` exactly. `login` opens the system browser and
receives the callback locally; the DeviantArt password never enters the CLI.
For a remote or headless system, also whitelist `dakit://oauth/callback` and use
`--manual --no-open`.

Credentials live under `~/.config/dakit/` (Windows: `%APPDATA%/dakit/`) and
refresh automatically. `logout` revokes the remote token; `logout --local`
only removes local credentials. Downloads stream through a temporary file and
preserve an existing destination unless `--overwrite` is explicit.

Configure a proxy with `--proxy HOST:PORT`, `--proxy http://HOST:PORT`,
`http_proxy`, `https_proxy`, or an HTTP-form `all_proxy`. `--verbose` / `-v`
writes redacted diagnostics to `stderr`. The CLI only supports HTTP proxies and
does not silently treat SOCKS5 as HTTP.

The CLI uses the official OAuth API, not web cookies/scraping, so it offers no
`cookies.txt`, SOCKS5 proxy, preview-quality switching, or "anti-ban" strategy.
The official API supports original-file downloads; the CLI never passes a
preview off as the original.


## Minimal example

```dart
final diagnostics = MyDiagnosticSink();
final network = NetworkProfile.environment();
final oauth = DAKitOAuthClient(
  config: OAuthConfig(
    clientId: clientId,
    redirectUri: Uri.parse('dakit://oauth/callback'),
  ),
  networkProfile: network,
  diagnostics: diagnostics,
);

final restored = await oauth.resumePending();
final tokens = restored ?? await oauth.authorize();

final transport = OfficialApiClient(
  session: oauth.session,
  networkProfile: network,
  diagnostics: diagnostics,
);
final account = await OfficialAccountRepository(transport).currentUser();
```

`authorize()` should be triggered by a user action. Create the client early at
startup and call `resumePending()` to receive cold-start deep links.

## Documentation

- [Getting started](docs/en/GETTING_STARTED.md): register an app, run the sample,
  embed the client;
- [Architecture](docs/en/ARCHITECTURE.md): boundaries, extension points,
  compatibility policy;
- [Authentication](docs/en/AUTHENTICATION.md): PKCE, platform callbacks,
  security, troubleshooting;
- [Networking](docs/en/NETWORKING.md): proxy model, mainland China networking,
  staged diagnostics;
- [Media](docs/en/MEDIA.md): original files, text, background tasks, acceptance
  boundaries;
- [Development](docs/en/DEVELOPMENT.md): toolchain, tests, three-platform builds,
  CI, releases;
- [Releasing](docs/en/RELEASING.md): package versioning and pub.dev publishing;
- [Live testing](docs/en/LIVE_TESTING.md): a full media matrix requiring user
  authorization;
- [Status](docs/en/STATUS.md): verified results and follow-up work.

## Development

The project pins Flutter 3.47.1 / Dart 3.13.1. Run the full quality gate:

```shell
./tool/verify.sh
```

Ordinary CI has no OAuth credentials. Unit tests, Android APK, macOS app, and
Windows/MSIX builds are verified on GitHub Actions; the live-account media
matrix still needs a valid Public OAuth app and test material.

## Design principles

- Never store `client_secret` on the client, and never bypass anti-bot checks;
- Do not use an embedded WebView in place of system-browser sign-in;
- Never disable TLS verification, and never log tokens, authorization codes,
  cookies, or PKCE verifiers;
- Do not expose upstream DTOs, plugin types, or a specific state-management
  framework as public domain API;
- Do not promise automatic adaptation to arbitrary website changes; compatibility
  is maintained by centralized adapters and contract tests.

## License

[MIT](LICENSE)

## Community

- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Code of conduct](CODE_OF_CONDUCT.md)

If DAKit helps you, **star it** so more people who need it can find it.
