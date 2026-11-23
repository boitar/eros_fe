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

  /// The category currently shown in the split detail pane, highlighted in the
  /// master list.
  final RxnString openCategory = RxnString();

  /// Reopened when the desktop detail pane would otherwise be empty.
  String lastCategory = EHRoutes.layoutSetting;

  /// The category a detail stack shows: its first settings page. Pages a
  /// category opens on top of itself keep their category selected.
  static String? categoryIn(Iterable<Route<dynamic>> history) => history
      .map((route) => route.settings.name)
      .firstWhereOrNull(
        (name) => name?.startsWith('${EHRoutes.setting}/') ?? false,
      );

  bool _tracksSplitSelection({bool? split}) {
    if (split != null) {
      return split && PlatformCapabilities.hostPlatform != TargetPlatform.android;
    }
    if (usesDesktopSettingPanes) {
      return true;
    }
    if (PlatformCapabilities.hostPlatform == TargetPlatform.android) {
      return false;
    }
    return Get.isRegistered<LayoutServices>() && isLayoutLarge;
  }

  int? _detailNavigatorIdForSplit() {
    if (!Get.isRegistered<LayoutServices>()) {
      return detailNavigatorId;
    }
    return Get.find<LayoutServices>().tabNavigation.selected?.detailId ??
        detailNavigatorId;
  }

  bool get _isSafeSettingStack {
    if (!Get.isRegistered<LayoutServices>()) {
      return false;
    }
    return Get.find<LayoutServices>().tabNavigation.selectedId ==
        'safe:${EHRoutes.setting}';
  }

  void _openSplit(String route) {
    if (!_isSafeSettingStack) {
      lastCategory = route;
    }
    openCategory.value = route.startsWith('${EHRoutes.setting}/')
        ? route
        : null;
    // A category replaces whatever the pane shows, its sub-pages included,
    // so the list and the pane always agree.
    Get.offNamedUntil<void>(
      route,
      (existing) => existing.isFirst,
      // The settings tab's own detail navigator, named directly.
      id: _detailNavigatorIdForSplit(),
    );
  }

  void open(String route, {bool? split}) {
    final bool desktopPanes = usesDesktopSettingPanes && (split ?? true);
    if (desktopPanes || split == true) {
      _openSplit(route);
      return;
    }
    // Keep the existing page-stack behavior outside the split master/detail
    // settings UI; large Android layouts still use Android's grouped settings.
    if (isLayoutLarge) {
      final topRoute =
          SecondNavigatorObserver().history.lastOrNull?.settings.name;
      if (topRoute?.startsWith('${EHRoutes.setting}/') ?? false) {
        Get.offNamed<void>(route, id: detailNavigatorId);
      } else {
        Get.toNamed<void>(route, id: detailNavigatorId);
      }
      return;
    }
    Get.toNamed<void>(route, id: detailNavigatorId);
  }

  /// Follows the settings tab's detail pane in split view: keeps
  /// [openCategory] aligned with the active category on both desktop and
  /// non-desktop split hosts (such as iPad / iPhone Duo), and on desktop also
  /// reopens [lastCategory] whenever the pane would otherwise be empty.
  void syncPane({bool? split}) {
    if (!_tracksSplitSelection(split: split)) {
      openCategory.value = null;
      return;
    }
    if (!Get.isRegistered<LayoutServices>()) {
      return;
    }
    final navigation = Get.find<LayoutServices>().tabNavigation;
    if (!LayoutServices.isSettingStack(navigation.selectedId)) {
      return;
    }
    final stack = navigation.selected;
    if (stack == null || Get.nestedKey(stack.detailId)?.currentState == null) {
      return;
    }
    final category = categoryIn(stack.detailObserver.history);
    openCategory.value = category;
    if (category != null) {
      if (!_isSafeSettingStack) {
        lastCategory = category;
      }
    } else if (usesDesktopSettingPanes && (split ?? true)) {
      final route = _isSafeSettingStack &&
              lastCategory == EHRoutes.accountSession
          ? EHRoutes.layoutSetting
          : lastCategory;
      _openSplit(route);
    }
  }

  /// Follows the settings tab's detail pane on desktop and other split hosts.
  void syncDesktopPane() => syncPane();
}
