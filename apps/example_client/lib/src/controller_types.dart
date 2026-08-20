import 'package:dakit_flutter/dakit_flutter.dart';

typedef LoadArtwork = Future<Artwork> Function(String id);
typedef ResolveOriginal = Future<MediaAsset> Function(String artworkId);
typedef ResumeSession = Future<AuthTokens?> Function({bool waitForCallback});
typedef Authorize = Future<AuthTokens> Function();
typedef ReadTokens = Future<AuthTokens> Function({bool forceRefresh});
typedef Logout = Future<void> Function({bool revoke});

enum ClientPhase {
  configurationRequired,
  restoring,
  signedOut,
  authorizing,
  loading,
  ready,
  failure,
}
