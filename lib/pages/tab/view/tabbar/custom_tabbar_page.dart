import 'package:blur/blur.dart';
import 'package:english_words/english_words.dart';
import 'package:eros_fe/adaptive/native_top_header.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/debug/offline_glass.dart';
import 'package:eros_fe/debug/offline_group_index.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/tab/controller/group/custom_sublist_controller.dart';
import 'package:eros_fe/pages/tab/controller/group/custom_tabbar_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:eros_fe/widget/liquid_glass_scroll_controller.dart';
import 'package:eros_fe/widget/segmented_rail.dart';
import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:flutter/cupertino.dart' hide CupertinoTabBar;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:keframe/keframe.dart';

import '../../comm.dart';
import '../constants.dart';
import 'custom_sub_page.dart';

class CustomTabbarList extends StatefulWidget {
  const CustomTabbarList({super.key});

  @override
  State<CustomTabbarList> createState() => _CustomTabbarListState();
}

class _CustomTabbarListState extends State<CustomTabbarList> {
  final CustomTabbarController controller = Get.find();

  final EhTabController ehTabController = EhTabController();
  final _headerScrollController = LiquidGlassScrollController();
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
  );

  @override
  void dispose() {
    _topState.dispose();
    _headerScrollController.dispose();
    super.dispose();
  }

  final EhSettingService _ehSettingService = Get.find();

  @override
  void initState() {
    super.initState();
    controller.pageController = PageController(initialPage: controller.index);
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
      LiquidGlassPlatform.isSupported &&
      !NativeNavigationBridge.enabled.value;

  GlobalKey _firstCardKeyFor(String profileUuid) =>
      _firstCardKeys.putIfAbsent(profileUuid, () => GlobalKey());

  double? _currentFirstCardTop() {
    final profiles = controller.profilesShow;
    if (profiles.isEmpty) {
      return null;
    }
    final index = controller.index.clamp(0, profiles.length - 1).toInt();
    return liquidGlassScreenTop(_firstCardKeyFor(profiles[index].uuid));
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

  Future<void> _selectProfile(int index) async {
    await _scrollToInitialContentAnchor();
    await controller.selectPage(index);
    await WidgetsBinding.instance.endOfFrame;
    if (_useLiquidGlass) {
      await _topState.resetToInitialAnchor();
    }
  }

  void _synchronizePageWithSelectedIndex() {
    if (!mounted || !controller.pageController.hasClients) {
      return;
    }
    final visibleProfiles = controller.profilesShow;
    if (visibleProfiles.isEmpty) {
      return;
    }
    final target =
        controller.index.clamp(0, visibleProfiles.length - 1).toInt();
    if (controller.pageController.position.isScrollingNotifier.value) {
      return;
    }
    final current = controller.pageController.page;
    if (current == null || (current - target).abs() > 0.01) {
      controller.pageController.jumpToPage(target);
    }
  }

  @override
  Widget build(BuildContext context) => offlineGlassPageProbe(
        route: 'gallery',
        page: () => controller.currProfileUuid,
        scrollController: _headerScrollController,
        innerPositions: () =>
            _nestedScrollKey.currentState?.innerPositions ??
            const <ScrollPosition>[],
        firstCardTop: _currentFirstCardTop,
        child: Obx(() => NativeNavigationPage(
              tabId: EHRoutes.gallery,
              chrome: NativePageChrome(
                title: L10n.of(context).tab_gallery,
                actions: [
                  ...offlineDuoRootNavigationActions(),
                  ...Get.find<TabHomeController>().nativeHiddenTabActions,
                  NativeNavigationAction(
                    id: 'search',
                    title: L10n.of(context).search,
                    symbol: 'magnifyingglass',
                    onPressed: NavigatorUtil.goSearchPage,
                  ),
                  if (controller.afterJump)
                    NativeNavigationAction(
                      id: 'top',
                      title: L10n.of(context).back_to_top,
                      symbol: 'arrow.up.circle',
                      onPressed: controller.jumpToTop,
                    ),
                  NativeNavigationAction(
                    id: 'jump',
                    title: L10n.of(context).jump_or_seek,
                    symbol: 'arrow.uturn.down.circle',
                    onPressed: () => controller.showJumpDialog(context),
                  ),
                ],
              ),
              child: _buildPage(context),
            )),
      );

  Widget _buildPage(BuildContext context) {
    return Obx(() {
      final liquidGlass = _useLiquidGlass;
      final hideTopBarOnScroll = _ehSettingService.hideTopBarOnScroll;

      final Widget scrollView = buildNestedScrollView(
        context,
        hideTopBarOnScroll,
        liquidGlass,
      );

      if (!liquidGlass) {
        return CupertinoPageScaffold(
          child: offlineGroupSelection(
              uuid: controller.currProfileUuid,
              index: controller.index,
              child: SizeCacheWidget(child: scrollView)),
        );
      }

      return CupertinoPageScaffold(
        backgroundColor: const Color(0x00000000),
        child: offlineGroupSelection(
          uuid: controller.currProfileUuid,
          index: controller.index,
          child: SizeCacheWidget(
            child: NotificationListener<ScrollNotification>(
              onNotification: _topState.handleScrollNotification,
              child: scrollView,
            ),
          ),
        ),
      );
    });
  }

  Widget buildNestedScrollView(
    BuildContext context,
    bool hideTopBarOnScroll,
    bool liquidGlass,
  ) {
    final mediaQuery = MediaQuery.of(context);
    final layout = LiquidGlassTopLayout.fromMediaQuery(mediaQuery);
    final topInset = mediaQuery.viewPadding.top;
    final native = NativeNavigationScope.isEnabled(context);
    final topTabbarHeight = topTabbarHeightFor(context);
    final headerMaxHeight = native
        ? topInset + topTabbarHeight
        : liquidGlass
            ? layout.safeTop +
                _ehSettingService.liquidGlassTopBarLayout.expandedHeight(
                  MediaQuery.textScalerOf(context),
                  hasCategories: controller.profilesShow.isNotEmpty,
                )
            : topInset + kHeaderMaxHeight;
    final dockTopBar =
        liquidGlass && hideTopBarOnScroll && layout.canDockTopRail;
    if (liquidGlass) {
      _topState.updateLayout(
        devicePixelRatio: mediaQuery.devicePixelRatio,
        topBarExtent: headerMaxHeight,
        safeTop: layout.safeTop,
      );
    }
    final nativeCollapsible = native && hideTopBarOnScroll;
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
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      floatHeaderSlivers: !liquidGlass,
      onlyOneScrollInBody: true,
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverOverlapAbsorber(
            handle: ExtendedNestedScrollView.sliverOverlapAbsorberHandleFor(
              context,
            ),
            sliver: SliverPersistentHeader(
              floating: !liquidGlass,
              pinned: true,
              delegate: FooSliverPersistentHeaderDelegate(
                builder: (context, offset, _) => native
                    ? NativeTopTabHeader(
                        topInset: topInset,
                        railHeight: topTabbarHeight,
                        child: CustomTabBar(controller: controller, opacity: 1),
                      )
                    : liquidGlass
                        ? const SizedBox.expand()
                        : Obx(
                            () => _buildSliverTopBar(
                              context,
                              offset,
                              headerMaxHeight,
                              layout: layout,
                              dockTopBar: dockTopBar,
                              liquidGlass: false,
                            ),
                          ),
                minHeight: native
                    ? NativeTopTabHeader.minExtentFor(
                        topInset: topInset,
                        railHeight: topTabbarHeight,
                        collapsible: nativeCollapsible,
                      )
                    : liquidGlass
                        ? 0.0
                        : hideTopBarOnScroll
                            ? dockTopBar
                                ? layout.collapsedHeaderHeight
                                : topInset + kTopTabbarHeight
                            : headerMaxHeight,
                maxHeight: headerMaxHeight,
              ),
            ),
          ),
        ];
      },
      body: buildSubPages(liquidGlass, hideTopBarOnScroll),
    );
    if (!liquidGlass) {
      return NativeBarAutoHide(enabled: nativeCollapsible, child: scrollView);
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
          child: LiquidGlassSafeAreaBase(
            safeTop: layout.safeTop,
            layout: _ehSettingService.liquidGlassTopBarLayout,
            hasCategories: controller.profilesShow.isNotEmpty,
          ),
        ),
        scrollView,
        // Fixed solid background above the scroll content and below the scrim
        // and rail. Its lower edge follows the active first card without
        // changing the list's scroll geometry.
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
          child: LiquidGlassTopScrim(
            safeTop: layout.safeTop,
            layout: _ehSettingService.liquidGlassTopBarLayout,
            hasCategories: controller.profilesShow.isNotEmpty,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: LiquidGlassBarMotionBuilder(
            enabled: dockTopBar,
            builder: (context, progress) =>
                _buildGlassRail(context, layout, progress),
          ),
        ),
      ],
    );
  }

  Builder buildSubPages(bool liquidGlass, bool hideTopBarOnScroll) {
    return Builder(
      builder: (context) {
        return GestureDetector(
          onPanDown: (e) {
            // 恢复启用 scrollToItem
            controller.linkScrollBarController.enableScrollToItem();
          },
          child: Obx(() {
            final pageView = PageView(
              key: const PageStorageKey('custom-visible-group-pages'),
              // CustomScrollPhysics对于改善滑动问题没有帮助
              // physics: const CustomScrollPhysics(),
              controller: controller.pageController,
              children: controller.profilesShow.isNotEmpty
                  ? [
                      ...controller.profilesShow.map(
                        (e) => SubListView<CustomSubListController>(
                          profileUuid: e.uuid,
                          firstCardKey: _firstCardKeyFor(e.uuid),
                          scrollToInitialAnchor: _scrollToInitialContentAnchor,
                          key: ValueKey(e.uuid),
                        ),
                      ),
                    ]
                  : [
                      const Center(
                        child: Text('[ ]', style: TextStyle(fontSize: 40)),
                      ),
                    ],
              onPageChanged: (index) {
                controller.linkScrollBarController.scrollToItem(index);
                controller.onPageChanged(index);
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
            return pageView;
          }),
        );
      },
    );
  }

  Widget _buildSliverTopBar(
    BuildContext context,
    double offset,
    double maxExtentCallBackValue, {
    required LiquidGlassTopLayout layout,
    required bool dockTopBar,
    required bool liquidGlass,
  }) {
    if (liquidGlass) {
      return LiquidGlassBarMotionBuilder(
        enabled: dockTopBar,
        builder: (context, progress) =>
            _buildGlassRail(context, layout, progress),
      );
    }

    final double collapseProgress = dockTopBar
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
    final bool collapsed = dockTopBar && collapseProgress >= 0.98;
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
                      child: CustomTabBar(
                        controller: controller,
                        opacity: customBarOpacity,
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
    LiquidGlassTopLayout layout,
    double fadeProgress,
  ) {
    return LiquidGlassRail(
      layout: _ehSettingService.liquidGlassTopBarLayout,
      pageController: controller.pageController,
      title: L10n.of(context).tab_gallery,
      safeTop: layout.safeTop,
      fadeProgress: fadeProgress,
      selectedIndex: controller.index,
      followSystemTransparency:
          _ehSettingService.liquidGlassFollowSystemTransparency,
      leading: LiquidGlassRailAction(
        icon: CupertinoIcons.time,
        label: '浏览历史',
        onPressed: () {
          Get.toNamed(EHRoutes.history, id: primaryNavigatorId);
        },
      ),
      trailing: <LiquidGlassRailAction>[
        LiquidGlassRailAction(
          icon: CupertinoIcons.arrow_uturn_down_circle,
          label: '跳转/搜寻',
          onPressed: () => controller.showJumpDialog(context),
        ),
      ],
      categoryTrailing: <LiquidGlassRailAction>[
        LiquidGlassRailAction(
          icon: CupertinoIcons.line_horizontal_3,
          label: '分组管理',
          onPressed: controller.pressedBar,
        ),
      ],
      categories: controller.profilesShow
          .map(
            (profile) => LiquidGlassRailCategory(
              id: profile.uuid,
              title: profile.name,
              onLongPress: () =>
                  showGroupActionSheet(context, controller, profile),
              onTap: () async {
                final index = controller.profilesShow.indexOf(profile);
                await _selectProfile(index);
              },
            ),
          )
          .toList(),
      onTitleTap: _scrollToInitialContentAnchor,
      refreshing: controller.isBackgroundRefresh,
    );
  }

  CupertinoNavigationBar getNavigationBar(
    BuildContext context, {
    double? opacity,
  }) {
    final useLiquidGlass =
        _ehSettingService.liquidGlass && LiquidGlassPlatform.isSupported;
    return CupertinoNavigationBar(
      transitionBetweenRoutes: false,
      automaticBackgroundVisibility: !useLiquidGlass,
      enableBackgroundFilterBlur: !useLiquidGlass,
      backgroundColor: useLiquidGlass
          ? const Color(0x00000000)
          : kEnableImpeller
              ? CupertinoTheme.of(context).barBackgroundColor.withOpacity(1)
              : null,
      border: null,
      // border: Border(
      //   bottom: BorderSide(
      //     color: CupertinoTheme.of(context).barBackgroundColor.withOpacity(0.2),
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
              Text(L10n.of(context).tab_gallery),
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
        child: controller.getLeading(context),
      ),
      trailing: Opacity(
        opacity: opacity ?? 1.0,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            CupertinoButton(
              minSize: 40,
              padding: const EdgeInsets.all(0),
              child: Semantics(
                label: '搜索',
                child: const Icon(CupertinoIcons.search, size: 28),
              ),
              onPressed: () {
                NavigatorUtil.goSearchPage();
              },
            ),
            // 页码跳转按钮
            // JumpButton(controller: controller),
            Obx(() {
              if (controller.afterJump) {
                return CupertinoButton(
                  minSize: 40,
                  padding: const EdgeInsets.all(0),
                  child: Semantics(
                    label: '回到顶部',
                    child: const Icon(CupertinoIcons.arrow_up_circle, size: 28),
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
                child: const Icon(
                  CupertinoIcons.arrow_uturn_down_circle,
                  size: 28,
                ),
              ),
              onPressed: () {
                controller.showJumpDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class JumpButton extends StatelessWidget {
  const JumpButton({super.key, required this.controller});

  final CustomTabbarController controller;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minSize: 36,
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        constraints: const BoxConstraints(minWidth: 24, maxHeight: 26),
        decoration: BoxDecoration(
          border: Border.all(
            color: CupertinoDynamicColor.resolve(
              CupertinoColors.activeBlue,
              context,
            ),
            width: 1.8,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Obx(
          () => Text(
            // '${max(1, controller.curPage + 1)}',
            '1',
            textAlign: TextAlign.center,
            textScaler: const TextScaler.linear(0.9),
            // textScaler: const TextScaler.linear(0.9),
            style: TextStyle(
              height: 1.3,
              fontWeight: FontWeight.bold,
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.activeBlue,
                context,
              ),
            ),
          ),
        ),
      ),
      onPressed: () {
        controller.showJumpDialog(context);
      },
    );
  }
}

class CustomTabBar extends StatelessWidget {
  const CustomTabBar({super.key, required this.controller, this.opacity = 0.0});

  final CustomTabbarController controller;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final barBackgroundColor = CupertinoTheme.of(context).barBackgroundColor;
    final EhSettingService ehSettingService = Get.find();
    return Obx(() {
      // 不要删除这行
      ehTheme.isDarkMode;
      final useLiquidGlass =
          ehSettingService.liquidGlass && LiquidGlassPlatform.isSupported;
      final topTabbarHeight = topTabbarHeightFor(context);
      if (LiquidGlassPlatform.isSupported &&
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
              pageController: controller.pageController,
              followSystemTransparency:
                  ehSettingService.liquidGlassFollowSystemTransparency,
              accessory: LiquidGlassRailAction(
                icon: CupertinoIcons.line_horizontal_3,
                label: L10n.of(context).group_management,
                onPressed: controller.pressedBar,
              ),
              items: [
                for (final profile in controller.profilesShow)
                  LiquidGlassRailCategory(
                    id: profile.uuid,
                    title: profile.name,
                    onTap: () => controller
                        .selectPage(controller.profilesShow.indexOf(profile)),
                    onLongPress: () =>
                        showGroupActionSheet(context, controller, profile),
                  ),
              ],
            ),
          ),
        );
      }

      final Widget bar = Stack(
        // fit: StackFit.expand,
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
              child: Row(
                children: [
                  Expanded(
                    child: Obx(() {
                      return LinkScrollBar(
                        key: ValueKey(
                          controller.profilesShow
                              .map((e) => '${e.uuid}${e.name}')
                              .join(),
                        ),
                        controller: controller.linkScrollBarController,
                        pageController: controller.pageController,
                        items: controller.profilesShow.isNotEmpty
                            ? controller.profilesShow
                                .map(
                                  (e) => LinkTabItem(
                                    title: e.name,
                                    actinos: [
                                      LinkTabItemAction(
                                        actinoText: '编辑分组',
                                        icon: FontAwesomeIcons.penToSquare,
                                        onTap: () {
                                          controller.toEditPage(uuid: e.uuid);
                                        },
                                      ),
                                      LinkTabItemAction(
                                        actinoText: '删除分组',
                                        icon: FontAwesomeIcons.trashCan,
                                        color: CupertinoDynamicColor.resolve(
                                          CupertinoColors.destructiveRed,
                                          context,
                                        ),
                                        onTap: () {
                                          controller
                                              .showDeleteGroupModalBottomSheet(
                                            e.uuid,
                                            context,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                )
                                .toList()
                            : [LinkTabItem(title: '+++')],
                        initIndex: controller.index,
                        onItemChange: (index) {
                          if (index < 0 ||
                              index >= controller.profilesShow.length ||
                              !controller.pageController.hasClients) {
                            return;
                          }
                          controller.pageController.animateToPage(index,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.ease);
                        },
                      );
                    }),
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
                                            child: const FaIcon(
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
                        offlineGroupControl(
                            'manage',
                            CupertinoButton(
                              minSize: 40,
                              padding: const EdgeInsets.all(0),
                              onPressed: controller.pressedBar,
                              child: Semantics(
                                label: '分组管理',
                                child: const FaIcon(
                                  FontAwesomeIcons.bars,
                                  size: 20,
                                ),
                              ),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
      return useLiquidGlass ? Opacity(opacity: opacity, child: bar) : bar;
    });
  }
}

/// Long-pressing a group offers editing and deletion.
void showGroupActionSheet(
  BuildContext context,
  CustomTabbarController controller,
  CustomProfile profile,
) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (sheetContext) => EhActionSheet(
      title: Text(profile.name),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.of(sheetContext).pop();
            controller.toEditPage(uuid: profile.uuid);
          },
          child: const Text('编辑分组'),
        ),
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () {
            Navigator.of(sheetContext).pop();
            controller.showDeleteGroupModalBottomSheet(
              profile.uuid,
              context,
            );
          },
          child: const Text('删除分组'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(sheetContext).pop(),
        child: Text(L10n.of(context).cancel),
      ),
    ),
  );
}

class EnglishWordList extends StatefulWidget {
  const EnglishWordList({super.key});

  @override
  State<EnglishWordList> createState() => _EnglishWordListState();
}

class _EnglishWordListState extends State<EnglishWordList>
    with AutomaticKeepAliveClientMixin {
  final CustomTabbarController controller = Get.find();
  final List<WordPair> wordList = [];

  @override
  void initState() {
    super.initState();
    wordList.addAll(generateWordPairs().take(100).toList());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.only(
            top: context.mediaQueryPadding.top + kTopTabbarHeight,
          ),
          sliver: EhCupertinoSliverRefreshControl(
            onRefresh: () async {
              await 1.seconds.delay();
              wordList.clear();
              wordList.addAll(generateWordPairs().take(100).toList());
              setState(() {});
            },
          ),
        ),
        SliverFixedExtentList(
          delegate: SliverChildBuilderDelegate((context, index) {
            return Text(wordList[index].asString);
          }, childCount: wordList.length),
          itemExtent: 50.0,
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
