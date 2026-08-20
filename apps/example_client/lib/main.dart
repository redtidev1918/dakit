import 'dart:async';

import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';

import 'src/client_app.dart';
import 'src/client_controller.dart';
import 'src/client_runtime.dart';
import 'src/diagnostic_log.dart';
import 'src/network_configuration.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final diagnostics = DiagnosticLog();
  final transfers = BackgroundTransferManager(diagnostics: diagnostics);
  const clientId = String.fromEnvironment('DAKIT_CLIENT_ID');
  late final NetworkProfile networkProfile;
  late final ProxyConfiguration? transferProxy;
  try {
    networkProfile = readExampleNetworkProfile();
    transferProxy = readExampleTransferProxy();
  } on DAKitException catch (error) {
    final controller = ExampleClientController.configurationFailure(
      diagnostics: diagnostics,
      failure: error,
      transferManager: transfers,
      initialTransferProxy: null,
    );
    runApp(DAKitExampleApp(controller: controller));
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
          diagnostics,
          networkProfile,
          connectivity,
          transfers,
          transferProxy,
        );
  runApp(DAKitExampleApp(controller: controller));
  unawaited(_initialize(controller));
}

Future<void> _initialize(ExampleClientController controller) async {
  await controller.initialize();
  const autoAuthorize = bool.fromEnvironment('DAKIT_AUTO_AUTHORIZE');
  if (autoAuthorize && controller.phase == ClientPhase.signedOut) {
    await controller.login();
  }
}

ExampleClientController _configuredController(
  DiagnosticLog diagnostics,
  NetworkProfile networkProfile,
  ConnectivityProbe connectivity,
  TransferManager transfers,
  ProxyConfiguration? transferProxy,
) {
  const clientId = String.fromEnvironment('DAKIT_CLIENT_ID');
  final oauth = DAKitOAuthClient(
    config: OAuthConfig(
      clientId: clientId,
      redirectUri: Uri.parse('dakit://oauth/callback'),
    ),
    networkProfile: networkProfile,
    diagnostics: diagnostics,
  );
  final transport = OfficialApiClient(
    session: oauth.session,
    diagnostics: diagnostics,
    config: ApiConfig(userAgent: 'DAKit-Example/0.1'),
    networkProfile: networkProfile,
  );
  final runtime = ClientRuntime(
    oauth: oauth,
    transport: transport,
    connectivity: connectivity,
    transfers: transfers,
    transferProxy: transferProxy,
  );
  return ExampleClientController(
    diagnostics: diagnostics,
    resumeSession: oauth.resumePending,
    authorize: oauth.authorize,
    validTokens: oauth.validTokens,
    logout: oauth.logout,
    loadAccount: runtime.accountRepository.currentUser,
    loadHome: () =>
        runtime.artworkRepository.browse(const PageRequest(limit: 12)),
    runConnectivity: connectivity.run,
    loadArtwork: runtime.artworkRepository.getById,
    resolveOriginal: runtime.mediaRepository.originalFile,
    transferManager: transfers,
    initialTransferProxy: transferProxy,
  );
}
