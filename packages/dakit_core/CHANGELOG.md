# Changelog

## 0.1.1

### Added

- `MediaAsset.availabilityReason` to carry a human-readable download denial
  reason (for example "Free download limit reached") through to hosts.

### Changed

- Documented that `Artwork.description` and `Artwork.textContent` are no longer
  populated by the official API; use `ArtworkContentRepository.get()` instead.

## 0.1.0

### Added

- Platform-neutral domain models for users, artworks, media, comments, folders,
  topics, notifications, and social relationships.
- Repository and transfer contracts for non-Flutter and Flutter hosts.
- Pagination value types, typed failures, and diagnostic events.
- Auth token, token store, and pending authorization store contracts.
