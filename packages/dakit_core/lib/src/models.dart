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

/// Relationship data attached to a friend or watcher list entry.
final class UserRelationship {
  const UserRelationship({
    required this.user,
    required this.isWatching,
    required this.watchOptions,
    this.watchesYou,
    this.lastVisitedAt,
  });

  final UserProfile user;
  final bool isWatching;
  final bool? watchesYou;
  final DateTime? lastVisitedAt;
  final WatchOptions watchOptions;
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
    this.isFavourited = false,
    this.isMultiMedia = false,
    MediaAvailability? downloadAvailability,
    this.textContent,
    this.tags = const <String>[],
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

  /// A short description of the artwork, if the provider returned one.
  ///
  /// DeviantArt's official API no longer populates this field, so it is
  /// usually `null`. To read the author's full description, use
  /// `ArtworkContentRepository.get()` and render `ArtworkContent.html`
  /// (the `deviation/content` endpoint).
  final String? description;
  final DateTime? publishedAt;
  final bool isMature;
  final bool isDownloadable;

  /// Whether the signed-in user has favourited this artwork.
  final bool isFavourited;

  /// Whether this deviation is a multi-image gallery (has additional pages).
  final bool isMultiMedia;
  final MediaAvailability downloadAvailability;

  /// Structured text embedded in a deviation response, if any.
  ///
  /// DeviantArt's official API no longer populates this field, so it is
  /// usually `null`. Prefer `ArtworkContentRepository.get()` for artwork text.
  final ArtworkTextContent? textContent;

  /// Searchable tag names attached to the artwork (e.g. `["belly", "comic"]`).
  final List<String> tags;

  /// Returns a copy of this artwork with the given fields replaced.
  Artwork copyWith({
    String? id,
    String? title,
    UserProfile? author,
    Uri? pageUri,
    List<MediaAsset>? media,
    String? description,
    DateTime? publishedAt,
    bool? isMature,
    bool? isDownloadable,
    bool? isFavourited,
    bool? isMultiMedia,
    MediaAvailability? downloadAvailability,
    ArtworkTextContent? textContent,
    List<String>? tags,
  }) {
    return Artwork(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      pageUri: pageUri ?? this.pageUri,
      media: media ?? this.media,
      description: description ?? this.description,
      publishedAt: publishedAt ?? this.publishedAt,
      isMature: isMature ?? this.isMature,
      isDownloadable: isDownloadable ?? this.isDownloadable,
      isFavourited: isFavourited ?? this.isFavourited,
      isMultiMedia: isMultiMedia ?? this.isMultiMedia,
      downloadAvailability: downloadAvailability ?? this.downloadAvailability,
      textContent: textContent ?? this.textContent,
      tags: tags ?? this.tags,
    );
  }
}

/// Structured text embedded in a deviation response.
///
/// [markup] is provider-authored data and must be rendered or sanitized by the
/// host application according to its own trust boundary.
///
/// DeviantArt's official API no longer returns these values; hosts that need
/// artwork text should fetch `ArtworkContent` instead.
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

/// A provider-curated discovery topic and its optional example artworks.
final class ArtworkTopic {
  const ArtworkTopic({
    required this.name,
    required this.canonicalName,
    required this.exampleArtworks,
  });

  final String name;
  final String canonicalName;
  final List<Artwork> exampleArtworks;
}

/// A notification or feedback item from the provider message center.
///
/// [html] is provider-authored markup. Hosts must sanitize it before rendering.
final class ProviderMessage {
  const ProviderMessage({
    required this.id,
    required this.type,
    required this.isOrphaned,
    required this.isNew,
    this.postedAt,
    this.stackId,
    this.stackCount,
    this.originator,
    this.html,
    this.profile,
    this.artwork,
    this.comment,
  });

  final String id;
  final String type;
  final bool isOrphaned;
  final bool isNew;
  final DateTime? postedAt;
  final String? stackId;
  final int? stackCount;
  final UserProfile? originator;
  final String? html;
  final UserProfile? profile;
  final Artwork? artwork;
  final Comment? comment;
}

enum FeedbackType { comments, replies, activity }
