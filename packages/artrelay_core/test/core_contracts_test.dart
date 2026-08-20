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

  test('page with more results requires a cursor', () {
    expect(
      () => Page<String>(items: const <String>[], hasMore: true),
      throwsA(isA<AssertionError>()),
    );
  });
}
