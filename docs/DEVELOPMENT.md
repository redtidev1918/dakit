# Development and network setup

## Pinned toolchain

The initial rewrite baseline was verified with:

```text
Flutter 3.47.1 stable, framework 6655482ec0
Engine 5d53178869
Dart 3.13.1
```

CI must use the same Flutter release. Local developers may install it through the
official archive or a trusted SDK manager.

## Mainland China

Different tools read different proxy variables. `curl` commonly accepts
`all_proxy`; Dart `HttpClient`, Flutter tooling, Gradle, and platform build tools may
not. Set only what the current command needs and do not commit a developer's proxy.

Example for a local HTTP proxy:

```shell
export all_proxy=http://127.0.0.1:7892
export http_proxy=http://127.0.0.1:7892
export https_proxy=http://127.0.0.1:7892
```

Clear all three variables when testing direct or system-proxy behavior.

Tsinghua TUNA currently documents these Flutter and Pub settings:

```shell
export FLUTTER_STORAGE_BASE_URL=https://mirrors.tuna.tsinghua.edu.cn/flutter
export PUB_HOSTED_URL=https://mirrors.tuna.tsinghua.edu.cn/dart-pub
```

The Git mirror is:

```text
https://mirrors.tuna.tsinghua.edu.cn/git/flutter-sdk.git
```

Mirror synchronization can lag a newly released Flutter engine. If an artifact URL
returns a tiny HTML response instead of a ZIP, unset `FLUTTER_STORAGE_BASE_URL` and
retry the official storage through `http_proxy`/`https_proxy`. Do not disable TLS
verification and do not combine partial archives from different URLs.

Pub mirrors may not expose the official package-advisory endpoint. Release and CI
security checks must also run against the official `https://pub.dev` service.

## Quality gate

```shell
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test packages/artrelay_core/test \
  packages/artrelay_api/test \
  packages/artrelay_flutter/test \
  apps/example_client/test
```

Live OAuth and API tests are opt-in because they require user interaction and must
never receive credentials in ordinary CI.

## Platform builds

The Android example follows Flutter 3.47.1 defaults: JDK 17, compile/target SDK
36, and NDK `28.2.13676358`. Verify the installed toolchain with `flutter doctor
-v`; local paths belong in Flutter configuration or `local.properties`, never in
tracked source.

```shell
cd apps/example_client
flutter build apk --debug
flutter build macos --debug
```

The Windows callback scheme is registered by the MSIX package:

```powershell
cd apps/example_client
flutter build windows
dart run msix:create
```

An unpackaged Windows debug executable cannot own a system URL protocol without
writing per-user registry state. ArtRelay deliberately leaves that state untouched;
use an MSIX smoke test in CI or install the generated package locally.
