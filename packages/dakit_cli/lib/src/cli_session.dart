import 'dart:convert';
import 'dart:io';

import 'package:dakit_api/dakit_api.dart';
import 'package:dakit_core/dakit_core.dart';

final class StaticTokenProvider implements AuthTokenProvider {
  const StaticTokenProvider(this.tokens);

  final AuthTokens tokens;

  @override
  Future<AuthTokens> validTokens({bool forceRefresh = false}) async => tokens;
}

final class FileTokenStore implements TokenStore {
  FileTokenStore({String? path}) : path = path ?? _defaultPath();

  final String path;

  @override
  Future<AuthTokens?> read() async {
    final file = File(path);
    if (!await file.exists()) return null;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) return null;
    final map = decoded.map((key, value) => MapEntry(key.toString(), value));
    final accessToken = map['access_token'];
    final tokenType = map['token_type'];
    final expiresAt = map['expires_at'];
    if (accessToken is! String ||
        tokenType is! String ||
        expiresAt is! String) {
      return null;
    }
    final rawScopes = map['scopes'];
    return AuthTokens(
      accessToken: accessToken,
      tokenType: tokenType,
      expiresAt: DateTime.parse(expiresAt),
      refreshToken: map['refresh_token'] as String?,
      scopes: rawScopes is List
          ? rawScopes.map((value) => value.toString()).toSet()
          : const <String>{},
    );
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{'access_token': tokens.accessToken, 'token_type': tokens.tokenType, 'expires_at': tokens.expiresAt.toUtc().toIso8601String(), 'refresh_token': tokens.refreshToken, 'scopes': tokens.scopes.toList()..sort()})}\n',
      flush: true,
    );
    if (!Platform.isWindows) {
      await Process.run('chmod', <String>['600', path]);
    }
  }

  @override
  Future<void> clear() async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  static String _defaultPath() {
    final configured = Platform.environment['DAKIT_CONFIG_HOME'];
    final base =
        configured ??
        (Platform.isWindows
            ? Platform.environment['APPDATA']
            : '${Platform.environment['HOME']}/.config');
    return '$base/dakit/credentials.json';
  }
}

final class CliContext {
  CliContext({
    required this.profile,
    required this.diagnostics,
    required this.tokens,
  });

  final NetworkProfile profile;
  final DiagnosticSink diagnostics;
  final AuthTokens tokens;

  late final OfficialApiClient transport = OfficialApiClient(
    session: StaticTokenProvider(tokens),
    networkProfile: profile,
    diagnostics: diagnostics,
  );
}
