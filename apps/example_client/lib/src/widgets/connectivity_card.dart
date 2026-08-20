import 'package:flutter/material.dart';

import '../client_controller.dart';

final class ConnectivityCard extends StatelessWidget {
  const ConnectivityCard({required this.controller, super.key});

  final ExampleClientController controller;

  @override
  Widget build(BuildContext context) {
    final report = controller.connectivity;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  report == null
                      ? Icons.network_check
                      : report.reachable
                      ? Icons.cloud_done
                      : Icons.cloud_off,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Network path',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (controller.checkingConnectivity)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton.icon(
                    onPressed: controller.checkConnectivity,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Run check'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              report == null
                  ? 'Checking DNS, TCP, TLS, and HTTP independently.'
                  : report.reachable
                  ? 'All four stages reached the service.'
                  : 'Stopped at ${report.failure?.stage.name ?? 'unknown'}: '
                        '${report.failure?.code ?? 'unknown'}',
            ),
            if (report != null) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final stage in report.stages)
                    Chip(
                      avatar: Icon(
                        stage.succeeded ? Icons.check : Icons.close,
                        size: 16,
                      ),
                      label: Text(
                        '${stage.stage.name} ${stage.elapsed.inMilliseconds} ms',
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
