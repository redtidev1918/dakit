# Project Status and Continuation Notes

This file records only the verifiable current state and next steps, to avoid mixing historical development logs into user documentation. Each important milestone is updated together with the same commit.

## Current Status

- Branch: `main`; remote: `https://github.com/redtidev1918/dakit.git`;
- Product name: DAKit — DeviantArt Client SDK;
- Version stage: `dakit_core` 0.1.5, `dakit_api` 0.1.8, and `dakit_flutter` 0.1.3, all published to pub.dev;
- Runtime: Flutter 3.47.1 / Dart 3.13.1;
- Platforms: Android, macOS, Windows/MSIX;
- Tests: formatting and analysis pass, 100 tests pass;
- Local builds: Android debug APK and macOS debug app pass;
- CI: the Linux quality gate and the four Android/macOS/Windows jobs pass;
- Package publishing: `dakit_core` 0.1.5, `dakit_api` 0.1.8, and `dakit_flutter` 0.1.3 have been successfully uploaded to pub.dev (verified via both paths: GitHub Actions OIDC automated publishing and local manual publishing);
- Dependency policy: the major upgrade of `flutter_secure_storage` is being ignored until the Android toolchain supports `compileSdk 37` (v11 is incompatible with the current Android API 36 / AGP 9.1.0);
- Not done: the five-category real media matrix under a valid Public OAuth application.

Full CI covers the Linux quality gate (analyze / format / test) and the Android APK, macOS app, and Windows/MSIX builds. The quality gate previously failed because the example_client test fakes did not implement `TransferManager.moveToSharedStorage` added in `dakit_core` 0.1.5; those fakes have been filled in, and all 100 tests pass locally.

## Implemented Scope

- Layered domain models, repositories, pagination, errors, diagnostics, and transport contracts;
- Public Client Authorization Code + S256 PKCE;
- Secure storage of pending transactions/tokens, cold-start callback, concurrent authorization merging, and serial refresh;
- Account, full user profile and statistics, friend/watcher lists, watch status, friend search, and batch user queries;
- Deviation details/body, home/search, daily deviations, watch feed, tag autocomplete and browsing, topic navigation;
- Gallery and favourites folders and their contents, optional folder deviation prefetch, and original file metadata;
- Reading/posting deviation comments, favouriting/unfavouriting, watching/unwatching, and centrally maintained OAuth scope constants;
- Notification/feedback message streams, mentions, stack expansion, and explicit deletion;
- A unified authenticated form mutation transport; POST replays only after a 401 refresh and does not automatically repeat non-idempotent operations on 429/5xx;
- Environment/direct/explicit HTTP proxies, custom Dio, and DNS/TCP/TLS/HTTP probes;
- Original file availability classification without passing preview off as original; `MediaAsset.availabilityReason` passes through the provider's rejection reason (distinguishing "downloads disabled by the author" from "free quota exhausted");
- Flutter background task resume, progress, retry, pause/resume/cancel, and independent proxy;
- Chinese/English example client and a sanitized diagnostics panel;
- Pure Dart `dakit_cli`: loopback OAuth login, batch download for a single deviation/artist/gallery/favourites/search, account queries, and connectivity diagnostics;
- CLI `--verbose` sanitized diagnostics output, and a built-in Debug console in the example client;
- Android custom scheme, macOS URL type, and Windows MSIX protocol activation;
- MIT licenses for the three packages, package README/changelog, and publishable archives.
- refresh/logout/token exchange have a generation guard, so late operations cannot restore a session after logout; actively cancelling a login ends the callback wait immediately.

## Verified Login Path

Verified on macOS: securely saving the pending state → launching the system browser → OS callback → DNS/TCP/TLS/HTTP. The provider then returned `oauth.provider.invalid_client`. The developer credentials provided at the time included a `client_secret`, indicating a Confidential registration was used; DAKit by design does not compile that secret into the client.

The next real login must create a new Public application, allowlist exactly `dakit://oauth/callback`, and provide only the `client_id` to the client. Access/refresh tokens must still be kept secret.

## Next Steps

1. Complete a system-browser login using a valid Public application;
2. Prepare the five categories of UUIDs — image, video, archive, literature, and restricted — following [LIVE_TESTING.md](LIVE_TESTING.md);
3. Run the full streaming download and SHA-256 acceptance;
4. Add contract tests based on real provider responses, and update this document.

## Resuming After Interruption

```shell
git status --short --branch
git log --oneline --decorate -5
flutter --version
./tool/verify.sh
```

First read the root [README](../../README.md) and this document. Do not restore the old Python implementation; the historical preview is kept only in the Git tag `python-preview-1.0.0a1`. Do not add real account credentials to the regular CI or the repository.
