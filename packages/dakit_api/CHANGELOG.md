# Changelog

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
