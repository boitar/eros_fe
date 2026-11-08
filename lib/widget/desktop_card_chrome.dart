import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/adaptive/tab_navigation.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_controller.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/widget/desktop_gallery_actions.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

/// The gallery the detail pane of [stack] shows, if any: the innermost
/// gallery page on its detail navigator, under whatever it opened on top
/// (comments, thumbnails).
String? galleryShownInDetail(
  TabNavigationStack? stack, {
  String? Function(String galleryTag)? gidForTag,
}) {
  if (stack == null) {
    return null;
  }
  for (final route in stack.detailObserver.history.reversed) {
    if (route.settings.name != EHRoutes.galleryPage) {
      continue;
    }
    final arguments = route.settings.arguments;
    if (arguments is! ControllerTagSnapshot) {
      return null;
    }
    return (gidForTag ?? _controllerGid)(arguments.galleryTag);
  }
  return null;
}

String? _controllerGid(String tag) =>
    Get.isRegistered<GalleryPageController>(tag: tag)
    ? Get.find<GalleryPageController>(tag: tag).gState.gid
    : null;

/// Corner radius of the cards the current list mode draws.
double cardRadiusFor(ListModeEnum mode) => switch (mode) {
  ListModeEnum.waterfallLarge => 16,
  ListModeEnum.grid || ListModeEnum.gridTags || ListModeEnum.waterfall => 6,
  _ => 12,
};

/// List modes put the cover at the card's left edge and text on the right:
/// their quick actions stack down the cover. Grids and waterfalls have the
/// cover on top, so the actions sit in a row over its top-right corner.
bool quickActionsOnCoverStart(ListModeEnum mode) =>
    mode == ListModeEnum.list || mode == ListModeEnum.simpleList;

/// Space between the list slot and the card the current list mode draws in
/// it: the list card keeps its own margin, grids leave it to their spacing.
EdgeInsets cardInsetsFor(ListModeEnum mode) => switch (mode) {
  ListModeEnum.list => const EdgeInsets.fromLTRB(10, 8, 10, 4),
  _ => EdgeInsets.zero,
};

/// Desktop pointer states for a gallery card: it lifts a little under the
/// mouse and shows read / favorite / download buttons, a right click opens
/// its context menu, and the gallery open in the detail pane beside the list
/// keeps an accent ring, so the list shows which one the pane belongs to.
///
/// Touch platforms get [child] unchanged.
class DesktopCardChrome extends StatefulWidget {
  const DesktopCardChrome({super.key, required this.gid, required this.child});

  final String gid;
  final Widget child;

  /// Stands in for the gallery page controllers in widget tests.
  @visibleForTesting
  static String? Function(String galleryTag)? debugGidForTag;

  @override
  State<DesktopCardChrome> createState() => _DesktopCardChromeState();
}

class _DesktopCardChromeState extends State<DesktopCardChrome> {
  bool _hovered = false;
  LayoutServices? _layout;
  TabNavigationStack? _stack;

  @override
  void initState() {
    super.initState();
    if (PlatformCapabilities.isDesktop && Get.isRegistered<LayoutServices>()) {
      _layout = Get.find<LayoutServices>();
      _layout!.tabNavigation.addListener(_followStack);
      _followStack();
    }
  }

  /// The selected tab's detail pane decides the ring; follow its stack as
  /// tabs change.
  void _followStack() {
    final stack = _layout?.tabNavigation.selected;
    if (identical(stack, _stack)) {
      if (mounted) {
        setState(() {});
      }
      return;
    }
    _stack?.detailObserver.revision.removeListener(_detailChanged);
    _stack = stack;
    _stack?.detailObserver.revision.addListener(_detailChanged);
    _detailChanged();
  }

  void _detailChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _setHovered(bool hovered) {
    setState(() => _hovered = hovered);
    final hoveredGid = DesktopGalleryActions.hoveredGid;
    if (hovered) {
      hoveredGid.value = widget.gid;
    } else if (hoveredGid.value == widget.gid) {
      hoveredGid.value = null;
    }
  }

  Future<void> _openMenu(TapUpDetails details) async {
    final item = DesktopGalleryActions.itemFor(widget.gid);
    if (item == null) {
      return;
    }
    await showDesktopGalleryMenu(
      context,
      position: details.globalPosition,
      entries: desktopGalleryMenuEntries(context, item),
    );
  }

  @override
  void dispose() {
    if (DesktopGalleryActions.hoveredGid.value == widget.gid) {
      DesktopGalleryActions.hoveredGid.value = null;
    }
    _layout?.tabNavigation.removeListener(_followStack);
    _stack?.detailObserver.revision.removeListener(_detailChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformCapabilities.isDesktop) {
      return widget.child;
    }
    final layout = _layout;
    final selected =
        layout != null &&
        layout.isLayoutLarge &&
        galleryShownInDetail(
              _stack,
              gidForTag: DesktopCardChrome.debugGidForTag,
            ) ==
            widget.gid;
    final mode = Get.isRegistered<EhSettingService>()
        ? Get.find<EhSettingService>().listMode.value
        : ListModeEnum.list;
    final double radius = cardRadiusFor(mode);
    final item = DesktopGalleryActions.itemFor(widget.gid);
    final insets = cardInsetsFor(mode);
    final onCover = quickActionsOnCoverStart(mode);
    return Semantics(
      selected: selected,
      child: MouseRegion(
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: GestureDetector(
          onSecondaryTapUp: _openMenu,
          child: AnimatedContainer(
            key: ValueKey<String>('desktop-card-${widget.gid}'),
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
            child: Stack(
              children: <Widget>[
                widget.child,
                if (item != null)
                  Positioned(
                    top: insets.top + 6,
                    left: onCover ? insets.left + 6 : null,
                    right: onCover ? null : insets.right + 8,
                    child: IgnorePointer(
                      ignoring: !_hovered,
                      child: AnimatedOpacity(
                        key: ValueKey<String>('desktop-quick-${widget.gid}'),
                        opacity: _hovered ? 1 : 0,
                        duration: const Duration(milliseconds: 120),
                        child: DesktopQuickActions(
                          item: item,
                          axis: onCover ? Axis.vertical : Axis.horizontal,
                        ),
                      ),
                    ),
                  ),
                if (selected)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Padding(
                        padding: insets,
                        child: DecoratedBox(
                          key: ValueKey<String>(
                            'desktop-card-ring-${widget.gid}',
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(radius),
                            border: Border.all(
                              color: EhPalette.accent.resolveFrom(context),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
