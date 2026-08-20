enum MediaKind {
  image,
  video,
  animation,
  archive,
  document,
  literature,
  unknown,
}

enum MediaRole { preview, original, attachment }

enum MediaAvailability {
  available,
  loginRequired,
  purchaseRequired,
  restricted,
  missing,
}

final class MediaAsset {
  const MediaAsset({
    required this.id,
    required this.kind,
    required this.role,
    required this.availability,
    this.uri,
    this.mimeType,
    this.filename,
    this.byteLength,
    this.width,
    this.height,
    this.duration,
  });

  final String id;
  final MediaKind kind;
  final MediaRole role;
  final MediaAvailability availability;
  final Uri? uri;
  final String? mimeType;
  final String? filename;
  final int? byteLength;
  final int? width;
  final int? height;
  final Duration? duration;

  bool get canTransfer =>
      availability == MediaAvailability.available && uri != null;
}
