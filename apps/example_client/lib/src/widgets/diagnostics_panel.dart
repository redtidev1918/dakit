import 'package:artrelay_flutter/artrelay_flutter.dart';
import 'package:flutter/material.dart' hide DiagnosticLevel;

import '../app_strings.dart';

final class DiagnosticsPanel extends StatelessWidget {
  const DiagnosticsPanel({required this.events, super.key});

  final List<DiagnosticEvent> events;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Card(
      child: ExpansionTile(
        initiallyExpanded: events.isNotEmpty,
        title: Text('${strings.diagnostics} (${events.length})'),
        subtitle: Text(strings.diagnosticsPrivacy),
        children: <Widget>[
          if (events.isEmpty) ListTile(title: Text(strings.noDiagnostics)),
          for (final event in events.take(20))
            ListTile(
              dense: true,
              leading: Icon(_levelIcon(event.level)),
              title: Text(event.code),
              subtitle: Text(
                '${event.stage.name} · ${event.message}'
                '${event.elapsed == null ? '' : ' · ${event.elapsed!.inMilliseconds} ms'}'
                '${event.attributes.isEmpty ? '' : '\n${_attributes(event.attributes)}'}',
              ),
            ),
        ],
      ),
    );
  }

  static IconData _levelIcon(DiagnosticLevel level) => switch (level) {
    DiagnosticLevel.debug => Icons.bug_report_outlined,
    DiagnosticLevel.info => Icons.info_outline,
    DiagnosticLevel.warning => Icons.warning_amber,
    DiagnosticLevel.error => Icons.error_outline,
  };

  static String _attributes(Map<String, Object?> attributes) => attributes
      .entries
      .where((entry) => !_secretKey.hasMatch(entry.key))
      .map((entry) => '${entry.key}=${entry.value}')
      .join(' · ');

  static final RegExp _secretKey = RegExp(
    'token|secret|verifier|authorization|cookie',
    caseSensitive: false,
  );
}
