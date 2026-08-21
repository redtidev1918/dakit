# Authentication and Sessions

DAKit's built-in on-device login adapter implements Authorization Code + S256 PKCE, suitable for Public Clients. The login page opens in the system's default browser; the SDK does not take over username, password, human verification, or third-party login pages. Projects using a Confidential Client can complete OAuth on a trusted backend and then connect the session to the API layer via `AuthTokenProvider`.

The official authentication guide is at [DeviantArt Authentication](https://deviantart.readme.io/docs/authentication).

## Choosing a Client type

Client type depends on where credentials are stored, not on how many features there are:

| Type | Suitable scenario | Application credentials issued by DeviantArt | DAKit support |
| --- | --- | --- | --- |
| Public | Mobile, desktop, SPA, and other programs that cannot keep secrets | `client_id` | Built-in PKCE login |
| Confidential | Services with a trusted backend that can keep long-term secrets | `client_id` + `client_secret` | Inject `AuthTokenProvider` after backend authentication |

Code and build artifacts installed on user devices cannot safely store shared secrets. Public apps link the authorization request through `client_id`, a one-time authorization code, and a PKCE verifier, and do not use `client_secret`.

`client_id` is an application identifier and may appear in the client; access tokens, refresh tokens, and `client_secret` are all private credentials. Public/Confidential describes the developer application type, not the token type.

If the developer console gave you a `client_secret`, that app registration is Confidential. That registration can still be used for the backend, but it cannot be handed directly to DAKit's on-device login adapter: compiling the secret into the client would leak it, and omitting it would yield `invalid_client` at the token exchange stage. When running a Flutter client directly, create a separate Public registration instead.

## Full Lifecycle

1. Generate a random `state`, a PKCE verifier, and an S256 challenge;
2. Write the pending transaction to platform secure storage;
3. Subscribe to deep links before opening the system browser;
4. The OS hands the exact callback URI back to the app;
5. Validate the scheme, host, path, expiry, and `state`;
6. Exchange the authorization code using the original verifier, without sending a secret;
7. Securely store the access/refresh tokens and delete the pending transaction;
8. Coordinate concurrent refreshes through a single session to avoid multiple simultaneous 401 refreshes.

The app should create `DAKitOAuthClient` early in startup, call `resumePending()` first, then show the UI. Call `authorize()` when the user explicitly taps log in. Concurrent authorization calls are merged into a single operation.

## Secure Storage

The default adapter uses `flutter_secure_storage`: Android uses the system secure storage, Windows uses the credential store, and macOS uses the Keychain. On macOS it defaults to `first_unlock_this_device` without enabling Data Protection Keychain, so ordinary unsigned development builds need no Keychain Sharing entitlement; hosts with enterprise signing policies can inject their own `TokenStore` and `PendingAuthorizationStore`.

No log should contain access tokens, refresh tokens, authorization codes, cookies, the PKCE verifier, proxy passwords, or signed media URLs. DAKit diagnostics keep only the stage, stable error code, elapsed time, and filtered attributes.

## Platform Callbacks

- Android: a browsable intent filter sends `dakit://oauth/callback` into the main Activity;
- macOS: `CFBundleURLTypes` registers the `dakit` scheme;
- Windows: the MSIX manifest registers the protocol, and `app_links` forwards the activation received by a new process to the existing instance.

A custom scheme is easy to integrate, but any other app can try to initiate the same URI, so `state`, exact redirect validation, and a short-lived transaction are all essential. If a claimed HTTPS redirect is needed in the future, it should be implemented by a host platform adapter and must not bypass the coordinator's validation.

## Troubleshooting

| Symptom or code | Meaning | What to check |
| --- | --- | --- |
| Browser does not open | launcher or system URL handling failed | default browser, system policy, the launch stage in diagnostics |
| Web page black screen / load failure | browser network or site policy issue | system browser proxy; it does not inherit Dart's in-app proxy |
| App unresponsive after login | callback was not handed back by the OS | platform scheme registration, whether the redirect matches exactly |
| callback state/redirect error | callback does not belong to the current transaction | do not reuse old links; clean up the old flow and retry |
| `oauth.provider.invalid_client` | provider does not accept the app identity | Public type, correct client ID, exact redirect; do not use a Confidential secret |
| token network/timeout/TLS | token endpoint not reachable | run the staged check and confirm the in-app network configuration |
| storage failure | secure storage unavailable | system credential store permissions, device lock-screen settings, native state fields |

Authentication failures and network failures are not collapsed into a single vague "login failed" message. When custom presentation is needed, map to localized text using `DAKitException.kind` and the stable `code`; do not show the raw underlying exception text directly to users.

## OAuth scopes and features

DAKit maintains constants centrally in `OAuthScope`. The mapping between features and required scopes:

| Feature | Required scope | Typical behavior when missing |
| --- | --- | --- |
| Read account / user profile / watch list | `user` | 401 |
| Favorite / unfavorite | `collection` | 401 |
| Watch / unwatch a user | `user.manage` | **403** (just `user` is not enough) |
| Gallery / collection folders | `gallery` | 401 |
| Watch feed (deviantsyouwatch) | `feed` | 401 |
| Home / search / daily recommendations | `browse` | 401 |
| Notifications / feedback / mentions | `message` | 401 |

Scopes missing at authorization time do not error at the token exchange stage; instead they surface as 401/403 on subsequent calls. When troubleshooting "a feature is always denied", first check which scopes the token actually received (`AuthTokens.scopes`) rather than only checking whether it is "logged in".

## Flutter: reusing a web session to complete authorization

DeviantArt's web login state and OAuth are two separate sets of credentials. If the client embeds a WebView already logged into `deviantart.com`, you can load the OAuth authorization URL into the **same** WebView: because the WebView holds the web session cookie, the user does not need to re-enter the password and only has to confirm the authorization page.

Implementation notes:

1. Customize `ExternalUriLauncher` to forward the authorization URL to the WebView (instead of the system browser);
2. The WebView intercepts `dakit://oauth/callback` and returns it to the coordinator via a custom `CallbackUriSource`;
3. Use `MergedCallbackUriSource` to merge the "system app-links callback" and the "WebView callback" concurrently
   —— do not use sequential `yield*`, since the app-links stream never closes and would starve the WebView callback;
4. The user may be logged in only on the web without an OAuth token, or vice versa. The host should present these two states clearly to the user, or guide the user through the missing step.
