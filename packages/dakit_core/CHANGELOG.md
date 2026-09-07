# Changelog

## [1.0.0](https://github.com/redtidev1918/dakit/compare/dakit_core-vv0.2.0...dakit_core-vv1.0.0) (2026-09-07)


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
* **api:** sort tag feeds by recent or popular ([1209d3a](https://github.com/redtidev1918/dakit/commit/1209d3a897db1a2f7a5ee5bacfe1c49ce21db6e0))
* **core,api:** expose a collection cover image on CollectionSummary ([05eb721](https://github.com/redtidev1918/dakit/commit/05eb7215169acdc95a1a41036e2d6f81b445e013))
* **core,api:** expose collection groups in More Like This result ([243bfa0](https://github.com/redtidev1918/dakit/commit/243bfa05a0eba44f73e333d50ebec89372c843a4))
* **core:** add Artwork.copyWith ([f6a2674](https://github.com/redtidev1918/dakit/commit/f6a2674ad084a66a04bfc5217a867309af716729))
* **core:** add MergedCallbackUriSource and document web-session gaps ([#5](https://github.com/redtidev1918/dakit/issues/5)) ([73c08b6](https://github.com/redtidev1918/dakit/commit/73c08b6e172c72c9b0b51db4e8e32b64aa41a048))
* map deviation tags into Artwork.tags ([2dc6271](https://github.com/redtidev1918/dakit/commit/2dc6271ee055b6499b84e0012681aa6b913b95bd))
* map is_favourited and is_multi_media into Artwork ([c78cfbf](https://github.com/redtidev1918/dakit/commit/c78cfbff7abb51bde09b8c2bed842a840fb5904b))
* **media:** expose download denial reason and document removed fields ([#4](https://github.com/redtidev1918/dakit/issues/4)) ([bf32c60](https://github.com/redtidev1918/dakit/commit/bf32c601f5b32394e1972ec04781d09cf6a705f6))
* **transfer:** add TransferManager.remove to clear finished records ([9e596dd](https://github.com/redtidev1918/dakit/commit/9e596ddf16cb0a9d44e3c05efb5a9f895ecba078))
* **transfer:** move completed downloads into shared storage ([602f0f6](https://github.com/redtidev1918/dakit/commit/602f0f6aa5eb4d450baee42b037e48619876935b))
* **web:** support DeviantArt web cookies for mature multi-image works ([5231553](https://github.com/redtidev1918/dakit/commit/52315530da445148d637aba80e96f1f6403088df))


### Bug Fixes

* **api:** use browse/morelikethis/preview for More Like This ([b535604](https://github.com/redtidev1918/dakit/commit/b535604ea6e87610ea62d66f5b14e833a74461c8))
* harden related results and destructive transfer removal ([7567ea6](https://github.com/redtidev1918/dakit/commit/7567ea639096543983601afc3fd42adba33eed5b))


### Code Refactoring

* rename the SDK to DAKit ([a9f0837](https://github.com/redtidev1918/dakit/commit/a9f0837f22ad1128c4587998ba0c0d11103462f0))

## 0.2.0

### Added

- `WebSession`: a DeviantArt website (cookie) session used by the private
  `_puppy` endpoints for mature multi-image works. `toString` is redacted (it
  exposes only `present` / `authenticated` flags, never the cookie value).

## 0.1.15

### Docs

- Publish pub.dev topics (`deviantart`, `deviantart-api`, `oauth`, `pkce`,
  `downloader`, …) so the package is discoverable in pub.dev search.

## 0.1.14


### Docs

- Modernized the package README: pub.dev badges, install snippet, and
  documentation links.

## 0.1.13

### Added

- `BrowseSort` enum (`recent` / `popular`) and an optional `sort` parameter on
  `DiscoveryRepository.tag`, so hosts can switch tag feeds between newest and
  most-popular order.

## 0.1.12

### Added

- `CollectionSummary.coverUri`: a nullable preview image for a collection, so
  hosts can render a cover instead of a placeholder when the provider supplies
  one.

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
