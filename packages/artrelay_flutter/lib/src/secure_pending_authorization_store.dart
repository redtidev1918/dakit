import 'dart:convert';

import 'package:artrelay_api/artrelay_api.dart';
import 'package:artrelay_core/artrelay_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'storage_failure.dart';

/// Persists PKCE state so a callback can survive application termination.
final class SecurePendingAuthorizationStore
    implements PendingAuthorizationStore {
  SecurePendingAuthorizationStore({
    FlutterSecureStorage? storage,
    this.key = 'artrelay.oauth.pending.v1',
  }) : _storage = storage ?? defaultClientSecureStorage;

  final FlutterSecureStorage _storage;
  final String key;

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: key);
    } on Object catch (error) {
      throw _failure('clear_failed', error);
    }
  }

  @override
  Future<PendingAuthorization?> read() async {
    try {
      final encoded = await _storage.read(key: key);
      if (encoded == null) return null;
      final raw = jsonDecode(encoded);
      if (raw is! Map) throw const FormatException('Expected JSON object.');
      final value = raw.map<String, Object?>(
        (key, item) => MapEntry(key.toString(), item),
      );
      final authorizationUri = Uri.parse(value['authorization_uri']! as String);
      final state = value['state']! as String;
      final codeVerifier = value['code_verifier']! as String;
      final createdAt = DateTime.parse(value['created_at']! as String).toUtc();
      if (!authorizationUri.isScheme('https') ||
          state.isEmpty ||
          codeVerifier.isEmpty) {
        throw const FormatException('Invalid pending authorization fields.');
      }
      return PendingAuthorization(
        authorizationUri: authorizationUri,
        state: state,
        codeVerifier: codeVerifier,
        createdAt: createdAt,
      );
    } on Object catch (error) {
      throw _failure('read_failed', error);
    }
  }

  @override
  Future<void> write(PendingAuthorization pending) async {
    final encoded = jsonEncode(<String, Object?>{
      'authorization_uri': pending.authorizationUri.toString(),
      'state': pending.state,
      'code_verifier': pending.codeVerifier,
      'created_at': pending.createdAt.toUtc().toIso8601String(),
    });
    try {
      await _storage.write(key: key, value: encoded);
    } on Object catch (error) {
      throw _failure('write_failed', error);
    }
  }

  static ArtRelayException _failure(String suffix, Object error) =>
      secureStorageFailure(
        code: 'pending_authorization_store.$suffix',
        message: 'Unable to access the pending OAuth transaction securely.',
        error: error,
      );
}
