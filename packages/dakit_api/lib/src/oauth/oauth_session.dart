import 'dart:async';

import 'package:dakit_core/dakit_core.dart';

import 'oauth_config.dart';
import 'oauth_token_client.dart';

/// Owns persisted tokens and coalesces concurrent refresh requests.
final class OAuthSession implements AuthTokenProvider {
  factory OAuthSession({
    required OAuthConfig config,
    required TokenStore store,
    required OAuthTokenClient tokenClient,
    DateTime Function()? now,
  }) => OAuthSession._(config, store, tokenClient, now ?? DateTime.now);

  OAuthSession._(this.config, this._store, this._tokenClient, this._now);

  final OAuthConfig config;
  final TokenStore _store;
  final OAuthTokenClient _tokenClient;
  final DateTime Function() _now;
  Future<AuthTokens>? _activeRefresh;
  Future<void>? _activeLogout;
  int _generation = 0;
  bool _loggingOut = false;

  /// Changes whenever the local session is invalidated.
  ///
  /// Authorization coordinators capture this value before opening a browser
  /// so a logout cannot be undone by a late token exchange.
  int get generation => _generation;

  @override
  Future<AuthTokens> validTokens({bool forceRefresh = false}) async {
    final expectedGeneration = _generation;
    _ensureUsable(expectedGeneration);
    final current = await _store.read();
    _ensureUsable(expectedGeneration);
    if (current == null) {
      throw _missingSession();
    }
    if (!forceRefresh && !current.isExpired(_now().toUtc())) return current;
    return _refresh(current, expectedGeneration);
  }

  Future<void> save(AuthTokens tokens, {int? expectedGeneration}) async {
    final expected = expectedGeneration ?? _generation;
    _ensureUsable(expected);
    await _store.write(tokens);
    if (_loggingOut || expected != _generation) {
      await _store.clear();
      throw _changedSession();
    }
  }

  Future<void> logout({bool revoke = true}) {
    final existing = _activeLogout;
    if (existing != null) return existing;
    final operation = _performLogout(revoke: revoke);
    _activeLogout = operation;
    unawaited(
      operation.then<void>(
        (_) => _clearLogout(operation),
        onError: (Object _, StackTrace _) => _clearLogout(operation),
      ),
    );
    return operation;
  }

  Future<void> _performLogout({required bool revoke}) async {
    _generation += 1;
    _loggingOut = true;
    AuthTokens? current;
    try {
      final refresh = _activeRefresh;
      if (refresh != null) {
        try {
          current = await refresh;
        } on Object {
          // A generation-aware refresh is expected to abort during logout.
        }
      }
      current ??= await _store.read();
      if (revoke && current != null) {
        await _tokenClient.revoke(config: config, current: current);
      }
    } finally {
      await _store.clear();
      _loggingOut = false;
    }
  }

  void _clearLogout(Future<void> operation) {
    if (identical(_activeLogout, operation)) _activeLogout = null;
  }

  Future<AuthTokens> _refresh(AuthTokens current, int expectedGeneration) {
    final existing = _activeRefresh;
    if (existing != null) return existing;
    final operation = _performRefresh(current, expectedGeneration);
    _activeRefresh = operation;
    unawaited(
      operation.then<void>(
        (_) => _clearRefresh(operation),
        onError: (Object _, StackTrace _) => _clearRefresh(operation),
      ),
    );
    return operation;
  }

  void _clearRefresh(Future<AuthTokens> operation) {
    if (identical(_activeRefresh, operation)) _activeRefresh = null;
  }

  Future<AuthTokens> _performRefresh(
    AuthTokens current,
    int expectedGeneration,
  ) async {
    final updated = await _tokenClient.refresh(
      config: config,
      current: current,
    );
    _ensureUsable(expectedGeneration);
    await _store.write(updated);
    if (_loggingOut || expectedGeneration != _generation) {
      await _store.clear();
      throw _changedSession();
    }
    return updated;
  }

  void _ensureUsable(int expectedGeneration) {
    if (_loggingOut || expectedGeneration != _generation) {
      throw _changedSession();
    }
  }

  static DAKitException _missingSession() => const DAKitException(
    kind: DAKitFailureKind.authentication,
    code: 'oauth.session.missing',
    message: 'No authorized session is available.',
  );

  static DAKitException _changedSession() => const DAKitException(
    kind: DAKitFailureKind.cancelled,
    code: 'oauth.session.changed',
    message: 'The OAuth session changed while an operation was running.',
  );
}
