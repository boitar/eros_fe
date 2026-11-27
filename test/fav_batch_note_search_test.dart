import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:eros_fe/common/controller/advance_search_controller.dart';
import 'package:eros_fe/common/controller/favorite_state_store.dart';
import 'package:eros_fe/common/controller/tag_trans_controller.dart';
import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/network/api.dart';
import 'package:eros_fe/network/app_dio/pdio.dart';
import 'package:eros_fe/network/request.dart';
import 'package:eros_fe/pages/tab/controller/favorite/fav_search_scope.dart';
import 'package:eros_fe/pages/tab/controller/favorite/favorite_selection_controller.dart';
import 'package:eros_fe/pages/tab/fetch_list.dart';
import 'package:eros_fe/pages/tab/view/favorite_batch_widgets.dart';
import 'package:eros_fe/pages/tab/view/favorite_search_widgets.dart';
import 'package:eros_fe/widget/fav_note_line.dart';
import 'package:eros_fe/widget/favcat_grid.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;

class _FakeSettings extends GetxService implements EhSettingService {
  @override
  RxBool isSiteEx = false.obs;
  @override
  bool get nativeHttpClientAdapter => false;
  @override
  bool get isPureDarkTheme => false;
  @override
  RxBool get pureDarkThemeObs => false.obs;
  @override
  bool get isTagTranslate => false;
  @override
  RxBool vibrate = false.obs;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected setting: ${invocation.memberName}');
}

class _FakeTagTrans extends GetxController implements TagTransController {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeUser extends GetxController implements UserController {
  @override
  Rx<User> user = const User().obs;
  @override
  bool get isLogin =>
      (user.value.memberId?.isNotEmpty ?? false) &&
      (user.value.passHash?.isNotEmpty ?? false);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected user access: ${invocation.memberName}');
}

class _FakeAdvanceSearch extends GetxController
    implements AdvanceSearchController {
  @override
  bool enableAdvance = true;
  @override
  Map<String, dynamic> get advanceSearchMap => <String, dynamic>{
        'f_sr': 'on',
        'f_srdd': '4',
      };
  @override
  Map<String, dynamic> get favSearchMap => const <String, dynamic>{};
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected advance search access: ${invocation.memberName}');
}

class _BatchFakeServer implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final bodies = <String>[];
  final Set<String> failGids = <String>{};
  int? forcePostStatus;
  String? forcePostBody;
  final Map<String, String> categories = <String, String>{
    '1001': '0',
    '1002': '0',
    '1003': '2',
  };

  String _favoritesHtml(String? filterCat) {
    final counts = List<int>.filled(10, 0);
    for (final cat in categories.values) {
      if (cat.isNotEmpty) {
        counts[int.parse(cat)]++;
      }
    }
    final folders = List.generate(
      10,
      (i) => '<div><div>${counts[i]}</div><div>icon</div><div>Folder $i</div></div>',
    ).join();
    final rows = categories.entries
        .where((e) =>
            e.value.isNotEmpty &&
            (filterCat == null || filterCat == 'a' || filterCat == e.value))
        .map((e) {
      final color = EHConst.favCat.entries
          .firstWhere((entry) => entry.value == e.value)
          .key;
      return '''
<tr>
  <td class="gl1c glcat"><div>Non-H</div></td>
  <td class="gl2c">
    <div><div><img src="https://ehgt.org/t/00/00/${e.key}.jpg" style="height:300px;width:210px" /></div></div>
    <div>
      <div id="posted_${e.key}" title="Folder ${e.value}" style="border-color:$color;">2026-01-01 00:00</div>
      <div class="ir" style="background-position:0px -1px"><div></div><div><div></div><div>20 pages</div></div></div>
    </div>
  </td>
  <td class="gl3c glname">
    <a href="https://e-hentai.org/g/${e.key}/abcdef1234/">
      <div class="glink">Gallery ${e.key}</div>
      <div class="glfnote" id="favnote_${e.key}">Note: Sample note ${e.key}</div>
    </a>
  </td>
  <td class="gl4c glhide"><div>uploader</div><div>20 pages</div></td>
</tr>''';
    }).join();
    return '''
<html><body>
  <div class="ido"><div class="nosel">$folders</div></div>
  <table class="itg gltc"><tbody>$rows</tbody></table>
</body></html>''';
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final bytes = <int>[];
    if (requestStream != null) {
      await requestStream.forEach(bytes.addAll);
    }
    final body = utf8.decode(bytes);
    bodies.add(body);
    final headers = <String, List<String>>{
      Headers.contentTypeHeader: ['text/html; charset=utf-8'],
    };
    if (options.method == 'POST' && options.uri.path == '/favorites.php') {
      if (forcePostStatus != null || forcePostBody != null) {
        return ResponseBody.fromString(
          forcePostBody ?? 'Internal Server Error',
          forcePostStatus ?? 500,
          headers: headers,
        );
      }
      final pairs = body.split('&').map((part) {
        final eq = part.indexOf('=');
        return MapEntry(
          Uri.decodeQueryComponent(part.substring(0, eq)),
          Uri.decodeQueryComponent(part.substring(eq + 1)),
        );
      }).toList();
      final ddact =
          pairs.firstWhere((e) => e.key == 'ddact', orElse: () => const MapEntry('', '')).value;
      final gids = pairs
          .where((e) => e.key == 'modifygids[]')
          .map((e) => e.value)
          .toList();
      for (final gid in gids) {
        if (failGids.contains(gid)) {
          continue;
        }
        if (ddact == 'delete') {
          categories[gid] = '';
        } else if (ddact.startsWith('fav')) {
          categories[gid] = ddact.substring(3);
        }
      }
      final filterCat = options.queryParameters['favcat']?.toString();
      return ResponseBody.fromString(_favoritesHtml(filterCat), 200,
          headers: headers);
    }
    final filterCat = options.queryParameters['favcat']?.toString();
    return ResponseBody.fromString(_favoritesHtml(filterCat), 200,
        headers: headers);
  }

  @override
  void close({bool force = false}) {}
}

Widget _wrapApp(Widget child, {Brightness brightness = Brightness.light}) {
  return CupertinoApp(
    locale: const Locale('zh', 'CN'),
    localizationsDelegates: const [
      L10n.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: L10n.delegate.supportedLocales,
    theme: CupertinoThemeData(brightness: brightness),
    home: CupertinoPageScaffold(child: SafeArea(child: child)),
  );
}

void main() {
  group('FavSearchScope query builder', () {
    test('formats qualifier prefixes and preserves existing namespaces', () {
      expect(buildFavoriteSearchQuery('alpha beta', FavSearchScope.all),
          'alpha beta');
      expect(buildFavoriteSearchQuery('alpha beta', FavSearchScope.title),
          'title:alpha title:beta');
      expect(buildFavoriteSearchQuery('"hello world" -draft', FavSearchScope.title),
          'title:"hello world" -title:draft');
      expect(buildFavoriteSearchQuery('artist:foo bar', FavSearchScope.tag),
          'artist:foo tag:bar');
      expect(
          buildFavoriteSearchQuery('artist:"foo bar" baz ""', FavSearchScope.tag),
          'artist:"foo bar" tag:baz');
      expect(buildFavoriteSearchQuery('re-read "art style"', FavSearchScope.note),
          'favnote:re-read favnote:"art style"');
      expect(buildFavoriteSearchQuery('favnote:keep -skip', FavSearchScope.note),
          'favnote:keep -favnote:skip');
    });

    test('extractFavoriteHighlightTerms strips prefixes and exclusions', () {
      expect(
        extractFavoriteHighlightTerms('favnote:"art style" title:sketch -draft'),
        ['art style', 'sketch'],
      );
    });
  });

  group('FavoriteStateStore note overlay & batch locking', () {
    setUp(() {
      favoriteStates.setAccount('test-account-note-overlay');
    });

    test('preserves note on folder move and clears note on unfavorite', () {
      favoriteStates.commit('5001', '1', 'Folder 1', note: 'Keep me');
      const base = GalleryProvider(gid: '5001', englishTitle: 'Test');
      expect(favoriteStates.overlay(base).favNote, 'Keep me');

      favoriteStates.commit('5001', '4', 'Folder 4');
      expect(favoriteStates.overlay(base).favcat, '4');
      expect(favoriteStates.overlay(base).favNote, 'Keep me');

      favoriteStates.commit('5001', '', '');
      expect(favoriteStates.overlay(base).favcat, '');
      expect(favoriteStates.overlay(base).favNote, '');
    });
  });

  group('FavoriteSelectionController', () {
    test('selects loaded items, toggles, keeps only failed, and exits', () {
      final ctrl = FavoriteSelectionController();
      const a = GalleryProvider(gid: '1');
      const b = GalleryProvider(gid: '2');
      const c = GalleryProvider(gid: '3');

      ctrl.enter(initialItem: a);
      expect(ctrl.selecting.value, isTrue);
      expect(ctrl.count, 1);
      expect(ctrl.isSelected('1'), isTrue);

      ctrl.selectAllLoaded([a, b, c]);
      expect(ctrl.count, 3);
      expect(ctrl.isAllLoadedSelected([a, b, c]), isTrue);

      ctrl.toggleSelectAllLoaded([a, b, c]);
      expect(ctrl.count, 0);

      ctrl.setSelected(b, true);
      ctrl.setSelected(c, true);
      ctrl.keepOnly(['c', '3']);
      expect(ctrl.selected.keys.toList(), ['3']);

      ctrl.exit();
      expect(ctrl.selecting.value, isFalse);
      expect(ctrl.count, 0);
    });
  });

  group('favoritesBatch & favorites search request contracts', () {
    late _BatchFakeServer server;
    late DioHttpConfig previousConfig;
    late _FakeUser fakeUser;

    var accountSeq = 0;

    setUp(() {
      Get.reset();
      Get.testMode = true;
      server = _BatchFakeServer();
      previousConfig = globalDioConfig;
      Api.cacheOption = CacheOptions(
        store: MemCacheStore(),
        policy: CachePolicy.noCache,
      );
      globalDioConfig = const DioHttpConfig(
        baseUrl: EHConst.EH_BASE_URL,
        proxy: 'DIRECT',
        domainFronting: false,
      );
      final dio = DioHttpClient(dioConfig: globalDioConfig).dio;
      dio.interceptors.clear();
      dio.httpClientAdapter = server;
      Global.profile = Global.profile.copyWith(
        user: const User(memberId: '42', passHash: 'hash'),
      );
      fakeUser = _FakeUser()
        ..user.value = const User(memberId: '42', passHash: 'hash');
      Get.put<EhSettingService>(_FakeSettings());
      Get.put<UserController>(fakeUser);
      Get.put<AdvanceSearchController>(_FakeAdvanceSearch());
      Get.put<TagTransController>(_FakeTagTrans());
      favoriteStates.setAccount('batch-test-${accountSeq++}');
    });

    tearDown(() {
      globalDioConfig = previousConfig;
      Get.reset();
    });

    test('encodeFavoritesBatchForm matches live favorites.php #favform wire format', () {
      expect(
        encodeFavoritesBatchForm(gids: ['1001', '1002'], ddact: 'fav3'),
        'ddact=fav3&modifygids%5B%5D=1001&modifygids%5B%5D=1002',
      );
      expect(
        encodeFavoritesBatchForm(gids: ['1001'], ddact: 'delete'),
        'ddact=delete&modifygids%5B%5D=1001',
      );
    });

    test('favoritesBatch moves items and reports partial failures accurately', () async {
      server.failGids.add('1002');
      final result = await favoritesBatch(
        gids: ['1001', '1002'],
        ddact: 'fav5',
        favcat: '0',
      );
      expect(result.succeededGids, ['1001']);
      expect(result.failedGids, ['1002']);
      expect(favoriteStates['1001']?.category, '5');
      expect(favoriteStates['1002']?.category, isNull);
      expect(server.requests.last.method, 'POST');
      expect(server.requests.last.uri.path, '/favorites.php');
      expect(
        server.bodies.last,
        'ddact=fav5&modifygids%5B%5D=1001&modifygids%5B%5D=1002',
      );
    });

    test('favoritesBatch deletes items with ddact=delete', () async {
      final result = await favoritesBatch(
        gids: ['1003'],
        ddact: 'delete',
        favcat: '2',
      );
      expect(result.allSucceeded, isTrue);
      expect(result.succeededGids, ['1003']);
      expect(favoriteStates['1003']?.category, '');
    });

    test('favoritesBatch rejects HTTP 500 and non-favorites HTML without committing', () async {
      server.forcePostStatus = 500;
      final res500 = await favoritesBatch(
        gids: ['1001'],
        ddact: 'delete',
        favcat: '0',
      );
      expect(res500.succeededGids, isEmpty);
      expect(res500.failedGids, ['1001']);
      expect(favoriteStates['1001'], isNull);

      server.forcePostStatus = 200;
      server.forcePostBody = '<html><body>Temporary error</body></html>';
      final resBadHtml = await favoritesBatch(
        gids: ['1001'],
        ddact: 'fav4',
        favcat: '0',
      );
      expect(resBadHtml.succeededGids, isEmpty);
      expect(resBadHtml.failedGids, ['1001']);
      expect(favoriteStates['1001'], isNull);
    });

    test('favorites search never sends advsearch=1 when global enableAdvance is true', () async {
      await getGallery(
        galleryListType: GalleryListType.favorite,
        favcat: '2',
        search: 'favnote:sample',
        globalSearch: true,
        refresh: true,
      );
      final req = server.requests.last;
      expect(req.uri.path, '/favorites.php');
      expect(req.queryParameters.containsKey('advsearch'), isFalse);
      expect(req.queryParameters.containsKey('f_sr'), isFalse);
      expect(req.queryParameters['favcat'], '2');
      expect(req.queryParameters['f_search'], 'favnote:sample');
    });
  });

  group('Favorites redesign widgets', () {
    setUp(() {
      Get.reset();
      Get.testMode = true;
      Get.put<EhSettingService>(_FakeSettings());
      Get.put<ThemeService>(ThemeService());
    });

    tearDown(() => Get.reset());

    testWidgets('FavcatGrid renders 10 folders, disables current, and lightens fav0 in dark mode',
        (tester) async {
      Favcat? picked;
      final folders = List.generate(
        10,
        (i) => Favcat(favId: '$i', favTitle: 'Folder $i', totNum: i * 3),
      );
      await tester.pumpWidget(_wrapApp(
        Builder(
          builder: (context) {
            expect(favcatDisplayColor(context, '0'), const Color(0xFF8E8E93));
            return SingleChildScrollView(
              child: FavcatGrid(
                favcats: folders,
                disabledFavId: '2',
                showAllOption: true,
                onSelect: (fav) => picked = fav,
              ),
            );
          },
        ),
        brightness: Brightness.dark,
      ));
      await tester.pumpAndSettle();

      expect(find.text('全部收藏'), findsOneWidget);
      expect(find.text('当前'), findsOneWidget);
      await tester.tap(find.text('Folder 2'));
      expect(picked, isNull);

      await tester.tap(find.text('Folder 5'));
      expect(picked?.favId, '5');
    });

    testWidgets('FavNoteLine hides empty note and highlights matched query',
        (tester) async {
      await tester.pumpWidget(_wrapApp(
        const Column(
          children: [
            FavNoteLine(note: ''),
            FavNoteLine(note: 'Great watercolor study', highlightQuery: 'watercolor'),
          ],
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('watercolor'), findsOneWidget);
    });

    testWidgets('FavSelectionHeader toggles select-all and deselect-all',
        (tester) async {
      final selection = FavoriteSelectionController();
      const items = [
        GalleryProvider(gid: '1'),
        GalleryProvider(gid: '2'),
      ];
      selection.enter(initialItem: items.first);
      await tester.pumpWidget(_wrapApp(
        FavSelectionHeader(
          selection: selection,
          scopeTitle: 'Folder 0',
          scopeFavId: '0',
          totalCount: 2,
          loadedItemsProvider: () => items,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('已选 1 项'), findsOneWidget);
      expect(find.text('全选'), findsOneWidget);

      await tester.tap(find.text('全选'));
      await tester.pumpAndSettle();
      expect(find.text('已选 2 项'), findsOneWidget);
      expect(find.text('取消全选'), findsOneWidget);

      await tester.tap(find.text('取消全选'));
      await tester.pumpAndSettle();
      expect(find.text('已选 0 项'), findsOneWidget);
    });

    testWidgets('FavSearchResultHeader renders Chinese count/scope order and enters selection',
        (tester) async {
      var entered = false;
      await tester.pumpWidget(_wrapApp(
        FavSearchResultHeader(
          scopeLabel: '备注',
          count: 3,
          selecting: false,
          onEnterSelection: () => entered = true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('备注中 3 个结果'), findsOneWidget);
      await tester.tap(find.text('选择'));
      expect(entered, isTrue);
    });

    testWidgets('FavSearchEmptyState invokes all-fields and all-folders actions',
        (tester) async {
      var widenedFields = false;
      var widenedFolders = false;
      await tester.pumpWidget(_wrapApp(
        FavSearchEmptyState(
          scopeLabel: '备注',
          query: 'sketch',
          canWidenFields: true,
          canWidenFolders: true,
          onSearchAllFields: () => widenedFields = true,
          onSearchAllFolders: () => widenedFolders = true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('备注里没有“sketch”'), findsOneWidget);
      await tester.tap(find.text('在全部字段中搜索'));
      await tester.tap(find.text('在全部收藏夹中搜索'));
      expect(widenedFields, isTrue);
      expect(widenedFolders, isTrue);
    });
  });
}
