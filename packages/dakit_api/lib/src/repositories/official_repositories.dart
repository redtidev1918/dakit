import 'package:dakit_core/dakit_core.dart';

import '../api_routes.dart';
import '../dto/deviation_mapper.dart';
import '../http/official_api_client.dart';

final class OfficialAccountRepository implements AccountRepository {
  const OfficialAccountRepository(this._transport);

  final OfficialApiTransport _transport;
  final DeviationMapper _mapper = const DeviationMapper();

  @override
  Future<UserProfile> currentUser() async {
    final json = await _transport.getJson(
      ApiRoutes.whoami,
      query: const <String, Object?>{'mature_content': true},
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
      ApiRoutes.profile(username.trim()),
      query: const <String, Object?>{
        'ext_collections': false,
        'ext_galleries': false,
        'mature_content': true,
        'expand': 'user.details,user.geo,user.stats',
      },
    );
    return _mapper.profile(json);
  }

  @override
  Future<Page<UserRelationship>> friends(
    String username,
    PageRequest request,
  ) => _relationships(ApiRoutes.friends, username, request);

  @override
  Future<Page<UserRelationship>> watchers(
    String username,
    PageRequest request,
  ) => _relationships(ApiRoutes.watchers, username, request);

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
      ApiRoutes.isWatching(username.trim()),
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
      ApiRoutes.friendsSearch,
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
      ApiRoutes.whois,
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
      ApiRoutes.deviation(id),
      query: const <String, Object?>{
        'mature_content': true,
        'expand': 'deviation.fulltext',
      },
    );
    return _mapper.artwork(json);
  }

  @override
  Future<Page<Artwork>> browse(PageRequest request) =>
      _page(ApiRoutes.browseHome, request);

  /// Coarse search fallback: the official API removed its dedicated search
  /// endpoint (the legacy `browse/search` is gone), so this asks
  /// `browse/home` with a `q` filter. It is not a full search surface — hosts
  /// that need real results should prefer a web-session adapter (DAViewer
  /// uses the website's own `_puppy/dabrowse/search/deviations`, as gallery-dl
  /// does) and keep this only as the no-web-session fallback.
  @override
  Future<Page<Artwork>> search(String query, PageRequest request) {
    if (query.trim().isEmpty) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'api.search.empty',
        message: 'A search query must not be empty.',
      );
    }
    return _page(ApiRoutes.browseHome, request, query: query.trim());
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

/// Reads fields that DeviantArt exposes only through `deviation/metadata`.
///
/// Browse/list responses and even `deviation/{id}` may omit searchable tags,
/// so hosts should use this repository when an [Artwork.tags] list is empty.
final class OfficialArtworkMetadataRepository {
  const OfficialArtworkMetadataRepository(this._transport);

  final OfficialApiTransport _transport;

  Future<List<String>> tags(String artworkId) async {
    final normalized = artworkId.trim();
    _validateIdentifier(normalized, 'artwork id');
    final json = await _transport.getJson(
      ApiRoutes.deviationMetadata,
      query: <String, Object?>{
        'deviationids[]': <String>[normalized],
        'mature_content': true,
      },
    );
    return _deviationMetadataTags(json, normalized);
  }
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
      ApiRoutes.deviationContent,
      query: <String, Object?>{
        'deviationid': artworkId,
        'for_edit': forEditing,
        'mature_content': true,
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
      _fetch(ApiRoutes.galleryAll, username, request);

  @override
  Future<Page<Artwork>> favourites(String username, PageRequest request) =>
      _fetch(ApiRoutes.collectionsAll, username, request);

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
        'mature_content': true,
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
      ApiRoutes.dailyDeviations,
      query: <String, Object?>{
        if (date != null) 'date': _calendarDate(date),
        'mature_content': true,
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
      ApiRoutes.deviantsYouWatch,
      query: <String, Object?>{
        'limit': request.limit,
        'offset': _offset(request.cursor),
        'mature_content': true,
      },
    );
    // DeviantArt returns an empty object (or a null `results`) for accounts
    // that do not watch anyone. That is a valid empty feed, not a malformed
    // generic page. Keep strict page parsing for contradictory pagination
    // metadata so an actual upstream schema change still remains observable.
    if ((!json.containsKey('results') || json['results'] == null) &&
        json['has_more'] != true &&
        json['next_offset'] == null) {
      return const Page<Artwork>(items: <Artwork>[], hasMore: false);
    }
    return _parsePage(json, _mapper.artwork);
  }

  @override
  Future<Page<Artwork>> tag(
    String tag,
    PageRequest request, {
    BrowseSort sort = BrowseSort.recent,
  }) async {
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
      ApiRoutes.browseTags,
      query: <String, Object?>{
        'tag': normalized,
        // DeviantArt's browse/tags accepts mode=newest|popular.
        'mode': sort == BrowseSort.popular ? 'popular' : 'newest',
        ..._hybridPageQuery(request.cursor),
        'limit': request.limit,
        'mature_content': true,
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
      ApiRoutes.browseTagSearch,
      query: <String, Object?>{'tag_name': normalized, 'mature_content': true},
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
      ApiRoutes.browseTopics,
      query: <String, Object?>{
        ..._hybridPageQuery(request.cursor),
        'limit': request.limit,
        'mature_content': true,
      },
    );
    return _parseHybridPage(json, _mapper.topic);
  }

  @override
  Future<List<ArtworkTopic>> topTopics() async {
    final json = await _transport.getJson(
      ApiRoutes.topTopics,
      query: const <String, Object?>{'mature_content': true},
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
      ApiRoutes.browseTopic,
      query: <String, Object?>{
        'topic': normalized,
        ..._hybridPageQuery(request.cursor),
        'limit': request.limit,
        'mature_content': true,
        'expand': 'user.watch',
      },
    );
    return _parseHybridPage(json, _mapper.artwork);
  }

  @override
  Future<MoreLikeThisResult> moreLikeThis(String seed) async {
    final normalized = seed.trim();
    if (normalized.isEmpty) {
      throw const DAKitException(
        kind: DAKitFailureKind.configuration,
        code: 'api.morelikethis.empty',
        message: 'A seed deviation id must not be empty.',
      );
    }
    // The official endpoint is `browse/morelikethis/preview`; it returns a
    // fixed (non-paginated) bundle of related deviations plus collection
    // groups rather than a page, so the older `browse/morelikethis` page shape
    // no longer exists.
    final json = await _transport.getJson(
      ApiRoutes.moreLikeThisPreview,
      query: <String, Object?>{'seed': normalized},
    );
    final fromDa = await _tolerantRelatedArtworks(json, 'more_from_da');
    final fromArtist = await _tolerantRelatedArtworks(json, 'more_from_artist');

    final seen = <String>{normalized};
    final artworks = <Artwork>[];
    // "More from DeviantArt" first, then "More from <artist>", de-duplicated
    // and excluding the seed itself so the section never repeats the artwork.
    for (final artwork in <Artwork>[...fromDa, ...fromArtist]) {
      if (seen.add(artwork.id)) artworks.add(artwork);
    }
    return MoreLikeThisResult(
      artworks: List<Artwork>.unmodifiable(artworks),
      featuredInCollections: _tolerantCollectionGroups(
        json,
        'featured_in_collections',
      ),
      suggestedCollections: _tolerantCollectionGroups(
        json,
        'suggested_collections',
      ),
    );
  }

  /// Related-deviation arrays occasionally contain deleted, restricted, or
  /// partially shaped entries. One bad sibling must not discard every usable
  /// recommendation in the response.
  Future<List<Artwork>> _tolerantRelatedArtworks(
    Map<String, Object?> json,
    String field,
  ) async {
    final raw = json[field];
    if (raw is! List) return const <Artwork>[];
    final artworks = <Artwork>[];
    final sparseIds = <String>[];
    for (final item in raw) {
      final entry = item is Map
          ? item.map<String, Object?>(
              (key, value) => MapEntry(key.toString(), value),
            )
          : null;
      if (entry == null || entry['is_deleted'] == true) continue;
      try {
        artworks.add(_mapper.artwork(entry));
      } on Object {
        // The current public schema guarantees only deviationid, printid and
        // is_deleted. Hydrate a legitimate sparse preview item through the
        // canonical deviation endpoint instead of discarding the whole rail.
        final id = entry['deviationid'];
        if (id is String && id.trim().isNotEmpty) sparseIds.add(id.trim());
      }
    }

    // Keep the fallback bounded so a provider response containing many sparse
    // entries cannot fan out an unbounded number of requests. Four concurrent
    // hydrations keep the section responsive without causing an API burst.
    Object? hydrationError;
    for (var offset = 0; offset < sparseIds.length; offset += 4) {
      final end = offset + 4 < sparseIds.length ? offset + 4 : sparseIds.length;
      final hydrated = await Future.wait<Artwork?>(
        sparseIds.sublist(offset, end).map((id) async {
          try {
            final detail = await _transport.getJson(
              ApiRoutes.deviation(id),
              query: const <String, Object?>{
                'mature_content': true,
                'expand': 'deviation.fulltext',
              },
            );
            return _mapper.artwork(detail);
          } on Object catch (error) {
            hydrationError ??= error;
            return null;
          }
        }),
      );
      artworks.addAll(hydrated.whereType<Artwork>());
    }

    // If the provider gave us real candidates but none could be rendered,
    // surface the transport/shape failure so hosts can show a retry state.
    if (artworks.isEmpty && sparseIds.isNotEmpty && hydrationError != null) {
      throw hydrationError!;
    }
    return List<Artwork>.unmodifiable(artworks);
  }

  /// Collections are the most volatile part of the preview response. If the
  /// provider changes or drops their shape, degrade to an empty list so the
  /// related artworks still render; contract tests against recorded fixtures
  /// surface the drift at build time.
  List<CollectionWithDeviations> _tolerantCollectionGroups(
    Map<String, Object?> json,
    String field,
  ) {
    try {
      return _collectionGroups(json, field);
    } on Object {
      return const <CollectionWithDeviations>[];
    }
  }

  List<CollectionWithDeviations> _collectionGroups(
    Map<String, Object?> json,
    String field,
  ) {
    final raw = json[field];
    if (raw == null) return const <CollectionWithDeviations>[];
    if (raw is! List) throw _missingField(field);
    return List<CollectionWithDeviations>.unmodifiable(
      raw.map((entry) {
        final group = _requiredItemMap(entry);
        final collection = _mapper.collectionSummary(
          _requiredItemMap(group['collection']),
        );
        final rawDeviations = group['deviations'];
        final deviations = rawDeviations is List
            ? List<Artwork>.unmodifiable(
                rawDeviations.map(
                  (item) => _mapper.artwork(_requiredItemMap(item)),
                ),
              )
            : const <Artwork>[];
        return CollectionWithDeviations(
          collection: collection,
          deviations: deviations,
        );
      }),
    );
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
    ApiRoutes.galleryFolders,
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
    ApiRoutes.collectionFolders,
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
  }) => _contents(ApiRoutes.gallery, folderId, username, request);

  @override
  Future<Page<Artwork>> collectionContents(
    String folderId, {
    String? username,
    PageRequest request = const PageRequest(),
  }) => _contents(ApiRoutes.collections, folderId, username, request);

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
        'mature_content': true,
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
        'mature_content': true,
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
        ApiRoutes.deviationDownload(artworkId),
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
      ApiRoutes.commentsFor(artworkId),
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
      ApiRoutes.postComment(artworkId),
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
    ApiRoutes.favourite,
    artworkId,
    collectionFolderIds,
    expected: true,
  );

  @override
  Future<FavouriteResult> unfavourite(
    String artworkId, {
    List<String> collectionFolderIds = const <String>[],
  }) => _setFavourite(
    ApiRoutes.unfavourite,
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
      ApiRoutes.watchUser(username),
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
    _requireSuccess(json, ApiRoutes.watch);
  }

  @override
  Future<void> unwatch(String username) async {
    _validateIdentifier(username, 'username');
    final json = await _transport.getJson(ApiRoutes.unwatchUser(username));
    _requireSuccess(json, ApiRoutes.unwatch);
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
      ApiRoutes.messagesFeed,
      query: <String, Object?>{
        'folderid': ?normalizedFolder,
        'stack': stacked,
        'cursor': ?normalizedCursor,
        'mature_content': true,
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
    ApiRoutes.messagesFeedback,
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
    ApiRoutes.messagesMentions,
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
  ) => _stack(ApiRoutes.messagesFeedback, stackId, request);

  @override
  Future<Page<ProviderMessage>> mentionStack(
    String stackId,
    PageRequest request,
  ) => _stack(ApiRoutes.messagesMentions, stackId, request);

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
        'mature_content': true,
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
      ApiRoutes.messagesDelete,
      form: <String, Object?>{
        'folderid': ?folder,
        'messageid': ?message,
        'stackid': ?stack,
      },
    );
    _requireSuccess(json, ApiRoutes.messagesDelete);
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
    // A 4xx from the download endpoint means the deviation exists but its
    // download was rejected (not downloadable, premium, limit reached…); a 5xx
    // is a transient server error and keeps bubbling up for a retry.
    DAKitFailureKind.upstream => _upstreamDownloadAvailability(error),
    _ => null,
  };
}

MediaAvailability? _upstreamDownloadAvailability(DAKitException error) {
  final rawStatus = error.details['status'];
  final status = switch (rawStatus) {
    int value => value,
    num value => value.toInt(),
    _ => null,
  };
  if (status != null && status >= 400 && status < 500) {
    return MediaAvailability.unavailable;
  }
  return null;
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

List<String> _deviationMetadataTags(
  Map<String, Object?> json,
  String artworkId,
) {
  final rawMetadata = json['metadata'];
  if (rawMetadata is! List) throw _missingField('metadata');
  for (final value in rawMetadata) {
    final entry = value is Map ? _requiredItemMap(value) : null;
    if (entry == null || entry['deviationid'] != artworkId) continue;
    final rawTags = entry['tags'];
    if (rawTags is! List) return const <String>[];
    final tags = <String>[];
    final seen = <String>{};
    for (final value in rawTags) {
      if (value is! Map) continue;
      final name = value['tag_name'] ?? value['name'];
      if (name is! String) continue;
      final normalized = name.trim();
      if (normalized.isNotEmpty && seen.add(normalized)) tags.add(normalized);
    }
    return List<String>.unmodifiable(tags);
  }
  throw DAKitException(
    kind: DAKitFailureKind.parsing,
    code: 'api.deviation.metadata.missing',
    message: 'The official API did not return the requested metadata.',
    details: <String, Object?>{'deviationid': artworkId},
  );
}

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
