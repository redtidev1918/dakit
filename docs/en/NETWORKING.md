# Networking, Proxies, and the China Development Environment

DAKit explicitly distinguishes three network paths: dependency downloads, OAuth/API inside Dart, and native background media transfer. They are handled by different tools, and setting a single `all_proxy` does not guarantee that all three paths take effect.

## OAuth and API

Pass the same `NetworkProfile` to OAuth and the official API:

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

Available modes:

- `NetworkProfile.environment()`: reads the Dart process's `http_proxy`, `https_proxy`, and `no_proxy`;
- `NetworkProfile.direct()`: forces a direct connection, for control/contrast diagnostics;
- `NetworkProfile.httpProxy(...)`: an explicit HTTP CONNECT proxy, with optional bypass hosts and in-memory Basic credentials;
- Custom Dio: for PAC, VPN SDKs, enterprise network stacks, certificate pinning, or test transports.

You cannot provide both a Dio and a `NetworkProfile`, otherwise the configuration intent is ambiguous. `environment` does not automatically read all system PAC/desktop proxies; mobile processes usually have no useful proxy environment variables either.

The system browser is a separate process; the sign-in web page uses the browser/OS's own network settings and is not controlled by the Dio configuration above. This explains the case where "the app's connectivity passes but the authorization page won't open."

## Media Transfer

Native background tasks do not necessarily go through the Dart HTTP stack and must be configured independently via `BackgroundTransferManager.configureProxy`. When disabling the proxy, pass `null` explicitly, otherwise the plugin's previously persisted configuration may still take effect. See the [media documentation](MEDIA.md) for details.

## Staged Diagnostics

`ConnectivityProbe` executes in order:

1. `dns`: resolves the actual next hop — the proxy host in proxy mode;
2. `connect`: establishes TCP to the next hop;
3. `tls`: establishes an HTTPS tunnel and validates the certificate against the system trust roots;
4. `http`: waits for any HTTP response; authentication and business permissions are judged separately.

The check stops at the first failing stage and returns a `ConnectivityReport`; it does not turn expected network failures into uncaught exceptions. Run a standalone probe:

```shell
dart run packages/dakit_api/example/connectivity.dart environment
dart run packages/dakit_api/example/connectivity.dart direct
dart run packages/dakit_api/example/connectivity.dart http 127.0.0.1 7892
```

Diagnostics record the route, stage, elapsed time, HTTP status, and stable error codes, but not proxy passwords, tokens, cookies, OAuth codes, or complete underlying exceptions.

## China Development Environment

A local HTTP proxy can be set with these commands:

```shell
export all_proxy=http://127.0.0.1:7892
export http_proxy=http://127.0.0.1:7892
export https_proxy=http://127.0.0.1:7892
```

`curl` usually reads `all_proxy`, Dart's `HttpClient` mainly reads `http_proxy`/`https_proxy`, and Flutter, Gradle, and the browser may each use different settings. When troubleshooting, record both "which path" and "which configuration"; do not attribute every failure to the proxy.

The [Tsinghua TUNA Flutter mirror help](https://mirrors.tuna.tsinghua.edu.cn/help/flutter/) provides the following Flutter/Pub configuration:

```shell
export FLUTTER_STORAGE_BASE_URL=https://mirrors.tuna.tsinghua.edu.cn/flutter
export PUB_HOSTED_URL=https://mirrors.tuna.tsinghua.edu.cn/dart-pub
```

Mirrors and proxies can coexist: the request first points to the mirror domain and is then forwarded by the proxy. However, mixing them adds variables, so it is recommended to validate one route at a time. Mirror sync may lag; when you download a tiny HTML error page, unset the mirror variables and access the official source through the proxy. Do not disable TLS or stitch together archives from different sources.

Pub mirrors may also lack the official security advisory endpoint. Release and dependency security checks should run at least once more against the official `https://pub.dev`. Before committing `pubspec.lock`, confirm the hosted source has not been permanently rewritten by a temporary mirror.

## Android Addresses

In the Android emulator, `127.0.0.1` refers to the emulator itself. To reach the development machine, use `10.0.2.2`; physical devices use a LAN-reachable address. Both the API proxy and the media proxy must be changed to addresses the device can reach, and the local proxy software must allow the corresponding listening scope.
