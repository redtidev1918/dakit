import 'package:dakit_core/dakit_core.dart';

enum NetworkProxyMode { environment, direct, httpProxy }

/// Credentials held in memory for an authenticated HTTP proxy.
///
/// [toString] is deliberately redacted so accidental logging does not expose
/// the password. Hosts that persist these values should use secure storage.
final class ProxyCredentials {
  ProxyCredentials({required this.username, required this.password}) {
    if (username.isEmpty) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'network.proxy.username_empty',
        message: 'An authenticated proxy requires a username.',
      );
    }
  }

  final String username;
  final String password;

  @override
  String toString() => 'ProxyCredentials(username: ***, password: ***)';
}

final class HttpProxyServer {
  HttpProxyServer({required this.host, required this.port, this.credentials}) {
    if (host.trim().isEmpty || host.contains(RegExp(r'[\s/:]'))) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'network.proxy.host_invalid',
        message:
            'Proxy host must be a hostname or IP address without a scheme.',
      );
    }
    if (port < 1 || port > 65535) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'network.proxy.port_invalid',
        message: 'Proxy port must be between 1 and 65535.',
      );
    }
  }

  final String host;
  final int port;
  final ProxyCredentials? credentials;

  @override
  String toString() =>
      'HttpProxyServer($host:$port, authenticated: ${credentials != null})';
}

/// Routing policy for OAuth and official API HTTP traffic.
///
/// `environment` reads Dart's documented `http_proxy`, `https_proxy`, and
/// `no_proxy` variables on native platforms. It does not promise operating
/// system PAC discovery. Hosts that need a platform-specific stack can inject
/// a configured Dio instance instead.
final class NetworkProfile {
  NetworkProfile.environment({Map<String, String>? environment})
    : mode = NetworkProxyMode.environment,
      environment = environment == null
          ? null
          : Map<String, String>.unmodifiable(environment),
      proxy = null,
      bypassHosts = const <String>{};

  NetworkProfile.direct()
    : mode = NetworkProxyMode.direct,
      environment = null,
      proxy = null,
      bypassHosts = const <String>{};

  NetworkProfile.httpProxy({
    required HttpProxyServer proxyServer,
    Set<String> bypassHosts = const <String>{},
  }) : mode = NetworkProxyMode.httpProxy,
       environment = null,
       proxy = proxyServer,
       bypassHosts = Set<String>.unmodifiable(
         bypassHosts.map(_normalizeBypassHost),
       );

  final NetworkProxyMode mode;

  /// Optional environment override, mainly useful to hosts and deterministic
  /// tests. A null value reads the process environment at request time.
  final Map<String, String>? environment;
  final HttpProxyServer? proxy;
  final Set<String> bypassHosts;

  bool bypasses(Uri uri) {
    if (mode != NetworkProxyMode.httpProxy) return false;
    final host = uri.host.toLowerCase();
    return bypassHosts.any((rule) {
      if (rule == '*') return true;
      final suffix = rule.startsWith('.') ? rule.substring(1) : rule;
      return host == suffix || host.endsWith('.$suffix');
    });
  }

  static String _normalizeBypassHost(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty || normalized.contains(RegExp(r'[\s/:]'))) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'network.proxy.bypass_invalid',
        message: 'Proxy bypass entries must be hostname suffixes.',
      );
    }
    return normalized;
  }

  @override
  String toString() => 'NetworkProfile(mode: ${mode.name})';
}
