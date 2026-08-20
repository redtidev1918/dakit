# Rewrite status

This file is the hand-off point after an interrupted session. Update it in the
same commit as every material milestone.

## Current state

- Phase: M0 — recoverable baseline
- Branch: `main`
- Last stable legacy tag: `python-preview-1.0.0a1`
- Legacy remote: `legacy-origin`
- Target runtime: stable Flutter/Dart
- Target platforms: Android first, then macOS and Windows
- Workspace health: Python preview remains runnable until the Flutter skeleton is green

## Next actions

1. Install Flutter stable and record exact `flutter --version` output.
2. Create the three packages and example app without deleting the Python files.
3. Add workspace-wide analysis and test commands.
4. Commit the green skeleton.
5. Only then remove the Python implementation in a separate commit.

## Decisions already made

- Flutter/Dart is the primary runtime.
- Rust/UniFFI is deferred until a real non-Flutter native consumer exists.
- OAuth uses external browser + PKCE + operating-system deep link.
- The SDK does not bundle or accept a client secret for public clients.
- Host applications supply client ID, redirect URI, scopes, storage, and optional transport overrides.
- The SDK is independent of Riverpod/Bloc and concrete databases.
- Official API and optional website compatibility code must remain separate.

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

