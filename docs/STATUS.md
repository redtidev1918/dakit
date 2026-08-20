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

1. Run representative live transfers for image, video, archive, literature, and
   restricted cases.
2. Add Dart, Android, macOS, and Windows CI jobs.

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
- Test suites: 59 passing
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
  `5ab1049ecc6d2193cbd757400f01abf293c5e775fab00cb1cfaa6317a0e1dc27`.
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
- OAuth and API clients now accept explicit environment, direct, or HTTP-proxy
  profiles while advanced hosts retain full Dio injection. Supplying conflicting
  transports is rejected rather than silently ignored.
- OAuth connection, timeout, and TLS failures remain typed network failures instead
  of being mislabeled as invalid authentication.
- `ConnectivityProbe` stops at the first DNS, TCP, TLS, or HTTP failure and returns
  a redacted report. The example runs it at startup and renders each stage with a
  manual retry control.
- A real network smoke test on this development machine passed all four stages via
  both `https_proxy=http://127.0.0.1:7892` and an explicit HTTP profile. Forced
  direct mode resolved DNS but timed out at TCP, proving route selection is not a
  cosmetic setting. A probe socket shutdown leak found by this test was fixed.
- The example now loads artwork detail on selection, resolves the dedicated
  original endpoint only for provider-downloadable work, and renders filename,
  media type, true byte size, availability, progress, speed, ETA, and local path.
- Native task records restore before login. Download scheduling and pause/resume/
  cancel controls reject concurrent taps, while late detail responses cannot
  overwrite a newer selection.
- API/OAuth and background-transfer proxy build defines are separate. The example
  explicitly clears a previously persisted native transfer proxy when no media
  proxy is configured.
- Preview-only behavior, stale-response suppression, task recovery, independent
  proxy configuration, enqueue/control mapping, and the detail UI are covered by
  tests. The complete 59-test gate and both local platform builds pass.
- The example UI is split into status, network, artwork, transfer, and diagnostic
  components; the executable is not a new monolithic widget or tied to a state
  management package.

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
