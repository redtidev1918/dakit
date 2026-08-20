import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dakit_api/dakit_api.dart';
import 'package:dakit_core/dakit_core.dart';
import 'package:dio/dio.dart';

NetworkProfile resolveNetworkProfile(String? proxy) {
  if (proxy != null && proxy.trim().isNotEmpty) {
    final separator = proxy.indexOf(':');
    if (separator <= 0 || separator == proxy.length - 1) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'network.proxy.usage',
        message: 'Proxy must be HOST:PORT.',
      );
    }
    return NetworkProfile.httpProxy(
      proxyServer: HttpProxyServer(
        host: proxy.substring(0, separator),
        port: int.tryParse(proxy.substring(separator + 1)) ?? -1,
      ),
    );
  }
  return NetworkProfile.environment();
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
}) async {
  final dio = createNetworkDio(
    profile: profile,
    options: BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 30),
    ),
  );
  try {
    final response = await dio.get<List<int>>(
      asset.uri.toString(),
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null) {
      throw const DAKitException(
        kind: DAKitFailureKind.network,
        code: 'media.download.empty',
        message: 'The download response contained no bytes.',
      );
    }
    final filename = safeFilename(
      asset.filename ?? asset.uri!.pathSegments.lastOrNull ?? 'original.bin',
    );
    final file = File(
      '${outputDirectory.path}${Platform.pathSeparator}$filename',
    );
    await file.writeAsBytes(bytes, flush: true);
    final digest = sha256.convert(bytes).toString();
    return 'saved=${file.path} bytes=${bytes.length} sha256=$digest '
        'mime=${asset.mimeType ?? response.headers.value('content-type')}';
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
  final parsed = int.tryParse(value) ?? fallback;
  if (parsed < 1) {
    throw DAKitException(
      kind: DAKitFailureKind.configuration,
      code: 'cli.option.invalid',
      message: '$label must be a positive integer.',
    );
  }
  return parsed;
}

String safeFilename(String value) {
  final leaf = value.replaceAll('\\', '/').split('/').last;
  final safe = leaf.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_').trim();
  return safe.isEmpty || safe == '.' || safe == '..' ? 'original.bin' : safe;
}
