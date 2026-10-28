import 'dart:math' as math;

import 'package:eros_fe/adaptive/tab_navigation.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/debug/offline_glass.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/tab/controller/search_page_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import 'home_page_large.dart';

typedef TabDestinationBuilder = Widget Function(BuildContext, String route);

class TabHomeSmall extends StatefulWidget {
  const TabHomeSmall({super.key, this.split = false, this.destinationBuilder});

  final bool split;
  final TabDestinationBuilder? destinationBuilder;

  @override
  State<TabHomeSmall> createState() => _TabHomeSmallState();
}

class _TabHomeSmallState extends State<TabHomeSmall> {
  final LiquidGlassBarMotion _barMotion = LiquidGlassBarMotion();
  late final TabHomeController controller = Get.find<TabHomeController>();
  bool _publicationScheduled = false;
  NativeNavigationSource? _nativeSource;
  final Map<String, Widget> _tabRoots = {};
  final LayoutServices _layout = Get.find();
  late final TabNavigationRegistry _navigation = _layout.tabNavigation;

  @override
  void initState() {
    super.initState();
    controller.tabController.addListener(_tabSelectionChanged);
    _navigation.addListener(_publishNativeNavigationState);
    NativeNavigationBridge.chromeRevision
        .addListener(_publishNativeNavigationState);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_nativeSource?.route == route || route == null) return;
    _nativeSource?.dispose();
    _nativeSource = NativeNavigationBridge.attachSource(
      route: route,
      state: _nativeNavigationState,
      onSelectTab: (route) async => controller.selectRoute(route),
      onBack: () async {
        if (_layout.isLayoutLarge &&
            (_navigation.selected?.detailObserver.history.length ?? 0) > 1 &&
            NativeNavigationBridge.chromeFor(
                    _navigation.selected!.detailObserver.history.last) ==
                _currentChrome &&
            _currentChrome != null) {
          await Get.nestedKey(detailNavigatorId)!.currentState!.maybePop();
        } else {
          await controller.popLogicalRoute();
        }
      },
    );
  }

  @override
  void dispose() {
    controller.tabController.removeListener(_tabSelectionChanged);
    _nativeSource?.dispose();
    _navigation.removeListener(_publishNativeNavigationState);
    NativeNavigationBridge.chromeRevision
        .removeListener(_publishNativeNavigationState);
    controller.resetTabTapSequence();
    _barMotion.dispose();
    super.dispose();
  }

  void _handleTabTap(int index, {required bool useLiquidGlass}) {
    _barMotion.reset();
    controller.onTap(index, useLiquidGlass: useLiquidGlass);
  }

  void _tabSelectionChanged() {
    NativeNavigationBridge.rootBarCollapsed.value = false;
    _publishNativeNavigationState();
  }

  NativePageChrome? get _currentChrome {
    final stack = _navigation.selected;
    if (stack == null) return null;
    final details = stack.detailObserver.history;
    final primary = stack.primaryObserver.history;
    if (!_layout.isLayoutLarge && primary.length > 1 && !stack.detailOnTop) {
      return NativeNavigationBridge.chromeFor(primary.last);
    }
    if (details.length > 1) {
      return NativeNavigationBridge.chromeFor(details.last);
    }
    if (primary.length > 1) {
      return NativeNavigationBridge.chromeFor(primary.last);
    }
    return NativeNavigationBridge.chromeFor(primary.lastOrNull);
  }

  void _publishNativeNavigationState() {
    if (_publicationScheduled) return;
    _publicationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _publicationScheduled = false;
      if (!mounted) {
        return;
      }
      _nativeSource?.invalidate();
    });
  }

  NativeNavigationState _nativeNavigationState() {
    final route = controller.currRoute;
    final chrome = _currentChrome;
    final titles = tabPages.titlesOf(context);
    return NativeNavigationState.withChrome(
      chrome,
      tabId: route,
      selectedTabId: route,
      fallbackTitle: titles[route] ?? route,
      backTitle: L10n.of(context).back,
      canGoBack: (Get.key.currentState?.canPop() ?? false) ||
          (Get.nestedKey(primaryNavigatorId)?.currentState?.canPop() ??
              false) ||
          (Get.nestedKey(detailNavigatorId)?.currentState?.canPop() ?? false),
      tabs: controller.visibleTabRoutes
          .map(
            (tabRoute) => NativeNavigationTab(
              id: tabRoute,
              title: titles[tabRoute] ?? tabRoute,
              symbol: tabPages.liquidGlassFallbackSymbols[tabRoute],
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    controller.init(inContext: context);
    final EhSettingService ehSettingService = Get.find();

    return Obx(() {
      final useLiquidGlass =
          ehSettingService.liquidGlass && LiquidGlassPlatform.isSupported;
      controller.setNavigationMode(useLiquidGlass: useLiquidGlass);
      _publishNativeNavigationState();
      final tabBar = useLiquidGlass
          ? LiquidGlassTabBar(
              items: controller.listBottomNavigationBarItem,
              onTap: (index) =>
                  _handleTabTap(index, useLiquidGlass: useLiquidGlass),
              followSystemTransparency:
                  ehSettingService.liquidGlassFollowSystemTransparency,
              nativeItems: controller.liquidGlassTabItems,
              searchLabel: L10n.of(context).search,
              onSearch: () {
                final bool isFavorite =
                    controller.currRoute == EHRoutes.favorite ||
                        controller.currRoute == EHRoutes.favoriteTabbar;
                NavigatorUtil.goSearchPage(
                  searchType:
                      isFavorite ? SearchType.favorite : SearchType.normal,
                  fromTabItem: controller.tabMap[controller.currRoute] ?? false,
                );
              },
            )
          : CupertinoTabBar(
              backgroundColor: kEnableImpeller
                  ? CupertinoTheme.of(context).barBackgroundColor.withValues(
                        alpha: 1,
                      )
                  : null,
              items: controller.listBottomNavigationBarItem,
              onTap: (index) {
                vibrateUtil.light();
                _handleTabTap(index, useLiquidGlass: useLiquidGlass);
              },
            );

      return LiquidGlassBarMotionScope(
        motion: _barMotion,
        child: AnimatedBuilder(
          animation: Listenable.merge(
              [controller.tabController, controller.selectionRevision]),
          builder: (context, _) => _buildStableTabs(
            context,
            tabBar.copyWith(currentIndex: controller.currentIndex),
          ),
        ),
      );
    });
  }

  Widget _buildStableTabs(BuildContext context, CupertinoTabBar tabBar) {
    final nativeShellEnabled = NativeNavigationScope.isEnabled(context);
    final selected = controller.navigationIdentity;
    _navigation.select(selected);
    _tabRoots.putIfAbsent(
        selected,
        () =>
            widget.destinationBuilder?.call(context, controller.currRoute) ??
            tabPages.tabViews[controller.currRoute]!);
    final media = MediaQuery.of(context);
    final barHeight = nativeShellEnabled
        ? 0.0
        : tabBar.preferredSize.height + media.padding.bottom;
    final opaqueBar = !nativeShellEnabled && tabBar.opaque(context);
    final contentBottom =
        math.max(media.viewInsets.bottom, opaqueBar ? barHeight : 0.0);
    var contentMedia = media.removeViewInsets(removeBottom: true);
    if (opaqueBar && barHeight > media.viewInsets.bottom) {
      contentMedia = contentMedia.removePadding(removeBottom: true);
    } else if (barHeight > media.viewInsets.bottom) {
      contentMedia = contentMedia.copyWith(
          padding: media.padding.copyWith(bottom: barHeight));
    }
    final source = AdaptiveEnvironment.maybeOf(context) ??
        AdaptiveEnvironmentSnapshot.fromMediaQuery(context);
    final rect = Rect.fromLTWH(0, 0, source.size.width,
        math.max(0.0, source.size.height - contentBottom));
    final environment = source.inRect(rect).copyWithGeometry(
          safeArea: contentMedia.padding,
          viewPadding: contentMedia.viewPadding,
          viewInsets: contentMedia.viewInsets,
        );
    return offlineDuoNavigationProbe(
        child: ColoredBox(
      color: CupertinoTheme.of(context).scaffoldBackgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fromRect(
            rect: rect,
            child: AdaptiveEnvironmentScope(
              snapshot: environment,
              child: MediaQuery(
                data: contentMedia.copyWith(size: rect.size),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    for (final entry in _tabRoots.entries)
                      RetainedTab(
                        key: ValueKey(entry.key),
                        active: entry.key == selected,
                        child: AdaptiveTabNavigator(
                          stack: _navigation.stackFor(entry.key),
                          split: widget.split,
                          primaryRoot: entry.value,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (!nativeShellEnabled)
            Align(
              alignment: Alignment.bottomCenter,
              child: MediaQuery.withNoTextScaling(child: tabBar),
            ),
        ],
      ),
    ));
  }
}
