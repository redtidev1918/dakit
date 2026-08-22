import 'dart:async';
import 'dart:ui' show Locale, Size;

import 'package:dakit_flutter/dakit_flutter.dart';
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
        transferManager: FakeTransferManager(),
        initialTransferProxy: null,
      );

      await tester.pumpWidget(DAKitExampleApp(controller: controller));

      expect(find.text('Client ID is not configured'), findsOneWidget);
      expect(find.textContaining('DAKIT_CLIENT_ID'), findsOneWidget);
      expect(find.textContaining('client secret'), findsOneWidget);
    },
  );

  testWidgets(
    'login updates the account and home content without manual refresh',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = ExampleClientController(
        diagnostics: DiagnosticLog(),
        resumeSession: ({waitForCallback = false}) async => null,
        authorize: () async => tokens,
        validTokens: ({forceRefresh = false}) async {
          throw const DAKitException(
            kind: DAKitFailureKind.authentication,
            code: 'oauth.session.missing',
            message: 'No session.',
          );
        },
        logout: ({revoke = true}) async {},
        loadAccount: () async => user,
        loadHome: () async =>
            Page<Artwork>(items: <Artwork>[artwork], hasMore: false),
        runConnectivity: successfulConnectivity,
        loadArtwork: (_) async => downloadableArtwork,
        resolveOriginal: (_) async => originalAsset,
        transferManager: FakeTransferManager(),
        initialTransferProxy: null,
      );
      await tester.pumpWidget(DAKitExampleApp(controller: controller));
      await controller.initialize();
      await tester.pump();

      await tester.tap(find.byKey(const Key('login-button')));
      await tester.pumpAndSettle();

      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('@sample-user'), findsOneWidget);
      expect(find.text('Example work'), findsOneWidget);
      expect(find.text('All four stages reached the service.'), findsOneWidget);

      final artworkTile = find.byKey(const Key('artwork-art-1'));
      await tester.ensureVisible(artworkTile);
      await tester.tap(artworkTile);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('artwork-detail')), findsOneWidget);
      expect(find.text('Original file'), findsOneWidget);
      expect(find.textContaining('48.0 MiB'), findsOneWidget);

      await tester.tap(find.byKey(const Key('download-original-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('queued · original.zip'), findsOneWidget);
    },
  );

  testWidgets('uses Simplified Chinese when requested by the host', (
    tester,
  ) async {
    final controller = ExampleClientController.unconfigured(
      diagnostics: DiagnosticLog(),
      transferManager: FakeTransferManager(),
      initialTransferProxy: null,
    );

    await tester.pumpWidget(
      DAKitExampleApp(controller: controller, locale: const Locale('zh', 'CN')),
    );

    expect(find.text('尚未配置 Client ID'), findsOneWidget);
    expect(find.text('网络链路'), findsOneWidget);
    expect(find.textContaining('诊断信息'), findsOneWidget);
  });
}

Future<ConnectivityReport> successfulConnectivity() async => ConnectivityReport(
  target: Uri.parse('https://example.test'),
  stages: <ConnectivityStageResult>[
    for (final stage in <DiagnosticStage>[
      DiagnosticStage.dns,
      DiagnosticStage.connect,
      DiagnosticStage.tls,
      DiagnosticStage.http,
    ])
      ConnectivityStageResult(
        stage: stage,
        succeeded: true,
        code: 'network.${stage.name}.ok',
        message: 'Success.',
        elapsed: Duration.zero,
      ),
  ],
);

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

final downloadableArtwork = Artwork(
  id: artwork.id,
  title: artwork.title,
  author: artwork.author,
  pageUri: artwork.pageUri,
  media: artwork.media,
  isDownloadable: true,
);

final originalAsset = MediaAsset(
  id: 'art-1:original',
  kind: MediaKind.archive,
  role: MediaRole.original,
  availability: MediaAvailability.available,
  uri: Uri.parse('https://files.example.test/original.zip'),
  filename: 'original.zip',
  byteLength: 50331648,
);

final class FakeTransferManager implements TransferManager {
  final StreamController<TransferSnapshot> controller =
      StreamController<TransferSnapshot>.broadcast();
  final Map<String, TransferSnapshot> snapshots = <String, TransferSnapshot>{};

  @override
  Stream<TransferSnapshot> get updates => controller.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<TransferSnapshot> enqueue(TransferRequest request) async {
    final snapshot = TransferSnapshot(
      id: request.id,
      state: TransferState.queued,
      progress: 0,
      filename: request.asset.filename,
      expectedBytes: request.asset.byteLength,
    );
    snapshots[snapshot.id] = snapshot;
    controller.add(snapshot);
    return snapshot;
  }

  @override
  Future<List<TransferSnapshot>> records() async => snapshots.values.toList();

  @override
  Future<void> pause(String id) async {}

  @override
  Future<void> resume(String id) async {}

  @override
  Future<void> cancel(String id) async {}

  @override
  Future<void> remove(String id) async {}

  @override
  Future<String?> moveToSharedStorage(
    String id,
    TransferSharedStorage destination,
  ) async => null;

  @override
  Future<void> configureProxy(ProxyConfiguration? proxy) async {}

  @override
  Future<void> dispose() => controller.close();
}
