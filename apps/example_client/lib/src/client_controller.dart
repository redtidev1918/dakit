import 'dart:async';

import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/foundation.dart';

import 'browse_controller.dart';
import 'controller_types.dart';
import 'diagnostic_log.dart';
import 'transfer_controller.dart';

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
    required Future<Page<Artwork>> Function() loadHome,
    required this.runConnectivity,
    required LoadArtwork loadArtwork,
    required ResolveOriginal resolveOriginal,
    required TransferManager transferManager,
    required ProxyConfiguration? initialTransferProxy,
  }) : _browse = BrowseController(
         loadHome: loadHome,
         loadArtwork: loadArtwork,
         resolveOriginal: resolveOriginal,
       ),
       _transfers = TransferController(
         manager: transferManager,
         initialProxy: initialTransferProxy,
       ),
       phase = ClientPhase.restoring {
    _attachTransferListeners();
    _attachBrowseListeners();
  }

  ExampleClientController.unconfigured({
    required this.diagnostics,
    required TransferManager transferManager,
    ProxyConfiguration? initialTransferProxy,
    this.runConnectivity,
  }) : _transfers = TransferController(
         manager: transferManager,
         initialProxy: initialTransferProxy,
       ),
       _browse = BrowseController(
         loadHome: null,
         loadArtwork: null,
         resolveOriginal: null,
       ),
       _resumeSession = null,
       _authorize = null,
       _validTokens = null,
       _logout = null,
       _loadAccount = null,
       phase = ClientPhase.configurationRequired {
    _attachTransferListeners();
    _attachBrowseListeners();
  }

  ExampleClientController.configurationFailure({
    required this.diagnostics,
    required this.failure,
    required TransferManager transferManager,
    ProxyConfiguration? initialTransferProxy,
  }) : _transfers = TransferController(
         manager: transferManager,
         initialProxy: initialTransferProxy,
       ),
       _browse = BrowseController(
         loadHome: null,
         loadArtwork: null,
         resolveOriginal: null,
       ),
       runConnectivity = null,
       _resumeSession = null,
       _authorize = null,
       _validTokens = null,
       _logout = null,
       _loadAccount = null,
       phase = ClientPhase.configurationRequired {
    _attachTransferListeners();
    _attachBrowseListeners();
  }

  final DiagnosticLog diagnostics;
  final ResumeSession? _resumeSession;
  final Authorize? _authorize;
  final ReadTokens? _validTokens;
  final Logout? _logout;
  final Future<UserProfile> Function()? _loadAccount;
  final RunConnectivity? runConnectivity;
  final BrowseController _browse;
  final TransferController _transfers;

  ClientPhase phase;
  UserProfile? user;
  DAKitException? failure;
  ConnectivityReport? connectivity;
  bool checkingConnectivity = false;
  bool _initialized = false;
  bool _disposed = false;

  List<Artwork> get artworks => _browse.artworks;
  Artwork? get selectedArtwork => _browse.selectedArtwork;
  MediaAsset? get selectedOriginal => _browse.selectedOriginal;
  DAKitException? get artworkFailure => _browse.artworkFailure;
  bool get loadingArtwork => _browse.loadingArtwork;
  Map<String, TransferSnapshot> get transfers => _transfers.transfers;
  DAKitException? get transferFailure => _transfers.transferFailure;
  bool get schedulingTransfer => _transfers.schedulingTransfer;
  bool get controllingTransfer => _transfers.controllingTransfer;

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
    await _transfers.initialize();
    if (phase == ClientPhase.configurationRequired) return;
    _setPhase(ClientPhase.restoring);
    try {
      await _resumeSession?.call(waitForCallback: false);
      await _validTokens?.call(forceRefresh: false);
      await _loadContent();
    } on DAKitException catch (error) {
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
    return _transfers.forArtwork(artwork.id);
  }

  Future<void> openArtwork(String id) async {
    await _browse.openArtwork(id);
  }

  void closeArtwork() {
    _browse.closeArtwork();
  }

  Future<void> downloadOriginal() async {
    final artwork = selectedArtwork;
    final asset = selectedOriginal;
    if (artwork == null || asset == null) return;
    await _transfers.download(artwork.id, asset);
  }

  Future<void> pauseTransfer() async {
    final snapshot = selectedTransfer;
    if (snapshot != null) await _transfers.pause(snapshot.id);
  }

  Future<void> resumeTransfer() async {
    final snapshot = selectedTransfer;
    if (snapshot != null) await _transfers.resume(snapshot.id);
  }

  Future<void> cancelTransfer() async {
    final snapshot = selectedTransfer;
    if (snapshot != null) await _transfers.cancel(snapshot.id);
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
    } on DAKitException catch (error) {
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
      user = null;
      await _browse.clear();
      _setPhase(ClientPhase.signedOut);
    } on DAKitException catch (error) {
      _setFailure(error);
    } on Object catch (error) {
      _setFailure(_unexpected(error));
    }
  }

  Future<String> runConsoleCommand(String input) async {
    final normalized = input.trim();
    if (normalized.isEmpty) return '';
    final parts = normalized.split(RegExp(r'\s+'));
    final command = parts.first.toLowerCase();
    switch (command) {
      case 'help':
        return 'Commands: help, phase, account, status, open UUID, '
            'download UUID, clear';
      case 'phase':
        return phase.name;
      case 'account':
        final account = user;
        return account == null
            ? 'No account loaded.'
            : '${account.username} (${account.id})';
      case 'status':
        await checkConnectivity();
        final report = connectivity;
        if (report == null) return 'Connectivity unavailable.';
        final stages = report.stages
            .map(
              (stage) =>
                  '${stage.stage.name}=${stage.succeeded ? 'ok' : stage.code}',
            )
            .join(', ');
        return 'reachable=${report.reachable} $stages';
      case 'open':
        if (parts.length < 2) return 'usage: open UUID';
        await openArtwork(parts[1]);
        final artwork = selectedArtwork;
        return artwork == null
            ? 'Artwork not loaded.'
            : '${artwork.title} (${artwork.id})';
      case 'download':
        if (parts.length < 2) return 'usage: download UUID';
        await openArtwork(parts[1]);
        if (selectedOriginal == null) {
          return 'Original is not transferable.';
        }
        await downloadOriginal();
        final snapshot = selectedTransfer;
        return snapshot == null
            ? 'Transfer scheduled.'
            : 'transfer=${snapshot.id} state=${snapshot.state.name}';
      case 'clear':
        diagnostics.clear();
        return 'Diagnostics cleared.';
      default:
        return 'Unknown command: $command';
    }
  }

  Future<void> _loadContent() async {
    final loadAccount = _loadAccount;
    if (loadAccount == null) return;
    _setPhase(ClientPhase.loading);
    try {
      user = await loadAccount();
      await _browse.refresh();
      _setPhase(ClientPhase.ready);
    } on DAKitException catch (error) {
      _setFailure(error);
    } on Object catch (error) {
      _setFailure(_unexpected(error));
    }
  }

  void _setPhase(ClientPhase value) {
    phase = value;
    notifyListeners();
  }

  void _setFailure(DAKitException error) {
    failure = error;
    phase = ClientPhase.failure;
    notifyListeners();
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

  void _attachTransferListeners() {
    _transfers.addListener(_handleTransferChange);
  }

  void _handleTransferChange() {
    if (!_disposed) notifyListeners();
  }

  void _attachBrowseListeners() {
    _browse.addListener(_handleBrowseChange);
  }

  void _handleBrowseChange() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _transfers.removeListener(_handleTransferChange);
    _browse.removeListener(_handleBrowseChange);
    _browse.dispose();
    _transfers.dispose();
    super.dispose();
  }
}
