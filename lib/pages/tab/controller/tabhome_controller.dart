import 'dart:async';

import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/tab/controller/favorite/favorite_tabbar_controller.dart';
import 'package:eros_fe/pages/tab/controller/group/custom_tabbar_controller.dart';
import 'package:eros_fe/pages/tab/view/download_page.dart';
import 'package:eros_fe/pages/tab/view/history_page.dart';
import 'package:eros_fe/pages/tab/view/tabbar/custom_tabbar_page.dart';
import 'package:eros_fe/pages/tab/view/tabbar/favorite_tabbar_page.dart';
import 'package:eros_fe/pages/tab/view/toplist_page.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

import '../../../common/service/layout_service.dart';
import '../comm.dart';
import '../view/setting_page.dart';

const double kIconSize = 24.0;
final TabPages tabPages = TabPages();

class TabPages {
  final Map<String, EhTabController?> scrollControllerMap = {};

  Map<String, Widget> get tabViews => <String, Widget>{
        EHRoutes.gallery: const CustomTabbarList(),
        EHRoutes.favorite: const FavoriteTabTabBarPage(),
        EHRoutes.toplist: const ToplistTab(),
        // EHRoutes.toplist: const ToplistTabDebug(),
        EHRoutes.history: const HistoryTab(),
        EHRoutes.download: const DownloadTab(),
        EHRoutes.setting: const SettingTab(),
      };

  final Map<String, FaIconData> iconDatas = <String, FaIconData>{
    EHRoutes.popular: FontAwesomeIcons.fire,
    EHRoutes.watched: FontAwesomeIcons.solidEye,
    // EHRoutes.gallery: FontAwesomeIcons.jira,
    EHRoutes.gallery: FontAwesomeIcons.layerGroup,
    EHRoutes.favorite: FontAwesomeIcons.solidHeart,
    EHRoutes.toplist: FontAwesomeIcons.listOl,
    EHRoutes.history: FontAwesomeIcons.history,
    EHRoutes.download: FontAwesomeIcons.download,
    EHRoutes.setting: FontAwesomeIcons.cog,
    EHRoutes.customList: FontAwesomeIcons.layerGroup,
    EHRoutes.favoriteTabbar: FontAwesomeIcons.heartBroken,
  };

  final Map<String, String> liquidGlassFallbackSymbols = <String, String>{
    EHRoutes.popular: 'flame.fill',
    EHRoutes.watched: 'eye.fill',
    EHRoutes.gallery: 'square.grid.2x2.fill',
    EHRoutes.favorite: 'heart.fill',
    EHRoutes.toplist: 'list.number',
    EHRoutes.history: 'clock.arrow.circlepath',
    EHRoutes.download: 'arrow.down.circle.fill',
    EHRoutes.setting: 'gearshape.fill',
    EHRoutes.customList: 'square.grid.2x2.fill',
    EHRoutes.favoriteTabbar: 'heart.slash.fill',
  };

  Map<String, Widget> get tabIcons => iconDatas
      .map((key, value) => MapEntry(key, FaIcon(value, size: kIconSize)));

  Map<String, String> get tabTitles => titlesOf(
      Get.key.currentContext ?? Get.find<TabHomeController>().tContext);

  Map<String, String> titlesOf(BuildContext context) => <String, String>{
        EHRoutes.popular: L10n.of(context).tab_popular,
        EHRoutes.watched: L10n.of(context).tab_watched,
        EHRoutes.gallery: L10n.of(context).tab_gallery,
        EHRoutes.favorite: L10n.of(context).tab_favorite,
        EHRoutes.toplist: L10n.of(context).tab_toplist,
        EHRoutes.history: L10n.of(context).tab_history,
        EHRoutes.download: L10n.of(context).tab_download,
        EHRoutes.setting: L10n.of(context).tab_setting,
        EHRoutes.customList: L10n.of(context).tab_gallery,
        EHRoutes.favoriteTabbar: L10n.of(context).tab_favorite,
      };
}

// 默认显示在tabbar的view
Map<String, bool> kDefTabMap = <String, bool>{
  // EHRoutes.popular: true,
  // EHRoutes.watched: false,
  EHRoutes.gallery: true,
  // EHRoutes.favoriteTabbar: true,
  EHRoutes.favorite: true,
  EHRoutes.toplist: true,
  EHRoutes.download: true,
  EHRoutes.history: false,
  // EHRoutes.customlist: false,
};

// 启用的项目以及默认显示顺序 ?
List<String> kTabNameList = <String>[
  EHRoutes.gallery,
  // EHRoutes.popular,
  // EHRoutes.customlist,
  // EHRoutes.watched,
  // EHRoutes.favoriteTabbar,
  EHRoutes.favorite,
  EHRoutes.toplist,
  EHRoutes.download,
  EHRoutes.history,
];

/// TabHome布局控制器
class TabHomeController extends GetxController {
  TabHomeController();

  DateTime? lastPressedAt; //上次点击时间

  String _selectedRoute = EHRoutes.gallery;

  int get currentIndex => _showTabs.indexOf(currRoute);
  set currentIndex(int index) {
    final tabs = _showTabs;
    final route = tabs[index.clamp(0, tabs.length - 1)];
    if (_selectedRoute != route) {
      _selectedRoute = route;
      _syncNavigationSelection();
      selectionRevision.value++;
    }
  }

  // Route identity can change without a numeric index change after safe mode
  // or tab configuration changes.
  final ValueNotifier<int> selectionRevision = ValueNotifier(0);
  Timer? _reselectionTimer;
  String? _reselectionRoute;
  EhTabController? _reselectionController;
  bool? _useLiquidGlass;

  final EhSettingService _ehSettingService = Get.find();

  bool get isSafeMode => _ehSettingService.isSafeMode.value;

  final CupertinoTabController tabController = CupertinoTabController();

  String get currRoute =>
      _showTabs.contains(_selectedRoute) ? _selectedRoute : _showTabs.first;

  // Safe mode never exposes routes retained by the normal browsing session.
  String get navigationIdentity => isSafeMode ? 'safe:$currRoute' : currRoute;

  List<String> get visibleTabRoutes => List<String>.unmodifiable(_showTabs);

  // 需要显示的tab
  List<String> get _showTabs => isSafeMode
      ? <String>[
          EHRoutes.gallery,
          EHRoutes.setting,
        ]
      : _sortedTabList;

  List<String> get _sortedTabList {
    final List<String> _list = <String>[];
    for (final String key in tabNameList) {
      if (tabMap[key] ?? false) {
        _list.add(key);
      }
    }
    if (_list.isEmpty) {
      _list.add(EHRoutes.gallery);
    }
    // setting 必须保留
    _list.add(EHRoutes.setting);
    return _list;
  }

  // 控制tab项顺序
  RxList<String> tabNameList = kTabNameList.obs;

  // 通过控制该变量控制tab项的开关
  RxMap<String, bool> tabMap = kDefTabMap.obs;

  late TabConfig _tabConfig;

  @override
  void onInit() {
    super.onInit();

    _tabConfig = Global.profile.tabConfig ?? (const TabConfig(tabItemList: []));

    if (_tabConfig.tabMap.isNotEmpty) {
      final List<String> _tabConfigNames =
          _tabConfig.tabItemList.map((e) => e.name).toList();

      final List<String> _addTabs = kTabNameList
          .where((String element) => !_tabConfigNames.contains(element))
          .toList();

      final _subTabs = _tabConfigNames
          .where((element) => !kTabNameList.contains(element))
          .toList();

      // logger.d('sub tab $_subTabs');

      for (final viewName in _subTabs) {
        _tabConfig.tabItemList
            .removeWhere((element) => element.name == viewName);
      }

      // 新增tab页的处理
      // logger.d('add tab $_addTabs');

      for (final viewName in _addTabs) {
        _tabConfig.tabItemList.add(TabItem(name: viewName, enable: false));
      }

      tabMap(_tabConfig.tabMap);
    }

    if (_tabConfig.tabNameList.isNotEmpty) {
      _tabConfig.tabNameList
          .removeWhere((element) => element == EHRoutes.setting);
      tabNameList(_tabConfig.tabNameList);
    }

    // logger.d('${tabNameList}');

    ever(tabMap, (Map<String, bool> map) {
      _syncSelectedTab();
      updateItemList(map, tabNameList);

      Global.profile = Global.profile.copyWith(tabConfig: _tabConfig.oN);
      Global.saveProfile();

      logger.d(
          '${_tabConfig.tabItemList.map((e) => '${e.name}:${e.enable}').toList().join('\n')} ');
    });

    ever(tabNameList, (List<String> nameList) {
      _syncSelectedTab();
      updateItemList(tabMap, nameList);

      Global.profile = Global.profile.copyWith(tabConfig: _tabConfig.oN);
      Global.saveProfile();

      logger.d(
          '${_tabConfig.tabItemList.map((e) => '${e.name}:${e.enable}').toList().join('\n')} ');
    });
  }

  void _syncSelectedTab() {
    resetTabTapSequence();
    _selectedRoute = currRoute;
    tabController.index = currentIndex;
    _syncNavigationSelection();
  }

  void _syncNavigationSelection() {
    if (Get.isRegistered<LayoutServices>() && usesAdaptiveNavigation) {
      Get.find<LayoutServices>().tabNavigation.select(navigationIdentity);
    }
  }

  void updateItemList(Map<String, bool> map, List<String> nameList) {
    final tabItemList = <TabItem>[];
    for (final String name in nameList) {
      tabItemList.add(TabItem(name: name, enable: map[name] ?? false));
    }
    _tabConfig = _tabConfig.copyWith(tabItemList: tabItemList);
  }

  List<BottomNavigationBarItem> get listBottomNavigationBarItem => _showTabs
      .map((e) => BottomNavigationBarItem(
            icon: tabPages.tabIcons[e]!,
            label: tabPages.tabTitles[e],
          ))
      .toList();

  List<LiquidGlassTabItem> get liquidGlassTabItems => _showTabs.map((route) {
        final FaIconData icon = tabPages.iconDatas[route]!;
        return LiquidGlassTabItem(
          label: tabPages.tabTitles[route] ?? route,
          codePoint: icon.codePoint,
          fontFamily: icon.fontFamily,
          fontPackage: icon.fontPackage,
          fallbackSymbol:
              tabPages.liquidGlassFallbackSymbols[route] ?? 'circle.fill',
        );
      }).toList();

  List<NativeNavigationAction> get nativeHiddenTabActions {
    if (isSafeMode) return const [];
    return [
      for (final route in tabNameList)
        if (!(tabMap[route] ?? false))
          NativeNavigationAction(
            id: 'destination:$route',
            title: tabPages.tabTitles[route] ?? route,
            symbol: tabPages.liquidGlassFallbackSymbols[route],
            onPressed: () async {
              await Get.toNamed<void>(route, id: primaryNavigatorId);
            },
          ),
    ];
  }

  late BuildContext tContext;

  /// 需要初始化获取BuildContext 否则修改语言时 tabitem 的文字不会立即生效
  void init({required BuildContext inContext}) {
    // logger.d(' rebuild home');
    tContext = inContext;
  }

  List<Widget> get viewList =>
      _showTabs.map((e) => tabPages.tabViews[e]!).toList();

  List<EhTabController?> get scrollControllerList =>
      _showTabs.map((e) => tabPages.scrollControllerMap[e]).toList();

  void resetTabTapSequence() {
    _reselectionTimer?.cancel();
    _reselectionTimer = null;
    _reselectionRoute = null;
    _reselectionController = null;
  }

  void setNavigationMode({required bool useLiquidGlass}) {
    if (_useLiquidGlass != useLiquidGlass) {
      resetTabTapSequence();
      _useLiquidGlass = useLiquidGlass;
    }
  }

  EhTabController? _currentPageScrollController(String route) {
    switch (route) {
      case EHRoutes.gallery:
        return Get.isRegistered<CustomTabbarController>()
            ? Get.find<CustomTabbarController>().currentPageScrollController
            : null;
      case EHRoutes.favorite:
        return Get.isRegistered<FavoriteTabBarController>()
            ? Get.find<FavoriteTabBarController>().currentPageScrollController
            : null;
      default:
        return tabPages.scrollControllerMap[route];
    }
  }

  Future<void> onTap(int index, {required bool useLiquidGlass}) async {
    setNavigationMode(useLiquidGlass: useLiquidGlass);
    final tabs = _showTabs;
    if (index < 0 || index >= tabs.length) {
      resetTabTapSequence();
      return;
    }
    if (index != currentIndex) {
      resetTabTapSequence();
      currentIndex = index;
      _syncNavigationSelection();
      if (tabController.index != index) {
        tabController.index = index;
      }
      return;
    }

    final route = tabs[index];
    // Like UITabBarController, reselecting a tab first returns to its root;
    // the next reselect scrolls or refreshes it.
    if (_popSelectedTabToRoot()) {
      resetTabTapSequence();
      return;
    }
    if (route == EHRoutes.setting) {
      resetTabTapSequence();
      return;
    }

    if (!useLiquidGlass) {
      final target = _currentPageScrollController(route);
      if (target == null || !target.canScrollToTop) {
        resetTabTapSequence();
        return;
      }
      if ((_reselectionTimer?.isActive ?? false) &&
          _reselectionRoute == route &&
          identical(_reselectionController, target)) {
        resetTabTapSequence();
        target.scrollToTopRefresh();
      } else {
        resetTabTapSequence();
        _reselectionRoute = route;
        _reselectionController = target;
        _reselectionTimer = Timer(
          const Duration(milliseconds: 800),
          resetTabTapSequence,
        );
        target.scrollToTop();
      }
      return;
    }

    resetTabTapSequence();
    switch (route) {
      case EHRoutes.gallery:
        if (Get.isRegistered<CustomTabbarController>()) {
          await Get.find<CustomTabbarController>().reselectCurrentPage();
        }
        return;
      case EHRoutes.favorite:
        if (Get.isRegistered<FavoriteTabBarController>()) {
          await Get.find<FavoriteTabBarController>().reselectCurrentPage();
        }
        return;
      case EHRoutes.toplist:
        await scrollControllerList[index]?.scrollToTopAndRefresh();
        return;
      default:
        scrollControllerList[index]?.scrollToTop();
    }
  }

  /// Pops the selected tab's pages that cover its root. A split layout shows
  /// the detail pane beside the root, so only the primary column pops there.
  bool _popSelectedTabToRoot() {
    if (!usesAdaptiveNavigation) {
      return false;
    }
    final layout = Get.find<LayoutServices>();
    final stack = layout.tabNavigation.selected;
    if (stack == null) {
      return false;
    }
    final ids = layout.isLayoutLarge
        ? <int>[stack.primaryId]
        : <int>[stack.detailId, stack.primaryId];
    var popped = false;
    for (final id in ids) {
      final navigator = Get.nestedKey(id)?.currentState;
      if (navigator != null && navigator.canPop()) {
        navigator.popUntil((route) => route.isFirst);
        popped = true;
      }
    }
    return popped;
  }

  void resetIndex() {
    resetTabTapSequence();
    final int last = _showTabs.length;
    currentIndex = last - 1;
    tabController.index = currentIndex;
  }

  /// Selects a logical tab requested by the optional native UIKit shell.
  ///
  /// The shell never owns the Flutter route stack; it only mirrors this
  /// controller's selection.
  Future<void> selectRoute(String route) async {
    final index = _showTabs.indexOf(route);
    if (index < 0 || index >= _showTabs.length) {
      return;
    }
    await onTap(index, useLiquidGlass: _useLiquidGlass ?? false);
  }

  @override
  void onClose() {
    resetTabTapSequence();
    tabController.dispose();
    selectionRevision.dispose();
    super.onClose();
  }

  /// 连按两次返回退出
  Future<bool> doubleClickBack() async {
    logger.t('click back');
    if (lastPressedAt == null ||
        DateTime.now().difference(lastPressedAt ?? DateTime.now()) >
            const Duration(seconds: 1)) {
      showToast(L10n.of(tContext).double_click_back);
      //两次点击间隔超过1秒则重新计时
      lastPressedAt = DateTime.now();
      return false;
    }
    return true;
  }

  Future<bool> onWillPop() async {
    return await popLogicalRoute() ? false : await doubleClickBack();
  }

  Future<bool> popLogicalRoute() async {
    final primaryOnTop = usesAdaptiveNavigation &&
        !(Get.find<LayoutServices>().tabNavigation.selected?.detailOnTop ??
            false);
    final order = primaryOnTop
        ? <int?>[primaryNavigatorId, detailNavigatorId]
        : <int?>[detailNavigatorId, primaryNavigatorId];
    for (final id in order) {
      if (id == null) continue;
      final navigator = Get.nestedKey(id)?.currentState;
      if (navigator != null && navigator.canPop()) {
        return navigator.maybePop();
      }
    }
    return false;
  }

  Future<void> onPopInvoked(bool didPop) async {
    logger.d('onPopInvoked $didPop');
  }
}
