# DAKit — DeviantArt Client SDK

DAKit is a modular Dart and Flutter foundation for third-party DeviantArt clients.
It provides domain contracts, official API integration, OAuth PKCE, secure session
storage, deep-link callbacks, diagnostics, and transfer abstractions without
dictating an application's UI or state-management framework.

DAKit is a community project and is not affiliated with or endorsed by DeviantArt.
“DeviantArt” is used only to identify the service with which the SDK interoperates.

> Status: active rewrite. The former Python preview is preserved at the Git tag
> `python-preview-1.0.0a1`; it is not the architecture of the next release.

## Workspace

| Package | Purpose | Flutter dependency |
| --- | --- | --- |
| `dakit_core` | Stable models, failures, repositories, pagination, diagnostics | No |
| `dakit_api` | OAuth PKCE and official HTTP API adapter | No |
| `dakit_flutter` | Browser, deep links, secure storage, background transfers | Yes |
| `example_client` | Android, macOS, and Windows integration smoke tests | App |

An application depends on `dakit_flutter` for a complete Flutter integration, or
uses `dakit_core` and `dakit_api` directly in a Dart host.

Until the first pub.dev release, depend on the required package directly from this
repository:

```yaml
dependencies:
  dakit_flutter:
    git:
      url: https://github.com/redtidev1918/dakit.git
      path: packages/dakit_flutter
```

Public clients supply their own OAuth client ID and exact redirect URI. DAKit
does not contain a shared client secret and never automates credentials, human
verification, or an embedded login WebView.

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
[`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md). Runtime proxy profiles and staged
connectivity checks are documented in [`docs/NETWORKING.md`](docs/NETWORKING.md).
Architecture and continuation state live in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) and
[`docs/STATUS.md`](docs/STATUS.md).

OAuth application registration and client integration are documented in
[`docs/OAUTH.md`](docs/OAUTH.md).

The runnable host and its build commands live in
[`apps/example_client`](apps/example_client/README.md).

Credential-free CI and opt-in real-account acceptance are separate. See
[`docs/LIVE_TESTING.md`](docs/LIVE_TESTING.md) for the redacted full-media matrix.

Original-file resolution, background recovery, and proxy behavior are documented
in [`docs/TRANSFERS.md`](docs/TRANSFERS.md).

The four-platform build matrix and its signing/security boundary are documented in
[`docs/CI.md`](docs/CI.md).

## Project rules

- Core packages contain no widgets, Riverpod, Bloc, or concrete database.
- OAuth uses Authorization Code + PKCE in the system browser.
- Official API DTOs never leak into public domain models.
- Preview assets are never represented as original downloads.
- Logs redact tokens, codes, cookies, and sensitive query parameters.
- Website compatibility code, if added, stays optional and isolated.

## License

See [LICENSE](LICENSE).
