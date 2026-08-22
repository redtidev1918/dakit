# Changelog

## 0.1.6

### Changed

- `BackgroundTransferManager.remove` now also deletes the downloaded file (both the moved shared-storage copy and the app-private original), not just the persisted record.

## 0.1.5

### Added

- `MasonryGridView` / `SliverMasonryGrid` — a lazy, balanced masonry (waterfall) layout for variable-height grid content (e.g. image galleries).

## 0.1.4

### Added

- `BackgroundTransferManager.remove` clears a finished transfer from the persisted records (the file is left in place).

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
