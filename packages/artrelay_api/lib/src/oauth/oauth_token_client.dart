import 'package:artrelay_core/artrelay_core.dart';

import 'oauth_config.dart';
import 'oauth_endpoint.dart';
import 'pkce.dart';

final class OAuthTokenClient {
  factory OAuthTokenClient({
    required OAuthEndpoint endpoint,
    DiagnosticSink diagnostics = const NoopDiagnosticSink(),
    DateTime Function()? now,
  }) => OAuthTokenClient._(endpoint, diagnostics, now ?? DateTime.now);

  OAuthTokenClient._(this._endpoint, this._diagnostics, this._now);

  final OAuthEndpoint _endpoint;
  final DiagnosticSink _diagnostics;
  final DateTime Function() _now;

  Future<AuthTokens> exchangeCode({
    required OAuthConfig config,
    required PendingAuthorization pending,
    required AuthorizationCallback callback,
  }) async {
    final started = _now();
    try {
      final response = await _endpoint.postForm(
        config.tokenEndpoint,
        <String, String>{
          'grant_type': 'authorization_code',
          'client_id': config.clientId,
          'redirect_uri': config.redirectUri.toString(),
          'code': callback.code,
          'code_verifier': pending.codeVerifier,
        },
      );
      final tokens = _parse(response);
      _recordSuccess('oauth.token.exchanged', started);
      return tokens;
    } on Object catch (error) {
      _recordFailure('oauth.token.exchange_failed', started, error);
      rethrow;
    }
  }

  Future<AuthTokens> refresh({
    required OAuthConfig config,
    required AuthTokens current,
  }) async {
    final refreshToken = current.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const ArtRelayException(
        kind: ArtRelayFailureKind.authentication,
        code: 'oauth.refresh.missing',
        message: 'The session cannot be refreshed and requires authorization.',
      );
    }
    final started = _now();
    try {
      final response = await _endpoint.postForm(
        config.tokenEndpoint,
        <String, String>{
          'grant_type': 'refresh_token',
          'client_id': config.clientId,
          'refresh_token': refreshToken,
        },
      );
      final tokens = _parse(response, fallbackRefreshToken: refreshToken);
      _recordSuccess('oauth.token.refreshed', started);
      return tokens;
    } on Object catch (error) {
      _recordFailure('oauth.token.refresh_failed', started, error);
      rethrow;
    }
  }

  Future<void> revoke({
    required OAuthConfig config,
    required AuthTokens current,
    bool currentSessionOnly = true,
  }) async {
    final token = current.refreshToken ?? current.accessToken;
    await _endpoint.postForm(config.revokeEndpoint, <String, String>{
      'token': token,
      if (currentSessionOnly) 'revoke_refresh_only': 'true',
    });
  }

  AuthTokens _parse(
    Map<String, Object?> response, {
    String? fallbackRefreshToken,
  }) {
    final accessToken = response['access_token'];
    final tokenType = response['token_type'];
    final expiresIn = _integer(response['expires_in']);
    if (accessToken is! String ||
        accessToken.isEmpty ||
        tokenType is! String ||
        tokenType.isEmpty ||
        expiresIn == null ||
        expiresIn <= 0) {
      throw const ArtRelayException(
        kind: ArtRelayFailureKind.parsing,
        code: 'oauth.token.invalid_response',
        message: 'The token response is missing required fields.',
      );
    }
    final rawScope = response['scope'];
    final scopes = rawScope is String
        ? rawScope.split(' ').where((value) => value.isNotEmpty).toSet()
        : const <String>{};
    return AuthTokens(
      accessToken: accessToken,
      tokenType: tokenType,
      expiresAt: _now().toUtc().add(Duration(seconds: expiresIn)),
      refreshToken:
          response['refresh_token'] as String? ?? fallbackRefreshToken,
      scopes: scopes,
    );
  }

  static int? _integer(Object? value) => switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text),
    _ => null,
  };

  void _recordSuccess(String code, DateTime started) {
    _diagnostics.add(
      DiagnosticEvent(
        stage: DiagnosticStage.tokenExchange,
        level: DiagnosticLevel.info,
        code: code,
        message: 'OAuth token operation completed.',
        elapsed: _now().difference(started),
      ),
    );
  }

  void _recordFailure(String code, DateTime started, Object error) {
    _diagnostics.add(
      DiagnosticEvent(
        stage: DiagnosticStage.tokenExchange,
        level: DiagnosticLevel.error,
        code: code,
        message: 'OAuth token operation failed.',
        elapsed: _now().difference(started),
        attributes: <String, Object?>{
          'failure_code': error is ArtRelayException
              ? error.code
              : 'unexpected',
        },
      ),
    );
  }
}
