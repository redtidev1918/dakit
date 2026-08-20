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

/// Counts exposed by a public DeviantArt profile.
final class UserProfileStats {
  const UserProfileStats({
    required this.deviations,
    required this.favourites,
    required this.comments,
    required this.pageViews,
    required this.profileComments,
  });

  final int deviations;
  final int favourites;
  final int comments;
  final int pageViews;
  final int profileComments;
}

/// Full profile information returned by the dedicated profile endpoint.
final class UserProfileDetails {
  const UserProfileDetails({
    required this.user,
    required this.isWatching,
    required this.profileUri,
    required this.isArtist,
    required this.stats,
    this.artistLevel,
    this.artistSpecialty,
    this.realName,
    this.tagline,
    this.country,
    this.website,
    this.bio,
    this.coverPhotoUri,
  });

  final UserProfile user;
  final bool isWatching;
  final Uri profileUri;
  final bool isArtist;
  final UserProfileStats stats;
  final String? artistLevel;
  final String? artistSpecialty;
  final String? realName;
  final String? tagline;
  final String? country;
  final String? website;
  final String? bio;
  final Uri? coverPhotoUri;
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

/// A comment returned by the official API.
///
/// [body] and [hiddenReason] are provider-authored data. Hosts should escape or
/// sanitize them for their chosen renderer.
final class Comment {
  const Comment({
    required this.id,
    required this.postedAt,
    required this.body,
    required this.author,
    required this.replyCount,
    required this.likeCount,
    this.parentId,
    this.hiddenReason,
    this.isLiked = false,
    this.isFeatured = false,
  });

  final String id;
  final String? parentId;
  final DateTime postedAt;
  final String body;
  final UserProfile author;
  final int replyCount;
  final int likeCount;
  final String? hiddenReason;
  final bool isLiked;
  final bool isFeatured;
}

final class CommentPage {
  const CommentPage({
    required this.items,
    required this.hasMore,
    required this.hasLess,
    this.nextOffset,
    this.previousOffset,
    this.total,
  });

  final List<Comment> items;
  final bool hasMore;
  final bool hasLess;
  final int? nextOffset;
  final int? previousOffset;
  final int? total;
}

final class FavouriteResult {
  const FavouriteResult({required this.isFavourite, required this.total});

  final bool isFavourite;
  final int total;
}

/// Categories selected when watching a user.
final class WatchOptions {
  const WatchOptions({
    this.friend = true,
    this.deviations = true,
    this.journals = true,
    this.forumThreads = true,
    this.critiques = true,
    this.scraps = true,
    this.activity = true,
    this.collections = true,
  });

  final bool friend;
  final bool deviations;
  final bool journals;
  final bool forumThreads;
  final bool critiques;
  final bool scraps;
  final bool activity;
  final bool collections;
}

enum FolderKind { gallery, collection }

/// A gallery or collection folder, optionally including provider-preloaded art.
final class ArtworkFolder {
  const ArtworkFolder({
    required this.id,
    required this.kind,
    required this.name,
    required this.description,
    required this.preloadedArtworks,
    this.parentId,
    this.size,
    this.thumbnail,
    this.hasSubfolders = false,
  });

  final String id;
  final FolderKind kind;
  final String name;
  final String description;
  final String? parentId;
  final int? size;
  final Artwork? thumbnail;
  final List<Artwork> preloadedArtworks;
  final bool hasSubfolders;
}

/// Optional work requested from gallery and collection folder endpoints.
final class FolderQueryOptions {
  const FolderQueryOptions({
    this.calculateSize = false,
    this.preloadArtworks = false,
    this.filterEmpty = false,
  });

  final bool calculateSize;
  final bool preloadArtworks;
  final bool filterEmpty;
}
