# dakit_api

Dart-only OAuth PKCE, networking, diagnostics, and official DeviantArt API adapters for DAKit. It maps provider responses into `dakit_core` models and does not depend on Flutter.

Implemented repositories cover the current account, full user profiles, user relationships and bulk lookup, artwork detail, rendered content, home browse/search, daily selections, watched-user feeds, tag autocomplete/browsing, topic navigation, gallery/collection folders and their contents, original-file metadata, artwork comments, favourites, and user watch state.

```dart
final network = NetworkProfile.environment();
final transport = OfficialApiClient(
  session: tokenProvider,
  networkProfile: network,
  diagnostics: diagnostics,
);

final account = await OfficialAccountRepository(transport).currentUser();
final profile = await OfficialUserRepository(transport).profile('username');
final users = await OfficialUserLookupRepository(transport).lookup(
  const <String>['first-user', 'second-user'],
);
final page = await OfficialArtworkRepository(transport).browse(
  const PageRequest(limit: 24),
);
final daily = await OfficialDiscoveryRepository(transport).dailyDeviations();
final folders = await OfficialFolderRepository(transport).galleryFolders(
  username: 'username',
);
final comments = OfficialCommentRepository(transport);
final social = OfficialSocialRepository(transport);
```

`tokenProvider` can be DAKit's `OAuthSession` or any host implementation of `AuthTokenProvider`. Advanced hosts may inject Dio instead of a `NetworkProfile`.

Public clients use Authorization Code + S256 PKCE and never embed a client secret. Preview URLs are not treated as originals; resolve transferable metadata through `OfficialMediaRepository`. Expected access denials become explicit media availability values, while network, throttling, and schema failures remain typed exceptions.

GET requests use bounded exponential retry for documented transient responses. Form-encoded mutations refresh once after a 401 but are not automatically retried after rate limits or server failures, preventing duplicate non-idempotent actions. Request `collection`, `comment.post`, or `user.manage` before using the corresponding social operation.

DAKit is a community project and is not affiliated with or endorsed by DeviantArt.
