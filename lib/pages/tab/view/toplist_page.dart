import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/pages/tab/controller/toplist_controller.dart';
import 'package:eros_fe/pages/tab/view/list/tab_base.dart';
import 'package:eros_fe/utils/cust_lib/persistent_header_builder.dart';
import 'package:eros_fe/utils/cust_lib/sliver/sliver_persistent_header.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/refresh.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:eros_fe/widget/link_scroll_bar.dart';
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

  GlobalKey centerKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    controller.initStateForListPage(
      context: context,
      ehTabController: ehTabController,
    );
  }

  LiquidGlassRail _buildGlassRail(
    BuildContext context,
    LiquidGlassTopLayout layout,
    double collapseProgress,
  ) {
    final l10n = L10n.of(context);
    final periodTitles = <String>[
      l10n.tolist_yesterday,
      l10n.tolist_past_month,
      l10n.tolist_past_year,
      l10n.tolist_alltime,
    ];
    return LiquidGlassRail(
      title: controller.getTopListTitle,
      safeTop: layout.safeTop,
      collapseProgress: collapseProgress,
      dockingTranslation: layout.dockingTranslation,
      selectedIndex:
          ToplistType.values.indexOf(controller.ehSettingService.toplist),
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
          onPressed: () => controller.setToplist(context),
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
            title: periodTitles[index],
            onTap: () => controller.setToplist(
              context,
              type: ToplistType.values[index],
            ),
          ),
      ],
      onTitleTap: () => controller.scrollToTop(context),
      refreshing: controller.isBackgroundRefresh,
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isRefresh = false;

    final navigationBar = CupertinoNavigationBar(
      transitionBetweenRoutes: false,
      padding: const EdgeInsetsDirectional.only(end: 4),
      leading: controller.getLeading(context),
      middle: Obx(() {
        return GestureDetector(
          onTap: () => controller.scrollToTop(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(controller.getTopListTitle),
              Obx(() {
                if (controller.isBackgroundRefresh)
                  return const CupertinoActivityIndicator(
                    radius: 10,
                  ).paddingSymmetric(horizontal: 8);
                else
                  return const SizedBox();
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
            StatefulBuilder(builder: (context, setState) {
              return CupertinoButton(
                padding: const EdgeInsets.all(0),
                minSize: 40,
                child: isRefresh
                    ? const CupertinoActivityIndicator(
                        radius: 10,
                      )
                    : const Icon(
                        CupertinoIcons.arrow_clockwise,
                        size: 24,
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
            }),
          CupertinoButton(
            padding: const EdgeInsets.all(0.0),
            minSize: 40,
            child: const Stack(
              alignment: Alignment.centerRight,
              // mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  CupertinoIcons.sort_down,
                  size: 28,
                ),
              ],
            ),
            onPressed: () => controller.setToplist(context),
          ),
          Obx(() {
            if (controller.afterJump) {
              return CupertinoButton(
                minSize: 40,
                padding: const EdgeInsets.all(0),
                child: const Icon(
                  CupertinoIcons.arrow_up_circle,
                  size: 28,
                ),
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
      final hideTopBarOnScroll =
          _ehSettingService.hideTopBarOnScroll || useLiquidGlass;
      final mediaQuery = MediaQuery.of(context);
      final layout = LiquidGlassTopLayout.fromMediaQuery(mediaQuery);
      final headerMaxHeight = mediaQuery.viewPadding.top +
          (useLiquidGlass
              ? LiquidGlassRail.expandedHeight
              : kMinInteractiveDimensionCupertino);
      final dockTopBar =
          useLiquidGlass && hideTopBarOnScroll && layout.canDockTopRail;

      final customScrollView = CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          if (useLiquidGlass)
            SliverPersistentHeader(
              floating: true,
              pinned: true,
              delegate: FooSliverPersistentHeaderDelegate(
                builder: (context, offset, _) => Obx(
                  () => _buildGlassRail(
                    context,
                    layout,
                    dockTopBar
                        ? layout.collapseProgress(
                            offset,
                            headerMaxHeight - layout.collapsedHeaderHeight,
                          )
                        : 0.0,
                  ),
                ),
                minHeight:
                    dockTopBar ? layout.collapsedHeaderHeight : headerMaxHeight,
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

      return CupertinoPageScaffold(
        navigationBar:
            useLiquidGlass || hideTopBarOnScroll ? null : navigationBar,
        child: SizeCacheWidget(child: customScrollView),
      );
    });
  }

  Widget _buildListView(
    BuildContext context,
  ) {
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
              child: const CupertinoActivityIndicator(
                radius: 14.0,
              ),
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
                      CupertinoColors.systemGrey, context),
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
