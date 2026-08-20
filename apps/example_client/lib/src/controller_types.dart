import 'package:dakit_flutter/dakit_flutter.dart';

typedef LoadArtwork = Future<Artwork> Function(String id);
typedef ResolveOriginal = Future<MediaAsset> Function(String artworkId);
