import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:crypto/crypto.dart';
import 'package:dakit_api/dakit_api.dart';
import 'package:dakit_core/dakit_core.dart';
import 'package:dio/dio.dart';

const _defaultScopes = 'basic,browse';
const _usage = '''
DAKit command-line client

Usage:
  dakit login --client-id ID [--scopes basic,browse] [--proxy HOST:PORT]
  dakit whoami [--proxy HOST:PORT]
  dakit download UUID [--output DIR] [--proxy HOST:PORT]
  dakit status [--proxy HOST:PORT]

Environment:
  DAKIT_CLIENT_ID      Public OAuth client ID (login only)
  http_proxy / https_proxy
''';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addCommand('login', _loginParser())
    ..addCommand('whoami', _proxyParser())
    ..addCommand('download', _downloadParser())
    ..addCommand('status', _proxyParser());

  ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }

  final command = results.command;
  if (command == null) {
    stdout.writeln(_usage);
    return;
  }

  try {
    exitCode = await switch (command.name) {
      'login' => _login(command),
      'whoami' => _whoami(command),
      'download' => _download(command),
      'status' => _status(command),
      _ => Future<int>.value(64),
    };
  } on DAKitException catch (error) {
    stderr.writeln('${error.kind.name} ${error.code}: ${error.message}');
    exitCode = 1;
  } on Object catch (error) {
    stderr.writeln('unexpected: $error');
    exitCode = 1;
  }
}

ArgParser _loginParser() {
  final parser = ArgParser()
    ..addOption('client-id', abbr: 'c', help: 'Public OAuth client ID.')
    ..addOption(
      'scopes',
      defaultsTo: _defaultScopes,
      help: 'Comma-separated OAuth scopes.',
    )
    ..addOption('port', defaultsTo: '8765', help: 'Loopback callback port.')
    ..addOption('proxy', help: 'HTTP proxy as HOST:PORT.');
  return parser;
}

ArgParser _downloadParser() {
  final parser = _proxyParser()
    ..addOption('output', defaultsTo: 'downloads', help: 'Output directory.');
  return parser;
}

ArgParser _proxyParser() {
  return ArgParser()..addOption('proxy', help: 'HTTP proxy as HOST:PORT.');
}

Future<int> _login(ArgResults arguments) async {
  final clientId =
      arguments['client-id'] as String? ??
      Platform.environment['DAKIT_CLIENT_ID'];
  if (clientId == null || clientId.trim().isEmpty) {
    stderr.writeln('Provide --client-id or DAKIT_CLIENT_ID.');
    return 64;
  }

  final scopes = (arguments['scopes'] as String)
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();
  final port = int.tryParse(arguments['port'] as String) ?? 8765;
  if (port < 1 || port > 65535) {
    stderr.writeln('--port must be between 1 and 65535.');
    return 64;
  }

  final redirectUri = Uri.parse('http://127.0.0.1:$port/callback');
  final callbackSource = LoopbackCallbackSource(
    port: port,
    path: redirectUri.path,
  );
  await callbackSource.start();

  final config = OAuthConfig(
    clientId: clientId.trim(),
    redirectUri: redirectUri,
    scopes: scopes,
  );
  final profile = _profile(arguments['proxy'] as String?);
  final tokenStore = FileTokenStore();
  final endpoint = DioOAuthEndpoint(networkProfile: profile);
  final tokenClient = OAuthTokenClient(endpoint: endpoint);
  final session = OAuthSession(
    config: config,
    store: tokenStore,
    tokenClient: tokenClient,
  );
  final coordinator = OAuthAuthorizationCoordinator(
    config: config,
    launcher: const PlatformUriLauncher(),
    callbacks: callbackSource,
    pendingStore: MemoryPendingAuthorizationStore(),
    tokenClient: tokenClient,
    session: session,
  );

  stdout.writeln('Opening your browser. Complete login to continue.');
  try {
    final tokens = await coordinator.authorize();
    stdout.writeln('Credentials saved to ${tokenStore.path}');
    final user = await _currentUser(StaticTokenProvider(tokens), profile);
    stdout.writeln('account=${user.username} id=${user.id}');
    return 0;
  } finally {
    await callbackSource.close();
  }
}

Future<int> _whoami(ArgResults arguments) async {
  final profile = _profile(arguments['proxy'] as String?);
  final tokens = await FileTokenStore().read();
  if (tokens == null) {
    stderr.writeln('Not logged in. Run `dakit login` first.');
    return 64;
  }
  final user = await _currentUser(StaticTokenProvider(tokens), profile);
  stdout.writeln('username=${user.username} id=${user.id}');
  return 0;
}

Future<int> _download(ArgResults arguments) async {
  final uuid = arguments.rest.firstOrNull;
  if (uuid == null || uuid.trim().isEmpty) {
    stderr.writeln('Provide an artwork UUID.');
    return 64;
  }
  final tokens = await FileTokenStore().read();
  if (tokens == null) {
    stderr.writeln('Not logged in. Run `dakit login` first.');
    return 64;
  }

  final profile = _profile(arguments['proxy'] as String?);
  final provider = StaticTokenProvider(tokens);
  final transport = OfficialApiClient(
    session: provider,
    networkProfile: profile,
  );
  final mediaRepository = OfficialMediaRepository(transport);
  final asset = await mediaRepository.originalFile(uuid.trim());
  if (!asset.canTransfer) {
    stderr.writeln('Not downloadable: availability=${asset.availability.name}');
    return 1;
  }

  final outputDirectory = Directory(arguments['output'] as String);
  await outputDirectory.create(recursive: true);
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
    final filename = _safeFilename(
      asset.filename ?? asset.uri!.pathSegments.lastOrNull ?? 'original.bin',
    );
    final file = File(
      '${outputDirectory.path}${Platform.pathSeparator}$filename',
    );
    await file.writeAsBytes(bytes, flush: true);
    final digest = sha256.convert(bytes).toString();
    stdout.writeln(
      'saved=${file.path} bytes=${bytes.length} sha256=$digest '
      'mime=${asset.mimeType ?? response.headers.value('content-type')}',
    );
    return 0;
  } finally {
    dio.close(force: true);
  }
}

Future<int> _status(ArgResults arguments) async {
  final profile = _profile(arguments['proxy'] as String?);
  final report = await ConnectivityProbe(
    target: Uri.https('www.deviantart.com', '/api/v1/oauth2/placebo'),
    profile: profile,
  ).run();

  stdout.writeln('profile=${profile.mode.name}');
  for (final stage in report.stages) {
    stdout.writeln(
      '${stage.stage.name}=${stage.succeeded ? 'ok' : stage.code} '
      '${stage.elapsed.inMilliseconds}ms',
    );
  }
  return report.reachable ? 0 : 1;
}

NetworkProfile _profile(String? proxy) {
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

Future<UserProfile> _currentUser(
  AuthTokenProvider session,
  NetworkProfile profile,
) async {
  final transport = OfficialApiClient(
    session: session,
    networkProfile: profile,
  );
  return OfficialAccountRepository(transport).currentUser();
}

String _safeFilename(String value) {
  final leaf = value.replaceAll('\\', '/').split('/').last;
  final safe = leaf.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_').trim();
  return safe.isEmpty || safe == '.' || safe == '..' ? 'original.bin' : safe;
}

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

final class MemoryPendingAuthorizationStore
    implements PendingAuthorizationStore {
  PendingAuthorization? _pending;

  @override
  Future<PendingAuthorization?> read() async => _pending;

  @override
  Future<void> write(PendingAuthorization pending) async {
    _pending = pending;
  }

  @override
  Future<void> clear() async {
    _pending = null;
  }
}

final class PlatformUriLauncher implements ExternalUriLauncher {
  const PlatformUriLauncher();

  @override
  Future<void> launch(Uri uri) async {
    if (Platform.isMacOS) {
      await Process.run('open', <String>[uri.toString()]);
      return;
    }
    if (Platform.isLinux) {
      await Process.run('xdg-open', <String>[uri.toString()]);
      return;
    }
    if (Platform.isWindows) {
      await Process.run('cmd', <String>[
        '/c',
        'start',
        uri.toString(),
      ], runInShell: true);
      return;
    }
    throw const DAKitException(
      kind: DAKitFailureKind.authentication,
      code: 'oauth.browser.unsupported_platform',
      message: 'This CLI does not know how to open a browser here.',
    );
  }
}

final class LoopbackCallbackSource implements CallbackUriSource {
  final int port;
  final String path;
  HttpServer? _server;
  late final StreamController<Uri> _controller;

  LoopbackCallbackSource({required this.port, required this.path}) {
    _controller = StreamController<Uri>(onCancel: _handleCancel);
  }

  @override
  Stream<Uri> get uris => _controller.stream;

  void _handleCancel() {
    final server = _server;
    _server = null;
    server?.close(force: true);
  }

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server!.listen(_handle);
  }

  Future<void> close() async {
    final server = _server;
    _server = null;
    if (server != null) await server.close(force: true);
    if (!_controller.isClosed) await _controller.close();
  }

  Future<void> _handle(HttpRequest request) async {
    final requestUri = request.uri;
    if (requestUri.path != path) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final callbackUri = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: port,
      path: path,
      queryParameters: requestUri.queryParameters.isEmpty
          ? null
          : requestUri.queryParameters,
    );
    if (!_controller.isClosed) _controller.add(callbackUri);
    request.response.headers.contentType = ContentType.html;
    request.response.write(
      '<!doctype html><html><body>'
      '<h1>DAKit login complete</h1>'
      '<p>You can close this window.</p>'
      '</body></html>',
    );
    await request.response.close();
  }
}
