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
}) async {
  final dio = createNetworkDio(
    profile: profile,
    options: BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 30),
    ),
  );
  try {
    final filename = safeFilename(
      asset.filename ?? asset.uri!.pathSegments.lastOrNull ?? 'original.bin',
    );
    final file = File(
      '${outputDirectory.path}${Platform.pathSeparator}$filename',
    );
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
