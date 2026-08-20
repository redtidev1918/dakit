import 'package:dakit_core/dakit_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure defaults that work in unsigned macOS builds as well as mobile and
/// Windows hosts. macOS still uses Keychain, but avoids the Data Protection
/// Keychain entitlement that requires an Apple provisioning profile.
const defaultClientSecureStorage = FlutterSecureStorage(
  mOptions: MacOsOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    usesDataProtectionKeychain: false,
  ),
);

DAKitException secureStorageFailure({
  required String code,
  required String message,
  required Object error,
}) {
  final details = <String, Object?>{};
  if (error is PlatformException) {
    details['platform_code'] = error.code;
    final nativeDetails = error.details;
    if (nativeDetails is int || nativeDetails is String) {
      details['native_status'] = nativeDetails;
    }
  }
  return DAKitException(
    kind: DAKitFailureKind.storage,
    code: code,
    message: message,
    details: Map<String, Object?>.unmodifiable(details),
    cause: error,
  );
}
