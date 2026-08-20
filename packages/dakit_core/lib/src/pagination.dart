final class PageRequest {
  const PageRequest({this.cursor, this.limit = 24})
    : assert(limit > 0 && limit <= 50, 'limit must be between 1 and 50');

  final String? cursor;
  final int limit;
}

final class Page<T> {
  const Page({required this.items, required this.hasMore, this.nextCursor})
    : assert(hasMore == false || nextCursor != null);

  final List<T> items;
  final bool hasMore;
  final String? nextCursor;
}

final class CommentPageRequest {
  const CommentPageRequest({
    this.offset = 0,
    this.limit = 10,
    this.maxDepth = 0,
    this.commentId,
  });

  final int offset;
  final int limit;
  final int maxDepth;
  final String? commentId;
}
