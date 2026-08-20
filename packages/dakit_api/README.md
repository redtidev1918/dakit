# dakit_api

Dart-only OAuth PKCE, networking, diagnostics, and official DeviantArt API adapters for DAKit. It maps provider responses into `dakit_core` models and does not depend on Flutter.

Implemented repositories cover the current account, artwork detail, rendered content, home browse/search, galleries, favourites, and original-file metadata.

```dart
final network = NetworkProfile.environment();
final transport = OfficialApiClient(
  session: tokenProvider,
  networkProfile: network,
  diagnostics: diagnostics,
);

final account = await OfficialAccountRepository(transport).currentUser();
final page = await OfficialArtworkRepository(transport).browse(
  const PageRequest(limit: 24),
);
```

`tokenProvider` can be DAKit's `OAuthSession` or any host implementation of `AuthTokenProvider`. Advanced hosts may inject Dio instead of a `NetworkProfile`.

Public clients use Authorization Code + S256 PKCE and never embed a client secret. Preview URLs are not treated as originals; resolve transferable metadata through `OfficialMediaRepository`. Expected access denials become explicit media availability values, while network, throttling, and schema failures remain typed exceptions.

DAKit is a community project and is not affiliated with or endorsed by DeviantArt.
