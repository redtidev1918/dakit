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
  });

  final String id;
  final String title;
  final UserProfile author;
  final Uri pageUri;
  final List<MediaAsset> media;
  final String? description;
  final DateTime? publishedAt;
  final bool isMature;
  final bool isDownloadable;
}
