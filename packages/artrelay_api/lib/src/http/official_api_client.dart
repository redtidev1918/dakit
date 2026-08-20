import 'dart:async';

import 'package:artrelay_core/artrelay_core.dart';
import 'package:dio/dio.dart';

import '../oauth/oauth_session.dart';
import 'api_config.dart';

typedef Delay = Future<void> Function(Duration duration);

/// Versioned, authenticated transport for idempotent official API reads.
final class OfficialApiClient {
  factory OfficialApiClient({
    required OAuthSession session,
    Dio? dio,
    ApiConfig? config,
    DiagnosticSink diagnostics = const NoopDiagnosticSink(),
    Delay? delay,
  }) => OfficialApiClient._(
    session,
    dio ?? Dio(),
    config ?? ApiConfig(),
    diagnostics,
    delay ?? Future<void>.delayed,
  );

  OfficialApiClient._(
    this._session,
    this._dio,
    this.config,
    this._diagnostics,
    this._delay,
  ) {
    _dio.options.connectTimeout = config.connectTimeout;
  }

  final OAuthSession _session;
  final Dio _dio;
  final DiagnosticSink _diagnostics;
  final Delay _delay;
  final ApiConfig config;

  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    CancelToken? cancelToken,
  }) async {
    final uri = _resolve(path);
    var tokens = await _session.validTokens();
    var refreshed = false;
    var retries = 0;

    while (true) {
      final started = DateTime.now();
      try {
        final response = await _dio.get<Object?>(
          uri.toString(),
          queryParameters: query,
          cancelToken: cancelToken,
          options: Options(
            headers: <String, Object?>{
              Headers.acceptHeader: Headers.jsonContentType,
              'Accept-Encoding': 'gzip',
              'User-Agent': config.userAgent,
              'Authorization': '${tokens.tokenType} ${tokens.accessToken}',
              'dA-minor-version': config.minorVersion.toString(),
            },
            responseType: ResponseType.json,
            sendTimeout: config.connectTimeout,
            receiveTimeout: config.receiveTimeout,
            validateStatus: (_) => true,
          ),
        );
        final status = response.statusCode ?? 0;
        _record(
          status < 400 ? DiagnosticLevel.info : DiagnosticLevel.warning,
          'api.response',
          path,
          started,
          status: status,
          retry: retries,
        );

        if (status == 401 && !refreshed) {
          tokens = await _session.validTokens(forceRefresh: true);
          refreshed = true;
          continue;
        }
        if (_retryableStatus(status) &&
            retries < config.retryPolicy.maxRetries) {
          retries += 1;
          await _delay(config.retryPolicy.delayFor(retries));
          continue;
        }
        if (status >= 400) throw _responseFailure(response);

        final data = response.data;
        if (data is! Map<String, Object?>) {
          throw const ArtRelayException(
            kind: ArtRelayFailureKind.parsing,
            code: 'api.response.invalid_json',
            message: 'The official API returned an unexpected response body.',
          );
        }
        return data;
      } on ArtRelayException {
        rethrow;
      } on DioException catch (error) {
        final failure = _dioFailure(error);
        _record(DiagnosticLevel.error, failure.code, path, started);
        throw failure;
      }
    }
  }

  Uri _resolve(String path) {
    final candidate = Uri.parse(path);
    if (candidate.hasScheme || candidate.hasAuthority || path.startsWith('/')) {
      throw const ArtRelayException(
        kind: ArtRelayFailureKind.configuration,
        code: 'api.path.invalid',
        message: 'API paths must be relative to the configured base URI.',
      );
    }
    return config.baseUri.resolve(path);
  }

  static bool _retryableStatus(int status) =>
      status == 429 || status == 500 || status == 503;

  ArtRelayException _responseFailure(Response<Object?> response) {
    final status = response.statusCode ?? 0;
    final data = response.data;
    if (status == 403 && data is String && data.trimLeft().startsWith('<')) {
      return const ArtRelayException(
        kind: ArtRelayFailureKind.upstream,
        code: 'api.response.html_403',
        message: 'The service rejected the HTTP client before API processing.',
      );
    }
    final body = data is Map<String, Object?>
        ? data
        : const <String, Object?>{};
    final providerCode = body['error'] as String?;
    final description = body['error_description'] as String?;
    final kind = switch (status) {
      401 => ArtRelayFailureKind.authentication,
      403 => ArtRelayFailureKind.authorization,
      404 => ArtRelayFailureKind.notFound,
      429 => ArtRelayFailureKind.rateLimit,
      >= 500 => ArtRelayFailureKind.upstream,
      _ => ArtRelayFailureKind.upstream,
    };
    return ArtRelayException(
      kind: kind,
      code: providerCode == null
          ? 'api.http.$status'
          : 'api.provider.$providerCode',
      message: description ?? 'The official API request failed.',
      retryable: _retryableStatus(status),
      details: <String, Object?>{
        'status': status,
        if (body['error_code'] case final Object code) 'provider_code': code,
      },
    );
  }

  static ArtRelayException _dioFailure(DioException error) {
    if (error.type == DioExceptionType.cancel) {
      return ArtRelayException(
        kind: ArtRelayFailureKind.cancelled,
        code: 'api.request.cancelled',
        message: 'The API request was cancelled.',
        cause: error,
      );
    }
    return ArtRelayException(
      kind: ArtRelayFailureKind.network,
      code: switch (error.type) {
        DioExceptionType.connectionTimeout => 'network.connect_timeout',
        DioExceptionType.sendTimeout => 'network.send_timeout',
        DioExceptionType.receiveTimeout => 'network.receive_timeout',
        DioExceptionType.badCertificate => 'network.tls_certificate',
        DioExceptionType.connectionError => 'network.connection',
        _ => 'network.request_failed',
      },
      message: 'The API request could not reach the service.',
      retryable: error.type != DioExceptionType.badCertificate,
      cause: error,
    );
  }

  void _record(
    DiagnosticLevel level,
    String code,
    String path,
    DateTime started, {
    int? status,
    int? retry,
  }) {
    _diagnostics.add(
      DiagnosticEvent(
        stage: DiagnosticStage.http,
        level: level,
        code: code,
        message: 'Official API request event.',
        elapsed: DateTime.now().difference(started),
        attributes: <String, Object?>{
          'path': path,
          ...status == null
              ? const <String, Object?>{}
              : <String, Object?>{'status': status},
          ...retry == null
              ? const <String, Object?>{}
              : <String, Object?>{'retry': retry},
        },
      ),
    );
  }
}
