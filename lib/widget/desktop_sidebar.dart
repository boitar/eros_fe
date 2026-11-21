import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/desktop_ui_preferences.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/widget/desktop_browse_style.dart';
import 'package:eros_fe/widget/desktop_control.dart';
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
    );
    String? summary(List<int> indices) =>
        indices.contains(currentIndex) ? items[currentIndex].label : null;
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
                    radius: 8,
                    onPressed: () => prefs.showSidebar(false),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(CupertinoIcons.sidebar_left, size: 17),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: DesktopControl(
                key: const ValueKey('desktop-sidebar-search'),
                label: searchLabel,
                onPressed: onSearch,
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.search, size: 15),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        searchLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.text2.resolveFrom(context),
                        ),
                      ),
                    ),
                    Text(
                      PlatformCapabilities.hostPlatform == TargetPlatform.macOS
                          ? '⌘F'
                          : 'Ctrl+F',
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.text2.resolveFrom(context),
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
                      preferences: prefs,
                      child: Column(
                        children: [for (final i in library) destination(i)],
                      ),
                    ),
                  DesktopSidebarSection(
                    id: 'groups',
                    title: groupsLabel,
                    preferences: prefs,
                    summary: groups.where((g) => g.selected).firstOrNull?.title,
                    onSecondaryTapDown: onManageGroups == null
                        ? null
                        : (d) => onManageGroups!(d.globalPosition),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (groups.isEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
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
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: groups[i].selected
                                        ? EhPalette.accent.resolveFrom(context)
                                        : palette.text2.resolveFrom(context),
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

class _SidebarRow extends StatelessWidget {
  const _SidebarRow({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onSecondaryTapDown,
  });
  final Widget icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final GestureTapDownCallback? onSecondaryTapDown;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: DesktopControl(
      label: label,
      selected: selected,
      onPressed: onTap,
      onSecondaryTapDown: onSecondaryTapDown,
      child: Row(
        children: [
          SizedBox.square(dimension: 16, child: FittedBox(child: icon)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: ehTheme.palette.text1.resolveFrom(context),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class DesktopSidebarSection extends StatefulWidget {
  const DesktopSidebarSection({
    super.key,
    required this.id,
    required this.title,
    required this.preferences,
    required this.child,
    this.summary,
    this.onSecondaryTapDown,
  });
  final String id, title;
  final String? summary;
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
      final color = ehTheme.palette.text2.resolveFrom(context);
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
              onPressed: _toggle,
              onSecondaryTapDown: widget.onSecondaryTapDown,
              tooltip: false,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  if (!expanded && widget.summary != null)
                    Flexible(
                      child: Text(
                        widget.summary!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: color),
                      ),
                    ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: expanded ? .25 : 0,
                    duration: DesktopBrowseStyle.motion(context, 180),
                    child: Icon(
                      CupertinoIcons.chevron_right,
                      size: 12,
                      color: color,
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
