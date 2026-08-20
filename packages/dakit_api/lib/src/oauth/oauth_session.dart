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

  @override
  Future<AuthTokens> validTokens({bool forceRefresh = false}) async {
    final current = await _store.read();
    if (current == null) {
      throw const DAKitException(
        kind: DAKitFailureKind.authentication,
        code: 'oauth.session.missing',
        message: 'No authorized session is available.',
      );
    }
    if (!forceRefresh && !current.isExpired(_now().toUtc())) return current;
    return _refresh(current);
  }

  Future<void> save(AuthTokens tokens) => _store.write(tokens);

  Future<void> logout({bool revoke = true}) async {
    final current = await _store.read();
    try {
      if (revoke && current != null) {
        await _tokenClient.revoke(config: config, current: current);
      }
    } finally {
      await _store.clear();
    }
  }

  Future<AuthTokens> _refresh(AuthTokens current) {
    final existing = _activeRefresh;
    if (existing != null) return existing;
    final operation = _performRefresh(current);
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

  Future<AuthTokens> _performRefresh(AuthTokens current) async {
    final updated = await _tokenClient.refresh(
      config: config,
      current: current,
    );
    await _store.write(updated);
    return updated;
  }
}
