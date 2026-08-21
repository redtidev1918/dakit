import 'dart:async';

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

/// Merges several callback sources so any of them can deliver the OAuth
/// redirect.
///
/// Useful when a client accepts callbacks from more than one channel — for
/// example the OS app-links plus an in-app WebView. [initial] also supplies the
/// cold-start URI; the remaining [others] only contribute their [CallbackUriSource.uris].
///
/// The streams are merged concurrently: a source whose stream never closes
/// (such as an OS app-links stream) must not starve the others. A sequential
/// `yield*` over the sources would block forever on the first non-closing
/// stream and never observe later callbacks.
final class MergedCallbackUriSource implements InitialCallbackUriSource {
  MergedCallbackUriSource({
    required this.initial,
    List<CallbackUriSource> others = const <CallbackUriSource>[],
  }) : others = List<CallbackUriSource>.unmodifiable(others);

  final InitialCallbackUriSource initial;
  final List<CallbackUriSource> others;

  @override
  Future<Uri?> initialUri() => initial.initialUri();

  @override
  Stream<Uri> get uris => Stream<Uri>.multi((controller) {
    void onData(Uri uri) => controller.add(uri);
    void onError(Object error, StackTrace stack) =>
        controller.addError(error, stack);

    final subscriptions = <StreamSubscription<Uri>>[
      initial.uris.listen(onData, onError: onError),
      for (final source in others) source.uris.listen(onData, onError: onError),
    ];
    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };
  });
}
