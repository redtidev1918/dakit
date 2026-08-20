import 'package:artrelay_api/artrelay_api.dart';
import 'package:artrelay_core/artrelay_core.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  final endpoint = Uri.parse('https://www.deviantart.com/oauth2/token');

  test('classifies a connection failure as network, not authentication', () {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException.connectionError(
            requestOptions: options,
            reason: 'offline',
          ),
        ),
      ),
    );

    expect(
      () => DioOAuthEndpoint(dio: dio).postForm(endpoint, const {}),
      throwsA(
        isA<ArtRelayException>()
            .having((error) => error.kind, 'kind', ArtRelayFailureKind.network)
            .having((error) => error.code, 'code', 'network.connection'),
      ),
    );
  });

  test('preserves provider OAuth failures as authentication failures', () {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException.badResponse(
            statusCode: 400,
            requestOptions: options,
            response: Response<Object?>(
              requestOptions: options,
              statusCode: 400,
              data: <String, Object?>{
                'error': 'invalid_grant',
                'error_description': 'The grant is invalid.',
              },
            ),
          ),
        ),
      ),
    );

    expect(
      () => DioOAuthEndpoint(dio: dio).postForm(endpoint, const {}),
      throwsA(
        isA<ArtRelayException>()
            .having(
              (error) => error.kind,
              'kind',
              ArtRelayFailureKind.authentication,
            )
            .having(
              (error) => error.code,
              'code',
              'oauth.provider.invalid_grant',
            ),
      ),
    );
  });

  test('rejects ambiguous custom Dio and profile configuration', () {
    expect(
      () =>
          DioOAuthEndpoint(dio: Dio(), networkProfile: NetworkProfile.direct()),
      throwsA(
        isA<ArtRelayException>().having(
          (error) => error.code,
          'code',
          'network.transport.ambiguous',
        ),
      ),
    );
  });
}
