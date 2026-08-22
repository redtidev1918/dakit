import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'clientSecureStorage labels the macOS keychain item with the host name',
    () {
      final storage = clientSecureStorage(serviceName: 'DAViewer');
      final options = storage.mOptions as MacOsOptions;

      expect(options.accountName, 'DAViewer');
      expect(options.label, 'DAViewer');
      expect(options.description, 'DAViewer OAuth session');
      expect(options.usesDataProtectionKeychain, isFalse);
      expect(
        options.accessibility,
        KeychainAccessibility.first_unlock_this_device,
      );
    },
  );
}
