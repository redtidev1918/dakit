# Changelog

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
