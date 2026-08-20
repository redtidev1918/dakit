import 'package:flutter/material.dart';

import '../client_controller.dart';
import '../app_strings.dart';

final class ClientStatusCard extends StatelessWidget {
  const ClientStatusCard({required this.controller, super.key});

  final ExampleClientController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(_icon, color: _color(theme.colorScheme)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    strings.phaseTitle(
                      controller.phase,
                      hasFailure: controller.failure != null,
                    ),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                if (controller.busy)
                  const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              strings.phaseMessage(
                controller.phase,
                hasFailure: controller.failure != null,
                artworkCount: controller.artworks.length,
              ),
            ),
            if (controller.phase == ClientPhase.configurationRequired &&
                controller.failure == null) ...<Widget>[
              const SizedBox(height: 12),
              const _CommandBox(
                'flutter run -d macos '
                '--dart-define=DAKIT_CLIENT_ID=YOUR_PUBLIC_CLIENT_ID',
              ),
            ],
            if (controller.phase == ClientPhase.signedOut) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('login-button'),
                onPressed: controller.login,
                icon: const Icon(Icons.open_in_browser),
                label: Text(strings.authorize),
              ),
            ],
            if (controller.user case final user?) ...<Widget>[
              const SizedBox(height: 16),
              Text('@${user.username}', style: theme.textTheme.headlineSmall),
              Text('${strings.userId}: ${user.id}'),
            ],
            if (controller.failure case final failure?) ...<Widget>[
              const SizedBox(height: 16),
              SelectableText(
                '${strings.errorCode}: ${failure.code}\n'
                '${strings.failureMessage(failure)}',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 12),
              Text(strings.failureHint(failure)),
              if (controller.phase !=
                  ClientPhase.configurationRequired) ...<Widget>[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  children: <Widget>[
                    FilledButton.tonalIcon(
                      onPressed: controller.login,
                      icon: const Icon(Icons.login),
                      label: Text(strings.loginAgain),
                    ),
                    OutlinedButton.icon(
                      onPressed: controller.refresh,
                      icon: const Icon(Icons.refresh),
                      label: Text(strings.retryApi),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  IconData get _icon => switch (controller.phase) {
    ClientPhase.configurationRequired => Icons.settings,
    ClientPhase.restoring || ClientPhase.loading => Icons.sync,
    ClientPhase.signedOut => Icons.lock_open,
    ClientPhase.authorizing => Icons.open_in_browser,
    ClientPhase.ready => Icons.check_circle,
    ClientPhase.failure => Icons.error,
  };

  Color _color(ColorScheme colors) => switch (controller.phase) {
    ClientPhase.ready => colors.primary,
    ClientPhase.failure => colors.error,
    _ => colors.secondary,
  };
}

final class _CommandBox extends StatelessWidget {
  const _CommandBox(this.command);

  final String command;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: SelectableText(command),
  );
}
