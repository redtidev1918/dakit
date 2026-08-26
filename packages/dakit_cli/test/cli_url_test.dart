import 'package:dakit_cli/src/cli_url.dart';
import 'package:test/test.dart';

void main() {
  group('parseCliUrl', () {
    test('classifies artwork pages by trailing numeric id', () {
      final target = parseCliUrl(
        'https://www.deviantart.com/loish/art/underwater-913624585',
      );
      expect(target?.kind, CliUrlKind.artwork);
      expect(target?.artworkId, '913624585');
      expect(target?.username, 'loish');
    });

    test('classifies journal pages', () {
      final target = parseCliUrl(
        'https://www.deviantart.com/loish/journal/My-Update-42',
      );
      expect(target?.kind, CliUrlKind.artwork);
      expect(target?.artworkId, '42');
    });

    test('classifies fav.me short links via base36', () {
      final target = parseCliUrl('https://fav.me/df3y58p');
      expect(target?.kind, CliUrlKind.artwork);
      expect(target?.artworkId, '913624585');
    });

    test('classifies view and view.php links', () {
      expect(
        parseCliUrl('https://www.deviantart.com/view/913624585/')?.artworkId,
        '913624585',
      );
      expect(
        parseCliUrl('https://www.deviantart.com/view.php?id=913624585')
            ?.artworkId,
        '913624585',
      );
    });

    test('accepts bare UUIDs and numeric ids', () {
      final uuid = 'a0367442-a7cf-4b5e-9b2a-585e6d98ce8d';
      expect(parseCliUrl(uuid)?.kind, CliUrlKind.artwork);
      expect(parseCliUrl(uuid)?.artworkId, uuid);
      expect(parseCliUrl('913624585')?.kind, CliUrlKind.artwork);
    });

    test('classifies galleries, folders, and favourites', () {
      expect(
        parseCliUrl('https://www.deviantart.com/loish/gallery')?.kind,
        CliUrlKind.gallery,
      );
      expect(
        parseCliUrl('https://www.deviantart.com/loish')?.kind,
        CliUrlKind.gallery,
      );
      final folder = parseCliUrl(
        'https://www.deviantart.com/loish/gallery/123456/My-Set',
      );
      expect(folder?.kind, CliUrlKind.galleryFolder);
      expect(folder?.folderId, '123456');
      expect(folder?.username, 'loish');
      expect(
        parseCliUrl('https://www.deviantart.com/loish/favourites')?.kind,
        CliUrlKind.favourites,
      );
      final collection = parseCliUrl(
        'https://www.deviantart.com/loish/favourites/654321/My-Favs',
      );
      expect(collection?.kind, CliUrlKind.collectionFolder);
      expect(collection?.folderId, '654321');
    });

    test('classifies tag and search URLs', () {
      expect(
        parseCliUrl('https://www.deviantart.com/tag/digitalart')?.kind,
        CliUrlKind.tag,
      );
      expect(
        parseCliUrl('https://www.deviantart.com/tag/digitalart')?.query,
        'digitalart',
      );
      final search = parseCliUrl(
        'https://www.deviantart.com/search?q=concept+art',
      );
      expect(search?.kind, CliUrlKind.search);
      expect(search?.query, 'concept art');
    });

    test('rejects non-DeviantArt input', () {
      expect(parseCliUrl('https://example.com/art/1-2'), isNull);
      expect(parseCliUrl('not a url with spaces'), isNull);
      expect(parseCliUrl(''), isNull);
    });
  });

  group('base36Decode', () {
    test('decodes base36 ids', () {
      expect(base36Decode('f3y58p'), '913624585');
      expect(base36Decode('0'), '0');
    });

    test('returns the input unchanged when not base36', () {
      expect(base36Decode('hello-world'), 'hello-world');
    });
  });
}
