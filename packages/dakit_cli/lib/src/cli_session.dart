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
    final Object? decoded;
    try {
      decoded = jsonDecode(await file.readAsString());
    } on FormatException catch (error) {
      throw DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'cli.credentials.invalid_json',
        message: 'The saved credentials file is not valid JSON.',
        cause: error,
        details: <String, Object?>{'path': path},
      );
    }
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
    try {
      return AuthTokens(
        accessToken: accessToken,
        tokenType: tokenType,
        expiresAt: DateTime.parse(expiresAt),
        refreshToken: map['refresh_token'] as String?,
        scopes: rawScopes is List
            ? rawScopes.map((value) => value.toString()).toSet()
            : const <String>{},
      );
    } on FormatException catch (error) {
      throw DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'cli.credentials.invalid_expiry',
        message: 'The saved credential expiry time is invalid.',
        cause: error,
        details: <String, Object?>{'path': path},
      );
    }
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
    final base = configured != null && configured.trim().isNotEmpty
        ? configured.trim()
        : _platformConfigHome();
    return '${Directory(base).path}${Platform.pathSeparator}dakit'
        '${Platform.pathSeparator}credentials.json';
  }

  static String _platformConfigHome() {
    if (Platform.isWindows) {
      return Platform.environment['APPDATA'] ??
          Platform.environment['LOCALAPPDATA'] ??
          _missingConfigHome();
    }
    final xdg = Platform.environment['XDG_CONFIG_HOME'];
    if (xdg != null && xdg.trim().isNotEmpty) return xdg;
    final home = Platform.environment['HOME'];
    if (home != null && home.trim().isNotEmpty) return '$home/.config';
    return _missingConfigHome();
  }

  static Never _missingConfigHome() => throw const DAKitException(
    kind: DAKitFailureKind.configuration,
    code: 'cli.config_home.missing',
    message: 'Cannot locate a config directory. Set DAKIT_CONFIG_HOME.',
  );
}

final class CliOAuthSettings {
  const CliOAuthSettings({required this.clientId, required this.redirectUri});

  final String clientId;
  final Uri redirectUri;
}

final class FileCliSettingsStore {
  FileCliSettingsStore({String? path}) : path = path ?? _defaultPath();

  final String path;

  Future<CliOAuthSettings?> read() async {
    final file = File(path);
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final clientId = decoded['client_id'];
      final redirect = decoded['redirect_uri'];
      final redirectUri = redirect is String ? Uri.tryParse(redirect) : null;
      if (clientId is! String ||
          clientId.trim().isEmpty ||
          redirectUri == null ||
          !redirectUri.hasScheme) {
        return null;
      }
      return CliOAuthSettings(
        clientId: clientId.trim(),
        redirectUri: redirectUri,
      );
    } on FormatException catch (error) {
      throw DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'cli.settings.invalid_json',
        message: 'The saved CLI settings file is not valid JSON.',
        cause: error,
        details: <String, Object?>{'path': path},
      );
    }
  }

  Future<void> write(CliOAuthSettings settings) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(<String, String>{'client_id': settings.clientId, 'redirect_uri': settings.redirectUri.toString()})}\n',
      flush: true,
    );
    if (!Platform.isWindows) {
      await Process.run('chmod', <String>['600', path]);
    }
  }

  Future<void> clear() async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  static String _defaultPath() =>
      '${File(FileTokenStore().path).parent.path}${Platform.pathSeparator}client.json';
}

final class CliContext {
  CliContext({
    required this.profile,
    required this.diagnostics,
    required this.session,
  });

  final NetworkProfile profile;
  final DiagnosticSink diagnostics;
  final AuthTokenProvider session;

  late final OfficialApiClient transport = OfficialApiClient(
    session: session,
    networkProfile: profile,
    diagnostics: diagnostics,
  );
}
