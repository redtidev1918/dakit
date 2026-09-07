# Changelog

## [1.0.0](https://github.com/redtidev1918/dakit/compare/dakit_api-vv0.2.0...dakit_api-vv1.0.0) (2026-09-07)


### ⚠ BREAKING CHANGES

* rename the SDK to DAKit

### Features

* add comments and social API mutations ([daf5cdf](https://github.com/redtidev1918/dakit/commit/daf5cdfd1ba29c411038267d568c922bf14df145))
* add notification and feedback message APIs ([ba92841](https://github.com/redtidev1918/dakit/commit/ba92841516d7b51eca6340de420f31d39c73afb4))
* add profile discovery and folder APIs ([2dff62a](https://github.com/redtidev1918/dakit/commit/2dff62ad6a8d960c3dcca8dcc26116b0f3572de2))
* add pub.dev topics for search discoverability ([b882632](https://github.com/redtidev1918/dakit/commit/b882632816322f287e4a0767de1b76ca7f8c374c))
* add topics and folder content browsing ([5f28f47](https://github.com/redtidev1918/dakit/commit/5f28f47e2d7ce5cce190ab9401cd0e9a0c299f61))
* add user relationship and lookup APIs ([89350f9](https://github.com/redtidev1918/dakit/commit/89350f9da9c479f428b5582e6e5e500fd685f67a))
* **api:** add moreLikeThis to discovery repositories ([0bdf150](https://github.com/redtidev1918/dakit/commit/0bdf15061294d2287f68286d19890f46699a3eaf))
* **api:** export DeviationMapper for raw JSON mapping ([0943d41](https://github.com/redtidev1918/dakit/commit/0943d413bad9de9a50d1c073dd6573b47d626c1b))
* **api:** sort tag feeds by recent or popular ([1209d3a](https://github.com/redtidev1918/dakit/commit/1209d3a897db1a2f7a5ee5bacfe1c49ce21db6e0))
* **core,api:** expose a collection cover image on CollectionSummary ([05eb721](https://github.com/redtidev1918/dakit/commit/05eb7215169acdc95a1a41036e2d6f81b445e013))
* **core,api:** expose collection groups in More Like This result ([243bfa0](https://github.com/redtidev1918/dakit/commit/243bfa05a0eba44f73e333d50ebec89372c843a4))
* map deviation tags into Artwork.tags ([2dc6271](https://github.com/redtidev1918/dakit/commit/2dc6271ee055b6499b84e0012681aa6b913b95bd))
* map is_favourited and is_multi_media into Artwork ([c78cfbf](https://github.com/redtidev1918/dakit/commit/c78cfbff7abb51bde09b8c2bed842a840fb5904b))
* **media:** expose download denial reason and document removed fields ([#4](https://github.com/redtidev1918/dakit/issues/4)) ([bf32c60](https://github.com/redtidev1918/dakit/commit/bf32c601f5b32394e1972ec04781d09cf6a705f6))
* **web:** support DeviantArt web cookies for mature multi-image works ([5231553](https://github.com/redtidev1918/dakit/commit/52315530da445148d637aba80e96f1f6403088df))


### Bug Fixes

* **api:** apply receiveTimeout so hung API requests fail instead of spinning forever ([0765cbb](https://github.com/redtidev1918/dakit/commit/0765cbb4b838e0bdc5b28e2016bb670a81d6df7a))
* **api:** classify invalid refresh credentials ([c31414c](https://github.com/redtidev1918/dakit/commit/c31414cb6bb40ac751f9029c41ab153f980b22ce))
* **api:** commit login before pending cleanup ([4b1567e](https://github.com/redtidev1918/dakit/commit/4b1567e9a3de9a26e9f11f2b1b83fb1b8656189a))
* **api:** decouple live OAuth from recovery storage ([383651d](https://github.com/redtidev1918/dakit/commit/383651d9b052319616385b2083008e261bdb934b))
* **api:** degrade collection groups gracefully on shape drift ([bcf677e](https://github.com/redtidev1918/dakit/commit/bcf677eb707356fb25cb9473ee8a3777980b506c))
* **api:** hydrate sparse related artwork previews ([4390935](https://github.com/redtidev1918/dakit/commit/43909357dbe7cba23db1f1b6538bb829b7ab01aa))
* **api:** invalidate rejected refresh sessions ([a442d73](https://github.com/redtidev1918/dakit/commit/a442d7307a9b7bfec7a4310a09a065816619cb04))
* **api:** load artwork tags from metadata ([8b81129](https://github.com/redtidev1918/dakit/commit/8b811295e3f7da215182d7ac4f45d0e1cb40f392))
* **api:** map download 4xx to unavailable instead of rethrowing ([d1df323](https://github.com/redtidev1918/dakit/commit/d1df323270242ad262589118aecc8012ad128ef6))
* **api:** mark premium/paid content image availability ([2c9de59](https://github.com/redtidev1918/dakit/commit/2c9de59512e52b8d6c783862710912be71d11323))
* **api:** read the correct formatted_excerpt field ([bd2984b](https://github.com/redtidev1918/dakit/commit/bd2984b3d9b2860aca67bfba75705565f8e48240))
* **api:** recover from token deletion failure ([cade2c7](https://github.com/redtidev1918/dakit/commit/cade2c75271223b60b184034de7f86aea9a60d6b))
* **api:** send mature_content on all read endpoints ([5c357d9](https://github.com/redtidev1918/dakit/commit/5c357d9b4e643a1e51dafa417ea9abd0bf756441))
* **api:** show mature gallery/folder content and map journal thumbs ([b0fbfbb](https://github.com/redtidev1918/dakit/commit/b0fbfbbd57468836e165da927640c53faf7737dc))
* **api:** skip idle authorization recovery ([7ddd9e1](https://github.com/redtidev1918/dakit/commit/7ddd9e1b96836bc800fa37c34d7e4c269e6f1b48))
* **api:** tag sort mode values are newest|popular not recent ([da94dc5](https://github.com/redtidev1918/dakit/commit/da94dc5bbc5444b21224dfde378c44cecf2f3fed))
* **api:** treat empty watched feed as valid ([50f9530](https://github.com/redtidev1918/dakit/commit/50f95308fdc69a2199706d4969a0d87e360809e9))
* **api:** use browse/morelikethis/preview for More Like This ([b535604](https://github.com/redtidev1918/dakit/commit/b535604ea6e87610ea62d66f5b14e833a74461c8))
* **ci:** resolve web client analyzer findings ([6646ffd](https://github.com/redtidev1918/dakit/commit/6646ffd23bd578064d32cedb86436d08c2030712))
* harden related results and destructive transfer removal ([7567ea6](https://github.com/redtidev1918/dakit/commit/7567ea639096543983601afc3fd42adba33eed5b))
* make OAuth logout and cancellation race-safe ([6c0ce55](https://github.com/redtidev1918/dakit/commit/6c0ce5525a2945b93e090eea15e40048108e1fab))
* satisfy formatter and typed task paths ([244e00e](https://github.com/redtidev1918/dakit/commit/244e00e31d25bfc9b16e74c6fa05fcaead7f4885))


### Code Refactoring

* rename the SDK to DAKit ([a9f0837](https://github.com/redtidev1918/dakit/commit/a9f0837f22ad1128c4587998ba0c0d11103462f0))

## 0.2.0

### Added

- `WebDeviationClient`: resolves a numeric deviation id through the website's
  `_puppy/dadeviation/init` endpoint (browser UA + CSRF) with a web cookie,
  returning **every** media asset for mature multi-image works (main file plus
  each additional page) as transferable signed-CDN `MediaAsset`s. Requires
  dakit_core >=0.2.0.
- `CookieProvider` with `StaticCookieProvider` and `EnvironmentCookieProvider`
  (`DAKIT_COOKIES`). Diagnostics route the cookie through the existing
  `Redactor`, so `cookie`/`set-cookie` are never logged.

### Fixed

- Web request headers always send the `Cookie` value; the cookie never appears
  in diagnostic attributes.

## 0.1.30

### Fixed

- `OfficialApiClient` now applies the configured `receiveTimeout` to its Dio
  (previously only `connectTimeout` was set, and dio's default receive
  timeout is `null`). An API host that accepts the connection but never
  replies — e.g. a blackholed route — previously hung the request forever;
  it now fails with a typed, retryable timeout error.

## 0.1.29


### Docs

- Publish pub.dev topics (`deviantart`, `deviantart-api`, `oauth`, `pkce`,
  `downloader`, …) so the package is discoverable in pub.dev search.

## 0.1.28


### Docs

- Modernized the package README: pub.dev badges, install snippet, and
  documentation links.

## 0.1.27

### Fixed

- Tag sort now sends the correct `browse/tags` mode values (`newest` / `popular`)
  instead of `recent`, which DeviantArt ignores — so "Newest" and "Popular"
  previously returned identical results.

## 0.1.26

### Added

- `OfficialDiscoveryRepository.tag` accepts a `BrowseSort` (`recent` / `popular`)
  and sends it as the `mode` query parameter, so tag feeds can be ordered by
  newest or most popular.

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
