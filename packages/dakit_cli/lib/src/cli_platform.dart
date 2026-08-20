import 'dart:async';
import 'dart:io';

import 'package:dakit_api/dakit_api.dart';
import 'package:dakit_core/dakit_core.dart';

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
