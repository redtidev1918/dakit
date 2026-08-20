/// OAuth tokens owned by a public client session.
final class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.tokenType,
    required this.expiresAt,
    this.refreshToken,
    this.scopes = const <String>{},
  });

  final String accessToken;
  final String tokenType;
  final DateTime expiresAt;
  final String? refreshToken;
  final Set<String> scopes;

  bool isExpired(
    DateTime now, {
    Duration leeway = const Duration(minutes: 1),
  }) => !expiresAt.isAfter(now.add(leeway));
}

/// Supplies a valid bearer session to an authenticated API transport.
///
/// Hosts may use the built-in OAuth session or adapt an existing account/token
/// system without depending on DAKit's persistence implementation.
abstract interface class AuthTokenProvider {
  Future<AuthTokens> validTokens({bool forceRefresh = false});
}

abstract interface class TokenStore {
  Future<AuthTokens?> read();

  Future<void> write(AuthTokens tokens);

  Future<void> clear();
}

abstract interface class ExternalUriLauncher {
  Future<void> launch(Uri uri);
}

abstract interface class CallbackUriSource {
  Stream<Uri> get uris;
}

/// Callback source that can recover the URI which cold-started an application.
abstract interface class InitialCallbackUriSource implements CallbackUriSource {
  Future<Uri?> initialUri();
}
