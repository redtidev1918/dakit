import 'package:dakit_cli/src/cli.dart';
import 'package:test/test.dart';

void main() {
  group('runCli', () {
    test('prints root and command help successfully', () async {
      expect(await runCli(const <String>['--help']), 0);
      expect(await runCli(const <String>['login', '--help']), 0);
    });

    test('supports conventional version forms', () async {
      expect(await runCli(const <String>['--version']), 0);
      expect(await runCli(const <String>['version']), 0);
    });

    test('returns usage status for invalid arguments', () async {
      expect(await runCli(const <String>['--not-an-option']), 64);
      expect(await runCli(const <String>['search']), 64);
    });
  });
}
