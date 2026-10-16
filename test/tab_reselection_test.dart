import 'package:eros_fe/common/controller/tag_controller.dart';
import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/common/controller/webdav_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/models/custom_profile.dart';
import 'package:eros_fe/models/fav_config.dart';
import 'package:eros_fe/models/favcat.dart';
import 'package:eros_fe/pages/controller/favorite_sel_controller.dart';
import 'package:eros_fe/pages/tab/comm.dart';
import 'package:eros_fe/pages/tab/controller/favorite/favorite_sublist_controller.dart';
import 'package:eros_fe/pages/tab/controller/favorite/favorite_tabbar_controller.dart';
import 'package:eros_fe/pages/tab/controller/group/custom_sublist_controller.dart';
import 'package:eros_fe/pages/tab/controller/group/custom_tabbar_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  late TabHomeController home;
  late CustomTabbarController gallery;
  late FavoriteTabBarController favorites;
  late _User user;
  late EhTabController first;
  late EhTabController second;
  late List<String> events;

  void reselectionTest(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        home.resetTabTapSequence();
      }
    });
  }

  setUp(() {
    Get.testMode = true;
    Get.put<LocaleService>(LocaleService());
    Get.put<EhSettingService>(_Settings());
    Get.put<TagController>(_Tag());
    Get.put<WebdavController>(_Webdav());
    user = _User();
    Get.put<UserController>(user);
    Get.put<FavoriteSelectorController>(_FavoriteSelector());
    home = Get.put<TabHomeController>(_Home());
    home.tabNameList.value = [
      EHRoutes.gallery,
      EHRoutes.favorite,
      EHRoutes.toplist,
      EHRoutes.history,
      EHRoutes.download,
    ];
    home.tabMap.value = {
      for (final route in home.tabNameList) route: true,
    };
    gallery = Get.put<CustomTabbarController>(_Gallery());
    favorites = Get.put<FavoriteTabBarController>(_Favorites());
    events = [];
    first = _scrollTarget(events, 'first');
    second = _scrollTarget(events, 'second');
    gallery.profiles.value = [
      const CustomProfile(uuid: 'first', name: 'First'),
      const CustomProfile(uuid: 'second', name: 'Second'),
    ];
    gallery.currProfileUuid = 'first';
    gallery.subControllerMap.addAll({
      'first': _CustomPage(first),
      'second': _CustomPage(second),
    });
    favorites.subControllerMap.addAll({
      'a': _FavoritePage(first),
      '0': _FavoritePage(second),
      'l': _FavoritePage(first),
    });
    tabPages.scrollControllerMap[EHRoutes.toplist] = first;
    tabPages.scrollControllerMap[EHRoutes.history] = first;
  });

  tearDown(() {
    Get.reset();
    tabPages.scrollControllerMap.clear();
    first.dispose();
    second.dispose();
  });

  for (final saved in [1, 99, -1]) {
    testWidgets('restored favorite index $saved selects its actual category',
        (tester) async {
      final restored = Get.put<FavoriteTabBarController>(
          _RestoringFavorites(saved),
          tag: 'restored-favorite');
      restored.subControllerMap.addAll({
        'a': _FavoritePage(first),
        '0': _FavoritePage(second),
      });
      final expectedIndex = saved.clamp(0, 1);
      expect(restored.index, expectedIndex);
      expect(restored.currFavcat, expectedIndex == 0 ? 'a' : '0');
      await restored.reselectCurrentPage();
      final targetName = expectedIndex == 0 ? 'first' : 'second';
      expect(events, ['$targetName:combined']);
    });
  }

  testWidgets('restored logged-out favorite index targets the local category',
      (tester) async {
    user.loggedIn = false;
    (Get.find<FavoriteSelectorController>() as _FavoriteSelector).values = [
      const Favcat(favId: 'l', favTitle: 'Local'),
    ];
    final restored = Get.put<FavoriteTabBarController>(_RestoringFavorites(8),
        tag: 'restored-favorite');
    restored.subControllerMap['l'] = _FavoritePage(first);
    expect(restored.index, 0);
    expect(restored.currFavcat, 'l');
    await restored.reselectCurrentPage();
    expect(events, ['first:combined']);
  });

  test('tab reselect awaits its scroll-and-refresh action once', () async {
    final controller = EhTabController();
    addTearDown(controller.dispose);
    final events = <String>[];
    controller.scrollToTopAndRefreshCall = () async {
      events.add('scroll');
      await Future<void>.delayed(Duration.zero);
      events.add('refresh');
    };

    await controller.scrollToTopAndRefresh();

    expect(events, <String>['scroll', 'refresh']);
  });

  reselectionTest('changing tabs does not scroll or refresh', (tester) async {
    await home.onTap(1, useLiquidGlass: false);
    expect(home.currentIndex, 1);
    expect(events, isEmpty);
    await home.onTap(1, useLiquidGlass: false);
    expect(events, ['first:top']);
  });

  reselectionTest(
      'standard reselect scrolls immediately and refreshes within 800ms',
      (tester) async {
    await home.onTap(0, useLiquidGlass: false);
    expect(events, ['first:top']);
    await tester.pump(const Duration(milliseconds: 799));
    await home.onTap(0, useLiquidGlass: false);
    expect(events, ['first:top', 'first:refresh']);
  });

  reselectionTest('the 800ms deadline starts a new single reselect',
      (tester) async {
    await home.onTap(0, useLiquidGlass: false);
    await tester.pump(const Duration(milliseconds: 800));
    await home.onTap(0, useLiquidGlass: false);
    expect(events, ['first:top', 'first:top']);
  });

  reselectionTest(
      'cancelled old timers cannot interrupt the third/fourth tap pair',
      (tester) async {
    await home.onTap(0, useLiquidGlass: false);
    await tester.pump(const Duration(milliseconds: 100));
    await home.onTap(0, useLiquidGlass: false);
    await tester.pump(const Duration(milliseconds: 100));
    await home.onTap(0, useLiquidGlass: false);
    await tester.pump(const Duration(milliseconds: 650));
    await home.onTap(0, useLiquidGlass: false);
    expect(events, [
      'first:top',
      'first:refresh',
      'first:top',
      'first:refresh',
    ]);
  });

  reselectionTest('switching main tabs clears pending reselection',
      (tester) async {
    await home.onTap(0, useLiquidGlass: false);
    await home.onTap(2, useLiquidGlass: false);
    await home.onTap(0, useLiquidGlass: false);
    await home.onTap(0, useLiquidGlass: false);
    expect(events, ['first:top', 'first:top']);
  });

  reselectionTest('gallery ignores the last registered cached sibling',
      (tester) async {
    tabPages.scrollControllerMap[EHRoutes.gallery] = second;
    await home.onTap(0, useLiquidGlass: false);
    await home.onTap(0, useLiquidGlass: false);
    expect(events, ['first:top', 'first:refresh']);
    expect(gallery.currentPageScrollController, same(first));
  });

  reselectionTest('gallery category round trip clears the original tap pair',
      (tester) async {
    await home.onTap(0, useLiquidGlass: false);
    gallery.onPageChanged(1);
    expect(gallery.currentPageScrollController, same(second));
    gallery.onPageChanged(0);
    await home.onTap(0, useLiquidGlass: false);
    expect(events, ['first:top', 'first:top']);
  });

  reselectionTest('controller identity changes cannot complete an old tap pair',
      (tester) async {
    await home.onTap(0, useLiquidGlass: false);
    gallery.subControllerMap['first'] = _CustomPage(second);
    await home.onTap(0, useLiquidGlass: false);
    expect(events, ['first:top', 'second:top']);
  });

  reselectionTest(
      'favorite category switching and local favorites use active page',
      (tester) async {
    home.currentIndex = 1;
    tabPages.scrollControllerMap[EHRoutes.favorite] = second;
    await home.onTap(1, useLiquidGlass: false);
    favorites.onPageChanged(1);
    await home.onTap(1, useLiquidGlass: false);
    await home.onTap(1, useLiquidGlass: false);
    expect(events, ['first:top', 'second:top', 'second:refresh']);
    user.loggedIn = false;
    expect(favorites.currentPageScrollController, same(first));
    await home.onTap(1, useLiquidGlass: false);
    expect(events.last, 'first:top');
  });

  reselectionTest('favorite category round trip clears the original tap pair',
      (tester) async {
    home.currentIndex = 1;
    await home.onTap(1, useLiquidGlass: false);
    favorites.onPageChanged(1);
    favorites.onPageChanged(0);
    await home.onTap(1, useLiquidGlass: false);
    expect(events, ['first:top', 'first:top']);
  });

  reselectionTest('mode changes without taps still reset the tap sequence',
      (tester) async {
    await home.onTap(0, useLiquidGlass: false);
    home.setNavigationMode(useLiquidGlass: true);
    home.setNavigationMode(useLiquidGlass: false);
    await home.onTap(0, useLiquidGlass: false);
    expect(events, ['first:top', 'first:top']);
  });

  reselectionTest('rendered standard mode wins over the glass setting',
      (tester) async {
    Get.find<EhSettingService>().liquidGlass = true;
    await home.onTap(0, useLiquidGlass: false);
    expect(events, ['first:top']);
  });

  reselectionTest('glass gallery/favorites/toplist retain scroll-and-refresh',
      (tester) async {
    for (final index in [0, 1, 2]) {
      home.currentIndex = index;
      await home.onTap(index, useLiquidGlass: true);
      await home.onTap(index, useLiquidGlass: true);
    }
    expect(events, List.filled(6, 'first:combined'));
  });

  reselectionTest('glass history retains scroll-only behavior', (tester) async {
    home.currentIndex = 3;
    await home.onTap(3, useLiquidGlass: true);
    await home.onTap(3, useLiquidGlass: true);
    expect(events, ['first:top', 'first:top']);
  });

  reselectionTest('standard history retains repeat-tap refresh',
      (tester) async {
    home.currentIndex = 3;
    await home.onTap(3, useLiquidGlass: false);
    await home.onTap(3, useLiquidGlass: false);
    expect(events, ['first:top', 'first:refresh']);
  });

  reselectionTest('settings/downloads do not gain new actions', (tester) async {
    for (final mode in [false, true]) {
      for (final index in [4, 5]) {
        home.currentIndex = index;
        await home.onTap(index, useLiquidGlass: mode);
        await home.onTap(index, useLiquidGlass: mode);
      }
    }
    expect(events, isEmpty);
  });

  reselectionTest('missing/unattached/disposed targets cannot arm refresh',
      (tester) async {
    first.hasScrollClientsCall = () => false;
    await home.onTap(0, useLiquidGlass: false);
    first.hasScrollClientsCall = () => true;
    await home.onTap(0, useLiquidGlass: false);
    expect(events, ['first:top']);
    gallery.subControllerMap.clear();
    await home.onTap(0, useLiquidGlass: false);
    gallery.subControllerMap['first'] = _CustomPage(first);
    await home.onTap(0, useLiquidGlass: false);
    expect(events, ['first:top', 'first:top']);
    final disposed = _scrollTarget(events, 'disposed')..dispose();
    gallery.subControllerMap['first'] = _CustomPage(disposed);
    await home.onTap(0, useLiquidGlass: false);
    await home.onTap(0, useLiquidGlass: true);
    expect(events, ['first:top', 'first:top']);
  });

  reselectionTest(
      'resetIndex clears pending taps and keeps indices synchronized',
      (tester) async {
    await home.onTap(0, useLiquidGlass: false);
    home.resetIndex();
    expect(home.currentIndex, 5);
    expect(home.tabController.index, 5);
    await home.onTap(0, useLiquidGlass: false);
    await home.onTap(0, useLiquidGlass: false);
    expect(events, ['first:top', 'first:top']);
  });

  reselectionTest('invalid indices are safe and clear the pending pair',
      (tester) async {
    await home.onTap(0, useLiquidGlass: false);
    await home.onTap(-1, useLiquidGlass: false);
    await home.onTap(99, useLiquidGlass: false);
    await home.onTap(0, useLiquidGlass: false);
    expect(events, ['first:top', 'first:top']);
    expect(home.currentIndex, 0);
  });

  reselectionTest('closing the controller cancels its pending timer',
      (tester) async {
    await home.onTap(0, useLiquidGlass: false);
    await Get.delete<TabHomeController>();
    await tester.pump(const Duration(seconds: 1));
    expect(events, ['first:top']);
  });
}

EhTabController _scrollTarget(List<String> events, String name) =>
    EhTabController()
      ..scrollToTopCall = (() => events.add('$name:top'))
      ..scrollToTopRefreshCall = (() => events.add('$name:refresh'))
      ..scrollToTopAndRefreshCall = (() async => events.add('$name:combined'));

class _Settings extends EhSettingService {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Home extends TabHomeController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Gallery extends CustomTabbarController {
  @override
  // ignore: must_call_super
  void onInit() {
    pageController = PageController();
  }

  @override
  // ignore: must_call_super
  void onReady() {}
}

class _Favorites extends FavoriteTabBarController {
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  // ignore: must_call_super
  void onReady() {}
}

class _RestoringFavorites extends FavoriteTabBarController {
  _RestoringFavorites(int saved) : _saved = FavConfig(lastIndex: saved);
  FavConfig? _saved;
  @override
  FavConfig? get favConfig => _saved;
  @override
  set favConfig(FavConfig? value) => _saved = value;
  @override
  // ignore: must_call_super
  void onReady() {}
}

class _User extends GetxController implements UserController {
  bool loggedIn = true;
  @override
  bool get isLogin => loggedIn;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FavoriteSelector extends GetxController
    implements FavoriteSelectorController {
  List<Favcat> values = [
    const Favcat(favId: 'a', favTitle: 'All'),
    const Favcat(favId: '0', favTitle: 'Category'),
  ];
  @override
  List<Favcat> get favcatList => values;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Tag extends GetxController implements TagController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Webdav extends GetxController implements WebdavController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CustomPage extends GetxController implements CustomSubListController {
  _CustomPage(this.tabScrollController);
  @override
  EhTabController? tabScrollController;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FavoritePage extends GetxController
    implements FavoriteSubListController {
  _FavoritePage(this.tabScrollController);
  @override
  EhTabController? tabScrollController;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
