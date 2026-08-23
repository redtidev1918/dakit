/// Single source of truth for official API endpoint paths.
///
/// DeviantArt occasionally moves or renames endpoints — for example the old
/// `browse/morelikethis` page was replaced by `browse/morelikethis/preview`.
/// Keeping every path here means such a change is a one-line edit, and a single
/// contract test ([api_routes_test.dart]) pins the whole surface so a typo is
/// caught before it reaches the network.
final class ApiRoutes {
  const ApiRoutes._();

  // Account / user.
  static const String whoami = 'user/whoami';
  static const String friends = 'user/friends'; // base, append /{username}
  static const String watchers = 'user/watchers'; // base, append /{username}
  static const String friendsSearch = 'user/friends/search';
  static const String whois = 'user/whois';

  // Artwork / discovery.
  static const String browseHome = 'browse/home';
  static const String deviationContent = 'deviation/content';
  static const String deviationMetadata = 'deviation/metadata';
  static const String dailyDeviations = 'browse/dailydeviations';
  static const String deviantsYouWatch = 'browse/deviantsyouwatch';
  static const String browseTags = 'browse/tags';
  static const String browseTagSearch = 'browse/tags/search';
  static const String browseTopics = 'browse/topics';
  static const String topTopics = 'browse/toptopics';
  static const String browseTopic = 'browse/topic';
  static const String moreLikeThisPreview = 'browse/morelikethis/preview';

  // Gallery / collections.
  static const String gallery = 'gallery'; // base, append /{folderId}
  static const String collections = 'collections'; // base, append /{folderId}
  static const String galleryAll = 'gallery/all';
  static const String collectionsAll = 'collections/all';
  static const String galleryFolders = 'gallery/folders';
  static const String collectionFolders = 'collections/folders';
  static const String favourite = 'collections/fave';
  static const String unfavourite = 'collections/unfave';

  // Social.
  static const String watch = 'user/friends/watch';
  static const String unwatch = 'user/friends/unwatch';

  // Messages.
  static const String messagesFeed = 'messages/feed';
  static const String messagesFeedback =
      'messages/feedback'; // base for /{stackId}
  static const String messagesMentions =
      'messages/mentions'; // base for /{stackId}
  static const String messagesDelete = 'messages/delete';

  // Parameterized helpers.
  static String profile(String username) =>
      'user/profile/${Uri.encodeComponent(username)}';
  static String isWatching(String username) =>
      'user/friends/watching/${Uri.encodeComponent(username)}';
  static String deviation(String id) => 'deviation/${Uri.encodeComponent(id)}';
  static String deviationDownload(String id) =>
      'deviation/download/${Uri.encodeComponent(id)}';
  static String commentsFor(String id) =>
      'comments/deviation/${Uri.encodeComponent(id)}';
  static String postComment(String id) =>
      'comments/post/deviation/${Uri.encodeComponent(id)}';
  static String watchUser(String username) =>
      'user/friends/watch/${Uri.encodeComponent(username)}';
  static String unwatchUser(String username) =>
      'user/friends/unwatch/${Uri.encodeComponent(username)}';
}
