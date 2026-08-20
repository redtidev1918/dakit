enum DAKitFailureKind {
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

final class DAKitException implements Exception {
  const DAKitException({
    required this.kind,
    required this.code,
    required this.message,
    this.retryable = false,
    this.details = const <String, Object?>{},
    this.cause,
  });

  final DAKitFailureKind kind;
  final String code;
  final String message;
  final bool retryable;
  final Map<String, Object?> details;
  final Object? cause;

  @override
  String toString() => 'DAKitException($code): $message';
}
