import 'dart:convert';
import 'dart:io';

import 'package:artrelay_api/artrelay_api.dart';
import 'package:artrelay_core/artrelay_core.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  test('maps the authenticated user and ignores additive fields', () async {
    final transport = FixtureTransport(<Map<String, Object?>>[
      await fixture('whoami.json'),
    ]);

    final user = await OfficialAccountRepository(transport).currentUser();

    expect(user.id, 'user-1');
    expect(user.username, 'sample-user');
    expect(user.avatarUri?.host, 'images.example.test');
    expect(transport.requests.single.path, 'user/whoami');
  });

  test('maps artwork image and video variants without treating previews as originals', () async {
    final transport = FixtureTransport(<Map<String, Object?>>[
      await fixture('deviation.json'),
    ]);

    final artwork = await OfficialArtworkRepository(transport).getById('art-1');

    expect(artwork.title, 'Example work');
    expect(artwork.publishedAt, DateTime.utc(2026, 8, 20, 3, 4, 5));
    expect(artwork.isDownloadable, isTrue);
    expect(artwork.downloadAvailability, MediaAvailability.available);
    expect(artwork.textContent?.format, 'writer');
    expect(artwork.textContent?.features, 'tables,links');
    expect(artwork.media, hasLength(3));
    expect(
      artwork.media.map((asset) => asset.kind),
      containsAll(<MediaKind>[MediaKind.image, MediaKind.video]),
    );
    expect(
      artwork.media.every((asset) => asset.role == MediaRole.preview),
      isTrue,
    );
    expect(transport.requests.single.path, 'deviation/art-1');
    expect(transport.requests.single.query['expand'], 'deviation.fulltext');
  });

  test(
    'loads rendered literature without executing provider HTML or CSS',
    () async {
      final transport = FixtureTransport(<Map<String, Object?>>[
        await fixture('content.json'),
      ]);

      final content = await OfficialArtworkContentRepository(transport)
          .get('art-1');

      expect(content.artworkId, 'art-1');
      expect(content.html, contains('Rendered literature'));
      expect(content.cssFonts, hasLength(1));
      expect(content.isEmpty, isFalse);
      expect(transport.requests.single.path, 'deviation/content');
      expect(transport.requests.single.query, <String, Object?>{
        'deviationid': 'art-1',
        'for_edit': false,
        'with_session': false,
      });
    },
  );

  test(
    'distinguishes paid and blocked original access in detail metadata',
    () async {
      final paidJson = await fixture('deviation.json')
        ..['is_downloadable'] = false
        ..['premium_folder_data'] = <String, Object?>{
          'type': 'premium',
          'has_access': false,
          'gallery_id': 'paid-gallery',
        };
      final blockedJson = await fixture('deviation.json')
        ..['is_downloadable'] = false
        ..['is_blocked'] = true;
      final transport = FixtureTransport(<Map<String, Object?>>[
        paidJson,
        blockedJson,
      ]);
      final repository = OfficialArtworkRepository(transport);

      final paid = await repository.getById('paid');
      final blocked = await repository.getById('blocked');

      expect(paid.downloadAvailability, MediaAvailability.purchaseRequired);
      expect(blocked.downloadAvailability, MediaAvailability.restricted);
    },
  );

  test('uses documented home pagination and search parameters', () async {
    final transport = FixtureTransport(<Map<String, Object?>>[
      await fixture('gallery_page.json'),
      await fixture('gallery_page.json'),
    ]);
    final repository = OfficialArtworkRepository(transport);

    final first = await repository.browse(const PageRequest(limit: 20));
    final search = await repository.search(
      'landscape',
      const PageRequest(cursor: '24', limit: 12),
    );

    expect(first.hasMore, isTrue);
    expect(first.nextCursor, '24');
    expect(search.items.single.id, 'art-1');
    expect(transport.requests[0].query, <String, Object?>{
      'offset': 0,
      'limit': 20,
    });
    expect(transport.requests[1].query, <String, Object?>{
      'offset': 24,
      'limit': 12,
      'q': 'landscape',
    });
  });

  test('clamps gallery limit to the provider maximum of 24', () async {
    final transport = FixtureTransport(<Map<String, Object?>>[
      await fixture('gallery_page.json'),
    ]);

    await OfficialGalleryRepository(transport)
        .gallery('sample-user', const PageRequest(limit: 50));

    expect(transport.requests.single.path, 'gallery/all');
    expect(transport.requests.single.query['limit'], 24);
  });

  test(
    'resolves original transfer metadata through the download endpoint',
    () async {
      final transport = FixtureTransport(<Map<String, Object?>>[
        await fixture('download.json'),
      ]);

      final asset = await OfficialMediaRepository(transport)
          .originalFile('art-1');

      expect(asset.role, MediaRole.original);
      expect(asset.kind, MediaKind.archive);
      expect(asset.byteLength, 50331648);
      expect(asset.canTransfer, isTrue);
      expect(transport.requests.single.path, 'deviation/download/art-1');
    },
  );

  test(
    'maps expected download denials without inventing an original URL',
    () async {
      final cases = <(ArtRelayException, MediaAvailability)>[
        (
          const ArtRelayException(
            kind: ArtRelayFailureKind.upstream,
            code: 'api.provider.invalid_request',
            message: 'Deviation not downloadable.',
            details: <String, Object?>{'provider_code': 2},
          ),
          MediaAvailability.unavailable,
        ),
        (
          const ArtRelayException(
            kind: ArtRelayFailureKind.authorization,
            code: 'api.http.403',
            message: 'Restricted.',
          ),
          MediaAvailability.restricted,
        ),
        (
          const ArtRelayException(
            kind: ArtRelayFailureKind.authentication,
            code: 'api.http.401',
            message: 'Login required.',
          ),
          MediaAvailability.loginRequired,
        ),
      ];

      for (final (failure, availability) in cases) {
        final asset = await OfficialMediaRepository(ThrowingTransport(failure))
            .originalFile('art-1');
        expect(asset.availability, availability);
        expect(asset.uri, isNull);
        expect(asset.canTransfer, isFalse);
      }
    },
  );

  test('keeps unexpected transfer failures observable', () async {
    const failure = ArtRelayException(
      kind: ArtRelayFailureKind.network,
      code: 'network.connection',
      message: 'Offline.',
    );

    expect(
      () =>
          OfficialMediaRepository(const ThrowingTransport(failure))
              .originalFile('art-1'),
      throwsA(same(failure)),
    );
  });

  test(
    'reports a typed parsing failure when required fields disappear',
    () async {
      final transport = FixtureTransport(<Map<String, Object?>>[
        <String, Object?>{'deviationid': 'art-1', 'is_deleted': false},
      ]);

      expect(
        () => OfficialArtworkRepository(transport).getById('art-1'),
        throwsA(
          isA<ArtRelayException>().having(
            (error) => error.code,
            'code',
            'api.dto.missing_field',
          ),
        ),
      );
    },
  );
}

Future<Map<String, Object?>> fixture(String name) async {
  final packageLocal = File('test/fixtures/$name');
  final workspaceLocal = File('packages/artrelay_api/test/fixtures/$name');
  final file = await packageLocal.exists() ? packageLocal : workspaceLocal;
  final data = jsonDecode(await file.readAsString());
  return (data as Map).map<String, Object?>(
    (key, value) => MapEntry(key.toString(), value),
  );
}

final class FixtureTransport implements OfficialApiTransport {
  FixtureTransport(this.responses);

  final List<Map<String, Object?>> responses;
  final List<FixtureRequest> requests = <FixtureRequest>[];

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    CancelToken? cancelToken,
  }) async {
    requests.add(FixtureRequest(path, Map<String, Object?>.of(query)));
    return responses.removeAt(0);
  }
}

final class FixtureRequest {
  const FixtureRequest(this.path, this.query);

  final String path;
  final Map<String, Object?> query;
}

final class ThrowingTransport implements OfficialApiTransport {
  const ThrowingTransport(this.failure);

  final ArtRelayException failure;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    CancelToken? cancelToken,
  }) => Future<Map<String, Object?>>.error(failure);
}
