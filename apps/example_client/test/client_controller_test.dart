import 'dart:async';

import 'package:artrelay_flutter/artrelay_flutter.dart';
import 'package:example_client/src/client_controller.dart';
import 'package:example_client/src/diagnostic_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('never resolves a preview-only artwork as an original', () async {
    var originalCalls = 0;
    final manager = MemoryTransferManager();
    final controller = createController(
      manager: manager,
      loadArtwork: (_) async => previewOnly,
      resolveOriginal: (_) async {
        originalCalls += 1;
        return original;
      },
    );

    await controller.openArtwork(previewOnly.id);

    expect(controller.selectedArtwork, same(previewOnly));
    expect(controller.selectedOriginal, isNull);
    expect(originalCalls, 0);
    controller.dispose();
  });

  test('a late detail response cannot overwrite a newer selection', () async {
    final firstOriginal = Completer<MediaAsset>();
    final manager = MemoryTransferManager();
    final controller = createController(
      manager: manager,
      loadArtwork: (id) async => id == first.id ? first : second,
      resolveOriginal: (id) => id == first.id
          ? firstOriginal.future
          : Future<MediaAsset>.value(secondAsset),
    );

    final firstLoad = controller.openArtwork(first.id);
    await pumpEventQueue();
    await controller.openArtwork(second.id);
    firstOriginal.complete(original);
    await firstLoad;

    expect(controller.selectedArtwork?.id, second.id);
    expect(controller.selectedOriginal?.id, secondAsset.id);
    controller.dispose();
  });

  test(
    'restores transfers and explicitly configures their own proxy',
    () async {
      final manager = MemoryTransferManager(
        restored: const <TransferSnapshot>[
          TransferSnapshot(
            id: 'original_art-1_1',
            state: TransferState.paused,
            progress: 0.4,
          ),
        ],
      );
      final controller = createController(
        manager: manager,
        initialTransferProxy: const ProxyConfiguration(
          host: '127.0.0.1',
          port: 7892,
        ),
      );

      await controller.initialize();

      expect(manager.initialized, isTrue);
      expect(manager.proxy?.host, '127.0.0.1');
      expect(controller.transfers.values.single.state, TransferState.paused);
      controller.dispose();
    },
  );

  test('enqueues and controls the selected original transfer', () async {
    final manager = MemoryTransferManager();
    final controller = createController(manager: manager);
    await controller.initialize();
    await controller.openArtwork(first.id);

    await controller.downloadOriginal();
    await controller.pauseTransfer();
    await controller.resumeTransfer();
    await controller.cancelTransfer();

    expect(manager.enqueued.single.asset.role, MediaRole.original);
    expect(manager.paused.single, startsWith('original_art-1_'));
    expect(manager.resumed, manager.paused);
    expect(manager.cancelled, manager.paused);
    controller.dispose();
  });
}

ExampleClientController createController({
  required MemoryTransferManager manager,
  LoadArtwork? loadArtwork,
  ResolveOriginal? resolveOriginal,
  ProxyConfiguration? initialTransferProxy,
}) => ExampleClientController(
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
  loadHome: () async => Page<Artwork>(items: const [], hasMore: false),
  runConnectivity: () async => ConnectivityReport(
    target: Uri.parse('https://example.test'),
    stages: const <ConnectivityStageResult>[],
  ),
  loadArtwork: loadArtwork ?? (_) async => first,
  resolveOriginal: resolveOriginal ?? (_) async => original,
  transferManager: manager,
  initialTransferProxy: initialTransferProxy,
);

final tokens = AuthTokens(
  accessToken: 'access',
  tokenType: 'Bearer',
  expiresAt: DateTime.utc(2026, 8, 20, 13),
);

const user = UserProfile(id: 'user-1', username: 'sample-user');

final first = Artwork(
  id: 'art-1',
  title: 'First',
  author: user,
  pageUri: Uri.parse('https://example.test/art-1'),
  media: const <MediaAsset>[],
  isDownloadable: true,
);

final second = Artwork(
  id: 'art-2',
  title: 'Second',
  author: user,
  pageUri: Uri.parse('https://example.test/art-2'),
  media: const <MediaAsset>[],
  isDownloadable: true,
);

final previewOnly = Artwork(
  id: 'preview',
  title: 'Preview',
  author: user,
  pageUri: Uri.parse('https://example.test/preview'),
  media: const <MediaAsset>[],
);

final original = MediaAsset(
  id: 'art-1:original',
  kind: MediaKind.archive,
  role: MediaRole.original,
  availability: MediaAvailability.available,
  uri: Uri.parse('https://files.example.test/first.zip'),
  filename: 'first.zip',
);

final secondAsset = MediaAsset(
  id: 'art-2:original',
  kind: MediaKind.image,
  role: MediaRole.original,
  availability: MediaAvailability.available,
  uri: Uri.parse('https://files.example.test/second.png'),
  filename: 'second.png',
);

final class MemoryTransferManager implements TransferManager {
  MemoryTransferManager({this.restored = const <TransferSnapshot>[]});

  final List<TransferSnapshot> restored;
  final StreamController<TransferSnapshot> controller =
      StreamController<TransferSnapshot>.broadcast();
  final List<TransferRequest> enqueued = <TransferRequest>[];
  final List<String> paused = <String>[];
  final List<String> resumed = <String>[];
  final List<String> cancelled = <String>[];
  bool initialized = false;
  ProxyConfiguration? proxy;

  @override
  Stream<TransferSnapshot> get updates => controller.stream;

  @override
  Future<void> initialize() async => initialized = true;

  @override
  Future<TransferSnapshot> enqueue(TransferRequest request) async {
    enqueued.add(request);
    final snapshot = TransferSnapshot(
      id: request.id,
      state: TransferState.queued,
      progress: 0,
      filename: request.asset.filename,
    );
    controller.add(snapshot);
    return snapshot;
  }

  @override
  Future<List<TransferSnapshot>> records() async => restored;

  @override
  Future<void> pause(String id) async => paused.add(id);

  @override
  Future<void> resume(String id) async => resumed.add(id);

  @override
  Future<void> cancel(String id) async => cancelled.add(id);

  @override
  Future<void> configureProxy(ProxyConfiguration? proxy) async {
    this.proxy = proxy;
  }

  @override
  Future<void> dispose() => controller.close();
}
