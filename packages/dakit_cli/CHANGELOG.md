# Changelog

## 0.2.0

### Added

- Standalone Linux x64/ARM64, macOS Intel/Apple Silicon, and Windows x64
  binaries published from the `dakit_cli-v*` release pipeline;
- Default loopback OAuth login, optional manual/headless login, remote token
  revocation, and automatic access-token refresh;
- Explicit `--overwrite`, `--no-open`, `--manual`, `logout`, and global
  `--version` controls;
- Direct HTTP proxy URL and `all_proxy` / `ALL_PROXY` support.

### Changed

- Stream large downloads to a temporary file instead of buffering an entire
  image or video in memory;
- Preserve existing downloads unless `--overwrite` is supplied;
- Return stable process exit codes and show command-specific help;
- Include provider reasons when an original file is unavailable.

### Fixed

- Preserve the first word of multi-word search queries;
- Accept `--delay 0` while rejecting malformed numeric options;
- Avoid shell interpretation when opening OAuth URLs on Windows;
- Report malformed local credentials as actionable configuration failures.

## 0.1.0

### Added

- Pure-Dart CLI for loopback OAuth sign-in, account queries, and connectivity diagnostics;
- Batch download for single deviations, artist galleries, folders, favourites, and search results;
- `--verbose` sanitized diagnostics output, with `dakit` and `devart-dl` executable names.
