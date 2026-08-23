import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dakit_api/dakit_api.dart';
import 'package:dakit_core/dakit_core.dart';

final class PlatformUriLauncher implements ExternalUriLauncher {
  const PlatformUriLauncher();

  @override
  Future<void> launch(Uri uri) async {
    late final ProcessResult result;
    if (Platform.isMacOS) {
      result = await Process.run('open', <String>[uri.toString()]);
    } else if (Platform.isLinux) {
      result = await Process.run('xdg-open', <String>[uri.toString()]);
    } else if (Platform.isWindows) {
      result = await Process.run('rundll32', <String>[
        'url.dll,FileProtocolHandler',
        uri.toString(),
      ]);
    } else {
      throw const DAKitException(
        kind: DAKitFailureKind.authentication,
        code: 'oauth.browser.unsupported_platform',
        message: 'This CLI does not know how to open a browser here.',
      );
    }
    if (result.exitCode != 0) {
      throw DAKitException(
        kind: DAKitFailureKind.authentication,
        code: 'oauth.browser.launch_failed',
        message: 'The system browser could not be opened.',
        details: <String, Object?>{'exit_code': result.exitCode},
      );
    }
  }
}

final class PrintingUriLauncher implements ExternalUriLauncher {
  const PrintingUriLauncher();

  @override
  Future<void> launch(Uri uri) async {
    stdout.writeln('Open this URL in a browser:\n$uri');
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
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    } on SocketException catch (error) {
      throw DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'oauth.callback.bind_failed',
        message:
            'Cannot listen on 127.0.0.1:$port. Choose another --port or use --manual.',
        cause: error,
      );
    }
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

final class StdinCallbackSource implements CallbackUriSource {
  const StdinCallbackSource();

  @override
  Stream<Uri> get uris => _readCallbackUrls();

  Stream<Uri> _readCallbackUrls() async* {
    stdout.writeln(
      'After authorizing, copy the full redirect URL from your browser '
      'address bar and paste it here, then press Enter.',
    );
    final lines = stdin.transform(utf8.decoder).transform(const LineSplitter());
    await for (final line in lines) {
      final uri = Uri.tryParse(line.trim());
      if (uri != null && uri.hasScheme) {
        yield uri;
        return;
      }
      stderr.writeln('Paste the full URL, including code and state.');
    }
  }
}
