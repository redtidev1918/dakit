# DAKit Documentation

This is the documentation index for DAKit. The user-facing overview, install,
and command-line usage live in the root [README](../../README.en.md); the files
in this directory go deeper by topic. The primary-language version is
[中文索引](../README.md).

## User guide

For developers embedding DAKit into their own apps:

- [Getting started](GETTING_STARTED.md) — register an OAuth app, run the example
  client, embed the SDK in your own Flutter app;
- [Authentication and sessions](AUTHENTICATION.md) — Authorization Code + PKCE,
  platform callbacks, secure storage, troubleshooting;
- [Networking, proxies, and the China development environment](NETWORKING.md) —
  the three network paths, the proxy model, staged diagnostics;
- [Media, text content, and background transfer](MEDIA.md) — preview vs. original
  files, text content, background download tasks.

## Development & maintenance

For contributors and maintainers:

- [Architecture and extension boundaries](ARCHITECTURE.md) — package layering,
  per-layer responsibilities, extension points, upstream change strategy;
- [Development, building, and releasing](DEVELOPMENT.md) — pinned toolchain,
  daily verification, three-platform builds, CI;
- [Releasing DAKit packages](RELEASING.md) — publishing the CLI binaries and the
  pub.dev packages;
- [Live service testing](LIVE_TESTING.md) — the full media acceptance matrix
  that requires user authorization;
- [Project status](STATUS.md) — verified results and next steps.

## Conventions

- The primary documentation language is Chinese; the English copy lives in
  `docs/en/` and stays in sync with the Chinese version;
- User-facing copy follows the bilingual convention of the root READMEs;
- Each document describes current behavior only; history lives in each package's
  `CHANGELOG.md`.
