import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/tab/controller/search_page_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

class TabHomeSmall extends StatefulWidget {
  const TabHomeSmall({super.key});

  @override
  State<TabHomeSmall> createState() => _TabHomeSmallState();
}

class _TabHomeSmallState extends State<TabHomeSmall> {
  final LiquidGlassBarMotion _barMotion = LiquidGlassBarMotion();
  late final TabHomeController controller = Get.find<TabHomeController>();

  @override
  void dispose() {
    _barMotion.dispose();
    super.dispose();
  }

  void _handleTabTap(int index) {
    _barMotion.reset();
    controller.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    controller.init(inContext: context);
    final EhSettingService ehSettingService = Get.find();

    return Obx(() {
      final useLiquidGlass =
          ehSettingService.liquidGlass && LiquidGlassPlatform.isSupported;
      final tabBar = useLiquidGlass
          ? LiquidGlassTabBar(
              items: controller.listBottomNavigationBarItem,
              motion: _barMotion,
              onTap: _handleTabTap,
              followSystemTransparency:
                  ehSettingService.liquidGlassFollowSystemTransparency,
              hideSearchOnScroll:
                  ehSettingService.hideLiquidGlassSearchOnScroll,
              nativeItems: controller.liquidGlassTabItems,
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
              onTap: _handleTabTap,
            );

      return CupertinoTabScaffold(
        controller: controller.tabController,
        tabBar: tabBar,
        tabBuilder: (BuildContext context, int index) {
          // return controller.viewList[index];
          return CupertinoTabView(
            builder: (BuildContext context) {
              // logger.d('build CupertinoTabView');
              return NotificationListener<ScrollNotification>(
                onNotification: _barMotion.handleScrollNotification,
                child: controller.viewList[index],
              );
            },
          );
        },
      );
    });
  }
}
