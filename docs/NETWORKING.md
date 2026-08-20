# Networking, proxies, and connectivity diagnostics

DAKit makes the route for OAuth and official API traffic explicit. It never
silently disables TLS validation and never assumes that a desktop operating-system
proxy is visible to Dart.

## API and OAuth profiles

Choose one profile and pass it to both clients:

```dart
final network = NetworkProfile.httpProxy(
  proxyServer: HttpProxyServer(host: '127.0.0.1', port: 7892),
  bypassHosts: const <String>{'localhost'},
);

final oauth = DAKitOAuthClient(
  config: oauthConfig,
  networkProfile: network,
  diagnostics: diagnostics,
);

final api = OfficialApiClient(
  session: oauth.session,
  networkProfile: network,
  diagnostics: diagnostics,
);
```

The available modes are:

- `NetworkProfile.environment()` reads Dart's `http_proxy`, `https_proxy`, and
  `no_proxy` process variables.
- `NetworkProfile.direct()` forces `DIRECT`, even when proxy variables exist.
- `NetworkProfile.httpProxy(...)` uses one explicit HTTP CONNECT proxy with an
  optional hostname bypass list and optional in-memory Basic credentials.

`environment` does not mean automatic PAC or desktop-settings discovery. Mobile
applications normally have no useful proxy environment. A host that needs a
platform networking stack, VPN SDK, enterprise PAC resolver, certificate pinning,
or mock transport should inject its own configured `Dio` instance. Supplying both
a Dio instance and a network profile is rejected instead of ignoring one.

Proxy credentials are redacted by `toString` and never placed in diagnostic
attributes. A host that persists them must use its platform secure-storage layer.

## Media traffic is independent

OAuth/API routing and native background-transfer routing are separate on purpose.
Changing one does not silently reroute the other. Configure media transfers through
`BackgroundTransferManager.configureProxy`; see [TRANSFERS.md](TRANSFERS.md).

## Staged diagnostics

`ConnectivityProbe` executes and reports four ordered stages:

1. `dns` resolves the actual next hop—the proxy host when proxied, otherwise the
   service host.
2. `connect` opens a TCP connection to that next hop.
3. `tls` creates the HTTPS tunnel and validates the service certificate using the
   platform trust roots.
4. `http` waits for an HTTP response. Any status proves transport reachability;
   authentication and provider authorization are diagnosed separately.

The probe stops at the first failure and returns `ConnectivityReport`; expected
connectivity failures do not crash the host. Events contain stage, stable code,
elapsed time, route type, and status where available. They do not contain proxy
passwords, tokens, OAuth codes, cookies, or exception messages.

Run the standalone probe from the workspace:

```shell
dart run packages/dakit_api/example/connectivity.dart environment
dart run packages/dakit_api/example/connectivity.dart direct
dart run packages/dakit_api/example/connectivity.dart http 127.0.0.1 7892
```

## Example-client build defines

The example defaults to `environment`. Explicit direct mode:

```shell
flutter run -d macos \
  --dart-define=DAKIT_CLIENT_ID=YOUR_PUBLIC_CLIENT_ID \
  --dart-define=DAKIT_PROXY_MODE=direct
```

Explicit local HTTP proxy:

```shell
flutter run -d macos \
  --dart-define=DAKIT_CLIENT_ID=YOUR_PUBLIC_CLIENT_ID \
  --dart-define=DAKIT_PROXY_MODE=http \
  --dart-define=DAKIT_PROXY_HOST=127.0.0.1 \
  --dart-define=DAKIT_PROXY_PORT=7892
```

`127.0.0.1` on Android is the Android device, not the development computer. Use
`10.0.2.2` for the standard Android emulator or a reachable LAN address for a
physical device. Do not embed authenticated proxy passwords in `--dart-define`.

Media transfer defines are deliberately separate:

```shell
--dart-define=DAKIT_TRANSFER_PROXY_HOST=127.0.0.1 \
--dart-define=DAKIT_TRANSFER_PROXY_PORT=7892
```

When these are absent, the example explicitly clears any native transfer proxy
persisted by an earlier run. Providing only a host or only a port is a visible
configuration error. Use `10.0.2.2` for both proxy hosts on an Android emulator.

The example runs the four-stage check at startup and exposes a **Run check** button.
An invalid mode, host, or port produces a visible configuration error rather than a
blank screen or an ignored fallback.
