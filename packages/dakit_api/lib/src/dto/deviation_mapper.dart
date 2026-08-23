import 'package:dakit_core/dakit_core.dart';

final class DeviationMapper {
  const DeviationMapper();

  Artwork artwork(Map<String, Object?> json) {
    final id = _requiredString(json, 'deviationid');
    final title = _requiredString(json, 'title');
    final pageUri = _requiredWebUri(json, 'url');
    final authorJson = _requiredMap(json, 'author');
    final author = user(authorJson);
    final downloadAvailability = _downloadAvailability(json);
    final media = <MediaAsset>[];
    final seen = <Uri>{};

    void addImage(
      String field, {
      MediaAvailability availability = MediaAvailability.available,
    }) {
      final value = _map(json[field]);
      if (value == null) return;
      final uri = _webUri(value['src']);
      if (uri == null || !seen.add(uri)) return;
      media.add(
        MediaAsset(
          id: '$id:$field',
          kind: MediaKind.image,
          role: MediaRole.preview,
          availability: availability,
          uri: uri,
          byteLength: _integer(value['filesize']),
          width: _integer(value['width']),
          height: _integer(value['height']),
        ),
      );
    }

    // The full-size `content` image follows the download availability (premium/
    // paid content is gated); `preview`/`social_preview` thumbnails stay
    // available so hosts can still render a low-res preview.
    addImage('content', availability: downloadAvailability);
    addImage('preview');
    addImage('social_preview');

    // Literature/journal deviations carry their embedded images in `thumbs`
    // (a list of sized thumbnails) rather than `content`/`preview`.
    final thumbs = _list(json['thumbs']);
    for (var index = 0; index < thumbs.length; index += 1) {
      final thumb = _map(thumbs[index]);
      if (thumb == null) continue;
      final uri = _webUri(thumb['src']);
      if (uri == null || !seen.add(uri)) continue;
      media.add(
        MediaAsset(
          id: '$id:thumb:$index',
          kind: MediaKind.image,
          role: MediaRole.preview,
          availability: MediaAvailability.available,
          uri: uri,
          width: _integer(thumb['width']),
          height: _integer(thumb['height']),
        ),
      );
    }

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
          _string(json['excerpt']) ?? _string(json['formatted_excerpt']),
      publishedAt: _dateTime(json['published_time']),
      isMature: json['is_mature'] == true,
      isDownloadable: json['is_downloadable'] == true,
      isFavourited: json['is_favourited'] == true,
      isMultiMedia: json['is_multi_media'] == true,
      downloadAvailability: downloadAvailability,
      textContent: _textContent(json),
      tags: _tags(json),
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

  UserProfileDetails profile(Map<String, Object?> json) {
    final stats = _requiredMap(json, 'stats');
    return UserProfileDetails(
      user: user(_requiredMap(json, 'user')),
      isWatching: _requiredBoolean(json, 'is_watching'),
      profileUri: _requiredWebUri(json, 'profile_url'),
      isArtist: _requiredBoolean(json, 'user_is_artist'),
      stats: UserProfileStats(
        deviations: _requiredInteger(stats, 'user_deviations'),
        favourites: _requiredInteger(stats, 'user_favourites'),
        comments: _requiredInteger(stats, 'user_comments'),
        pageViews: _requiredInteger(stats, 'profile_pageviews'),
        profileComments: _requiredInteger(stats, 'profile_comments'),
      ),
      artistLevel: _nullableRequiredText(json, 'artist_level'),
      artistSpecialty: _nullableRequiredText(json, 'artist_specialty'),
      realName: _emptyToNull(_requiredText(json, 'real_name')),
      tagline: _emptyToNull(_requiredText(json, 'tagline')),
      country: _emptyToNull(_requiredText(json, 'country')),
      website: _emptyToNull(_requiredText(json, 'website')),
      bio: _emptyToNull(_requiredText(json, 'bio')),
      coverPhotoUri: _nullableRequiredWebUri(json, 'cover_photo'),
    );
  }

  UserRelationship relationship(Map<String, Object?> json) {
    final watch = _requiredMap(json, 'watch');
    if (!json.containsKey('lastvisit')) throw _missing('lastvisit');
    final rawLastVisit = json['lastvisit'];
    final lastVisit = _dateTime(rawLastVisit);
    if (rawLastVisit != null && lastVisit == null) throw _missing('lastvisit');
    final rawWatchesYou = json['watches_you'];
    if (rawWatchesYou != null && rawWatchesYou is! bool) {
      throw _missing('watches_you');
    }
    return UserRelationship(
      user: user(_requiredMap(json, 'user')),
      isWatching: _requiredBoolean(json, 'is_watching'),
      watchesYou: rawWatchesYou as bool?,
      lastVisitedAt: lastVisit,
      watchOptions: WatchOptions(
        friend: _requiredBoolean(watch, 'friend'),
        deviations: _requiredBoolean(watch, 'deviations'),
        journals: _requiredBoolean(watch, 'journals'),
        forumThreads: _requiredBoolean(watch, 'forum_threads'),
        critiques: _requiredBoolean(watch, 'critiques'),
        scraps: _requiredBoolean(watch, 'scraps'),
        activity: _requiredBoolean(watch, 'activity'),
        collections: _requiredBoolean(watch, 'collections'),
      ),
    );
  }

  ArtworkFolder folder(Map<String, Object?> json, FolderKind kind) {
    final rawThumbnail = _nullableRequiredMap(json, 'thumb');
    final rawPreloaded = json['deviations'];
    if (rawPreloaded != null && rawPreloaded is! List) {
      throw _missing('deviations');
    }
    final preloaded = <Artwork>[];
    for (final value
        in rawPreloaded is List ? rawPreloaded : const <Object?>[]) {
      final item = _map(value);
      if (item == null) throw _missing('deviations.item');
      preloaded.add(artwork(item));
    }
    final rawSize = json['size'];
    final size = _integer(rawSize);
    if (rawSize != null && size == null) throw _missing('size');
    final rawHasSubfolders = json['has_subfolders'];
    if (rawHasSubfolders != null && rawHasSubfolders is! bool) {
      throw _missing('has_subfolders');
    }
    return ArtworkFolder(
      id: _requiredString(json, 'folderid'),
      kind: kind,
      name: _requiredText(json, 'name'),
      description: _requiredText(json, 'description'),
      parentId: kind == FolderKind.gallery
          ? _nullableRequiredText(json, 'parent')
          : null,
      size: size,
      thumbnail: rawThumbnail == null ? null : artwork(rawThumbnail),
      preloadedArtworks: List<Artwork>.unmodifiable(preloaded),
      hasSubfolders: rawHasSubfolders == true,
    );
  }

  ArtworkTopic topic(Map<String, Object?> json) {
    final examples = <Artwork>[];
    final seen = <String>{};

    void addExample(Object? value) {
      final item = _map(value);
      if (item == null) throw _missing('example_deviations.item');
      final mapped = artwork(item);
      if (seen.add(mapped.id)) examples.add(mapped);
    }

    final rawExamples = json['example_deviations'];
    if (rawExamples is List) {
      for (final value in rawExamples) {
        addExample(value);
      }
    } else if (rawExamples != null) {
      addExample(rawExamples);
    }
    final rawDeviations = json['deviations'];
    if (rawDeviations is List) {
      for (final value in rawDeviations) {
        addExample(value);
      }
    } else if (rawDeviations != null) {
      throw _missing('deviations');
    }
    return ArtworkTopic(
      name: _requiredString(json, 'name'),
      canonicalName: _requiredString(json, 'canonical_name'),
      exampleArtworks: List<Artwork>.unmodifiable(examples),
    );
  }

  /// Maps a `gallection` object from the "More Like This" preview endpoint:
  /// a numeric collection/folder id, its display name, its owner, and — when
  /// the provider supplies one — a preview image (cover) for the collection.
  CollectionSummary collectionSummary(Map<String, Object?> json) {
    return CollectionSummary(
      folderId: _requiredInteger(json, 'folderid'),
      name: _requiredText(json, 'name'),
      owner: user(_requiredMap(json, 'owner')),
      coverUri: _collectionCoverUri(json),
    );
  }

  /// The first usable image from a collection's `thumb` deviation or a bare
  /// `preview`/`cover` image object. Returns `null` when the provider gave no
  /// cover, so hosts render a placeholder instead of a broken image.
  Uri? _collectionCoverUri(Map<String, Object?> json) {
    final candidates = <Map<String, Object?>?>[
      _map(json['thumb']),
      _map(json['preview']),
      _map(json['cover']),
    ];
    for (final candidate in candidates) {
      if (candidate == null) continue;
      final uri = _firstImageUri(candidate);
      if (uri != null) return uri;
    }
    return null;
  }

  Uri? _firstImageUri(Map<String, Object?> json) {
    for (final field in <String>['preview', 'content', 'social_preview']) {
      final image = _map(json[field]);
      final uri = image == null ? null : _webUri(image['src']);
      if (uri != null) return uri;
    }
    final thumbs = _list(json['thumbs']);
    for (final thumb in thumbs) {
      final image = _map(thumb);
      final uri = image == null ? null : _webUri(image['src']);
      if (uri != null) return uri;
    }
    return null;
  }

  ProviderMessage message(Map<String, Object?> json) {
    final subject = _map(json['subject']);

    T? optionalObject<T>(
      Object? value,
      T Function(Map<String, Object?> item) parse,
      String field,
    ) {
      if (value == null) return null;
      final mapped = _map(value);
      if (mapped == null) throw _missing(field);
      return parse(mapped);
    }

    final rawPosted = json['ts'];
    final posted = _dateTime(rawPosted);
    if (rawPosted != null && posted == null) throw _missing('ts');
    final rawStackCount = json['stack_count'];
    final stackCount = _integer(rawStackCount);
    if (rawStackCount != null && stackCount == null) {
      throw _missing('stack_count');
    }
    return ProviderMessage(
      id: _requiredString(json, 'messageid'),
      type: _requiredString(json, 'type'),
      isOrphaned: _requiredBoolean(json, 'orphaned'),
      isNew: _requiredBoolean(json, 'is_new'),
      postedAt: posted,
      stackId: _emptyToNull(_string(json['stackid']) ?? ''),
      stackCount: stackCount,
      originator: optionalObject(json['originator'], user, 'originator'),
      html: _string(json['html']),
      profile: optionalObject(
        subject?['profile'] ?? json['profile'],
        user,
        'profile',
      ),
      artwork: optionalObject(
        subject?['deviation'] ?? json['deviation'],
        artwork,
        'deviation',
      ),
      comment: optionalObject(
        subject?['comment'] ?? json['comment'],
        comment,
        'comment',
      ),
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

  Comment comment(Map<String, Object?> json) {
    final rawBody = json['body'];
    if (rawBody is! String) throw _missing('body');
    return Comment(
      id: _requiredString(json, 'commentid'),
      parentId: _string(json['parentid']),
      postedAt: _requiredDateTime(json, 'posted'),
      body: rawBody,
      author: user(_requiredMap(json, 'user')),
      replyCount: _requiredInteger(json, 'replies'),
      likeCount: _requiredInteger(json, 'likes'),
      hiddenReason: _string(json['hidden']),
      isLiked: _requiredBoolean(json, 'is_liked'),
      isFeatured: _requiredBoolean(json, 'is_featured'),
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

  static List<String> _tags(Map<String, Object?> json) {
    final rawTags = json['tags'];
    if (rawTags is! List) return const <String>[];
    final tags = <String>[];
    for (final value in rawTags) {
      if (value is! Map) continue;
      final name = _string(value['tag_name']) ?? _string(value['name']);
      if (name != null && name.isNotEmpty) tags.add(name);
    }
    return List<String>.unmodifiable(tags);
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

String _requiredText(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) throw _missing(key);
  return value.trim();
}

String? _nullableRequiredText(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) throw _missing(key);
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw _missing(key);
  return _emptyToNull(value.trim());
}

Map<String, Object?>? _nullableRequiredMap(
  Map<String, Object?> json,
  String key,
) {
  if (!json.containsKey(key)) throw _missing(key);
  final value = json[key];
  if (value == null) return null;
  final mapped = _map(value);
  if (mapped == null) throw _missing(key);
  return mapped;
}

Uri? _nullableRequiredWebUri(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) throw _missing(key);
  final value = json[key];
  if (value == null) return null;
  final text = value is String ? value.trim() : null;
  if (text != null && text.isEmpty) return null;
  final uri = _webUri(value);
  if (uri == null) throw _missing(key);
  return uri;
}

Uri _requiredWebUri(Map<String, Object?> json, String key) {
  final value = _webUri(json[key]);
  if (value == null) throw _missing(key);
  return value;
}

int _requiredInteger(Map<String, Object?> json, String key) {
  final value = _integer(json[key]);
  if (value == null) throw _missing(key);
  return value;
}

bool _requiredBoolean(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw _missing(key);
  return value;
}

DateTime _requiredDateTime(Map<String, Object?> json, String key) {
  final value = _dateTime(json[key]);
  if (value == null) throw _missing(key);
  return value;
}

DAKitException _missing(String key) => DAKitException(
  kind: DAKitFailureKind.parsing,
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

String? _emptyToNull(String value) => value.isEmpty ? null : value;

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
