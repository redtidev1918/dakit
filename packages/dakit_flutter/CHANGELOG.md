# Changelog

## 0.1.0

### Added

- `DAKitOAuthClient` composition root for system-browser login, cold-start
  callback recovery, and token lifecycle.
- Secure token and pending authorization stores backed by
  `flutter_secure_storage`.
- `BackgroundTransferManager` with queued, running, paused, completed, failed,
  and cancelled transfer state tracking.
- App links and system URI launcher adapters.
