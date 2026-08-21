import 'package:dakit_api/dakit_api.dart';
import 'package:dakit_core/dakit_core.dart';

import 'app_links_callback_source.dart';
import 'secure_pending_authorization_store.dart';
import 'secure_token_store.dart';
import 'system_uri_launcher.dart';

/// Ready-to-use OAuth lifecycle for Flutter applications.
///
/// Advanced hosts can replace every boundary while ordinary clients only need
/// an [OAuthConfig]. Construct this early in application startup so cold-start
/// links can be recovered by [resumePending].
final class DAKitOAuthClient {
  factory DAKitOAuthClient({
    required OAuthConfig config,
    TokenStore? tokenStore,
    PendingAuthorizationStore? pendingStore,
    ExternalUriLauncher? launcher,
    CallbackUriSource? callbacks,
    OAuthEndpoint? endpoint,
    NetworkProfile? networkProfile,
    DiagnosticSink diagnostics = const NoopDiagnosticSink(),
    DateTime Function()? now,
    Duration timeout = const Duration(minutes: 10),
  }) {
    if (endpoint != null && networkProfile != null) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'network.transport.ambiguous',
        message:
            'Provide either an OAuth endpoint or a network profile, not both.',
      );
    }
    final resolvedTokenStore = tokenStore ?? SecureTokenStore();
    final tokenClient = OAuthTokenClient(
      endpoint:
          endpoint ??
          DioOAuthEndpoint(
            networkProfile: networkProfile,
            diagnostics: diagnostics,
          ),
      diagnostics: diagnostics,
      now: now,
    );
    final session = OAuthSession(
      config: config,
      store: resolvedTokenStore,
      tokenClient: tokenClient,
      now: now,
    );
    final coordinator = OAuthAuthorizationCoordinator(
      config: config,
      launcher: launcher ?? const SystemUriLauncher(),
      callbacks: callbacks ?? AppLinksCallbackUriSource(),
      pendingStore: pendingStore ?? SecurePendingAuthorizationStore(),
      tokenClient: tokenClient,
      session: session,
      diagnostics: diagnostics,
      now: now,
      timeout: timeout,
    );
    return DAKitOAuthClient._(session, coordinator);
  }

  const DAKitOAuthClient._(this.session, this.authorization);

  final OAuthSession session;
  final OAuthAuthorizationCoordinator authorization;

  bool get isAuthorizing => authorization.isAuthorizing;

  Future<AuthTokens> authorize() => authorization.authorize();

  Future<AuthTokens?> resumePending({bool waitForCallback = false}) =>
      authorization.resumePending(waitForCallback: waitForCallback);

  Future<AuthTokens> validTokens({bool forceRefresh = false}) =>
      session.validTokens(forceRefresh: forceRefresh);

  Future<void> logout({bool revoke = true}) async {
    // The pending PKCE transaction is only a cold-start callback backup; a
    // failure to clear it (e.g. the macOS keychain denies access to an
    // unsigned host) must not block logout, otherwise the token store is left
    // intact and the user can never request fresh scopes on re-login.
    try {
      await authorization.cancelPending();
    } on DAKitException {
      // Continue to clear the session below.
    }
    await session.logout(revoke: revoke);
  }
}
