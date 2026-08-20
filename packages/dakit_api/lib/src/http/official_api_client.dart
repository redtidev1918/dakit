import 'dart:async';

import 'package:dakit_core/dakit_core.dart';
import 'package:dio/dio.dart';

import 'api_config.dart';
import 'network_adapter.dart';
import 'network_profile.dart';

typedef Delay = Future<void> Function(Duration duration);

abstract interface class OfficialApiTransport {
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    CancelToken? cancelToken,
  });
}

/// Official API transport that can also perform form-encoded mutations.
///
/// Mutations refresh once after an authentication failure, but are not
/// automatically retried after rate-limit or server responses because the
/// provider may already have applied a non-idempotent operation.
abstract interface class OfficialApiMutationTransport
    implements OfficialApiTransport {
  Future<Map<String, Object?>> postFormJson(
    String path, {
    Map<String, Object?> form = const <String, Object?>{},
    CancelToken? cancelToken,
  });
}

/// Versioned, authenticated transport for the official API.
final class OfficialApiClient implements OfficialApiMutationTransport {
  factory OfficialApiClient({
    required AuthTokenProvider session,
    Dio? dio,
    NetworkProfile? networkProfile,
    ApiConfig? config,
    DiagnosticSink diagnostics = const NoopDiagnosticSink(),
    Delay? delay,
  }) => OfficialApiClient._(
    session,
    _resolveDio(dio, networkProfile),
    config ?? ApiConfig(),
    diagnostics,
    delay ?? Future<void>.delayed,
  );

  static Dio _resolveDio(Dio? dio, NetworkProfile? profile) {
    if (dio != null && profile != null) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'network.transport.ambiguous',
        message: 'Provide either a Dio client or a network profile, not both.',
      );
    }
    return dio ??
        createNetworkDio(profile: profile ?? NetworkProfile.environment());
  }

  OfficialApiClient._(
    this._session,
    this._dio,
    this.config,
    this._diagnostics,
    this._delay,
  ) {
    _dio.options.connectTimeout = config.connectTimeout;
  }

  final AuthTokenProvider _session;
  final Dio _dio;
  final DiagnosticSink _diagnostics;
  final Delay _delay;
  final ApiConfig config;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    CancelToken? cancelToken,
  }) => _requestJson(
    path,
    method: 'GET',
    query: query,
    cancelToken: cancelToken,
    retryTransientResponses: true,
  );

  @override
  Future<Map<String, Object?>> postFormJson(
    String path, {
    Map<String, Object?> form = const <String, Object?>{},
    CancelToken? cancelToken,
  }) => _requestJson(
    path,
    method: 'POST',
    form: form,
    cancelToken: cancelToken,
    retryTransientResponses: false,
  );

  Future<Map<String, Object?>> _requestJson(
    String path, {
    required String method,
    required bool retryTransientResponses,
    Map<String, Object?> query = const <String, Object?>{},
    Map<String, Object?>? form,
    CancelToken? cancelToken,
  }) async {
    final uri = _resolve(path);
    var tokens = await _session.validTokens();
    var refreshed = false;
    var retries = 0;

    while (true) {
      final started = DateTime.now();
      try {
        final response = await _dio.request<Object?>(
          uri.toString(),
          queryParameters: query,
          data: form,
          cancelToken: cancelToken,
          options: Options(
            method: method,
            headers: <String, Object?>{
              Headers.acceptHeader: Headers.jsonContentType,
              'Accept-Encoding': 'gzip',
              'User-Agent': config.userAgent,
              'Authorization': '${tokens.tokenType} ${tokens.accessToken}',
              'dA-minor-version': config.minorVersion.toString(),
            },
            contentType: form == null
                ? null
                : Headers.formUrlEncodedContentType,
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
          method: method,
          status: status,
          retry: retries,
        );

        if (status == 401 && !refreshed) {
          tokens = await _session.validTokens(forceRefresh: true);
          refreshed = true;
          continue;
        }
        if (retryTransientResponses &&
            _retryableStatus(status) &&
            retries < config.retryPolicy.maxRetries) {
          retries += 1;
          await _delay(config.retryPolicy.delayFor(retries));
          continue;
        }
        if (status >= 400) throw _responseFailure(response);

        final data = response.data;
        if (data is! Map<String, Object?>) {
          throw const DAKitException(
            kind: DAKitFailureKind.parsing,
            code: 'api.response.invalid_json',
            message: 'The official API returned an unexpected response body.',
          );
        }
        return data;
      } on DAKitException {
        rethrow;
      } on DioException catch (error) {
        final failure = _dioFailure(error);
        _record(
          DiagnosticLevel.error,
          failure.code,
          path,
          started,
          method: method,
        );
        throw failure;
      }
    }
  }

  Uri _resolve(String path) {
    final candidate = Uri.parse(path);
    if (candidate.hasScheme ||
        candidate.hasAuthority ||
        candidate.hasQuery ||
        candidate.hasFragment ||
        path.startsWith('/')) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'api.path.invalid',
        message: 'API paths must be relative and contain no query or fragment.',
      );
    }
    return config.baseUri.resolve(path);
  }

  static bool _retryableStatus(int status) =>
      status == 429 || status == 500 || status == 503;

  DAKitException _responseFailure(Response<Object?> response) {
    final status = response.statusCode ?? 0;
    final data = response.data;
    if (status == 403 && data is String && data.trimLeft().startsWith('<')) {
      return const DAKitException(
        kind: DAKitFailureKind.upstream,
        code: 'api.response.html_403',
        message: 'The service rejected the HTTP client before API processing.',
      );
    }
    final body = data is Map<String, Object?>
        ? data
        : const <String, Object?>{};
    final rawProviderCode = body['error'];
    final providerCode = rawProviderCode is String ? rawProviderCode : null;
    final rawDescription = body['error_description'];
    final description = rawDescription is String ? rawDescription : null;
    final kind = switch (status) {
      401 => DAKitFailureKind.authentication,
      403 => DAKitFailureKind.authorization,
      404 => DAKitFailureKind.notFound,
      429 => DAKitFailureKind.rateLimit,
      >= 500 => DAKitFailureKind.upstream,
      _ => DAKitFailureKind.upstream,
    };
    return DAKitException(
      kind: kind,
      code: providerCode == null
          ? 'api.http.$status'
          : 'api.provider.$providerCode',
      message: description ?? 'The official API request failed.',
      retryable: _retryableStatus(status),
      details: <String, Object?>{
        'status': status,
        if (body['error_code'] case final Object code) 'provider_code': code,
        if (description != null)
          'provider_description': _boundedDescription(description),
      },
    );
  }

  static DAKitException _dioFailure(DioException error) {
    if (error.type == DioExceptionType.cancel) {
      return DAKitException(
        kind: DAKitFailureKind.cancelled,
        code: 'api.request.cancelled',
        message: 'The API request was cancelled.',
        cause: error,
      );
    }
    return DAKitException(
      kind: DAKitFailureKind.network,
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

  static String _boundedDescription(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.length <= 240
        ? normalized
        : '${normalized.substring(0, 240)}…';
  }

  void _record(
    DiagnosticLevel level,
    String code,
    String path,
    DateTime started, {
    required String method,
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
          'method': method,
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
