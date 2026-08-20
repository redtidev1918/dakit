import 'dart:async';

import 'package:dakit_core/dakit_core.dart';

import 'oauth_config.dart';
import 'oauth_session.dart';
import 'oauth_token_client.dart';
import 'pkce.dart';

abstract interface class PendingAuthorizationStore {
  Future<PendingAuthorization?> read();

  Future<void> write(PendingAuthorization pending);

  Future<void> clear();
}

/// Coordinates a complete public-client login without owning any UI.
///
/// The transaction is persisted before the system browser opens, allowing a
/// host application to call [resumePending] after a cold-start callback.
final class OAuthAuthorizationCoordinator {
  factory OAuthAuthorizationCoordinator({
    required OAuthConfig config,
    required ExternalUriLauncher launcher,
    required CallbackUriSource callbacks,
    required PendingAuthorizationStore pendingStore,
    required OAuthTokenClient tokenClient,
    required OAuthSession session,
    PkceFlow? flow,
    DiagnosticSink diagnostics = const NoopDiagnosticSink(),
    DateTime Function()? now,
    Duration timeout = const Duration(minutes: 10),
  }) => OAuthAuthorizationCoordinator._(
    config,
    launcher,
    callbacks,
    pendingStore,
    tokenClient,
    session,
    flow ?? PkceFlow(),
    diagnostics,
    now ?? DateTime.now,
    timeout,
  );

  OAuthAuthorizationCoordinator._(
    this.config,
    this._launcher,
    this._callbacks,
    this._pendingStore,
    this._tokenClient,
    this._session,
    this._flow,
    this._diagnostics,
    this._now,
    this.timeout,
  );

  final OAuthConfig config;
  final ExternalUriLauncher _launcher;
  final CallbackUriSource _callbacks;
  final PendingAuthorizationStore _pendingStore;
  final OAuthTokenClient _tokenClient;
  final OAuthSession _session;
  final PkceFlow _flow;
  final DiagnosticSink _diagnostics;
  final DateTime Function() _now;
  final Duration timeout;
  Future<AuthTokens>? _active;
  Completer<void>? _cancellation;
  int _authorizationGeneration = 0;

  bool get isAuthorizing => _active != null;

  Future<AuthTokens> authorize() => _singleFlight(_start);

  /// Continues a transaction saved before the process was terminated.
  ///
  /// Returns `null` when there is nothing to resume. Hosts should call this as
  /// early as practical after constructing their callback source.
  Future<AuthTokens?> resumePending({bool waitForCallback = false}) async {
    final pending = await _pendingStore.read();
    if (pending == null) return null;
    Uri? initialCallback;
    if (_callbacks case final InitialCallbackUriSource initialSource) {
      final initial = await initialSource.initialUri();
      if (initial != null && _flow.matchesRedirect(config, initial)) {
        initialCallback = initial;
      }
    }
    if (initialCallback == null && !waitForCallback) return null;
    return _singleFlight(
      () => _complete(pending, initialCallback: initialCallback),
    );
  }

  Future<void> cancelPending() async {
    _authorizationGeneration += 1;
    final cancellation = _cancellation;
    if (cancellation != null && !cancellation.isCompleted) {
      cancellation.complete();
    }
    await _pendingStore.clear();
    _record(
      DiagnosticStage.oauthCallback,
      DiagnosticLevel.info,
      'oauth.transaction.cancelled',
      'The pending authorization transaction was cancelled.',
    );
  }

  Future<AuthTokens> _singleFlight(Future<AuthTokens> Function() operation) {
    final existing = _active;
    if (existing != null) return existing;
    _cancellation = Completer<void>();
    final future = operation();
    _active = future;
    unawaited(
      future.then<void>(
        (_) => _clearActive(future),
        onError: (Object _, StackTrace _) => _clearActive(future),
      ),
    );
    return future;
  }

  void _clearActive(Future<AuthTokens> future) {
    if (identical(_active, future)) {
      _active = null;
      _cancellation = null;
    }
  }

  Future<AuthTokens> _start() async {
    final pending = _flow.start(config, now: _now().toUtc());
    await _pendingStore.write(pending);
    _record(
      DiagnosticStage.oauthLaunch,
      DiagnosticLevel.info,
      'oauth.transaction.created',
      'A PKCE authorization transaction was created.',
    );

    return _waitForCallback(
      pending,
      afterListening: () async {
        try {
          await _launcher.launch(pending.authorizationUri);
          _record(
            DiagnosticStage.oauthLaunch,
            DiagnosticLevel.info,
            'oauth.browser.opened',
            'The authorization request was handed to the system browser.',
          );
        } on Object catch (error) {
          await _pendingStore.clear();
          if (error is DAKitException) rethrow;
          throw DAKitException(
            kind: DAKitFailureKind.authentication,
            code: 'oauth.browser.launch_failed',
            message:
                'The operating system could not open the authorization URL.',
            cause: error,
          );
        }
      },
    );
  }

  Future<AuthTokens> _complete(
    PendingAuthorization pending, {
    Uri? initialCallback,
  }) async {
    final age = _now().toUtc().difference(pending.createdAt);
    if (age >= timeout) {
      await _pendingStore.clear();
      throw const DAKitException(
        kind: DAKitFailureKind.authentication,
        code: 'oauth.callback.expired',
        message: 'The OAuth authorization transaction expired.',
      );
    }
    return _waitForCallback(
      pending,
      remaining: timeout - age,
      initialCallback: initialCallback,
    );
  }

  Future<AuthTokens> _waitForCallback(
    PendingAuthorization pending, {
    Duration? remaining,
    Future<void> Function()? afterListening,
    Uri? initialCallback,
  }) async {
    final started = _now();
    final expectedAuthorizationGeneration = _authorizationGeneration;
    final expectedSessionGeneration = _session.generation;
    final cancellation = _cancellation;
    if (cancellation == null) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'oauth.transaction.not_active',
        message: 'No OAuth authorization transaction is active.',
      );
    }
    _record(
      DiagnosticStage.oauthCallback,
      DiagnosticLevel.debug,
      'oauth.callback.waiting',
      'Waiting for the operating system OAuth callback.',
    );

    try {
      final callbackUri = await _nextCallback(
        remaining ?? timeout,
        cancellation: cancellation,
        afterListening: afterListening,
        initialCallback: initialCallback,
      );
      _ensureNotCancelled(expectedAuthorizationGeneration);
      final callback = _flow.validateCallback(
        config: config,
        pending: pending,
        callbackUri: callbackUri,
        now: _now().toUtc(),
        timeout: timeout,
      );
      _record(
        DiagnosticStage.oauthCallback,
        DiagnosticLevel.info,
        'oauth.callback.validated',
        'The OAuth callback passed redirect and state validation.',
        elapsed: _now().difference(started),
      );
      final tokens = await _tokenClient.exchangeCode(
        config: config,
        pending: pending,
        callback: callback,
      );
      _ensureNotCancelled(expectedAuthorizationGeneration);
      await _session.save(
        tokens,
        expectedGeneration: expectedSessionGeneration,
      );
      if (expectedAuthorizationGeneration != _authorizationGeneration) {
        await _session.logout();
        throw _cancelledAuthorization();
      }
      await _pendingStore.clear();
      _record(
        DiagnosticStage.storage,
        DiagnosticLevel.info,
        'oauth.session.saved',
        'The authorized session was stored securely.',
      );
      return tokens;
    } on TimeoutException catch (error) {
      await _pendingStore.clear();
      final failure = DAKitException(
        kind: DAKitFailureKind.authentication,
        code: 'oauth.callback.timeout',
        message: 'No OAuth callback arrived before the timeout.',
        retryable: true,
        cause: error,
      );
      _recordFailure(
        DiagnosticStage.oauthCallback,
        failure.code,
        failure,
        elapsed: _now().difference(started),
      );
      throw failure;
    } on DAKitException catch (error) {
      _recordFailure(
        switch (error) {
          _ when error.kind == DAKitFailureKind.storage =>
            DiagnosticStage.storage,
          _ when error.code.startsWith('oauth.browser.') =>
            DiagnosticStage.oauthLaunch,
          _ => DiagnosticStage.oauthCallback,
        },
        error.code,
        error,
        elapsed: _now().difference(started),
      );
      rethrow;
    }
  }

  Future<Uri> _nextCallback(
    Duration wait, {
    required Completer<void> cancellation,
    Future<void> Function()? afterListening,
    Uri? initialCallback,
  }) async {
    final controller = StreamController<Uri>();
    late final StreamSubscription<Uri> subscription;
    subscription = _callbacks.uris.listen((uri) {
      if (_flow.matchesRedirect(config, uri) && !controller.isClosed) {
        controller.add(uri);
      }
    }, onError: controller.addError);
    try {
      if (cancellation.isCompleted) throw _cancelledAuthorization();
      if (initialCallback != null) {
        controller.add(initialCallback);
      }
      await afterListening?.call();
      final cancelled = cancellation.future.then<Uri>(
        (_) => throw _cancelledAuthorization(),
      );
      return await Future.any<Uri>(<Future<Uri>>[
        controller.stream.first,
        cancelled,
      ]).timeout(wait);
    } finally {
      await subscription.cancel();
      await controller.close();
    }
  }

  void _ensureNotCancelled(int expectedGeneration) {
    if (expectedGeneration != _authorizationGeneration) {
      throw _cancelledAuthorization();
    }
  }

  static DAKitException _cancelledAuthorization() => const DAKitException(
    kind: DAKitFailureKind.cancelled,
    code: 'oauth.transaction.cancelled',
    message: 'The OAuth authorization transaction was cancelled.',
  );

  void _record(
    DiagnosticStage stage,
    DiagnosticLevel level,
    String code,
    String message, {
    Duration? elapsed,
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    _diagnostics.add(
      DiagnosticEvent(
        stage: stage,
        level: level,
        code: code,
        message: message,
        elapsed: elapsed,
        attributes: attributes,
      ),
    );
  }

  void _recordFailure(
    DiagnosticStage stage,
    String code,
    Object error, {
    Duration? elapsed,
  }) {
    _record(
      stage,
      DiagnosticLevel.error,
      code,
      'The OAuth authorization operation failed.',
      elapsed: elapsed,
      attributes: <String, Object?>{
        'failure_code': error is DAKitException ? error.code : 'unexpected',
        if (error is DAKitException) ...error.details,
      },
    );
  }
}
