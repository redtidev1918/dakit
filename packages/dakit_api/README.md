# dakit_api

Dart-only OAuth and official HTTP integration for DAKit. The package depends on
`dakit_core` and maps upstream responses into stable core models.

OAuth public clients use Authorization Code with S256 PKCE. The client ID and exact
redirect URI are runtime configuration; no client secret belongs in an application.

The exported official repositories cover account identity, artwork detail and
full text, home browse/search, galleries, favourites, and original-file metadata.
Upstream DTOs stay private: callers only receive `dakit_core` models.

```dart
final network = NetworkProfile.environment();
final transport = OfficialApiClient(
  session: session,
  networkProfile: network,
  diagnostics: diagnostics,
);
final artworks = OfficialArtworkRepository(transport);
final content = OfficialArtworkContentRepository(transport);
final originals = OfficialMediaRepository(transport);

final artwork = await artworks.getById(id);
final rendered = await content.get(artwork.id);
final original = await originals.originalFile(artwork.id);
```

`session` may be the built-in `OAuthSession` or any host implementation of the
platform-neutral `AuthTokenProvider`; API transport is not coupled to secure
storage or browser login.

Preview URLs are deliberately not labeled as originals. Resolve the original only
when `Artwork.downloadAvailability` is `available`. Expected login, access,
not-downloadable, and missing-file responses become non-transferable `MediaAsset`
values; network, rate-limit, and schema failures remain exceptions. Provider HTML
and CSS are returned as inert data and are never evaluated by this package.

`NetworkProfile` supports environment proxy discovery, forced direct connections,
and explicit HTTP proxies. `ConnectivityProbe` isolates DNS, TCP, TLS, and HTTP
failures. Advanced hosts may inject their own Dio transport instead; the SDK never
offers a certificate-validation bypass.
