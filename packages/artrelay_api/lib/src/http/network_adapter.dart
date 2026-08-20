import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'network_profile.dart';

/// Creates a Dio client with an explicit native routing policy.
///
/// Certificate validation remains Dart's secure default. There is
/// intentionally no `badCertificateCallback` escape hatch in this API.
Dio createNetworkDio({required NetworkProfile profile, BaseOptions? options}) {
  final dio = Dio(options);
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () => createProfiledHttpClient(profile),
  );
  return dio;
}

HttpClient createProfiledHttpClient(NetworkProfile profile) {
  final client = HttpClient();
  switch (profile.mode) {
    case NetworkProxyMode.environment:
      final environment = profile.environment;
      client.findProxy = environment == null
          ? HttpClient.findProxyFromEnvironment
          : (uri) => HttpClient.findProxyFromEnvironment(
              uri,
              environment: environment,
            );
    case NetworkProxyMode.direct:
      client.findProxy = (_) => 'DIRECT';
    case NetworkProxyMode.httpProxy:
      final proxy = profile.proxy!;
      client.findProxy = (uri) => profile.bypasses(uri)
          ? 'DIRECT'
          : 'PROXY ${proxy.host}:${proxy.port}';
      if (proxy.credentials case final credentials?) {
        client.authenticateProxy = (host, port, scheme, realm) async {
          if (host != proxy.host || port != proxy.port) return false;
          client.addProxyCredentials(
            host,
            port,
            realm ?? '',
            HttpClientBasicCredentials(
              credentials.username,
              credentials.password,
            ),
          );
          return true;
        };
      }
  }
  return client;
}
