import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// macOS and Windows windows wide enough for it trade the bottom bar for a
/// sidebar, as desktop apps do. Pages pushed in a single column open beside
/// it, so it never depends on the list/detail split.
bool usesDesktopSidebar({required AdaptiveEnvironmentSnapshot environment}) =>
    PlatformCapabilities.isDesktop &&
    environment.size.width >= DesktopSidebar.minWindowWidth;

/// Tells the pages beside the sidebar that it lists the gallery's groups, so
/// their own top bars drop the group chips and name the current group.
class DesktopSidebarScope extends InheritedWidget {
  const DesktopSidebarScope({
    super.key,
    required this.visible,
    required super.child,
  });

  final bool visible;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DesktopSidebarScope>()
          ?.visible ??
      false;

  @override
  bool updateShouldNotify(DesktopSidebarScope oldWidget) =>
      visible != oldWidget.visible;
}

/// One gallery group listed under the sidebar's "Groups" heading.
@immutable
class DesktopSidebarGroup {
  const DesktopSidebarGroup({required this.title, required this.selected});

  final String title;
  final bool selected;
}

/// The desktop navigation sidebar: a search field, the tab destinations in
/// "Browse" and "Library" sections, the gallery's groups, and settings at the
/// bottom. With glass it floats as a rounded panel; without, it is a plain
/// column on the page surface with a hairline edge.
class DesktopSidebar extends StatelessWidget {
  const DesktopSidebar({
    super.key,
    required this.routes,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.glass,
    required this.searchLabel,
    required this.onSearch,
    this.browseLabel = '',
    this.libraryLabel = '',
    this.groupsLabel = '',
    this.groups = const <DesktopSidebarGroup>[],
    this.onGroupTap,
  });

  /// Route of each entry in [items], in the same order.
  final List<String> routes;
  final List<BottomNavigationBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool glass;
  final String searchLabel;
  final VoidCallback onSearch;
  final String browseLabel;
  final String libraryLabel;
  final String groupsLabel;
  final List<DesktopSidebarGroup> groups;
  final ValueChanged<int>? onGroupTap;

  static const double width = 232;
  static const double margin = 8;
  static const double minWindowWidth = 900;

  static const Set<String> libraryRoutes = <String>{
    EHRoutes.favorite,
    EHRoutes.download,
    EHRoutes.history,
  };

  /// Horizontal space the sidebar takes from the content.
  static double reservedWidth({required bool glass}) =>
      glass ? width + margin * 2 : width + 1;

  /// ⌘F on macOS, Ctrl+F elsewhere.
  static SingleActivator get searchShortcut => SingleActivator(
    LogicalKeyboardKey.keyF,
    meta: PlatformCapabilities.hostPlatform == TargetPlatform.macOS,
    control: PlatformCapabilities.hostPlatform != TargetPlatform.macOS,
  );

  /// ⌘, / Ctrl+, opens settings.
  static SingleActivator get settingsShortcut => SingleActivator(
    LogicalKeyboardKey.comma,
    meta: PlatformCapabilities.hostPlatform == TargetPlatform.macOS,
    control: PlatformCapabilities.hostPlatform != TargetPlatform.macOS,
  );

  /// ⌘[ on macOS, Alt+← on Windows: back one page.
  static SingleActivator get backShortcut =>
      PlatformCapabilities.hostPlatform == TargetPlatform.macOS
      ? const SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true)
      : const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true);

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final browse = <int>[];
    final library = <int>[];
    int? setting;
    for (var index = 0; index < routes.length; index++) {
      final route = routes[index];
      if (route == EHRoutes.setting) {
        setting = index;
      } else if (libraryRoutes.contains(route)) {
        library.add(index);
      } else {
        browse.add(index);
      }
    }
    Widget destination(int index) => _SidebarRow(
      key: ValueKey<String>('desktop-sidebar-${routes[index]}'),
      icon: index == currentIndex ? items[index].activeIcon : items[index].icon,
      label: items[index].label ?? '',
      selected: index == currentIndex,
      glass: glass,
      onTap: () => onTap(index),
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: _SearchField(
            label: searchLabel,
            onTap: onSearch,
            glass: glass,
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              if (browse.isNotEmpty) ...<Widget>[
                if (browseLabel.isNotEmpty) _SectionHeader(browseLabel),
                for (final index in browse) destination(index),
              ],
              if (library.isNotEmpty) ...<Widget>[
                _SectionHeader(libraryLabel),
                for (final index in library) destination(index),
              ],
              if (groups.isNotEmpty) ...<Widget>[
                _SectionHeader(groupsLabel),
                for (var index = 0; index < groups.length; index++)
                  _SidebarRow(
                    key: ValueKey<String>('desktop-sidebar-group-$index'),
                    icon: _GroupDot(selected: groups[index].selected),
                    label: groups[index].title,
                    selected: groups[index].selected,
                    glass: glass,
                    onTap: () => onGroupTap?.call(index),
                  ),
              ],
            ],
          ),
        ),
        if (setting != null) destination(setting),
      ],
    );
    final padded = Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: IconTheme.merge(
        data: IconThemeData(
          color: palette.text2.resolveFrom(context),
          size: 16,
        ),
        child: content,
      ),
    );
    if (!glass) {
      return DecoratedBox(
        key: const ValueKey<String>('desktop-sidebar'),
        decoration: BoxDecoration(
          color: palette.surface.resolveFrom(context),
          border: Border(
            right: BorderSide(color: palette.hairline.resolveFrom(context)),
          ),
        ),
        child: SizedBox(width: width, child: padded),
      );
    }
    return Padding(
      key: const ValueKey<String>('desktop-sidebar'),
      padding: const EdgeInsets.all(margin),
      child: SizedBox(
        width: width,
        child: LiquidGlassSurface(
          enabled: true,
          useNativeGlass: false,
          borderRadius: BorderRadius.circular(20),
          child: padded,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
    child: Semantics(
      header: true,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: ehTheme.palette.text2.resolveFrom(context),
        ),
      ),
    ),
  );
}

class _GroupDot extends StatelessWidget {
  const _GroupDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 16,
    height: 16,
    child: Center(
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? EhPalette.accent.resolveFrom(context)
              : ehTheme.palette.text3.resolveFrom(context),
        ),
      ),
    ),
  );
}

/// A sidebar row: hover highlight, a lens (glass) or tonal fill (solid) when
/// selected, and a button for assistive technologies.
class _SidebarRow extends StatefulWidget {
  const _SidebarRow({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.glass,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final bool selected;
  final bool glass;
  final VoidCallback onTap;

  @override
  State<_SidebarRow> createState() => _SidebarRowState();
}

class _SidebarRowState extends State<_SidebarRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final Color fill;
    if (widget.selected) {
      fill = widget.glass
          ? (dark ? const Color(0x24FFFFFF) : const Color(0x1214161C))
          : EhPalette.accentSoft.resolveFrom(context);
    } else if (_hovered) {
      fill = dark ? const Color(0x12FFFFFF) : const Color(0x0A14161C);
    } else {
      fill = const Color(0x00000000);
    }
    final Color foreground = widget.selected && !widget.glass
        ? EhPalette.accent.resolveFrom(context)
        : palette.text1.resolveFrom(context);
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 32,
            margin: const EdgeInsets.symmetric(vertical: 1),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: ShapeDecoration(
              color: fill,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(widget.glass ? 16 : 8),
              ),
            ),
            child: Row(
              children: <Widget>[
                IconTheme.merge(
                  data: IconThemeData(
                    color: widget.selected
                        ? foreground
                        : palette.text2.resolveFrom(context),
                  ),
                  // Tab icons carry their own (larger) size: fit them to the row.
                  child: SizedBox.square(
                    dimension: 16,
                    child: FittedBox(child: widget.icon),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: widget.selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: foreground,
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

class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.label,
    required this.onTap,
    required this.glass,
  });

  final String label;
  final VoidCallback onTap;
  final bool glass;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final mac = PlatformCapabilities.hostPlatform == TargetPlatform.macOS;
    final Color base = dark ? const Color(0x14FFFFFF) : const Color(0x0D14161C);
    final Color hover = dark
        ? const Color(0x1FFFFFFF)
        : const Color(0x1414161C);
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.text,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          key: const ValueKey<String>('desktop-sidebar-search'),
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: ShapeDecoration(
              color: _hovered ? hover : base,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(widget.glass ? 16 : 8),
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  CupertinoIcons.search,
                  size: 15,
                  color: palette.text2.resolveFrom(context),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: palette.text2.resolveFrom(context),
                    ),
                  ),
                ),
                Text(
                  mac ? '⌘F' : 'Ctrl+F',
                  style: TextStyle(
                    fontSize: 11,
                    color: palette.text3.resolveFrom(context),
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
