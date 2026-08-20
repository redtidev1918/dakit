import 'dart:io';

import 'package:artrelay_api/artrelay_api.dart';

Future<void> main(List<String> arguments) async {
  final profile = switch (arguments.firstOrNull) {
    null || 'environment' => NetworkProfile.environment(),
    'direct' => NetworkProfile.direct(),
    'http' when arguments.length == 3 => NetworkProfile.httpProxy(
      proxyServer: HttpProxyServer(
        host: arguments[1],
        port: int.parse(arguments[2]),
      ),
    ),
    _ => throw ArgumentError(
      'Usage: dart run example/connectivity.dart '
      '[environment|direct|http HOST PORT]',
    ),
  };
  final report = await ConnectivityProbe(
    target: Uri.https('www.deviantart.com', '/'),
    profile: profile,
  ).run();

  stdout.writeln('profile=${profile.mode.name}');
  for (final stage in report.stages) {
    stdout.writeln(
      '${stage.stage.name}=${stage.succeeded ? 'ok' : stage.code} '
      '${stage.elapsed.inMilliseconds}ms',
    );
  }
  if (!report.reachable) exitCode = 1;
}
