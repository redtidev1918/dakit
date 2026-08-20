# Continuous integration

`.github/workflows/ci.yml` pins Flutter `3.47.1` and runs on pushes to `main`, pull
requests, and manual dispatches.

## Jobs

- **Analyze and test** runs the same `tool/verify.sh` gate used locally.
- **Android debug APK** uses the maintained Android SDK setup action to install
  API 36, Build Tools 36, NDK `28.2.13676358`, and JDK 17 before uploading the
  APK. It does not assume that a hosted runner exposes `sdkmanager` on `PATH`.
- **macOS debug app** compiles the native application on a macOS runner and
  uploads the `.app` smoke-test artifact.
- **Windows app and MSIX** compiles the release runner, packages the registered
  `artrelay` callback protocol, and uploads both unpackaged files and a development
  MSIX.

The platform builds depend on the quality job, so broken contracts do not consume
three full build runners. Concurrency cancels an obsolete run for the same branch.
Dependency caching is isolated per operating system by the Flutter setup action.

## Security and release boundary

Ordinary CI contains no OAuth client ID, client secret, access token, refresh token,
proxy password, or signing credential. Live provider tests remain opt-in and must
use an explicitly authorized environment.

Uploaded APK, macOS, and Windows artifacts are integration smoke builds, not store
releases. The MSIX package uses the packaging tool's development certificate and
does not install that certificate on the runner. Production distribution requires
the host application's own identities, signing keys, store metadata, and protected
release workflow.

CI uses official Flutter and Pub endpoints. Mainland mirror configuration remains a
local developer choice and cannot rewrite the repository lockfile in CI.
