# Changelog

## 0.1.7

### Added

- `Artwork.copyWith` so hosts can derive a changed artwork (e.g. flipping `isFavourited`) without reconstructing every field.

## 0.1.6

### Added

- `TransferManager.remove` so hosts can clear a finished transfer from the persisted records without deleting the downloaded file.

## 0.1.5

### Added

- `TransferSharedStorage` and `TransferManager.moveToSharedStorage` so hosts can
  move a completed transfer into a system shared-storage location (e.g. the
  public Downloads folder) without duplicating the file.

## 0.1.4

### Added

- `Artwork.isFavourited` and `Artwork.isMultiMedia` so hosts can reflect favourite state and multi-image galleries without extra provider calls.

## 0.1.3

### Added

- `Artwork.tags` — the searchable tag names attached to a deviation.

## 0.1.2

### Added

- `MergedCallbackUriSource` to merge multiple callback sources concurrently,
  so a non-closing stream (e.g. the OS app-links stream) cannot starve a later
  source (e.g. an in-app WebView callback).

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
