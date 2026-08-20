import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test(
    'secure store restores a pending PKCE transaction after restart',
    () async {
      final store = SecurePendingAuthorizationStore();
      final pending = PendingAuthorization(
        authorizationUri: Uri(
          scheme: 'https',
          host: 'www.deviantart.com',
          path: '/oauth2/authorize',
        ),
        state: 'secret-state',
        codeVerifier: 'secret-verifier',
        createdAt: DateTime.utc(2026, 8, 20, 12),
      );

      await store.write(pending);
      final restored = await store.read();

      expect(restored?.authorizationUri, pending.authorizationUri);
      expect(restored?.state, pending.state);
      expect(restored?.codeVerifier, pending.codeVerifier);
      expect(restored?.createdAt, pending.createdAt);
    },
  );
}
