import 'dart:convert';
import 'dart:math';

import 'package:dakit_core/dakit_core.dart';
import 'package:crypto/crypto.dart';

import 'oauth_config.dart';

final class PendingAuthorization {
  const PendingAuthorization({
    required this.authorizationUri,
    required this.state,
    required this.codeVerifier,
    required this.createdAt,
  });

  final Uri authorizationUri;
  final String state;
  final String codeVerifier;
  final DateTime createdAt;
}

final class AuthorizationCallback {
  const AuthorizationCallback({required this.code});

  final String code;
}

final class PkceFlow {
  PkceFlow({Random? random}) : _random = random ?? Random.secure();

  static const String _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  final Random _random;

  PendingAuthorization start(OAuthConfig config, {DateTime? now}) {
    final codeVerifier = _randomString(64);
    final state = _randomString(48);
    final digest = sha256.convert(ascii.encode(codeVerifier));
    final challenge = base64Url.encode(digest.bytes).replaceAll('=', '');
    final query = <String, String>{
      'response_type': 'code',
      'client_id': config.clientId,
      'redirect_uri': config.redirectUri.toString(),
      'scope': config.scopes.join(' '),
      'state': state,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
    };

    return PendingAuthorization(
      authorizationUri: config.authorizationEndpoint.replace(
        queryParameters: query,
      ),
      state: state,
      codeVerifier: codeVerifier,
      createdAt: (now ?? DateTime.now()).toUtc(),
    );
  }

  AuthorizationCallback validateCallback({
    required OAuthConfig config,
    required PendingAuthorization pending,
    required Uri callbackUri,
    DateTime? now,
    Duration timeout = const Duration(minutes: 10),
  }) {
    final current = (now ?? DateTime.now()).toUtc();
    if (current.difference(pending.createdAt) > timeout) {
      throw const DAKitException(
        kind: DAKitFailureKind.authentication,
        code: 'oauth.callback.expired',
        message: 'The OAuth authorization transaction expired.',
      );
    }
    if (!_sameCallback(config.redirectUri, callbackUri)) {
      throw const DAKitException(
        kind: DAKitFailureKind.authentication,
        code: 'oauth.callback.redirect_mismatch',
        message:
            'The OAuth callback URI does not match the configured redirect.',
      );
    }
    final state = callbackUri.queryParameters['state'];
    if (state == null || state != pending.state) {
      throw const DAKitException(
        kind: DAKitFailureKind.authentication,
        code: 'oauth.callback.state_mismatch',
        message: 'The OAuth callback state is missing or invalid.',
      );
    }
    final error = callbackUri.queryParameters['error'];
    if (error != null) {
      final description = callbackUri.queryParameters['error_description'];
      throw DAKitException(
        kind: DAKitFailureKind.authorization,
        code: 'oauth.provider.$error',
        message:
            description ?? 'The authorization server rejected the request.',
        details: <String, Object?>{
          'provider_error': error,
          if (description != null)
            'provider_description': _boundedDescription(description),
        },
      );
    }
    final code = callbackUri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw const DAKitException(
        kind: DAKitFailureKind.authentication,
        code: 'oauth.callback.code_missing',
        message: 'The OAuth callback did not contain an authorization code.',
      );
    }
    return AuthorizationCallback(code: code);
  }

  bool matchesRedirect(OAuthConfig config, Uri callbackUri) =>
      _sameCallback(config.redirectUri, callbackUri);

  String _randomString(int length) => String.fromCharCodes(
    List<int>.generate(
      length,
      (_) => _alphabet.codeUnitAt(_random.nextInt(_alphabet.length)),
      growable: false,
    ),
  );

  static bool _sameCallback(Uri expected, Uri actual) =>
      expected.scheme == actual.scheme &&
      expected.userInfo == actual.userInfo &&
      expected.host == actual.host &&
      expected.port == actual.port &&
      expected.path == actual.path;

  static String _boundedDescription(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.length <= 240
        ? normalized
        : '${normalized.substring(0, 240)}…';
  }
}
