import 'package:artrelay_flutter/artrelay_flutter.dart';
import 'package:flutter/material.dart';

import '../client_controller.dart';

final class ClientStatusCard extends StatelessWidget {
  const ClientStatusCard({required this.controller, super.key});

  final ExampleClientController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  child: Text(_title, style: theme.textTheme.titleLarge),
                ),
                if (controller.busy)
                  const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(_message),
            if (controller.phase == ClientPhase.configurationRequired &&
                controller.failure == null) ...<Widget>[
              const SizedBox(height: 12),
              const _CommandBox(
                'flutter run -d macos '
                '--dart-define=ARTRELAY_CLIENT_ID=YOUR_PUBLIC_CLIENT_ID',
              ),
            ],
            if (controller.phase == ClientPhase.signedOut) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('login-button'),
                onPressed: controller.login,
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Authorize in system browser'),
              ),
            ],
            if (controller.user case final user?) ...<Widget>[
              const SizedBox(height: 16),
              Text('@${user.username}', style: theme.textTheme.headlineSmall),
              Text('User ID: ${user.id}'),
            ],
            if (controller.failure case final failure?) ...<Widget>[
              const SizedBox(height: 16),
              SelectableText(
                '${failure.code}\n${failure.message}',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 12),
              Text(_failureHint(failure)),
              if (controller.phase !=
                  ClientPhase.configurationRequired) ...<Widget>[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  children: <Widget>[
                    FilledButton.tonalIcon(
                      onPressed: controller.login,
                      icon: const Icon(Icons.login),
                      label: const Text('Start login again'),
                    ),
                    OutlinedButton.icon(
                      onPressed: controller.refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry API'),
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

  String get _title => switch (controller.phase) {
    ClientPhase.configurationRequired =>
      controller.failure == null
          ? 'Client ID is not configured'
          : 'Network configuration is invalid',
    ClientPhase.restoring => 'Restoring secure session',
    ClientPhase.signedOut => 'Ready to authorize',
    ClientPhase.authorizing => 'Waiting for browser callback',
    ClientPhase.loading => 'Loading account data',
    ClientPhase.ready => 'Connected',
    ClientPhase.failure => 'Operation failed',
  };

  String get _message => switch (controller.phase) {
    ClientPhase.configurationRequired =>
      controller.failure == null
          ? 'Pass the Public Client ID at build time. No client secret is used.'
          : 'Fix the proxy build defines and restart the example client.',
    ClientPhase.restoring =>
      'Checking secure storage and a possible cold-start callback.',
    ClientPhase.signedOut =>
      'Authorization opens the real system browser and returns through '
          'artrelay://oauth/callback.',
    ClientPhase.authorizing =>
      'Complete authorization in the browser. This screen will update '
          'automatically when the operating system delivers the callback.',
    ClientPhase.loading =>
      'The session is valid; requesting account and home data.',
    ClientPhase.ready => '${controller.artworks.length} home items loaded.',
    ClientPhase.failure =>
      'The error code and diagnostic timeline below identify the failed stage.',
  };

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

  static String _failureHint(
    ArtRelayException failure,
  ) => switch (failure.kind) {
    ArtRelayFailureKind.configuration =>
      'Check the client ID and exact redirect whitelist.',
    ArtRelayFailureKind.authentication || ArtRelayFailureKind.authorization => 'Check browser completion, callback delivery, state, and provider access.',
    ArtRelayFailureKind.network =>
      'Check DNS, TLS, proxy selection, and whether the service is reachable.',
    ArtRelayFailureKind.storage =>
      'Check Keychain, Keystore, or Windows credential storage access.',
    ArtRelayFailureKind.parsing =>
      'The upstream response no longer satisfies a required SDK contract.',
    _ => 'Use the diagnostic event codes below to locate the failing stage.',
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
