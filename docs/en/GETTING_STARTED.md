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

If you do not need a graphical interface for now, you can use `dakit_cli` directly:

Before using it, prepare:

1. Register a **Public** OAuth app on DeviantArt;
2. Add the exact callback URL `dakit://oauth/callback` to the app whitelist;
3. Record the app's `client_id`.

```shell
dart run packages/dakit_cli/bin/dakit.dart status --proxy 127.0.0.1:7892
dart run packages/dakit_cli/bin/dakit.dart login --client-id YOUR_PUBLIC_CLIENT_ID --proxy 127.0.0.1:7892
dart run packages/dakit_cli/bin/dakit.dart url ARTWORK_UUID --dest downloads --proxy 127.0.0.1:7892
dart run packages/dakit_cli/bin/dakit.dart artist USERNAME --limit 24 --delay 1
dart run packages/dakit_cli/bin/dakit.dart gallery USERNAME [gallery_id]
dart run packages/dakit_cli/bin/dakit.dart fav USERNAME [folder_id]
dart run packages/dakit_cli/bin/dakit.dart search "digital art" --limit 24
dart run packages/dakit_cli/bin/dakit.dart login validate
```

CLI login uses the callback `dakit://oauth/callback`, which must be added exactly to the Public app whitelist. After authorization completes, paste the full callback URL from the browser address bar back into the CLI. Batch download commands require completing login first and passing the artwork UUID / username. Credentials are saved to `~/.config/dakit/credentials.json` on your machine (`%APPDATA%/dakit/credentials.json` on Windows), and after a download completes the CLI prints the save path, byte count, SHA-256, and media type. Run `dakit --help` to view the full checklist.

All CLI commands support `--verbose` / `-v`, which outputs redacted diagnostic events to `stderr`:

```shell
dart run packages/dakit_cli/bin/dakit.dart status --proxy 127.0.0.1:7892 --verbose
```

The CLI uses the official OAuth API and does not use web cookies / scraping; therefore it does not support `cookies.txt`, SOCKS5 proxies, preview quality switching, or "anti-ban" parameters. The official API provides original files directly, and the CLI will not pass off preview as original.

After logging in to the Flutter example client, there is a built-in Debug console at the bottom of the page where you can type `help`, `account`, `status`, `open UUID`, `download UUID`, `clear`.

## 3. Embed in a Flutter App

Before the first release to pub.dev, you need to declare the three packages explicitly from the Git repository; otherwise `dakit_flutter`'s not-yet-published transitive dependencies `dakit_core` / `dakit_api` cannot be resolved:

```yaml
dependencies:
  dakit_core:
    git:
      url: https://github.com/redtidev1918/dakit.git
      path: packages/dakit_core
  dakit_api:
    git:
      url: https://github.com/redtidev1918/dakit.git
      path: packages/dakit_api
  dakit_flutter:
    git:
      url: https://github.com/redtidev1918/dakit.git
      path: packages/dakit_flutter
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
