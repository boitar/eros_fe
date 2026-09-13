import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:eros_fe/network/favorite_mutation.dart';
import 'package:eros_fe/common/parser/gallery_fav_parser.dart';
import 'package:eros_fe/common/parser/gallery_detail_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart';

String popup(String? selected, {String checked = 'checked'}) => '''
<div id="galpop"><div><div class="nosel">${List.generate(10, (i) => '''
<div><div><input type="radio" name="favcat" value="$i" ${selected == '$i' ? checked : ''}></div>
<div>icon</div><div>自定义 $i</div></div>''').join()}</div><textarea>note</textarea></div></div>''';

void main() {
  test('authoritative reads never fall back to stale cache on network errors',
      () {
    final original =
        CacheOptions(store: MemCacheStore(), hitCacheOnErrorExcept: [401]);
    final readback = favoriteNetworkCacheOptions(original, transient: true);
    expect(readback.policy, CachePolicy.noCache);
    expect(readback.hitCacheOnErrorExcept, isNull);
    expect(favoriteNetworkCacheOptions(original).policy, CachePolicy.refresh);
    expect(favoriteNetworkCacheOptions(original).hitCacheOnErrorExcept, isNull);
    expect(original.hitCacheOnErrorExcept, [401]);
  });

  for (var i = 0; i < 10; i++) {
    test('popup category $i accepts empty checked attribute', () {
      final result = parserAddFavPage(popup('$i', checked: 'checked=""'));
      expect(result.selectFavcat, '$i');
      expect(result.favcats[i].favTitle, '自定义 $i');
    });
    test('detail category $i tolerates CSS whitespace', () {
      final result = parseDetailFavorite(parse(
          '<div id="fav"><div style="BACKGROUND-POSITION: 0px -${2 + i * 19}px"></div></div><a id="favoritelink">我的收藏</a>'));
      expect(result, ('$i', '我的收藏'));
    });
  }
  test('unselected popup is distinct from malformed/login/error page', () {
    expect(parserAddFavPage(popup(null)).selectFavcat, isNull);
    for (final html in [
      '<form>Log in</form>',
      '<div id="galpop">error</div>'
    ]) {
      expect(() => parserAddFavPage(html), throwsFormatException);
    }
  });
  test('unknown detail icon is not cancellation', () {
    expect(
        parseDetailFavorite(parse(
                '<div id="fav"><div style="background-position:invalid"></div></div><a id="favoritelink">custom</a>'))
            .$1,
        isNull);
    expect(
        parseDetailFavorite(parse(
                '<div id="fav"></div><a id="favoritelink">Add to Favorites</a>'))
            .$1,
        '');
  });
  test('successful submission requires server readback', () async {
    var posts = 0;
    var reads = 0;
    final result = await confirmFavoriteMutation(
        category: '7',
        submit: () async {
          posts++;
        },
        readBack: () async {
          reads++;
          return parserAddFavPage(popup('7'));
        });
    expect(result.selectFavcat, '7');
    expect([posts, reads], [1, 1]);
  });
  test('timeout after server saved is resolved without repeating POST',
      () async {
    var posts = 0;
    final result = await confirmFavoriteMutation(
        category: '7',
        submit: () async {
          posts++;
          throw StateError('timeout');
        },
        readBack: () async => parserAddFavPage(popup('7')));
    expect(result.selectFavcat, '7');
    expect(posts, 1);
  });
  test('HTTP success with unchanged selection is not business success',
      () async {
    await expectLater(
        confirmFavoriteMutation(
            category: '7',
            submit: () async {},
            readBack: () async => parserAddFavPage(popup(null))),
        throwsStateError);
  });
  test('unreadable response does not claim cancellation succeeded', () async {
    await expectLater(
        confirmFavoriteMutation(
            category: 'favdel',
            submit: () async {},
            readBack: () async => parserAddFavPage('<p>Log in</p>')),
        throwsStateError);
  });
  test('cancel succeeds only with an unselected valid popup', () async {
    final result = await confirmFavoriteMutation(
        category: 'favdel',
        submit: () async {},
        readBack: () async => parserAddFavPage(popup(null)));
    expect(result.selectFavcat, isNull);
  });
  test('removal uses detail, not default popup category zero', () async {
    var posts = 0;
    var reads = 0;
    final result = await confirmFavoriteMutation(
      category: 'favdel',
      submit: () async { posts++; },
      readBack: () async => throw StateError('popup must not be used'),
      readRemoval: () async {
        reads++;
        final category = parseDetailFavorite(parse(
            '<div id="fav"></div><a id="favoritelink">Add to Favorites</a>')).$1;
        return category == '';
      },
    );
    expect(result.selectFavcat, isNull);
    expect([posts, reads], [1, 1]);
  });
  test('removal does not commit on still-favorited or unknown detail', () async {
    for (final state in <bool?>[false, null]) {
      await expectLater(confirmFavoriteMutation(
        category: 'favdel', submit: () async {},
        readBack: () async => parserAddFavPage(popup(null)),
        readRemoval: () async => state,
      ), throwsStateError);
    }
  });
  test('uncertain delete is confirmed once without repeating POST', () async {
    var posts = 0;
    final result = await confirmFavoriteMutation(
      category: 'favdel',
      submit: () async { posts++; throw StateError('timeout'); },
      readBack: () async => parserAddFavPage(popup('0')),
      readRemoval: () async => true,
    );
    expect(result.selectFavcat, isNull);
    expect(posts, 1);
  });
  test('failed removal verification does not report success', () async {
    await expectLater(confirmFavoriteMutation(
      category: 'favdel', submit: () async {},
      readBack: () async => parserAddFavPage(popup(null)),
      readRemoval: () async => throw StateError('offline'),
    ), throwsStateError);
  });
  test('all/local/invalid categories never reach POST', () async {
    for (final category in ['a', 'l', '10', '']) {
      var posted = false;
      await expectLater(
          confirmFavoriteMutation(
              category: category,
              submit: () async {
                posted = true;
              },
              readBack: () async => parserAddFavPage(popup(null))),
          throwsArgumentError);
      expect(posted, isFalse);
    }
  });
}
