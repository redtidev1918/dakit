import 'package:artrelay_api/artrelay_api.dart';
import 'package:artrelay_core/artrelay_core.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 20, 12);

  test('sends version, user agent, compression, and bearer headers', () async {
    final harness = ApiHarness(
      now: now,
      responses: <ResponseSpec>[
        const ResponseSpec(200, <String, Object?>{'status': 'success'}),
      ],
    );

    final result = await harness.client.getJson(
      'placebo',
      query: const <String, Object?>{'with_session': false},
    );

    final request = harness.requests.single;
    expect(result['status'], 'success');
    expect(request.headers['Authorization'], 'Bearer original-access');
    expect(request.headers['dA-minor-version'], '20240701');
    expect(request.headers['User-Agent'], 'ArtRelay-Test/1.0');
    expect(request.headers['Accept-Encoding'], 'gzip');
    expect(request.uri.path, '/api/v1/oauth2/placebo');
  });

  test('refreshes once after 401 and replays with the new token', () async {
    final harness = ApiHarness(
      now: now,
      responses: <ResponseSpec>[
        const ResponseSpec(401, <String, Object?>{'error': 'unauthorized'}),
        const ResponseSpec(200, <String, Object?>{'status': 'success'}),
      ],
      tokenResponses: <Map<String, Object?>>[
        <String, Object?>{
          'access_token': 'refreshed-access',
          'token_type': 'Bearer',
          'expires_in': 3600,
          'scope': 'basic',
        },
      ],
    );

    await harness.client.getJson('placebo');

    expect(harness.requests, hasLength(2));
    expect(
      harness.requests.last.headers['Authorization'],
      'Bearer refreshed-access',
    );
    expect(harness.tokenForms, hasLength(1));
  });

  test('uses exponential delay for adaptive rate limiting', () async {
    final delays = <Duration>[];
    final harness = ApiHarness(
      now: now,
      responses: <ResponseSpec>[
        const ResponseSpec(429, <String, Object?>{'error': 'server_error'}),
        const ResponseSpec(429, <String, Object?>{'error': 'server_error'}),
        const ResponseSpec(200, <String, Object?>{'status': 'success'}),
      ],
      delay: (duration) async => delays.add(duration),
    );

    await harness.client.getJson('browse/dailydeviations');

    expect(delays, <Duration>[
      const Duration(seconds: 1),
      const Duration(seconds: 2),
    ]);
  });

  test('classifies an HTML 403 as an HTTP client rejection', () async {
    final harness = ApiHarness(
      now: now,
      responses: <ResponseSpec>[
        const ResponseSpec(403, '<html>blocked</html>'),
      ],
    );

    expect(
      () => harness.client.getJson('placebo'),
      throwsA(
        isA<ArtRelayException>().having(
          (error) => error.code,
          'code',
          'api.response.html_403',
        ),
      ),
    );
  });
}

final class ApiHarness {
  ApiHarness({
    required DateTime now,
    required List<ResponseSpec> responses,
    List<Map<String, Object?>> tokenResponses = const <Map<String, Object?>>[],
    Delay? delay,
  }) : requests = <RequestOptions>[],
       tokenForms = <Map<String, String>>[] {
    final store = MemoryStore(
      AuthTokens(
        accessToken: 'original-access',
        tokenType: 'Bearer',
        refreshToken: 'original-refresh',
        expiresAt: now.add(const Duration(hours: 1)),
      ),
    );
    final oauthEndpoint = QueueOAuthEndpoint(tokenResponses, tokenForms);
    final oauthConfig = OAuthConfig(
      clientId: '12345',
      redirectUri: Uri.parse('artrelay://oauth/callback'),
    );
    final session = OAuthSession(
      config: oauthConfig,
      store: store,
      tokenClient: OAuthTokenClient(endpoint: oauthEndpoint, now: () => now),
      now: () => now,
    );
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final spec = responses.removeAt(0);
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: spec.status,
              data: spec.data,
            ),
          );
        },
      ),
    );
    client = OfficialApiClient(
      session: session,
      dio: dio,
      config: ApiConfig(userAgent: 'ArtRelay-Test/1.0'),
      delay: delay,
    );
  }

  late final OfficialApiClient client;
  final List<RequestOptions> requests;
  final List<Map<String, String>> tokenForms;
}

final class ResponseSpec {
  const ResponseSpec(this.status, this.data);

  final int status;
  final Object? data;
}

final class MemoryStore implements TokenStore {
  MemoryStore(this.value);

  AuthTokens? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<AuthTokens?> read() async => value;

  @override
  Future<void> write(AuthTokens tokens) async => value = tokens;
}

final class QueueOAuthEndpoint implements OAuthEndpoint {
  QueueOAuthEndpoint(this.responses, this.forms);

  final List<Map<String, Object?>> responses;
  final List<Map<String, String>> forms;

  @override
  Future<Map<String, Object?>> postForm(
    Uri endpoint,
    Map<String, String> form,
  ) async {
    forms.add(form);
    return responses.removeAt(0);
  }
}
