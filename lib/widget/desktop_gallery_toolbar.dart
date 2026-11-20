import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/tab/controller/group/custom_tabbar_controller.dart';
import 'package:eros_fe/widget/desktop_control.dart';
import 'package:eros_fe/widget/desktop_display_mode_menu.dart';
import 'package:eros_fe/widget/desktop_gallery_actions.dart';
import 'package:eros_fe/widget/desktop_sidebar.dart';
import 'package:eros_fe/widget/macos_window_chrome.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

/// A pane-local toolbar shared by desktop glass and solid appearances.
/// Mobile rails keep their existing layout and gestures.
class DesktopGalleryToolbar extends StatelessWidget {
  const DesktopGalleryToolbar({super.key, required this.controller});

  final CustomTabbarController controller;

  Future<void> _showCommands(BuildContext context, {Offset? position}) {
    final l10n = L10n.of(context);
    return showDesktopGalleryMenu(
      context,
      position: position ?? desktopMenuAnchor(context),
      entries: [
        DesktopMenuEntry(
          label: l10n.jump_or_seek,
          icon: CupertinoIcons.arrow_uturn_down_circle,
          onSelected: () => controller.showJumpDialog(context),
        ),
        if (controller.afterJump)
          DesktopMenuEntry(
            label: l10n.back_to_top,
            icon: CupertinoIcons.arrow_up_circle,
            onSelected: controller.jumpToTop,
          ),
        DesktopMenuEntry(
          label: l10n.group_management,
          icon: CupertinoIcons.folder,
          onSelected: controller.pressedBar,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Obx(() {
    final l10n = L10n.of(context);
    final profile = controller.profileMap[controller.currProfileUuid];
    final busy = controller.isReloading;
    final sidebar = DesktopSidebarScope.maybeOf(context);
    final mac = PlatformCapabilities.hostPlatform == TargetPlatform.macOS;
    final restore = mac && sidebar?.desktop == true && !sidebar!.visible;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          // Only the leftmost toolbar shares space with the native traffic lights.
          if (mac && !(sidebar?.visible ?? false))
            ValueListenableBuilder<MacOSWindowControls>(
              valueListenable: MacOSWindowChrome.controls,
              builder: (_, controls, _) => SizedBox(width: controls.leading),
            ),
          if (restore)
            DesktopControl(
              key: const ValueKey('desktop-show-sidebar'),
              label: l10n.desktop_show_sidebar,
              onPressed: sidebar.onShow,
              padding: const EdgeInsets.all(6),
              child: const Icon(CupertinoIcons.sidebar_left, size: 18),
            ),
          Flexible(
            child: Builder(
              builder: (anchor) => DesktopControl(
                label:
                    '${profile?.name ?? l10n.tab_gallery} · ${l10n.group_management}',
                padding: const EdgeInsets.symmetric(horizontal: 8),
                onPressed: () => _showCommands(anchor),
                onSecondaryTapDown: (event) =>
                    _showCommands(anchor, position: event.globalPosition),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        profile?.name ?? l10n.tab_gallery,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(CupertinoIcons.chevron_down, size: 10),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: MoveWindow(child: const SizedBox.expand())),
          DesktopControl(
            key: const ValueKey('desktop-refresh-list'),
            label: busy ? l10n.desktop_refreshing : l10n.desktop_refresh,
            onPressed: busy || profile == null
                ? null
                : controller.refreshFromToolbar,
            padding: const EdgeInsets.all(5),
            child: busy
                ? CupertinoActivityIndicator(
                    radius: 9,
                    animating: !MediaQuery.disableAnimationsOf(context),
                  )
                : const Icon(CupertinoIcons.arrow_clockwise, size: 18),
          ),
          const SizedBox(width: 4),
          Builder(
            builder: (anchor) => DesktopControl(
              key: const ValueKey('desktop-display-mode'),
              label: l10n.desktop_display_mode,
              padding: const EdgeInsets.all(5),
              onPressed: () =>
                  showDesktopDisplayModeMenu(anchor, controller: controller),
              child: const Icon(CupertinoIcons.square_grid_2x2, size: 18),
            ),
          ),
        ],
      ),
    );
  });
}
