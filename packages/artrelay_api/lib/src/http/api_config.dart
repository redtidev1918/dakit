import 'package:artrelay_core/artrelay_core.dart';

final class ApiConfig {
  ApiConfig({
    Uri? baseUri,
    this.minorVersion = 20240701,
    this.userAgent = 'ArtRelay/0.1',
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 30),
    this.retryPolicy = const RetryPolicy(),
  }) : baseUri = baseUri ?? Uri.https('www.deviantart.com', '/api/v1/oauth2/') {
    if (!this.baseUri.isScheme('https')) {
      throw const ArtRelayException(
        kind: ArtRelayFailureKind.configuration,
        code: 'api.base_uri.insecure',
        message: 'The official API base URI must use HTTPS.',
      );
    }
    if (minorVersion <= 0 || userAgent.trim().isEmpty) {
      throw const ArtRelayException(
        kind: ArtRelayFailureKind.configuration,
        code: 'api.config.invalid',
        message: 'API minor version and User-Agent must be configured.',
      );
    }
  }

  final Uri baseUri;
  final int minorVersion;
  final String userAgent;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final RetryPolicy retryPolicy;
}

final class RetryPolicy {
  const RetryPolicy({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maximumDelay = const Duration(seconds: 8),
  }) : assert(maxRetries >= 0);

  final int maxRetries;
  final Duration initialDelay;
  final Duration maximumDelay;

  Duration delayFor(int retry) {
    final multiplier = 1 << (retry - 1).clamp(0, 30);
    final milliseconds = initialDelay.inMilliseconds * multiplier;
    return Duration(
      milliseconds: milliseconds.clamp(0, maximumDelay.inMilliseconds),
    );
  }
}
