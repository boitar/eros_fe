import 'dart:math' as math;

import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/utils/gallery_title.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/macos_window_chrome.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../common.dart';
import '../controller/view_controller.dart';
import '../controller/view_state.dart';
import 'reader_layout.dart';
import 'view_widget.dart';

/// macOS and Windows read like a desktop app: a toolbar with the layout,
/// direction and fullscreen controls, a thumbnail sidebar, page buttons at
/// the sides, the scroll wheel turning pages and a scrubber with key hints.
bool usesDesktopReaderChrome(BuildContext context) =>
    PlatformCapabilities.isDesktop && !NativeNavigationScope.isEnabled(context);

/// Whether the desktop reader floats its controls as glass over the page.
bool usesDesktopReaderGlass(BuildContext context) =>
    GlassMode.of(context) != GlassMode.off;

/// The reader's own key: F, on macOS where the window can go fullscreen.
bool get desktopReaderCanFullscreen =>
    PlatformCapabilities.hostPlatform == TargetPlatform.macOS;

const Color _kText = Color(0xFFECEDF0);
const Color _kText2 = Color(0xFFA3A7AF);
const Color _kBar = Color(0xDB141519);
const Color _kSidebar = Color(0xEB121317);
const Color _kHairline = Color(0x12FFFFFF);
const Color _kCapsule = Color(0xE61C1D22);
const Color _kButtonFill = Color(0xB3141519);

Color get _accent => EhPalette.accent.darkColor;

/// The reading direction to return to when leaving vertical scrolling.
ViewMode _lastHorizontal = ViewMode.leftToRight;

/// One of the three layouts the toolbar's segmented control picks.
enum DesktopReaderLayout { single, double, vertical }

DesktopReaderLayout desktopReaderLayoutOf(ViewExtState state) =>
    state.viewMode == ViewMode.topToBottom
    ? DesktopReaderLayout.vertical
    : state.columnMode == ViewColumnMode.single
    ? DesktopReaderLayout.single
    : DesktopReaderLayout.double;

void _setViewMode(ViewExtController controller, ViewMode mode) {
  final settings = controller.vState.ehSettingService;
  if (settings.viewMode.value == mode) {
    return;
  }
  if (settings.viewMode.value != ViewMode.topToBottom) {
    _lastHorizontal = settings.viewMode.value;
  }
  settings.viewMode.value = mode;
  controller.handOnViewModeChanged(mode);
  // The side page buttons come and go with vertical scrolling.
  controller.update([idViewBar]);
}

void setDesktopReaderLayout(
  ViewExtController controller,
  DesktopReaderLayout layout,
) {
  final state = controller.vState;
  if (layout == DesktopReaderLayout.vertical) {
    _setViewMode(controller, ViewMode.topToBottom);
    return;
  }
  if (state.viewMode == ViewMode.topToBottom) {
    _setViewMode(controller, _lastHorizontal);
  }
  final preference = state.ehSettingService.readerColumnPreference;
  controller.setColumnPreference(
    layout == DesktopReaderLayout.single
        ? ReaderColumnPreference.single
        : preference == ReaderColumnPreference.evenLeft
        ? ReaderColumnPreference.evenLeft
        : ReaderColumnPreference.oddLeft,
  );
}

void toggleDesktopReaderDirection(ViewExtController controller) {
  final mode = controller.vState.viewMode;
  if (mode == ViewMode.topToBottom) {
    return;
  }
  _setViewMode(
    controller,
    mode == ViewMode.leftToRight ? ViewMode.rightToLeft : ViewMode.leftToRight,
  );
}

/// "3–4" for a spread, "3" for a single page.
String desktopReaderPageLabel(ViewExtState state) {
  if (state.viewMode == ViewMode.topToBottom) {
    return '${state.currentItemIndex + 1}';
  }
  final images = state.pagination.imagesForPage(state.pageIndex);
  if (images.length < 2) {
    return '${state.currentItemIndex + 1}';
  }
  return '${images.first + 1}–${images.last + 1}';
}

Future<void> _openReadSettings(ViewExtController controller) async {
  controller.cancelVolumeKeydownListen();
  await Get.toNamed(EHRoutes.readSetting);
  controller.addVolumeKeydownListen();
}

/// Places the desktop chrome around the page view [content].
///
/// Without glass the toolbar and the sidebar take their own space; with
/// glass the pages fill the window and the controls float over them.
/// Clicking the middle of the page hides all of it.
class ReaderDesktopLayout extends GetView<ViewExtController> {
  const ReaderDesktopLayout({
    super.key,
    required this.content,
    required this.glass,
  });

  final Widget content;
  final bool glass;

  static const double topBarHeight = 52;
  static const double sidebarWidth = 168;

  @override
  Widget build(BuildContext context) {
    final state = controller.vState;
    final visible = state.showBar;
    final vertical = state.viewMode == ViewMode.topToBottom;
    final sidebar = !glass && visible && state.showThumbList;
    final top = !glass && visible ? topBarHeight : 0.0;
    final left = sidebar ? sidebarWidth : 0.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentRect = Rect.fromLTRB(
          left,
          top,
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final bottomWidth = math.min(
          glass ? 760.0 : 600.0,
          contentRect.width - 32,
        );
        return ColoredBox(
          color: const Color(0xFF08090B),
          child: Stack(
            children: [
              Positioned.fromRect(
                rect: contentRect,
                // Spreads size themselves from the environment: give them
                // the page area, not the whole window.
                child: AdaptivePane(
                  environment:
                      AdaptiveEnvironment.maybeOf(context) ??
                      AdaptiveEnvironmentSnapshot.fromMediaQuery(context),
                  rect: contentRect,
                  child: _WheelPager(enabled: !vertical, child: content),
                ),
              ),
              if (glass)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: ReaderChromeFade(
                    visible: visible,
                    slide: const Offset(0, -0.15),
                    child: const ReaderDesktopTopBar(glass: true),
                  ),
                )
              else if (visible)
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: topBarHeight,
                  child: ReaderDesktopTopBar(glass: false),
                ),
              if (sidebar)
                const Positioned(
                  left: 0,
                  top: topBarHeight,
                  bottom: 0,
                  width: sidebarWidth,
                  child: DecoratedBox(
                    key: ValueKey<String>('reader-desktop-sidebar'),
                    decoration: BoxDecoration(
                      color: _kSidebar,
                      border: Border(right: BorderSide(color: _kHairline)),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: ThumbnailListView.sidebarThumbWidth + 16,
                        child: ThumbnailListView(axis: Axis.vertical),
                      ),
                    ),
                  ),
                ),
              if (!vertical) ...[
                Positioned(
                  left: contentRect.left + (glass ? 20 : 16),
                  top: contentRect.center.dy - 22,
                  child: ReaderChromeFade(
                    visible: visible,
                    child: _PageButton(glass: glass, forward: false),
                  ),
                ),
                Positioned(
                  right: glass ? 20 : 16,
                  top: contentRect.center.dy - 22,
                  child: ReaderChromeFade(
                    visible: visible,
                    child: _PageButton(glass: glass, forward: true),
                  ),
                ),
              ],
              if (bottomWidth > 0)
                Positioned(
                  left:
                      contentRect.left + (contentRect.width - bottomWidth) / 2,
                  width: bottomWidth,
                  bottom: glass ? 16 : 22,
                  child: ReaderChromeFade(
                    visible: visible,
                    slide: const Offset(0, 0.15),
                    child: ReaderDesktopBottomBar(glass: glass),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The scroll wheel (or a trackpad swipe) turns pages, one per gesture.
class _WheelPager extends StatefulWidget {
  const _WheelPager({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<_WheelPager> createState() => _WheelPagerState();
}

class _WheelPagerState extends State<_WheelPager> {
  Duration? _last;
  static const Duration _gap = Duration(milliseconds: 280);

  void _onSignal(PointerSignalEvent event) {
    if (!widget.enabled ||
        event is! PointerScrollEvent ||
        HardwareKeyboard.instance.isControlPressed) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, _turnPage);
  }

  void _turnPage(PointerSignalEvent signal) {
    final event = signal as PointerScrollEvent;
    final delta = event.scrollDelta.dy.abs() >= event.scrollDelta.dx.abs()
        ? event.scrollDelta.dy
        : event.scrollDelta.dx;
    if (delta.abs() < 4) {
      return;
    }
    // The event's own clock: a burst from one swipe arrives within the gap.
    final now = event.timeStamp;
    final last = _last;
    if (last != null && (now - last).abs() < _gap) {
      return;
    }
    _last = now;
    final controller = Get.find<ViewExtController>();
    if (delta > 0) {
      controller.toNext();
    } else {
      controller.toPrev();
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    // The margins beside a page turn it too, not only the image.
    behavior: HitTestBehavior.translucent,
    onPointerSignal: _onSignal,
    child: widget.child,
  );
}

Widget _glassSurface({required double radius, required Widget child}) =>
    LiquidGlassSurface(
      enabled: true,
      useNativeGlass: false,
      style: LiquidGlassStyle.clear,
      borderRadius: BorderRadius.circular(radius),
      child: child,
    );

/// A toolbar button: an icon in a hit box, tinted while [selected].
class _BarButton extends StatefulWidget {
  const _BarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.glass = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool glass;

  /// Disabled buttons stay in place, dimmed, so the toolbar never shifts
  /// under the pointer when the layout changes.
  final bool enabled;

  @override
  State<_BarButton> createState() => _BarButtonState();
}

class _BarButtonState extends State<_BarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final Color fill = !enabled
        ? const Color(0x00000000)
        : widget.selected
        ? (widget.glass
              ? const Color(0x2EFFFFFF)
              : _accent.withValues(alpha: .18))
        : _hovered
        ? const Color(0x1AFFFFFF)
        : const Color(0x00000000);
    final double size = widget.glass ? 32 : 30;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.label,
      excludeSemantics: true,
      onTap: enabled ? widget.onTap : null,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          key: ValueKey<String>('reader-desktop-${widget.label}'),
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? widget.onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(widget.glass ? size / 2 : 7),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: !enabled
                  ? _kText.withValues(alpha: .3)
                  : widget.selected && !widget.glass
                  ? _accent
                  : _kText,
            ),
          ),
        ),
      ),
    );
  }
}

/// Single · Double · Vertical.
class _LayoutSegments extends StatelessWidget {
  const _LayoutSegments({
    required this.controller,
    required this.glass,
    this.compact = false,
  });

  final ViewExtController controller;
  final bool glass;
  final bool compact;

  static Map<DesktopReaderLayout, String> labels(BuildContext context) {
    final l10n = L10n.of(context);
    return {
      DesktopReaderLayout.single: l10n.reader_single_page,
      DesktopReaderLayout.double: l10n.reader_double_page,
      DesktopReaderLayout.vertical: l10n.reader_vertical,
    };
  }

  static double widthFor(BuildContext context, {required bool glass}) =>
      4 +
      labels(context).values.fold<double>(0, (width, label) {
        final painter = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final result = width + painter.width + (glass ? 24 : 20);
        painter.dispose();
        return result;
      });

  @override
  Widget build(BuildContext context) {
    final current = desktopReaderLayoutOf(controller.vState);
    final icons = {
      DesktopReaderLayout.single: CupertinoIcons.rectangle,
      DesktopReaderLayout.double: CupertinoIcons.book,
      DesktopReaderLayout.vertical: CupertinoIcons.arrow_down,
    };
    final radius = glass ? 14.0 : 5.0;
    return Container(
      key: const ValueKey<String>('reader-desktop-layouts'),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: glass ? null : const Color(0x12FFFFFF),
        borderRadius: BorderRadius.circular(radius + 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in labels(context).entries)
            Semantics(
              button: true,
              selected: entry.key == current,
              label: entry.value,
              excludeSemantics: true,
              onTap: () => setDesktopReaderLayout(controller, entry.key),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  key: ValueKey<String>('reader-layout-${entry.key.name}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setDesktopReaderLayout(controller, entry.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    height: compact ? 30 : (glass ? 28 : 24),
                    width: compact ? 32 : null,
                    padding: compact
                        ? EdgeInsets.zero
                        : EdgeInsets.symmetric(horizontal: glass ? 12 : 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: entry.key == current
                          ? (glass
                                ? const Color(0x2EFFFFFF)
                                : const Color(0x24FFFFFF))
                          : const Color(0x00000000),
                      borderRadius: BorderRadius.circular(radius),
                    ),
                    child: compact
                        ? Icon(icons[entry.key], size: 17, color: _kText)
                        : Text(
                            entry.value,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: entry.key == current ? _kText : _kText2,
                            ),
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Back, thumbnails · title and page · layout, direction, auto read,
/// fullscreen and settings.
class ReaderDesktopTopBar extends GetView<ViewExtController> {
  const ReaderDesktopTopBar({super.key, required this.glass});

  final bool glass;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return GetBuilder<ViewExtController>(
      id: idViewTopBar,
      builder: (logic) => LayoutBuilder(
        builder: (context, constraints) {
          final state = logic.vState;
          final size = glass ? 32.0 : 30.0;
          final fullWidth =
              _LayoutSegments.widthFor(context, glass: glass) +
              (glass ? 64 : 52) +
              size * ((glass ? 1 : 2) + (desktopReaderCanFullscreen ? 4 : 3)) +
              124;
          final compact = constraints.maxWidth < fullWidth;
          final title = GalleryTitleParts.parse(
            state.pageState?.displayTitle ?? '',
          ).title;
          final page = l10n.reader_page_of(
            desktopReaderPageLabel(state),
            state.fileCount,
          );
          final vertical = state.viewMode == ViewMode.topToBottom;
          final showTitle = title.isNotEmpty && !compact;
          final titleBlock = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showTitle)
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _kText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              Text(
                page,
                key: const ValueKey<String>('reader-desktop-page'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: showTitle ? _kText2 : _kText,
                  fontSize: showTitle ? 11 : 13,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          );
          final leading = <Widget>[
            _BarButton(
              glass: glass,
              icon: CupertinoIcons.chevron_left,
              label: l10n.back,
              onTap: Get.back,
            ),
            if (!glass)
              GetBuilder<ViewExtController>(
                id: idShowThumbListIcon,
                builder: (logic) => _BarButton(
                  icon: CupertinoIcons.sidebar_left,
                  label: l10n.thumbnails,
                  selected: logic.vState.showThumbList,
                  onTap: logic.switchShowThumbList,
                ),
              ),
          ];
          final trailing = <Widget>[
            _LayoutSegments(controller: logic, glass: glass, compact: compact),
            const SizedBox(width: 4),
            if (!compact) ...[
              _BarButton(
                glass: glass,
                // Vertical scrolling has no reading direction to flip.
                enabled: !vertical,
                icon: state.viewMode == ViewMode.rightToLeft
                    ? CupertinoIcons.arrow_left
                    : CupertinoIcons.arrow_right,
                label:
                    '${l10n.reading_direction}: '
                    '${state.viewMode == ViewMode.rightToLeft ? l10n.right_to_left : l10n.left_to_right}',
                onTap: () => toggleDesktopReaderDirection(logic),
              ),
              GetBuilder<ViewExtController>(
                id: idAutoReadIcon,
                builder: (logic) => _BarButton(
                  glass: glass,
                  icon: CupertinoIcons.timer,
                  label: l10n.reader_auto_read,
                  selected: logic.vState.autoRead,
                  onTap: () => logic.tapAutoRead(context),
                ),
              ),
              if (desktopReaderCanFullscreen)
                ValueListenableBuilder<bool>(
                  valueListenable: MacOSWindowChrome.fullscreen,
                  builder: (context, fullscreen, _) => _BarButton(
                    glass: glass,
                    icon: fullscreen
                        ? CupertinoIcons.fullscreen_exit
                        : CupertinoIcons.fullscreen,
                    label: l10n.fullscreen,
                    selected: fullscreen,
                    onTap: MacOSWindowChrome.toggleFullscreen,
                  ),
                ),
            ],
            _ReaderMoreMenu(controller: logic, glass: glass, compact: compact),
          ];
          if (!glass) {
            return Container(
              key: const ValueKey<String>('reader-desktop-topbar'),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: const BoxDecoration(
                color: _kBar,
                border: Border(bottom: BorderSide(color: _kHairline)),
              ),
              child: Row(
                children: [
                  ...leading,
                  const SizedBox(width: 12),
                  Expanded(child: titleBlock),
                  const SizedBox(width: 12),
                  ...trailing,
                ],
              ),
            );
          }
          Widget capsule(Widget child, {Key? key}) => _glassSurface(
            radius: 20,
            child: SizedBox(
              key: key,
              height: 40,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: child,
              ),
            ),
          );
          return Padding(
            key: const ValueKey<String>('reader-desktop-topbar'),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                capsule(Row(mainAxisSize: MainAxisSize.min, children: leading)),
                const SizedBox(width: 12),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: capsule(
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: titleBlock,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                capsule(
                  Row(mainAxisSize: MainAxisSize.min, children: trailing),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Secondary controls remain reachable at every window width. Image exports
/// use the same controller actions as the mobile reader, including fileImage.
class _ReaderMoreMenu extends StatefulWidget {
  const _ReaderMoreMenu({
    required this.controller,
    required this.glass,
    required this.compact,
  });

  final ViewExtController controller;
  final bool glass;
  final bool compact;

  @override
  State<_ReaderMoreMenu> createState() => _ReaderMoreMenuState();
}

class _ReaderMoreMenuState extends State<_ReaderMoreMenu> {
  bool _open = false;
  ViewExtController get controller => widget.controller;

  void _setOpen(bool open) {
    _open = open;
    controller.setKeyboardShortcutsSuspended(this, open);
  }

  @override
  void didUpdateWidget(_ReaderMoreMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != controller) {
      oldWidget.controller.setKeyboardShortcutsSuspended(this, false);
      controller.setKeyboardShortcutsSuspended(this, _open);
    }
  }

  @override
  void dispose() {
    controller.setKeyboardShortcutsSuspended(this, false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final state = controller.vState;
    return CupertinoMenuAnchor(
      onOpen: () => _setOpen(true),
      onClose: () => _setOpen(false),
      menuChildren: [
        CupertinoMenuItem(
          leading: const Icon(CupertinoIcons.arrow_down_to_line),
          onPressed: () => controller.tapSave(context),
          child: Text(l10n.save_current_image),
        ),
        CupertinoMenuItem(
          leading: const Icon(CupertinoIcons.share),
          onPressed: () => controller.tapShare(context),
          child: Text(l10n.share_image),
        ),
        if (widget.compact) ...[
          CupertinoMenuItem(
            leading: const Icon(CupertinoIcons.arrow_left_right),
            onPressed: state.viewMode == ViewMode.topToBottom
                ? null
                : () => toggleDesktopReaderDirection(controller),
            child: Text(
              '${l10n.reading_direction}: '
              '${state.viewMode == ViewMode.rightToLeft ? l10n.right_to_left : l10n.left_to_right}',
            ),
          ),
          GetBuilder<ViewExtController>(
            id: idAutoReadIcon,
            builder: (logic) => CupertinoMenuItem(
              leading: Icon(
                logic.vState.autoRead
                    ? CupertinoIcons.checkmark
                    : CupertinoIcons.timer,
              ),
              onPressed: () => logic.tapAutoRead(context),
              child: Text(l10n.reader_auto_read),
            ),
          ),
          if (desktopReaderCanFullscreen)
            CupertinoMenuItem(
              leading: const Icon(CupertinoIcons.fullscreen),
              onPressed: MacOSWindowChrome.toggleFullscreen,
              child: Text(l10n.fullscreen),
            ),
        ],
        CupertinoMenuItem(
          leading: const Icon(CupertinoIcons.settings),
          onPressed: () => _openReadSettings(controller),
          child: Text(l10n.read_setting),
        ),
      ],
      builder: (context, menu, _) => _BarButton(
        glass: widget.glass,
        icon: CupertinoIcons.ellipsis,
        label: l10n.more_actions,
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key(this.label, {required this.glass});

  final String label;
  final bool glass;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: glass ? const Color(0x1FFFFFFF) : null,
      border: glass ? null : Border.all(color: const Color(0x33FFFFFF)),
      borderRadius: BorderRadius.circular(glass ? 5 : 4),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: Color(0xFFC9CCD3),
      ),
    ),
  );
}

/// The page scrubber with key hints; with glass, the filmstrip above it.
class ReaderDesktopBottomBar extends GetView<ViewExtController> {
  const ReaderDesktopBottomBar({super.key, required this.glass});

  final bool glass;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return GetBuilder<ViewExtController>(
      id: idViewBottomBar,
      builder: (logic) {
        final hints = <Widget>[
          _Key('← →', glass: glass),
          const SizedBox(width: 5),
          Text(l10n.reader_turn_page),
          if (desktopReaderCanFullscreen) ...[
            const SizedBox(width: 8),
            _Key('F', glass: glass),
            const SizedBox(width: 5),
            Text(l10n.fullscreen),
          ],
          const SizedBox(width: 8),
          _Key('T', glass: glass),
          const SizedBox(width: 5),
          Text(l10n.thumbnails),
        ];
        final scrubber = SizedBox(
          height: glass ? 32 : 48,
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                Expanded(
                  child: GetBuilder<ViewExtController>(
                    id: idViewPageSlider,
                    builder: (logic) {
                      final count = logic.vState.fileCount;
                      if (count <= 1) {
                        return const SizedBox.shrink();
                      }
                      return ViewPageSlider(
                        max: count - 1.0,
                        sliderValue: math.min(
                          logic.vState.sliderValue,
                          count - 1.0,
                        ),
                        onChangedEnd: logic.handOnSliderChangedEnd,
                        onChanged: logic.handOnSliderChanged,
                        reverse: logic.vState.viewMode == ViewMode.rightToLeft,
                      );
                    },
                  ),
                ),
                // Hints only where they leave the scrubber room.
                if (constraints.maxWidth >= 520) ...[
                  Container(
                    width: 1,
                    height: 20,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: const Color(0x1FFFFFFF),
                  ),
                  DefaultTextStyle(
                    style: const TextStyle(fontSize: 11, color: _kText2),
                    child: Row(
                      key: const ValueKey<String>('reader-desktop-hints'),
                      mainAxisSize: MainAxisSize.min,
                      children: hints,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
        if (!glass) {
          return Container(
            key: const ValueKey<String>('reader-desktop-bottombar'),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: _kCapsule,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0x1AFFFFFF), width: .5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 30,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: scrubber,
          );
        }
        return _glassSurface(
          radius: 26,
          child: Padding(
            key: const ValueKey<String>('reader-desktop-bottombar'),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (logic.vState.showThumbList) ...[
                  const SizedBox(
                    height: kThumbListViewHeight,
                    child: ThumbnailListView(),
                  ),
                  const SizedBox(height: 8),
                ],
                scrubber,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The page buttons at the sides: [forward] is the right one. The controller
/// maps them to the reading direction like the arrow keys.
class _PageButton extends GetView<ViewExtController> {
  const _PageButton({required this.glass, required this.forward});

  final bool glass;
  final bool forward;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    // Right-to-left reading turns forward with the left button.
    final next =
        forward != (controller.vState.viewMode == ViewMode.rightToLeft);
    final label = next ? l10n.reader_next_page : l10n.reader_previous_page;
    final double size = glass ? 44 : 40;
    final icon = Icon(
      forward ? CupertinoIcons.chevron_right : CupertinoIcons.chevron_left,
      size: 18,
      color: _kText,
    );
    final button = SizedBox.square(dimension: size, child: icon);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: forward ? controller.tapRight : controller.tapLeft,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: ValueKey<String>('reader-desktop-${forward ? 'next' : 'prev'}'),
          behavior: HitTestBehavior.opaque,
          // The right button turns towards the right, as → does.
          onTap: forward ? controller.tapRight : controller.tapLeft,
          child: glass
              ? _glassSurface(radius: size / 2, child: button)
              : DecoratedBox(
                  decoration: const BoxDecoration(
                    color: _kButtonFill,
                    shape: BoxShape.circle,
                  ),
                  child: button,
                ),
        ),
      ),
    );
  }
}

/// F toggles fullscreen; Esc leaves fullscreen before it leaves the reader.
bool handleDesktopReaderKey(LogicalKeyboardKey key) {
  if (!PlatformCapabilities.isDesktop || !desktopReaderCanFullscreen) {
    return false;
  }
  if (key == LogicalKeyboardKey.keyF) {
    MacOSWindowChrome.toggleFullscreen();
    return true;
  }
  if (key == LogicalKeyboardKey.escape && MacOSWindowChrome.fullscreen.value) {
    MacOSWindowChrome.toggleFullscreen();
    return true;
  }
  return false;
}
