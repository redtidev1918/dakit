import 'package:dakit_core/dakit_core.dart';

/// Supplies the DeviantArt web (cookie) session used by website endpoints.
///
/// Implementations should return `null` (or an empty [WebSession]) when no
/// cookie is configured, so callers can cleanly fall back to the OAuth API.
/// Cookie values are secrets: never log them — the diagnostic redactor treats
/// `cookie`/`set-cookie` as sensitive, and [WebSession.toString] is redacted.
abstract interface class CookieProvider {
  Future<WebSession?> session();
}

/// A provider that always returns the same [WebSession] (or none).
final class StaticCookieProvider implements CookieProvider {
  const StaticCookieProvider(WebSession? value) : _value = value;

  /// Build from a raw cookie string; `null`/blank yields a provider returning
  /// `null` (no web session).
  factory StaticCookieProvider.fromCookie(String? raw) =>
      StaticCookieProvider(WebSession.parse(raw));

  final WebSession? _value;

  @override
  Future<WebSession?> session() async => _value;
}

/// Reads the cookie from an environment-variable style map.
///
/// Honors `DAKIT_COOKIES` (the CLI's variable) by default. A blank or missing
/// value yields `null`, so unset environments simply have no web session.
final class EnvironmentCookieProvider implements CookieProvider {
  EnvironmentCookieProvider({
    Map<String, String>? environment,
    this.variable = 'DAKIT_COOKIES',
  }) : environment = environment ?? const <String, String>{};

  final Map<String, String> environment;
  final String variable;

  @override
  Future<WebSession?> session() async =>
      WebSession.parse(environment[variable]);
}
