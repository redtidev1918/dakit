# Changelog

## 0.1.25

### Fixed

- Treat persisted PKCE state as optional recovery support during a live OAuth
  flow. A temporarily unavailable platform key store can no longer prevent the
  browser from opening, turn cancellation into an error, or override the real
  callback/timeout result.
- If cold-start PKCE recovery storage is unreadable, return to a clean signed-
  out state so the host can offer a fresh authorization instead of exposing a
  secure-storage implementation error.

## 0.1.24

### Fixed

- Skip the encrypted pending-authorization store during ordinary cold starts
  that contain no OAuth callback. This prevents an unavailable or slow
  platform key store from delaying startup when there is no login to resume.

## 0.1.23

### Fixed

- Treat the saved OAuth token as the login commit point. Failure to remove an
  obsolete pending-PKCE Keychain item is now a cleanup warning and can no
  longer turn a successful token exchange into a failed login that users must
  repeat.

## 0.1.22

### Fixed

- Always leave the internal logout state even when Keychain/token deletion
  fails. A subsequent browser authorization can now save its replacement token
  instead of being rejected as `oauth.session.changed` on every attempt.

## 0.1.21

### Fixed

- `OAuthSession` now clears unusable local credentials after a definitive
  refresh rejection and emits `invalidations`. Hosts can leave authenticated UI
  immediately even when a slow refresh completed after their startup timeout.

## 0.1.20

### Fixed

- Normalize DeviantArt's non-standard `invalid_request` response for an
  invalid refresh token to `oauth.refresh.invalid`. Clients can now clear a
  revoked session instead of misclassifying it as a temporary outage and
  retrying authenticated endpoints indefinitely.

## 0.1.19

### Added

- `DeviationMapper.collectionSummary` now maps a collection's `thumb` /
  `preview` / `cover` image into `CollectionSummary.coverUri`.

## 0.1.18

### Fixed

- `OfficialDiscoveryRepository.watched` now treats the official API's empty
  object / null-results response for accounts that watch nobody as a valid
  empty feed. Contradictory pagination metadata remains a parsing failure, so
  real upstream schema drift is not silently swallowed.

## 0.1.17

### Added

- Added `OfficialArtworkMetadataRepository.tags`, backed by the official
  `deviation/metadata` endpoint, so hosts can hydrate tags omitted from compact
  browse responses and from `deviation/{id}`.

## 0.1.16

### Fixed

- `OfficialDiscoveryRepository.moreLikeThis` now hydrates sparse related
  deviations through `deviation/{id}` in bounded batches. This matches the
  current public schema, which only guarantees identifiers and deletion state
  in preview entries, instead of silently dropping every valid recommendation.
- If every sparse recommendation fails to hydrate, the repository surfaces the
  failure so hosts can present a retry state rather than an unexplained empty
  section.

## 0.1.15

### Fixed

- `OfficialDiscoveryRepository.moreLikeThis` now skips malformed, deleted, or
  restricted entries independently and tolerates a missing related rail. One
  bad recommendation can no longer discard every valid sibling in the preview;
  transport failures still throw so hosts can offer retry.

## 0.1.14

### Changed

- Centralized every official API endpoint path into `ApiRoutes` (internal),
  with a contract test pinning the routes, so a provider endpoint rename is a
  one-line edit. No behavior change.

## 0.1.13

### Fixed

- `OfficialDiscoveryRepository.moreLikeThis` now degrades to empty
  `featured_in_collections` / `suggested_collections` when their shape drifts,
  so a provider change to the volatile collection groups no longer drops the
  related artworks.

## 0.1.12

### Added

- `OfficialDiscoveryRepository.moreLikeThis` now also maps
  `featured_in_collections` and `suggested_collections` (each a collection
  `folderid`/name/owner plus its listed deviations) into `MoreLikeThisResult`.

## 0.1.11

### Fixed

- `OfficialDiscoveryRepository.moreLikeThis` now calls the real
  `browse/morelikethis/preview` endpoint (the old `browse/morelikethis` page
  endpoint no longer exists) and flattens `more_from_artist` +
  `more_from_da` into a de-duplicated artwork list, excluding the seed.

## 0.1.10

### Added

- `OfficialDiscoveryRepository.moreLikeThis` maps the official `browse/morelikethis` endpoint into a paged `Artwork` list.

## 0.1.9

### Changed

- `DeviationMapper` now marks the full-size `content` image with the same availability as the download (premium/paid content is `purchaseRequired`), while `preview`/`social_preview` thumbnails stay available so hosts can still render an accessible thumbnail.

## 0.1.8

### Fixed

- `DeviationMapper` now reads the correct `formatted_excerpt` field (the
  previous `formatted_exerpt` typo meant the HTML-excerpt fallback never
  matched, so `Artwork.description` only ever used the plain `excerpt`).

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
