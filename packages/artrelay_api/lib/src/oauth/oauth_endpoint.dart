import 'package:artrelay_core/artrelay_core.dart';
import 'package:dio/dio.dart';

abstract interface class OAuthEndpoint {
  Future<Map<String, Object?>> postForm(Uri endpoint, Map<String, String> form);
}

final class DioOAuthEndpoint implements OAuthEndpoint {
  DioOAuthEndpoint({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  Future<Map<String, Object?>> postForm(
    Uri endpoint,
    Map<String, String> form,
  ) async {
    try {
      final response = await _dio.post<Object?>(
        endpoint.toString(),
        data: FormData.fromMap(form),
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.json,
        ),
      );
      final data = response.data;
      if (data is! Map<String, Object?>) {
        throw const ArtRelayException(
          kind: ArtRelayFailureKind.parsing,
          code: 'oauth.response.invalid_json',
          message: 'The OAuth endpoint returned an unexpected response.',
        );
      }
      return data;
    } on ArtRelayException {
      rethrow;
    } on DioException catch (error) {
      final responseData = error.response?.data;
      final provider = responseData is Map<String, Object?>
          ? responseData['error'] as String?
          : null;
      final description = responseData is Map<String, Object?>
          ? responseData['error_description'] as String?
          : null;
      throw ArtRelayException(
        kind: ArtRelayFailureKind.authentication,
        code: provider == null
            ? 'oauth.http.failed'
            : 'oauth.provider.$provider',
        message: description ?? 'The OAuth endpoint request failed.',
        retryable:
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            (error.response?.statusCode ?? 0) >= 500,
        details: <String, Object?>{
          if (error.response?.statusCode case final int status)
            'status': status,
        },
        cause: error,
      );
    }
  }
}
