import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/desktop_ui_preferences.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/widget/desktop_browse_style.dart';
import 'package:eros_fe/widget/desktop_control.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:eros_fe/widget/macos_window_chrome.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

bool usesDesktopSidebar({required AdaptiveEnvironmentSnapshot environment}) =>
    PlatformCapabilities.isDesktop &&
    environment.size.width >= DesktopSidebar.minWindowWidth;

/// Capability and user visibility are separate: hiding a desktop sidebar must
/// never opt the content into a mobile bottom bar.
class DesktopSidebarScope extends InheritedWidget {
  const DesktopSidebarScope({
    super.key,
    required this.visible,
    this.desktop = false,
    this.onShow,
    required super.child,
  });
  final bool visible;
  final bool desktop;
  final VoidCallback? onShow;
  static DesktopSidebarScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DesktopSidebarScope>();
  static bool of(BuildContext context) => maybeOf(context)?.visible ?? false;
  @override
  bool updateShouldNotify(DesktopSidebarScope oldWidget) =>
      visible != oldWidget.visible ||
      desktop != oldWidget.desktop ||
      onShow != oldWidget.onShow;
}

@immutable
class DesktopSidebarGroup {
  const DesktopSidebarGroup({
    required this.title,
    required this.selected,
    this.id,
  });
  final String title;
  final bool selected;
  final String? id;
}

class DesktopSidebar extends StatelessWidget {
  const DesktopSidebar({
    super.key,
    required this.routes,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.searchLabel,
    required this.onSearch,
    this.browseLabel = '',
    this.libraryLabel = '',
    this.groupsLabel = '',
    this.groups = const [],
    this.groupSummary,
    this.onGroupTap,
    this.onGroupContext,
    this.onManageGroups,
    this.recentReading,
    this.preferences,
  });
  final List<String> routes;
  final List<BottomNavigationBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final String searchLabel;
  final VoidCallback onSearch;
  final String browseLabel, libraryLabel, groupsLabel;
  final List<DesktopSidebarGroup> groups;
  final String? groupSummary;
  final ValueChanged<int>? onGroupTap;
  final void Function(int, Offset)? onGroupContext;
  final ValueChanged<Offset>? onManageGroups;
  final Widget? recentReading;
  final DesktopUiPreferences? preferences;
  static const width = DesktopBrowseStyle.sidebarWidth;
  static const margin = DesktopBrowseStyle.inset;
  static const minWindowWidth = DesktopBrowseStyle.minimumWindowWidth;
  static const libraryRoutes = {
    EHRoutes.favorite,
    EHRoutes.download,
    EHRoutes.history,
  };
  static double reservedWidth() => DesktopBrowseStyle.sidebarExtent;
  static SingleActivator get searchShortcut => SingleActivator(
    LogicalKeyboardKey.keyF,
    meta: PlatformCapabilities.hostPlatform == TargetPlatform.macOS,
    control: PlatformCapabilities.hostPlatform != TargetPlatform.macOS,
  );
  static SingleActivator get settingsShortcut => SingleActivator(
    LogicalKeyboardKey.comma,
    meta: PlatformCapabilities.hostPlatform == TargetPlatform.macOS,
    control: PlatformCapabilities.hostPlatform != TargetPlatform.macOS,
  );
  static SingleActivator get backShortcut =>
      PlatformCapabilities.hostPlatform == TargetPlatform.macOS
      ? const SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true)
      : const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true);

  @override
  Widget build(BuildContext context) {
    final prefs = preferences ?? DesktopUiPreferences.instance;
    final palette = ehTheme.palette;
    final l10n = L10n.of(context);
    final bool dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final browse = <int>[], library = <int>[];
    int? setting;
    for (var i = 0; i < routes.length; i++) {
      if (routes[i] == EHRoutes.setting) {
        setting = i;
      } else if (libraryRoutes.contains(routes[i])) {
        library.add(i);
      } else {
        browse.add(i);
      }
    }
    Widget destination(int index) => _SidebarRow(
      key: ValueKey('desktop-sidebar-${routes[index]}'),
      icon: index == currentIndex ? items[index].activeIcon : items[index].icon,
      label: items[index].label ?? '',
      selected: index == currentIndex,
      onTap: () => onTap(index),
      shortcut: routes[index] == EHRoutes.setting
          ? (PlatformCapabilities.hostPlatform == TargetPlatform.macOS
              ? '⌘,'
              : 'Ctrl+,')
          : null,
    );
    String? summary(List<int> indices) => indices.contains(currentIndex)
        ? items[currentIndex].label
        : (indices == browse && indices.isNotEmpty
            ? items[indices.first].label
            : null);
    final bool browseActive = browse.contains(currentIndex);
    final bool libraryActive = library.contains(currentIndex);
    final String? activeGroupTitle =
        groups.where((g) => g.selected).firstOrNull?.title ?? groupSummary;
    final bool groupsActive = groups.any((g) => g.selected);
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: IconTheme.merge(
        data: IconThemeData(
          color: palette.text2.resolveFrom(context),
          size: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: DesktopBrowseStyle.toolbarHeight,
              child: Row(
                children: [
                  // Only whitespace (and the passive Windows label) moves the window.
                  Expanded(
                    child: MoveWindow(
                      child:
                          PlatformCapabilities.hostPlatform ==
                              TargetPlatform.windows
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  browseLabel.isNotEmpty
                                      ? browseLabel
                                      : l10n.app_title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: palette.text2.resolveFrom(context),
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.expand(),
                    ),
                  ),
                  DesktopControl(
                    key: const ValueKey('desktop-hide-sidebar'),
                    label: l10n.desktop_hide_sidebar,
                    minSize: 30,
                    radius: 999,
                    hoverColor: DesktopBrowseStyle.capsuleHover(context),
                    onPressed: () => prefs.showSidebar(false),
                    padding: const EdgeInsets.all(6),
                    child: const EhSvgIcon(CupertinoIcons.sidebar_left, size: 16),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DesktopControl(
                key: const ValueKey('desktop-sidebar-search'),
                label: searchLabel,
                radius: 999,
                minSize: 34,
                tooltip: false,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                idleColor: dark
                    ? const Color(0x10FFFFFF)
                    : const Color(0xFFF3F4F7),
                hoverColor: DesktopBrowseStyle.capsuleHover(context),
                pressedColor: DesktopBrowseStyle.capsulePressed(context),
                onPressed: onSearch,
                child: Row(
                  children: [
                    EhSvgIcon(
                      CupertinoIcons.search,
                      size: 14,
                      color: palette.text2.resolveFrom(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        searchLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.text2.resolveFrom(context),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surface.resolveFrom(context),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: palette.hairline.resolveFrom(context),
                        ),
                      ),
                      child: Text(
                        PlatformCapabilities.hostPlatform == TargetPlatform.macOS
                            ? '⌘F'
                            : 'Ctrl+F',
                        style: TextStyle(
                          fontSize: 10,
                          color: palette.text2.resolveFrom(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (browse.isNotEmpty)
                    DesktopSidebarSection(
                      id: 'browse',
                      title: browseLabel,
                      summary: summary(browse),
                      summaryActive: browseActive,
                      preferences: prefs,
                      child: Column(
                        children: [for (final i in browse) destination(i)],
                      ),
                    ),
                  if (library.isNotEmpty)
                    DesktopSidebarSection(
                      id: 'library',
                      title: libraryLabel,
                      summary: summary(library),
                      summaryActive: libraryActive,
                      preferences: prefs,
                      child: Column(
                        children: [for (final i in library) destination(i)],
                      ),
                    ),
                  DesktopSidebarSection(
                    id: 'groups',
                    title: groupsLabel,
                    preferences: prefs,
                    summary: activeGroupTitle,
                    summaryActive: groupsActive,
                    onSecondaryTapDown: onManageGroups == null
                        ? null
                        : (d) => onManageGroups!(d.globalPosition),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (groups.isEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                            child: Text(
                              l10n.desktop_no_groups,
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.text2.resolveFrom(context),
                              ),
                            ),
                          ),
                        for (var i = 0; i < groups.length; i++)
                          _SidebarRow(
                            key: ValueKey(
                              'desktop-sidebar-group-${groups[i].id ?? i}',
                            ),
                            label: groups[i].title,
                            selected: groups[i].selected,
                            icon: SizedBox.square(
                              dimension: 16,
                              child: Center(
                                child: Container(
                                  width: 5.5,
                                  height: 5.5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: groups[i].selected
                                        ? palette.text1.resolveFrom(context)
                                        : palette.text3.resolveFrom(context),
                                  ),
                                ),
                              ),
                            ),
                            onTap: () => onGroupTap?.call(i),
                            onSecondaryTapDown: onGroupContext == null
                                ? null
                                : (d) => onGroupContext!(i, d.globalPosition),
                          ),
                      ],
                    ),
                  ),
                  DesktopSidebarSection(
                    id: 'recent',
                    title: l10n.desktop_recent_reading,
                    preferences: prefs,
                    child:
                        recentReading ??
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(
                            l10n.desktop_recent_empty,
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.text2.resolveFrom(context),
                            ),
                          ),
                        ),
                  ),
                ],
              ),
            ),
            if (setting != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 4),
                child: SizedBox(
                  height: 1,
                  child: ColoredBox(color: palette.hairline.resolveFrom(context)),
                ),
              ),
              destination(setting),
            ],
          ],
        ),
      ),
    );
    return ValueListenableBuilder<MacOSWindowControls>(
      valueListenable: MacOSWindowChrome.controls,
      builder: (context, controls, _) => Padding(
        key: const ValueKey('desktop-sidebar'),
        padding: EdgeInsets.fromLTRB(
          margin,
          margin +
              (PlatformCapabilities.hostPlatform == TargetPlatform.macOS
                  ? controls.systemSafeTop
                  : 0),
          margin,
          margin,
        ),
        child: SizedBox(
          width: width,
          child: DesktopPaneSurface(sidebar: true, child: content),
        ),
      ),
    );
  }
}

class _SidebarRow extends StatefulWidget {
  const _SidebarRow({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onSecondaryTapDown,
    this.shortcut,
  });
  final Widget icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final GestureTapDownCallback? onSecondaryTapDown;
  final String? shortcut;

  @override
  State<_SidebarRow> createState() => _SidebarRowState();
}

class _SidebarRowState extends State<_SidebarRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final text1 = palette.text1.resolveFrom(context);
    final text2 = palette.text2.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: MouseRegion(
        opaque: false,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: DesktopControl(
          label: widget.label,
          selected: widget.selected,
          tooltip: false,
          radius: 999,
          minSize: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          selectedColor: DesktopBrowseStyle.capsuleSelected(context),
          selectedHoverColor: DesktopBrowseStyle.capsuleSelectedHover(context),
          hoverColor: DesktopBrowseStyle.capsuleHover(context),
          pressedColor: DesktopBrowseStyle.capsulePressed(context),
          onPressed: widget.onTap,
          onSecondaryTapDown: widget.onSecondaryTapDown,
          child: Row(
            children: [
              SizedBox.square(
                dimension: 16,
                child: FittedBox(
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(
                      end: (widget.selected || _hovered) ? text1 : text2,
                    ),
                    duration: DesktopBrowseStyle.motion(context, 185),
                    curve: Curves.easeOutCubic,
                    child: widget.icon,
                    builder: (context, iconColor, child) => IconTheme.merge(
                      data: IconThemeData(color: iconColor),
                      child: child!,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: widget.selected
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: text1,
                  ),
                ),
              ),
              if (widget.shortcut != null)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    widget.shortcut!,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: text2.withValues(alpha: .75),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DesktopSidebarSection extends StatefulWidget {
  const DesktopSidebarSection({
    super.key,
    required this.id,
    required this.title,
    required this.preferences,
    required this.child,
    this.summary,
    this.summaryActive = false,
    this.onSecondaryTapDown,
  });
  final String id, title;
  final String? summary;
  final bool summaryActive;
  final DesktopUiPreferences preferences;
  final Widget child;
  final GestureTapDownCallback? onSecondaryTapDown;
  @override
  State<DesktopSidebarSection> createState() => _DesktopSidebarSectionState();
}

class _DesktopSidebarSectionState extends State<DesktopSidebarSection> {
  final _header = FocusNode();
  final _body = FocusScopeNode();
  @override
  void dispose() {
    _header.dispose();
    _body.dispose();
    super.dispose();
  }

  void _toggle() {
    if (widget.preferences.isExpanded(widget.id) && _body.hasFocus)
      _header.requestFocus();
    widget.preferences.toggleSection(widget.id);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.preferences,
    builder: (context, _) {
      final expanded = widget.preferences.isExpanded(widget.id);
      final palette = ehTheme.palette;
      final text1 = palette.text1.resolveFrom(context);
      final text2 = palette.text2.resolveFrom(context);
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DesktopControl(
              key: ValueKey('desktop-section-${widget.id}'),
              label: widget.title,
              focusNode: _header,
              expanded: expanded,
              radius: 999,
              minSize: 32,
              hoverColor: DesktopBrowseStyle.capsuleHover(context),
              onPressed: _toggle,
              onSecondaryTapDown: widget.onSecondaryTapDown,
              tooltip: false,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: text2,
                      ),
                    ),
                  ),
                  if (!expanded &&
                      widget.summary != null &&
                      widget.summary!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 96),
                      child: Text(
                        widget.summary!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: widget.summaryActive
                              ? FontWeight.w500
                              : FontWeight.w400,
                          color: widget.summaryActive ? text1 : text2,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  SizedBox.square(
                    dimension: 14,
                    child: Center(
                      child: AnimatedRotation(
                        turns: expanded ? .25 : 0,
                        duration: DesktopBrowseStyle.motion(context, 180),
                        child: EhSvgIcon(
                          CupertinoIcons.chevron_right,
                          size: 12,
                          strokeWidth: 2.1,
                          color: text2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: DesktopBrowseStyle.motion(context, 180),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: Offstage(
                offstage: !expanded,
                child: ExcludeSemantics(
                  excluding: !expanded,
                  child: ExcludeFocus(
                    excluding: !expanded,
                    child: FocusScope(node: _body, child: widget.child),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
