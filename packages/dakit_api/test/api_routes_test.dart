import 'package:dakit_api/src/api_routes.dart';
import 'package:test/test.dart';

void main() {
  test('pins the static official API endpoint paths', () {
    expect(ApiRoutes.whoami, 'user/whoami');
    expect(ApiRoutes.friends, 'user/friends');
    expect(ApiRoutes.watchers, 'user/watchers');
    expect(ApiRoutes.friendsSearch, 'user/friends/search');
    expect(ApiRoutes.whois, 'user/whois');

    expect(ApiRoutes.browseHome, 'browse/home');
    expect(ApiRoutes.deviationContent, 'deviation/content');
    expect(ApiRoutes.deviationMetadata, 'deviation/metadata');
    expect(ApiRoutes.dailyDeviations, 'browse/dailydeviations');
    expect(ApiRoutes.deviantsYouWatch, 'browse/deviantsyouwatch');
    expect(ApiRoutes.browseTags, 'browse/tags');
    expect(ApiRoutes.browseTagSearch, 'browse/tags/search');
    expect(ApiRoutes.browseTopics, 'browse/topics');
    expect(ApiRoutes.topTopics, 'browse/toptopics');
    expect(ApiRoutes.browseTopic, 'browse/topic');
    expect(ApiRoutes.moreLikeThisPreview, 'browse/morelikethis/preview');

    expect(ApiRoutes.galleryAll, 'gallery/all');
    expect(ApiRoutes.collectionsAll, 'collections/all');
    expect(ApiRoutes.galleryFolders, 'gallery/folders');
    expect(ApiRoutes.collectionFolders, 'collections/folders');
    expect(ApiRoutes.favourite, 'collections/fave');
    expect(ApiRoutes.unfavourite, 'collections/unfave');

    expect(ApiRoutes.watch, 'user/friends/watch');
    expect(ApiRoutes.unwatch, 'user/friends/unwatch');

    expect(ApiRoutes.messagesFeed, 'messages/feed');
    expect(ApiRoutes.messagesFeedback, 'messages/feedback');
    expect(ApiRoutes.messagesMentions, 'messages/mentions');
    expect(ApiRoutes.messagesDelete, 'messages/delete');
  });

  test('URL-encodes parameterized endpoint paths', () {
    expect(ApiRoutes.deviation('a b/c'), 'deviation/a%20b%2Fc');
    expect(ApiRoutes.deviationDownload('art-1'), 'deviation/download/art-1');
    expect(ApiRoutes.commentsFor('art-1'), 'comments/deviation/art-1');
    expect(ApiRoutes.postComment('art-1'), 'comments/post/deviation/art-1');
    expect(ApiRoutes.watchUser('user name'), 'user/friends/watch/user%20name');
    expect(
      ApiRoutes.unwatchUser('user name'),
      'user/friends/unwatch/user%20name',
    );
    expect(ApiRoutes.profile('user name'), 'user/profile/user%20name');
    expect(
      ApiRoutes.isWatching('user name'),
      'user/friends/watching/user%20name',
    );
  });
}
