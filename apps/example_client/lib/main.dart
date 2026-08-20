import 'package:artrelay_flutter/artrelay_flutter.dart';
import 'package:flutter/material.dart';

import 'src/client_app.dart';
import 'src/client_controller.dart';
import 'src/diagnostic_log.dart';
import 'src/network_configuration.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final diagnostics = DiagnosticLog();
  const clientId = String.fromEnvironment('ARTRELAY_CLIENT_ID');
  late final NetworkProfile networkProfile;
  try {
    networkProfile = readExampleNetworkProfile();
  } on ArtRelayException catch (error) {
    final controller = ExampleClientController.configurationFailure(
      diagnostics: diagnostics,
      failure: error,
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
        )
      : _configuredController(
          clientId,
          diagnostics,
          networkProfile,
          connectivity,
        );
  runApp(ArtRelayExampleApp(controller: controller));
  controller.initialize();
}

ExampleClientController _configuredController(
  String clientId,
  DiagnosticLog diagnostics,
  NetworkProfile networkProfile,
  ConnectivityProbe connectivity,
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
  return ExampleClientController(
    diagnostics: diagnostics,
    resumeSession: oauth.resumePending,
    authorize: oauth.authorize,
    validTokens: oauth.validTokens,
    logout: oauth.logout,
    loadAccount: OfficialAccountRepository(transport).currentUser,
    loadHome: () =>
        OfficialArtworkRepository(transport)
            .browse(const PageRequest(limit: 12)),
    runConnectivity: connectivity.run,
  );
}
