# Changelog

## 0.1.11

### Changed

- Clarified the destructive `TransferManager.remove` contract: implementations
  remove downloaded local files as well as the persisted record, and must keep
  the record retryable when a known file cannot be deleted.

## 0.1.10

### Added

- `MoreLikeThisResult`, `CollectionSummary`, and `CollectionWithDeviations`
  models, and `DiscoveryRepository.moreLikeThis` now returns the full preview
  bundle: related artworks plus `featured_in_collections` and
  `suggested_collections`.

## 0.1.9

### Changed

- `DiscoveryRepository.moreLikeThis` now returns a flat, de-duplicated
  `List<Artwork>` instead of a `Page<Artwork>` — the official
  `browse/morelikethis/preview` endpoint is not paginated.

## 0.1.8

### Added

- `DiscoveryRepository.moreLikeThis` so hosts can surface related deviations ("More Like This") from the official browse endpoint.

## 0.1.7

### Added

- `Artwork.copyWith` so hosts can derive a changed artwork (e.g. flipping `isFavourited`) without reconstructing every field.

## 0.1.6

### Added

- `TransferManager.remove` for finished transfer cleanup. Its original
  record-only semantics were superseded by the destructive contract in 0.1.11.

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
