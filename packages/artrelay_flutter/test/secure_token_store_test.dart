import 'package:artrelay_flutter/artrelay_flutter.dart';
import 'package:artrelay_flutter/src/storage_failure.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('secure store round-trips a session without losing scopes', () async {
    final store = SecureTokenStore();
    final tokens = AuthTokens(
      accessToken: 'secret-access-token',
      tokenType: 'Bearer',
      expiresAt: DateTime.utc(2026, 8, 20, 13),
      refreshToken: 'secret-refresh-token',
      scopes: const <String>{'browse', 'basic'},
    );

    await store.write(tokens);
    final restored = await store.read();

    expect(restored?.accessToken, tokens.accessToken);
    expect(restored?.refreshToken, tokens.refreshToken);
    expect(restored?.scopes, tokens.scopes);
    expect(restored?.expiresAt, tokens.expiresAt);
  });

  test('macOS defaults do not require a provisioning profile', () {
    final options = defaultClientSecureStorage.mOptions as MacOsOptions;

    expect(options.usesDataProtectionKeychain, isFalse);
    expect(
      options.accessibility,
      KeychainAccessibility.first_unlock_this_device,
    );
    expect(options.groupId, isNull);
  });
}
