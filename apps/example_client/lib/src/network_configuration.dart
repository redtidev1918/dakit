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

ProxyConfiguration? readExampleTransferProxy() => parseExampleTransferProxy(
  host: const String.fromEnvironment('ARTRELAY_TRANSFER_PROXY_HOST'),
  port: const String.fromEnvironment('ARTRELAY_TRANSFER_PROXY_PORT'),
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

ProxyConfiguration? parseExampleTransferProxy({
  String host = '',
  String port = '',
}) {
  final normalizedHost = host.trim();
  final normalizedPort = port.trim();
  if (normalizedHost.isEmpty && normalizedPort.isEmpty) return null;
  if (normalizedHost.isEmpty || normalizedPort.isEmpty) {
    throw const ArtRelayException(
      kind: ArtRelayFailureKind.configuration,
      code: 'example.transfer_proxy.incomplete',
      message: 'Transfer proxy host and port must be provided together.',
    );
  }
  final parsedPort = int.tryParse(normalizedPort);
  if (parsedPort == null || parsedPort < 1 || parsedPort > 65535) {
    throw const ArtRelayException(
      kind: ArtRelayFailureKind.configuration,
      code: 'example.transfer_proxy.port_invalid',
      message: 'Transfer proxy port must be between 1 and 65535.',
    );
  }
  final validated = HttpProxyServer(host: normalizedHost, port: parsedPort);
  return ProxyConfiguration(host: validated.host, port: validated.port);
}
