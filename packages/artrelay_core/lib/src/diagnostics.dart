enum DiagnosticStage {
  dns,
  connect,
  tls,
  http,
  oauthLaunch,
  oauthCallback,
  tokenExchange,
  parsing,
  storage,
  transfer,
}

enum DiagnosticLevel { debug, info, warning, error }

final class DiagnosticEvent {
  DiagnosticEvent({
    required this.stage,
    required this.level,
    required this.code,
    required this.message,
    DateTime? occurredAt,
    this.operationId,
    this.elapsed,
    this.attributes = const <String, Object?>{},
  }) : occurredAt = occurredAt ?? DateTime.now().toUtc();

  final DiagnosticStage stage;
  final DiagnosticLevel level;
  final String code;
  final String message;
  final DateTime occurredAt;
  final String? operationId;
  final Duration? elapsed;
  final Map<String, Object?> attributes;
}

abstract interface class DiagnosticSink {
  void add(DiagnosticEvent event);
}

final class NoopDiagnosticSink implements DiagnosticSink {
  const NoopDiagnosticSink();

  @override
  void add(DiagnosticEvent event) {}
}
