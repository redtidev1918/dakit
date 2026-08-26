# Changelog

## 0.2.2

### Added

- `dakit url` accepts any DeviantArt link and auto-detects the target
  (artwork/journal pages, fav.me short links, user galleries,
  gallery/favourites folders, tag pages, search URLs), routing to the right
  downloader like gallery-dl. Numeric artwork ids from web URLs are resolved to
  UUIDs through the website's public `dadeviation/init` endpoint.
- `--archive FILE`: an id-per-line archive of already-downloaded deviations;
  re-runs skip archived items and append new ones after a successful download.
- `--filename TEMPLATE`: filename template with `{id}`, `{title}`,
  `{username}`, `{published}`, `{filename}`, `{ext}` tokens.
- `--write-info-json`: writes a metadata `.json` sidecar next to each download.

## 0.2.1

### Fixed

- Build Linux ARM64 from the supported x64 Flutter toolchain with Dart's
  official cross-compiler, and validate the resulting ELF architecture. The
  `0.2.0` source tag produced no GitHub Release because Flutter 3.47.1 has no
  Linux ARM64 SDK archive; this is the first downloadable binary release and
  includes all `0.2.0` changes below.

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
