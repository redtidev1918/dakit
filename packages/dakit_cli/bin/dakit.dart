import 'dart:io';

import 'package:dakit_cli/src/cli.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runCli(arguments);
}
