import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';

import '../client_controller.dart';
import '../app_strings.dart';

final class TransfersOverview extends StatelessWidget {
  const TransfersOverview({required this.controller, super.key});

  final ExampleClientController controller;

  @override
  Widget build(BuildContext context) {
    final records = controller.transfers.values.toList(growable: false)
      ..sort((left, right) => right.id.compareTo(left.id));
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    return Card(
      child: ExpansionTile(
        initiallyExpanded: controller.transferFailure != null,
        title: Text('${strings.backgroundTransfers} (${records.length})'),
        subtitle: Text(strings.transferPersistence),
        children: <Widget>[
          if (controller.transferFailure case final failure?)
            ListTile(
              leading: Icon(
                Icons.error_outline,
                color: theme.colorScheme.error,
              ),
              title: Text(failure.code),
              subtitle: Text(strings.failureMessage(failure)),
            ),
          for (final snapshot in records.take(10))
            ListTile(
              dense: true,
              leading: Icon(
                snapshot.state == TransferState.completed
                    ? Icons.check_circle_outline
                    : snapshot.state == TransferState.failed
                    ? Icons.error_outline
                    : Icons.downloading,
              ),
              title: Text(snapshot.filename ?? snapshot.id),
              subtitle: Text(
                '${snapshot.state.name} · '
                '${(snapshot.progress * 100).clamp(0, 100).toStringAsFixed(1)}%',
              ),
            ),
        ],
      ),
    );
  }
}
