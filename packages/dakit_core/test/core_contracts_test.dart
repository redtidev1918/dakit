import 'package:dakit_core/dakit_core.dart';
import 'package:test/test.dart';

void main() {
  group('AuthTokens', () {
    test('treats a token inside the refresh leeway as expired', () {
      final now = DateTime.utc(2026, 8, 20, 12);
      final tokens = AuthTokens(
        accessToken: 'redacted',
        tokenType: 'Bearer',
        expiresAt: now.add(const Duration(seconds: 30)),
      );

      expect(tokens.isExpired(now), isTrue);
      expect(tokens.isExpired(now, leeway: Duration.zero), isFalse);
    });
  });

  test('restricted media cannot be transferred without a URI', () {
    const asset = MediaAsset(
      id: 'asset-1',
      kind: MediaKind.image,
      role: MediaRole.original,
      availability: MediaAvailability.restricted,
    );

    expect(asset.canTransfer, isFalse);
  });

  test('media asset exposes an optional availability reason', () {
    const withoutReason = MediaAsset(
      id: 'asset-1',
      kind: MediaKind.image,
      role: MediaRole.original,
      availability: MediaAvailability.unavailable,
    );
    const withReason = MediaAsset(
      id: 'asset-2',
      kind: MediaKind.image,
      role: MediaRole.original,
      availability: MediaAvailability.unavailable,
      availabilityReason: 'Free download limit reached.',
    );

    expect(withoutReason.availabilityReason, isNull);
    expect(withReason.availabilityReason, 'Free download limit reached.');
  });

  test('artwork derives an honest original availability by default', () {
    final downloadable = Artwork(
      id: 'downloadable',
      title: 'Downloadable',
      author: user,
      pageUri: Uri.parse('https://example.test/downloadable'),
      media: const <MediaAsset>[],
      isDownloadable: true,
    );
    final previewOnly = Artwork(
      id: 'preview-only',
      title: 'Preview only',
      author: user,
      pageUri: Uri.parse('https://example.test/preview-only'),
      media: const <MediaAsset>[],
    );

    expect(downloadable.downloadAvailability, MediaAvailability.available);
    expect(previewOnly.downloadAvailability, MediaAvailability.unavailable);
  });

  test('artwork copyWith replaces only the requested fields', () {
    final artwork = Artwork(
      id: 'art-1',
      title: 'Title',
      author: user,
      pageUri: Uri.parse('https://example.test/art-1'),
      media: const <MediaAsset>[],
      description: 'desc',
      isMature: true,
      isDownloadable: true,
      isFavourited: false,
      isMultiMedia: true,
      tags: const <String>['a', 'b'],
    );

    final favourited = artwork.copyWith(isFavourited: true);

    expect(favourited.isFavourited, isTrue);
    expect(favourited.id, 'art-1');
    expect(favourited.title, 'Title');
    expect(favourited.author.username, 'sample-user');
    expect(favourited.description, 'desc');
    expect(favourited.isMature, isTrue);
    expect(favourited.isDownloadable, isTrue);
    expect(favourited.isMultiMedia, isTrue);
    expect(favourited.tags, <String>['a', 'b']);
    expect(artwork.isFavourited, isFalse);
  });

  test('page with more results requires a cursor', () {
    expect(
      () => Page<String>(items: const <String>[], hasMore: true),
      throwsA(isA<AssertionError>()),
    );
  });

  test('transfer completion is a final state', () {
    const snapshot = TransferSnapshot(
      id: 'task-1',
      state: TransferState.completed,
      progress: 1,
    );

    expect(snapshot.isFinal, isTrue);
  });
}

const user = UserProfile(id: 'user-1', username: 'sample-user');
