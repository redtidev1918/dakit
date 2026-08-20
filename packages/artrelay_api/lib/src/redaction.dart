final class Redactor {
  const Redactor();

  static const Set<String> _sensitiveNames = <String>{
    'access_token',
    'authorization',
    'client_secret',
    'code',
    'code_verifier',
    'cookie',
    'refresh_token',
    'set-cookie',
    'token',
  };

  Map<String, Object?> fields(Map<String, Object?> values) => <String, Object?>{
    for (final entry in values.entries)
      entry.key: _sensitiveNames.contains(entry.key.toLowerCase())
          ? '<redacted>'
          : entry.value,
  };

  Uri uri(Uri value) {
    if (!value.hasQuery) return value;
    return value.replace(
      queryParameters: <String, String>{
        for (final entry in value.queryParameters.entries)
          entry.key: _sensitiveNames.contains(entry.key.toLowerCase())
              ? '<redacted>'
              : entry.value,
      },
    );
  }
}
