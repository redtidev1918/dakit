import 'dart:convert';
import 'dart:io';

import 'package:dakit_api/dakit_api.dart';
import 'package:dakit_core/dakit_core.dart';
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
      final cases = <(DAKitException, MediaAvailability)>[
        (
          const DAKitException(
            kind: DAKitFailureKind.upstream,
            code: 'api.provider.invalid_request',
            message: 'Deviation not downloadable.',
            details: <String, Object?>{'provider_code': 2},
          ),
          MediaAvailability.unavailable,
        ),
        (
          const DAKitException(
            kind: DAKitFailureKind.authorization,
            code: 'api.http.403',
            message: 'Restricted.',
          ),
          MediaAvailability.restricted,
        ),
        (
          const DAKitException(
            kind: DAKitFailureKind.authentication,
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
    const failure = DAKitException(
      kind: DAKitFailureKind.network,
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
          isA<DAKitException>().having(
            (error) => error.code,
            'code',
            'api.dto.missing_field',
          ),
        ),
      );
    },
  );

  test('loads and posts artwork comments through stable models', () async {
    final transport = FixtureMutationTransport(
      getResponses: <Map<String, Object?>>[
        <String, Object?>{
          'has_more': true,
          'next_offset': 10,
          'has_less': false,
          'prev_offset': null,
          'total': 11,
          'thread': <Object?>[commentJson('comment-1', 'Existing comment')],
        },
      ],
      postResponses: <Map<String, Object?>>[
        commentJson('comment-2', 'Reply text', parentId: 'comment-1'),
      ],
    );
    final repository = OfficialCommentRepository(transport);

    final page = await repository.forArtwork(
      'art-1',
      request: const CommentPageRequest(limit: 10, maxDepth: 2),
    );
    final posted = await repository.postToArtwork(
      'art-1',
      'Reply text',
      parentCommentId: 'comment-1',
    );

    expect(page.items.single.body, 'Existing comment');
    expect(page.nextOffset, 10);
    expect(page.total, 11);
    expect(posted.parentId, 'comment-1');
    expect(transport.getRequests.single.path, 'comments/deviation/art-1');
    expect(transport.getRequests.single.query['maxdepth'], 2);
    expect(transport.postRequests.single.path, 'comments/post/deviation/art-1');
    expect(transport.postRequests.single.form, <String, Object?>{
      'body': 'Reply text',
      'commentid': 'comment-1',
    });
  });

  test(
    'maps favourite and watch mutations without leaking transport types',
    () async {
      final transport = FixtureMutationTransport(
        getResponses: <Map<String, Object?>>[
          <String, Object?>{'success': true},
        ],
        postResponses: <Map<String, Object?>>[
          <String, Object?>{'success': true, 'favourites': 8},
          <String, Object?>{'success': true, 'favourites': 7},
          <String, Object?>{'success': true},
        ],
      );
      final repository = OfficialSocialRepository(transport);

      final added = await repository.favourite(
        'art-1',
        collectionFolderIds: const <String>['folder-1'],
      );
      final removed = await repository.unfavourite('art-1');
      await repository.watch(
        'sample-user',
        options: const WatchOptions(activity: false),
      );
      await repository.unwatch('sample-user');

      expect(added.isFavourite, isTrue);
      expect(added.total, 8);
      expect(removed.isFavourite, isFalse);
      expect(removed.total, 7);
      expect(transport.postRequests[0].path, 'collections/fave');
      expect(transport.postRequests[0].form['folderid'], <String>['folder-1']);
      expect(transport.postRequests[2].form['watch[activity]'], isFalse);
      expect(
        transport.getRequests.single.path,
        'user/friends/unwatch/sample-user',
      );
    },
  );

  test('validates comment limits before making a request', () async {
    final transport = FixtureMutationTransport();

    await expectLater(
      OfficialCommentRepository(transport)
          .forArtwork('art-1', request: const CommentPageRequest(maxDepth: 6)),
      throwsA(
        isA<DAKitException>().having(
          (error) => error.code,
          'code',
          'api.comment.page.invalid',
        ),
      ),
    );
    expect(transport.getRequests, isEmpty);
  });
}

Map<String, Object?> commentJson(String id, String body, {String? parentId}) =>
    <String, Object?>{
      'commentid': id,
      'parentid': parentId,
      'posted': '2026-08-20T12:00:00Z',
      'replies': 0,
      'hidden': null,
      'body': body,
      'is_liked': false,
      'is_featured': false,
      'likes': 2,
      'user': <String, Object?>{'userid': 'user-1', 'username': 'sample-user'},
    };

Future<Map<String, Object?>> fixture(String name) async {
  final packageLocal = File('test/fixtures/$name');
  final workspaceLocal = File('packages/dakit_api/test/fixtures/$name');
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

final class FixtureMutationTransport implements OfficialApiMutationTransport {
  FixtureMutationTransport({
    List<Map<String, Object?>> getResponses = const <Map<String, Object?>>[],
    List<Map<String, Object?>> postResponses = const <Map<String, Object?>>[],
  }) : getResponses = List<Map<String, Object?>>.of(getResponses),
       postResponses = List<Map<String, Object?>>.of(postResponses);

  final List<Map<String, Object?>> getResponses;
  final List<Map<String, Object?>> postResponses;
  final List<FixtureRequest> getRequests = <FixtureRequest>[];
  final List<FixtureMutationRequest> postRequests = <FixtureMutationRequest>[];

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    CancelToken? cancelToken,
  }) async {
    getRequests.add(FixtureRequest(path, Map<String, Object?>.of(query)));
    return getResponses.removeAt(0);
  }

  @override
  Future<Map<String, Object?>> postFormJson(
    String path, {
    Map<String, Object?> form = const <String, Object?>{},
    CancelToken? cancelToken,
  }) async {
    postRequests.add(
      FixtureMutationRequest(path, Map<String, Object?>.of(form)),
    );
    return postResponses.removeAt(0);
  }
}

final class FixtureMutationRequest {
  const FixtureMutationRequest(this.path, this.form);

  final String path;
  final Map<String, Object?> form;
}

final class ThrowingTransport implements OfficialApiTransport {
  const ThrowingTransport(this.failure);

  final DAKitException failure;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    CancelToken? cancelToken,
  }) => Future<Map<String, Object?>>.error(failure);
}
