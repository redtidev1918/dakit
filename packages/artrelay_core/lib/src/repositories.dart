import 'media.dart';
import 'models.dart';
import 'pagination.dart';

abstract interface class AccountRepository {
  Future<UserProfile> currentUser();
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

/// Resolves transferable media separately from artwork metadata.
///
/// Providers commonly protect original files behind a dedicated endpoint. This
/// contract keeps that provider-specific lookup out of download engines and UI
/// code.
abstract interface class MediaRepository {
  Future<MediaAsset> originalFile(String artworkId);
}
