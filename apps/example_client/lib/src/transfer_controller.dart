import 'dart:async';

import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/foundation.dart';

final class TransferController extends ChangeNotifier {
  TransferController({required this.manager, this.initialProxy}) {
    _subscription = manager.updates.listen(
      _onUpdate,
      onError: (Object error, StackTrace stackTrace) {
        transferFailure = _unexpected(error);
        notifyListeners();
      },
    );
  }

  final TransferManager manager;
  final ProxyConfiguration? initialProxy;
  final Map<String, TransferSnapshot> transfers = <String, TransferSnapshot>{};
  DAKitException? transferFailure;
  bool schedulingTransfer = false;
  bool controllingTransfer = false;
  bool _initialized = false;
  bool _disposed = false;
  late final StreamSubscription<TransferSnapshot> _subscription;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await manager.initialize();
      await manager.configureProxy(initialProxy);
      for (final snapshot in await manager.records()) {
        transfers[snapshot.id] = snapshot;
      }
      notifyListeners();
    } on DAKitException catch (error) {
      transferFailure = error;
      notifyListeners();
    } on Object catch (error) {
      transferFailure = _unexpected(error);
      notifyListeners();
    }
  }

  TransferSnapshot? forArtwork(String artworkId) {
    final prefix = _transferPrefix(artworkId);
    final matching =
        transfers.values
            .where((snapshot) => snapshot.id.startsWith(prefix))
            .toList(growable: false)
          ..sort((left, right) => right.id.compareTo(left.id));
    return matching.firstOrNull;
  }

  Future<void> download(String artworkId, MediaAsset asset) async {
    if (schedulingTransfer) return;
    transferFailure = null;
    schedulingTransfer = true;
    notifyListeners();
    try {
      final snapshot = await manager.enqueue(
        TransferRequest(
          id: '${_transferPrefix(artworkId)}${DateTime.now().microsecondsSinceEpoch}',
          asset: asset,
        ),
      );
      _onUpdate(snapshot);
    } on DAKitException catch (error) {
      transferFailure = error;
    } on Object catch (error) {
      transferFailure = _unexpected(error);
    } finally {
      schedulingTransfer = false;
      notifyListeners();
    }
  }

  Future<void> pause(String id) => _control(manager.pause, id);

  Future<void> resume(String id) => _control(manager.resume, id);

  Future<void> cancel(String id) => _control(manager.cancel, id);

  Future<void> _control(
    Future<void> Function(String id) operation,
    String id,
  ) async {
    if (controllingTransfer) return;
    transferFailure = null;
    controllingTransfer = true;
    notifyListeners();
    try {
      await operation(id);
    } on DAKitException catch (error) {
      transferFailure = error;
    } on Object catch (error) {
      transferFailure = _unexpected(error);
    } finally {
      controllingTransfer = false;
      notifyListeners();
    }
  }

  void _onUpdate(TransferSnapshot snapshot) {
    transfers[snapshot.id] = snapshot;
    notifyListeners();
  }

  static String _transferPrefix(String artworkId) {
    final safeId = artworkId.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
    return 'original_${safeId}_';
  }

  static DAKitException _unexpected(Object error) => DAKitException(
    kind: DAKitFailureKind.upstream,
    code: 'example.unexpected',
    message: 'The example client encountered an unexpected failure.',
    cause: error,
  );

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_subscription.cancel());
    unawaited(manager.dispose());
    super.dispose();
  }
}
