# Getting Started

This document walks through developer app registration, running the example client, and embedding the SDK from scratch. First, prepare Flutter 3.47.1, Dart 3.13.1, and the target platform toolchains.

## 0. Preparation Checklist

Before you start, confirm the following:

- Have a DeviantArt account and be able to create an app on the developer page;
- For client-style programs, choose the **Public** Client type; you only need `client_id`, and you do not store `client_secret`;
- Whitelist the callback URL precisely for the program you are going to run:
  - Example client / desktop / Android: `dakit://oauth/callback`
  - Command-line client: `http://127.0.0.1:8765/callback`
- Logging in requires `client_id`; downloading also requires the artwork UUID.

## 1. Register a Developer App

Create an app on DeviantArt's app management page. First, choose the Client type according to how your program is deployed:

| Deployment | Client type | Client credentials | DAKit integration |
| --- | --- | --- | --- |
| Apps on Flutter Android, macOS, Windows, or other user devices | **Public** | `client_id` | Use DAKit's built-in Authorization Code + PKCE login |
| Your own backend that can store credentials securely | **Confidential** | `client_id` + `client_secret` | Complete authentication on the backend; the client joins the session through a custom `AuthTokenProvider` |

The example client in this repository logs in directly on the user's device, so it should choose **Public**. Then fill in:

- Set the OAuth2 Redirect URI Whitelist to `dakit://oauth/callback`;
- Fill in Title, Description, and Download URL with your own client information;
- Original URLs Whitelist is only used for the `original_url` parameter, unrelated to reading the original file of an artwork; fill it in only when you have an actual use for it.

Credential names are easy to confuse:

- `client_id` is the public identifier of the developer app;
- `client_secret` is the long-term secret of a Confidential app, not a user token;
- `access_token` and `refresh_token` are session credentials issued after user authorization completes.

If the app management page shows both `client_id` and `client_secret`, the current registration is **Confidential**. It can be kept for backend use, but you must not compile the secret into an APK, EXE, or macOS app. To run this repository's example client, create a separate Public app; a Public registration only needs to pass `client_id` to DAKit.

The callback URL must match exactly, including scheme, host, path, case, and trailing slash. The current example always uses:

```text
dakit://oauth/callback
```

## 2. Run the Example Client

From the repository root, fetch dependencies and check the environment:

```shell
flutter pub get
flutter doctor -v
./tool/verify.sh
```

macOS:

```shell
cd apps/example_client
flutter run -d macos --dart-define=DAKIT_CLIENT_ID=YOUR_PUBLIC_CLIENT_ID
```

Android:

```shell
cd apps/example_client
flutter run -d android --dart-define=DAKIT_CLIENT_ID=YOUR_PUBLIC_CLIENT_ID
```

Windows requires installing the MSIX for the system to register the `dakit` scheme; an unpackaged EXE will not modify the user registry. See the [development documentation](DEVELOPMENT.md) for build commands.

The example app follows the system language to display Chinese or English. It is used to verify login, account, browsing, artwork details, original-file resolution, background tasks, and diagnostics; it is not a production UI template.

### Command-Line Client

Download a standalone binary from
[GitHub Releases](https://github.com/redtidev1918/dakit/releases?q=dakit_cli);
Dart and Flutter are not required. Builds cover Linux x64/ARM64, Windows x64,
and macOS Intel/Apple Silicon. The macOS archives are explicitly marked
unsigned previews.

Whitelist `http://127.0.0.1:8765/callback` exactly on a Public OAuth app, then:

```text
dakit login --client-id YOUR_PUBLIC_CLIENT_ID
dakit whoami
dakit search "digital art" --limit 24 --dest downloads
dakit logout
```

The CLI signs in through the system browser, refreshes sessions automatically,
and streams downloads through temporary files. See the root
[README](../../README.en.md#command-line-client) for all commands, proxy modes,
headless login, overwrite behavior, and security notes.

## 3. Embed in a Flutter App

The packages are available on pub.dev. A full Flutter integration only needs
`dakit_flutter`; its dependencies resolve automatically:

```yaml
dependencies:
  dakit_flutter: ^0.1.8
```

Then create the OAuth client before `runApp`:

```dart
final oauth = DAKitOAuthClient(
  config: OAuthConfig(
    clientId: clientId,
    redirectUri: Uri.parse('dakit://oauth/callback'),
    scopes: const <String>{'basic', 'browse'},
  ),
  networkProfile: NetworkProfile.environment(),
  diagnostics: diagnosticSink,
);

final resumed = await oauth.resumePending();
runApp(ClientApp(oauth: oauth, restoredTokens: resumed));
```

After the user taps login, run:

```dart
final tokens = await oauth.authorize();
```

Build the API repositories:

```dart
final api = OfficialApiClient(
  session: oauth.session,
  networkProfile: NetworkProfile.environment(),
  diagnostics: diagnosticSink,
);

final accountRepository = OfficialAccountRepository(api);
final userRepository = OfficialUserRepository(api);
final userLookupRepository = OfficialUserLookupRepository(api);
final artworkRepository = OfficialArtworkRepository(api);
final discoveryRepository = OfficialDiscoveryRepository(api);
final contentRepository = OfficialArtworkContentRepository(api);
final galleryRepository = OfficialGalleryRepository(api);
final folderRepository = OfficialFolderRepository(api);
final mediaRepository = OfficialMediaRepository(api);
final commentRepository = OfficialCommentRepository(api);
final socialRepository = OfficialSocialRepository(api);
final messageRepository = OfficialMessageRepository(api);
```

By default the scope only includes `basic` and `browse`. When you need write operations, explicitly request the corresponding permissions before the first authorization:

```dart
OAuthConfig(
  clientId: clientId,
  redirectUri: Uri.parse('dakit://oauth/callback'),
  scopes: const <String>{
    OAuthScope.basic,
    OAuthScope.browse,
    OAuthScope.collection,
    OAuthScope.commentPost,
    OAuthScope.message,
    OAuthScope.user,
    OAuthScope.userManage,
  },
)
```

After changing the scope you must have the user re-authorize; existing tokens do not automatically gain the newly added permissions. Favoriting requires `collection`, posting comments requires `comment.post`, the notifications and feedback center requires `message`, checking whether the current account follows a user requires `user`, and follow management requires `user.manage`.

`dakit_core` and `dakit_api` provide composable domain and network capabilities, and `dakit_flutter` provides common platform integrations. An existing account backend can provide a custom `AuthTokenProvider` to `OfficialApiClient`; enterprise network environments can inject a preconfigured Dio; secure storage, deep links, and background tasks also have independently replaceable interfaces.

## 4. Register Platform Callbacks

The example already includes Android, macOS, and Windows/MSIX configurations. When copying it into your own app, you must replace the app identifier and callback scheme accordingly:

- Android: add a browsable intent filter to the main Activity, and avoid conflicting with Flutter's default deep-link handling;
- macOS: register the scheme in `CFBundleURLTypes`;
- Windows: register the scheme in the MSIX manifest, and forward the activation event to the existing process.

Use the example platform projects as an executable reference; do not just copy the Dart code. See the [authentication documentation](AUTHENTICATION.md) for the full lifecycle and common failures.

## 5. Next Steps

- Proxy or mainland China network: [Networking & Diagnostics](NETWORKING.md);
- Correctly distinguish preview, original file, and body text: [Media & Transfer](MEDIA.md);
- Testing, building, and releasing: [Development & Maintenance](DEVELOPMENT.md);
- Live-service acceptance not yet completed: [Live Testing](LIVE_TESTING.md).
