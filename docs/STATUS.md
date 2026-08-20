# Rewrite status

This file is the hand-off point after an interrupted session. Update it in the
same commit as every material milestone.

## Current state

- Phase: M1 — core and official API
- Branch: `main`
- Last stable legacy tag: `python-preview-1.0.0a1`
- Legacy remote: `legacy-origin`
- Target runtime: stable Flutter/Dart
- Target platforms: Android first, then macOS and Windows
- Workspace health: four-member Flutter workspace is green; Python preview removed from main

## Next actions

1. Implement token exchange, refresh coordination, redaction, and Dio transport.
2. Add official API DTO fixtures and repository adapters.
3. Configure the example app custom-scheme callback on all three platforms.
4. Replace the generated counter screen with an integration diagnostics client.
5. Add Dart, Android, macOS, and Windows CI jobs.

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
- Test suites: 8 passing

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
