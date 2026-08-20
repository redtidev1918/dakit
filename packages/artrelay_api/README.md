# artrelay_api

Dart-only OAuth and official HTTP integration for ArtRelay. The package depends on
`artrelay_core` and maps upstream responses into stable core models.

OAuth public clients use Authorization Code with S256 PKCE. The client ID and exact
redirect URI are runtime configuration; no client secret belongs in an application.

The exported official repositories cover account identity, artwork detail, home
browse/search, galleries, favourites, and original-file metadata. Upstream DTOs stay
private: callers only receive `artrelay_core` models.

```dart
final transport = OfficialApiClient(session: session);
final artworks = OfficialArtworkRepository(transport);
final originals = OfficialMediaRepository(transport);

final artwork = await artworks.getById(id);
final original = await originals.originalFile(artwork.id);
```

Preview URLs are deliberately not labeled as originals. Resolve the original only
when `Artwork.isDownloadable` is true and handle the provider's typed authorization
or availability failure.
