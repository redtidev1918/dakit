# Rewrite status

This file is the hand-off point after an interrupted session. Update it in the
same commit as every material milestone.

## Current state

- Phase: M2 — platform integration
- Branch: `main`
- Last stable legacy tag: `python-preview-1.0.0a1`
- Legacy remote: `legacy-origin`
- Target runtime: stable Flutter/Dart
- Target platforms: Android first, then macOS and Windows
- Workspace health: four-member Flutter workspace is green; Python preview removed from main

## Next actions

1. Add API proxy selection and staged DNS/connect/TLS/HTTP diagnostics.
2. Add artwork detail and transfer controls to the example client.
3. Run representative live transfers for image, video, archive, literature, and
   restricted cases.
4. Add Dart, Android, macOS, and Windows CI jobs.

## Decisions already made

- Flutter/Dart is the primary runtime.
- Rust/UniFFI is deferred until a real non-Flutter native consumer exists.
- OAuth uses external browser + PKCE + operating-system deep link.
- The SDK does not bundle or accept a client secret for public clients.
- Host applications supply client ID, redirect URI, scopes, storage, and optional transport overrides.
- The SDK is independent of Riverpod/Bloc and concrete databases.
- Official API and optional website compatibility code must remain separate.

## Verified baseline

- Flutter 3.47.1 stable (`6655482ec0`)
- Engine `5d53178869`
- Dart 3.13.1
- `flutter analyze`: no issues
- Test suites: 36 passing
- Local builds: Android debug APK and macOS debug application succeed

## Latest milestone

- Official account, artwork, home browse/search, gallery, favourites, and original
  media repositories map API responses into core domain objects.
- Page offsets are validated; gallery and collection requests honor the provider's
  current maximum of 24 results.
- Preview/content/video assets remain previews. The transferable original is only
  produced by the dedicated download-metadata endpoint.
- DTO mapping ignores additive upstream fields and raises a typed parsing failure
  when a required domain field disappears.
- Fixtures follow the official OpenAPI 3.1 definitions published with API version
  `1.20240701`; no live account data or credentials are checked in.
- OAuth authorization now subscribes before browser launch, coalesces concurrent
  attempts, persists PKCE state, restores cold-start callbacks, and emits separate
  launch/callback/token/storage diagnostics.
- `ArtRelayOAuthClient` wires mature browser, deep-link, secure-storage, and HTTP
  adapters while preserving replaceable boundaries for advanced clients.
- The example registers `artrelay://oauth/callback` on Android and macOS. Windows
  forwards a callback to the existing instance and registers the protocol through
  its MSIX manifest.
- Verified Android APK SHA-256 on this machine:
  `c2fc8f4ba217ea3e169bbb05b044ef136e6862d6eea96b389f9d1198aacbde9b`.
- Startup restoration no longer waits for a callback when the app was opened
  normally, and a previous initial link cannot poison a new authorization attempt.
- The generated counter was replaced by a responsive integration client with
  explicit configuration, authorization, loading, connected, and failure states.
  It automatically loads the account and home feed after a successful callback and
  renders the most recent structured diagnostics without sensitive values.
- `BackgroundTransferManager` now maps the maintained native transfer plugin into
  stable core contracts with persisted recovery, expected size, progress, retry,
  pause/resume/cancel, safe filenames, and explicit transfer-proxy clearing.
- Android and macOS still build after adding the native transfer plugin. Both macOS
  entitlement files now include outbound network permission; without it, sandboxed
  OAuth, API, and media requests would fail despite a successful build.

## Known external requirements

- The developer application redirect whitelist must exactly contain the redirect URI used by the example app.
- Android and Windows release builds require their native build toolchains or CI runners.
- Live tests require user authorization and must not run in ordinary CI.

## Resume command checklist

```shell
git status --short --branch
git log --oneline --decorate -5
flutter --version
dart analyze
dart test
```

If Flutter packages already exist, read this file and `docs/MIGRATION.md` before editing.
