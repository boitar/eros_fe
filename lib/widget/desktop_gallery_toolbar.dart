import 'dart:math' as math;

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/tab/controller/group/custom_tabbar_controller.dart';
import 'package:eros_fe/utils/toast.dart';
import 'package:eros_fe/widget/desktop_browse_style.dart';
import 'package:eros_fe/widget/desktop_control.dart';
import 'package:eros_fe/widget/desktop_display_mode_menu.dart';
import 'package:eros_fe/widget/desktop_gallery_actions.dart';
import 'package:eros_fe/widget/desktop_sidebar.dart';
import 'package:eros_fe/widget/macos_window_chrome.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';

/// A pane-local toolbar shared by desktop glass and solid appearances.
/// Mobile rails keep their existing layout and gestures.
class DesktopGalleryToolbar extends StatelessWidget {
  const DesktopGalleryToolbar({super.key, required this.controller});

  final CustomTabbarController controller;

  Offset _bottomLeftAnchor(BuildContext context) {
    final object = context.findRenderObject();
    if (object is RenderBox && object.hasSize) {
      return object.localToGlobal(Offset(0, object.size.height + 4));
    }
    return const Offset(16, 52);
  }

  ListModeEnum _resolveListMode() {
    try {
      return controller.currentListMode;
    } catch (_) {
      return ListModeEnum.list;
    }
  }

  int? _resolveItemCount() {
    try {
      final length = controller.currentSubController?.state?.length;
      return length != null && length > 0 ? length : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _setViewMode(BuildContext context, ListModeEnum mode) async {
    final l10n = L10n.of(context);
    final uuid = controller.currProfileUuid;
    final profile = controller.profileMap[uuid];
    try {
      if (profile != null) {
        await controller.setGroupListMode(uuid, mode);
      } else if (mode != ListModeEnum.global &&
          Get.isRegistered<EhSettingService>()) {
        Get.find<EhSettingService>().listMode.value = mode;
      }
    } catch (_) {
      showToast(l10n.desktop_mode_sync_failed);
    }
  }

  Future<void> _showGroupMenu(BuildContext context, {Offset? position}) {
    final l10n = L10n.of(context);
    final profiles = controller.profilesShow;
    final currentUuid = controller.currProfileUuid;
    return showDesktopGalleryMenu(
      context,
      position: position ?? _bottomLeftAnchor(context),
      entries: [
        for (var i = 0; i < profiles.length; i++)
          DesktopMenuEntry(
            label: profiles[i].name,
            icon: CupertinoIcons.collections,
            selected: profiles[i].uuid == currentUuid,
            onSelected: () => controller.selectPage(i),
          ),
        DesktopMenuEntry(
          dividerBefore: profiles.isNotEmpty,
          label: l10n.group_management,
          icon: CupertinoIcons.folder,
          onSelected: controller.pressedBar,
        ),
      ],
    );
  }

  Future<void> _showMoreMenu(BuildContext context, {Offset? position}) {
    final l10n = L10n.of(context);
    return showDesktopGalleryMenu(
      context,
      position: position ?? desktopMenuAnchor(context),
      entries: [
        DesktopMenuEntry(
          label: l10n.desktop_display_mode,
          icon: CupertinoIcons.square_grid_2x2,
          onSelected: () => showDesktopDisplayModeMenu(
            context,
            controller: controller,
            position: position,
          ),
        ),
        if (controller.afterJump)
          DesktopMenuEntry(
            label: l10n.back_to_top,
            icon: CupertinoIcons.arrow_up_circle,
            onSelected: controller.jumpToTop,
          ),
        DesktopMenuEntry(
          dividerBefore: true,
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
    final palette = ehTheme.palette;
    final profile = controller.profileMap[controller.currProfileUuid];
    final busy = controller.isReloading;
    final sidebar = DesktopSidebarScope.maybeOf(context);
    final mac = PlatformCapabilities.hostPlatform == TargetPlatform.macOS;
    final restore = sidebar?.desktop == true && !sidebar!.visible;
    final paneLeftInset = (sidebar?.desktop ?? false)
        ? DesktopBrowseStyle.inset
        : 0.0;
    final mode = _resolveListMode();
    final isListMode =
        mode == ListModeEnum.list || mode == ListModeEnum.simpleList;
    final itemCount = _resolveItemCount();

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 10, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Only the leftmost toolbar shares space with the native traffic lights.
          if (mac && !(sidebar?.visible ?? false))
            ValueListenableBuilder<MacOSWindowControls>(
              valueListenable: MacOSWindowChrome.controls,
              builder: (_, controls, _) => SizedBox(
                width: math.max(0.0, controls.leading - paneLeftInset - 6.0),
              ),
            ),
          if (restore) ...[
            DesktopControl(
              key: const ValueKey('desktop-show-sidebar'),
              label: l10n.desktop_show_sidebar,
              minSize: 30,
              radius: 8,
              onPressed: sidebar.onShow,
              padding: const EdgeInsets.all(6),
              child: const EhSvgIcon(CupertinoIcons.sidebar_left, size: 17),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                width: 1,
                height: 16,
                child: ColoredBox(color: palette.hairline.resolveFrom(context)),
              ),
            ),
          ],
          // Single Expanded guarantees the right action cluster stays flush right.
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                if (mac)
                  Positioned.fill(
                    child: MoveWindow(child: const SizedBox.expand()),
                  ),
                LayoutBuilder(
                  builder: (context, constraints) => Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Builder(
                            builder: (anchor) => DesktopControl(
                              key: const ValueKey('desktop-group-menu'),
                              label:
                                  '${profile?.name ?? l10n.tab_gallery} · ${l10n.group_management}',
                              minSize: 30,
                              radius: 8,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              onPressed: () => _showGroupMenu(anchor),
                              onSecondaryTapDown: (event) => _showGroupMenu(
                                anchor,
                                position: event.globalPosition,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      profile?.name ?? l10n.tab_gallery,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: palette.text1.resolveFrom(
                                          context,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  EhSvgIcon(
                                    CupertinoIcons.chevron_down,
                                    size: 10,
                                    color: palette.text3.resolveFrom(context),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (itemCount != null && constraints.maxWidth >= 140)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: palette.fill.resolveFrom(context),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$itemCount',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  color: palette.text2.resolveFrom(context),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DesktopControl(
            key: const ValueKey('desktop-jump-page'),
            label: l10n.jump_or_seek,
            minSize: 30,
            radius: 8,
            onPressed: profile == null
                ? null
                : () => controller.showJumpDialog(context),
            padding: const EdgeInsets.all(6),
            child: const EhSvgIcon(CupertinoIcons.arrow_up_arrow_down, size: 15),
          ),
          const SizedBox(width: 2),
          DesktopControl(
            key: const ValueKey('desktop-refresh-list'),
            label: busy ? l10n.desktop_refreshing : l10n.desktop_refresh,
            minSize: 30,
            radius: 8,
            onPressed: busy || profile == null
                ? null
                : controller.refreshFromToolbar,
            padding: const EdgeInsets.all(6),
            child: busy
                ? CupertinoActivityIndicator(
                    radius: 8,
                    animating: !MediaQuery.disableAnimationsOf(context),
                  )
                : const EhSvgIcon(CupertinoIcons.arrow_clockwise, size: 16),
          ),
          const SizedBox(width: 6),
          _ViewModeSegmentedSwitch(
            isListMode: isListMode,
            label: l10n.desktop_display_mode,
            onSelectList: (anchor) {
              if (isListMode) {
                showDesktopDisplayModeMenu(anchor, controller: controller);
              } else {
                _setViewMode(anchor, ListModeEnum.list);
              }
            },
            onSelectGrid: (anchor) {
              if (!isListMode) {
                showDesktopDisplayModeMenu(anchor, controller: controller);
              } else {
                _setViewMode(anchor, ListModeEnum.grid);
              }
            },
            onOpenMenu: (anchor, position) => showDesktopDisplayModeMenu(
              anchor,
              controller: controller,
              position: position,
            ),
          ),
          const SizedBox(width: 4),
          Builder(
            builder: (anchor) => DesktopControl(
              key: const ValueKey('desktop-more-actions'),
              label: l10n.more_actions,
              minSize: 30,
              radius: 8,
              padding: const EdgeInsets.all(6),
              onPressed: () => _showMoreMenu(anchor),
              onSecondaryTapDown: (event) =>
                  _showMoreMenu(anchor, position: event.globalPosition),
              child: const EhSvgIcon(CupertinoIcons.ellipsis, size: 16),
            ),
          ),
        ],
      ),
    );
  });
}

class _ViewModeSegmentedSwitch extends StatelessWidget {
  const _ViewModeSegmentedSwitch({
    required this.isListMode,
    required this.label,
    required this.onSelectList,
    required this.onSelectGrid,
    required this.onOpenMenu,
  });

  final bool isListMode;
  final String label;
  final ValueChanged<BuildContext> onSelectList;
  final ValueChanged<BuildContext> onSelectGrid;
  final void Function(BuildContext anchor, Offset position) onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    return Container(
      height: 30,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: palette.fill.resolveFrom(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegmentButton(
            key: const ValueKey('desktop-view-list'),
            active: isListMode,
            label: label,
            icon: CupertinoIcons.list_bullet,
            onPressed: onSelectList,
            onSecondaryTap: onOpenMenu,
          ),
          _SegmentButton(
            key: const ValueKey('desktop-display-mode'),
            active: !isListMode,
            label: label,
            icon: CupertinoIcons.square_grid_2x2,
            onPressed: onSelectGrid,
            onSecondaryTap: onOpenMenu,
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatefulWidget {
  const _SegmentButton({
    super.key,
    required this.active,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.onSecondaryTap,
  });

  final bool active;
  final String label;
  final IconData icon;
  final ValueChanged<BuildContext> onPressed;
  final void Function(BuildContext anchor, Offset position) onSecondaryTap;

  @override
  State<_SegmentButton> createState() => _SegmentButtonState();
}

class _SegmentButtonState extends State<_SegmentButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final fill = widget.active
        ? palette.raised.resolveFrom(context)
        : _hover
        ? palette.text1.resolveFrom(context).withValues(alpha: dark ? .07 : .04)
        : const Color(0x00000000);
    return Semantics(
      button: true,
      selected: widget.active,
      label: widget.label,
      excludeSemantics: true,
      onTap: () => widget.onPressed(context),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onPressed(context),
          onSecondaryTapDown: (event) =>
              widget.onSecondaryTap(context, event.globalPosition),
          child: AnimatedContainer(
            duration: DesktopBrowseStyle.motion(context, 120),
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(6),
              boxShadow: widget.active && !dark
                  ? const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: EhSvgIcon(
              widget.icon,
              size: 14,
              color: widget.active
                  ? palette.text1.resolveFrom(context)
                  : palette.text2.resolveFrom(context),
            ),
          ),
        ),
      ),
    );
  }
}
