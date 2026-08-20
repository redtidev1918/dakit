import 'dart:math';

import 'package:dakit_api/dakit_api.dart';
import 'package:dakit_core/dakit_core.dart';
import 'package:test/test.dart';

void main() {
  final config = OAuthConfig(
    clientId: '12345',
    redirectUri: Uri.parse('dakit://oauth/callback'),
  );
  final now = DateTime.utc(2026, 8, 20, 12);

  test('creates an OAuth 2.1 PKCE authorization request', () {
    final pending = PkceFlow(random: Random(7)).start(config, now: now);
    final query = pending.authorizationUri.queryParameters;

    expect(query['response_type'], 'code');
    expect(query['client_id'], '12345');
    expect(query['redirect_uri'], 'dakit://oauth/callback');
    expect(query['code_challenge_method'], 'S256');
    expect(query['code_challenge'], hasLength(43));
    expect(pending.codeVerifier, hasLength(64));
    expect(pending.state, hasLength(48));
  });

  test('accepts an exact callback with matching state', () {
    final pending = PkceFlow(random: Random(8)).start(config, now: now);
    final callback = Uri.parse(
      'dakit://oauth/callback?code=abc&state=${pending.state}',
    );

    final result = PkceFlow().validateCallback(
      config: config,
      pending: pending,
      callbackUri: callback,
      now: now.add(const Duration(minutes: 1)),
    );

    expect(result.code, 'abc');
  });

  test('rejects mismatched state before exposing the code', () {
    final pending = PkceFlow(random: Random(9)).start(config, now: now);

    expect(
      () => PkceFlow().validateCallback(
        config: config,
        pending: pending,
        callbackUri: Uri.parse(
          'dakit://oauth/callback?code=abc&state=attacker',
        ),
        now: now,
      ),
      throwsA(
        isA<DAKitException>().having(
          (error) => error.code,
          'code',
          'oauth.callback.state_mismatch',
        ),
      ),
    );
  });

  test('preserves a bounded provider error description for diagnostics', () {
    final flow = PkceFlow(random: Random(2));
    final pending = flow.start(config, now: now);

    expect(
      () => flow.validateCallback(
        config: config,
        pending: pending,
        callbackUri: config.redirectUri.replace(
          queryParameters: <String, String>{
            'state': pending.state,
            'error': 'invalid_client',
            'error_description': 'Invalid   client.\nCheck the application.',
          },
        ),
        now: now,
      ),
      throwsA(
        isA<DAKitException>()
            .having(
              (error) => error.code,
              'code',
              'oauth.provider.invalid_client',
            )
            .having(
              (error) => error.details['provider_description'],
              'provider description',
              'Invalid client. Check the application.',
            ),
      ),
    );
  });
}
