import 'package:artrelay_flutter/artrelay_flutter.dart';
import 'package:example_client/src/network_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults can use environment proxy discovery', () {
    expect(
      parseExampleNetworkProfile(mode: 'environment').mode,
      NetworkProxyMode.environment,
    );
  });

  test('parses a local HTTP proxy and bypass list', () {
    final profile = parseExampleNetworkProfile(
      mode: 'http',
      host: '127.0.0.1',
      port: '7892',
      bypass: 'localhost, .example.test',
    );

    expect(profile.proxy?.host, '127.0.0.1');
    expect(profile.proxy?.port, 7892);
    expect(profile.bypasses(Uri.parse('https://api.example.test')), isTrue);
  });

  test('invalid mode is an actionable configuration failure', () {
    expect(
      () => parseExampleNetworkProfile(mode: 'automatic'),
      throwsA(
        isA<ArtRelayException>().having(
          (error) => error.code,
          'code',
          'example.proxy.mode_invalid',
        ),
      ),
    );
  });
}
