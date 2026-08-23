import 'dart:convert';
import 'dart:io';

import 'package:dakit_api/dakit_api.dart';
import 'package:dakit_cli/src/cli_networking.dart';
import 'package:dakit_core/dakit_core.dart';
import 'package:test/test.dart';

void main() {
  group('CLI option parsing', () {
    test('preserves every word in a search query', () {
      expect(
        searchQuery(<String>['digital', 'concept', 'art']),
        'digital concept art',
      );
    });

    test('accepts zero delay but rejects invalid values', () {
      expect(nonNegativeInt('0', 1, '--delay'), 0);
      expect(
        () => nonNegativeInt('-1', 1, '--delay'),
        throwsA(isA<DAKitException>()),
      );
      expect(
        () => positiveInt('abc', 24, '--limit'),
        throwsA(isA<DAKitException>()),
      );
    });

    test('accepts host, URL, and all_proxy HTTP forms', () {
      expect(resolveNetworkProfile('127.0.0.1:7892').proxy!.port, 7892);
      expect(
        resolveNetworkProfile('http://proxy.example:8080').proxy!.host,
        'proxy.example',
      );
      expect(
        resolveNetworkProfile(
          null,
          environment: const <String, String>{
            'all_proxy': 'http://127.0.0.1:7892',
          },
        ).proxy!.port,
        7892,
      );
      expect(
        () => resolveNetworkProfile('socks5://127.0.0.1:1080'),
        throwsA(isA<DAKitException>()),
      );
    });

    test('sanitizes paths and extracts URL identifiers', () {
      expect(safeFilename('../bad:name?.png'), 'bad_name_.png');
      expect(extractUuid('https://example.test/art/uuid-123'), 'uuid-123');
      expect(extractUuid('uuid-123'), 'uuid-123');
      expect(terminalText('unsafe\n\u001b[31mtext'), 'unsafe [31mtext');
    });
  });

  test(
    'streams downloads, preserves files, and overwrites explicitly',
    () async {
      var requestCount = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        requestCount += 1;
        request.response.headers.contentType = ContentType.text;
        request.response.add(
          utf8.encode(requestCount == 1 ? 'first' : 'second'),
        );
        await request.response.close();
      });
      final directory = await Directory.systemTemp.createTemp(
        'dakit-cli-test-',
      );
      final asset = MediaAsset(
        id: 'asset',
        kind: MediaKind.image,
        role: MediaRole.original,
        availability: MediaAvailability.available,
        uri: Uri.parse('http://127.0.0.1:${server.port}/asset'),
        filename: 'asset.txt',
      );

      try {
        final first = await downloadAsset(
          asset: asset,
          profile: NetworkProfile.direct(),
          outputDirectory: directory,
        );
        expect(first, startsWith('saved='));
        final file = File(
          '${directory.path}${Platform.pathSeparator}asset.txt',
        );
        expect(await file.readAsString(), 'first');

        final existing = await downloadAsset(
          asset: asset,
          profile: NetworkProfile.direct(),
          outputDirectory: directory,
        );
        expect(existing, startsWith('exists='));
        expect(requestCount, 1);

        await downloadAsset(
          asset: asset,
          profile: NetworkProfile.direct(),
          outputDirectory: directory,
          overwrite: true,
        );
        expect(await file.readAsString(), 'second');
        expect(await File('${file.path}.part').exists(), isFalse);
        expect(await File('${file.path}.bak').exists(), isFalse);
      } finally {
        await server.close(force: true);
        await directory.delete(recursive: true);
      }
    },
  );
}
