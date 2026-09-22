import 'package:blur/blur.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/tab/controller/favorite/favorite_tabbar_controller.dart';
import 'package:eros_fe/pages/tab/controller/search_page_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
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

class _FavoriteTabTabBarPageState extends State<FavoriteTabTabBarPage> {
  final EhTabController ehTabController = EhTabController();
  final LinkScrollBarController linkScrollBarController =
      LinkScrollBarController();
  final controller = Get.find<FavoriteTabBarController>();
  late PageController pageController;

  final EhSettingService _ehSettingService = Get.find();

  @override
  void initState() {
    super.initState();
    pageController = PageController(initialPage: controller.index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _synchronizePageWithSelectedIndex();
    });
  }

  void _synchronizePageWithSelectedIndex() {
    if (!mounted || !pageController.hasClients) return;
    final favcats = controller.favcatList;
    if (favcats.isEmpty) return;
    final target = controller.index.clamp(0, favcats.length - 1).toInt();
    final current = pageController.page;
    if (current == null || (current - target).abs() > 0.01) {
      pageController.jumpToPage(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final layout = LiquidGlassTopLayout.fromMediaQuery(mediaQuery);
    final headerMaxHeight = mediaQuery.viewPadding.top +
        (_ehSettingService.liquidGlass && LiquidGlassPlatform.isSupported
            ? LiquidGlassRail.expandedHeight
            : kHeaderMaxHeight);

    return Obx(() {
      final liquidGlass =
          _ehSettingService.liquidGlass && LiquidGlassPlatform.isSupported;
      final hideTopBarOnScroll =
          _ehSettingService.hideTopBarOnScroll || liquidGlass;

      final scrollView = buildNestedScrollView(
        headerMaxHeight,
        hideTopBarOnScroll,
        liquidGlass,
        layout,
      );

      return CupertinoPageScaffold(
        // navigationBar: navigationBar,
        child: SizeCacheWidget(child: scrollView),
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
    if (liquidGlass) {
      final double collapseProgress = dockTopBar
          ? layout.collapseProgress(
              offset,
              maxExtentCallBackValue - layout.collapsedHeaderHeight,
            )
          : 0.0;
      return _buildGlassRail(context, collapseProgress, layout);
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
            (offset / (kMinInteractiveDimensionCupertino - 1)).clamp(0.0, 1.0);
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
              offset: Offset(
                0,
                -layout.dockingTranslation * collapseProgress,
              ),
              child: Transform.scale(
                alignment: Alignment.topCenter,
                scale: 1.0 - collapseProgress * 0.18,
                child: Stack(
                  children: [
                    getNavigationBar(context, opacity: navBarOpacity),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: FavoriteTabBar(
                        pageController: pageController,
                        linkScrollBarController: linkScrollBarController,
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
    double collapseProgress,
    LiquidGlassTopLayout layout,
  ) {
    return LiquidGlassRail(
      title: L10n.of(context).tab_favorite,
      safeTop: layout.safeTop,
      collapseProgress: collapseProgress,
      dockingTranslation: layout.dockingTranslation,
      selectedIndex: controller.index,
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
          label: '收藏排序',
          onPressed: () => controller.setOrder(context),
        ),
        LiquidGlassRailAction(
          icon: CupertinoIcons.arrow_uturn_down_circle,
          label: '跳转/搜寻',
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
                    id: isLayoutLarge ? 1 : null,
                  );
                  if (result != null && result is Favcat) {
                    final index = controller.favcatList.indexWhere(
                      (element) => element.favId == result.favId,
                    );
                    if (index >= 0) {
                      pageController.jumpToPage(index);
                    }
                  }
                },
              ),
            ]
          : const <LiquidGlassRailAction>[],
      categories: controller.favcatList
          .map(
            (favcat) => LiquidGlassRailCategory(
              title: favcat.favTitle,
              onTap: () {
                final index = controller.favcatList.indexOf(favcat);
                pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
              },
            ),
          )
          .toList(),
      onTitleTap: () => controller.scrollToTop(context),
      refreshing: controller.isBackgroundRefresh,
    );
  }

  Widget buildNestedScrollView(
    double headerMaxHeight,
    bool hideTopBarOnScroll,
    bool liquidGlass,
    LiquidGlassTopLayout layout,
  ) {
    final dockTopBar =
        liquidGlass && hideTopBarOnScroll && layout.canDockTopRail;
    return ExtendedNestedScrollView(
      floatHeaderSlivers: true,
      onlyOneScrollInBody: true,
      headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
        return [
          SliverOverlapAbsorber(
            handle: ExtendedNestedScrollView.sliverOverlapAbsorberHandleFor(
              context,
            ),
            sliver: SliverPersistentHeader(
              floating: true,
              pinned: true,
              delegate: FooSliverPersistentHeaderDelegate(
                builder: (context, offset, _) => Obx(
                  () => _buildTopBar(
                    context,
                    offset,
                    headerMaxHeight,
                    layout: layout,
                    dockTopBar: dockTopBar,
                    liquidGlass: liquidGlass,
                  ),
                ),
                // minHeight: context.mediaQueryPadding.top + kTopTabbarHeight,
                minHeight: hideTopBarOnScroll
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
  }

  Builder buildBody(bool liquidGlass, bool hideTopBarOnScroll) {
    return Builder(builder: (context) {
      return GestureDetector(
        onPanDown: (e) {
          // 恢复启用 scrollToItem
          linkScrollBarController.enableScrollToItem();
        },
        child: Obx(() {
          final pageView = PageView(
            key: ValueKey(controller.showBarsBtn), // 登录状态变化后能刷新
            controller: pageController,
            children: [
              ...controller.favcatList.map((e) => FavoriteSubPage(
                    favcat: e.favId,
                    pinned: !hideTopBarOnScroll,
                    liquidGlass: liquidGlass,
                  )),
            ],
            onPageChanged: (index) {
              linkScrollBarController.scrollToItem(index);
              controller.onPageChanged(index);
            },
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _synchronizePageWithSelectedIndex();
          });
          return pageView;
        }),
      );
    });
  }

  Widget getNavigationBar(BuildContext context, {double? opacity}) {
    return Obx(() {
      final useLiquidGlass =
          _ehSettingService.liquidGlass && LiquidGlassPlatform.isSupported;
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
            onTap: () => controller.scrollToTop(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(L10n.of(context).tab_favorite),
                Obx(() {
                  if (controller.isBackgroundRefresh) {
                    return const CupertinoActivityIndicator(
                      radius: 10,
                    ).paddingSymmetric(horizontal: 8);
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
              // 搜索按钮
              CupertinoButton(
                minSize: 40,
                padding: const EdgeInsets.all(0),
                child: Semantics(
                  label: '搜索',
                  child: const Icon(
                    // FontAwesomeIcons.magnifyingGlass,
                    CupertinoIcons.search,
                    size: 28,
                  ),
                ),
                onPressed: () {
                  final bool fromTabItem = Get.find<TabHomeController>()
                          .tabMap[controller.heroTag ?? ''] ??
                      false;
                  NavigatorUtil.goSearchPage(
                      searchType: SearchType.favorite,
                      fromTabItem: fromTabItem);
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
                      const Icon(
                        CupertinoIcons.sort_down,
                        size: 28,
                      ),
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
                      child: const Icon(
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
                  child: const Icon(
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
          ehSettingService.liquidGlass && LiquidGlassPlatform.isSupported;

      final Widget bar = Stack(
        alignment: Alignment.topCenter,
        children: [
          if (!useLiquidGlass)
            Blur(
              blur: 10,
              blurColor: barBackgroundColor,
              colorOpacity: kEnableImpeller ? 1.0 : opacity,
              child: Container(
                height: kTopTabbarHeight,
              ),
            ),
          Container(
            decoration: useLiquidGlass
                ? null
                : const BoxDecoration(
                    border: kDefaultNavBarBorder,
                  ),
            padding: EdgeInsets.only(
              left: context.mediaQueryPadding.left,
              right: context.mediaQueryPadding.right,
            ),
            child: SizedBox(
              height: kTopTabbarHeight,
              child: Obx(() {
                return Row(
                  children: [
                    Expanded(
                      child: LinkScrollBar(
                        pageController: pageController,
                        controller: linkScrollBarController,
                        items: controller.favcatList
                            .map((e) => LinkTabItem(
                                  title: e.favTitle,
                                  // icon: LineIcons.dotCircleAlt,
                                ))
                            .toList(),
                        itemPadding: const EdgeInsets.symmetric(horizontal: 8),
                        initIndex: controller.index,
                        onItemChange: (index) => pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.ease),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 刷新按钮
                          if (GetPlatform.isDesktop)
                            Builder(builder: (context) {
                              bool isRefresh = false;
                              return StatefulBuilder(
                                  builder: (context, setState) {
                                return CupertinoButton(
                                  minSize: 40,
                                  padding: const EdgeInsets.all(0),
                                  child: isRefresh
                                      ? const CupertinoActivityIndicator(
                                          radius: 10)
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
                              });
                            }),
                          if (controller.showBarsBtn)
                            CupertinoButton(
                              minSize: 40,
                              padding: const EdgeInsets.all(0),
                              child: Semantics(
                                label: '选择收藏夹',
                                child: const FaIcon(
                                  FontAwesomeIcons.bars,
                                  size: 20,
                                ),
                              ),
                              onPressed: () async {
                                // 跳转收藏夹选择页
                                final result = await Get.toNamed(
                                  EHRoutes.selFavorite,
                                  id: isLayoutLarge ? 1 : null,
                                );
                                if (result != null && result is Favcat) {
                                  final index = controller.favcatList
                                      .indexWhere((element) =>
                                          element.favId == result.favId);
                                  pageController.jumpToPage(index);
                                }
                              },
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
}
