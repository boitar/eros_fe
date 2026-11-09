import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:flutter/cupertino.dart';

/// Android's navigation rail for list/detail layouts: the same destinations
/// as the bottom bar, stacked down the left edge. With glass it floats as a
/// vertical capsule; without, it is a plain column on the page surface.
class AndroidNavigationRail extends StatelessWidget {
  const AndroidNavigationRail({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.glass,
  });

  final List<BottomNavigationBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool glass;

  static const double railWidth = 80;
  static const double margin = 12;

  /// Horizontal space the rail takes from the content: margins, and the
  /// left safe inset (a landscape cutout) the rail keeps clear of.
  static double reservedWidth({required bool glass, double leftInset = 0}) =>
      leftInset + (glass ? railWidth + margin * 2 : railWidth);

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final destinations = SingleChildScrollView(
      primary: false,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: glass ? 8 : 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var index = 0; index < items.length; index++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _RailDestination(
                  item: items[index],
                  selected: index == currentIndex,
                  glass: glass,
                  onTap: () => onTap(index),
                ),
              ),
          ],
        ),
      ),
    );
    if (!glass) {
      return ColoredBox(
        key: const ValueKey<String>('android-navigation-rail'),
        color: palette.surface.resolveFrom(context),
        child: SafeArea(
          right: false,
          child: SizedBox(width: railWidth, child: destinations),
        ),
      );
    }
    // The capsule itself keeps clear of the status bar and any cutout.
    return SafeArea(
      key: const ValueKey<String>('android-navigation-rail'),
      right: false,
      child: Padding(
        padding: const EdgeInsets.all(margin),
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: railWidth,
            child: LiquidGlassSurface(
              enabled: true,
              useNativeGlass: false,
              borderRadius: BorderRadius.circular(railWidth / 2),
              child: destinations,
            ),
          ),
        ),
      ),
    );
  }
}

class _RailDestination extends StatelessWidget {
  const _RailDestination({
    required this.item,
    required this.selected,
    required this.glass,
    required this.onTap,
  });

  final BottomNavigationBarItem item;
  final bool selected;
  final bool glass;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final Color foreground = selected
        ? (glass
              ? palette.text1.resolveFrom(context)
              : EhPalette.accent.resolveFrom(context))
        : palette.text2.resolveFrom(context);
    // Glass stays monochrome: a brighter lens marks the selection.
    final Color indicator = glass
        ? (dark ? const Color(0x29FFFFFF) : const Color(0x1414161C))
        : EhPalette.accentSoft.resolveFrom(context);
    final label = item.label ?? '';
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 72,
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: 56,
                height: 32,
                decoration: ShapeDecoration(
                  color: selected ? indicator : const Color(0x00000000),
                  shape: const StadiumBorder(),
                ),
                child: IconTheme.merge(
                  data: IconThemeData(color: foreground, size: 22),
                  child: Center(child: selected ? item.activeIcon : item.icon),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: MediaQuery.textScalerOf(context)
                    .clamp(maxScaleFactor: 1.2),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Android's bottom navigation bar when glass is off: Material 3 proportions
/// on the app's palette, with a tonal pill behind the selected icon.
///
/// It extends [CupertinoTabBar] so the home shell keeps measuring, copying
/// and laying it out exactly as before.
class AndroidNavigationBar extends CupertinoTabBar {
  const AndroidNavigationBar({
    super.key,
    required super.items,
    super.onTap,
    super.currentIndex,
    super.height = barHeight,
  });

  static const double barHeight = 80;

  @override
  bool opaque(BuildContext context) => true;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      key: const ValueKey<String>('android-navigation-bar'),
      height: height + bottom,
      padding: EdgeInsets.only(bottom: bottom),
      color: palette.surface.resolveFrom(context),
      child: Row(
        children: <Widget>[
          for (var index = 0; index < items.length; index++)
            Expanded(
              child: _BarDestination(
                item: items[index],
                selected: index == currentIndex,
                onTap: () => onTap?.call(index),
              ),
            ),
        ],
      ),
    );
  }

  @override
  AndroidNavigationBar copyWith({
    Key? key,
    List<BottomNavigationBarItem>? items,
    Color? backgroundColor,
    Color? activeColor,
    Color? inactiveColor,
    double? iconSize,
    double? height,
    Border? border,
    int? currentIndex,
    ValueChanged<int>? onTap,
  }) {
    return AndroidNavigationBar(
      key: key ?? this.key,
      items: items ?? this.items,
      onTap: onTap ?? this.onTap,
      currentIndex: currentIndex ?? this.currentIndex,
      height: height ?? this.height,
    );
  }
}

class _BarDestination extends StatelessWidget {
  const _BarDestination({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final BottomNavigationBarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final Color foreground = selected
        ? EhPalette.accent.resolveFrom(context)
        : palette.text2.resolveFrom(context);
    final label = item.label ?? '';
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: 64,
              height: 32,
              decoration: ShapeDecoration(
                color: selected
                    ? EhPalette.accentSoft.resolveFrom(context)
                    : const Color(0x00000000),
                shape: const StadiumBorder(),
              ),
              child: IconTheme.merge(
                data: IconThemeData(color: foreground, size: 22),
                child: Center(child: selected ? item.activeIcon : item.icon),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler:
                  MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2),
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? palette.text1.resolveFrom(context) : foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
