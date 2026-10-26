import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:eros_fe/common/parser/gallery_detail_parser.dart';
import 'package:eros_fe/common/parser/gallery_fav_parser.dart';
import 'package:eros_fe/network/favorite_mutation.dart';
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
  test('successful submission requires server category and note', () async {
    var posts = 0;
    var reads = 0;
    final result = await confirmFavoriteMutation(
        category: '7',
        note: 'note',
        submit: () async {
          posts++;
        },
        readBack: () async {
          reads++;
          return const FavoriteServerSnapshot(category: '7', note: 'note');
        });
    expect(result.category, '7');
    expect([posts, reads], [1, 1]);
  });
  test('timeout after server saved is resolved without repeating POST',
      () async {
    var posts = 0;
    final result = await confirmFavoriteMutation(
        category: '7',
        submit: () async {
          posts++;
          throw TimeoutException('Synthetic timeout');
        },
        readBack: () async =>
            const FavoriteServerSnapshot(category: '7', note: ''));
    expect(result.category, '7');
    expect(posts, 1);
  });
  test('HTTP success with unchanged selection is not business success',
      () async {
    await expectLater(
        confirmFavoriteMutation(
            category: '7',
            submit: () async {},
            wait: (_) async {},
            readBack: () async => const FavoriteServerSnapshot(category: '')),
        throwsA(isA<FavoriteMutationException>()));
  });
  test('unreadable response does not claim cancellation succeeded', () async {
    await expectLater(
        confirmFavoriteMutation(
            category: 'favdel',
            submit: () async {},
            wait: (_) async {},
            readBack: () async => const FavoriteServerSnapshot(category: null)),
        throwsA(isA<FavoriteMutationException>()));
  });
  test('cancel succeeds only with an unselected valid popup', () async {
    final result = await confirmFavoriteMutation(
        category: 'favdel',
        submit: () async {},
        readBack: () async => const FavoriteServerSnapshot(category: ''));
    expect(result.category, '');
  });
  test('removal uses detail, not default popup category zero', () async {
    var posts = 0;
    var reads = 0;
    final result = await confirmFavoriteMutation(
      category: 'favdel',
      submit: () async {
        posts++;
      },
      readBack: () async {
        reads++;
        final category = parseDetailFavorite(parse(
                '<div id="fav"></div><a id="favoritelink">Add to Favorites</a>'))
            .$1;
        return FavoriteServerSnapshot(category: category);
      },
    );
    expect(result.category, '');
    expect([posts, reads], [1, 1]);
  });
  test('removal does not commit on still-favorited or unknown detail',
      () async {
    for (final state in <String?>['0', null]) {
      await expectLater(
          confirmFavoriteMutation(
            category: 'favdel',
            submit: () async {},
            wait: (_) async {},
            readBack: () async => FavoriteServerSnapshot(category: state),
          ),
          throwsA(isA<FavoriteMutationException>()));
    }
  });
  test('uncertain delete is confirmed once without repeating POST', () async {
    var posts = 0;
    final result = await confirmFavoriteMutation(
      category: 'favdel',
      submit: () async {
        posts++;
        throw TimeoutException('Synthetic timeout');
      },
      readBack: () async => const FavoriteServerSnapshot(category: ''),
    );
    expect(result.category, '');
    expect(posts, 1);
  });
  test('failed removal verification does not report success', () async {
    await expectLater(
        confirmFavoriteMutation(
          category: 'favdel',
          submit: () async {},
          wait: (_) async {},
          readBack: () async => throw Exception('Synthetic offline'),
        ),
        throwsA(isA<FavoriteMutationException>()));
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
              readBack: () async => const FavoriteServerSnapshot(category: '')),
          throwsArgumentError);
      expect(posted, isFalse);
    }
  });

  for (var category = 0; category < 10; category++) {
    test('server category $category and literal note are confirmed', () async {
      final result = await confirmFavoriteMutation(
        category: '$category',
        note: ' note &+=\r\n保留空白 ',
        submit: () async {},
        readBack: () async => FavoriteServerSnapshot(
            category: '$category', note: ' note &+=\n保留空白 '),
      );
      expect(result.category, '$category');
    });
  }

  test('default popup zero cannot establish a server favorite', () async {
    expect(parserAddFavPage(popup('0')).selectFavcat, '0');
    await expectLater(
      confirmFavoriteMutation(
        category: '0',
        submit: () async {},
        wait: (_) async {},
        readBack: () async => const FavoriteServerSnapshot(category: ''),
      ),
      throwsA(isA<FavoriteMutationException>()),
    );
  });

  for (final code in [401, 403, 404, 429]) {
    test('explicit rejection $code never reads or claims success', () async {
      var reads = 0;
      await expectLater(
          confirmFavoriteMutation(
            category: '0',
            submit: () async => throw FavoriteMutationException(
                FavoriteMutationFailure.rejected,
                statusCode: code),
            readBack: () async {
              reads++;
              return const FavoriteServerSnapshot(category: '0', note: '');
            },
          ),
          throwsA(isA<FavoriteMutationException>()
              .having((e) => e.statusCode, 'status', code)));
      expect(reads, 0);
    });
  }

  test('note mismatch and missing note cannot become success', () async {
    for (final note in <String?>['different', null, ' trimmed']) {
      await expectLater(
          confirmFavoriteMutation(
            category: '7',
            note: ' trimmed ',
            submit: () async {},
            wait: (_) async {},
            readBack: () async =>
                FavoriteServerSnapshot(category: '7', note: note),
          ),
          throwsA(isA<FavoriteMutationException>()));
    }
  });

  test('only readback retries, with a fixed three-read bound', () async {
    var posts = 0;
    var reads = 0;
    final delays = <Duration>[];
    await expectLater(
        confirmFavoriteMutation(
          category: '7',
          submit: () async {
            posts++;
          },
          wait: (d) async {
            delays.add(d);
          },
          readBack: () async {
            reads++;
            return const FavoriteServerSnapshot(category: null);
          },
        ),
        throwsA(isA<FavoriteMutationException>()));
    expect(posts, 1);
    expect(reads, 3);
    expect(delays,
        [const Duration(milliseconds: 400), const Duration(seconds: 1)]);
  });

  test('a late server save resolves on the second read without another POST',
      () async {
    var reads = 0;
    var posts = 0;
    final result = await confirmFavoriteMutation(
      category: '7',
      submit: () async {
        posts++;
        throw const FavoriteMutationException(
            FavoriteMutationFailure.unconfirmed,
            statusCode: 503);
      },
      wait: (_) async {},
      readBack: () async =>
          FavoriteServerSnapshot(category: ++reads == 1 ? '' : '7', note: ''),
    );
    expect(result.category, '7');
    expect([posts, reads], [1, 2]);
  });

  test('account switch after readback prevents success', () async {
    var changed = false;
    await expectLater(
        confirmFavoriteMutation(
          category: '7',
          submit: () async {},
          checkAccount: () {
            if (changed) {
              throw const FavoriteMutationException(
                  FavoriteMutationFailure.accountChanged);
            }
          },
          readBack: () async {
            changed = true;
            return const FavoriteServerSnapshot(category: '7', note: '');
          },
        ),
        throwsA(isA<FavoriteMutationException>().having(
            (e) => e.failure, 'kind', FavoriteMutationFailure.accountChanged)));
  });

  test('login and challenge responses are not successful mutation responses',
      () {
    for (final data in [
      'Failed login redirect setup',
      '<form id="loginform">Sign in</form>',
      '<title>Just a moment...</title><div class="cf-chl-test"></div>',
      'Request forbidden by administrative rules',
    ]) {
      expect(
          () => checkFavoriteResponse(
              Response<String>(
                  requestOptions: RequestOptions(path: '/'),
                  data: data,
                  statusCode: 200),
              FavoriteMutationPhase.submit),
          throwsA(isA<FavoriteMutationException>()));
    }
    expect(
        () => checkFavoriteResponse(
            Response<String>(
                requestOptions: RequestOptions(path: '/'),
                statusCode: 302,
                headers: Headers.fromMap({
                  'location': [
                    'https://forums.e-hentai.org/remoteapi.php?secret=not-for-toast'
                  ]
                })),
            FavoriteMutationPhase.submit),
        throwsA(isA<FavoriteMutationException>()));
  });

  test('popup notes retain leading/trailing whitespace', () {
    expect(
        parserAddFavPage(popup('7').replaceFirst(
                '>note</textarea>', '> note &amp;+=\n保留空白 </textarea>'))
            .favNote,
        ' note &+=\n保留空白 ');
  });

  test('user-visible errors never include arbitrary exception payloads', () {
    expect(
        favoriteMutationMessage(
            Exception('Cookie: secret-token response <html> password')),
        isNot(contains('secret')));
    const error = FavoriteMutationException(FavoriteMutationFailure.rejected,
        statusCode: 403);
    expect(favoriteMutationMessage(error), contains('403'));
    expect(favoriteMutationMessage(error), isNot(contains('Bad state')));
  });
}
