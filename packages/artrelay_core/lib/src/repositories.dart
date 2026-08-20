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

abstract interface class GalleryRepository {
  Future<Page<Artwork>> gallery(String username, PageRequest request);

  Future<Page<Artwork>> favourites(String username, PageRequest request);
}
