import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dakit_core/dakit_core.dart';
import 'package:background_downloader/background_downloader.dart' as bg;
import 'package:path_provider/path_provider.dart';

abstract interface class BackgroundTransferBackend {
  Stream<bg.TaskUpdate> get updates;

  Future<void> start();

  Future<bool> enqueue(bg.DownloadTask task);

  Future<bg.TaskRecord?> recordForId(String id);

  Future<List<bg.TaskRecord>> records(String group);

  Future<bool> pause(bg.DownloadTask task);

  Future<bool> resume(bg.DownloadTask task);

  Future<bool> cancel(String id);

  Future<void> remove(String id);

  Future<String?> moveToSharedStorage(
    bg.DownloadTask task,
    bg.SharedStorage destination,
  );

  Future<List<(String, String)>> configureProxy(ProxyConfiguration? proxy);
}

final class FileDownloaderBackend implements BackgroundTransferBackend {
  FileDownloaderBackend({bg.FileDownloader? downloader})
    : _downloader = downloader ?? bg.FileDownloader();

  final bg.FileDownloader _downloader;

  @override
  Stream<bg.TaskUpdate> get updates => _downloader.updates;

  @override
  Future<void> start() => _downloader.start(autoCleanDatabase: true);

  @override
  Future<bool> enqueue(bg.DownloadTask task) => _downloader.enqueue(task);

  @override
  Future<bg.TaskRecord?> recordForId(String id) =>
      _downloader.database.recordForId(id);

  @override
  Future<List<bg.TaskRecord>> records(String group) =>
      _downloader.database.allRecords(group: group);

  @override
  Future<bool> pause(bg.DownloadTask task) => _downloader.pause(task);

  @override
  Future<bool> resume(bg.DownloadTask task) => _downloader.resume(task);

  @override
  Future<bool> cancel(String id) => _downloader.cancelTaskWithId(id);

  @override
  Future<void> remove(String id) => _downloader.database.deleteRecordWithId(id);

  @override
  Future<String?> moveToSharedStorage(
    bg.DownloadTask task,
    bg.SharedStorage destination,
  ) => _downloader.moveToSharedStorage(task, destination);

  @override
  Future<List<(String, String)>> configureProxy(ProxyConfiguration? proxy) =>
      _downloader.configure(
        globalConfig: proxy == null
            ? (bg.Config.proxy, false)
            : (bg.Config.proxy, (proxy.host, proxy.port)),
      );
}

/// Cross-platform recoverable transfer adapter backed by native schedulers.
final class BackgroundTransferManager implements TransferManager {
  factory BackgroundTransferManager({
    DiagnosticSink diagnostics = const NoopDiagnosticSink(),
  }) => BackgroundTransferManager._(FileDownloaderBackend(), diagnostics);

  BackgroundTransferManager._(this._backend, this._diagnostics) {
    _subscription = _backend.updates.listen(
      _queueUpdate,
      onError: _streamError,
    );
  }

  static const String group = 'dakit.transfer.v1';

  final BackgroundTransferBackend _backend;
  final DiagnosticSink _diagnostics;
  final StreamController<TransferSnapshot> _updates =
      StreamController<TransferSnapshot>.broadcast();
  final Map<String, TransferSnapshot> _latest = <String, TransferSnapshot>{};
  final Map<String, String> _movedPaths = <String, String>{};
  late final StreamSubscription<bg.TaskUpdate> _subscription;
  Future<void> _updateTail = Future<void>.value();
  bool _initialized = false;
  bool _disposed = false;

  @override
  Stream<TransferSnapshot> get updates => _updates.stream;

  @override
  Future<void> initialize() async {
    _ensureOpen();
    if (_initialized) return;
    await _backend.start();
    await _loadMovedPaths();
    _initialized = true;
    _record('transfer.manager.ready', DiagnosticLevel.info);
  }

  @override
  Future<TransferSnapshot> enqueue(TransferRequest request) async {
    _ensureReady();
    final uri = request.asset.uri;
    if (request.id.trim().isEmpty ||
        request.retries < 0 ||
        request.retries > 10) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'transfer.request.invalid',
        message: 'Transfer ID and retry count are invalid.',
      );
    }
    if (!request.asset.canTransfer || uri == null) {
      throw const DAKitException(
        kind: DAKitFailureKind.restricted,
        code: 'transfer.asset.unavailable',
        message: 'The selected media asset is not transferable.',
      );
    }
    if (!uri.isScheme('https')) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'transfer.url.insecure',
        message: 'Media transfers require an HTTPS URL.',
      );
    }
    if (await _backend.recordForId(request.id) != null) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'transfer.id.duplicate',
        message: 'A transfer with this ID already exists.',
      );
    }

    final filename = _safeFilename(
      request.filename ?? request.asset.filename ?? uri.pathSegments.lastOrNull,
      fallback: '${request.id}.bin',
    );
    final task = bg.DownloadTask(
      taskId: request.id,
      url: uri.toString(),
      filename: filename,
      directory: 'DAKit',
      baseDirectory: _baseDirectory(request.directory),
      group: group,
      updates: bg.Updates.statusAndProgress,
      requiresWiFi: request.requiresWifi,
      retries: request.retries,
      allowPause: true,
      displayName: filename,
      metaData: request.asset.id,
    );
    if (!await _backend.enqueue(task)) {
      throw const DAKitException(
        kind: DAKitFailureKind.transfer,
        code: 'transfer.enqueue.failed',
        message: 'The platform scheduler rejected the transfer.',
        retryable: true,
      );
    }
    final snapshot = TransferSnapshot(
      id: request.id,
      state: TransferState.queued,
      progress: 0,
      filename: filename,
      expectedBytes: request.asset.byteLength,
    );
    _emit(snapshot);
    return snapshot;
  }

  @override
  Future<List<TransferSnapshot>> records() async {
    _ensureReady();
    final records = await _backend.records(group);
    return Future.wait(records.map(_snapshotFromRecord));
  }

  @override
  Future<void> pause(String id) async {
    final task = await _task(id);
    if (!await _backend.pause(task)) {
      throw _operationFailure('pause');
    }
  }

  @override
  Future<void> resume(String id) async {
    final task = await _task(id);
    if (!await _backend.resume(task)) {
      throw _operationFailure('resume');
    }
  }

  @override
  Future<void> cancel(String id) async {
    _ensureReady();
    if (!await _backend.cancel(id)) throw _operationFailure('cancel');
  }

  @override
  Future<void> remove(String id) async {
    _ensureReady();
    await _backend.remove(id);
    _latest.remove(id);
    _movedPaths.remove(id);
    await _persistMovedPaths();
  }

  @override
  Future<String?> moveToSharedStorage(
    String id,
    TransferSharedStorage destination,
  ) async {
    _ensureReady();
    final task = await _task(id);
    final newPath = await _backend.moveToSharedStorage(
      task,
      _sharedStorage(destination),
    );
    if (newPath == null || newPath.isEmpty) return null;
    _movedPaths[id] = newPath;
    await _persistMovedPaths();
    final previous = _latest[id];
    if (previous != null) {
      _emit(
        TransferSnapshot(
          id: previous.id,
          state: previous.state,
          progress: previous.progress,
          filename: previous.filename,
          localPath: newPath,
          expectedBytes: previous.expectedBytes,
        ),
      );
    }
    return newPath;
  }

  @override
  Future<void> configureProxy(ProxyConfiguration? proxy) async {
    _ensureReady();
    if (proxy != null &&
        (proxy.host.trim().isEmpty || proxy.port <= 0 || proxy.port > 65535)) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'transfer.proxy.invalid',
        message: 'Proxy host and port are invalid.',
      );
    }
    final results = await _backend.configureProxy(proxy);
    final failures = results.where((result) => result.$2.trim().isNotEmpty);
    if (failures.isNotEmpty) {
      throw DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'transfer.proxy.unsupported',
        message: 'The platform rejected the transfer proxy configuration.',
        details: <String, Object?>{
          'responses': failures.map((item) => '${item.$1}:${item.$2}').toList(),
        },
      );
    }
    _record(
      proxy == null ? 'transfer.proxy.cleared' : 'transfer.proxy.configured',
      DiagnosticLevel.info,
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription.cancel();
    await _updateTail;
    await _updates.close();
  }

  Future<bg.DownloadTask> _task(String id) async {
    _ensureReady();
    final record = await _backend.recordForId(id);
    final task = record?.task;
    if (task is! bg.DownloadTask) {
      throw const DAKitException(
        kind: DAKitFailureKind.notFound,
        code: 'transfer.task.not_found',
        message: 'The transfer task does not exist.',
      );
    }
    return task;
  }

  void _queueUpdate(bg.TaskUpdate update) {
    _updateTail = _updateTail.then((_) => _handleUpdate(update));
  }

  void _streamError(Object error, StackTrace stackTrace) {
    _record(
      'transfer.update_stream.failed',
      DiagnosticLevel.error,
      attributes: <String, Object?>{'failure_code': 'unexpected'},
    );
  }

  Future<void> _handleUpdate(bg.TaskUpdate update) async {
    if (update.task.group != group || _disposed) return;
    switch (update) {
      case bg.TaskProgressUpdate progress:
        final previous = _latest[progress.task.taskId];
        _emit(
          TransferSnapshot(
            id: progress.task.taskId,
            state: previous?.state ?? TransferState.running,
            progress: progress.progress.clamp(0, 1),
            filename: progress.task.filename,
            expectedBytes: progress.hasExpectedFileSize
                ? progress.expectedFileSize
                : previous?.expectedBytes,
            networkBytesPerSecond: progress.hasNetworkSpeed
                ? (progress.networkSpeed * 1024 * 1024).round()
                : null,
            timeRemaining: progress.hasTimeRemaining
                ? progress.timeRemaining
                : null,
          ),
        );
      case bg.TaskStatusUpdate status:
        final state = _state(status.status);
        final path = state == TransferState.completed
            ? await status.task.filePath()
            : null;
        final previous = _latest[status.task.taskId];
        _emit(
          TransferSnapshot(
            id: status.task.taskId,
            state: state,
            progress: state == TransferState.completed
                ? 1
                : previous?.progress ?? 0,
            filename: status.task.filename,
            localPath: path,
            expectedBytes: previous?.expectedBytes,
            failureCode: status.exception?.exceptionType,
            failureMessage: status.exception?.description,
          ),
        );
    }
  }

  Future<TransferSnapshot> _snapshotFromRecord(bg.TaskRecord record) async {
    final state = _state(record.status);
    return TransferSnapshot(
      id: record.taskId,
      state: state,
      progress: record.progress.clamp(0, 1),
      filename: record.task.filename,
      localPath: state == TransferState.completed
          ? _movedPaths[record.taskId] ?? await record.task.filePath()
          : null,
      expectedBytes: record.expectedFileSize >= 0
          ? record.expectedFileSize
          : null,
      failureCode: record.exception?.exceptionType,
      failureMessage: record.exception?.description,
    );
  }

  Future<File> _movedPathsFile() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}dakit_moved_paths.json');
  }

  Future<void> _loadMovedPaths() async {
    try {
      final file = await _movedPathsFile();
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return;
      _movedPaths
        ..clear()
        ..addAll(
          decoded.map((key, value) => MapEntry(key.toString(), '$value')),
        );
    } on Object {
      // A corrupt or unreadable file must not block the manager.
    }
  }

  Future<void> _persistMovedPaths() async {
    try {
      final file = await _movedPathsFile();
      await file.writeAsString(jsonEncode(_movedPaths), flush: true);
    } on Object {
      // Best effort; the in-memory map still serves the current session.
    }
  }

  void _emit(TransferSnapshot snapshot) {
    _latest[snapshot.id] = snapshot;
    if (!_updates.isClosed) _updates.add(snapshot);
    _record(
      'transfer.state.${snapshot.state.name}',
      snapshot.state == TransferState.failed
          ? DiagnosticLevel.error
          : DiagnosticLevel.info,
      attributes: <String, Object?>{
        'task_id': snapshot.id,
        'progress': snapshot.progress,
        if (snapshot.failureCode != null) 'failure_code': snapshot.failureCode!,
      },
    );
  }

  void _record(
    String code,
    DiagnosticLevel level, {
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    _diagnostics.add(
      DiagnosticEvent(
        stage: DiagnosticStage.transfer,
        level: level,
        code: code,
        message: 'Background transfer event.',
        attributes: attributes,
      ),
    );
  }

  void _ensureReady() {
    _ensureOpen();
    if (!_initialized) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'transfer.manager.not_initialized',
        message: 'Initialize the transfer manager before using it.',
      );
    }
  }

  void _ensureOpen() {
    if (_disposed) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'transfer.manager.disposed',
        message: 'The transfer manager has already been disposed.',
      );
    }
  }

  static DAKitException _operationFailure(String operation) => DAKitException(
    kind: DAKitFailureKind.transfer,
    code: 'transfer.$operation.failed',
    message: 'The platform could not $operation the transfer.',
    retryable: true,
  );

  static bg.BaseDirectory _baseDirectory(TransferDirectory directory) =>
      switch (directory) {
        TransferDirectory.applicationDocuments =>
          bg.BaseDirectory.applicationDocuments,
        TransferDirectory.applicationSupport =>
          bg.BaseDirectory.applicationSupport,
        TransferDirectory.temporary => bg.BaseDirectory.temporary,
      };

  static bg.SharedStorage _sharedStorage(TransferSharedStorage destination) =>
      switch (destination) {
        TransferSharedStorage.downloads => bg.SharedStorage.downloads,
        TransferSharedStorage.images => bg.SharedStorage.images,
        TransferSharedStorage.video => bg.SharedStorage.video,
        TransferSharedStorage.audio => bg.SharedStorage.audio,
        TransferSharedStorage.files => bg.SharedStorage.files,
      };

  static TransferState _state(bg.TaskStatus state) => switch (state) {
    bg.TaskStatus.enqueued => TransferState.queued,
    bg.TaskStatus.running => TransferState.running,
    bg.TaskStatus.waitingToRetry => TransferState.retrying,
    bg.TaskStatus.paused => TransferState.paused,
    bg.TaskStatus.complete => TransferState.completed,
    bg.TaskStatus.notFound => TransferState.notFound,
    bg.TaskStatus.failed => TransferState.failed,
    bg.TaskStatus.canceled => TransferState.cancelled,
  };

  static String _safeFilename(String? value, {required String fallback}) {
    final leaf = value?.split(RegExp(r'[/\\]')).last.trim() ?? '';
    final sanitized = leaf
        .replaceAll(RegExp(r'[\x00-\x1f<>:"|?*]'), '_')
        .replaceAll(RegExp(r'^\.+$'), '')
        .trim();
    return sanitized.isEmpty ? fallback : sanitized;
  }
}

BackgroundTransferManager createBackgroundTransferManagerForTesting({
  required BackgroundTransferBackend backend,
  DiagnosticSink diagnostics = const NoopDiagnosticSink(),
}) => BackgroundTransferManager._(backend, diagnostics);

extension on List<String> {
  String? get lastOrNull => isEmpty ? null : last;
}
