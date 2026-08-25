import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Builds a Keychain-backed [FlutterSecureStorage] whose macOS keychain item is
/// identified with [serviceName] instead of the plugin default
/// `flutter_secure_storage_service`.
///
/// macOS shows that item name verbatim in its "…wants to use confidential
/// information stored in …" authorization prompt, so hosts should pass a
/// user-facing product name (for example `DAViewer`) rather than expose an
/// implementation detail that reads like a leak of arbitrary secrets.
///
/// The accessibility profile matches [defaultClientSecureStorage]:
/// `first_unlock_this_device` and no Data Protection Keychain, so ordinary
/// unsigned development builds keep working without an Apple provisioning
/// profile or Keychain Sharing entitlement.
FlutterSecureStorage clientSecureStorage({required String serviceName}) {
  return FlutterSecureStorage(
    aOptions: AndroidOptions(
      // A transient Keystore/decrypt failure must never wipe the session.
      // The plugin default resetOnError=true deletes the stored value on any
      // decryption error, which silently signs the user out after a restart.
      // With false the token survives; the next launch retries the read.
      resetOnError: false,
    ),
    mOptions: MacOsOptions(
      accountName: serviceName,
      label: serviceName,
      description: '$serviceName OAuth session',
      accessibility: KeychainAccessibility.first_unlock_this_device,
      usesDataProtectionKeychain: false,
    ),
  );
}
