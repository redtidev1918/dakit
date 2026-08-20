import 'package:artrelay_flutter/artrelay_flutter.dart';

NetworkProfile readExampleNetworkProfile() => parseExampleNetworkProfile(
  mode: const String.fromEnvironment(
    'ARTRELAY_PROXY_MODE',
    defaultValue: 'environment',
  ),
  host: const String.fromEnvironment('ARTRELAY_PROXY_HOST'),
  port: const String.fromEnvironment('ARTRELAY_PROXY_PORT'),
  bypass: const String.fromEnvironment('ARTRELAY_PROXY_BYPASS'),
);

NetworkProfile parseExampleNetworkProfile({
  required String mode,
  String host = '',
  String port = '',
  String bypass = '',
}) => switch (mode.trim().toLowerCase()) {
  'environment' => NetworkProfile.environment(),
  'direct' => NetworkProfile.direct(),
  'http' => NetworkProfile.httpProxy(
    proxyServer: HttpProxyServer(host: host.trim(), port: _proxyPort(port)),
    bypassHosts: bypass
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet(),
  ),
  _ => throw const ArtRelayException(
    kind: ArtRelayFailureKind.configuration,
    code: 'example.proxy.mode_invalid',
    message: 'ARTRELAY_PROXY_MODE must be environment, direct, or http.',
  ),
};

int _proxyPort(String value) {
  final parsed = int.tryParse(value);
  if (parsed == null) {
    throw const ArtRelayException(
      kind: ArtRelayFailureKind.configuration,
      code: 'example.proxy.port_invalid',
      message: 'ARTRELAY_PROXY_PORT must be an integer.',
    );
  }
  return parsed;
}
