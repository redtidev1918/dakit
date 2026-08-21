# Contributing to DAKit

DAKit is a modular DeviantArt SDK for Dart & Flutter. Contributions are welcome
— fixes, new endpoints, tests, docs, and diagnostics.

## Repository layout

```
packages/
  dakit_core     Domain models, repository/transfer contracts, pagination
  dakit_api      OAuth PKCE, network config, official API implementation
  dakit_flutter  System browser, deep links, secure storage, transfers
  dakit_cli      Pure-Dart CLI for login/download/diagnostics
apps/
  example_client Reference Flutter app
```

The dependency direction is fixed: `dakit_flutter → dakit_api → dakit_core`.
Business apps depend only on the layer they need.

## Before you start

- Search existing issues/PRs first.
- SDK changes must not expose upstream DTOs, plugin types, or a specific state
  management framework as public API.
- For security issues see [SECURITY.md](SECURITY.md) — do not file publicly.

## Development

1. Install Flutter 3.47.1 / Dart 3.13.1.
2. `dart pub get` in the workspace root.
3. Run the quality gate: `./tool/verify.sh` (analyze + tests).

## Workflow

1. Fork and branch from `main`.
2. Make a focused change; add/update tests.
3. `./tool/verify.sh` must pass.
4. Open a PR explaining what and why.

## Releasing

Package versions and pub.dev publishing are handled per
[docs/RELEASING.md](docs/RELEASING.md). Dependency order matters:
`dakit_core` → `dakit_api` → `dakit_flutter`.
