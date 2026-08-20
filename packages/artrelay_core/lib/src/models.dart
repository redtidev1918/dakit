import 'media.dart';

final class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUri,
    this.profileUri,
  });

  final String id;
  final String username;
  final String? displayName;
  final Uri? avatarUri;
  final Uri? profileUri;
}

final class Artwork {
  const Artwork({
    required this.id,
    required this.title,
    required this.author,
    required this.pageUri,
    required this.media,
    this.description,
    this.publishedAt,
    this.isMature = false,
    this.isDownloadable = false,
    MediaAvailability? downloadAvailability,
    this.textContent,
  }) : downloadAvailability =
           downloadAvailability ??
           (isDownloadable
               ? MediaAvailability.available
               : MediaAvailability.unavailable);

  final String id;
  final String title;
  final UserProfile author;
  final Uri pageUri;
  final List<MediaAsset> media;
  final String? description;
  final DateTime? publishedAt;
  final bool isMature;
  final bool isDownloadable;
  final MediaAvailability downloadAvailability;
  final ArtworkTextContent? textContent;
}

/// Structured text embedded in a deviation response.
///
/// [markup] is provider-authored data and must be rendered or sanitized by the
/// host application according to its own trust boundary.
final class ArtworkTextContent {
  const ArtworkTextContent({
    required this.excerpt,
    this.format,
    this.markup,
    this.features,
  });

  final String excerpt;
  final String? format;
  final String? markup;
  final String? features;
}

/// Full rendered content returned by the dedicated content endpoint.
///
/// HTML and CSS are intentionally exposed as data. The SDK never evaluates
/// them or injects them into a web view.
final class ArtworkContent {
  const ArtworkContent({
    required this.artworkId,
    this.html,
    this.css,
    this.cssFonts = const <String>[],
    this.originalMarkup,
  });

  final String artworkId;
  final String? html;
  final String? css;
  final List<String> cssFonts;
  final String? originalMarkup;

  bool get isEmpty =>
      html == null && css == null && cssFonts.isEmpty && originalMarkup == null;
}
