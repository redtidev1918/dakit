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
  }) => ExampleClientController._(
    diagnostics: diagnostics,
    resumeSession: resumeSession,
    authorize: authorize,
    validTokens: validTokens,
    logout: logout,
    loadAccount: loadAccount,
    loadHome: loadHome,
    runConnectivity: runConnectivity,
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
  }) : phase = ClientPhase.restoring;

  ExampleClientController.unconfigured({
    required this.diagnostics,
    this.runConnectivity,
  }) : _resumeSession = null,
       _authorize = null,
       _validTokens = null,
       _logout = null,
       _loadAccount = null,
       _loadHome = null,
       phase = ClientPhase.configurationRequired;

  ExampleClientController.configurationFailure({
    required this.diagnostics,
    required this.failure,
  }) : runConnectivity = null,
       _resumeSession = null,
       _authorize = null,
       _validTokens = null,
       _logout = null,
       _loadAccount = null,
       _loadHome = null,
       phase = ClientPhase.configurationRequired;

  final DiagnosticLog diagnostics;
  final ResumeSession? _resumeSession;
  final Authorize? _authorize;
  final ReadTokens? _validTokens;
  final Logout? _logout;
  final Future<UserProfile> Function()? _loadAccount;
  final Future<Page<Artwork>> Function()? _loadHome;
  final RunConnectivity? runConnectivity;

  ClientPhase phase;
  UserProfile? user;
  List<Artwork> artworks = const <Artwork>[];
  ArtRelayException? failure;
  ConnectivityReport? connectivity;
  bool checkingConnectivity = false;
  bool _initialized = false;

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
}
