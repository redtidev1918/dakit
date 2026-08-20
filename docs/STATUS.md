# Rewrite status

This file is the hand-off point after an interrupted session. Update it in the
same commit as every material milestone.

## Current state

- Phase: M3 — live provider verification
- Branch: `main`
- Last stable legacy tag: `python-preview-1.0.0a1`
- Legacy remote: `legacy-origin`
- Target runtime: stable Flutter/Dart
- Target platforms: Android first, then macOS and Windows
- Workspace health: four-member Flutter workspace is green; Python preview removed from main

## Next actions

1. Run representative live transfers for image, video, archive, literature, and
   restricted cases with `docs/LIVE_TESTING.md`; do not commit the access token or
   signed media URLs.

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
- Test suites: 69 passing
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
- `DAKitOAuthClient` wires mature browser, deep-link, secure-storage, and HTTP
  adapters while preserving replaceable boundaries for advanced clients.
- The example registers `dakit://oauth/callback` on Android and macOS. Windows
  forwards a callback to the existing instance and registers the protocol through
  its MSIX manifest.
- Verified renamed Android APK SHA-256 on this machine:
  `eb34fee98cbf359d7bfa01e6e77a40d8e3b77526e9b50f3f493e4370b7edda96`.
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
- Secure OAuth state and tokens use macOS Keychain without opting into the Data
  Protection Keychain. This fixes the pre-browser storage failure without adding
  the Keychain Sharing entitlement, which would require an Apple provisioning
  profile and break unsigned local and CI builds. Hosts may still inject a custom
  secure-storage policy.
- The example follows the host system language for English and Simplified Chinese.
  User-facing failures use localized explanations and retain stable diagnostic
  codes; safe native storage status fields are visible while secret-bearing fields
  remain filtered.
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
  tests. The complete 65-test gate and both local platform builds pass.
- The example UI is split into status, network, artwork, transfer, and diagnostic
  components; the executable is not a new monolithic widget or tied to a state
  management package.
- GitHub Actions now defines a credential-free quality job plus Android, macOS, and
  Windows/MSIX build jobs pinned to Flutter 3.47.1. Platform artifacts are smoke
  builds, not implicitly trusted releases; provider live tests remain opt-in.
- Hosted CI run [`32357369309`](https://github.com/redtidev1918/dakit/actions/runs/32357369309)
  passed all four jobs on their real GitHub runners: the 59-test quality gate,
  Android APK, macOS application, Windows application/protocol-enabled MSIX, and
  all artifact uploads. The preceding run exposed that the Ubuntu runner did not
  publish `sdkmanager` on `PATH`; Android SDK discovery, license handling, and
  pinned component installation now use `android-actions/setup-android`. Artifact
  upload uses its Node 24 release without the earlier deprecation warning.
- OAuth token exchange now sends a genuine URL-encoded form. A loopback wire test
  caught and prevents the previous mismatch where a Dio multipart object was paired
  with a form content type, which could make a successful browser callback fail at
  the token endpoint.
- Artwork detail requests expand structured full text. The dedicated content
  repository returns literature HTML, CSS, fonts, and editing markup as inert data;
  no provider content is executed by the SDK.
- Original media now distinguishes available, login-required, purchase-required,
  restricted, unavailable, and missing states. Expected provider denials never
  invent a preview URL, while network, throttling, and parsing failures still throw
  typed exceptions.
- API transport now consumes the platform-neutral `AuthTokenProvider` contract
  instead of a concrete OAuth session, removing authentication/persistence coupling
  for embedding hosts.
- The opt-in live verifier requires the complete image/video/archive/literature/
  restricted matrix by default, performs staged connectivity and account checks,
  streams full allowed files, verifies byte counts and SHA-256, and writes a
  redacted JSON report. It is documented but has not yet been run with a real token
  and representative UUIDs.
- A safe invalid-token smoke run reached the real service through the environment
  proxy, passed DNS/TCP/TLS/HTTP stages, classified the API response as
  `api.provider.invalid_token`, wrote a redacted report, and exposed no token or
  signed URL. This proves diagnostics and credential handling, not the media matrix.
- Product, package, public API, callback scheme, environment variables, native
  identifiers, User-Agent values, tests, and documentation are now consistently
  named `DAKit — DeviantArt Client SDK`, `dakit_*`, and `dakit://`. No `ArtRelay`
  identifier remains in the working tree.
- A real macOS authorization run with client `75380` passed secure pending-state
  persistence, system-browser launch, operating-system callback delivery, and all
  four connectivity stages. It then failed at the provider token exchange with
  `oauth.provider.invalid_client`, not storage. The supplied credentials included a
  client secret, which according to current provider documentation identifies a
  Confidential registration; the example intentionally requires a Public client
  and never embeds that secret.
- All three packages now carry consistent MIT license files. Clean-commit
  publication dry-runs build valid archives and pass with zero warnings for
  `dakit_core`, `dakit_api`, and `dakit_flutter`.

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
