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
