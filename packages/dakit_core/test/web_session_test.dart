import 'package:dakit_core/dakit_core.dart';
import 'package:test/test.dart';

void main() {
  group('WebSession', () {
    test('parse normalises segments and tolerates whitespace', () {
      final session = WebSession.parse(' auth=a ; auth_secure=b ; userinfo=c ');
      expect(session, isNotNull);
      expect(session!.isPresent, isTrue);
      expect(session.cookieHeader, 'auth=a; auth_secure=b; userinfo=c');
    });

    test('blank / null input yields no session', () {
      expect(WebSession.parse(null), isNull);
      expect(WebSession.parse(''), isNull);
      expect(WebSession.parse('   '), isNull);
      expect(WebSession.parse(' ; ; '), isNull);
    });

    test('detects login markers', () {
      expect(
        WebSession.parse('auth=x; auth_secure=y')!.looksAuthenticated,
        isTrue,
      );
      expect(WebSession.parse('foo=bar')!.looksAuthenticated, isFalse);
    });

    test('toString never contains the cookie value', () {
      const secret = 'super-secret-token-value-123456';
      final session = WebSession.parse('auth=$secret');
      final rendered = session.toString();
      expect(rendered, contains('present: true'));
      expect(rendered, isNot(contains(secret)));
      expect(rendered, isNot(contains('super-secret')));
    });

    test('equality by cookie value', () {
      expect(WebSession.parse('auth=a'), equals(WebSession.parse('auth=a')));
      expect(
        WebSession.parse('auth=a'),
        isNot(equals(WebSession.parse('auth=b'))),
      );
    });
  });
}
