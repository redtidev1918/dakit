# OAuth integration

ArtRelay uses the public-client Authorization Code flow with an S256 PKCE
challenge. A Flutter, Android, macOS, or Windows client must never contain a
client secret.

## Provider application

Register the application as a **Public** client and add the exact redirect URI:

```text
artrelay://oauth/callback
```

Scheme, host, path, case, and trailing slash must match. The example application
registers this URI on Android and macOS; its Windows MSIX manifest registers the
`artrelay` scheme.

## Flutter setup

Create the OAuth client before `runApp` so the deep-link plugin can observe a
cold-start callback. Supply the client ID at build or runtime; do not commit a
developer account value.

```dart
final network = NetworkProfile.environment();
final oauth = ArtRelayOAuthClient(
  config: OAuthConfig(
    clientId: clientId,
    redirectUri: Uri.parse('artrelay://oauth/callback'),
  ),
  networkProfile: network,
  diagnostics: diagnostics,
);

runApp(MyApp(oauth: oauth));
await oauth.resumePending(); // Update application state if tokens are returned.
```

Start an interactive authorization only from an explicit user action:

```dart
final tokens = await oauth.authorize();
```

The coordinator performs these steps in order:

1. Generate state, verifier, and S256 challenge.
2. Persist the pending transaction in platform secure storage.
3. Subscribe to callbacks before opening the system browser.
4. Validate the exact redirect, expiry, and state.
5. Exchange the code without a client secret.
6. Persist access and refresh tokens, then clear the pending transaction.

Concurrent calls share one authorization operation. Startup recovery returns
immediately when the process was not opened by an OAuth callback, so stale pending
state cannot hold the first frame. A process terminated while the browser is open
can resume from secure storage. Callback timeouts, provider
denials, browser launch failures, token failures, and storage failures have
different diagnostic stages and error codes.

## Platform notes

- Android uses a browsable `singleTop` activity intent filter and disables
  Flutter's competing default deep-link handler.
- macOS declares `CFBundleURLTypes` and uses Flutter's Swift Package Manager
  plugin integration.
- Windows forwards callbacks to an existing process through `app_links`; the
  scheme is registered by the packaged MSIX manifest. An unpackaged debug EXE
  is not registered globally by design.

The host may replace the browser launcher, callback source, token store, pending
transaction store, OAuth endpoint, and diagnostic sink through constructor
arguments. This keeps the SDK usable in clients with their own platform layer.
OAuth endpoint network failures remain network failures rather than being mislabeled
as rejected credentials. Proxy selection and staged connectivity checks are covered
in [NETWORKING.md](NETWORKING.md).
