/// DeviantArt website session used for the private `_puppy` endpoints.
///
/// Mature (age-restricted) multi-image works are NOT served by the public
/// OAuth API: `deviation/{uuid}` returns 404 for them and never returns the
/// additional pages. The website's own `_puppy/dadeviation/init` endpoint,
/// called with a logged-in **web cookie**, is the only way to resolve such an
/// id to its media. [WebSession] carries that cookie header value.
///
/// A web session is separate from the OAuth [AuthTokenProvider]: it is a
/// browser cookie string (e.g. `auth=…; auth_secure=…; userinfo=…`), not a
/// bearer token.
library;

/// A DeviantArt web (cookie) session.
///
/// Instances are cheap value objects. [cookieHeader] returns the exact value
/// to send in the `Cookie:` HTTP header; it is never logged (the redaction
/// table treats `cookie` / `set-cookie` as sensitive).
final class WebSession {
  const WebSession(this._cookie);

  /// Build a session from a raw cookie string (`name=value; name2=value2`).
  ///
  /// Whitespace around segments and a trailing semicolon are tolerated.
  /// Returns `null` for an empty/blank input so callers can treat "no cookie"
  /// as "no web session".
  static WebSession? parse(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final normalised = trimmed
        .split(RegExp(r';\s*'))
        .where((segment) => segment.trim().isNotEmpty)
        .map((segment) => segment.trim())
        .join('; ');
    if (normalised.isEmpty) return null;
    return WebSession(normalised);
  }

  final String _cookie;

  /// The value for a `Cookie:` request header. Empty when the session holds no
  /// cookie (use [isPresent] to gate requests).
  String get cookieHeader => _cookie;

  /// Whether this session carries at least one cookie.
  bool get isPresent => _cookie.isNotEmpty;

  /// Best-effort check that the session includes the login markers DeviantArt
  /// sets for an authenticated browser (`auth` / `auth_secure`). Anonymous
  /// visitors may hold other cookies, so this is only a hint for diagnostics —
  /// requests are not gated on it.
  bool get looksAuthenticated {
    final names = _cookie
        .split(';')
        .map((segment) => segment.split('=').first.trim().toLowerCase())
        .toSet();
    return names.contains('auth') || names.contains('auth_secure');
  }

  @override
  bool operator ==(Object other) =>
      other is WebSession && other._cookie == _cookie;

  @override
  int get hashCode => _cookie.hashCode;

  /// Deliberately redacted: logs/`toString` must never leak the cookie.
  @override
  String toString() => 'WebSession(present: $isPresent, '
      'authenticated: $looksAuthenticated)';
}
