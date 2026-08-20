import 'dart:async';
import 'dart:io';

import 'package:dakit_core/dakit_core.dart';

import 'network_adapter.dart';
import 'network_profile.dart';

final class NetworkProbeRoute {
  const NetworkProbeRoute({
    required this.host,
    required this.port,
    required this.usesProxy,
  });

  final String host;
  final int port;
  final bool usesProxy;
}

final class ConnectivityStageResult {
  const ConnectivityStageResult({
    required this.stage,
    required this.succeeded,
    required this.code,
    required this.message,
    required this.elapsed,
    this.attributes = const <String, Object?>{},
  });

  final DiagnosticStage stage;
  final bool succeeded;
  final String code;
  final String message;
  final Duration elapsed;
  final Map<String, Object?> attributes;
}

final class ConnectivityReport {
  ConnectivityReport({
    required this.target,
    required List<ConnectivityStageResult> stages,
  }) : stages = List<ConnectivityStageResult>.unmodifiable(stages);

  final Uri target;
  final List<ConnectivityStageResult> stages;

  bool get reachable =>
      stages.length == 4 && stages.every((stage) => stage.succeeded);

  ConnectivityStageResult? get failure =>
      stages.where((stage) => !stage.succeeded).firstOrNull;
}

abstract interface class ConnectivityProbeBackend {
  Future<NetworkProbeRoute> resolveRoute(Uri target, NetworkProfile profile);

  Future<int> lookup(String host, Duration timeout);

  Future<void> connect(NetworkProbeRoute route, Duration timeout);

  Future<void> negotiateTls(
    Uri target,
    NetworkProfile profile,
    Duration timeout,
  );

  Future<int> request(Uri target, NetworkProfile profile, Duration timeout);
}

/// Runs a deterministic DNS -> TCP -> TLS -> HTTP diagnostic sequence.
///
/// The probe stops at the first failed stage, returns a report instead of
/// throwing, and emits the same redacted events used by the rest of the SDK.
final class ConnectivityProbe {
  ConnectivityProbe({
    required this.target,
    NetworkProfile? profile,
    ConnectivityProbeBackend? backend,
    this.diagnostics = const NoopDiagnosticSink(),
    this.stageTimeout = const Duration(seconds: 10),
    DateTime Function()? now,
  }) : profile = profile ?? NetworkProfile.environment(),
       _backend = backend ?? const NativeConnectivityProbeBackend(),
       _now = now ?? DateTime.now {
    if (!target.isScheme('https') || target.host.isEmpty) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'network.probe.target_invalid',
        message: 'Connectivity probes require an HTTPS target.',
      );
    }
    if (stageTimeout <= Duration.zero) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'network.probe.timeout_invalid',
        message: 'Connectivity probe timeout must be positive.',
      );
    }
  }

  final Uri target;
  final NetworkProfile profile;
  final ConnectivityProbeBackend _backend;
  final DiagnosticSink diagnostics;
  final Duration stageTimeout;
  final DateTime Function() _now;

  Future<ConnectivityReport> run() async {
    final results = <ConnectivityStageResult>[];
    NetworkProbeRoute? route;

    route = await _stage(
      results,
      stage: DiagnosticStage.dns,
      successCode: 'network.dns.ok',
      failureCode: 'network.dns.failed',
      successMessage: 'DNS resolution completed.',
      failureMessage: 'DNS resolution failed.',
      operation: () async {
        final resolved = await _backend.resolveRoute(target, profile);
        final addresses = await _backend.lookup(resolved.host, stageTimeout);
        if (addresses < 1) {
          throw const SocketException('DNS returned no addresses.');
        }
        return resolved;
      },
      attributes: (value) => <String, Object?>{
        'route': value.usesProxy ? 'http_proxy' : 'direct',
        'resolved_host': value.host,
      },
    );
    if (route == null) {
      return ConnectivityReport(target: target, stages: results);
    }
    final resolvedRoute = route;

    final connected = await _stage<bool>(
      results,
      stage: DiagnosticStage.connect,
      successCode: 'network.connect.ok',
      failureCode: 'network.connect.failed',
      successMessage: 'TCP connection completed.',
      failureMessage: 'TCP connection failed.',
      operation: () async {
        await _backend.connect(resolvedRoute, stageTimeout);
        return true;
      },
      attributes: (_) => <String, Object?>{
        'route': resolvedRoute.usesProxy ? 'http_proxy' : 'direct',
        'port': resolvedRoute.port,
      },
    );
    if (connected != true) {
      return ConnectivityReport(target: target, stages: results);
    }

    final tls = await _stage<bool>(
      results,
      stage: DiagnosticStage.tls,
      successCode: 'network.tls.ok',
      failureCode: 'network.tls.failed',
      successMessage: 'TLS certificate validation completed.',
      failureMessage: 'TLS negotiation or certificate validation failed.',
      operation: () async {
        await _backend.negotiateTls(target, profile, stageTimeout);
        return true;
      },
      attributes: (_) => const <String, Object?>{
        'certificate_validation': true,
      },
    );
    if (tls != true) {
      return ConnectivityReport(target: target, stages: results);
    }

    await _stage<int>(
      results,
      stage: DiagnosticStage.http,
      successCode: 'network.http.ok',
      failureCode: 'network.http.failed',
      successMessage: 'The HTTPS service returned an HTTP response.',
      failureMessage: 'The HTTPS request failed before receiving a response.',
      operation: () => _backend.request(target, profile, stageTimeout),
      attributes: (status) => <String, Object?>{'status': status},
    );
    return ConnectivityReport(target: target, stages: results);
  }

  Future<T?> _stage<T>(
    List<ConnectivityStageResult> results, {
    required DiagnosticStage stage,
    required String successCode,
    required String failureCode,
    required String successMessage,
    required String failureMessage,
    required Future<T> Function() operation,
    required Map<String, Object?> Function(T value) attributes,
  }) async {
    final started = _now();
    try {
      final value = await operation().timeout(stageTimeout);
      final elapsed = _now().difference(started);
      final values = attributes(value);
      final result = ConnectivityStageResult(
        stage: stage,
        succeeded: true,
        code: successCode,
        message: successMessage,
        elapsed: elapsed,
        attributes: values,
      );
      results.add(result);
      diagnostics.add(
        DiagnosticEvent(
          stage: stage,
          level: DiagnosticLevel.info,
          code: successCode,
          message: successMessage,
          elapsed: elapsed,
          attributes: values,
        ),
      );
      return value;
    } on Object catch (error) {
      final elapsed = _now().difference(started);
      final code = error is TimeoutException
          ? '$failureCode.timeout'
          : failureCode;
      final values = <String, Object?>{
        'failure_type': error.runtimeType.toString(),
        if (error case final DAKitException failure)
          'failure_code': failure.code,
      };
      results.add(
        ConnectivityStageResult(
          stage: stage,
          succeeded: false,
          code: code,
          message: failureMessage,
          elapsed: elapsed,
          attributes: values,
        ),
      );
      diagnostics.add(
        DiagnosticEvent(
          stage: stage,
          level: DiagnosticLevel.error,
          code: code,
          message: failureMessage,
          elapsed: elapsed,
          attributes: values,
        ),
      );
      return null;
    }
  }
}

final class NativeConnectivityProbeBackend implements ConnectivityProbeBackend {
  const NativeConnectivityProbeBackend();

  @override
  Future<NetworkProbeRoute> resolveRoute(
    Uri target,
    NetworkProfile profile,
  ) async {
    final directive = switch (profile.mode) {
      NetworkProxyMode.environment => HttpClient.findProxyFromEnvironment(
        target,
        environment: profile.environment,
      ),
      NetworkProxyMode.direct => 'DIRECT',
      NetworkProxyMode.httpProxy =>
        profile.bypasses(target)
            ? 'DIRECT'
            : 'PROXY ${profile.proxy!.host}:${profile.proxy!.port}',
    };
    for (final candidate in directive.split(';')) {
      final value = candidate.trim();
      if (value.toUpperCase() == 'DIRECT') {
        return NetworkProbeRoute(
          host: target.host,
          port: target.hasPort ? target.port : 443,
          usesProxy: false,
        );
      }
      if (value.toUpperCase().startsWith('PROXY ')) {
        final authority = value.substring(6).trim();
        final uri = Uri.tryParse('http://$authority');
        if (uri != null && uri.host.isNotEmpty && uri.hasPort) {
          return NetworkProbeRoute(
            host: uri.host,
            port: uri.port,
            usesProxy: true,
          );
        }
      }
    }
    throw const DAKitException(
      kind: DAKitFailureKind.configuration,
      code: 'network.proxy.directive_unsupported',
      message: 'The configured proxy directive is not supported.',
    );
  }

  @override
  Future<int> lookup(String host, Duration timeout) async =>
      (await InternetAddress.lookup(host).timeout(timeout)).length;

  @override
  Future<void> connect(NetworkProbeRoute route, Duration timeout) async {
    final socket = await Socket.connect(
      route.host,
      route.port,
      timeout: timeout,
    );
    socket.destroy();
  }

  @override
  Future<void> negotiateTls(
    Uri target,
    NetworkProfile profile,
    Duration timeout,
  ) async {
    final client = createProfiledHttpClient(profile)
      ..connectionTimeout = timeout;
    try {
      final request = await client.openUrl('HEAD', target).timeout(timeout);
      request.abort();
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<int> request(
    Uri target,
    NetworkProfile profile,
    Duration timeout,
  ) async {
    final client = createProfiledHttpClient(profile)
      ..connectionTimeout = timeout;
    try {
      final request = await client.headUrl(target).timeout(timeout);
      request
        ..followRedirects = false
        ..headers.set(HttpHeaders.userAgentHeader, 'DAKit-Diagnostics/0.1');
      final response = await request.close().timeout(timeout);
      final status = response.statusCode;
      await response.drain<void>().timeout(timeout);
      return status;
    } finally {
      client.close(force: true);
    }
  }
}
