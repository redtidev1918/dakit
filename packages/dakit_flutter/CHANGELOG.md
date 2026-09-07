# Changelog

## [1.0.0](https://github.com/redtidev1918/dakit/compare/dakit_flutter-vv0.1.13...dakit_flutter-vv1.0.0) (2026-09-07)


### ⚠ BREAKING CHANGES

* rename the SDK to DAKit

### Features

* add comments and social API mutations ([daf5cdf](https://github.com/redtidev1918/dakit/commit/daf5cdfd1ba29c411038267d568c922bf14df145))
* add pub.dev topics for search discoverability ([b882632](https://github.com/redtidev1918/dakit/commit/b882632816322f287e4a0767de1b76ca7f8c374c))
* **flutter:** add clientSecureStorage() for friendly macOS keychain naming ([b9bcff9](https://github.com/redtidev1918/dakit/commit/b9bcff9d4a6e4c2bf01f1aff240b5acc5b0e8369))
* **transfer:** add TransferManager.remove to clear finished records ([9e596dd](https://github.com/redtidev1918/dakit/commit/9e596ddf16cb0a9d44e3c05efb5a9f895ecba078))
* **transfer:** move completed downloads into shared storage ([602f0f6](https://github.com/redtidev1918/dakit/commit/602f0f6aa5eb4d450baee42b037e48619876935b))
* **widgets:** add MasonryGridView / SliverMasonryGrid (waterfall layout) ([874f7df](https://github.com/redtidev1918/dakit/commit/874f7dfa6632c6a55a6f626c4ac612a4685f24c1))


### Bug Fixes

* **deps:** release Flutter adapter for DAKit 0.2 ([60ec841](https://github.com/redtidev1918/dakit/commit/60ec841094979eb94b6af7f88aee869945904aae))
* **flutter:** keep app-readable copy when moving to shared storage on Android ([cb2ccf8](https://github.com/redtidev1918/dakit/commit/cb2ccf828aec0e5b50a4e2a78603663ee538f5cf))
* **flutter:** logout continues past pending-store clear failure ([d6a8d88](https://github.com/redtidev1918/dakit/commit/d6a8d886135bba25c54549ed0659c9f3e048b58f))
* **flutter:** never auto-delete the OAuth token on Android ([ccf95a0](https://github.com/redtidev1918/dakit/commit/ccf95a071f1d3b1cf5897faf51b0528826f7fe16))
* **flutter:** persist moved shared-storage paths across restarts ([8e00235](https://github.com/redtidev1918/dakit/commit/8e00235157e73ca029d348928ae65df2fe8a6e2c))
* harden related results and destructive transfer removal ([7567ea6](https://github.com/redtidev1918/dakit/commit/7567ea639096543983601afc3fd42adba33eed5b))
* make OAuth logout and cancellation race-safe ([6c0ce55](https://github.com/redtidev1918/dakit/commit/6c0ce5525a2945b93e090eea15e40048108e1fab))
* **release:** align dakit_flutter constraints to ^0.2.0 for workspace publish ([b93927c](https://github.com/redtidev1918/dakit/commit/b93927cb208d388ecdf3198a5f00e8994f3dfff8))
* satisfy formatter and typed task paths ([244e00e](https://github.com/redtidev1918/dakit/commit/244e00e31d25bfc9b16e74c6fa05fcaead7f4885))
* **transfer:** remove() deletes the downloaded file ([c8eded5](https://github.com/redtidev1918/dakit/commit/c8eded56accb641953f6625b20def38de5742e95))


### Code Refactoring

* rename the SDK to DAKit ([a9f0837](https://github.com/redtidev1918/dakit/commit/a9f0837f22ad1128c4587998ba0c0d11103462f0))

## 0.1.13

- Update DAKit API and Core dependencies to the released 0.2.x series.

## 0.1.12

### Docs

- Publish pub.dev topics (`deviantart`, `deviantart-api`, `oauth`, `pkce`,
  `downloader`, …) so the package is discoverable in pub.dev search.

## 0.1.11


### Docs

- Modernized the package README: pub.dev badges, install snippet, and
  documentation links.

## 0.1.10

### Fixed

- `clientSecureStorage` disables Android `resetOnError`: the plugin default
  deletes a stored value on any decryption failure, which silently wiped the
  OAuth token after a restart and forced a re-login. The token now survives a
  transient Keystore/decrypt error and the next launch retries the read.

## 0.1.9

### Fixed

- `BackgroundTransferManager.moveToSharedStorage` on Android keeps the
  app-readable private copy while still exposing the shared copy, so in-app
  previews keep working under scoped storage (a file moved into public
  Downloads via MediaStore is not readable back by the app).

## 0.1.8

### Fixed

- `BackgroundTransferManager.remove` now deletes unique known file paths before
  removing the persisted record. File/path failures throw retryable typed
  storage errors and retain metadata, preventing silent orphan files.

## 0.1.7

### Added

- `clientSecureStorage(serviceName:)` — builds a Keychain-backed
  `FlutterSecureStorage` whose macOS keychain item is labelled with a
  user-facing product name (instead of the plugin default
  `flutter_secure_storage_service`), so macOS's authorization prompt no longer
  reads like the host is reaching for arbitrary secrets. Keeps
  `usesDataProtectionKeychain: false` so unsigned builds still work.

## 0.1.6

### Changed

- `BackgroundTransferManager.remove` now also deletes the downloaded file (both the moved shared-storage copy and the app-private original), not just the persisted record.

## 0.1.5

### Added

- `MasonryGridView` / `SliverMasonryGrid` — a lazy, balanced masonry (waterfall) layout for variable-height grid content (e.g. image galleries).

## 0.1.4

### Added

- `BackgroundTransferManager.remove` added finished-transfer cleanup. Its
  original record-only behavior was superseded by destructive removal in
  0.1.6 and fail-closed removal in 0.1.8.

## 0.1.3

### Fixed

- Persist moved shared-storage paths (`moveToSharedStorage`) so the download
  list reports the correct location after an app restart instead of a stale
  private path.

## 0.1.2

### Added

- `BackgroundTransferManager.moveToSharedStorage` moves a completed download
  into a system shared-storage location (e.g. the public Downloads folder) and
  re-emits the snapshot with the updated path.

## 0.1.1

### Fixed

- `DAKitOAuthClient.logout` no longer aborts when clearing the pending PKCE
  transaction fails (e.g. macOS keychain access denied for an unsigned host).
  Logout now always clears the token store, so a subsequent sign-in can request
  fresh scopes.

## 0.1.0

### Added

- `DAKitOAuthClient` composition root for system-browser login, cold-start
  callback recovery, and token lifecycle.
- Secure token and pending authorization stores backed by
  `flutter_secure_storage`.
- `BackgroundTransferManager` with queued, running, paused, completed, failed,
  and cancelled transfer state tracking.
- App links and system URI launcher adapters.
