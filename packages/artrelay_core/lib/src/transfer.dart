import 'media.dart';

enum TransferState {
  queued,
  running,
  retrying,
  paused,
  completed,
  notFound,
  failed,
  cancelled,
}

enum TransferDirectory { applicationDocuments, applicationSupport, temporary }

final class TransferRequest {
  const TransferRequest({
    required this.id,
    required this.asset,
    this.directory = TransferDirectory.applicationDocuments,
    this.filename,
    this.requiresWifi = false,
    this.retries = 3,
  });

  final String id;
  final MediaAsset asset;
  final TransferDirectory directory;
  final String? filename;
  final bool requiresWifi;
  final int retries;
}

final class TransferSnapshot {
  const TransferSnapshot({
    required this.id,
    required this.state,
    required this.progress,
    this.filename,
    this.localPath,
    this.expectedBytes,
    this.networkBytesPerSecond,
    this.timeRemaining,
    this.failureCode,
    this.failureMessage,
  });

  final String id;
  final TransferState state;
  final double progress;
  final String? filename;
  final String? localPath;
  final int? expectedBytes;
  final int? networkBytesPerSecond;
  final Duration? timeRemaining;
  final String? failureCode;
  final String? failureMessage;

  bool get isFinal => switch (state) {
    TransferState.completed ||
    TransferState.notFound ||
    TransferState.failed ||
    TransferState.cancelled => true,
    _ => false,
  };
}

final class ProxyConfiguration {
  const ProxyConfiguration({required this.host, required this.port});

  final String host;
  final int port;
}

abstract interface class TransferManager {
  Stream<TransferSnapshot> get updates;

  Future<void> initialize();

  Future<TransferSnapshot> enqueue(TransferRequest request);

  Future<List<TransferSnapshot>> records();

  Future<void> pause(String id);

  Future<void> resume(String id);

  Future<void> cancel(String id);

  Future<void> configureProxy(ProxyConfiguration? proxy);

  Future<void> dispose();
}
