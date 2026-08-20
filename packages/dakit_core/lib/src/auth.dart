abstract final class OAuthScope {
  static const String basic = 'basic';
  static const String browse = 'browse';
  static const String collection = 'collection';
  static const String commentManage = 'comment.manage';
  static const String commentPost = 'comment.post';
  static const String feed = 'feed';
  static const String gallery = 'gallery';
  static const String message = 'message';
  static const String note = 'note';
  static const String publish = 'publish';
  static const String stash = 'stash';
  static const String user = 'user';
  static const String userManage = 'user.manage';
}

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
