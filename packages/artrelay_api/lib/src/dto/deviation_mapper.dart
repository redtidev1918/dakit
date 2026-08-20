import 'package:artrelay_core/artrelay_core.dart';

final class DeviationMapper {
  const DeviationMapper();

  Artwork artwork(Map<String, Object?> json) {
    final id = _requiredString(json, 'deviationid');
    final title = _requiredString(json, 'title');
    final pageUri = _requiredWebUri(json, 'url');
    final authorJson = _requiredMap(json, 'author');
    final author = user(authorJson);
    final media = <MediaAsset>[];
    final seen = <Uri>{};

    void addImage(String field) {
      final value = _map(json[field]);
      if (value == null) return;
      final uri = _webUri(value['src']);
      if (uri == null || !seen.add(uri)) return;
      media.add(
        MediaAsset(
          id: '$id:$field',
          kind: MediaKind.image,
          role: MediaRole.preview,
          availability: MediaAvailability.available,
          uri: uri,
          byteLength: _integer(value['filesize']),
          width: _integer(value['width']),
          height: _integer(value['height']),
        ),
      );
    }

    addImage('content');
    addImage('preview');
    addImage('social_preview');

    final videos = _list(json['videos']);
    for (var index = 0; index < videos.length; index += 1) {
      final video = _map(videos[index]);
      if (video == null) continue;
      final uri = _webUri(video['src']);
      if (uri == null || !seen.add(uri)) continue;
      final duration = _integer(video['duration']);
      media.add(
        MediaAsset(
          id: '$id:video:$index',
          kind: MediaKind.video,
          role: MediaRole.preview,
          availability: MediaAvailability.available,
          uri: uri,
          filename: _string(video['quality']),
          byteLength: _integer(video['filesize']),
          duration: duration == null ? null : Duration(seconds: duration),
        ),
      );
    }

    final flash = _map(json['flash']);
    if (flash != null) {
      final uri = _webUri(flash['src']);
      if (uri != null && seen.add(uri)) {
        media.add(
          MediaAsset(
            id: '$id:animation',
            kind: MediaKind.animation,
            role: MediaRole.preview,
            availability: MediaAvailability.available,
            uri: uri,
            width: _integer(flash['width']),
            height: _integer(flash['height']),
          ),
        );
      }
    }

    return Artwork(
      id: id,
      title: title,
      author: author,
      pageUri: pageUri,
      media: List<MediaAsset>.unmodifiable(media),
      description:
          _string(json['excerpt']) ?? _string(json['formatted_exerpt']),
      publishedAt: _dateTime(json['published_time']),
      isMature: json['is_mature'] == true,
      isDownloadable: json['is_downloadable'] == true,
      downloadAvailability: _downloadAvailability(json),
      textContent: _textContent(json),
    );
  }

  UserProfile user(Map<String, Object?> json) {
    final id = _requiredString(json, 'userid');
    final username = _requiredString(json, 'username');
    return UserProfile(
      id: id,
      username: username,
      displayName: _string(json['real_name']) ?? username,
      avatarUri: _webUri(json['usericon']),
      profileUri: Uri.https('www.deviantart.com', '/$username'),
    );
  }

  MediaAsset original(Map<String, Object?> json, String artworkId) {
    final uri = _requiredWebUri(json, 'src');
    final filename = _requiredString(json, 'filename');
    return MediaAsset(
      id: '$artworkId:original',
      kind: _kindFromFilename(filename),
      role: MediaRole.original,
      availability: MediaAvailability.available,
      uri: uri,
      filename: filename,
      byteLength: _integer(json['filesize']),
      width: _integer(json['width']),
      height: _integer(json['height']),
    );
  }

  ArtworkContent content(Map<String, Object?> json, String artworkId) {
    return ArtworkContent(
      artworkId: artworkId,
      html: _string(json['html']),
      css: _string(json['css']),
      cssFonts: List<String>.unmodifiable(
        _list(json['css_fonts']).whereType<String>(),
      ),
      originalMarkup: _string(json['original_markup']),
    );
  }

  static ArtworkTextContent? _textContent(Map<String, Object?> json) {
    final text = _map(json['text_content']);
    if (text == null) return null;
    final body = _map(text['body']);
    final excerpt = _string(text['excerpt']) ?? '';
    final format = _string(body?['type']);
    final markup = _string(body?['markup']);
    final features = _string(body?['features']);
    if (excerpt.isEmpty &&
        format == null &&
        markup == null &&
        features == null) {
      return null;
    }
    return ArtworkTextContent(
      excerpt: excerpt,
      format: format,
      markup: markup,
      features: features,
    );
  }

  static MediaAvailability _downloadAvailability(Map<String, Object?> json) {
    if (json['is_deleted'] == true) return MediaAvailability.missing;
    if (json['is_blocked'] == true) return MediaAvailability.restricted;
    final premium = _map(json['premium_folder_data']);
    if (premium != null && premium['has_access'] == false) {
      return MediaAvailability.purchaseRequired;
    }
    final tierAccess = _string(json['tier_access']);
    if (tierAccess == 'locked' || tierAccess == 'locked-subscribed') {
      return MediaAvailability.purchaseRequired;
    }
    if (json['is_downloadable'] == true) return MediaAvailability.available;
    return MediaAvailability.unavailable;
  }

  static MediaKind _kindFromFilename(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' || 'avif' => MediaKind.image,
      'mp4' || 'webm' || 'mov' => MediaKind.video,
      'swf' => MediaKind.animation,
      'zip' || 'rar' || '7z' || 'tar' || 'gz' => MediaKind.archive,
      'pdf' || 'epub' => MediaKind.document,
      'txt' || 'md' || 'rtf' => MediaKind.literature,
      _ => MediaKind.unknown,
    };
  }
}

Map<String, Object?> _requiredMap(Map<String, Object?> json, String key) {
  final value = _map(json[key]);
  if (value == null) throw _missing(key);
  return value;
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = _string(json[key]);
  if (value == null || value.isEmpty) throw _missing(key);
  return value;
}

Uri _requiredWebUri(Map<String, Object?> json, String key) {
  final value = _webUri(json[key]);
  if (value == null) throw _missing(key);
  return value;
}

ArtRelayException _missing(String key) => ArtRelayException(
  kind: ArtRelayFailureKind.parsing,
  code: 'api.dto.missing_field',
  message: 'The official API response is missing a required field.',
  details: <String, Object?>{'field': key},
);

Map<String, Object?>? _map(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return null;
}

List<Object?> _list(Object? value) => value is List ? value : const <Object?>[];

String? _string(Object? value) => value is String ? value.trim() : null;

int? _integer(Object? value) => switch (value) {
  int number => number,
  num number => number.toInt(),
  String text => int.tryParse(text),
  _ => null,
};

Uri? _webUri(Object? value) {
  final text = _string(value);
  final uri = text == null ? null : Uri.tryParse(text);
  if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
    return null;
  }
  return uri;
}

DateTime? _dateTime(Object? value) {
  if (value is num) {
    final milliseconds = value.abs() < 100000000000
        ? value.toInt() * 1000
        : value.toInt();
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  }
  final text = _string(value);
  if (text == null) return null;
  final numeric = int.tryParse(text);
  if (numeric != null) return _dateTime(numeric);
  return DateTime.tryParse(text)?.toUtc();
}
