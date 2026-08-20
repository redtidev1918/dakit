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
