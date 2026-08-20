import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_strings.dart';
import 'client_controller.dart';
import 'widgets/artwork_browser.dart';
import 'widgets/connectivity_card.dart';
import 'widgets/diagnostics_panel.dart';
import 'widgets/status_card.dart';
import 'widgets/transfers_overview.dart';

final class DAKitExampleApp extends StatefulWidget {
  const DAKitExampleApp({required this.controller, this.locale, super.key});

  final ExampleClientController controller;
  final Locale? locale;

  @override
  State<DAKitExampleApp> createState() => _DAKitExampleAppState();
}

final class _DAKitExampleAppState extends State<DAKitExampleApp> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: (context) => AppStrings.of(context).applicationTitle,
    locale: widget.locale,
    supportedLocales: const <Locale>[Locale('en'), Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
        title: Text(AppStrings.of(context).clientTitle),
        actions: <Widget>[
          if (controller.phase == ClientPhase.ready)
            IconButton(
              tooltip: AppStrings.of(context).refreshAccount,
              onPressed: controller.busy ? null : controller.refresh,
              icon: const Icon(Icons.refresh),
            ),
          if (controller.phase == ClientPhase.ready)
            IconButton(
              tooltip: AppStrings.of(context).signOut,
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
