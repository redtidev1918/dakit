import 'dart:async';

import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/foundation.dart';

import 'account_controller.dart';
import 'browse_controller.dart';
import 'controller_types.dart';
import 'diagnostic_log.dart';
import 'transfer_controller.dart';

export 'controller_types.dart';

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
    required ResumeSession resumeSession,
    required Authorize authorize,
    required ReadTokens validTokens,
    required Logout logout,
    required Future<UserProfile> Function() loadAccount,
    required Future<Page<Artwork>> Function() loadHome,
    required this.runConnectivity,
    required LoadArtwork loadArtwork,
    required ResolveOriginal resolveOriginal,
    required TransferManager transferManager,
    required ProxyConfiguration? initialTransferProxy,
  }) : _account = AccountController(
         resumeSession: resumeSession,
         authorize: authorize,
         validTokens: validTokens,
         logout: logout,
         loadAccount: loadAccount,
       ),
       _browse = BrowseController(
         loadHome: loadHome,
         loadArtwork: loadArtwork,
         resolveOriginal: resolveOriginal,
       ),
       _transfers = TransferController(
         manager: transferManager,
         initialProxy: initialTransferProxy,
       ) {
    _attachTransferListeners();
    _attachBrowseListeners();
    _attachAccountListeners();
  }

  ExampleClientController.unconfigured({
    required this.diagnostics,
    required TransferManager transferManager,
    ProxyConfiguration? initialTransferProxy,
    this.runConnectivity,
  }) : _account = AccountController(
         initialPhase: ClientPhase.configurationRequired,
       ),
       _transfers = TransferController(
         manager: transferManager,
         initialProxy: initialTransferProxy,
       ),
       _browse = BrowseController(
         loadHome: null,
         loadArtwork: null,
         resolveOriginal: null,
       ) {
    _attachTransferListeners();
    _attachBrowseListeners();
    _attachAccountListeners();
  }

  ExampleClientController.configurationFailure({
    required this.diagnostics,
    required DAKitException failure,
    required TransferManager transferManager,
    ProxyConfiguration? initialTransferProxy,
  }) : _account = AccountController(
         initialPhase: ClientPhase.configurationRequired,
       ),
       _transfers = TransferController(
         manager: transferManager,
         initialProxy: initialTransferProxy,
       ),
       _browse = BrowseController(
         loadHome: null,
         loadArtwork: null,
         resolveOriginal: null,
       ),
       runConnectivity = null {
    _account.failure = failure;
    _attachTransferListeners();
    _attachBrowseListeners();
    _attachAccountListeners();
  }

  final DiagnosticLog diagnostics;
  final RunConnectivity? runConnectivity;
  final AccountController _account;
  final BrowseController _browse;
  final TransferController _transfers;

  ConnectivityReport? connectivity;
  bool checkingConnectivity = false;
  bool _initialized = false;
  bool _disposed = false;

  ClientPhase get phase => _account.phase;
  UserProfile? get user => _account.user;
  DAKitException? get failure => _account.failure;
  bool get busy => _account.busy;
  List<Artwork> get artworks => _browse.artworks;
  Artwork? get selectedArtwork => _browse.selectedArtwork;
  MediaAsset? get selectedOriginal => _browse.selectedOriginal;
  DAKitException? get artworkFailure => _browse.artworkFailure;
  bool get loadingArtwork => _browse.loadingArtwork;
  Map<String, TransferSnapshot> get transfers => _transfers.transfers;
  DAKitException? get transferFailure => _transfers.transferFailure;
  bool get schedulingTransfer => _transfers.schedulingTransfer;
  bool get controllingTransfer => _transfers.controllingTransfer;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    unawaited(checkConnectivity());
    await _transfers.initialize();
    if (phase == ClientPhase.configurationRequired) return;
    await _account.restore();
    if (_account.phase == ClientPhase.ready) await _browse.refresh();
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
    await _account.login();
    if (_account.phase == ClientPhase.ready) await _browse.refresh();
  }

  Future<void> refresh() async {
    await _account.refresh();
    if (_account.phase == ClientPhase.ready) await _browse.refresh();
  }

  Future<void> signOut() async {
    await _account.signOut();
    if (_account.phase == ClientPhase.signedOut) await _browse.clear();
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

  void _attachAccountListeners() {
    _account.addListener(_handleAccountChange);
  }

  void _handleAccountChange() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _account.removeListener(_handleAccountChange);
    _transfers.removeListener(_handleTransferChange);
    _browse.removeListener(_handleBrowseChange);
    _account.dispose();
    _browse.dispose();
    _transfers.dispose();
    super.dispose();
  }
}
