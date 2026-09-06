import 'dart:async';

import 'package:dakit_core/dakit_core.dart';
import 'package:dio/dio.dart';

import '../http/network_adapter.dart';
import '../http/network_profile.dart';
import '../redaction.dart';

/// Result of resolving a DeviantArt deviation through the website's own
/// `_puppy/dadeviation/init` endpoint.
///
/// Unlike the OAuth API, the website endpoint (when called with a logged-in
/// web cookie) returns **every** media asset for mature multi-image works:
/// the main file plus each additional page.
final class WebMediaResult {
  const WebMediaResult({
    required this.deviationId,
    required this.uuid,
    required this.isMature,
    required this.isMultiMedia,
    required this.assets,
  });

  /// Numeric deviation id (as it appears in a web URL).
  final String deviationId;

  /// Canonical UUID, usable with the official API.
  final String uuid;

  final bool isMature;
  final bool isMultiMedia;

  /// Main asset first, then additional pages in page order.
  final List<MediaAsset> assets;
}

/// Client for DeviantArt's private website (`_puppy`) endpoints.
///
/// This is the only channel that serves mature multi-image works unblurred:
/// the OAuth API 404s them and omits additional media, while the website
/// `init` payload includes the signed CDN URLs when presented with a valid
/// web cookie.
final class WebDeviationClient {
  WebDeviationClient({
    required NetworkProfile networkProfile,
    WebSession? session,
    Dio? dio,
    DiagnosticSink diagnostics = const NoopDiagnosticSink(),
    String userAgent = _defaultUserAgent,
  }) : _session = session,
       _dio = dio ??
           createNetworkDio(
             profile: networkProfile,
             options: BaseOptions(
               connectTimeout: const Duration(seconds: 20),
               receiveTimeout: const Duration(seconds: 30),
             ),
           ),
       _diagnostics = diagnostics,
       _userAgent = userAgent;

  static const String _defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static const Redactor _redactor = Redactor();

  final WebSession? _session;
  final Dio _dio;
  final DiagnosticSink _diagnostics;
  final String _userAgent;

  bool get hasWebSession => _session?.isPresent ?? false;

  /// Resolves a numeric deviation [id] (from a web URL / fav.me) and returns
  /// every media asset the website exposes. Numeric ids use the website
  /// endpoint; UUIDs are returned as-is.
  ///
  /// [username] is forwarded as the optional `username` hint the website uses
  /// to disambiguate renamed works.
  Future<WebMediaResult> deviationMedia(
    String id, {
    String? username,
    CancelToken? cancelToken,
  }) async {
    final started = DateTime.now();
    try {
      final data = await _init(id, username: username, cancelToken: cancelToken);

      final deviation = data['deviation'];
      if (deviation is! Map<String, Object?>) {
        throw const DAKitException(
          kind: DAKitFailureKind.parsing,
          code: 'web.init.no_deviation',
          message: 'The website init payload did not contain a deviation.',
        );
      }

      final extended = deviation['extended'];
      final uuid = extended is Map ? extended['deviationUuid'] : null;
      if (uuid is! String || uuid.isEmpty) {
        throw const DAKitException(
          kind: DAKitFailureKind.notFound,
          code: 'web.init.no_uuid',
          message: 'Could not resolve the deviation to a UUID.',
        );
      }

      final media = deviation['media'];
      final assets = <MediaAsset>[];
      final baseUri = _baseUri(media);

      // Main media.
      final main = _mediaAsset(
        media,
        baseUri: baseUri,
        id: '$id:original',
        role: MediaRole.original,
        index: 0,
      );
      if (main != null) assets.add(main);

      // Additional pages (multi-image works).
      final additional = extended is Map ? extended['additionalMedia'] : null;
      if (additional is List) {
        var page = 1;
        for (final item in additional) {
          if (item is! Map<String, Object?>) continue;
          final itemMedia = item['media'];
          final asset = _mediaAsset(
            itemMedia is Map<String, Object?> ? itemMedia : item,
            baseUri: _baseUri(itemMedia is Map<String, Object?> ? itemMedia : media),
            id: '$id:page$page',
            role: MediaRole.attachment,
            index: page,
          );
          if (asset != null) {
            assets.add(asset);
            page += 1;
          }
        }
      }

      if (assets.isEmpty) {
        throw const DAKitException(
          kind: DAKitFailureKind.parsing,
          code: 'web.init.no_media',
          message: 'The website init payload exposed no downloadable media.',
        );
      }

      final bool mature = switch (deviation['isMature']) {
        final bool b => b,
        final String s => s.toLowerCase() == 'true',
        _ => false,
      };

      _record(DiagnosticLevel.info, 'web.init.ok', id, started, <String, Object?>{
        'assets': assets.length,
        'mature': mature,
        'pages': additional is List ? additional.length : 0,
      });

      return WebMediaResult(
        deviationId: id,
        uuid: uuid,
        isMature: mature,
        isMultiMedia: assets.length > 1,
        assets: List<MediaAsset>.unmodifiable(assets),
      );
    } on DAKitException {
      rethrow;
    } on DioException catch (error) {
      final failure = _dioFailure(error);
      _record(DiagnosticLevel.error, failure.code, id, started, const <String, Object?>{});
      throw failure;
    }
  }

  Future<Map<String, Object?>> _init(
    String id, {
    String? username,
    CancelToken? cancelToken,
  }) async {
    // The website requires a CSRF token scraped from the home page.
    final home = await _dio.get<String>(
      'https://www.deviantart.com/',
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.plain,
        headers: _headers(accept: 'text/html'),
        validateStatus: (_) => true,
      ),
    );
    if ((home.statusCode ?? 0) >= 400) {
      throw DAKitException(
        kind: DAKitFailureKind.upstream,
        code: 'web.home.blocked',
        message:
            'The DeviantArt website rejected the client (status ${home.statusCode}). '
            'This usually means the egress IP is blocked; try a different network or proxy.',
        retryable: true,
      );
    }
    final csrf = RegExp(r"window\.__CSRF_TOKEN__ = '([^']*)'")
        .firstMatch(home.data ?? '')
        ?.group(1);
    if (csrf == null || csrf.isEmpty) {
      throw const DAKitException(
        kind: DAKitFailureKind.upstream,
        code: 'web.csrf.unavailable',
        message: 'Could not read the DeviantArt CSRF token from the home page.',
        retryable: true,
      );
    }

    final response = await _dio.get<Object?>(
      'https://www.deviantart.com/_puppy/dadeviation/init',
      queryParameters: <String, Object?>{
        'deviationid': id,
        if (username != null && username.isNotEmpty) 'username': username,
        // `type` has been a required enum (art/journal) since 2026; omitting
        // it returns 400.
        'type': 'art',
        'include_session': 'false',
        'csrf_token': csrf,
        'mature_content': 'true',
      },
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.json,
        headers: _headers(accept: 'application/json'),
        validateStatus: (_) => true,
      ),
    );

    final status = response.statusCode ?? 0;
    if (status == 404) {
      throw const DAKitException(
        kind: DAKitFailureKind.notFound,
        code: 'web.init.not_found',
        message:
            'DeviantArt returned 404 for this deviation. Mature works require '
            'a logged-in web cookie (see WebSession); the OAuth API cannot see them.',
      );
    }
    if (status >= 400) {
      throw DAKitException(
        kind: DAKitFailureKind.upstream,
        code: 'web.init.http_$status',
        message: 'The DeviantArt init endpoint failed with status $status.',
        retryable: status == 429 || status >= 500,
      );
    }
    final data = response.data;
    if (data is! Map<String, Object?>) {
      throw const DAKitException(
        kind: DAKitFailureKind.parsing,
        code: 'web.init.invalid_json',
        message: 'The DeviantArt init endpoint returned an unexpected body.',
      );
    }
    return data;
  }

  Map<String, String> _headers({required String accept}) => <String, String>{
    'User-Agent': _userAgent,
    'Accept': accept,
    if (hasWebSession) 'Cookie': _session!.cookieHeader,
  };

  static String? _baseUri(Object? media) {
    if (media is Map && media['baseUri'] is String) {
      return media['baseUri'] as String;
    }
    return null;
  }

  /// Build a [MediaAsset] from a website `media` object.
  ///
  /// Modern DeviantArt serves the original file directly from `media.baseUri`
  /// (an absolute, token-signed CDN URL); the `token`/`prettyName`/`tokenConstraints`
  /// triplet is the older template form. We prefer a ready-to-download URL and
  /// never synthesise `/v1/fit` variants, which return 400/404.
  static MediaAsset? _mediaAsset(
    Object? mediaNode, {
    required String? baseUri,
    required String id,
    required MediaRole role,
    required int index,
  }) {
    if (mediaNode is! Map<String, Object?>) return null;
    final media = mediaNode['media'] is Map<String, Object?>
        ? mediaNode['media'] as Map<String, Object?>
        : mediaNode;

    final Uri? uri = _pickUri(media, baseUri: baseUri);
    if (uri == null) return null;

    final types = media['types'];
    String? mimeType;
    String? filename;
    int? width;
    int? height;
    int? byteLength;
    if (types is List) {
      // The highest-fidelity entry is typically the first; walk it for metadata.
      for (final entry in types) {
        if (entry is! Map<String, Object?>) continue;
        final c = entry['c'];
        if (c is String && mimeType == null) mimeType = c;
        if (entry['h'] is int && height == null) height = entry['h'] as int;
        if (entry['w'] is int && width == null) width = entry['w'] as int;
        if (entry['filesize'] is int && byteLength == null) {
          byteLength = entry['filesize'] as int;
        }
      }
    }
    final pretty = media['prettyName'];
    if (pretty is String && pretty.isNotEmpty) filename = pretty;

    final kind = _guessKind(mimeType, uri);

    return MediaAsset(
      id: id,
      kind: kind,
      role: role,
      availability: MediaAvailability.available,
      uri: uri,
      mimeType: mimeType,
      filename: filename,
      byteLength: byteLength,
      width: width,
      height: height,
    );
  }

  static Uri? _pickUri(Map<String, Object?> media, {required String? baseUri}) {
    // Prefer a fully-qualified baseUri (the modern signed original).
    final base = media['baseUri'] is String ? media['baseUri'] as String : baseUri;
    if (base != null && base.isNotEmpty) {
      final uri = Uri.tryParse(base);
      if (uri != null && uri.hasScheme && uri.host.isNotEmpty) return uri;
    }
    // Fall back to the first tokenised type's fully-resolved URL.
    final token = media['token'];
    final types = media['types'];
    if (token is String && types is List && types.isNotEmpty) {
      final first = types.first;
      if (first is Map<String, Object?>) {
        final t = first['t'];
        final cdn = first['cdnUrl'];
        final candidate = cdn is String && cdn.isNotEmpty
            ? cdn
            : (t is String && base != null ? '$base$t?token=$token' : null);
        if (candidate != null) {
          final uri = Uri.tryParse(candidate);
          if (uri != null && uri.hasScheme) return uri;
        }
      }
    }
    return null;
  }

  static MediaKind _guessKind(String? mimeType, Uri uri) {
    final mime = (mimeType ?? '').toLowerCase();
    final path = uri.path.toLowerCase();
    if (mime.startsWith('video/') || path.endsWith('.mp4') || path.endsWith('.webm')) {
      return MediaKind.video;
    }
    if (mime.contains('gif') || path.endsWith('.gif')) return MediaKind.animation;
    if (mime.startsWith('image/') ||
        path.endsWith('.png') ||
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.webp')) {
      return MediaKind.image;
    }
    return MediaKind.unknown;
  }

  static DAKitException _dioFailure(DioException error) {
    if (error.type == DioExceptionType.cancel) {
      return const DAKitException(
        kind: DAKitFailureKind.cancelled,
        code: 'web.request.cancelled',
        message: 'The website request was cancelled.',
      );
    }
    return DAKitException(
      kind: DAKitFailureKind.network,
      code: switch (error.type) {
        DioExceptionType.connectionTimeout => 'web.connect_timeout',
        DioExceptionType.sendTimeout => 'web.send_timeout',
        DioExceptionType.receiveTimeout => 'web.receive_timeout',
        DioExceptionType.badCertificate => 'web.tls_certificate',
        DioExceptionType.connectionError => 'web.connection',
        _ => 'web.request_failed',
      },
      message: 'The DeviantArt website could not be reached.',
      retryable: error.type != DioExceptionType.badCertificate,
      cause: error,
    );
  }

  void _record(
    DiagnosticLevel level,
    String code,
    String deviationId,
    DateTime started,
    Map<String, Object?> attributes,
  ) {
    _diagnostics.add(
      DiagnosticEvent(
        stage: DiagnosticStage.http,
        level: level,
        code: code,
        message: 'Website deviation request.',
        elapsed: DateTime.now().difference(started),
        // Cookie is never part of attributes; the redactor is applied
        // defensively in case a future field is added.
        attributes: _redactor.fields(<String, Object?>{
          'deviation': deviationId,
          ...attributes,
        }),
      ),
    );
  }

  void close() => _dio.close(force: true);
}
