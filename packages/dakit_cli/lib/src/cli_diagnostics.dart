import 'dart:io';

import 'package:dakit_core/dakit_core.dart';

final class CliDiagnostics implements DiagnosticSink {
  const CliDiagnostics();

  @override
  void add(DiagnosticEvent event) {
    final elapsed = event.elapsed == null
        ? ''
        : ' (${event.elapsed!.inMilliseconds}ms)';
    final attributes = event.attributes.isEmpty ? '' : ' ${event.attributes}';
    stderr.writeln(
      '[${event.stage.name}] ${event.level.name} '
      '${event.code}$elapsed$attributes',
    );
  }
}
