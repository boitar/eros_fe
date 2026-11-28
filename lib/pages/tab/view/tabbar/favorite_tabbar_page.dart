import 'package:blur/blur.dart';
import 'package:eros_fe/adaptive/native_top_header.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/debug/offline_glass.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/tab/controller/favorite/favorite_selection_controller.dart';
import 'package:eros_fe/pages/tab/controller/favorite/favorite_tabbar_controller.dart';
import 'package:eros_fe/pages/tab/controller/search_page_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/pages/tab/view/favorite_batch_widgets.dart';
import 'package:eros_fe/pages/tab/view/hidden_tabs_rail_action.dart';
import 'package:eros_fe/pages/tab/view/top_bar_layout_reset.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/canvas_grain.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:eros_fe/widget/liquid_glass_scroll_controller.dart';
import 'package:eros_fe/widget/scroll_edge_progress.dart';
import 'package:eros_fe/widget/segmented_rail.dart';
import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:keframe/keframe.dart';

import '../../comm.dart';
import '../constants.dart';
import 'favorite_sub_page.dart';

class FavoriteTabTabBarPage extends StatefulWidget {
  const FavoriteTabTabBarPage({super.key});

  @override
  State<FavoriteTabTabBarPage> createState() => _FavoriteTabTabBarPageState();
}

class _FavoriteTabTabBarPageState extends State<FavoriteTabTabBarPage>
    with TopBarLayoutReset<FavoriteTabTabBarPage> {
  @override
  void resetForTopBarLayout() {
    for (final sub in controller.subControllerMap.values) {
      sub.galleryAnchor.forget();
    }
    _topState.jumpToInitialAnchor();
  }

  final EhTabController ehTabController = EhTabController();
  final LinkScrollBarController linkScrollBarController =
      LinkScrollBarController();
  final controller = Get.find<FavoriteTabBarController>();
  final FavoriteSelectionController _selection = FavoriteSelectionController();
  final FavoriteSelectableRegistry _selectionRegistry =
      FavoriteSelectableRegistry();
  late PageController pageController;

  final _headerScrollController = LiquidGlassScrollController();
  final _nativeEdgeProgress = ScrollEdgeProgressController(
    revealDistance: LiquidGlassEdgeTokens.reveal,
  );
  final GlobalKey<ExtendedNestedScrollViewState> _nestedScrollKey =
      GlobalKey<ExtendedNestedScrollViewState>();
  final Map<String, GlobalKey> _firstCardKeys = <String, GlobalKey>{};
  late final LiquidGlassTopStateCoordinator _topState =
      LiquidGlassTopStateCoordinator(
        scrollController: _headerScrollController,
        additionalPositions: () =>
            _nestedScrollKey.currentState?.innerPositions ??
            const <ScrollPosition>[],
        firstCardTopProvider: _currentFirstCardTop,
        firstCardRestTopProvider: () => _currentFirstCardTop(visual: true),
      );

  @override
  void dispose() {
    _selection.onClose();
    _topState.dispose();
    _nativeEdgeProgress.dispose();
    _headerScrollController.dispose();
    super.dispose();
  }

  List<GalleryProvider> _loadedItemsForCurrentTab() {
    return controller.subControllerMap[controller.currFavcat]?.state ??
        const <GalleryProvider>[];
  }

  Favcat? _currentFavcatModel() {
    final id = controller.currFavcat;
    for (final fav in controller.favcatList) {
      if (fav.favId == id) {
        return fav;
      }
    }
    return null;
  }

  void _enterSelection() {
    _selection.enter();
  }

  void _removeFromCurrentTab(Set<String> gids) {
    controller.subControllerMap[controller.currFavcat]?.removeGidsLocally(gids);
  }

  Future<void> _onBatchMove() async {
    await runBatchMoveFlow(
      context: context,
      selection: _selection,
      currentFavcat: controller.currFavcat,
      onRemoveFromCurrentView: _removeFromCurrentTab,
      onRefreshCurrentView: () => controller.reloadData(),
    );
  }

  Future<void> _onBatchRemove() async {
    await runBatchRemoveFlow(
      context: context,
      selection: _selection,
      currentFavcat: controller.currFavcat,
      onRemoveFromCurrentView: _removeFromCurrentTab,
    );
  }

  Widget _buildSelectionHeader(BuildContext context, {double? height}) {
    final currentFav = _currentFavcatModel();
    final loaded = _loadedItemsForCurrentTab();
    final scopeTitle = currentFav?.favTitle ?? L10n.of(context).all_Favorites;
    final totalCount = currentFav?.totNum ?? loaded.length;
    return FavSelectionHeader(
      selection: _selection,
      scopeTitle: scopeTitle,
      scopeFavId: controller.currFavcat,
      totalCount: totalCount,
      loadedItemsProvider: _loadedItemsForCurrentTab,
      height: height,
    );
  }

  final EhSettingService _ehSettingService = Get.find();

  @override
  void initState() {
    super.initState();
    pageController = PageController(initialPage: controller.index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _synchronizePageWithSelectedIndex();
      if (_useLiquidGlass) {
        _topState.refresh();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _topState.attachBarMotion(LiquidGlassBarMotionScope.maybeOf(context));
  }

  bool get _useLiquidGlass =>
      _ehSettingService.liquidGlass &&
      (GlassMode.of(context).forComponent(flutterImplemented: true) !=
          GlassMode.off) &&
      !NativeNavigationBridge.enabled.value;

  GlobalKey _firstCardKeyFor(String favId) =>
      _firstCardKeys.putIfAbsent(favId, () => GlobalKey());

  double? _currentFirstCardTop({bool visual = false}) {
    final favcats = controller.favcatList;
    if (favcats.isEmpty) {
      return null;
    }
    final index = controller.index.clamp(0, favcats.length - 1).toInt();
    return visual ? liquidGlassCardScreenTop(_firstCardKeyFor(favcats[index].favId)) : liquidGlassScreenTop(_firstCardKeyFor(favcats[index].favId));
  }

  Future<void> _scrollToInitialContentAnchor() async {
    if (_useLiquidGlass) {
      await _topState.resetToInitialAnchor();
      return;
    }
    if (_headerScrollController.hasClients) {
      await _headerScrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.ease,
      );
    }
  }

  Future<void> _selectFavoriteCategory(int index) async {
    await _scrollToInitialContentAnchor();
    if (pageController.hasClients) {
      // Selected at once, like a gallery group, so the rail answers the tap
      // instead of following the page through every category on the way.
      controller.onPageChanged(index);
      controller.landingPage = index;
      try {
        await pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      } finally {
        if (controller.landingPage == index) {
          controller.landingPage = null;
        }
      }
    }
    await WidgetsBinding.instance.endOfFrame;
    if (_useLiquidGlass) {
      await _topState.resetToInitialAnchor();
    }
  }

  void _synchronizePageWithSelectedIndex() {
    if (!mounted || !pageController.hasClients) {
      return;
    }
    final favcats = controller.favcatList;
    if (favcats.isEmpty) {
      return;
    }
    final target = controller.index.clamp(0, favcats.length - 1).toInt();
    if (pageController.position.isScrollingNotifier.value) {
      return;
    }
    final current = pageController.page;
    if (current == null || (current - target).abs() > 0.01) {
      pageController.jumpToPage(target);
    }
  }

  @override
  Widget build(BuildContext context) => offlineGlassPageProbe(
    route: 'favorite',
    page: () => controller.currFavcat,
    controllerOwner: controller,
    scrollController: _headerScrollController,
    innerPositions: () =>
        _nestedScrollKey.currentState?.innerPositions ??
        const <ScrollPosition>[],
    firstCardTop: _currentFirstCardTop,
    child: Obx(
      () {
        final selecting = _selection.selecting.value;
        final hasSelection = _selection.hasSelection && !_selection.busy.value;
        final canMove = controller.currFavcat != 'l';
        final l10n = L10n.of(context);
        return FavoriteListScope(
          selection: _selection,
          registry: _selectionRegistry,
          showFavNote: true,
          hideTagsInWaterfall: true,
          favNoteMaxLines: 1,
          child: NativeNavigationPage(
            tabId: EHRoutes.favorite,
            chrome: selecting
                ? NativePageChrome(
                    title: l10n.tab_favorite,
                    actions: [
                      NativeNavigationAction(
                        id: 'select.done',
                        title: l10n.done,
                        symbol: 'xmark',
                        prominent: true,
                        priority: NativeBarItemPriority.high,
                        onPressed: _selection.exit,
                      ),
                    ],
                    toolbarActions: [
                      if (canMove)
                        NativeNavigationAction(
                          id: 'fav.batch.move',
                          title: l10n.fav_move_to,
                          symbol: 'folder',
                          enabled: hasSelection,
                          onPressed: _onBatchMove,
                        ),
                      NativeNavigationAction(
                        id: 'fav.batch.remove',
                        title: l10n.remove_from_favorites,
                        symbol: 'heart.slash',
                        enabled: hasSelection,
                        onPressed: _onBatchRemove,
                      ),
                    ],
                  )
                : NativePageChrome(
                    title: l10n.tab_favorite,
                    actions: [
                      ...Get.find<TabHomeController>().nativeHiddenTabActions,
                      NativeNavigationAction(
                        id: 'select',
                        title: l10n.fav_select,
                        symbol: 'checkmark.circle',
                        onPressed: _enterSelection,
                      ),
                      NativeNavigationAction(
                        id: 'search',
                        title: l10n.search,
                        symbol: 'magnifyingglass',
                        onPressed: () => NavigatorUtil.goSearchPage(
                          searchType: SearchType.favorite,
                        ),
                      ),
                      NativeNavigationAction(
                        id: 'order',
                        title:
                            '${l10n.favorites_order} (${controller.orderText})',
                        symbol: 'arrow.down',
                        onPressed: () => controller.setOrder(context),
                      ),
                      if (controller.afterJump)
                        NativeNavigationAction(
                          id: 'top',
                          title: l10n.back_to_top,
                          symbol: 'arrow.up.circle',
                          onPressed: controller.jumpToTop,
                        ),
                      NativeNavigationAction(
                        id: 'jump',
                        title: l10n.jump_or_seek,
                        symbol: 'arrow.uturn.down.circle',
                        onPressed: () => controller.showJumpDialog(context),
                      ),
                    ],
                  ),
            child: _buildPage(context),
          ),
        );
      },
    ),
  );

  Widget _buildPage(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final layout = LiquidGlassTopLayout.fromMediaQuery(mediaQuery);
    final topTabbarHeight = topTabbarHeightFor(context);
    return Obx(() {
      final liquidGlass = _useLiquidGlass;
      final native = NativeNavigationScope.isEnabled(context);
      final headerMaxHeight = native
          ? mediaQuery.viewPadding.top + topTabbarHeight
          : liquidGlass
          ? layout.safeTop +
                _ehSettingService.liquidGlassTopBarLayout.expandedHeight(
                  MediaQuery.textScalerOf(context),
                  hasCategories: controller.favcatList.isNotEmpty,
                )
          : mediaQuery.viewPadding.top + kHeaderMaxHeight;
      final hideTopBarOnScroll = _ehSettingService.hideTopBarOnScroll;

      final scrollView = buildNestedScrollView(
        headerMaxHeight,
        hideTopBarOnScroll,
        liquidGlass,
        layout,
      );

      final content = Stack(
        fit: StackFit.expand,
        children: <Widget>[
          scrollView,
          if (!native)
            FavoriteBatchActionBar(
              selection: _selection,
              allowMove: controller.currFavcat != 'l',
              onMove: _onBatchMove,
              onRemove: _onBatchRemove,
            ),
        ],
      );

      if (!liquidGlass) {
        return CupertinoPageScaffold(
          child: CanvasGrain(child: SizeCacheWidget(child: content)),
        );
      }

      return CupertinoPageScaffold(
        backgroundColor: const Color(0x00000000),
        child: SizeCacheWidget(
          child: NotificationListener<ScrollNotification>(
            onNotification: _topState.handleScrollNotification,
            child: content,
          ),
        ),
      );
    });
  }

  Widget _buildTopBar(
    BuildContext context,
    double offset,
    double maxExtentCallBackValue, {
    required LiquidGlassTopLayout layout,
    required bool dockTopBar,
    required bool liquidGlass,
  }) {
    if (NativeNavigationScope.isEnabled(context)) {
      return Obx(
        () => NativeTopTabHeader(
          topInset: MediaQuery.viewPaddingOf(context).top,
          railHeight: topTabbarHeightFor(context),
          edgeProgress: _nativeEdgeProgress,
          child: _selection.selecting.value
              ? _buildSelectionHeader(
                  context,
                  height: topTabbarHeightFor(context),
                )
              : FavoriteTabBar(
                  pageController: pageController,
                  linkScrollBarController: linkScrollBarController,
                  controller: controller,
                  opacity: 1,
                ),
        ),
      );
    }
    if (liquidGlass) {
      return LiquidGlassBarMotionBuilder(
        enabled: dockTopBar,
        builder: (context, progress) =>
            _buildGlassRail(context, progress, layout),
      );
    }

    final collapseProgress = dockTopBar
        ? layout.collapseProgress(
            offset,
            maxExtentCallBackValue - layout.collapsedHeaderHeight,
          )
        : 0.0;
    final navBarOpacity = dockTopBar
        ? 1.0 - collapseProgress
        : 1.0 -
              (offset / (kMinInteractiveDimensionCupertino - 1)).clamp(
                0.0,
                1.0,
              );
    final collapsed = dockTopBar && collapseProgress >= 0.98;
    final customBarOpacity = navBarOpacity;
    return SizedBox(
      height: maxExtentCallBackValue,
      child: Offstage(
        offstage: collapsed,
        child: IgnorePointer(
          ignoring: collapsed,
          child: ExcludeSemantics(
            excluding: collapsed,
            child: Transform.translate(
              offset: Offset(0, -layout.dockingTranslation * collapseProgress),
              child: Transform.scale(
                alignment: Alignment.topCenter,
                scale: 1.0 - collapseProgress * 0.18,
                child: Stack(
                  children: [
                    getNavigationBar(context, opacity: navBarOpacity),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Obx(
                        () => _selection.selecting.value
                            ? _buildSelectionHeader(
                                context,
                                height: topTabbarHeightFor(context),
                              )
                            : FavoriteTabBar(
                                pageController: pageController,
                                linkScrollBarController:
                                    linkScrollBarController,
                                controller: controller,
                                opacity: customBarOpacity,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassRail(
    BuildContext context,
    double fadeProgress,
    LiquidGlassTopLayout layout,
  ) {
    return Obx(() {
      final selecting = _selection.selecting.value;
      final l10n = L10n.of(context);
      if (selecting) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            LiquidGlassRail(
              layout: _ehSettingService.liquidGlassTopBarLayout,
              pageController: pageController,
              title: l10n.tab_favorite,
              safeTop: layout.safeTop,
              fadeProgress: fadeProgress,
              selectedIndex: controller.index,
              followSystemTransparency: _ehSettingService.liquidGlassMaterial,
              leading: LiquidGlassRailAction(
                icon: CupertinoIcons.xmark,
                label: l10n.done,
                onPressed: _selection.exit,
              ),
              trailing: const <LiquidGlassRailAction>[],
              categories: const <LiquidGlassRailCategory>[],
              onTitleTap: _scrollToInitialContentAnchor,
              refreshing: false,
            ),
            _buildSelectionHeader(context, height: 48),
          ],
        );
      }
      return LiquidGlassRail(
        layout: _ehSettingService.liquidGlassTopBarLayout,
        pageController: pageController,
        title: l10n.tab_favorite,
        safeTop: layout.safeTop,
        fadeProgress: fadeProgress,
        selectedIndex: controller.index,
        followSystemTransparency: _ehSettingService.liquidGlassMaterial,
        leading: hiddenTabsRailAction(context),
        trailing: <LiquidGlassRailAction>[
          LiquidGlassRailAction(
            icon: CupertinoIcons.checkmark_circle,
            label: l10n.fav_select,
            onPressed: _enterSelection,
          ),
          LiquidGlassRailAction(
            icon: CupertinoIcons.sort_down,
            label: l10n.favorites_order,
            onPressed: () => controller.setOrder(context),
          ),
          LiquidGlassRailAction(
            icon: CupertinoIcons.arrow_uturn_down_circle,
            label: l10n.jump_or_seek,
            onPressed: () => controller.showJumpDialog(context),
          ),
        ],
        categoryTrailing: controller.showBarsBtn
            ? <LiquidGlassRailAction>[
                LiquidGlassRailAction(
                  icon: CupertinoIcons.line_horizontal_3,
                  label: '选择收藏夹',
                  onPressed: () async {
                    final result = await Get.toNamed(
                      EHRoutes.selFavorite,
                      id: primaryNavigatorId,
                    );
                    if (result != null && result is Favcat) {
                      final index = controller.favcatList.indexWhere(
                        (element) => element.favId == result.favId,
                      );
                      if (index >= 0) {
                        await _selectFavoriteCategory(index);
                      }
                    }
                  },
                ),
              ]
            : const <LiquidGlassRailAction>[],
        search: PlatformCapabilities.topSearchCapsule
            ? LiquidGlassRailSearch(
                label: L10n.of(context).search,
                onTap: () => NavigatorUtil.goSearchPage(
                  searchType: SearchType.favorite,
                  fromTabItem:
                      Get.find<TabHomeController>().tabMap[EHRoutes.favorite] ??
                      false,
                ),
              )
            : null,
        categories: controller.favcatList
            .map(
              (favcat) => LiquidGlassRailCategory(
                id: favcat.favId,
                title: favcat.favTitle,
                onTap: () async {
                  final index = controller.favcatList.indexOf(favcat);
                  await _selectFavoriteCategory(index);
                },
              ),
            )
            .toList(),
        onTitleTap: _scrollToInitialContentAnchor,
        refreshing: controller.isBackgroundRefresh,
      );
    });
  }

  Widget buildNestedScrollView(
    double headerMaxHeight,
    bool hideTopBarOnScroll,
    bool liquidGlass,
    LiquidGlassTopLayout layout,
  ) {
    final dockTopBar =
        liquidGlass && hideTopBarOnScroll && layout.canDockTopRail;
    if (liquidGlass) {
      _topState.updateLayout(
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        topBarExtent: headerMaxHeight,
        safeTop: layout.safeTop,
      );
    }
    final native = NativeNavigationScope.isEnabled(context);
    final nativeCollapsible = native && hideTopBarOnScroll;
    final topTabbarHeight = topTabbarHeightFor(context);
    _headerScrollController.headerExtent = native
        ? nativeCollapsible
              ? topTabbarHeight
              : 0
        : liquidGlass
        ? headerMaxHeight
        : headerMaxHeight - layout.collapsedHeaderHeight;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _topState.setBarFadeEnabled(dockTopBar);
        if (liquidGlass) {
          _topState.refresh();
        }
      }
    });
    final Widget scrollView = ExtendedNestedScrollView(
      key: _nestedScrollKey,
      controller: _headerScrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      floatHeaderSlivers: !liquidGlass,
      onlyOneScrollInBody: true,
      headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
        return [
          SliverOverlapAbsorber(
            handle: ExtendedNestedScrollView.sliverOverlapAbsorberHandleFor(
              context,
            ),
            sliver: SliverPersistentHeader(
              floating: !liquidGlass,
              pinned: true,
              delegate: FooSliverPersistentHeaderDelegate(
                builder: (context, offset, _) => liquidGlass
                    ? const SizedBox.expand()
                    : _buildTopBar(
                        context,
                        offset,
                        headerMaxHeight,
                        layout: layout,
                        dockTopBar: dockTopBar,
                        liquidGlass: false,
                      ),
                // minHeight: context.mediaQueryPadding.top + kTopTabbarHeight,
                minHeight: native
                    ? NativeTopTabHeader.minExtentFor(
                        topInset: MediaQuery.viewPaddingOf(context).top,
                        railHeight: topTabbarHeight,
                        collapsible: nativeCollapsible,
                      )
                    : liquidGlass
                    ? 0.0
                    : hideTopBarOnScroll
                    ? dockTopBar
                          ? layout.collapsedHeaderHeight
                          : layout.safeTop + kTopTabbarHeight
                    : headerMaxHeight,
                maxHeight: headerMaxHeight,
              ),
            ),
          ),
        ];
      },
      body: buildBody(liquidGlass, hideTopBarOnScroll),
    );
    if (!liquidGlass) {
      return ScrollEdgeProgressListener(
        controller: _nativeEdgeProgress,
        enabled: native,
        activePage: controller.currFavcat,
        child: NativeBarAutoHide(enabled: nativeCollapsible, child: scrollView),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Themed base below the scroll content: solid through the status-bar
        // safe area, then fading to the shared top fade end, so gap
        // background between cards has no fixed seam. Cards scroll above it
        // and stay visible through the top scrim.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: LiquidGlassBarMotionBuilder(
            enabled: dockTopBar,
            builder: (context, progress) => LiquidGlassSafeAreaBase(
              firstCardRestTop: _topState.firstCardRestTop,
              safeTop: layout.safeTop,
              layout: _ehSettingService.liquidGlassTopBarLayout,
              hasCategories: controller.favcatList.isNotEmpty,
              edgeProgress: _nativeEdgeProgress,
              barFadeProgress: progress,
            ),
          ),
        ),
        ScrollEdgeProgressListener(
          controller: _nativeEdgeProgress,
          activePage: controller.currFavcat,
          child: scrollView,
        ),
        // Fixed solid background above the scroll content and below the scrim
        // and rail. Its lower edge follows the active first card without
        // changing the list's scroll geometry.
        if (!PlatformCapabilities.isDesktop)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LiquidGlassSolidMask(
              progressListenable: _topState.solidMaskProgress,
              safeTop: layout.safeTop,
              // The mask bottom follows the first card from safeTop to the
              // category rail's lower edge.
              height: headerMaxHeight,
            ),
          ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: LiquidGlassBarMotionBuilder(
            enabled: dockTopBar,
            builder: (context, progress) => LiquidGlassTopScrim(
              firstCardRestTop: _topState.firstCardRestTop,
              safeTop: layout.safeTop,
              layout: _ehSettingService.liquidGlassTopBarLayout,
              hasCategories: controller.favcatList.isNotEmpty,
              edgeProgress: _nativeEdgeProgress,
              barFadeProgress: progress,
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: LiquidGlassBarMotionBuilder(
            enabled: dockTopBar,
            builder: (context, progress) => LiquidGlassTopSoftEdge(
              safeTop: layout.safeTop,
              layout: _ehSettingService.liquidGlassTopBarLayout,
              edgeProgress: _nativeEdgeProgress,
              barFadeProgress: progress,
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: LiquidGlassBarMotionBuilder(
            enabled: dockTopBar,
            builder: (context, progress) =>
                _buildGlassRail(context, progress, layout),
          ),
        ),
      ],
    );
  }

  Builder buildBody(bool liquidGlass, bool hideTopBarOnScroll) {
    return Builder(
      builder: (context) {
        return GestureDetector(
          onPanDown: (e) {
            // 恢复启用 scrollToItem
            linkScrollBarController.enableScrollToItem();
          },
          child: Obx(() {
            final selecting = _selection.selecting.value;
            final pageView = PageView(
              key: ValueKey(controller.showBarsBtn), // 登录状态变化后能刷新
              controller: pageController,
              physics: selecting ? const NeverScrollableScrollPhysics() : null,
              children: [
                ...controller.favcatList.map(
                  (e) => ScrollEdgeProgressListener(
                    key: ValueKey(e.favId),
                    controller: _nativeEdgeProgress,
                    enabled:
                        liquidGlass || NativeNavigationScope.isEnabled(context),
                    page: e.favId,
                    child: FavoriteSubPage(
                      favcat: e.favId,
                      firstCardKey: _firstCardKeyFor(e.favId),
                      contentTopGap: liquidGlass
                          ? LiquidGlassEdgeTokens.contentGapFor(context)
                          : null,
                      scrollToInitialAnchor: _scrollToInitialContentAnchor,
                    ),
                  ),
                ),
              ],
              onPageChanged: (index) {
                linkScrollBarController.scrollToItem(index);
                controller.onPageChanged(index);
                _nativeEdgeProgress.selectPage(controller.currFavcat);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _useLiquidGlass) {
                    _topState.refresh();
                  }
                });
              },
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _synchronizePageWithSelectedIndex();
            });
            return FavoriteSwipeSelectRegion(
              selection: _selection,
              registry: _selectionRegistry,
              scrollControllerProvider: () =>
                  _nestedScrollKey.currentState?.innerController,
              child: pageView,
            );
          }),
        );
      },
    );
  }

  Widget getNavigationBar(BuildContext context, {double? opacity}) {
    return Obx(() {
      final useLiquidGlass =
          _ehSettingService.liquidGlass &&
          (GlassMode.of(context).forComponent(flutterImplemented: true) !=
              GlassMode.off);
      return CupertinoNavigationBar(
        automaticBackgroundVisibility: !useLiquidGlass,
        enableBackgroundFilterBlur: !useLiquidGlass,
        backgroundColor: useLiquidGlass
            ? const Color(0x00000000)
            : kEnableImpeller
            ? CupertinoTheme.of(context).barBackgroundColor.withOpacity(1)
            : null,
        transitionBetweenRoutes: false,
        border: null,
        // border: Border(
        //   bottom: BorderSide(
        //     color:
        //         CupertinoTheme.of(context).barBackgroundColor.withOpacity(0.2),
        //     width: 0.1, // 0.0 means one physical pixel
        //   ),
        // ),
        padding: const EdgeInsetsDirectional.only(end: 4),
        middle: Opacity(
          opacity: opacity ?? 1.0,
          child: GestureDetector(
            onTap: _scrollToInitialContentAnchor,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(L10n.of(context).tab_favorite),
                Obx(() {
                  if (controller.isBackgroundRefresh) {
                    return const CupertinoActivityIndicator(radius: 10)
                        .paddingSymmetric(horizontal: 8);
                  } else {
                    return const SizedBox();
                  }
                }),
              ],
            ),
          ),
        ),
        leading: Opacity(
          opacity: opacity ?? 1.0,
          child: _selection.selecting.value
              ? CupertinoButton(
                  minimumSize: const Size(44, 44),
                  padding: EdgeInsets.zero,
                  onPressed: _selection.exit,
                  child: Semantics(
                    label: L10n.of(context).done,
                    child: const EhSvgIcon(CupertinoIcons.xmark, size: 22),
                  ),
                )
              : controller.getLeading(context),
        ),
        trailing: Opacity(
          opacity: opacity ?? 1.0,
          child: _selection.selecting.value
              ? const SizedBox.shrink()
              : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 批量选择按钮
              CupertinoButton(
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.zero,
                onPressed: _enterSelection,
                child: Semantics(
                  label: L10n.of(context).fav_select,
                  child: const EhSvgIcon(
                    CupertinoIcons.checkmark_circle,
                    size: 26,
                  ),
                ),
              ),
              // 搜索按钮
              CupertinoButton(
                minSize: 40,
                padding: const EdgeInsets.all(0),
                child: Semantics(
                  label: '搜索',
                  child: const EhSvgIcon(
                    // FontAwesomeIcons.magnifyingGlass,
                    CupertinoIcons.search,
                    size: 28,
                  ),
                ),
                onPressed: () {
                  final bool fromTabItem =
                      Get.find<TabHomeController>().tabMap[controller.heroTag ??
                          ''] ??
                      false;
                  NavigatorUtil.goSearchPage(
                    searchType: SearchType.favorite,
                    fromTabItem: fromTabItem,
                  );
                },
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(0.0),
                minSize: 40,
                child: Semantics(
                  label: '收藏排序',
                  child: Stack(
                    alignment: Alignment.centerRight,
                    // mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // const Icon(
                      //   FontAwesomeIcons.arrowDownWideShort,
                      //   size: 20,
                      // ),
                      const EhSvgIcon(CupertinoIcons.sort_down, size: 28),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          controller.orderText,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                onPressed: () => controller.setOrder(context),
              ),
              Obx(() {
                if (controller.afterJump) {
                  return CupertinoButton(
                    minSize: 40,
                    padding: const EdgeInsets.all(0),
                    child: Semantics(
                      label: '回到顶部',
                      child: const EhSvgIcon(
                        CupertinoIcons.arrow_up_circle,
                        size: 28,
                      ),
                    ),
                    onPressed: () {
                      controller.jumpToTop();
                    },
                  );
                } else {
                  return const SizedBox();
                }
              }),
              CupertinoButton(
                minSize: 40,
                padding: const EdgeInsets.all(0),
                child: Semantics(
                  label: '跳转/搜寻',
                  child: const EhSvgIcon(
                    CupertinoIcons.arrow_uturn_down_circle,
                    size: 28,
                  ),
                ),
                onPressed: () {
                  controller.showJumpDialog(context);
                },
              ),
              // PageSelectorButton(controller: controller),
            ],
          ).paddingOnly(right: 4),
        ),
      );
    });
  }
}

class FavoriteTabBar extends StatelessWidget {
  const FavoriteTabBar({
    super.key,
    required this.pageController,
    required this.linkScrollBarController,
    required this.controller,
    this.opacity = 0.0,
  });

  final PageController pageController;
  final LinkScrollBarController linkScrollBarController;
  final FavoriteTabBarController controller;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final barBackgroundColor = CupertinoTheme.of(context).barBackgroundColor;
    final EhSettingService ehSettingService = Get.find();
    return Obx(() {
      // 不要删除这行
      ehTheme.isDarkMode;
      final useLiquidGlass =
          ehSettingService.liquidGlass &&
          (GlassMode.of(context).forComponent(flutterImplemented: true) !=
              GlassMode.off);
      final topTabbarHeight = topTabbarHeightFor(context);
      if ((GlassMode.of(context).forComponent(flutterImplemented: true) !=
              GlassMode.off) &&
          (useLiquidGlass || NativeNavigationScope.isEnabled(context))) {
        return Padding(
          padding: EdgeInsets.only(
            left: context.mediaQueryPadding.left,
            right: context.mediaQueryPadding.right,
          ),
          child: SizedBox(
            height: topTabbarHeight,
            child: SegmentedRail(
              opacity: opacity,
              selectedIndex: controller.index,
              pageController: pageController,
              followSystemTransparency: ehSettingService.liquidGlassMaterial,
              accessory: controller.showBarsBtn
                  ? LiquidGlassRailAction(
                      icon: CupertinoIcons.line_horizontal_3,
                      label: L10n.of(context).choose_favcat,
                      onPressed: () => _chooseFavcat(),
                    )
                  : null,
              items: [
                for (final favcat in controller.favcatList)
                  LiquidGlassRailCategory(
                    id: favcat.favId,
                    title: favcat.favTitle,
                    onTap: () {
                      final index = controller.favcatList.indexOf(favcat);
                      if (index >= 0 && pageController.hasClients) {
                        pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      }

      final Widget bar = Stack(
        alignment: Alignment.topCenter,
        children: [
          if (!useLiquidGlass)
            Blur(
              blur: 10,
              blurColor: barBackgroundColor,
              colorOpacity: kEnableImpeller ? 1.0 : opacity,
              child: Container(height: topTabbarHeight),
            ),
          Container(
            decoration: useLiquidGlass
                ? null
                : const BoxDecoration(border: kDefaultNavBarBorder),
            padding: EdgeInsets.only(
              left: context.mediaQueryPadding.left,
              right: context.mediaQueryPadding.right,
            ),
            child: SizedBox(
              height: topTabbarHeight,
              child: Obx(() {
                return Row(
                  children: [
                    Expanded(
                      child: LinkScrollBar(
                        pageController: pageController,
                        controller: linkScrollBarController,
                        items: controller.favcatList
                            .map(
                              (e) => LinkTabItem(
                                title: e.favTitle,
                                // icon: LineIcons.dotCircleAlt,
                              ),
                            )
                            .toList(),
                        itemPadding: const EdgeInsets.symmetric(horizontal: 8),
                        initIndex: controller.index,
                        onItemChange: (index) => pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.ease,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 刷新按钮
                          if (GetPlatform.isDesktop)
                            Builder(
                              builder: (context) {
                                bool isRefresh = false;
                                return StatefulBuilder(
                                  builder: (context, setState) {
                                    return CupertinoButton(
                                      minSize: 40,
                                      padding: const EdgeInsets.all(0),
                                      child: isRefresh
                                          ? const CupertinoActivityIndicator(
                                              radius: 10,
                                            )
                                          : Semantics(
                                              label: '刷新',
                                              child: const EhSvgFaIcon(
                                                FontAwesomeIcons.rotateRight,
                                                size: 20,
                                              ),
                                            ),
                                      onPressed: () async {
                                        setState(() {
                                          isRefresh = true;
                                        });
                                        try {
                                          await controller.reloadData();
                                        } finally {
                                          setState(() {
                                            isRefresh = false;
                                          });
                                        }
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          if (controller.showBarsBtn)
                            CupertinoButton(
                              minSize: 40,
                              padding: const EdgeInsets.all(0),
                              child: Semantics(
                                label: '选择收藏夹',
                                child: const EhSvgFaIcon(
                                  FontAwesomeIcons.bars,
                                  size: 20,
                                ),
                              ),
                              onPressed: _chooseFavcat,
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      );
      return useLiquidGlass ? Opacity(opacity: opacity, child: bar) : bar;
    });
  }

  // 跳转收藏夹选择页
  Future<void> _chooseFavcat() async {
    final result = await Get.toNamed(
      EHRoutes.selFavorite,
      id: primaryNavigatorId,
    );
    if (result != null && result is Favcat) {
      final index = controller.favcatList.indexWhere(
        (element) => element.favId == result.favId,
      );
      if (index >= 0) pageController.jumpToPage(index);
    }
  }
}
