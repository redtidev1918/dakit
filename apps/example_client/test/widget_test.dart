import 'package:artrelay_flutter/artrelay_flutter.dart';
import 'package:example_client/src/client_app.dart';
import 'package:example_client/src/client_controller.dart';
import 'package:example_client/src/diagnostic_log.dart';
import 'package:flutter/foundation.dart' show Key;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shows an actionable command instead of a blank configuration screen',
    (tester) async {
      final controller = ExampleClientController.unconfigured(
        diagnostics: DiagnosticLog(),
      );

      await tester.pumpWidget(ArtRelayExampleApp(controller: controller));

      expect(find.text('Client ID is not configured'), findsOneWidget);
      expect(find.textContaining('ARTRELAY_CLIENT_ID'), findsOneWidget);
      expect(find.textContaining('client secret'), findsOneWidget);
    },
  );

  testWidgets(
    'login updates the account and home content without manual refresh',
    (tester) async {
      final controller = ExampleClientController(
        diagnostics: DiagnosticLog(),
        resumeSession: ({waitForCallback = false}) async => null,
        authorize: () async => tokens,
        validTokens: ({forceRefresh = false}) async {
          throw const ArtRelayException(
            kind: ArtRelayFailureKind.authentication,
            code: 'oauth.session.missing',
            message: 'No session.',
          );
        },
        logout: ({revoke = true}) async {},
        loadAccount: () async => user,
        loadHome: () async =>
            Page<Artwork>(items: <Artwork>[artwork], hasMore: false),
      );
      await tester.pumpWidget(ArtRelayExampleApp(controller: controller));
      await controller.initialize();
      await tester.pump();

      await tester.tap(find.byKey(const Key('login-button')));
      await tester.pumpAndSettle();

      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('@sample-user'), findsOneWidget);
      expect(find.text('Example work'), findsOneWidget);
    },
  );
}

final tokens = AuthTokens(
  accessToken: 'access',
  tokenType: 'Bearer',
  expiresAt: DateTime.utc(2026, 8, 20, 13),
);

const user = UserProfile(id: 'user-1', username: 'sample-user');

final artwork = Artwork(
  id: 'art-1',
  title: 'Example work',
  author: user,
  pageUri: Uri.parse('https://example.test/art-1'),
  media: const <MediaAsset>[],
);
