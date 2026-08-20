import 'dart:async';

import 'package:artrelay_flutter/artrelay_flutter.dart';
import 'package:flutter/material.dart';

import 'src/client_app.dart';
import 'src/client_controller.dart';
import 'src/diagnostic_log.dart';
import 'src/network_configuration.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final diagnostics = DiagnosticLog();
  final transfers = BackgroundTransferManager(diagnostics: diagnostics);
  const clientId = String.fromEnvironment('ARTRELAY_CLIENT_ID');
  late final NetworkProfile networkProfile;
  late final ProxyConfiguration? transferProxy;
  try {
    networkProfile = readExampleNetworkProfile();
    transferProxy = readExampleTransferProxy();
  } on ArtRelayException catch (error) {
    final controller = ExampleClientController.configurationFailure(
      diagnostics: diagnostics,
      failure: error,
      transferManager: transfers,
      initialTransferProxy: null,
    );
    runApp(ArtRelayExampleApp(controller: controller));
    return;
  }
  final connectivity = ConnectivityProbe(
    target: Uri.https('www.deviantart.com', '/'),
    profile: networkProfile,
    diagnostics: diagnostics,
  );
  final controller = clientId.isEmpty
      ? ExampleClientController.unconfigured(
          diagnostics: diagnostics,
          runConnectivity: connectivity.run,
          transferManager: transfers,
          initialTransferProxy: transferProxy,
        )
      : _configuredController(
          clientId,
          diagnostics,
          networkProfile,
          connectivity,
          transfers,
          transferProxy,
        );
  runApp(ArtRelayExampleApp(controller: controller));
  unawaited(_initialize(controller));
}

Future<void> _initialize(ExampleClientController controller) async {
  await controller.initialize();
  const autoAuthorize = bool.fromEnvironment('ARTRELAY_AUTO_AUTHORIZE');
  if (autoAuthorize && controller.phase == ClientPhase.signedOut) {
    await controller.login();
  }
}

ExampleClientController _configuredController(
  String clientId,
  DiagnosticLog diagnostics,
  NetworkProfile networkProfile,
  ConnectivityProbe connectivity,
  TransferManager transfers,
  ProxyConfiguration? transferProxy,
) {
  final oauth = ArtRelayOAuthClient(
    config: OAuthConfig(
      clientId: clientId,
      redirectUri: Uri.parse('artrelay://oauth/callback'),
    ),
    networkProfile: networkProfile,
    diagnostics: diagnostics,
  );
  final transport = OfficialApiClient(
    session: oauth.session,
    diagnostics: diagnostics,
    config: ApiConfig(userAgent: 'ArtRelay-Example/0.1'),
    networkProfile: networkProfile,
  );
  final artworks = OfficialArtworkRepository(transport);
  final media = OfficialMediaRepository(transport);
  return ExampleClientController(
    diagnostics: diagnostics,
    resumeSession: oauth.resumePending,
    authorize: oauth.authorize,
    validTokens: oauth.validTokens,
    logout: oauth.logout,
    loadAccount: OfficialAccountRepository(transport).currentUser,
    loadHome: () => artworks.browse(const PageRequest(limit: 12)),
    runConnectivity: connectivity.run,
    loadArtwork: artworks.getById,
    resolveOriginal: media.originalFile,
    transferManager: transfers,
    initialTransferProxy: transferProxy,
  );
}
