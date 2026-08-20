import 'package:flutter/material.dart';

import 'client_controller.dart';
import 'widgets/artwork_browser.dart';
import 'widgets/connectivity_card.dart';
import 'widgets/diagnostics_panel.dart';
import 'widgets/status_card.dart';
import 'widgets/transfers_overview.dart';

final class ArtRelayExampleApp extends StatefulWidget {
  const ArtRelayExampleApp({required this.controller, super.key});

  final ExampleClientController controller;

  @override
  State<ArtRelayExampleApp> createState() => _ArtRelayExampleAppState();
}

final class _ArtRelayExampleAppState extends State<ArtRelayExampleApp> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

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
    home: ClientHome(controller: widget.controller),
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
              ClientStatusCard(controller: controller),
              const SizedBox(height: 16),
              ConnectivityCard(controller: controller),
              if (controller.transfers.isNotEmpty ||
                  controller.transferFailure != null) ...<Widget>[
                const SizedBox(height: 16),
                TransfersOverview(controller: controller),
              ],
              const SizedBox(height: 16),
              if (controller.phase == ClientPhase.ready)
                ArtworkBrowser(controller: controller),
              const SizedBox(height: 16),
              DiagnosticsPanel(events: controller.diagnostics.events),
            ],
          ),
        ),
      ),
    ),
  );
}
