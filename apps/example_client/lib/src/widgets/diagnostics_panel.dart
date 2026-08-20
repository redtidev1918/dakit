import 'package:artrelay_flutter/artrelay_flutter.dart';
import 'package:flutter/material.dart' hide DiagnosticLevel;

final class DiagnosticsPanel extends StatelessWidget {
  const DiagnosticsPanel({required this.events, super.key});

  final List<DiagnosticEvent> events;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      initiallyExpanded: events.isNotEmpty,
      title: Text('Diagnostics (${events.length})'),
      subtitle: const Text(
        'Secrets and authorization codes are never displayed.',
      ),
      children: <Widget>[
        if (events.isEmpty)
          const ListTile(title: Text('No diagnostic events yet.')),
        for (final event in events.take(20))
          ListTile(
            dense: true,
            leading: Icon(_levelIcon(event.level)),
            title: Text(event.code),
            subtitle: Text(
              '${event.stage.name} · ${event.message}'
              '${event.elapsed == null ? '' : ' · ${event.elapsed!.inMilliseconds} ms'}',
            ),
          ),
      ],
    ),
  );

  static IconData _levelIcon(DiagnosticLevel level) => switch (level) {
    DiagnosticLevel.debug => Icons.bug_report_outlined,
    DiagnosticLevel.info => Icons.info_outline,
    DiagnosticLevel.warning => Icons.warning_amber,
    DiagnosticLevel.error => Icons.error_outline,
  };
}
