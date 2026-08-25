import 'dart:async';

import 'package:dakit_api/dakit_api.dart';
import 'package:dakit_core/dakit_core.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 20, 12);
  final config = OAuthConfig(
    clientId: '12345',
    redirectUri: Uri.parse('dakit://oauth/callback'),
  );

  test(
    'subscribes before launch, validates callback, and persists tokens',
    () async {
      final callbacks = FakeCallbackSource();
      final pendingStore = MemoryPendingStore();
      final tokenStore = MemoryTokenStore();
      final endpoint = FakeOAuthEndpoint();
      final diagnostics = MemoryDiagnostics();
      var launches = 0;
      final launcher = FakeLauncher((authorizationUri) async {
        launches += 1;
        expect(pendingStore.value, isNotNull);
        callbacks.add(Uri.parse('other://unrelated'));
        callbacks.add(
          config.redirectUri.replace(
            queryParameters: <String, String>{
              'code': 'authorization-code',
              'state': authorizationUri.queryParameters['state']!,
            },
          ),
        );
      });
      final coordinator = buildCoordinator(
        config: config,
        callbacks: callbacks,
        pendingStore: pendingStore,
        tokenStore: tokenStore,
        endpoint: endpoint,
        launcher: launcher,
        diagnostics: diagnostics,
        now: now,
      );

      final tokens = await coordinator.authorize();

      expect(launches, 1);
      expect(tokens.accessToken, 'access');
      expect(tokenStore.value?.accessToken, 'access');
      expect(pendingStore.value, isNull);
      expect(endpoint.forms.single, isNot(contains('client_secret')));
      expect(
        diagnostics.events.map((event) => event.code),
        containsAll(<String>[
          'oauth.transaction.created',
          'oauth.browser.opened',
          'oauth.callback.validated',
          'oauth.session.saved',
        ]),
      );
    },
  );

  test(
    'coalesces concurrent authorization requests into one browser launch',
    () async {
      final callbacks = FakeCallbackSource();
      final pendingStore = MemoryPendingStore();
      final tokenStore = MemoryTokenStore();
      final endpoint = FakeOAuthEndpoint();
      var launches = 0;
      final launcher = FakeLauncher((authorizationUri) async {
        launches += 1;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        callbacks.add(
          config.redirectUri.replace(
            queryParameters: <String, String>{
              'code': 'authorization-code',
              'state': authorizationUri.queryParameters['state']!,
            },
          ),
        );
      });
      final coordinator = buildCoordinator(
        config: config,
        callbacks: callbacks,
        pendingStore: pendingStore,
        tokenStore: tokenStore,
        endpoint: endpoint,
        launcher: launcher,
        now: now,
      );

      final results = await Future.wait(<Future<AuthTokens>>[
        coordinator.authorize(),
        coordinator.authorize(),
      ]);

      expect(launches, 1);
      expect(endpoint.forms, hasLength(1));
      expect(results.map((value) => value.accessToken), everyElement('access'));
    },
  );

  test('pending cleanup failure cannot roll back a saved login', () async {
    final callbacks = FakeCallbackSource();
    final pendingStore = MemoryPendingStore(failClear: true);
    final tokenStore = MemoryTokenStore();
    final diagnostics = MemoryDiagnostics();
    final coordinator = buildCoordinator(
      config: config,
      callbacks: callbacks,
      pendingStore: pendingStore,
      tokenStore: tokenStore,
      endpoint: FakeOAuthEndpoint(),
      launcher: FakeLauncher((authorizationUri) async {
        callbacks.add(
          config.redirectUri.replace(
            queryParameters: <String, String>{
              'code': 'authorization-code',
              'state': authorizationUri.queryParameters['state']!,
            },
          ),
        );
      }),
      diagnostics: diagnostics,
      now: now,
    );

    final tokens = await coordinator.authorize();

    expect(tokens.accessToken, 'access');
    expect(tokenStore.value?.accessToken, 'access');
    expect(pendingStore.value, isNotNull);
    expect(
      diagnostics.events.map((event) => event.code),
      containsAll(<String>[
        'oauth.pending_cleanup.deferred',
        'oauth.session.saved',
      ]),
    );
  });

  test('resumes a cold-start transaction from the initial callback', () async {
    final pending = PendingAuthorization(
      authorizationUri: Uri(
        scheme: 'https',
        host: 'www.deviantart.com',
        path: '/oauth2/authorize',
      ),
      state: 'persisted-state',
      codeVerifier: 'persisted-verifier',
      createdAt: DateTime.utc(2026, 8, 20, 11, 59),
    );
    final callbacks = FakeCallbackSource(
      initial: Uri.parse(
        'dakit://oauth/callback?code=cold-code&state=persisted-state',
      ),
    );
    final pendingStore = MemoryPendingStore(value: pending);
    final tokenStore = MemoryTokenStore();
    final endpoint = FakeOAuthEndpoint();
    final coordinator = buildCoordinator(
      config: config,
      callbacks: callbacks,
      pendingStore: pendingStore,
      tokenStore: tokenStore,
      endpoint: endpoint,
      launcher: FakeLauncher((_) async {}),
      now: now,
    );

    final tokens = await coordinator.resumePending();

    expect(tokens?.accessToken, 'access');
    expect(endpoint.forms.single['code'], 'cold-code');
    expect(endpoint.forms.single['code_verifier'], 'persisted-verifier');
  });

  test('reports a typed callback timeout and clears stale state', () async {
    final callbacks = FakeCallbackSource();
    final pendingStore = MemoryPendingStore();
    final coordinator = buildCoordinator(
      config: config,
      callbacks: callbacks,
      pendingStore: pendingStore,
      tokenStore: MemoryTokenStore(),
      endpoint: FakeOAuthEndpoint(),
      launcher: FakeLauncher((_) async {}),
      now: now,
      timeout: const Duration(milliseconds: 5),
    );

    await expectLater(
      coordinator.authorize(),
      throwsA(
        isA<DAKitException>().having(
          (error) => error.code,
          'code',
          'oauth.callback.timeout',
        ),
      ),
    );
    expect(pendingStore.value, isNull);
  });

  test(
    'cancels an active browser transaction without waiting for timeout',
    () async {
      final callbacks = FakeCallbackSource();
      final pendingStore = MemoryPendingStore();
      final tokenStore = MemoryTokenStore();
      final launched = Completer<void>();
      final coordinator = buildCoordinator(
        config: config,
        callbacks: callbacks,
        pendingStore: pendingStore,
        tokenStore: tokenStore,
        endpoint: FakeOAuthEndpoint(),
        launcher: FakeLauncher((_) async => launched.complete()),
        now: now,
      );

      final authorization = coordinator.authorize();
      await launched.future;
      await coordinator.cancelPending();

      await expectLater(
        authorization,
        throwsA(
          isA<DAKitException>().having(
            (error) => error.code,
            'code',
            'oauth.transaction.cancelled',
          ),
        ),
      );
      expect(pendingStore.value, isNull);
      expect(tokenStore.value, isNull);
    },
  );

  test(
    'startup recovery returns promptly when no cold-start callback exists',
    () async {
      final pending = PendingAuthorization(
        authorizationUri: Uri.https('www.deviantart.com', '/oauth2/authorize'),
        state: 'persisted-state',
        codeVerifier: 'persisted-verifier',
        createdAt: DateTime.utc(2026, 8, 20, 11, 59),
      );
      final pendingStore = MemoryPendingStore(value: pending);
      final coordinator = buildCoordinator(
        config: config,
        callbacks: FakeCallbackSource(),
        pendingStore: pendingStore,
        tokenStore: MemoryTokenStore(),
        endpoint: FakeOAuthEndpoint(),
        launcher: FakeLauncher((_) async {}),
        now: now,
      );

      final result = await coordinator.resumePending();

      expect(result, isNull);
      expect(pendingStore.value, same(pending));
      expect(coordinator.isAuthorizing, isFalse);
    },
  );
}

OAuthAuthorizationCoordinator buildCoordinator({
  required OAuthConfig config,
  required FakeCallbackSource callbacks,
  required MemoryPendingStore pendingStore,
  required MemoryTokenStore tokenStore,
  required FakeOAuthEndpoint endpoint,
  required FakeLauncher launcher,
  required DateTime now,
  DiagnosticSink diagnostics = const NoopDiagnosticSink(),
  Duration timeout = const Duration(minutes: 10),
}) {
  final tokenClient = OAuthTokenClient(endpoint: endpoint, now: () => now);
  final session = OAuthSession(
    config: config,
    store: tokenStore,
    tokenClient: tokenClient,
    now: () => now,
  );
  return OAuthAuthorizationCoordinator(
    config: config,
    launcher: launcher,
    callbacks: callbacks,
    pendingStore: pendingStore,
    tokenClient: tokenClient,
    session: session,
    diagnostics: diagnostics,
    now: () => now,
    timeout: timeout,
  );
}

final class FakeCallbackSource implements InitialCallbackUriSource {
  FakeCallbackSource({this.initial});

  final Uri? initial;
  final StreamController<Uri> controller = StreamController<Uri>.broadcast();

  void add(Uri uri) => controller.add(uri);

  @override
  Future<Uri?> initialUri() async => initial;

  @override
  Stream<Uri> get uris => controller.stream;
}

final class FakeLauncher implements ExternalUriLauncher {
  const FakeLauncher(this.callback);

  final Future<void> Function(Uri uri) callback;

  @override
  Future<void> launch(Uri uri) => callback(uri);
}

final class MemoryPendingStore implements PendingAuthorizationStore {
  MemoryPendingStore({this.value, this.failClear = false});

  PendingAuthorization? value;
  final bool failClear;

  @override
  Future<void> clear() async {
    if (failClear) {
      throw const DAKitException(
        kind: DAKitFailureKind.storage,
        code: 'pending_authorization_store.clear_failed',
        message: 'Unable to clear pending authorization.',
      );
    }
    value = null;
  }

  @override
  Future<PendingAuthorization?> read() async => value;

  @override
  Future<void> write(PendingAuthorization pending) async => value = pending;
}

final class MemoryTokenStore implements TokenStore {
  AuthTokens? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<AuthTokens?> read() async => value;

  @override
  Future<void> write(AuthTokens tokens) async => value = tokens;
}

final class FakeOAuthEndpoint implements OAuthEndpoint {
  final List<Map<String, String>> forms = <Map<String, String>>[];

  @override
  Future<Map<String, Object?>> postForm(
    Uri endpoint,
    Map<String, String> form,
  ) async {
    forms.add(Map<String, String>.of(form));
    return <String, Object?>{
      'access_token': 'access',
      'token_type': 'Bearer',
      'refresh_token': 'refresh',
      'expires_in': 3600,
      'scope': 'basic browse',
    };
  }
}

final class MemoryDiagnostics implements DiagnosticSink {
  final List<DiagnosticEvent> events = <DiagnosticEvent>[];

  @override
  void add(DiagnosticEvent event) => events.add(event);
}
