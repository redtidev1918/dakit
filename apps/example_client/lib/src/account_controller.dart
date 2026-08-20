import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/foundation.dart';

import 'controller_types.dart';

final class AccountController extends ChangeNotifier {
  AccountController({
    this.resumeSession,
    this.authorize,
    this.validTokens,
    this.logout,
    this.loadAccount,
    ClientPhase initialPhase = ClientPhase.restoring,
  }) : phase = initialPhase;

  final ResumeSession? resumeSession;
  final Authorize? authorize;
  final ReadTokens? validTokens;
  final Logout? logout;
  final Future<UserProfile> Function()? loadAccount;

  ClientPhase phase;
  UserProfile? user;
  DAKitException? failure;

  bool get busy => switch (phase) {
    ClientPhase.restoring ||
    ClientPhase.authorizing ||
    ClientPhase.loading => true,
    _ => false,
  };

  Future<void> restore() async {
    phase = ClientPhase.restoring;
    notifyListeners();
    try {
      await resumeSession?.call(waitForCallback: false);
      await validTokens?.call(forceRefresh: false);
      await _loadAccountData();
    } on DAKitException catch (error) {
      if (error.code == 'oauth.session.missing') {
        phase = ClientPhase.signedOut;
        notifyListeners();
      } else {
        _setFailure(error);
      }
    } on Object catch (error) {
      _setFailure(_unexpected(error));
    }
  }

  Future<void> login() async {
    final authorize = this.authorize;
    if (authorize == null || busy) return;
    failure = null;
    phase = ClientPhase.authorizing;
    notifyListeners();
    try {
      await authorize();
      await _loadAccountData();
    } on DAKitException catch (error) {
      _setFailure(error);
    } on Object catch (error) {
      _setFailure(_unexpected(error));
    }
  }

  Future<void> refresh() async {
    if (busy) return;
    failure = null;
    await _loadAccountData();
  }

  Future<void> signOut() async {
    final logout = this.logout;
    if (logout == null || busy) return;
    phase = ClientPhase.loading;
    notifyListeners();
    try {
      await logout(revoke: true);
      user = null;
      phase = ClientPhase.signedOut;
      notifyListeners();
    } on DAKitException catch (error) {
      _setFailure(error);
    } on Object catch (error) {
      _setFailure(_unexpected(error));
    }
  }

  Future<void> _loadAccountData() async {
    final loadAccount = this.loadAccount;
    if (loadAccount == null) return;
    user = await loadAccount();
    phase = ClientPhase.ready;
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
}
