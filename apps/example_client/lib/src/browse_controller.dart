import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/foundation.dart';

import 'controller_types.dart';

final class BrowseController extends ChangeNotifier {
  BrowseController({this.loadHome, this.loadArtwork, this.resolveOriginal});

  final Future<Page<Artwork>> Function()? loadHome;
  final LoadArtwork? loadArtwork;
  final ResolveOriginal? resolveOriginal;

  List<Artwork> artworks = const <Artwork>[];
  Artwork? selectedArtwork;
  MediaAsset? selectedOriginal;
  DAKitException? artworkFailure;
  bool loadingArtwork = false;
  int _detailGeneration = 0;

  Future<void> refresh() async {
    final loader = loadHome;
    if (loader == null) return;
    artworks = List<Artwork>.unmodifiable((await loader()).items);
    notifyListeners();
  }

  Future<void> clear() async {
    _detailGeneration += 1;
    artworks = const <Artwork>[];
    selectedArtwork = null;
    selectedOriginal = null;
    artworkFailure = null;
    loadingArtwork = false;
    notifyListeners();
  }

  Future<void> openArtwork(String id) async {
    final artworkLoader = loadArtwork;
    final originalResolver = resolveOriginal;
    if (artworkLoader == null || originalResolver == null) return;
    final generation = ++_detailGeneration;
    selectedArtwork = artworks.where((item) => item.id == id).firstOrNull;
    selectedOriginal = null;
    artworkFailure = null;
    loadingArtwork = true;
    notifyListeners();
    try {
      final detail = await artworkLoader(id);
      if (generation != _detailGeneration) return;
      selectedArtwork = detail;
      if (detail.downloadAvailability == MediaAvailability.available) {
        final resolved = await originalResolver(detail.id);
        if (generation != _detailGeneration) return;
        selectedOriginal = resolved;
      }
    } on DAKitException catch (error) {
      if (generation == _detailGeneration) artworkFailure = error;
    } on Object catch (error) {
      if (generation == _detailGeneration) artworkFailure = _unexpected(error);
    } finally {
      if (generation == _detailGeneration) {
        loadingArtwork = false;
        notifyListeners();
      }
    }
  }

  void closeArtwork() {
    _detailGeneration += 1;
    selectedArtwork = null;
    selectedOriginal = null;
    artworkFailure = null;
    loadingArtwork = false;
    notifyListeners();
  }

  static DAKitException _unexpected(Object error) => DAKitException(
    kind: DAKitFailureKind.upstream,
    code: 'example.unexpected',
    message: 'The example client encountered an unexpected failure.',
    cause: error,
  );
}
