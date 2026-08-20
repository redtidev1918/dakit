import 'package:artrelay_flutter/artrelay_flutter.dart';
import 'package:flutter/material.dart';

import 'src/client_app.dart';
import 'src/client_controller.dart';
import 'src/diagnostic_log.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final diagnostics = DiagnosticLog();
  const clientId = String.fromEnvironment('ARTRELAY_CLIENT_ID');
  final controller = clientId.isEmpty
      ? ExampleClientController.unconfigured(diagnostics: diagnostics)
      : _configuredController(clientId, diagnostics);
  runApp(ArtRelayExampleApp(controller: controller));
  controller.initialize();
}

ExampleClientController _configuredController(
  String clientId,
  DiagnosticLog diagnostics,
) {
  final oauth = ArtRelayOAuthClient(
    config: OAuthConfig(
      clientId: clientId,
      redirectUri: Uri.parse('artrelay://oauth/callback'),
    ),
    diagnostics: diagnostics,
  );
  final transport = OfficialApiClient(
    session: oauth.session,
    diagnostics: diagnostics,
    config: ApiConfig(userAgent: 'ArtRelay-Example/0.1'),
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
  );
}
