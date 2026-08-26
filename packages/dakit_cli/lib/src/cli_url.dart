/// Classifies a DeviantArt URL (or a bare artwork UUID/numeric id) into a
/// download target — mirroring gallery-dl's URL-pattern dispatch.
library;

enum CliUrlKind {
  /// A single deviation: an artwork or journal page, `/view/{id}`, or a
  /// fav.me short link.
  artwork,

  /// A whole gallery: `{user}/gallery`, a bare profile URL, or unknown
  /// `{user}/…` sections (profile, statuses, …).
  gallery,

  /// One gallery folder: `{user}/gallery/{folderId}/{name}`.
  galleryFolder,

  /// All favourites: `{user}/favourites`.
  favourites,

  /// One favourites collection: `{user}/favourites/{folderId}/{name}`.
  collectionFolder,

  /// A tag page: `deviantart.com/tag/{tag}`.
  tag,

  /// A search URL: `deviantart.com/search?q=…`.
  search,
}

final class CliUrlTarget {
  const CliUrlTarget({
    required this.kind,
    this.artworkId,
    this.username,
    this.folderId,
    this.query,
  });

  final CliUrlKind kind;

  /// Numeric or UUID id for [CliUrlKind.artwork].
  final String? artworkId;

  final String? username;

  /// Numeric web folder id for gallery/favourites folders.
  final String? folderId;

  /// Tag or search query.
  final String? query;
}

/// Parses a DeviantArt URL or a bare artwork id into a [CliUrlTarget].
/// Returns `null` for input that does not look like a DeviantArt target.
CliUrlTarget? parseCliUrl(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  // fav.me short links: fav.me/d{base36} or fav.me/{numeric}.
  final favMe = RegExp(
    r'fav\.me/(?:d)?([0-9a-z]+)',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (favMe != null) {
    return CliUrlTarget(
      kind: CliUrlKind.artwork,
      artworkId: base36Decode(favMe.group(1)!),
    );
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  final host = uri.host.toLowerCase();
  if (host.isEmpty || !_isDeviantArtHost(host)) {
    // Bare artwork id (UUID or numeric), not a URL path.
    if (!trimmed.contains('/') && !trimmed.contains(' ')) {
      return CliUrlTarget(kind: CliUrlKind.artwork, artworkId: trimmed);
    }
    return null;
  }

  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return null;

  switch (segments.first) {
    case 'view':
      return CliUrlTarget(
        kind: CliUrlKind.artwork,
        artworkId: segments.elementAtOrNull(1),
      );
    case 'view.php':
      return CliUrlTarget(
        kind: CliUrlKind.artwork,
        artworkId: uri.queryParameters['id'],
      );
    case 'tag':
      return CliUrlTarget(
        kind: CliUrlKind.tag,
        query: segments.elementAtOrNull(1),
      );
    case 'search':
      final query = uri.queryParameters['q']?.trim();
      if (query == null || query.isEmpty) return null;
      return CliUrlTarget(kind: CliUrlKind.search, query: query);
  }

  final user = segments.first;
  final rest = segments.sublist(1);
  if (rest.isEmpty) {
    return CliUrlTarget(kind: CliUrlKind.gallery, username: user);
  }
  switch (rest.first) {
    case 'art':
    case 'journal':
      return CliUrlTarget(
        kind: CliUrlKind.artwork,
        username: user,
        artworkId: _trailingArtworkId(rest.elementAtOrNull(1)),
      );
    case 'gallery':
      if (rest.length >= 3 && rest[1] != 'scraps') {
        return CliUrlTarget(
          kind: CliUrlKind.galleryFolder,
          username: user,
          folderId: rest[1],
        );
      }
      return CliUrlTarget(kind: CliUrlKind.gallery, username: user);
    case 'favourites':
      if (rest.length >= 3) {
        return CliUrlTarget(
          kind: CliUrlKind.collectionFolder,
          username: user,
          folderId: rest[1],
        );
      }
      return CliUrlTarget(kind: CliUrlKind.favourites, username: user);
    default:
      // e.g. {user}/profile, {user}/statuses — download their gallery.
      return CliUrlTarget(kind: CliUrlKind.gallery, username: user);
  }
}

bool _isDeviantArtHost(String host) =>
    host == 'deviantart.com' || host.endsWith('.deviantart.com');

/// Extracts the trailing numeric deviation id from a `{slug}-{id}` segment.
String? _trailingArtworkId(String? segment) {
  if (segment == null || segment.isEmpty) return null;
  final match = RegExp(r'-(\d+)$').firstMatch(segment);
  if (match != null) return match.group(1);
  return RegExp(r'^\d+$').hasMatch(segment) ? segment : null;
}

/// Decodes a base36 short id (fav.me links) to a decimal string. Returns the
/// input unchanged when it is not base36.
String base36Decode(String value) {
  var result = 0;
  for (final code in value.toLowerCase().codeUnits) {
    final digit = switch (code) {
      >= 0x30 && <= 0x39 => code - 0x30,
      >= 0x61 && <= 0x7a => code - 0x61 + 10,
      _ => -1,
    };
    if (digit < 0) return value;
    result = result * 36 + digit;
  }
  return '$result';
}
