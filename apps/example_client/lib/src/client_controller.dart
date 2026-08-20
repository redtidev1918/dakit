import 'dart:async';

import 'package:artrelay_flutter/artrelay_flutter.dart';
import 'package:flutter/foundation.dart';

import 'diagnostic_log.dart';

enum ClientPhase {
  configurationRequired,
  restoring,
  signedOut,
  authorizing,
  loading,
  ready,
  failure,
}

typedef ResumeSession = Future<AuthTokens?> Function({bool waitForCallback});
typedef Authorize = Future<AuthTokens> Function();
typedef ReadTokens = Future<AuthTokens> Function({bool forceRefresh});
typedef Logout = Future<void> Function({bool revoke});
typedef RunConnectivity = Future<ConnectivityReport> Function();
typedef LoadArtwork = Future<Artwork> Function(String id);
typedef ResolveOriginal = Future<MediaAsset> Function(String artworkId);

final class ExampleClientController extends ChangeNotifier {
  factory ExampleClientController({
    required DiagnosticLog diagnostics,
    required ResumeSession resumeSession,
    required Authorize authorize,
    required ReadTokens validTokens,
    required Logout logout,
    required Future<UserProfile> Function() loadAccount,
    required Future<Page<Artwork>> Function() loadHome,
    required RunConnectivity runConnectivity,
    required LoadArtwork loadArtwork,
    required ResolveOriginal resolveOriginal,
    required TransferManager transferManager,
    ProxyConfiguration? initialTransferProxy,
  }) => ExampleClientController._(
    diagnostics: diagnostics,
    resumeSession: resumeSession,
    authorize: authorize,
    validTokens: validTokens,
    logout: logout,
    loadAccount: loadAccount,
    loadHome: loadHome,
    runConnectivity: runConnectivity,
    loadArtwork: loadArtwork,
    resolveOriginal: resolveOriginal,
    transferManager: transferManager,
    initialTransferProxy: initialTransferProxy,
  );

  ExampleClientController._({
    required this.diagnostics,
    required this._resumeSession,
    required this._authorize,
    required this._validTokens,
    required this._logout,
    required this._loadAccount,
    required this._loadHome,
    required this.runConnectivity,
    required this._loadArtwork,
    required this._resolveOriginal,
    required this.transferManager,
    required this.initialTransferProxy,
  }) : phase = ClientPhase.restoring {
    _listenToTransfers();
  }

  ExampleClientController.unconfigured({
    required this.diagnostics,
    required this.transferManager,
    this.initialTransferProxy,
    this.runConnectivity,
  }) : _resumeSession = null,
       _authorize = null,
       _validTokens = null,
       _logout = null,
       _loadAccount = null,
       _loadHome = null,
       _loadArtwork = null,
       _resolveOriginal = null,
       phase = ClientPhase.configurationRequired {
    _listenToTransfers();
  }

  ExampleClientController.configurationFailure({
    required this.diagnostics,
    required this.failure,
    required this.transferManager,
    this.initialTransferProxy,
  }) : runConnectivity = null,
       _resumeSession = null,
       _authorize = null,
       _validTokens = null,
       _logout = null,
       _loadAccount = null,
       _loadHome = null,
       _loadArtwork = null,
       _resolveOriginal = null,
       phase = ClientPhase.configurationRequired {
    _listenToTransfers();
  }

  final DiagnosticLog diagnostics;
  final ResumeSession? _resumeSession;
  final Authorize? _authorize;
  final ReadTokens? _validTokens;
  final Logout? _logout;
  final Future<UserProfile> Function()? _loadAccount;
  final Future<Page<Artwork>> Function()? _loadHome;
  final RunConnectivity? runConnectivity;
  final LoadArtwork? _loadArtwork;
  final ResolveOriginal? _resolveOriginal;
  final TransferManager transferManager;
  final ProxyConfiguration? initialTransferProxy;
  late final StreamSubscription<TransferSnapshot> _transferSubscription;

  ClientPhase phase;
  UserProfile? user;
  List<Artwork> artworks = const <Artwork>[];
  ArtRelayException? failure;
  ConnectivityReport? connectivity;
  bool checkingConnectivity = false;
  Artwork? selectedArtwork;
  MediaAsset? selectedOriginal;
  ArtRelayException? artworkFailure;
  ArtRelayException? transferFailure;
  bool loadingArtwork = false;
  bool schedulingTransfer = false;
  bool controllingTransfer = false;
  final Map<String, TransferSnapshot> transfers = <String, TransferSnapshot>{};
  bool _initialized = false;
  bool _disposed = false;
  int _detailGeneration = 0;

  bool get busy => switch (phase) {
    ClientPhase.restoring ||
    ClientPhase.authorizing ||
    ClientPhase.loading => true,
    _ => false,
  };

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    unawaited(checkConnectivity());
    await _restoreTransfers();
    if (phase == ClientPhase.configurationRequired) return;
    _setPhase(ClientPhase.restoring);
    try {
      await _resumeSession?.call(waitForCallback: false);
      await _validTokens?.call(forceRefresh: false);
      await _loadContent();
    } on ArtRelayException catch (error) {
      if (error.code == 'oauth.session.missing') {
        _setPhase(ClientPhase.signedOut);
      } else {
        _setFailure(error);
      }
    } on Object catch (error) {
      _setFailure(_unexpected(error));
    }
  }

  TransferSnapshot? get selectedTransfer {
    final artwork = selectedArtwork;
    if (artwork == null) return null;
    final prefix = _transferPrefix(artwork.id);
    final matching =
        transfers.values
            .where((snapshot) => snapshot.id.startsWith(prefix))
            .toList(growable: false)
          ..sort((left, right) => right.id.compareTo(left.id));
    return matching.firstOrNull;
  }

  Future<void> openArtwork(String id) async {
    final loadArtwork = _loadArtwork;
    final resolveOriginal = _resolveOriginal;
    if (loadArtwork == null || resolveOriginal == null) return;
    final generation = ++_detailGeneration;
    selectedArtwork = artworks.where((item) => item.id == id).firstOrNull;
    selectedOriginal = null;
    artworkFailure = null;
    transferFailure = null;
    loadingArtwork = true;
    notifyListeners();
    try {
      final detail = await loadArtwork(id);
      if (generation != _detailGeneration) return;
      selectedArtwork = detail;
      if (detail.isDownloadable) {
        final resolved = await resolveOriginal(detail.id);
        if (generation != _detailGeneration) return;
        selectedOriginal = resolved;
      }
    } on ArtRelayException catch (error) {
      if (generation == _detailGeneration) artworkFailure = error;
    } on Object catch (error) {
      if (generation == _detailGeneration) artworkFailure = _unexpected(error);
    } finally {
      if (generation == _detailGeneration) {
        loadingArtwork = false;
        notifyListeners();
      }
    }
  }

  void closeArtwork() {
    _detailGeneration += 1;
    selectedArtwork = null;
    selectedOriginal = null;
    artworkFailure = null;
    transferFailure = null;
    loadingArtwork = false;
    notifyListeners();
  }

  Future<void> downloadOriginal() async {
    final artwork = selectedArtwork;
    final asset = selectedOriginal;
    if (artwork == null || asset == null || schedulingTransfer) return;
    transferFailure = null;
    schedulingTransfer = true;
    notifyListeners();
    try {
      final snapshot = await transferManager.enqueue(
        TransferRequest(
          id: '${_transferPrefix(artwork.id)}${DateTime.now().microsecondsSinceEpoch}',
          asset: asset,
        ),
      );
      _onTransferUpdate(snapshot);
    } on ArtRelayException catch (error) {
      transferFailure = error;
    } on Object catch (error) {
      transferFailure = _unexpected(error);
    } finally {
      schedulingTransfer = false;
      notifyListeners();
    }
  }

  Future<void> pauseTransfer() => _controlTransfer(transferManager.pause);

  Future<void> resumeTransfer() => _controlTransfer(transferManager.resume);

  Future<void> cancelTransfer() => _controlTransfer(transferManager.cancel);

  Future<void> _controlTransfer(
    Future<void> Function(String id) operation,
  ) async {
    final snapshot = selectedTransfer;
    if (snapshot == null || controllingTransfer) return;
    transferFailure = null;
    controllingTransfer = true;
    notifyListeners();
    try {
      await operation(snapshot.id);
    } on ArtRelayException catch (error) {
      transferFailure = error;
    } on Object catch (error) {
      transferFailure = _unexpected(error);
    } finally {
      controllingTransfer = false;
      notifyListeners();
    }
  }

  Future<void> _restoreTransfers() async {
    try {
      await transferManager.initialize();
      await transferManager.configureProxy(initialTransferProxy);
      for (final snapshot in await transferManager.records()) {
        transfers[snapshot.id] = snapshot;
      }
      notifyListeners();
    } on ArtRelayException catch (error) {
      transferFailure = error;
      notifyListeners();
    } on Object catch (error) {
      transferFailure = _unexpected(error);
      notifyListeners();
    }
  }

  void _onTransferUpdate(TransferSnapshot snapshot) {
    transfers[snapshot.id] = snapshot;
    notifyListeners();
  }

  void _listenToTransfers() {
    _transferSubscription = transferManager.updates.listen(
      _onTransferUpdate,
      onError: (Object error, StackTrace stackTrace) {
        transferFailure = _unexpected(error);
        notifyListeners();
      },
    );
  }

  Future<void> checkConnectivity() async {
    final operation = runConnectivity;
    if (operation == null || checkingConnectivity) return;
    checkingConnectivity = true;
    notifyListeners();
    try {
      connectivity = await operation();
    } finally {
      checkingConnectivity = false;
      notifyListeners();
    }
  }

  Future<void> login() async {
    final authorize = _authorize;
    if (authorize == null || busy) return;
    failure = null;
    _setPhase(ClientPhase.authorizing);
    try {
      await authorize();
      await _loadContent();
    } on ArtRelayException catch (error) {
      _setFailure(error);
    } on Object catch (error) {
      _setFailure(_unexpected(error));
    }
  }

  Future<void> refresh() async {
    if (busy) return;
    failure = null;
    await _loadContent();
  }

  Future<void> signOut() async {
    final logout = _logout;
    if (logout == null || busy) return;
    _setPhase(ClientPhase.loading);
    try {
      await logout(revoke: true);
      closeArtwork();
      user = null;
      artworks = const <Artwork>[];
      _setPhase(ClientPhase.signedOut);
    } on ArtRelayException catch (error) {
      _setFailure(error);
    } on Object catch (error) {
      _setFailure(_unexpected(error));
    }
  }

  Future<void> _loadContent() async {
    final loadAccount = _loadAccount;
    final loadHome = _loadHome;
    if (loadAccount == null || loadHome == null) return;
    _setPhase(ClientPhase.loading);
    try {
      final values = await Future.wait<Object>(<Future<Object>>[
        loadAccount(),
        loadHome(),
      ]);
      user = values[0] as UserProfile;
      artworks = List<Artwork>.unmodifiable((values[1] as Page<Artwork>).items);
      _setPhase(ClientPhase.ready);
    } on ArtRelayException catch (error) {
      _setFailure(error);
    } on Object catch (error) {
      _setFailure(_unexpected(error));
    }
  }

  void _setPhase(ClientPhase value) {
    phase = value;
    notifyListeners();
  }

  void _setFailure(ArtRelayException error) {
    failure = error;
    phase = ClientPhase.failure;
    notifyListeners();
  }

  static ArtRelayException _unexpected(Object error) => ArtRelayException(
    kind: ArtRelayFailureKind.upstream,
    code: 'example.unexpected',
    message: 'The example client encountered an unexpected failure.',
    cause: error,
  );

  static String _transferPrefix(String artworkId) {
    final safeId = artworkId.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
    return 'original_${safeId}_';
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_transferSubscription.cancel());
    unawaited(transferManager.dispose());
    super.dispose();
  }
}
