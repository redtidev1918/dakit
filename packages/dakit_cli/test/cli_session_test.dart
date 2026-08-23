import 'dart:io';

import 'package:dakit_cli/src/cli_session.dart';
import 'package:dakit_core/dakit_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('dakit-session-test-');
  });

  tearDown(() => directory.delete(recursive: true));

  test('round-trips credentials and OAuth refresh settings', () async {
    final tokenStore = FileTokenStore(
      path: '${directory.path}/credentials.json',
    );
    final settingsStore = FileCliSettingsStore(
      path: '${directory.path}/client.json',
    );
    final tokens = AuthTokens(
      accessToken: 'access',
      tokenType: 'Bearer',
      expiresAt: DateTime.utc(2030),
      refreshToken: 'refresh',
      scopes: const <String>{'basic', 'browse'},
    );
    final settings = CliOAuthSettings(
      clientId: '1234',
      redirectUri: Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: 8765,
        path: '/callback',
      ),
    );

    await tokenStore.write(tokens);
    await settingsStore.write(settings);

    final restoredTokens = await tokenStore.read();
    final restoredSettings = await settingsStore.read();
    expect(restoredTokens!.accessToken, 'access');
    expect(restoredTokens.refreshToken, 'refresh');
    expect(restoredTokens.scopes, <String>{'basic', 'browse'});
    expect(restoredSettings!.clientId, '1234');
    expect(restoredSettings.redirectUri, settings.redirectUri);
  });

  test('reports malformed credential JSON without leaking contents', () async {
    final path = '${directory.path}/credentials.json';
    await File(path).writeAsString('{not-json');
    final store = FileTokenStore(path: path);

    expect(
      store.read,
      throwsA(
        isA<DAKitException>().having(
          (error) => error.code,
          'code',
          'cli.credentials.invalid_json',
        ),
      ),
    );
  });
}
