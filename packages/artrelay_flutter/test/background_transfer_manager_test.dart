import 'dart:async';

import 'package:artrelay_core/artrelay_core.dart';
import 'package:artrelay_flutter/src/background_transfer_manager.dart';
import 'package:background_downloader/background_downloader.dart' as bg;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'enqueues the full asset with a safe filename and resumable task',
    () async {
      final backend = FakeTransferBackend();
      final manager = createBackgroundTransferManagerForTesting(
        backend: backend,
      );
      await manager.initialize();
      final asset = MediaAsset(
        id: 'art-1:original',
        kind: MediaKind.archive,
        role: MediaRole.original,
        availability: MediaAvailability.available,
        uri: Uri(
          scheme: 'https',
          host: 'files.example.test',
          path: '/download/archive.zip',
        ),
        filename: '../unsafe:archive.zip',
        byteLength: 50331648,
      );

      final snapshot = await manager.enqueue(
        TransferRequest(id: 'task-1', asset: asset),
      );

      final task = backend.enqueued.single;
      expect(snapshot.expectedBytes, 50331648);
      expect(snapshot.filename, 'unsafe_archive.zip');
      expect(task.url, asset.uri.toString());
      expect(task.allowPause, isTrue);
      expect(task.updates, bg.Updates.statusAndProgress);
      expect(task.headers, isEmpty);
      expect(task.group, BackgroundTransferManager.group);
      await manager.dispose();
    },
  );

  test(
    'maps native progress and failure updates into stable snapshots',
    () async {
      final backend = FakeTransferBackend();
      final manager = createBackgroundTransferManagerForTesting(
        backend: backend,
      );
      await manager.initialize();
      final task = bg.DownloadTask(
        taskId: 'task-1',
        url: 'https://files.example.test/file.bin',
        filename: 'file.bin',
        group: BackgroundTransferManager.group,
        baseDirectory: bg.BaseDirectory.root,
        directory: '/tmp',
      );
      final received = <TransferSnapshot>[];
      final subscription = manager.updates.listen(received.add);

      backend.controller.add(
        bg.TaskProgressUpdate(task, 0.5, 1000, 2, const Duration(seconds: 10)),
      );
      backend.controller.add(
        bg.TaskStatusUpdate(
          task,
          bg.TaskStatus.failed,
          bg.TaskConnectionException('connection reset'),
        ),
      );
      await pumpEventQueue();

      expect(received[0].state, TransferState.running);
      expect(received[0].expectedBytes, 1000);
      expect(received[0].networkBytesPerSecond, 2 * 1024 * 1024);
      expect(received[1].state, TransferState.failed);
      expect(received[1].failureCode, 'TaskConnectionException');
      await subscription.cancel();
      await manager.dispose();
    },
  );

  test(
    'restores persisted task records and controls pause resume cancel',
    () async {
      final backend = FakeTransferBackend();
      final task = bg.DownloadTask(
        taskId: 'task-1',
        url: 'https://files.example.test/file.bin',
        filename: 'file.bin',
        group: BackgroundTransferManager.group,
      );
      backend.stored['task-1'] = bg.TaskRecord(
        task,
        bg.TaskStatus.paused,
        0.4,
        1000,
      );
      final manager = createBackgroundTransferManagerForTesting(
        backend: backend,
      );
      await manager.initialize();

      final records = await manager.records();
      await manager.pause('task-1');
      await manager.resume('task-1');
      await manager.cancel('task-1');

      expect(records.single.state, TransferState.paused);
      expect(records.single.progress, 0.4);
      expect(backend.paused, <String>['task-1']);
      expect(backend.resumed, <String>['task-1']);
      expect(backend.cancelled, <String>['task-1']);
      await manager.dispose();
    },
  );

  test('configures and explicitly clears the transfer proxy', () async {
    final backend = FakeTransferBackend();
    final manager = createBackgroundTransferManagerForTesting(backend: backend);
    await manager.initialize();

    await manager.configureProxy(
      const ProxyConfiguration(host: '127.0.0.1', port: 7892),
    );
    await manager.configureProxy(null);

    expect(backend.proxies, hasLength(2));
    expect(backend.proxies.first?.host, '127.0.0.1');
    expect(backend.proxies.first?.port, 7892);
    expect(backend.proxies.last, isNull);
    await manager.dispose();
  });

  test('rejects unavailable assets before invoking the platform', () async {
    final backend = FakeTransferBackend();
    final manager = createBackgroundTransferManagerForTesting(backend: backend);
    await manager.initialize();

    await expectLater(
      manager.enqueue(
        const TransferRequest(
          id: 'task-1',
          asset: MediaAsset(
            id: 'restricted',
            kind: MediaKind.image,
            role: MediaRole.original,
            availability: MediaAvailability.loginRequired,
          ),
        ),
      ),
      throwsA(
        isA<ArtRelayException>().having(
          (error) => error.code,
          'code',
          'transfer.asset.unavailable',
        ),
      ),
    );
    expect(backend.enqueued, isEmpty);
    await manager.dispose();
  });
}

final class FakeTransferBackend implements BackgroundTransferBackend {
  final StreamController<bg.TaskUpdate> controller =
      StreamController<bg.TaskUpdate>.broadcast();
  final List<bg.DownloadTask> enqueued = <bg.DownloadTask>[];
  final Map<String, bg.TaskRecord> stored = <String, bg.TaskRecord>{};
  final List<String> paused = <String>[];
  final List<String> resumed = <String>[];
  final List<String> cancelled = <String>[];
  final List<ProxyConfiguration?> proxies = <ProxyConfiguration?>[];

  @override
  Stream<bg.TaskUpdate> get updates => controller.stream;

  @override
  Future<void> start() async {}

  @override
  Future<bool> enqueue(bg.DownloadTask task) async {
    enqueued.add(task);
    stored[task.taskId] = bg.TaskRecord(task, bg.TaskStatus.enqueued, 0, -1);
    return true;
  }

  @override
  Future<bg.TaskRecord?> recordForId(String id) async => stored[id];

  @override
  Future<List<bg.TaskRecord>> records(String group) async => stored.values
      .where((record) => record.group == group)
      .toList(growable: false);

  @override
  Future<bool> pause(bg.DownloadTask task) async {
    paused.add(task.taskId);
    return true;
  }

  @override
  Future<bool> resume(bg.DownloadTask task) async {
    resumed.add(task.taskId);
    return true;
  }

  @override
  Future<bool> cancel(String id) async {
    cancelled.add(id);
    return true;
  }

  @override
  Future<List<(String, String)>> configureProxy(
    ProxyConfiguration? proxy,
  ) async {
    proxies.add(proxy);
    return <(String, String)>[(bg.Config.proxy, '')];
  }
}
