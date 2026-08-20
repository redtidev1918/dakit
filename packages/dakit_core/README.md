# dakit_core

Platform-neutral domain contracts for DAKit clients. This package has no Flutter, HTTP, plugin, UI, state-management, cache, or database dependency.

It exports:

- account, full-profile, artwork, folder, content, media, pagination, and transfer models;
- repository interfaces for accounts, profiles, discovery feeds, folders, galleries, favourites, content, original media, comments, and social actions;
- OAuth token-provider and persistence boundaries;
- structured diagnostics and typed `DAKitException` failures;
- a platform-neutral `TransferManager` contract.

```dart
Future<Artwork> loadArtwork(
  ArtworkRepository repository,
  String id,
) => repository.getById(id);
```

Applications may wrap these interfaces with their own cache or offline policy. Provider DTOs and platform plugin types are intentionally absent from the public API.

DAKit is a community project and is not affiliated with or endorsed by DeviantArt.
