import 'package:artrelay_core/artrelay_core.dart';
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
