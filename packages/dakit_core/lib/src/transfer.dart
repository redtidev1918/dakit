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

/// A system shared-storage destination a completed transfer can be moved into
/// (e.g. the public Downloads folder or the photo/video gallery).
enum TransferSharedStorage { downloads, images, video, audio, files }

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

  /// Removes a completed/terminated transfer from the persisted records (the
  /// downloaded file itself is left in place). Used to clear finished items
  /// from a download history without deleting the user's file.
  Future<void> remove(String id);

  /// Moves a completed transfer into a system shared-storage location (e.g. the
  /// public Downloads folder) without duplicating it, and re-emits the snapshot
  /// with the new [TransferSnapshot.localPath]. Returns the new path, or `null`
  /// when the move failed or is unsupported on this platform.
  Future<String?> moveToSharedStorage(
    String id,
    TransferSharedStorage destination,
  );

  Future<void> configureProxy(ProxyConfiguration? proxy);

  Future<void> dispose();
}
