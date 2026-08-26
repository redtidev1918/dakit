# dakit_core

Platform-neutral domain contracts for [DAKit](https://github.com/redtidev1918/dakit)
clients. This package has **no Flutter, HTTP, plugin, UI, state-management,
cache, or database dependency** — it is the shared foundation that `dakit_api`
and `dakit_flutter` build on.

[![pub.dev](https://img.shields.io/pub/v/dakit_core?style=flat)](https://pub.dev/packages/dakit_core)
[![likes](https://img.shields.io/pub/likes/dakit_core?style=flat)](https://pub.dev/packages/dakit_core/score)
[![popularity](https://img.shields.io/pub/popularity/dakit_core?style=flat)](https://pub.dev/packages/dakit_core/score)

## Install

```yaml
dependencies:
  dakit_core: ^0.1.14
```

## What it exports

- account, full-profile, artwork, topic, folder, content, media, pagination, and
  transfer models;
- repository interfaces for accounts, profiles, user relationships/lookups,
  discovery feeds, folders, galleries, favourites, content, original media,
  comments, social actions, and provider messages;
- OAuth token-provider and persistence boundaries;
- structured diagnostics and typed `DAKitException` failures;
- a platform-neutral `TransferManager` contract.

## Example

```dart
Future<Artwork> loadArtwork(
  ArtworkRepository repository,
  String id,
) => repository.getById(id);
```

Applications may wrap these interfaces with their own cache or offline policy.
Provider DTOs and platform plugin types are intentionally absent from the
public API.

## Documentation

- [Getting started](https://github.com/redtidev1918/dakit/blob/main/docs/GETTING_STARTED.md)
- [Architecture](https://github.com/redtidev1918/dakit/blob/main/docs/ARCHITECTURE.md)
- [Documentation index](https://github.com/redtidev1918/dakit/blob/main/docs/README.md)

DAKit is a community project and is not affiliated with or endorsed by
DeviantArt. [MIT licensed](https://github.com/redtidev1918/dakit/blob/main/LICENSE).
