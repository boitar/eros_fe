import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/pages/tab/controller/group/custom_tabbar_controller.dart';
import 'package:eros_fe/widget/desktop_gallery_actions.dart';
import 'package:flutter/cupertino.dart';
import 'package:eros_fe/pages/setting/layout_setting_page.dart'
    show listModeLabels;
import 'package:eros_fe/utils/toast.dart';
import 'package:get/get.dart';

Offset desktopMenuAnchor(BuildContext context) {
  final object = context.findRenderObject();
  if (object is RenderBox && object.hasSize) {
    return object.localToGlobal(Offset(object.size.width, object.size.height));
  }
  return const Offset(16, 52);
}

Future<void> showDesktopDisplayModeMenu(
  BuildContext context, {
  required CustomTabbarController controller,
  Offset? position,
}) {
  final l10n = L10n.of(context);
  final labels = listModeLabels(context);
  final current = controller.currentListMode;
  final followsGlobal = controller.currentListFollowsGlobal;
  final uuid = controller.currProfileUuid;
  final profile = controller.profileMap[uuid];
  Future<void> select(ListModeEnum mode) async {
    try {
      if (profile != null) {
        await controller.setGroupListMode(uuid, mode);
      } else if (mode != ListModeEnum.global) {
        Get.find<EhSettingService>().listMode.value = mode;
      }
    } catch (_) {
      showToast(l10n.desktop_mode_sync_failed);
    }
  }

  final globalLabel = labels[Get.find<EhSettingService>().listMode.value];
  final entries = <DesktopMenuEntry>[
    if (profile != null)
      DesktopMenuEntry(
        label: '${l10n.desktop_follow_global} · $globalLabel',
        icon: CupertinoIcons.arrow_right_arrow_left,
        selected: followsGlobal,
        onSelected: () => select(ListModeEnum.global),
      ),
    for (final entry in labels.entries)
      DesktopMenuEntry(
        label: entry.value,
        icon: _iconFor(entry.key),
        selected: !followsGlobal && current == entry.key,
        onSelected: () => select(entry.key),
      ),
  ];
  return showDesktopGalleryMenu(
    context,
    position: position ?? desktopMenuAnchor(context),
    entries: entries,
    title: profile == null
        ? l10n.desktop_global_mode
        : '${l10n.desktop_current_group} · ${profile.name}',
    subtitle: profile == null ? l10n.desktop_global_mode_hint : null,
  );
}

IconData _iconFor(ListModeEnum mode) => switch (mode) {
  ListModeEnum.list => CupertinoIcons.list_bullet,
  ListModeEnum.simpleList => CupertinoIcons.list_bullet_indent,
  ListModeEnum.waterfall => CupertinoIcons.rectangle_grid_2x2,
  ListModeEnum.waterfallLarge => CupertinoIcons.rectangle_grid_1x2,
  ListModeEnum.grid => CupertinoIcons.square_grid_2x2,
  ListModeEnum.gridTags => CupertinoIcons.square_grid_3x2,
  ListModeEnum.debugSimple => CupertinoIcons.ant,
  ListModeEnum.global => CupertinoIcons.globe,
};
