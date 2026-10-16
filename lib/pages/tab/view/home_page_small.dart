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
    controller.resetTabTapSequence();
    _barMotion.dispose();
    super.dispose();
  }

  void _handleTabTap(int index, {required bool useLiquidGlass}) {
    _barMotion.reset();
    controller.onTap(index, useLiquidGlass: useLiquidGlass);
  }

  @override
  Widget build(BuildContext context) {
    controller.init(inContext: context);
    final EhSettingService ehSettingService = Get.find();

    return Obx(() {
      final useLiquidGlass =
          ehSettingService.liquidGlass && LiquidGlassPlatform.isSupported;
      controller.setNavigationMode(useLiquidGlass: useLiquidGlass);
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
        child: CupertinoTabScaffold(
          controller: controller.tabController,
          tabBar: tabBar,
          tabBuilder: (BuildContext context, int index) {
            // return controller.viewList[index];
            return CupertinoTabView(
              builder: (BuildContext context) {
                // Glass pages feed their own LiquidGlassTopStateCoordinator
                // with scroll notifications; the shared bar motion is written
                // only by that coordinator, so the top bar fade and the
                // initial anchor never process the same page notifications
                // twice.
                return controller.viewList[index];
              },
            );
          },
        ),
      );
    });
  }
}
