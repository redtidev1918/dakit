import 'dart:async';

import 'package:dakit_api/dakit_api.dart';
import 'package:dakit_core/dakit_core.dart';
import 'package:test/test.dart';

void main() {
  final target = Uri.parse('https://www.deviantart.com/oauth2/authorize');

  group('network profiles', () {
    test('explicit proxy supports deterministic hostname bypasses', () {
      final profile = NetworkProfile.httpProxy(
        proxyServer: HttpProxyServer(host: '127.0.0.1', port: 7892),
        bypassHosts: const <String>{'localhost', '.example.test'},
      );

      expect(profile.bypasses(Uri.parse('https://api.example.test')), isTrue);
      expect(profile.bypasses(Uri.parse('https://example.test')), isTrue);
      expect(profile.bypasses(Uri.parse('https://example.com')), isFalse);
      expect(profile.toString(), isNot(contains('127.0.0.1')));
    });

    test('credentials never reveal their values in toString', () {
      final credentials = ProxyCredentials(
        username: 'private-user',
        password: 'private-password',
      );

      expect(credentials.toString(), isNot(contains('private-user')));
      expect(credentials.toString(), isNot(contains('private-password')));
    });

    test('rejects malformed explicit proxy settings', () {
      expect(
        () => HttpProxyServer(host: 'http://localhost', port: 7892),
        throwsA(
          isA<DAKitException>().having(
            (error) => error.code,
            'code',
            'network.proxy.host_invalid',
          ),
        ),
      );
      expect(
        () => HttpProxyServer(host: 'localhost', port: 0),
        throwsA(
          isA<DAKitException>().having(
            (error) => error.code,
            'code',
            'network.proxy.port_invalid',
          ),
        ),
      );
    });

    test('environment route resolves the primary HTTPS proxy', () async {
      final route = await const NativeConnectivityProbeBackend().resolveRoute(
        target,
        NetworkProfile.environment(
          environment: const <String, String>{'https_proxy': '127.0.0.1:7892'},
        ),
      );

      expect(route.usesProxy, isTrue);
      expect(route.host, '127.0.0.1');
      expect(route.port, 7892);
    });
  });

  group('connectivity probe', () {
    test('reports DNS, TCP, TLS, and HTTP success in order', () async {
      final diagnostics = RecordingDiagnostics();
      final report = await ConnectivityProbe(
        target: target,
        profile: NetworkProfile.direct(),
        backend: FakeProbeBackend(),
        diagnostics: diagnostics,
      ).run();

      expect(report.reachable, isTrue);
      expect(report.stages.map((result) => result.stage), <DiagnosticStage>[
        DiagnosticStage.dns,
        DiagnosticStage.connect,
        DiagnosticStage.tls,
        DiagnosticStage.http,
      ]);
      expect(report.stages.last.attributes['status'], 403);
      expect(diagnostics.events, hasLength(4));
    });

    for (final stage in <DiagnosticStage>[
      DiagnosticStage.dns,
      DiagnosticStage.connect,
      DiagnosticStage.tls,
      DiagnosticStage.http,
    ]) {
      test('stops at and identifies a ${stage.name} failure', () async {
        final report = await ConnectivityProbe(
          target: target,
          profile: NetworkProfile.direct(),
          backend: FakeProbeBackend(failureStage: stage),
        ).run();

        expect(report.reachable, isFalse);
        expect(report.failure?.stage, stage);
        expect(report.stages.last.succeeded, isFalse);
        expect(report.stages.length, stage.index + 1);
      });
    }

    test('labels a timed out stage without leaking exception text', () async {
      final report = await ConnectivityProbe(
        target: target,
        backend: FakeProbeBackend(
          failureStage: DiagnosticStage.connect,
          timeoutFailure: true,
        ),
      ).run();

      expect(report.failure?.code, 'network.connect.failed.timeout');
      expect(report.failure?.attributes, isNot(contains('message')));
    });

    test('retains an actionable nested configuration code', () async {
      final report = await ConnectivityProbe(
        target: target,
        backend: ConfigurationFailureBackend(),
      ).run();

      expect(
        report.failure?.attributes['failure_code'],
        'network.proxy.directive_unsupported',
      );
    });
  });
}

class FakeProbeBackend implements ConnectivityProbeBackend {
  FakeProbeBackend({this.failureStage, this.timeoutFailure = false});

  final DiagnosticStage? failureStage;
  final bool timeoutFailure;

  Never _fail(DiagnosticStage stage) {
    if (timeoutFailure) throw TimeoutException('${stage.name} timed out');
    throw StateError('${stage.name} failed');
  }

  @override
  Future<NetworkProbeRoute> resolveRoute(
    Uri target,
    NetworkProfile profile,
  ) async {
    if (failureStage == DiagnosticStage.dns) _fail(DiagnosticStage.dns);
    return NetworkProbeRoute(host: target.host, port: 443, usesProxy: false);
  }

  @override
  Future<int> lookup(String host, Duration timeout) async => 2;

  @override
  Future<void> connect(NetworkProbeRoute route, Duration timeout) async {
    if (failureStage == DiagnosticStage.connect) {
      _fail(DiagnosticStage.connect);
    }
  }

  @override
  Future<void> negotiateTls(
    Uri target,
    NetworkProfile profile,
    Duration timeout,
  ) async {
    if (failureStage == DiagnosticStage.tls) _fail(DiagnosticStage.tls);
  }

  @override
  Future<int> request(
    Uri target,
    NetworkProfile profile,
    Duration timeout,
  ) async {
    if (failureStage == DiagnosticStage.http) _fail(DiagnosticStage.http);
    return 403;
  }
}

final class RecordingDiagnostics implements DiagnosticSink {
  final List<DiagnosticEvent> events = <DiagnosticEvent>[];

  @override
  void add(DiagnosticEvent event) => events.add(event);
}

final class ConfigurationFailureBackend extends FakeProbeBackend {
  @override
  Future<NetworkProbeRoute> resolveRoute(Uri target, NetworkProfile profile) {
    throw const DAKitException(
      kind: DAKitFailureKind.configuration,
      code: 'network.proxy.directive_unsupported',
      message: 'Unsupported proxy.',
    );
  }
}
