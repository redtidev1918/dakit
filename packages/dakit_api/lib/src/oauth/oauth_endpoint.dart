import 'package:dakit_core/dakit_core.dart';
import 'package:dio/dio.dart';

import '../http/network_adapter.dart';
import '../http/network_profile.dart';

abstract interface class OAuthEndpoint {
  Future<Map<String, Object?>> postForm(Uri endpoint, Map<String, String> form);
}

final class DioOAuthEndpoint implements OAuthEndpoint {
  DioOAuthEndpoint({
    Dio? dio,
    NetworkProfile? networkProfile,
    this.diagnostics = const NoopDiagnosticSink(),
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 30),
  }) : _dio = _resolveDio(dio, networkProfile, connectTimeout, receiveTimeout);

  static Dio _resolveDio(
    Dio? dio,
    NetworkProfile? profile,
    Duration connectTimeout,
    Duration receiveTimeout,
  ) {
    if (dio != null && profile != null) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'network.transport.ambiguous',
        message: 'Provide either a Dio client or a network profile, not both.',
      );
    }
    return dio ??
        createNetworkDio(
          profile: profile ?? NetworkProfile.environment(),
          options: BaseOptions(
            connectTimeout: connectTimeout,
            receiveTimeout: receiveTimeout,
          ),
        );
  }

  final Dio _dio;
  final DiagnosticSink diagnostics;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  @override
  Future<Map<String, Object?>> postForm(
    Uri endpoint,
    Map<String, String> form,
  ) async {
    final started = DateTime.now();
    try {
      final response = await _dio.post<Object?>(
        endpoint.toString(),
        data: form,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.json,
          sendTimeout: connectTimeout,
          receiveTimeout: receiveTimeout,
        ),
      );
      final data = response.data;
      if (data is! Map<String, Object?>) {
        throw const DAKitException(
          kind: DAKitFailureKind.parsing,
          code: 'oauth.response.invalid_json',
          message: 'The OAuth endpoint returned an unexpected response.',
        );
      }
      _record(
        DiagnosticLevel.info,
        'oauth.http.ok',
        endpoint,
        started,
        status: response.statusCode,
      );
      return data;
    } on DAKitException {
      rethrow;
    } on DioException catch (error) {
      final networkFailure = _networkFailure(error);
      if (networkFailure != null) {
        _record(DiagnosticLevel.error, networkFailure.code, endpoint, started);
        throw networkFailure;
      }
      final responseData = error.response?.data;
      final provider = responseData is Map<String, Object?>
          ? responseData['error'] as String?
          : null;
      final description = responseData is Map<String, Object?>
          ? responseData['error_description'] as String?
          : null;
      final failure = DAKitException(
        kind: DAKitFailureKind.authentication,
        code: provider == null
            ? 'oauth.http.failed'
            : 'oauth.provider.$provider',
        message: description ?? 'The OAuth endpoint request failed.',
        retryable: (error.response?.statusCode ?? 0) >= 500,
        details: <String, Object?>{
          if (error.response?.statusCode case final int status)
            'status': status,
          'provider_error': ?provider,
          ...description == null
              ? const <String, Object?>{}
              : <String, Object?>{
                  'provider_description': _boundedDescription(description),
                },
        },
        cause: error,
      );
      _record(
        DiagnosticLevel.error,
        failure.code,
        endpoint,
        started,
        status: error.response?.statusCode,
      );
      throw failure;
    }
  }

  static DAKitException? _networkFailure(DioException error) {
    if (error.response != null) return null;
    final code = switch (error.type) {
      DioExceptionType.connectionTimeout => 'network.connect_timeout',
      DioExceptionType.sendTimeout => 'network.send_timeout',
      DioExceptionType.receiveTimeout => 'network.receive_timeout',
      DioExceptionType.badCertificate => 'network.tls_certificate',
      DioExceptionType.connectionError => 'network.connection',
      DioExceptionType.cancel => 'oauth.request.cancelled',
      _ => 'network.request_failed',
    };
    return DAKitException(
      kind: error.type == DioExceptionType.cancel
          ? DAKitFailureKind.cancelled
          : DAKitFailureKind.network,
      code: code,
      message: error.type == DioExceptionType.cancel
          ? 'The OAuth endpoint request was cancelled.'
          : 'The OAuth endpoint could not reach the service.',
      retryable:
          error.type != DioExceptionType.badCertificate &&
          error.type != DioExceptionType.cancel,
      cause: error,
    );
  }

  static String _boundedDescription(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.length <= 240
        ? normalized
        : '${normalized.substring(0, 240)}…';
  }

  void _record(
    DiagnosticLevel level,
    String code,
    Uri endpoint,
    DateTime started, {
    int? status,
  }) {
    diagnostics.add(
      DiagnosticEvent(
        stage: DiagnosticStage.http,
        level: level,
        code: code,
        message: 'OAuth endpoint HTTP event.',
        elapsed: DateTime.now().difference(started),
        attributes: <String, Object?>{
          'host': endpoint.host,
          'path': endpoint.path,
          ...status == null
              ? const <String, Object?>{}
              : <String, Object?>{'status': status},
        },
      ),
    );
  }
}
