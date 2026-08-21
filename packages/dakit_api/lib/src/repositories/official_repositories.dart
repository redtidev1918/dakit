import 'package:dakit_core/dakit_core.dart';

import '../dto/deviation_mapper.dart';
import '../http/official_api_client.dart';

final class OfficialAccountRepository implements AccountRepository {
  const OfficialAccountRepository(this._transport);

  final OfficialApiTransport _transport;
  final DeviationMapper _mapper = const DeviationMapper();

  @override
  Future<UserProfile> currentUser() async {
    final json = await _transport.getJson(
      'user/whoami',
      query: const <String, Object?>{'with_session': false},
    );
    return _mapper.user(json);
  }
}

final class OfficialUserRepository implements UserRepository {
  const OfficialUserRepository(this._transport);

  final OfficialApiTransport _transport;
  final DeviationMapper _mapper = const DeviationMapper();

  @override
  Future<UserProfileDetails> profile(String username) async {
    _validateIdentifier(username, 'username');
    final json = await _transport.getJson(
      'user/profile/${Uri.encodeComponent(username.trim())}',
      query: const <String, Object?>{
        'ext_collections': false,
        'ext_galleries': false,
        'with_session': false,
        'expand': 'user.details,user.geo,user.stats',
      },
    );
    return _mapper.profile(json);
  }

  @override
  Future<Page<UserRelationship>> friends(
    String username,
    PageRequest request,
  ) => _relationships('user/friends', username, request);

  @override
  Future<Page<UserRelationship>> watchers(
    String username,
    PageRequest request,
  ) => _relationships('user/watchers', username, request);

  Future<Page<UserRelationship>> _relationships(
    String path,
    String username,
    PageRequest request,
  ) async {
    _validateIdentifier(username, 'username');
    _validatePageRequest(request);
    final json = await _transport.getJson(
      '$path/${Uri.encodeComponent(username.trim())}',
      query: <String, Object?>{
        'offset': _offset(request.cursor),
        'limit': request.limit,
        'expand': 'user.details,user.geo,user.profile,user.stats',
      },
    );
    return _parsePage(json, _mapper.relationship);
  }

  @override
  Future<bool> isWatching(String username) async {
    _validateIdentifier(username, 'username');
    final json = await _transport.getJson(
      'user/friends/watching/${Uri.encodeComponent(username.trim())}',
    );
    return _requiredResponseBoolean(json, 'watching');
  }

  @override
  Future<List<UserProfile>> searchFriends(
    String query, {
    String? username,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'api.user.search.empty',
        message: 'A user search query must not be empty.',
      );
    }
    final normalizedUsername = username?.trim();
    if (normalizedUsername != null && normalizedUsername.isEmpty) {
      _validateIdentifier('', 'username');
    }
    final json = await _transport.getJson(
      'user/friends/search',
      query: <String, Object?>{
        'username': ?normalizedUsername,
        'query': normalizedQuery,
      },
    );
    final rawResults = json['results'];
    if (rawResults is! List) throw _missingField('results');
    return List<UserProfile>.unmodifiable(
      rawResults.map((item) => _mapper.user(_requiredItemMap(item))),
    );
  }
}

final class OfficialUserLookupRepository implements UserLookupRepository {
  const OfficialUserLookupRepository(this._transport);

  final OfficialApiMutationTransport _transport;
  final DeviationMapper _mapper = const DeviationMapper();

  @override
  Future<List<UserProfile>> lookup(Iterable<String> usernames) async {
    final normalized = <String>[];
    final seen = <String>{};
    for (final username in usernames) {
      final value = username.trim();
      _validateIdentifier(value, 'username');
      if (seen.add(value.toLowerCase())) normalized.add(value);
    }
    if (normalized.isEmpty) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'api.user.lookup.empty',
        message: 'At least one username is required.',
      );
    }
    final json = await _transport.postFormJson(
      'user/whois',
      form: <String, Object?>{'usernames': normalized},
    );
    final rawResults = json['results'];
    if (rawResults is! List) throw _missingField('results');
    return List<UserProfile>.unmodifiable(
      rawResults.map((item) => _mapper.user(_requiredItemMap(item))),
    );
  }
}

final class OfficialArtworkRepository implements ArtworkRepository {
  const OfficialArtworkRepository(this._transport);

  final OfficialApiTransport _transport;
  final DeviationMapper _mapper = const DeviationMapper();

  @override
  Future<Artwork> getById(String id) async {
    _validateIdentifier(id, 'artwork id');
    final json = await _transport.getJson(
      'deviation/${Uri.encodeComponent(id)}',
      query: const <String, Object?>{
        'with_session': false,
        'expand': 'deviation.fulltext',
      },
    );
    return _mapper.artwork(json);
  }

  @override
  Future<Page<Artwork>> browse(PageRequest request) =>
      _page('browse/home', request);

  @override
  Future<Page<Artwork>> search(String query, PageRequest request) {
    if (query.trim().isEmpty) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'api.search.empty',
        message: 'A search query must not be empty.',
      );
    }
    return _page('browse/home', request, query: query.trim());
  }

  Future<Page<Artwork>> _page(
    String path,
    PageRequest request, {
    String? query,
  }) async {
    final offset = _offset(request.cursor);
    final json = await _transport.getJson(
      path,
      query: <String, Object?>{
        'offset': offset,
        'limit': request.limit,
        ...query == null
            ? const <String, Object?>{}
            : <String, Object?>{'q': query},
      },
    );
    return _artworkPage(json);
  }

  Page<Artwork> _artworkPage(Map<String, Object?> json) =>
      _parsePage(json, (item) => _mapper.artwork(item));
}

final class OfficialArtworkContentRepository
    implements ArtworkContentRepository {
  const OfficialArtworkContentRepository(this._transport);

  final OfficialApiTransport _transport;
  final DeviationMapper _mapper = const DeviationMapper();

  @override
  Future<ArtworkContent> get(
    String artworkId, {
    bool forEditing = false,
  }) async {
    _validateIdentifier(artworkId, 'artwork id');
    final json = await _transport.getJson(
      'deviation/content',
      query: <String, Object?>{
        'deviationid': artworkId,
        'for_edit': forEditing,
        'with_session': false,
      },
    );
    return _mapper.content(json, artworkId);
  }
}

final class OfficialGalleryRepository implements GalleryRepository {
  const OfficialGalleryRepository(this._transport);

  final OfficialApiTransport _transport;
  final DeviationMapper _mapper = const DeviationMapper();

  @override
  Future<Page<Artwork>> gallery(String username, PageRequest request) =>
      _fetch('gallery/all', username, request);

  @override
  Future<Page<Artwork>> favourites(String username, PageRequest request) =>
      _fetch('collections/all', username, request);

  Future<Page<Artwork>> _fetch(
    String path,
    String username,
    PageRequest request,
  ) async {
    _validateIdentifier(username, 'username');
    final json = await _transport.getJson(
      path,
      query: <String, Object?>{
        'username': username,
        'offset': _offset(request.cursor),
        'limit': request.limit.clamp(1, 24),
        'with_session': false,
      },
    );
    return _parsePage(json, _mapper.artwork);
  }
}

final class OfficialDiscoveryRepository implements DiscoveryRepository {
  const OfficialDiscoveryRepository(this._transport);

  final OfficialApiTransport _transport;
  final DeviationMapper _mapper = const DeviationMapper();

  @override
  Future<List<Artwork>> dailyDeviations({DateTime? date}) async {
    final json = await _transport.getJson(
      'browse/dailydeviations',
      query: <String, Object?>{
        if (date != null) 'date': _calendarDate(date),
        'with_session': false,
        'expand': 'user.watch',
      },
    );
    final rawResults = json['results'];
    if (rawResults is! List) throw _missingField('results');
    return List<Artwork>.unmodifiable(
      rawResults.map((item) => _mapper.artwork(_requiredItemMap(item))),
    );
  }

  @override
  Future<Page<Artwork>> watched(PageRequest request) async {
    _validatePageRequest(request);
    final json = await _transport.getJson(
      'browse/deviantsyouwatch',
      query: <String, Object?>{
        'limit': request.limit,
        'offset': _offset(request.cursor),
        'with_session': false,
      },
    );
    return _parsePage(json, _mapper.artwork);
  }

  @override
  Future<Page<Artwork>> tag(String tag, PageRequest request) async {
    final normalized = tag.trim();
    if (normalized.isEmpty) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'api.tag.empty',
        message: 'A tag must not be empty.',
      );
    }
    _validatePageRequest(request);
    final json = await _transport.getJson(
      'browse/tags',
      query: <String, Object?>{
        'tag': normalized,
        ..._hybridPageQuery(request.cursor),
        'limit': request.limit,
        'with_session': false,
        'expand': 'user.watch',
      },
    );
    return _parseHybridPage(json, _mapper.artwork);
  }

  @override
  Future<List<String>> suggestTags(String partialTag) async {
    final normalized = partialTag.trim();
    if (normalized.isEmpty) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'api.tag.empty',
        message: 'A partial tag must not be empty.',
      );
    }
    final json = await _transport.getJson(
      'browse/tags/search',
      query: <String, Object?>{'tag_name': normalized, 'with_session': false},
    );
    final rawResults = json['results'];
    if (rawResults is! List) throw _missingField('results');
    final suggestions = <String>[];
    for (final value in rawResults) {
      final item = _requiredItemMap(value);
      final tagName = item['tag_name'];
      if (tagName is! String || tagName.trim().isEmpty) {
        throw _missingField('tag_name');
      }
      suggestions.add(tagName.trim());
    }
    return List<String>.unmodifiable(suggestions);
  }

  @override
  Future<Page<ArtworkTopic>> topics(PageRequest request) async {
    _validatePageLimit(request, 10);
    final json = await _transport.getJson(
      'browse/topics',
      query: <String, Object?>{
        ..._hybridPageQuery(request.cursor),
        'limit': request.limit,
        'with_session': false,
      },
    );
    return _parseHybridPage(json, _mapper.topic);
  }

  @override
  Future<List<ArtworkTopic>> topTopics() async {
    final json = await _transport.getJson(
      'browse/toptopics',
      query: const <String, Object?>{'with_session': false},
    );
    final rawResults = json['results'];
    if (rawResults is! List) throw _missingField('results');
    return List<ArtworkTopic>.unmodifiable(
      rawResults.map((item) => _mapper.topic(_requiredItemMap(item))),
    );
  }

  @override
  Future<Page<Artwork>> topic(String canonicalName, PageRequest request) async {
    final normalized = canonicalName.trim();
    if (normalized.isEmpty) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'api.topic.empty',
        message: 'A topic name must not be empty.',
      );
    }
    _validatePageLimit(request, 24);
    final json = await _transport.getJson(
      'browse/topic',
      query: <String, Object?>{
        'topic': normalized,
        ..._hybridPageQuery(request.cursor),
        'limit': request.limit,
        'with_session': false,
        'expand': 'user.watch',
      },
    );
    return _parseHybridPage(json, _mapper.artwork);
  }
}

final class OfficialFolderRepository implements FolderRepository {
  const OfficialFolderRepository(this._transport);

  final OfficialApiTransport _transport;
  final DeviationMapper _mapper = const DeviationMapper();

  @override
  Future<Page<ArtworkFolder>> galleryFolders({
    String? username,
    PageRequest request = const PageRequest(),
    FolderQueryOptions options = const FolderQueryOptions(),
  }) => _folders(
    'gallery/folders',
    FolderKind.gallery,
    username,
    request,
    options,
  );

  @override
  Future<Page<ArtworkFolder>> collectionFolders({
    String? username,
    PageRequest request = const PageRequest(),
    FolderQueryOptions options = const FolderQueryOptions(),
  }) => _folders(
    'collections/folders',
    FolderKind.collection,
    username,
    request,
    options,
  );

  @override
  Future<Page<Artwork>> galleryContents(
    String folderId, {
    String? username,
    PageRequest request = const PageRequest(),
  }) => _contents('gallery', folderId, username, request);

  @override
  Future<Page<Artwork>> collectionContents(
    String folderId, {
    String? username,
    PageRequest request = const PageRequest(),
  }) => _contents('collections', folderId, username, request);

  Future<Page<ArtworkFolder>> _folders(
    String path,
    FolderKind kind,
    String? username,
    PageRequest request,
    FolderQueryOptions options,
  ) async {
    final normalizedUsername = username?.trim();
    if (normalizedUsername != null && normalizedUsername.isEmpty) {
      _validateIdentifier('', 'username');
    }
    _validatePageRequest(request);
    final json = await _transport.getJson(
      path,
      query: <String, Object?>{
        'username': ?normalizedUsername,
        'calculate_size': options.calculateSize,
        'ext_preload': options.preloadArtworks,
        'filter_empty_folder': options.filterEmpty,
        'with_session': false,
        'offset': _offset(request.cursor),
        'limit': request.limit,
      },
    );
    return _parsePage(json, (item) => _mapper.folder(item, kind));
  }

  Future<Page<Artwork>> _contents(
    String path,
    String folderId,
    String? username,
    PageRequest request,
  ) async {
    _validateIdentifier(folderId, 'folder id');
    final normalizedUsername = username?.trim();
    if (normalizedUsername != null && normalizedUsername.isEmpty) {
      _validateIdentifier('', 'username');
    }
    _validatePageLimit(request, 24);
    final json = await _transport.getJson(
      '$path/${Uri.encodeComponent(folderId.trim())}',
      query: <String, Object?>{
        'username': ?normalizedUsername,
        'offset': _offset(request.cursor),
        'limit': request.limit,
        'with_session': false,
        'expand': 'user.watch',
      },
    );
    return _parsePage(json, _mapper.artwork);
  }
}

final class OfficialMediaRepository implements MediaRepository {
  const OfficialMediaRepository(this._transport);

  final OfficialApiTransport _transport;
  final DeviationMapper _mapper = const DeviationMapper();

  @override
  Future<MediaAsset> originalFile(String artworkId) async {
    _validateIdentifier(artworkId, 'artwork id');
    try {
      final json = await _transport.getJson(
        'deviation/download/${Uri.encodeComponent(artworkId)}',
      );
      return _mapper.original(json, artworkId);
    } on DAKitException catch (error) {
      final availability = _expectedMediaAvailability(error);
      if (availability == null) rethrow;
      return MediaAsset(
        id: '$artworkId:original',
        kind: MediaKind.unknown,
        role: MediaRole.original,
        availability: availability,
        availabilityReason: error.details['provider_description'] as String?,
      );
    }
  }
}

final class OfficialCommentRepository implements CommentRepository {
  const OfficialCommentRepository(this._transport);

  final OfficialApiMutationTransport _transport;
  final DeviationMapper _mapper = const DeviationMapper();

  @override
  Future<CommentPage> forArtwork(
    String artworkId, {
    CommentPageRequest request = const CommentPageRequest(),
  }) async {
    _validateIdentifier(artworkId, 'artwork id');
    _validateCommentPage(request);
    final commentId = request.commentId?.trim();
    final json = await _transport.getJson(
      'comments/deviation/${Uri.encodeComponent(artworkId)}',
      query: <String, Object?>{
        'offset': request.offset,
        'limit': request.limit,
        'maxdepth': request.maxDepth,
        if (commentId != null && commentId.isNotEmpty) 'commentid': commentId,
        'expand': 'comment.fulltext',
      },
    );
    final rawThread = json['thread'];
    if (rawThread is! List) throw _missingField('thread');
    final hasMore = _requiredResponseBoolean(json, 'has_more');
    final hasLess = _requiredResponseBoolean(json, 'has_less');
    final nextOffset = _optionalInteger(json['next_offset']);
    final previousOffset = _optionalInteger(json['prev_offset']);
    if (hasMore && nextOffset == null) throw _missingField('next_offset');
    if (hasLess && previousOffset == null) throw _missingField('prev_offset');
    return CommentPage(
      items: List<Comment>.unmodifiable(
        rawThread.map((item) => _mapper.comment(_requiredItemMap(item))),
      ),
      hasMore: hasMore,
      hasLess: hasLess,
      nextOffset: nextOffset,
      previousOffset: previousOffset,
      total: _optionalInteger(json['total']),
    );
  }

  @override
  Future<Comment> postToArtwork(
    String artworkId,
    String body, {
    String? parentCommentId,
  }) async {
    _validateIdentifier(artworkId, 'artwork id');
    if (body.trim().isEmpty) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'api.comment.empty',
        message: 'A comment body must not be empty.',
      );
    }
    final parent = parentCommentId?.trim();
    if (parentCommentId != null && (parent == null || parent.isEmpty)) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'api.comment.parent.invalid',
        message: 'A parent comment ID must not be empty.',
      );
    }
    final json = await _transport.postFormJson(
      'comments/post/deviation/${Uri.encodeComponent(artworkId)}',
      form: <String, Object?>{'body': body, 'commentid': ?parent},
    );
    return _mapper.comment(json);
  }
}

final class OfficialSocialRepository implements SocialRepository {
  const OfficialSocialRepository(this._transport);

  final OfficialApiMutationTransport _transport;

  @override
  Future<FavouriteResult> favourite(
    String artworkId, {
    List<String> collectionFolderIds = const <String>[],
  }) => _setFavourite(
    'collections/fave',
    artworkId,
    collectionFolderIds,
    expected: true,
  );

  @override
  Future<FavouriteResult> unfavourite(
    String artworkId, {
    List<String> collectionFolderIds = const <String>[],
  }) => _setFavourite(
    'collections/unfave',
    artworkId,
    collectionFolderIds,
    expected: false,
  );

  Future<FavouriteResult> _setFavourite(
    String path,
    String artworkId,
    List<String> folderIds, {
    required bool expected,
  }) async {
    _validateIdentifier(artworkId, 'artwork id');
    final folders = folderIds.map((value) => value.trim()).toList();
    if (folders.any((value) => value.isEmpty)) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'api.collection.folder.invalid',
        message: 'Collection folder IDs must not be empty.',
      );
    }
    final json = await _transport.postFormJson(
      path,
      form: <String, Object?>{
        'deviationid': artworkId,
        if (folders.isNotEmpty) 'folderid': folders,
      },
    );
    _requireSuccess(json, path);
    final total = _optionalInteger(json['favourites']);
    if (total == null || total < 0) throw _missingField('favourites');
    return FavouriteResult(isFavourite: expected, total: total);
  }

  @override
  Future<void> watch(
    String username, {
    WatchOptions options = const WatchOptions(),
  }) async {
    _validateIdentifier(username, 'username');
    final json = await _transport.postFormJson(
      'user/friends/watch/${Uri.encodeComponent(username)}',
      form: <String, Object?>{
        'watch[friend]': options.friend,
        'watch[deviations]': options.deviations,
        'watch[journals]': options.journals,
        'watch[forum_threads]': options.forumThreads,
        'watch[critiques]': options.critiques,
        'watch[scraps]': options.scraps,
        'watch[activity]': options.activity,
        'watch[collections]': options.collections,
      },
    );
    _requireSuccess(json, 'user/friends/watch');
  }

  @override
  Future<void> unwatch(String username) async {
    _validateIdentifier(username, 'username');
    final json = await _transport.getJson(
      'user/friends/unwatch/${Uri.encodeComponent(username)}',
    );
    _requireSuccess(json, 'user/friends/unwatch');
  }
}

final class OfficialMessageRepository implements MessageRepository {
  const OfficialMessageRepository(this._transport);

  final OfficialApiMutationTransport _transport;
  final DeviationMapper _mapper = const DeviationMapper();

  @override
  Future<Page<ProviderMessage>> feed({
    String? cursor,
    String? folderId,
    bool stacked = true,
  }) async {
    final normalizedCursor = _optionalIdentifier(cursor, 'message cursor');
    final normalizedFolder = _optionalIdentifier(folderId, 'folder id');
    final json = await _transport.getJson(
      'messages/feed',
      query: <String, Object?>{
        'folderid': ?normalizedFolder,
        'stack': stacked,
        'cursor': ?normalizedCursor,
        'with_session': false,
      },
    );
    final items = _parseItems(json, _mapper.message);
    final hasMore = _requiredResponseBoolean(json, 'has_more');
    final next = json['cursor'];
    if (next is! String || (hasMore && next.isEmpty)) {
      throw _missingField('cursor');
    }
    return Page<ProviderMessage>(
      items: items,
      hasMore: hasMore,
      nextCursor: hasMore ? next : null,
    );
  }

  @override
  Future<Page<ProviderMessage>> feedback(
    FeedbackType type,
    PageRequest request, {
    String? folderId,
    bool stacked = true,
  }) => _offsetMessages(
    'messages/feedback',
    request,
    query: <String, Object?>{
      'type': type.name,
      'folderid': ?_optionalIdentifier(folderId, 'folder id'),
      'stack': stacked,
    },
  );

  @override
  Future<Page<ProviderMessage>> mentions(
    PageRequest request, {
    String? folderId,
    bool stacked = true,
  }) => _offsetMessages(
    'messages/mentions',
    request,
    query: <String, Object?>{
      'folderid': ?_optionalIdentifier(folderId, 'folder id'),
      'stack': stacked,
    },
  );

  @override
  Future<Page<ProviderMessage>> feedbackStack(
    String stackId,
    PageRequest request,
  ) => _stack('messages/feedback', stackId, request);

  @override
  Future<Page<ProviderMessage>> mentionStack(
    String stackId,
    PageRequest request,
  ) => _stack('messages/mentions', stackId, request);

  Future<Page<ProviderMessage>> _stack(
    String path,
    String stackId,
    PageRequest request,
  ) {
    _validateIdentifier(stackId, 'message stack id');
    return _offsetMessages(
      '$path/${Uri.encodeComponent(stackId.trim())}',
      request,
    );
  }

  Future<Page<ProviderMessage>> _offsetMessages(
    String path,
    PageRequest request, {
    Map<String, Object?> query = const <String, Object?>{},
  }) async {
    _validatePageRequest(request);
    final json = await _transport.getJson(
      path,
      query: <String, Object?>{
        ...query,
        'offset': _offset(request.cursor),
        'limit': request.limit,
        'with_session': false,
      },
    );
    return _parsePage(json, _mapper.message);
  }

  @override
  Future<void> delete({
    String? messageId,
    String? stackId,
    String? folderId,
  }) async {
    final message = _optionalIdentifier(messageId, 'message id');
    final stack = _optionalIdentifier(stackId, 'message stack id');
    final folder = _optionalIdentifier(folderId, 'folder id');
    if ((message == null) == (stack == null)) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'api.message.delete.invalid_target',
        message: 'Exactly one message ID or stack ID must be provided.',
      );
    }
    final json = await _transport.postFormJson(
      'messages/delete',
      form: <String, Object?>{
        'folderid': ?folder,
        'messageid': ?message,
        'stackid': ?stack,
      },
    );
    _requireSuccess(json, 'messages/delete');
  }
}

MediaAvailability? _expectedMediaAvailability(DAKitException error) {
  final rawProviderCode = error.details['provider_code'];
  final providerCode = switch (rawProviderCode) {
    int value => value,
    num value => value.toInt(),
    String value => int.tryParse(value),
    _ => null,
  };
  if (providerCode == 1 || providerCode == 3) {
    return MediaAvailability.missing;
  }
  if (providerCode == 2) return MediaAvailability.unavailable;
  return switch (error.kind) {
    DAKitFailureKind.authentication => MediaAvailability.loginRequired,
    DAKitFailureKind.authorization => MediaAvailability.restricted,
    DAKitFailureKind.notFound => MediaAvailability.missing,
    _ => null,
  };
}

Page<T> _parsePage<T>(
  Map<String, Object?> json,
  T Function(Map<String, Object?> item) parse,
) {
  final rawResults = json['results'];
  if (rawResults is! List) {
    throw const DAKitException(
      kind: DAKitFailureKind.parsing,
      code: 'api.page.missing_results',
      message: 'The official API page does not contain a results list.',
    );
  }
  final items = <T>[];
  for (final raw in rawResults) {
    if (raw is! Map) {
      throw const DAKitException(
        kind: DAKitFailureKind.parsing,
        code: 'api.page.invalid_item',
        message: 'The official API page contains an invalid result.',
      );
    }
    final item = raw.map<String, Object?>(
      (key, value) => MapEntry(key.toString(), value),
    );
    items.add(parse(item));
  }
  final hasMore = json['has_more'] == true;
  final rawCursor = json['next_cursor'];
  final next = rawCursor is String && rawCursor.isNotEmpty
      ? rawCursor
      : json['next_offset'];
  final nextCursor = next?.toString();
  if (hasMore && (nextCursor == null || nextCursor.isEmpty)) {
    throw const DAKitException(
      kind: DAKitFailureKind.parsing,
      code: 'api.page.missing_cursor',
      message: 'The API reports another page without a continuation cursor.',
    );
  }
  return Page<T>(
    items: List<T>.unmodifiable(items),
    hasMore: hasMore,
    nextCursor: hasMore ? nextCursor : null,
  );
}

Page<T> _parseHybridPage<T>(
  Map<String, Object?> json,
  T Function(Map<String, Object?> item) parse,
) {
  final page = _parsePage(json, parse);
  if (!page.hasMore) return page;
  final rawCursor = json['next_cursor'];
  if (rawCursor is String && rawCursor.isNotEmpty) {
    return Page<T>(
      items: page.items,
      hasMore: true,
      nextCursor: 'cursor:$rawCursor',
    );
  }
  final offset = _optionalInteger(json['next_offset']);
  if (offset == null || offset < 0 || offset > 50000) {
    throw _missingField('next_offset');
  }
  return Page<T>(
    items: page.items,
    hasMore: true,
    nextCursor: 'offset:$offset',
  );
}

Map<String, Object?> _hybridPageQuery(String? continuation) {
  if (continuation == null) return const <String, Object?>{'offset': 0};
  if (continuation.startsWith('cursor:')) {
    final value = continuation.substring('cursor:'.length);
    if (value.isNotEmpty) return <String, Object?>{'cursor': value};
  }
  if (continuation.startsWith('offset:')) {
    return <String, Object?>{
      'offset': _offset(continuation.substring('offset:'.length)),
    };
  }
  final legacyOffset = int.tryParse(continuation);
  if (legacyOffset != null) {
    return <String, Object?>{'offset': _offset(continuation)};
  }
  if (continuation.isNotEmpty) return <String, Object?>{'cursor': continuation};
  throw const DAKitException(
    kind: DAKitFailureKind.configuration,
    code: 'api.page.invalid_cursor',
    message: 'The tag continuation cursor is invalid.',
  );
}

String _calendarDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

void _validatePageRequest(PageRequest request) {
  _validatePageLimit(request, 50);
}

void _validatePageLimit(PageRequest request, int maximum) {
  if (request.limit < 1 || request.limit > maximum) {
    throw const DAKitException(
      kind: DAKitFailureKind.configuration,
      code: 'api.page.invalid_limit',
      message: 'The page limit is outside the provider limits.',
    );
  }
}

int _offset(String? cursor) {
  if (cursor == null) return 0;
  final value = int.tryParse(cursor);
  if (value == null || value < 0 || value > 50000) {
    throw const DAKitException(
      kind: DAKitFailureKind.configuration,
      code: 'api.page.invalid_cursor',
      message: 'The page cursor must be an offset between 0 and 50000.',
    );
  }
  return value;
}

void _validateIdentifier(String value, String label) {
  if (value.trim().isEmpty) {
    throw DAKitException(
      kind: DAKitFailureKind.configuration,
      code: 'api.identifier.empty',
      message: 'The $label must not be empty.',
    );
  }
}

void _validateCommentPage(CommentPageRequest request) {
  if (request.offset < -10000 ||
      request.offset > 10000 ||
      request.limit < 1 ||
      request.limit > 50 ||
      request.maxDepth < 0 ||
      request.maxDepth > 5 ||
      (request.commentId != null && request.commentId!.trim().isEmpty)) {
    throw const DAKitException(
      kind: DAKitFailureKind.configuration,
      code: 'api.comment.page.invalid',
      message: 'Comment pagination or depth is outside provider limits.',
    );
  }
}

Map<String, Object?> _requiredItemMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw _missingField('thread.item');
}

List<T> _parseItems<T>(
  Map<String, Object?> json,
  T Function(Map<String, Object?> item) parse,
) {
  final rawResults = json['results'];
  if (rawResults is! List) throw _missingField('results');
  return List<T>.unmodifiable(
    rawResults.map((item) => parse(_requiredItemMap(item))),
  );
}

String? _optionalIdentifier(String? value, String label) {
  if (value == null) return null;
  final normalized = value.trim();
  _validateIdentifier(normalized, label);
  return normalized;
}

int? _optionalInteger(Object? value) => switch (value) {
  int number => number,
  num number => number.toInt(),
  String text => int.tryParse(text),
  _ => null,
};

bool _requiredResponseBoolean(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is bool) return value;
  throw _missingField(field);
}

DAKitException _missingField(String field) => DAKitException(
  kind: DAKitFailureKind.parsing,
  code: 'api.response.missing_field',
  message: 'The official API response is missing a required field.',
  details: <String, Object?>{'field': field},
);

void _requireSuccess(Map<String, Object?> json, String operation) {
  final success = json['success'];
  if (success == true) return;
  if (success == false) {
    throw DAKitException(
      kind: DAKitFailureKind.upstream,
      code: 'api.mutation.rejected',
      message: 'The provider did not apply the requested operation.',
      details: <String, Object?>{'operation': operation},
    );
  }
  throw _missingField('success');
}
