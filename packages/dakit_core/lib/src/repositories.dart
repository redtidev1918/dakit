import 'media.dart';
import 'models.dart';
import 'pagination.dart';

abstract interface class AccountRepository {
  Future<UserProfile> currentUser();
}

abstract interface class UserRepository {
  Future<UserProfileDetails> profile(String username);

  Future<Page<UserRelationship>> friends(String username, PageRequest request);

  Future<Page<UserRelationship>> watchers(String username, PageRequest request);

  Future<bool> isWatching(String username);

  Future<List<UserProfile>> searchFriends(String query, {String? username});
}

abstract interface class UserLookupRepository {
  Future<List<UserProfile>> lookup(Iterable<String> usernames);
}

abstract interface class ArtworkRepository {
  Future<Artwork> getById(String id);

  Future<Page<Artwork>> browse(PageRequest request);

  Future<Page<Artwork>> search(String query, PageRequest request);
}

abstract interface class ArtworkContentRepository {
  /// Fetches rendered literature/journal content independently from metadata.
  ///
  /// Editing markup is only available when the authenticated user owns the
  /// artwork and [forEditing] is true.
  Future<ArtworkContent> get(String artworkId, {bool forEditing = false});
}

abstract interface class GalleryRepository {
  Future<Page<Artwork>> gallery(String username, PageRequest request);

  Future<Page<Artwork>> favourites(String username, PageRequest request);
}

/// Read-only feeds used by home, discovery, and tag screens.
abstract interface class DiscoveryRepository {
  Future<List<Artwork>> dailyDeviations({DateTime? date});

  Future<Page<Artwork>> watched(PageRequest request);

  Future<Page<Artwork>> tag(String tag, PageRequest request);

  Future<List<String>> suggestTags(String partialTag);

  Future<Page<ArtworkTopic>> topics(PageRequest request);

  Future<List<ArtworkTopic>> topTopics();

  Future<Page<Artwork>> topic(String canonicalName, PageRequest request);
}

abstract interface class FolderRepository {
  Future<Page<ArtworkFolder>> galleryFolders({
    String? username,
    PageRequest request = const PageRequest(),
    FolderQueryOptions options = const FolderQueryOptions(),
  });

  Future<Page<ArtworkFolder>> collectionFolders({
    String? username,
    PageRequest request = const PageRequest(),
    FolderQueryOptions options = const FolderQueryOptions(),
  });

  Future<Page<Artwork>> galleryContents(
    String folderId, {
    String? username,
    PageRequest request = const PageRequest(),
  });

  Future<Page<Artwork>> collectionContents(
    String folderId, {
    String? username,
    PageRequest request = const PageRequest(),
  });
}

/// Resolves transferable media separately from artwork metadata.
///
/// Providers commonly protect original files behind a dedicated endpoint. This
/// contract keeps that provider-specific lookup out of download engines and UI
/// code.
abstract interface class MediaRepository {
  Future<MediaAsset> originalFile(String artworkId);
}

abstract interface class CommentRepository {
  Future<CommentPage> forArtwork(
    String artworkId, {
    CommentPageRequest request = const CommentPageRequest(),
  });

  Future<Comment> postToArtwork(
    String artworkId,
    String body, {
    String? parentCommentId,
  });
}

abstract interface class SocialRepository {
  Future<FavouriteResult> favourite(
    String artworkId, {
    List<String> collectionFolderIds = const <String>[],
  });

  Future<FavouriteResult> unfavourite(
    String artworkId, {
    List<String> collectionFolderIds = const <String>[],
  });

  Future<void> watch(
    String username, {
    WatchOptions options = const WatchOptions(),
  });

  Future<void> unwatch(String username);
}
