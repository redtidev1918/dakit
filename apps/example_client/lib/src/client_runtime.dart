import 'package:dakit_flutter/dakit_flutter.dart';

/// Composition root for the example client.
///
/// Keeps transport, repositories, OAuth, connectivity, and transfers as one
/// injectable bundle so `main.dart` stays small and the controller receives
/// already-wired dependencies instead of rebuilding them.
final class ClientRuntime {
  ClientRuntime({
    required this.oauth,
    required this.transport,
    required this.connectivity,
    required this.transfers,
    required this.transferProxy,
  });

  final DAKitOAuthClient oauth;
  final OfficialApiClient transport;
  final ConnectivityProbe connectivity;
  final TransferManager transfers;
  final ProxyConfiguration? transferProxy;

  OfficialAccountRepository get accountRepository =>
      OfficialAccountRepository(transport);

  OfficialArtworkRepository get artworkRepository =>
      OfficialArtworkRepository(transport);

  OfficialMediaRepository get mediaRepository =>
      OfficialMediaRepository(transport);
}
