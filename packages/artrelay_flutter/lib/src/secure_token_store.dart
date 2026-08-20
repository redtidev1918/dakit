import 'dart:convert';

import 'package:artrelay_core/artrelay_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'storage_failure.dart';

final class SecureTokenStore implements TokenStore {
  SecureTokenStore({
    FlutterSecureStorage? storage,
    this.key = 'artrelay.oauth.tokens.v1',
  }) : _storage = storage ?? defaultClientSecureStorage;

  final FlutterSecureStorage _storage;
  final String key;

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: key);
    } on Object catch (error) {
      throw secureStorageFailure(
        code: 'token_store.clear_failed',
        message: 'Unable to clear the OAuth session from secure storage.',
        error: error,
      );
    }
  }

  @override
  Future<AuthTokens?> read() async {
    try {
      final encoded = await _storage.read(key: key);
      if (encoded == null) return null;
      final value = jsonDecode(encoded) as Map<String, Object?>;
      final rawScopes = value['scopes'] as List<Object?>? ?? const <Object?>[];
      return AuthTokens(
        accessToken: value['access_token']! as String,
        tokenType: value['token_type']! as String,
        expiresAt: DateTime.parse(value['expires_at']! as String).toUtc(),
        refreshToken: value['refresh_token'] as String?,
        scopes: rawScopes.cast<String>().toSet(),
      );
    } on ArtRelayException {
      rethrow;
    } on Object catch (error) {
      throw secureStorageFailure(
        code: 'token_store.read_failed',
        message: 'Unable to read or decode the OAuth session.',
        error: error,
      );
    }
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    final value = <String, Object?>{
      'access_token': tokens.accessToken,
      'token_type': tokens.tokenType,
      'expires_at': tokens.expiresAt.toUtc().toIso8601String(),
      'refresh_token': tokens.refreshToken,
      'scopes': tokens.scopes.toList(growable: false)..sort(),
    };
    try {
      await _storage.write(key: key, value: jsonEncode(value));
    } on Object catch (error) {
      throw secureStorageFailure(
        code: 'token_store.write_failed',
        message: 'Unable to persist the OAuth session securely.',
        error: error,
      );
    }
  }
}
