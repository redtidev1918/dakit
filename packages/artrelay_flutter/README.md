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

The facade accepts the API package's `NetworkProfile`, so browser authorization can
be followed by token exchange through an explicit route. The external browser still
uses the operating system's own networking configuration.

`BackgroundTransferManager` adapts platform schedulers into the core transfer
contract. It recovers tracked tasks after restart and supports progress, retry,
pause, resume, cancel, and a media-specific proxy without exposing plugin types.
