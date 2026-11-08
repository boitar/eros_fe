import 'package:collection/collection.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/index.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// macOS and Windows windows wide enough for a split show settings as two
/// panes, like a desktop settings window: the categories on the left and the
/// open category on the right, which is never left empty.
bool get usesDesktopSettingPanes =>
    PlatformCapabilities.isDesktop &&
    Get.isRegistered<LayoutServices>() &&
    isLayoutLarge;

class SettingViewController extends GetxController {
  /// The large title has scrolled under the bar, so the bar names the page.
  final RxBool titleInBar = false.obs;

  /// Content has scrolled under the bar, which shows its soft edge.
  final RxBool contentUnderBar = false.obs;

  /// The category the desktop detail pane shows, highlighted in the list.
  final RxnString openCategory = RxnString();

  /// Reopened when the pane would otherwise be empty.
  String lastCategory = EHRoutes.layoutSetting;

  /// The category a detail stack shows: its first settings page. Pages a
  /// category opens on top of itself keep their category selected.
  static String? categoryIn(Iterable<Route<dynamic>> history) => history
      .map((route) => route.settings.name)
      .firstWhereOrNull(
        (name) => name?.startsWith('${EHRoutes.setting}/') ?? false,
      );

  void open(String route) {
    if (usesDesktopSettingPanes) {
      lastCategory = route;
      // A category replaces whatever the pane shows, its sub-pages included,
      // so the list and the pane always agree.
      Get.offNamedUntil<void>(
        route,
        (existing) => existing.isFirst,
        // The settings tab's own detail navigator, named directly.
        id:
            Get.find<LayoutServices>().tabNavigation.selected?.detailId ??
            detailNavigatorId,
      );
      return;
    }
    if (isLayoutLarge) {
      final topRoute =
          SecondNavigatorObserver().history.lastOrNull?.settings.name;
      if (topRoute?.startsWith('/setting') ?? false) {
        Get.offNamed(route, id: detailNavigatorId);
      } else {
        Get.toNamed(route, id: detailNavigatorId);
      }
    } else {
      Get.toNamed(route, id: detailNavigatorId);
    }
  }

  /// Follows the settings tab's detail pane on desktop: notes its category
  /// and opens the last one when the pane is empty (first visit, or after
  /// going back from a category).
  void syncDesktopPane() {
    if (!usesDesktopSettingPanes) {
      openCategory.value = null;
      return;
    }
    final navigation = Get.find<LayoutServices>().tabNavigation;
    if (navigation.selectedId != EHRoutes.setting) {
      return;
    }
    final stack = navigation.selected;
    if (stack == null || Get.nestedKey(stack.detailId)?.currentState == null) {
      return;
    }
    final category = categoryIn(stack.detailObserver.history);
    openCategory.value = category;
    if (category == null) {
      open(lastCategory);
    } else {
      lastCategory = category;
    }
  }
}
