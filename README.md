# ArtRelay

ArtRelay is a modular Dart and Flutter foundation for third-party art community
clients. It provides domain contracts, official API integration, OAuth PKCE, secure
session storage, deep-link callbacks, diagnostics, and transfer abstractions without
dictating an application's UI or state-management framework.

> Status: active rewrite. The former Python preview is preserved at the Git tag
> `python-preview-1.0.0a1`; it is not the architecture of the next release.

## Workspace

| Package | Purpose | Flutter dependency |
| --- | --- | --- |
| `artrelay_core` | Stable models, failures, repositories, pagination, diagnostics | No |
| `artrelay_api` | OAuth PKCE and official HTTP API adapter | No |
| `artrelay_flutter` | Browser, deep links, secure storage, background transfers | Yes |
| `example_client` | Android, macOS, and Windows integration smoke tests | App |

An application depends on `artrelay_flutter` for a complete Flutter integration, or
uses `artrelay_core` and `artrelay_api` directly in a Dart host.

```yaml
dependencies:
  artrelay_flutter: ^0.1.0-dev.1
```

Public clients supply their own OAuth client ID and exact redirect URI. ArtRelay
does not contain a shared client secret and never automates a login browser.

## Development

Required toolchain:

- Flutter 3.47.1 stable
- Dart 3.13.1
- Android SDK for APK builds
- Xcode for macOS builds
- A Windows runner with Visual Studio for Windows builds

Run the complete local quality gate:

```shell
./tool/verify.sh
```

For mainland China mirror and proxy behavior, see
[`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md). Architecture and continuation state
live in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) and
[`docs/STATUS.md`](docs/STATUS.md).

OAuth application registration and client integration are documented in
[`docs/OAUTH.md`](docs/OAUTH.md).

The runnable host and its build commands live in
[`apps/example_client`](apps/example_client/README.md).

## Project rules

- Core packages contain no widgets, Riverpod, Bloc, or concrete database.
- OAuth uses Authorization Code + PKCE in the system browser.
- Official API DTOs never leak into public domain models.
- Preview assets are never represented as original downloads.
- Logs redact tokens, codes, cookies, and sensitive query parameters.
- Website compatibility code, if added, stays optional and isolated.

## License

See [LICENSE](LICENSE).
