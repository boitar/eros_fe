import 'dart:math' as math;

import 'package:eros_fe/adaptive/browse_layout.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/adaptive/tab_navigation.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/debug/offline_glass.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/tab/controller/group/custom_tabbar_controller.dart';
import 'package:eros_fe/pages/tab/controller/search_page_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/android_navigation_rail.dart';
import 'package:eros_fe/widget/canvas_grain.dart';
import 'package:eros_fe/widget/desktop_sidebar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'home_page_large.dart';

typedef TabDestinationBuilder = Widget Function(BuildContext, String route);

/// Android list/detail layouts move the destinations into a rail on the left
/// instead of a bar under both panes.
bool usesAndroidNavigationRail({
  required bool split,
  required AdaptiveEnvironmentSnapshot environment,
}) =>
    PlatformCapabilities.topSearchCapsule && split && environment.isSplit;

/// Android gives a pushed page (detail, search, a group) the whole screen,
/// so the tab bar slides away while [stack] holds a page above its roots.
/// A single column opens details in the detail stack and other pages in the
/// primary stack, so either counts. Split layouts keep the bar.
bool hidesTabBarForPushedPage(
  TabNavigationStack? stack, {
  required bool layoutLarge,
}) {
  if (!PlatformCapabilities.topSearchCapsule || layoutLarge || stack == null) {
    return false;
  }
  return stack.primaryObserver.history.length > 1 ||
      stack.detailObserver.history.length > 1;
}

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

  /// Each tab's navigators outlive any change in what wraps them, so their
  /// owner moves along instead of being rebuilt: a new owner would clear the
  /// pages on record while the old pages stay on screen.
  final Map<String, GlobalKey> _tabNavigators = {};
  final LayoutServices _layout = Get.find();
  late final TabNavigationRegistry _navigation = _layout.tabNavigation;

  @override
  void initState() {
    super.initState();
    // Warm the haptic engine so the first tab switch isn't late.
    vibrateUtil.prepareHaptics();
    controller.tabController.addListener(_tabSelectionChanged);
    _navigation.addListener(_publishNativeNavigationState);
    NativeNavigationBridge.chromeRevision
        .addListener(_publishNativeNavigationState);
    HardwareKeyboard.instance.addHandler(_handleDesktopShortcut);
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
      // The system tab bar gives no feedback of its own.
      onSelectTab: (route) async {
        vibrateUtil.tabSwitch();
        await controller.selectRoute(route);
      },
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
    HardwareKeyboard.instance.removeHandler(_handleDesktopShortcut);
    super.dispose();
  }

  /// Whether the last build showed the desktop sidebar, whose search field
  /// answers ⌘F / Ctrl+F.
  bool _sidebarShown = false;

  bool _handleDesktopShortcut(KeyEvent event) {
    if (!_sidebarShown || event is! KeyDownEvent || !mounted) {
      return false;
    }
    if (!DesktopSidebar.searchShortcut
        .accepts(event, HardwareKeyboard.instance)) {
      return false;
    }
    _openSearch();
    return true;
  }

  void _openSearch() {
    final bool isFavorite = controller.currRoute == EHRoutes.favorite ||
        controller.currRoute == EHRoutes.favoriteTabbar;
    NavigatorUtil.goSearchPage(
      searchType: isFavorite ? SearchType.favorite : SearchType.normal,
      fromTabItem: controller.tabMap[controller.currRoute] ?? false,
    );
  }

  Widget _buildDesktopSidebar(BuildContext context, CupertinoTabBar tabBar,
      {required bool glass}) {
    final l10n = L10n.of(context);
    void selectTab(int index) {
      vibrateUtil.tabSwitch();
      tabBar.onTap?.call(index);
    }

    Widget sidebar(
            List<DesktopSidebarGroup> groups, ValueChanged<int>? onGroupTap) =>
        DesktopSidebar(
          routes: controller.visibleTabRoutes,
          items: tabBar.items,
          currentIndex: tabBar.currentIndex,
          onTap: selectTab,
          glass: glass,
          searchLabel: l10n.search,
          onSearch: _openSearch,
          browseLabel: l10n.setting_group_browse,
          libraryLabel: l10n.sidebar_library,
          groupsLabel: l10n.group,
          groups: groups,
          onGroupTap: onGroupTap,
        );
    if (!Get.isRegistered<CustomTabbarController>()) {
      return sidebar(const <DesktopSidebarGroup>[], null);
    }
    final groups = Get.find<CustomTabbarController>();
    return Obx(() {
      final onGallery = controller.currRoute == EHRoutes.gallery;
      final profiles = groups.profilesShow;
      return sidebar(
        <DesktopSidebarGroup>[
          for (var index = 0; index < profiles.length; index++)
            DesktopSidebarGroup(
              title: profiles[index].name,
              selected: onGallery && index == groups.index,
            ),
        ],
        (index) {
          final gallery =
              controller.visibleTabRoutes.indexOf(EHRoutes.gallery);
          if (!onGallery && gallery >= 0) {
            selectTab(gallery);
          }
          groups.selectPage(index);
        },
      );
    });
  }

  void _handleTabTap(int index, {required bool useLiquidGlass}) {
    _barMotion.reset();
    controller.onTap(index, useLiquidGlass: useLiquidGlass);
  }

  void _tabSelectionChanged() {
    NativeNavigationBridge.rootBarCollapsed.value = false;
    _publishNativeNavigationState();
  }

  /// Android gives a pushed page (detail, search, a group) the whole screen,
  /// so its own bottom controls never sit on top of the tab bar.
  bool get _hidesBarForPushedPage => hidesTabBarForPushedPage(
        _navigation.selected,
        layoutLarge: _layout.isLayoutLarge,
      );

  NativePageChrome? get _currentChrome {
    final stack = _navigation.selected;
    if (stack == null) return null;
    final details = stack.detailObserver.history;
    final primary = stack.primaryObserver.history;
    if (!_layout.isLayoutLarge && primary.length > 1 && !stack.detailOnTop) {
      return pushedPageChrome(primary.last);
    }
    if (details.length > 1) {
      return pushedPageChrome(details.last);
    }
    if (primary.length > 1) {
      return pushedPageChrome(primary.last);
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
      final useLiquidGlass = ehSettingService.liquidGlass &&
          (GlassMode.of(context).forComponent(flutterImplemented: true) !=
              GlassMode.off);
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
              // Android searches from the capsule at the top of list pages.
              onSearch: PlatformCapabilities.topSearchCapsule
                  ? null
                  : () {
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
          : PlatformCapabilities.topSearchCapsule
              ? AndroidNavigationBar(
                  items: controller.listBottomNavigationBarItem,
                  onTap: (index) {
                    vibrateUtil.tabSwitch();
                    _handleTabTap(index, useLiquidGlass: useLiquidGlass);
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
                vibrateUtil.tabSwitch();
                _handleTabTap(index, useLiquidGlass: useLiquidGlass);
              },
            );

      return LiquidGlassBarMotionScope(
        motion: _barMotion,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            controller.tabController,
            controller.selectionRevision,
            // Pushes and pops decide whether Android shows the bar. Other
            // hosts keep their original rebuild triggers.
            if (PlatformCapabilities.topSearchCapsule) _navigation,
          ]),
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
    final source = AdaptiveEnvironment.maybeOf(context) ??
        AdaptiveEnvironmentSnapshot.fromMediaQuery(context);
    final androidRail = !nativeShellEnabled &&
        usesAndroidNavigationRail(split: widget.split, environment: source);
    final sidebarMode = !nativeShellEnabled &&
        !androidRail &&
        usesDesktopSidebar(environment: source);
    _sidebarShown = sidebarMode;
    // Either takes the destinations off the bottom edge to the left.
    final railMode = androidRail || sidebarMode;
    final glassRail = tabBar is LiquidGlassTabBar;
    final railWidth = sidebarMode
        ? DesktopSidebar.reservedWidth(glass: glassRail)
        : railMode
            ? AndroidNavigationRail.reservedWidth(
                glass: glassRail,
                leftInset: media.padding.left,
              )
            : 0.0;
    final barHidden =
        !nativeShellEnabled && !railMode && _hidesBarForPushedPage;
    final barHeight = nativeShellEnabled || barHidden || railMode
        ? 0.0
        : tabBar.preferredSize.height + media.padding.bottom;
    final opaqueBar = !nativeShellEnabled &&
        !barHidden &&
        !railMode &&
        tabBar.opaque(context);
    final contentBottom =
        math.max(media.viewInsets.bottom, opaqueBar ? barHeight : 0.0);
    var contentMedia = media.removeViewInsets(removeBottom: true);
    if (railMode) {
      // The rail covers the left edge, cutout included.
      contentMedia = contentMedia.removePadding(removeLeft: true);
    }
    if (opaqueBar && barHeight > media.viewInsets.bottom) {
      contentMedia = contentMedia.removePadding(removeBottom: true);
    } else if (barHeight > media.viewInsets.bottom) {
      contentMedia = contentMedia.copyWith(
          padding: contentMedia.padding.copyWith(bottom: barHeight));
    }
    final rect = Rect.fromLTWH(
        railWidth,
        0,
        math.max(0.0, source.size.width - railWidth),
        math.max(0.0, source.size.height - contentBottom));
    final environment = source.inRect(rect).copyWithGeometry(
          safeArea: contentMedia.padding,
          viewPadding: contentMedia.viewPadding,
          viewInsets: contentMedia.viewInsets,
        );
    return offlineDuoNavigationProbe(
        child: ColoredBox(
      color: CupertinoTheme.of(context).scaffoldBackgroundColor,
      // Shows through the transparent list pages of the glass layout.
      child: CanvasGrain(
          child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fromRect(
            rect: rect,
            child: AdaptiveEnvironmentScope(
              snapshot: environment,
              child: MediaQuery(
                data: contentMedia.copyWith(size: rect.size),
                child: DesktopSidebarScope(
                  visible: sidebarMode,
                  child: Stack(
                  fit: StackFit.expand,
                  children: [
                    for (final entry in _tabRoots.entries)
                      RetainedTab(
                        key: ValueKey(entry.key),
                        active: entry.key == selected,
                        child: AdaptiveTabNavigator(
                          key: _tabNavigators.putIfAbsent(
                              entry.key, GlobalKey.new),
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
          ),
          if (sidebarMode)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: railWidth,
              child: _buildDesktopSidebar(context, tabBar, glass: glassRail),
            )
          else if (railMode)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: railWidth,
              child: MediaQuery.withNoTextScaling(
                child: AndroidNavigationRail(
                  items: tabBar.items,
                  currentIndex: tabBar.currentIndex,
                  glass: glassRail,
                  onTap: (index) {
                    // The solid bar's own handler already ticks.
                    if (glassRail) {
                      vibrateUtil.tabSwitch();
                    }
                    tabBar.onTap?.call(index);
                  },
                ),
              ),
            )
          else if (!nativeShellEnabled && PlatformCapabilities.hostPlatform == TargetPlatform.macOS && widget.split && source.isSplit)
            Obx(()=>Positioned(bottom:0,left:source.contentRect.left,
              width:AdaptiveBrowseLayout.primaryPaneWidth(source.contentRect.width,Get.find<LayoutServices>().sideProportion),
              child:MediaQuery.withNoTextScaling(child:tabBar)))
          else if (!nativeShellEnabled && !PlatformCapabilities.topSearchCapsule)
            // Only Android hides the bar for pushed pages; elsewhere keep the
            // bar's original tree so its taps behave exactly as before.
            Align(
              alignment: Alignment.bottomCenter,
              child: MediaQuery.withNoTextScaling(child: tabBar),
            )
          else if (!nativeShellEnabled)
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedSlide(
                key: const ValueKey<String>('tab-bar-slide'),
                offset: barHidden ? const Offset(0, 1.5) : Offset.zero,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: IgnorePointer(
                  ignoring: barHidden,
                  child: ExcludeSemantics(
                    excluding: barHidden,
                    child: MediaQuery.withNoTextScaling(child: tabBar),
                  ),
                ),
              ),
            ),
        ],
      )),
    ));
  }
}
