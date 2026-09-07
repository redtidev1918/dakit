# Changelog

## [0.4.0](https://github.com/redtidev1918/dakit/compare/dakit_cli-v0.3.0...dakit_cli-vv0.4.0) (2026-09-07)


### Features

* add CLI home and recommended browse commands ([30f464a](https://github.com/redtidev1918/dakit/commit/30f464a73b231b9774495bb34dd924a1a200cd2f))
* add CLI verbose diagnostics and in-app debug console ([c10e617](https://github.com/redtidev1918/dakit/commit/c10e617a869b9f2a5426e69ac244af99480f124f))
* add pure Dart CLI client ([128e9be](https://github.com/redtidev1918/dakit/commit/128e9be290dbec6a910d12f34d8d4a4b74cb9c2e))
* **cli:** publish standalone DAKit binaries ([31873a8](https://github.com/redtidev1918/dakit/commit/31873a80865b4134c80b33e1d4ce822b5eda791b))
* **cli:** URL auto-detection, archive, filename templates, info-json sidecars ([aa4499c](https://github.com/redtidev1918/dakit/commit/aa4499ce59192cdb7023074db765d1aebc4545fa))
* expand CLI with artist/gallery/fav/search downloads ([b6d505e](https://github.com/redtidev1918/dakit/commit/b6d505e571ce3c7119bc1c38116edcb2cd976bfe))
* **web:** support DeviantArt web cookies for mature multi-image works ([5231553](https://github.com/redtidev1918/dakit/commit/52315530da445148d637aba80e96f1f6403088df))


### Bug Fixes

* _puppy/dadeviation/init requires type=art since 2026 ([8f1845f](https://github.com/redtidev1918/dakit/commit/8f1845faa565d2e8c833b18d35af1e4f059e98e5))
* **cli:** cross-compile Linux ARM64 release ([4772723](https://github.com/redtidev1918/dakit/commit/4772723931553c3fc1bfbe59348aed2a9c678b66))
* **test:** implement moveToSharedStorage in example_client fakes ([de96905](https://github.com/redtidev1918/dakit/commit/de9690521e72fadfe50e16e20d76abb83fd7d303))
* use whitelisted custom-scheme callback for CLI login ([1ce8c46](https://github.com/redtidev1918/dakit/commit/1ce8c4617877f3eb695bd977053a51e82e472017))

## 0.3.0

### Added

- Mature multi-image downloads: the `url` command now accepts a web cookie via
  `--cookies '<name>=value; …'`, `--cookies @path/to/file`, or the
  `DAKIT_COOKIES` environment variable. With a cookie, mature (age-restricted)
  multi-image works download every page via the website's `_puppy` endpoint
  (the OAuth API 404s them and omits attachments). Multi-page files are
  disambiguated with a `-pN` suffix; without a cookie the OAuth single-file
  path remains the fallback and a 404 points users to `--cookies`. Requires
  dakit_api >=0.2.0.

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
