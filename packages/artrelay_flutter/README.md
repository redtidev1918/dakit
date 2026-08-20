# artrelay_flutter

Flutter platform integrations for ArtRelay. It adapts mature plugins to the
platform-neutral interfaces exported by `artrelay_core`:

- `url_launcher` for the external system browser;
- `app_links` for Android, macOS, and Windows callback URIs;
- `flutter_secure_storage` for OAuth session storage.

The package does not provide screens or require a state-management framework.

For ordinary clients, `ArtRelayOAuthClient` assembles these adapters into a complete
public-client login lifecycle. Advanced clients can replace any boundary without
forking the SDK. See the workspace `docs/OAUTH.md` integration guide.
