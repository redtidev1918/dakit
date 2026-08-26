# dakit_flutter

Flutter platform adapters for [DAKit](https://github.com/redtidev1918/dakit):
a ready-to-use OAuth facade, deep links, secure storage, and native background
transfers — without imposing screens or a state-management framework.

[![pub.dev](https://img.shields.io/pub/v/dakit_flutter?style=flat)](https://pub.dev/packages/dakit_flutter)
[![likes](https://img.shields.io/pub/likes/dakit_flutter?style=flat)](https://pub.dev/packages/dakit_flutter/score)
[![popularity](https://img.shields.io/pub/popularity/dakit_flutter?style=flat)](https://pub.dev/packages/dakit_flutter/score)

The package re-exports `dakit_core` and `dakit_api`, so a full Flutter
integration depends on this one package only.

## Install

```yaml
dependencies:
  dakit_flutter: ^0.1.12
```

## Example

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

## What you get

- **OAuth**: Authorization Code + S256 PKCE through the external system
  browser, with cold-start callback recovery via `resumePending()`.
- **Replaceable parts**: hosts can swap the launcher, callback source, token
  store, pending transaction store, OAuth endpoint, or network profile.
- **Background transfers**: `BackgroundTransferManager` provides persisted task
  recovery, progress, retry, pause/resume/cancel, and a media proxy independent
  from OAuth/API routing. It never substitutes previews when an original file
  is unavailable.

Android, macOS, and Windows still require native callback registration in the
host application.

## Documentation

- [Getting started](https://github.com/redtidev1918/dakit/blob/main/docs/GETTING_STARTED.md)
- [Authentication](https://github.com/redtidev1918/dakit/blob/main/docs/AUTHENTICATION.md)
- [Media and transfers](https://github.com/redtidev1918/dakit/blob/main/docs/MEDIA.md)
- [Documentation index](https://github.com/redtidev1918/dakit/blob/main/docs/README.md)

DAKit is a community project and is not affiliated with or endorsed by
DeviantArt. [MIT licensed](https://github.com/redtidev1918/dakit/blob/main/LICENSE).
