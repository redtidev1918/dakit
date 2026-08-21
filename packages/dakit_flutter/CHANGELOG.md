# Changelog

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
