enum ArtRelayFailureKind {
  configuration,
  authentication,
  authorization,
  network,
  rateLimit,
  notFound,
  restricted,
  upstream,
  parsing,
  storage,
  transfer,
  cancelled,
}

final class ArtRelayException implements Exception {
  const ArtRelayException({
    required this.kind,
    required this.code,
    required this.message,
    this.retryable = false,
    this.details = const <String, Object?>{},
    this.cause,
  });

  final ArtRelayFailureKind kind;
  final String code;
  final String message;
  final bool retryable;
  final Map<String, Object?> details;
  final Object? cause;

  @override
  String toString() => 'ArtRelayException($code): $message';
}
