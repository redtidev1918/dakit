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
  final next = json['next_cursor'] ?? json['next_offset'];
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
