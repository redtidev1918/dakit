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

  test('public code exchange sends PKCE and no client secret', () async {
    final endpoint = FakeOAuthEndpoint(<Map<String, Object?>>[
      <String, Object?>{
        'access_token': 'access',
        'token_type': 'Bearer',
        'refresh_token': 'refresh',
        'expires_in': 3600,
        'scope': 'basic browse',
      },
    ]);
    final flow = PkceFlow();
    final pending = flow.start(config, now: now);
    final tokens = await OAuthTokenClient(endpoint: endpoint, now: () => now)
        .exchangeCode(
          config: config,
          pending: pending,
          callback: const AuthorizationCallback(code: 'authorization-code'),
        );

    expect(tokens.accessToken, 'access');
    expect(tokens.expiresAt, now.add(const Duration(hours: 1)));
    expect(endpoint.forms.single['code_verifier'], pending.codeVerifier);
    expect(endpoint.forms.single, isNot(contains('client_secret')));
  });

  test('concurrent expired-session reads share one refresh request', () async {
    final endpoint = FakeOAuthEndpoint(<Map<String, Object?>>[
      <String, Object?>{
        'access_token': 'new-access',
        'token_type': 'Bearer',
        'expires_in': 3600,
        'scope': 'basic',
      },
    ], delay: const Duration(milliseconds: 10));
    final store = MemoryTokenStore(
      AuthTokens(
        accessToken: 'old-access',
        tokenType: 'Bearer',
        refreshToken: 'old-refresh',
        expiresAt: now.subtract(const Duration(minutes: 1)),
      ),
    );
    final session = OAuthSession(
      config: config,
      store: store,
      tokenClient: OAuthTokenClient(endpoint: endpoint, now: () => now),
      now: () => now,
    );

    final results = await Future.wait(<Future<AuthTokens>>[
      session.validTokens(),
      session.validTokens(),
      session.validTokens(),
    ]);

    expect(endpoint.forms, hasLength(1));
    expect(results.map((tokens) => tokens.accessToken).toSet(), <String>{
      'new-access',
    });
    expect(results.first.refreshToken, 'old-refresh');
    expect(store.value?.accessToken, 'new-access');
  });

  test('refresh preserves scopes when the provider omits scope', () async {
    final endpoint = FakeOAuthEndpoint(<Map<String, Object?>>[
      <String, Object?>{
        'access_token': 'new-access',
        'token_type': 'Bearer',
        'expires_in': 3600,
      },
    ]);
    final store = MemoryTokenStore(
      AuthTokens(
        accessToken: 'old-access',
        tokenType: 'Bearer',
        refreshToken: 'old-refresh',
        expiresAt: now.subtract(const Duration(minutes: 1)),
        scopes: const <String>{'basic', 'browse', 'user'},
      ),
    );
    final session = OAuthSession(
      config: config,
      store: store,
      tokenClient: OAuthTokenClient(endpoint: endpoint, now: () => now),
      now: () => now,
    );

    final refreshed = await session.validTokens();

    expect(refreshed.scopes, const <String>{'basic', 'browse', 'user'});
  });

  test('invalid refresh clears tokens and notifies the host', () async {
    final store = MemoryTokenStore(
      AuthTokens(
        accessToken: 'old-access',
        tokenType: 'Bearer',
        refreshToken: 'invalid-refresh',
        expiresAt: now.subtract(const Duration(minutes: 1)),
      ),
    );
    final session = OAuthSession(
      config: config,
      store: store,
      tokenClient: OAuthTokenClient(
        endpoint: InvalidRefreshEndpoint(),
        now: () => now,
      ),
      now: () => now,
    );
    final invalidation = session.invalidations.first;

    await expectLater(
      session.validTokens(),
      throwsA(
        isA<DAKitException>().having(
          (error) => error.code,
          'code',
          'oauth.refresh.invalid',
        ),
      ),
    );

    expect((await invalidation).code, 'oauth.refresh.invalid');
    expect(store.value, isNull);
    expect(session.generation, 1);
    await expectLater(
      session.validTokens(),
      throwsA(
        isA<DAKitException>().having(
          (error) => error.code,
          'code',
          'oauth.session.missing',
        ),
      ),
    );
  });

  test('logout cannot be undone by an in-flight refresh', () async {
    final endpoint = ControlledOAuthEndpoint();
    final store = MemoryTokenStore(
      AuthTokens(
        accessToken: 'old-access',
        tokenType: 'Bearer',
        refreshToken: 'old-refresh',
        expiresAt: now.subtract(const Duration(minutes: 1)),
        scopes: const <String>{'basic', 'browse'},
      ),
    );
    final session = OAuthSession(
      config: config,
      store: store,
      tokenClient: OAuthTokenClient(endpoint: endpoint, now: () => now),
      now: () => now,
    );

    final refresh = session.validTokens();
    await endpoint.refreshStarted.future;
    final logout = session.logout();
    endpoint.releaseRefresh.complete();

    await expectLater(
      refresh,
      throwsA(
        isA<DAKitException>().having(
          (error) => error.code,
          'code',
          'oauth.session.changed',
        ),
      ),
    );
    await logout;

    expect(store.value, isNull);
    expect(endpoint.forms, hasLength(2));
    expect(endpoint.forms.last['token'], 'old-refresh');
  });

  test(
    'a token exchange started before logout cannot restore a session',
    () async {
      final endpoint = FakeOAuthEndpoint(const <Map<String, Object?>>[]);
      final store = MemoryTokenStore(null);
      final session = OAuthSession(
        config: config,
        store: store,
        tokenClient: OAuthTokenClient(endpoint: endpoint, now: () => now),
        now: () => now,
      );
      final generation = session.generation;

      await session.logout(revoke: false);

      await expectLater(
        session.save(
          AuthTokens(
            accessToken: 'late-access',
            tokenType: 'Bearer',
            expiresAt: now.add(const Duration(hours: 1)),
          ),
          expectedGeneration: generation,
        ),
        throwsA(
          isA<DAKitException>().having(
            (error) => error.code,
            'code',
            'oauth.session.changed',
          ),
        ),
      );
      expect(store.value, isNull);
    },
  );

  test('logout clears local tokens after successful revocation', () async {
    final endpoint = FakeOAuthEndpoint(<Map<String, Object?>>[
      <String, Object?>{'success': true},
    ]);
    final store = MemoryTokenStore(
      AuthTokens(
        accessToken: 'access',
        tokenType: 'Bearer',
        refreshToken: 'refresh',
        expiresAt: now.add(const Duration(hours: 1)),
      ),
    );
    final session = OAuthSession(
      config: config,
      store: store,
      tokenClient: OAuthTokenClient(endpoint: endpoint, now: () => now),
      now: () => now,
    );

    await session.logout();

    expect(store.value, isNull);
    expect(endpoint.forms.single['token'], 'refresh');
    expect(endpoint.forms.single['revoke_refresh_only'], 'true');
  });

  test('failed token deletion cannot poison the next authorization', () async {
    final store = FailingClearTokenStore(
      AuthTokens(
        accessToken: 'old-access',
        tokenType: 'Bearer',
        expiresAt: now.add(const Duration(hours: 1)),
      ),
    );
    final session = OAuthSession(
      config: config,
      store: store,
      tokenClient: OAuthTokenClient(
        endpoint: FakeOAuthEndpoint(const <Map<String, Object?>>[]),
        now: () => now,
      ),
      now: () => now,
    );

    await expectLater(session.logout(revoke: false), throwsStateError);
    final replacement = AuthTokens(
      accessToken: 'replacement',
      tokenType: 'Bearer',
      expiresAt: now.add(const Duration(hours: 2)),
    );
    await session.save(replacement);

    expect(store.value?.accessToken, 'replacement');
    expect((await session.validTokens()).accessToken, 'replacement');
  });
}

final class FakeOAuthEndpoint implements OAuthEndpoint {
  FakeOAuthEndpoint(this.responses, {this.delay = Duration.zero});

  final List<Map<String, Object?>> responses;
  final Duration delay;
  final List<Map<String, String>> forms = <Map<String, String>>[];

  @override
  Future<Map<String, Object?>> postForm(
    Uri endpoint,
    Map<String, String> form,
  ) async {
    forms.add(Map<String, String>.unmodifiable(form));
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return responses.removeAt(0);
  }
}

final class ControlledOAuthEndpoint implements OAuthEndpoint {
  final Completer<void> refreshStarted = Completer<void>();
  final Completer<void> releaseRefresh = Completer<void>();
  final List<Map<String, String>> forms = <Map<String, String>>[];

  @override
  Future<Map<String, Object?>> postForm(
    Uri endpoint,
    Map<String, String> form,
  ) async {
    forms.add(Map<String, String>.unmodifiable(form));
    if (form['grant_type'] == 'refresh_token') {
      refreshStarted.complete();
      await releaseRefresh.future;
      return <String, Object?>{
        'access_token': 'new-access',
        'token_type': 'Bearer',
        'expires_in': 3600,
      };
    }
    return <String, Object?>{'success': true};
  }
}

final class InvalidRefreshEndpoint implements OAuthEndpoint {
  @override
  Future<Map<String, Object?>> postForm(
    Uri endpoint,
    Map<String, String> form,
  ) => throw const DAKitException(
    kind: DAKitFailureKind.authentication,
    code: 'oauth.refresh.invalid',
    message: 'The refresh token is invalid.',
  );
}

final class MemoryTokenStore implements TokenStore {
  MemoryTokenStore(this.value);

  AuthTokens? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<AuthTokens?> read() async => value;

  @override
  Future<void> write(AuthTokens tokens) async => value = tokens;
}

final class FailingClearTokenStore extends MemoryTokenStore {
  FailingClearTokenStore(super.value);

  @override
  Future<void> clear() => throw StateError('keychain denied deletion');
}
