import 'dart:convert';
import 'dart:io';

import 'package:dakit_api/dakit_api.dart';
import 'package:dakit_core/dakit_core.dart';
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
    expect(request.headers['User-Agent'], 'DAKit-Test/1.0');
    expect(request.headers['Accept-Encoding'], 'gzip');
    expect(request.uri.path, '/api/v1/oauth2/placebo');
  });

  test('accepts a host token provider without an OAuth session', () async {
    final provider = StaticTokenProvider(
      AuthTokens(
        accessToken: 'host-access',
        tokenType: 'Bearer',
        expiresAt: now.add(const Duration(hours: 1)),
      ),
    );
    late RequestOptions request;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            request = options;
            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                statusCode: 200,
                data: <String, Object?>{'status': 'success'},
              ),
            );
          },
        ),
      );

    await OfficialApiClient(session: provider, dio: dio).getJson('placebo');

    expect(request.headers['Authorization'], 'Bearer host-access');
    expect(provider.calls, 1);
  });

  test('sends authenticated mutations as URL-encoded POST forms', () async {
    final harness = ApiHarness(
      now: now,
      responses: <ResponseSpec>[
        const ResponseSpec(200, <String, Object?>{
          'success': true,
          'favourites': 12,
        }),
      ],
    );

    await harness.client.postFormJson(
      'collections/fave',
      form: const <String, Object?>{
        'deviationid': 'art-1',
        'folderid': <String>['folder-1', 'folder-2'],
      },
    );

    final request = harness.requests.single;
    expect(request.method, 'POST');
    expect(request.contentType, Headers.formUrlEncodedContentType);
    expect(request.data, <String, Object?>{
      'deviationid': 'art-1',
      'folderid': <String>['folder-1', 'folder-2'],
    });
    expect(request.headers['Authorization'], 'Bearer original-access');
  });

  test(
    'Dio wire encoding preserves arrays and nested form field names',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      late String body;
      final received = server.first.then((request) async {
        body = await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write('{"success":true}');
        await request.response.close();
      });

      await Dio().post<Object?>(
        'http://${server.address.host}:${server.port}/form',
        data: <String, Object?>{
          'folderid': <String>['folder-1', 'folder-2'],
          'watch[activity]': false,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      await received;

      final fields = body
          .split('&')
          .map(Uri.decodeQueryComponent)
          .toList(growable: false);
      expect(
        fields,
        containsAll(<String>[
          'folderid=folder-1',
          'folderid=folder-2',
          'watch[activity]=false',
        ]),
      );
    },
  );

  test('does not automatically retry non-idempotent mutations', () async {
    final delays = <Duration>[];
    final harness = ApiHarness(
      now: now,
      responses: <ResponseSpec>[
        const ResponseSpec(503, <String, Object?>{'error': 'server_error'}),
      ],
      delay: (duration) async => delays.add(duration),
    );

    await expectLater(
      harness.client.postFormJson(
        'comments/post/deviation/art-1',
        form: const <String, Object?>{'body': 'Hello'},
      ),
      throwsA(
        isA<DAKitException>().having(
          (error) => error.kind,
          'kind',
          DAKitFailureKind.upstream,
        ),
      ),
    );

    expect(harness.requests, hasLength(1));
    expect(delays, isEmpty);
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

  test('refreshes once after a mutation 401 and preserves the form', () async {
    final harness = ApiHarness(
      now: now,
      responses: <ResponseSpec>[
        const ResponseSpec(401, <String, Object?>{'error': 'unauthorized'}),
        const ResponseSpec(200, <String, Object?>{
          'success': true,
          'favourites': 1,
        }),
      ],
      tokenResponses: <Map<String, Object?>>[
        <String, Object?>{
          'access_token': 'refreshed-access',
          'token_type': 'Bearer',
          'expires_in': 3600,
        },
      ],
    );
    const form = <String, Object?>{'deviationid': 'art-1'};

    await harness.client.postFormJson('collections/fave', form: form);

    expect(harness.requests, hasLength(2));
    expect(harness.requests.every((request) => request.data == form), isTrue);
    expect(
      harness.requests.last.headers['Authorization'],
      'Bearer refreshed-access',
    );
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
        isA<DAKitException>().having(
          (error) => error.code,
          'code',
          'api.response.html_403',
        ),
      ),
    );
  });

  test(
    'preserves a bounded provider description for API diagnostics',
    () async {
      final description = List<String>.filled(100, 'rejected').join(' ');
      final harness = ApiHarness(
        now: now,
        responses: <ResponseSpec>[
          ResponseSpec(400, <String, Object?>{
            'error': 'invalid_request',
            'error_description': description,
          }),
        ],
      );

      await expectLater(
        harness.client.getJson('placebo'),
        throwsA(
          isA<DAKitException>().having(
            (error) =>
                (error.details['provider_description']! as String).length,
            'bounded description length',
            241,
          ),
        ),
      );
    },
  );

  test('applies connect and receive timeouts from ApiConfig', () async {
    final dio = Dio();
    OfficialApiClient(
      session: StaticTokenProvider(
        AuthTokens(
          accessToken: 'a',
          tokenType: 'Bearer',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      ),
      dio: dio,
      config: ApiConfig(
        connectTimeout: const Duration(seconds: 7),
        receiveTimeout: const Duration(seconds: 11),
      ),
    );
    addTearDown(dio.close);

    expect(dio.options.connectTimeout, const Duration(seconds: 7));
    expect(dio.options.receiveTimeout, const Duration(seconds: 11));
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
      redirectUri: Uri.parse('dakit://oauth/callback'),
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
      config: ApiConfig(userAgent: 'DAKit-Test/1.0'),
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

final class StaticTokenProvider implements AuthTokenProvider {
  StaticTokenProvider(this.tokens);

  final AuthTokens tokens;
  int calls = 0;

  @override
  Future<AuthTokens> validTokens({bool forceRefresh = false}) async {
    calls += 1;
    return tokens;
  }
}
