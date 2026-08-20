import 'package:artrelay_flutter/artrelay_flutter.dart';
import 'package:flutter/material.dart' hide DiagnosticLevel;

import 'client_controller.dart';

final class ArtRelayExampleApp extends StatelessWidget {
  const ArtRelayExampleApp({required this.controller, super.key});

  final ExampleClientController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ArtRelay Example',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff4263eb),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    ),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff91a7ff),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    home: ClientHome(controller: controller),
  );
}

final class ClientHome extends StatelessWidget {
  const ClientHome({required this.controller, super.key});

  final ExampleClientController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge(<Listenable>[
      controller,
      controller.diagnostics,
    ]),
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('ArtRelay integration client'),
        actions: <Widget>[
          if (controller.phase == ClientPhase.ready)
            IconButton(
              tooltip: 'Refresh account and home',
              onPressed: controller.busy ? null : controller.refresh,
              icon: const Icon(Icons.refresh),
            ),
          if (controller.phase == ClientPhase.ready)
            IconButton(
              tooltip: 'Revoke session and sign out',
              onPressed: controller.busy ? null : controller.signOut,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: SafeArea(
        child: SelectionArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              _StatusCard(controller: controller),
              const SizedBox(height: 16),
              _ConnectivityCard(controller: controller),
              const SizedBox(height: 16),
              if (controller.phase == ClientPhase.ready)
                _ArtworkList(artworks: controller.artworks),
              const SizedBox(height: 16),
              _Diagnostics(events: controller.diagnostics.events),
            ],
          ),
        ),
      ),
    ),
  );
}

final class _ConnectivityCard extends StatelessWidget {
  const _ConnectivityCard({required this.controller});

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
                        '${stage.stage.name} '
                        '${stage.elapsed.inMilliseconds} ms',
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

final class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.controller});

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
              const SizedBox(height: 16),
              if (controller.phase != ClientPhase.configurationRequired)
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

final class _ArtworkList extends StatelessWidget {
  const _ArtworkList({required this.artworks});

  final List<Artwork> artworks;

  @override
  Widget build(BuildContext context) {
    if (artworks.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('The home endpoint returned no artwork.'),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Home', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final artwork in artworks)
          Card(
            child: ListTile(
              title: Text(artwork.title),
              subtitle: Text('@${artwork.author.username} · ${artwork.id}'),
              trailing: Icon(
                artwork.isDownloadable ? Icons.download_done : Icons.visibility,
              ),
            ),
          ),
      ],
    );
  }
}

final class _Diagnostics extends StatelessWidget {
  const _Diagnostics({required this.events});

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
