import 'dart:convert';
import 'dart:typed_data';

import 'package:dakit_api/dakit_api.dart';
import 'package:dakit_core/dakit_core.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

/// A deterministic Dio adapter that replies to the website endpoints.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this._handler);

  final ResponseBody Function(RequestOptions options) _handler;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _handler(options);
  }
}

ResponseBody _html(String body) => ResponseBody.fromString(
      body,
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['text/html'],
      },
    );

ResponseBody _json(Object body) => ResponseBody.fromBytes(
      utf8.encode(jsonEncode(body)),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );

/// Mature multi-image `_puppy/init` payload: main + one additional page.
Map<String, Object?> _initPayload() => <String, Object?>{
      'deviation': <String, Object?>{
        'isMature': true,
        'media': <String, Object?>{
          'baseUri': 'https://images-wixmp.example.test/signed-main/full.png',
          'prettyName': 'main.png',
          'token': 'tok',
          'types': <Map<String, Object?>>[
            <String, Object?>{'t': '.png', 'c': 'image/png', 'h': 1200, 'w': 900},
          ],
        },
        'extended': <String, Object?>{
          'deviationUuid': '11111111-2222-3333-4444-555555555555',
          'additionalMedia': <Map<String, Object?>>[
            <String, Object?>{
              'media': <String, Object?>{
                'baseUri':
                    'https://images-wixmp.example.test/signed-extra/full2.png',
                'prettyName': 'page2.png',
                'token': 'tok',
                'types': <Map<String, Object?>>[
                  <String, Object?>{
                    't': '.png',
                    'c': 'image/png',
                    'h': 1000,
                    'w': 800,
                  },
                ],
              },
            },
          ],
        },
      },
    };

WebDeviationClient _client(ResponseBody Function(RequestOptions) handler) {
  final dio = Dio(BaseOptions())..httpClientAdapter = _StubAdapter(handler);
  return WebDeviationClient(
    networkProfile: NetworkProfile.direct(),
    session: WebSession.parse('auth=abc; auth_secure=def'),
    dio: dio,
  );
}

void main() {
  group('WebDeviationClient', () {
    test('returns every asset for a mature multi-image work', () async {
      final client = _client((options) {
        if (options.path.endsWith('/')) {
          return _html("<script>window.__CSRF_TOKEN__ = 'csrf-token'</script>");
        }
        return _json(_initPayload());
      });

      final result = await client.deviationMedia('1376900771');

      expect(result.uuid, '11111111-2222-3333-4444-555555555555');
      expect(result.isMature, isTrue);
      expect(result.isMultiMedia, isTrue);
      expect(result.assets, hasLength(2));
      // Main first, additional page second.
      expect(result.assets[0].role, MediaRole.original);
      expect(result.assets[1].role, MediaRole.attachment);
      expect(
        result.assets[0].uri.toString(),
        contains('signed-main/full.png'),
      );
      expect(
        result.assets[1].uri.toString(),
        contains('signed-extra/full2.png'),
      );
      expect(result.assets.every((a) => a.canTransfer), isTrue);
    });

    test('sends the web cookie on both requests and type=art', () async {
      RequestOptions? initRequest;
      final client = _client((options) {
        if (options.path.endsWith('/')) {
          return _html("<script>window.__CSRF_TOKEN__ = 'c'</script>");
        }
        initRequest = options;
        return _json(_initPayload());
      });

      await client.deviationMedia('123', username: 'someone');

      final req = initRequest!;
      expect(req.headers['cookie'], 'auth=abc; auth_secure=def');
      expect(req.queryParameters['type'], 'art');
      expect(req.queryParameters['deviationid'], '123');
      expect(req.queryParameters['username'], 'someone');
      expect(req.queryParameters['csrf_token'], 'c');
    });

    test('throws notFound with cookie hint on HTTP 404', () async {
      final client = _client((options) {
        if (options.path.endsWith('/')) {
          return _html("<script>window.__CSRF_TOKEN__ = 'c'</script>");
        }
        return ResponseBody.fromString('not found', 404);
      });

      expect(
        () => client.deviationMedia('999'),
        throwsA(
          isA<DAKitException>()
              .having((e) => e.kind, 'kind', DAKitFailureKind.notFound)
              .having((e) => e.message, 'message', contains('cookie')),
        ),
      );
    });

    test('diagnostic attributes never include the cookie', () async {
      final events = <DiagnosticEvent>[];
      final dio = Dio(BaseOptions())
        ..httpClientAdapter = _StubAdapter((options) {
          if (options.path.endsWith('/')) {
            return _html("<script>window.__CSRF_TOKEN__ = 'c'</script>");
          }
          return _json(_initPayload());
        });
      final client = WebDeviationClient(
        networkProfile: NetworkProfile.direct(),
        session: WebSession.parse('auth=topsecretvalue'),
        dio: dio,
        diagnostics: _CollectingSink(events),
      );

      await client.deviationMedia('1');

      final rendered = events.map((e) => e.toString()).join(' ');
      expect(rendered, isNot(contains('topsecretvalue')));
      expect(events.any((e) => e.attributes.containsKey('cookie')), isFalse);
    });
  });
}

class _CollectingSink implements DiagnosticSink {
  _CollectingSink(this.events);
  final List<DiagnosticEvent> events;
  @override
  void add(DiagnosticEvent event) => events.add(event);
}
