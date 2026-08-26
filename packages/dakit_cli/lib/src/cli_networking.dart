import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dakit_api/dakit_api.dart';
import 'package:dakit_core/dakit_core.dart';
import 'package:dio/dio.dart';

NetworkProfile resolveNetworkProfile(
  String? proxy, {
  Map<String, String>? environment,
}) {
  final processEnvironment = environment ?? Platform.environment;
  final configured = proxy?.trim().isNotEmpty == true
      ? proxy!.trim()
      : (processEnvironment['all_proxy'] ??
            processEnvironment['ALL_PROXY'] ??
            '');
  if (configured.isNotEmpty) {
    final value = configured.trim();
    final uri = Uri.tryParse(value.contains('://') ? value : 'http://$value');
    if (uri == null ||
        uri.scheme != 'http' ||
        uri.host.isEmpty ||
        !uri.hasPort ||
        uri.port < 1 ||
        uri.port > 65535 ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'network.proxy.usage',
        message: 'Proxy must be HOST:PORT or http://HOST:PORT.',
      );
    }
    return NetworkProfile.httpProxy(
      proxyServer: HttpProxyServer(host: uri.host, port: uri.port),
    );
  }
  return NetworkProfile.environment(environment: environment);
}

Future<UserProfile> currentUser(
  AuthTokenProvider session,
  NetworkProfile profile, [
  DiagnosticSink diagnostics = const NoopDiagnosticSink(),
]) async {
  final transport = OfficialApiClient(
    session: session,
    networkProfile: profile,
    diagnostics: diagnostics,
  );
  return OfficialAccountRepository(transport).currentUser();
}

Future<String> downloadAsset({
  required MediaAsset asset,
  required NetworkProfile profile,
  required Directory outputDirectory,
  bool overwrite = false,
  String? filename,
  Future<void> Function(String savedPath)? onSaved,
}) async {
  final dio = createNetworkDio(
    profile: profile,
    options: BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 30),
    ),
  );
  try {
    final name =
        filename ??
        safeFilename(
          asset.filename ??
              asset.uri!.pathSegments.lastOrNull ??
              'original.bin',
        );
    final file = File('${outputDirectory.path}${Platform.pathSeparator}$name');
    if (await file.exists() && !overwrite) {
      return 'exists=${file.path} (use --overwrite to replace it)';
    }
    final partial = File('${file.path}.part');
    if (await partial.exists()) await partial.delete();
    try {
      final response = await dio.download(
        asset.uri.toString(),
        partial.path,
        deleteOnError: true,
      );
      final bytes = await partial.length();
      if (bytes == 0) {
        throw const DAKitException(
          kind: DAKitFailureKind.network,
          code: 'media.download.empty',
          message: 'The download response contained no bytes.',
        );
      }
      final digest = await sha256.bind(partial.openRead()).first;
      final backup = File('${file.path}.bak');
      var movedExisting = false;
      if (await file.exists()) {
        if (await backup.exists()) await backup.delete();
        await file.rename(backup.path);
        movedExisting = true;
      }
      try {
        await partial.rename(file.path);
        if (movedExisting && await backup.exists()) await backup.delete();
      } on Object {
        if (movedExisting && await backup.exists() && !await file.exists()) {
          await backup.rename(file.path);
        }
        rethrow;
      }
      if (onSaved != null) await onSaved(file.path);
      return 'saved=${file.path} bytes=$bytes sha256=$digest '
          'mime=${asset.mimeType ?? response.headers.value('content-type')}';
    } finally {
      if (await partial.exists()) await partial.delete();
    }
  } finally {
    dio.close(force: true);
  }
}

String? extractUuid(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final trimmed = value.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) return trimmed;
  final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
  return segments.isEmpty ? null : segments.last;
}

int positiveInt(String value, int fallback, String label) {
  final parsed = value.isEmpty ? fallback : int.tryParse(value);
  if (parsed == null) {
    throw DAKitException(
      kind: DAKitFailureKind.configuration,
      code: 'cli.option.invalid',
      message: '$label must be an integer.',
    );
  }
  if (parsed < 1) {
    throw DAKitException(
      kind: DAKitFailureKind.configuration,
      code: 'cli.option.invalid',
      message: '$label must be a positive integer.',
    );
  }
  return parsed;
}

int nonNegativeInt(String value, int fallback, String label) {
  final parsed = value.isEmpty ? fallback : int.tryParse(value);
  if (parsed == null || parsed < 0) {
    throw DAKitException(
      kind: DAKitFailureKind.configuration,
      code: 'cli.option.invalid',
      message: '$label must be a non-negative integer.',
    );
  }
  return parsed;
}

String searchQuery(Iterable<String> parts) => parts.join(' ').trim();

String terminalText(Object? value) => value
    .toString()
    .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String safeFilename(String value) {
  final leaf = value.replaceAll('\\', '/').split('/').last;
  final safe = leaf.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_').trim();
  return safe.isEmpty || safe == '.' || safe == '..' ? 'original.bin' : safe;
}

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

const String _cliUserAgent =
    'dakit/0.2 (command-line DeviantArt client; '
    '+https://github.com/redtidev1918/dakit)';

/// Resolves a numeric artwork id (from a web URL or fav.me link) to its UUID
/// through the website's public `_puppy/dadeviation/init` endpoint — the same
/// resolution DAViewer performs, needed because the official API rejects
/// numeric ids. UUIDs pass through unchanged. Throws [DAKitException] when the
/// id cannot be resolved.
Future<String> resolveArtworkUuid({
  required String id,
  String? username,
  required NetworkProfile profile,
}) async {
  if (id.isEmpty) {
    throw const DAKitException(
      kind: DAKitFailureKind.configuration,
      code: 'cli.url.empty_id',
      message: 'The URL does not contain an artwork id.',
    );
  }
  if (_uuidPattern.hasMatch(id)) return id;
  final dio = createNetworkDio(
    profile: profile,
    options: BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  try {
    final home = await dio.get<String>(
      'https://www.deviantart.com/',
      options: Options(
        responseType: ResponseType.plain,
        headers: <String, dynamic>{
          'User-Agent': _cliUserAgent,
          'Accept': 'text/html',
        },
      ),
    );
    final csrf = RegExp(r"window\.__CSRF_TOKEN__ = '([^']*)'")
        .firstMatch(home.data ?? '')
        ?.group(1);
    if (csrf == null || csrf.isEmpty) {
      throw const DAKitException(
        kind: DAKitFailureKind.network,
        code: 'web.csrf.unavailable',
        message: 'Could not read the DeviantArt CSRF token.',
      );
    }
    final response = await dio.get<Object?>(
      'https://www.deviantart.com/_puppy/dadeviation/init',
      queryParameters: <String, Object?>{
        'deviationid': id,
        if (username != null && username.isNotEmpty) 'username': username,
        'include_session': 'false',
        'csrf_token': csrf,
        'mature_content': true,
      },
      options: Options(
        responseType: ResponseType.json,
        headers: <String, dynamic>{
          'User-Agent': _cliUserAgent,
          'Accept': 'application/json',
        },
      ),
    );
    final data = response.data;
    final deviation = data is Map ? data['deviation'] : null;
    final extended = deviation is Map ? deviation['extended'] : null;
    final uuid = extended is Map ? extended['deviationUuid'] : null;
    if (uuid is! String || uuid.isEmpty) {
      throw DAKitException(
        kind: DAKitFailureKind.notFound,
        code: 'web.init.no_uuid',
        message: 'Could not resolve artwork $id to a UUID.',
      );
    }
    return uuid;
  } on DAKitException {
    rethrow;
  } on Object catch (error) {
    throw DAKitException(
      kind: DAKitFailureKind.network,
      code: 'web.init.unreachable',
      message: 'Could not reach the DeviantArt resolution endpoint: $error',
    );
  } finally {
    dio.close(force: true);
  }
}

/// A simple archive of already-downloaded deviation IDs (one per line),
/// mirroring gallery-dl's `--download-archive`. Records are appended after a
/// successful download so re-runs skip work already done.
final class DownloadArchive {
  DownloadArchive._(this._ids, this.path);

  final Set<String> _ids;
  final String path;

  static Future<DownloadArchive> open(String? path) async {
    if (path == null || path.trim().isEmpty) {
      return DownloadArchive._(<String>{}, '');
    }
    final file = File(path);
    final ids = <String>{};
    if (await file.exists()) {
      for (final line in await file.readAsLines()) {
        final id = line.trim();
        if (id.isNotEmpty) ids.add(id);
      }
    }
    return DownloadArchive._(ids, path);
  }

  bool contains(String id) => _ids.contains(id);

  Future<void> add(String id) async {
    if (path.isEmpty || !_ids.add(id)) return;
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsString('$id\n', mode: FileMode.append);
  }
}

/// Renders a `--filename` template over the current asset name.
/// Tokens: `{filename}` (server name without extension), `{ext}`, `{id}`,
/// `{title}`, `{username}`, `{published}` (YYYY-MM-DD).
String resolveFilenameTemplate(
  String template,
  MediaAsset asset, {
  String? artworkId,
  String? title,
  String? username,
  DateTime? published,
}) {
  final current =
      asset.filename ?? asset.uri?.pathSegments.lastOrNull ?? 'original.bin';
  final dot = current.lastIndexOf('.');
  final stem = dot > 0 ? current.substring(0, dot) : current;
  final ext = dot > 0 ? current.substring(dot + 1) : '';
  final publishedDay = published?.toIso8601String().substring(0, 10) ?? '';
  final rendered = template
      .replaceAll('{filename}', stem)
      .replaceAll('{ext}', ext)
      .replaceAll('{id}', artworkId ?? asset.id)
      .replaceAll('{title}', title ?? stem)
      .replaceAll('{username}', username ?? '')
      .replaceAll('{published}', publishedDay);
  return safeFilename(rendered);
}

/// Writes a `--write-info-json` metadata sidecar next to a downloaded file
/// (`<saved-path>.json`), mirroring gallery-dl's info-json output.
Future<void> writeInfoJson(String savedPath, Map<String, Object?> metadata) =>
    File('$savedPath.json').writeAsString('${jsonEncode(metadata)}\n');
