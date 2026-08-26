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

  group('download helpers', () {
    test('renders filename templates with tokens', () {
      final asset = MediaAsset(
        id: 'uuid-1',
        kind: MediaKind.image,
        role: MediaRole.original,
        availability: MediaAvailability.available,
        uri: Uri.parse('https://example.test/underwater.jpg'),
        filename: 'underwater_by_loish_d913624585.jpg',
      );
      expect(
        resolveFilenameTemplate(
          '{id}_{title}.{ext}',
          asset,
          artworkId: '913624585',
          title: 'Underwater',
          username: 'loish',
          published: DateTime.parse('2022-04-20T03:42:50-0700'),
        ),
        '913624585_Underwater.jpg',
      );
      expect(
        resolveFilenameTemplate(
          '{published}_{username}_{filename}.{ext}',
          asset,
          username: 'loish',
          published: DateTime.parse('2022-04-20T03:42:50-0700'),
        ),
        '2022-04-20_loish_underwater_by_loish_d913624585.jpg',
      );
    });

    test('sanitizes template output', () {
      final asset = MediaAsset(
        id: 'uuid-1',
        kind: MediaKind.image,
        role: MediaRole.original,
        availability: MediaAvailability.available,
        uri: Uri.parse('https://example.test/a.jpg'),
        filename: 'a.jpg',
      );
      // safeFilename keeps only the last path segment (traversal guard) and
      // replaces illegal characters, so a hostile title cannot escape the
      // output directory.
      expect(
        resolveFilenameTemplate('{title}', asset, title: 'a/b:c?.jpg'),
        'b_c_.jpg',
      );
    });

    test('tracks archive membership and appends new ids', () async {
      final directory = await Directory.systemTemp.createTemp('dakit-archive-');
      final path = '${directory.path}${Platform.pathSeparator}archive.txt';
      await File(path).writeAsString('known-id\n');
      try {
        final archive = await DownloadArchive.open(path);
        expect(archive.contains('known-id'), isTrue);
        expect(archive.contains('new-id'), isFalse);
        await archive.add('new-id');
        final reopened = await DownloadArchive.open(path);
        expect(reopened.contains('new-id'), isTrue);
      } finally {
        await directory.delete(recursive: true);
      }
    });

    test('archive is a no-op when no path is given', () async {
      final archive = await DownloadArchive.open(null);
      expect(archive.contains('x'), isFalse);
      await archive.add('x'); // must not throw
    });
  });
}
