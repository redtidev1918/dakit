import 'package:dakit_api/dakit_api.dart';
import 'package:dakit_core/dakit_core.dart';
import 'package:test/test.dart';

void main() {
  group('StaticCookieProvider', () {
    test('returns parsed session or null', () async {
      final withCookie = StaticCookieProvider.fromCookie('auth=a; auth_secure=b');
      final s = await withCookie.session();
      expect(s, isNotNull);
      expect(s!.looksAuthenticated, isTrue);

      final empty = StaticCookieProvider.fromCookie('  ');
      expect(await empty.session(), isNull);
    });
  });

  group('EnvironmentCookieProvider', () {
    test('reads DAKIT_COOKIES by default', () async {
      final provider = EnvironmentCookieProvider(
        environment: const <String, String>{'DAKIT_COOKIES': 'auth=x'},
      );
      final s = await provider.session();
      expect(s, isNotNull);
      expect(s!.cookieHeader, 'auth=x');
    });

    test('missing variable yields null', () async {
      final provider = EnvironmentCookieProvider(
        environment: const <String, String>{},
      );
      expect(await provider.session(), isNull);
    });

    test('honours a custom variable name', () async {
      final provider = EnvironmentCookieProvider(
        variable: 'MY_COOKIE',
        environment: const <String, String>{'MY_COOKIE': 'auth=y'},
      );
      expect(await provider.session(), isNotNull);
    });
  });

  group('redaction', () {
    test('cookie field is redacted', () {
      const redactor = Redactor();
      final out = redactor.fields(const <String, Object?>{
        'cookie': 'auth=supersecret',
        'set-cookie': 'auth_secure=hidden',
        'status': 200,
      });
      expect(out['cookie'], '<redacted>');
      expect(out['set-cookie'], '<redacted>');
      expect(out['status'], 200);
    });
  });
}
