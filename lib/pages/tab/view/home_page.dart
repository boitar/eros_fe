import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'home_page_large.dart';

class HomePage extends GetView<TabHomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // controller.init(inContext: context);
    final LayoutServices layoutServices = Get.find();
    final EhSettingService ehSettingService = Get.find();

    final child = Obx(
      () {
        final tabletLayoutType = ehSettingService.tabletLayoutType;

        logger.t(' ${context.width} ${context.height}');

        layoutServices.layoutMode = getLayoutMode(context, tabletLayoutType);

        return TabHomeLarge(split: isLayoutLarge);
      },
    );

    // return PopScope(
    //   canPop: false,
    //   onPopInvoked: controller.onPopInvoked,
    //   child: child,
    // );

    return WillPopScope(
      onWillPop: controller.onWillPop,
      child: child,
    );
  }

  LayoutMode getLayoutMode(
      BuildContext context, TabletLayout tabletLayoutType) {
    final adaptive = AdaptiveEnvironment.maybeOf(context) ??
        AdaptiveEnvironmentSnapshot.fromMediaQuery(context);

    // The split shell is based on usable space, not on an iPad/device
    // predicate. This keeps Duo inner portrait and narrow Split View single
    // column while allowing the inner landscape to use list/detail panes.
    if (tabletLayoutType == TabletLayout.never || !adaptive.isSplit) {
      return LayoutMode.small;
    }
    if (tabletLayoutType == TabletLayout.landscape &&
        adaptive.size.width <= adaptive.size.height) {
      return LayoutMode.small;
    }
    return LayoutMode.large;
  }
}
