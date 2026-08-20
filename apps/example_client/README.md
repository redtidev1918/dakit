# ArtRelay example client

This application is an integration and diagnostics client, not a production UI.
It proves that a host can consume the public Flutter facade without accessing
private DTOs or platform implementation details.

Register `artrelay://oauth/callback` exactly on a Public OAuth application, then
run without committing the client ID:

```shell
flutter run -d macos \
  --dart-define=ARTRELAY_CLIENT_ID=YOUR_PUBLIC_CLIENT_ID
```

The same define can be supplied to `flutter build apk` or `flutter build windows`.
The app displays distinct configuration, session restore, browser callback, API,
parsing, storage, and unexpected failure states. Its diagnostic list contains no
tokens, authorization codes, cookies, or PKCE secrets.

It also runs a DNS, TCP, TLS, and HTTP check at startup. To use a local desktop
HTTP proxy explicitly:

```shell
flutter run -d macos \
  --dart-define=ARTRELAY_CLIENT_ID=YOUR_PUBLIC_CLIENT_ID \
  --dart-define=ARTRELAY_PROXY_MODE=http \
  --dart-define=ARTRELAY_PROXY_HOST=127.0.0.1 \
  --dart-define=ARTRELAY_PROXY_PORT=7892
```

Use `ARTRELAY_PROXY_MODE=direct` to prove direct behavior. Android emulators use
`10.0.2.2`, not `127.0.0.1`, to reach a proxy on the development computer. Full
profile and diagnostic semantics are in `docs/NETWORKING.md`.

Build-only smoke tests do not require an OAuth application:

```shell
flutter build macos --debug
flutter build apk --debug
```
