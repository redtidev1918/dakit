# dakit_flutter

Flutter platform adapters for DAKit. The package re-exports `dakit_core` and `dakit_api`, then adds a ready-to-use OAuth facade and native background transfers without imposing screens or a state-management framework.

```dart
final oauth = DAKitOAuthClient(
  config: OAuthConfig(
    clientId: clientId,
    redirectUri: Uri.parse('dakit://oauth/callback'),
  ),
  networkProfile: NetworkProfile.environment(),
  diagnostics: diagnostics,
);

final restored = await oauth.resumePending();
final tokens = restored ?? await oauth.authorize();
```

The default integration uses the external system browser, `app_links`, and platform secure storage. Hosts can replace the launcher, callback source, token store, pending transaction store, OAuth endpoint, or network profile. Android, macOS, and Windows still require native callback registration in the host application.

`BackgroundTransferManager` provides persisted task recovery, progress, retry, pause/resume/cancel, and a media proxy independent from OAuth/API routing. It never substitutes previews when an original file is unavailable.

See the repository [getting-started guide](https://github.com/redtidev1918/dakit/blob/main/docs/GETTING_STARTED.md) and [authentication guide](https://github.com/redtidev1918/dakit/blob/main/docs/AUTHENTICATION.md).

DAKit is a community project and is not affiliated with or endorsed by DeviantArt.
