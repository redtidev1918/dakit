import 'package:artrelay_core/artrelay_core.dart';

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
      throw const ArtRelayException(
        kind: ArtRelayFailureKind.configuration,
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
    } on ArtRelayException catch (error) {
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

MediaAvailability? _expectedMediaAvailability(ArtRelayException error) {
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
    ArtRelayFailureKind.authentication => MediaAvailability.loginRequired,
    ArtRelayFailureKind.authorization => MediaAvailability.restricted,
    ArtRelayFailureKind.notFound => MediaAvailability.missing,
    _ => null,
  };
}

Page<T> _parsePage<T>(
  Map<String, Object?> json,
  T Function(Map<String, Object?> item) parse,
) {
  final rawResults = json['results'];
  if (rawResults is! List) {
    throw const ArtRelayException(
      kind: ArtRelayFailureKind.parsing,
      code: 'api.page.missing_results',
      message: 'The official API page does not contain a results list.',
    );
  }
  final items = <T>[];
  for (final raw in rawResults) {
    if (raw is! Map) {
      throw const ArtRelayException(
        kind: ArtRelayFailureKind.parsing,
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
    throw const ArtRelayException(
      kind: ArtRelayFailureKind.parsing,
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
    throw const ArtRelayException(
      kind: ArtRelayFailureKind.configuration,
      code: 'api.page.invalid_cursor',
      message: 'The page cursor must be an offset between 0 and 50000.',
    );
  }
  return value;
}

void _validateIdentifier(String value, String label) {
  if (value.trim().isEmpty) {
    throw ArtRelayException(
      kind: ArtRelayFailureKind.configuration,
      code: 'api.identifier.empty',
      message: 'The $label must not be empty.',
    );
  }
}
