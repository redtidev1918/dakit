# Changelog

## 0.1.7

### Fixed

- `OfficialMediaRepository.originalFile` now maps a 4xx from the download
  endpoint to `MediaAvailability.unavailable` instead of rethrowing, so hosts
  show a "not downloadable" hint rather than a full-screen error. 5xx errors
  still bubble up for a retry.

## 0.1.6

### Fixed

- Every official read endpoint now sends `mature_content: true` and no longer
  forces `with_session: false`, so mature deviations appear consistently in
  browse, search, tags, topics, gallery/folder/collection feeds, and messages
  for signed-in users (the session is used for watch state too).

## 0.1.5

### Added

- Export `DeviationMapper` so hosts can map raw official-API deviation JSON
  (e.g. `user/profile/posts` journals) without a repository round-trip.

## 0.1.4

### Fixed

- Gallery, folder, and collection requests now send `mature_content: true` and
  stop forcing `with_session: false`, so folders/galleries full of mature
  deviations no longer render as empty for signed-in users.

### Added

- `DeviationMapper` maps a literature deviation's embedded `thumbs` images into
  `Artwork.media`, so journals with inline art render their images.

## 0.1.3

### Added

- `DeviationMapper` maps `is_favourited` and `is_multi_media` into `Artwork`.

## 0.1.2

### Added

- `DeviationMapper` now maps a deviation's `tags` into `Artwork.tags`.

## 0.1.1

### Changed

- `OfficialMediaRepository.originalFile` now populates
  `MediaAsset.availabilityReason` from the provider `error_description` when a
  download is declined, so hosts can distinguish "Deviation not downloadable"
  from "Free download limit reached".

## 0.1.0

### Added

- Authorization Code + PKCE OAuth flow with callback validation and token
  exchange, refresh, and revocation.
- Network profiles, explicit proxy support, and staged connectivity probing.
- Official DeviantArt API adapters for accounts, users, artworks, discovery,
  galleries, folders, media, comments, social actions, and messages.
- Private upstream DTO mapping with additive-field tolerance and typed parsing
  failures.
