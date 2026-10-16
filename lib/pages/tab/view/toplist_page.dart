import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/debug/offline_glass.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/tab/controller/toplist_controller.dart';
import 'package:eros_fe/pages/tab/view/list/tab_base.dart';
import 'package:eros_fe/utils/cust_lib/persistent_header_builder.dart';
import 'package:eros_fe/utils/cust_lib/sliver/sliver_persistent_header.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:eros_fe/widget/liquid_glass_scroll_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:keframe/keframe.dart';

import '../comm.dart';
import 'gallery_base.dart';

class ToplistTab extends StatefulWidget {
  const ToplistTab({Key? key}) : super(key: key);

  @override
  _ToplistTabState createState() => _ToplistTabState();
}

class _ToplistTabState extends State<ToplistTab> {
  final controller = Get.find<TopListViewController>();
  final EhTabController ehTabController = EhTabController();
  final EhSettingService _ehSettingService = Get.find();

  final _headerScrollController = LiquidGlassScrollController();
  final GlobalKey _firstCardKey = GlobalKey(debugLabel: 'toplist-first-card');
  late final LiquidGlassTopStateCoordinator _topState =
      LiquidGlassTopStateCoordinator(
    scrollController: _headerScrollController,
    firstCardTopProvider: () => liquidGlassScreenTop(_firstCardKey),
  );

  @override
  void dispose() {
    ehTabController.dispose();
    _topState.dispose();
    _headerScrollController.dispose();
    super.dispose();
  }

  GlobalKey centerKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    controller.initStateForListPage(
      context: context,
      ehTabController: ehTabController,
    );
    ehTabController.hasScrollClientsCall =
        () => mounted && _headerScrollController.hasClients;
    ehTabController.scrollToTopCall = _scrollToInitialContentAnchor;
    ehTabController.scrollToTopRefreshCall = () {
      if (_headerScrollController.hasClients) {
        _headerScrollController.animateTo(
          -kDefaultRefreshTriggerPullDistance,
          duration: const Duration(milliseconds: 500),
          curve: Curves.ease,
        );
      }
    };
    ehTabController.scrollToTopAndRefreshCall = () async {
      await _scrollToInitialContentAnchor();
      if (ehTabController.hasScrollClients) {
        await controller.onRefresh();
      }
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _topState.attachBarMotion(LiquidGlassBarMotionScope.maybeOf(context));
  }

  bool get _useLiquidGlass =>
      _ehSettingService.liquidGlass && LiquidGlassPlatform.isSupported;

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

  Future<void> _setToplist({ToplistType? type}) async {
    await _scrollToInitialContentAnchor();
    if (!mounted) {
      return;
    }
    await controller.setToplist(context, type: type);
  }

  LiquidGlassRail _buildGlassRail(
    BuildContext context,
    LiquidGlassTopLayout layout,
    double fadeProgress,
  ) {
    final l10n = L10n.of(context);
    final periodTitles = <String>[
      l10n.tolist_yesterday,
      l10n.tolist_past_month,
      l10n.tolist_past_year,
      l10n.tolist_alltime,
    ];
    return LiquidGlassRail(
      layout: _ehSettingService.liquidGlassTopBarLayout,
      title: controller.getTopListTitle,
      safeTop: layout.safeTop,
      fadeProgress: fadeProgress,
      selectedIndex: ToplistType.values.indexOf(
        controller.ehSettingService.toplist,
      ),
      followSystemTransparency:
          _ehSettingService.liquidGlassFollowSystemTransparency,
      leading: LiquidGlassRailAction(
        icon: CupertinoIcons.time,
        label: '浏览历史',
        onPressed: () {
          Get.toNamed(EHRoutes.history, id: isLayoutLarge ? 1 : null);
        },
      ),
      trailing: <LiquidGlassRailAction>[
        LiquidGlassRailAction(
          icon: CupertinoIcons.sort_down,
          label: '切换排行周期',
          onPressed: () => _setToplist(),
        ),
        LiquidGlassRailAction(
          icon: CupertinoIcons.arrow_uturn_down_circle,
          label: '跳转/搜寻',
          onPressed: () => controller.showJumpDialog(context),
        ),
      ],
      categories: <LiquidGlassRailCategory>[
        for (int index = 0; index < periodTitles.length; index++)
          LiquidGlassRailCategory(
            id: ToplistType.values[index].name,
            title: periodTitles[index],
            onTap: () => _setToplist(type: ToplistType.values[index]),
          ),
      ],
      onTitleTap: _scrollToInitialContentAnchor,
      refreshing: controller.isBackgroundRefresh,
    );
  }

  @override
  Widget build(BuildContext context) => offlineGlassPageProbe(
        route: 'toplist',
        page: () => 'toplist',
        scrollController: _headerScrollController,
        firstCardTop: () => liquidGlassScreenTop(_firstCardKey),
        child: _buildPage(context),
      );

  Widget _buildPage(BuildContext context) {
    bool isRefresh = false;

    final navigationBar = CupertinoNavigationBar(
      transitionBetweenRoutes: false,
      padding: const EdgeInsetsDirectional.only(end: 4),
      leading: controller.getLeading(context),
      middle: Obx(() {
        return GestureDetector(
          onTap: _scrollToInitialContentAnchor,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(controller.getTopListTitle),
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
        );
      }),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (GetPlatform.isDesktop)
            StatefulBuilder(
              builder: (context, setState) {
                return CupertinoButton(
                  padding: const EdgeInsets.all(0),
                  minSize: 40,
                  child: isRefresh
                      ? const CupertinoActivityIndicator(radius: 10)
                      : const Icon(CupertinoIcons.arrow_clockwise, size: 24),
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
            ),
          CupertinoButton(
            padding: const EdgeInsets.all(0.0),
            minSize: 40,
            child: const Stack(
              alignment: Alignment.centerRight,
              // mainAxisSize: MainAxisSize.min,
              children: <Widget>[Icon(CupertinoIcons.sort_down, size: 28)],
            ),
            onPressed: () => controller.setToplist(context),
          ),
          Obx(() {
            if (controller.afterJump) {
              return CupertinoButton(
                minSize: 40,
                padding: const EdgeInsets.all(0),
                child: const Icon(CupertinoIcons.arrow_up_circle, size: 28),
                onPressed: () {
                  controller.jumpToTop();
                },
              );
            } else {
              return const SizedBox();
            }
          }),
          Obx(() {
            if (controller.next.isNotEmpty) {
              return CupertinoButton(
                minSize: 40,
                padding: const EdgeInsets.all(0),
                child: const Icon(
                  CupertinoIcons.arrow_uturn_down_circle,
                  size: 28,
                ),
                onPressed: () {
                  controller.showJumpDialog(context);
                },
              );
            } else {
              return const SizedBox.shrink();
            }
          }),
        ],
      ),
    );

    return Obx(() {
      final useLiquidGlass =
          _ehSettingService.liquidGlass && LiquidGlassPlatform.isSupported;
      final hideTopBarOnScroll = _ehSettingService.hideTopBarOnScroll;
      final mediaQuery = MediaQuery.of(context);
      final layout = LiquidGlassTopLayout.fromMediaQuery(mediaQuery);
      final headerMaxHeight = useLiquidGlass
          ? layout.safeTop +
              _ehSettingService.liquidGlassTopBarLayout.expandedHeight(
                MediaQuery.textScalerOf(context),
              )
          : mediaQuery.viewPadding.top + kMinInteractiveDimensionCupertino;
      final dockTopBar =
          useLiquidGlass && hideTopBarOnScroll && layout.canDockTopRail;

      if (useLiquidGlass) {
        _topState.updateLayout(
          devicePixelRatio: mediaQuery.devicePixelRatio,
          topBarExtent: headerMaxHeight,
          safeTop: layout.safeTop,
        );
      }
      _headerScrollController.headerExtent = useLiquidGlass
          ? headerMaxHeight
          : headerMaxHeight - layout.collapsedHeaderHeight;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _topState.setBarFadeEnabled(dockTopBar);
          if (useLiquidGlass) {
            _topState.refresh();
          }
        }
      });
      final customScrollView = CustomScrollView(
        controller: _headerScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          if (useLiquidGlass)
            SliverPersistentHeader(
              floating: false,
              pinned: true,
              delegate: FooSliverPersistentHeaderDelegate(
                builder: (context, offset, _) => const SizedBox.expand(),
                minHeight: 0.0,
                // Reserve only the active top-bar height so the first card
                // begins below the rail and then scrolls behind it.
                maxHeight: headerMaxHeight,
              ),
            )
          else if (hideTopBarOnScroll)
            SliverFloatingPinnedPersistentHeader(
              delegate: SliverFloatingPinnedPersistentHeaderBuilder(
                minExtentProtoType: SizedBox(
                  height: context.mediaQueryPadding.top,
                ),
                maxExtentProtoType: navigationBar,
                builder: (_, __, ___) => navigationBar,
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.only(
              top: useLiquidGlass || hideTopBarOnScroll
                  ? 0
                  : (kMinInteractiveDimensionCupertino +
                      context.mediaQueryPadding.top),
            ),
            sliver: EhCupertinoSliverRefreshControl(
              onRefresh: controller.onRefresh,
            ),
          ),
          SliverSafeArea(
            top: false,
            bottom: false,
            sliver: _buildListView(context),
          ),
          Obx(() {
            return SliverSafeArea(
              sliver: EndIndicator(
                pageState: controller.pageState,
                loadDataMore: controller.loadDataMore,
              ),
            );
          }),
        ],
      );

      final Widget pageContent = useLiquidGlass
          ? Stack(
              fit: StackFit.expand,
              children: <Widget>[
                // Themed base below the scroll content: solid through the
                // status-bar safe area, then fading to the shared top fade
                // end, so gap background between cards has no fixed seam.
                // Cards scroll above it and stay visible through the scrim.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LiquidGlassSafeAreaBase(
                    safeTop: layout.safeTop,
                    layout: _ehSettingService.liquidGlassTopBarLayout,
                  ),
                ),
                customScrollView,
                // Fixed solid background above the scroll content and below
                // the scrim and rail. Its lower edge follows the first card
                // without changing the list's scroll geometry.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LiquidGlassSolidMask(
                    progressListenable: _topState.solidMaskProgress,
                    safeTop: layout.safeTop,
                    // The mask bottom follows the first card from safeTop to
                    // the category rail's lower edge.
                    height: headerMaxHeight,
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LiquidGlassTopScrim(
                    safeTop: layout.safeTop,
                    // The period categories are always present.
                    layout: _ehSettingService.liquidGlassTopBarLayout,
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
            )
          : customScrollView;

      if (!useLiquidGlass) {
        return CupertinoPageScaffold(
          navigationBar:
              useLiquidGlass || hideTopBarOnScroll ? null : navigationBar,
          child: SizeCacheWidget(child: pageContent),
        );
      }

      return CupertinoPageScaffold(
        navigationBar: null,
        backgroundColor: const Color(0x00000000),
        child: SizeCacheWidget(
          child: NotificationListener<ScrollNotification>(
            onNotification: _topState.handleScrollNotification,
            child: pageContent,
          ),
        ),
      );
    });
  }

  Widget _buildListView(BuildContext context) {
    return GetBuilder<TopListViewController>(
      global: false,
      init: controller,
      id: controller.listViewId,
      builder: (logic) {
        final status = logic.status;

        if (status.isLoading) {
          return SliverFillRemaining(
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.only(bottom: 50),
              child: const CupertinoActivityIndicator(radius: 14.0),
            ),
          );
        }

        if (status.isError) {
          return SliverFillRemaining(
            child: Container(
              padding: const EdgeInsets.only(bottom: 50),
              child: GalleryErrorPage(
                onTap: logic.reLoadDataFirst,
                error: status.errorMessage,
              ),
            ),
          );
        }

        if (status.isSuccess) {
          return getGallerySliverList(
            logic.state,
            controller.heroTag,
            next: logic.next,
            lastComplete: controller.lastComplete,
            centerKey: centerKey,
            firstCardKey: _firstCardKey,
            key: controller.sliverAnimatedListKey,
            lastTopItemIndex: controller.lastTopitemIndex,
          );
        }

        return SliverFillRemaining(
          child: Container(
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(
                  FontAwesomeIcons.hippo,
                  size: 100,
                  color: CupertinoDynamicColor.resolve(
                    CupertinoColors.systemGrey,
                    context,
                  ),
                ),
                Text(''),
              ],
            ),
          ).autoCompressKeyboard(context),
        );
      },
    );
  }
}
