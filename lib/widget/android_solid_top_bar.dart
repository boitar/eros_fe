import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:flutter/cupertino.dart';

/// Android's list header when glass is off: a search field row, then the
/// groups as scrollable filter chips. Both rows keep the heights of the bars
/// they replace, so the header still collapses the same way.
class AndroidSolidTopBar extends StatefulWidget {
  const AndroidSolidTopBar({
    super.key,
    required this.search,
    required this.categories,
    required this.selectedIndex,
    this.leading,
    this.trailing = const <LiquidGlassRailAction>[],
    this.categoryTrailing,
    this.opacity = 1,
    this.rowHeight = 44,
    this.chipRowHeight = 44,
  });

  final LiquidGlassRailSearch search;
  final List<LiquidGlassRailCategory> categories;
  final int selectedIndex;
  final Widget? leading;
  final List<LiquidGlassRailAction> trailing;
  final LiquidGlassRailAction? categoryTrailing;
  final double opacity;
  final double rowHeight;
  final double chipRowHeight;

  @override
  State<AndroidSolidTopBar> createState() => _AndroidSolidTopBarState();
}

class _AndroidSolidTopBarState extends State<AndroidSolidTopBar> {
  final ScrollController _chips = ScrollController();
  final Map<int, GlobalKey> _chipKeys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(animate: false));
  }

  @override
  void didUpdateWidget(AndroidSolidTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  /// Keeps the selected chip on screen when the page is swiped.
  void _reveal({bool animate = true}) {
    final context = _chipKeys[widget.selectedIndex]?.currentContext;
    if (!mounted || context == null) {
      return;
    }
    Scrollable.ensureVisible(
      context,
      alignment: 0.5,
      duration: animate ? const Duration(milliseconds: 240) : Duration.zero,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _chips.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final text1 = palette.text1.resolveFrom(context);
    final text2 = palette.text2.resolveFrom(context);
    final padding = MediaQuery.paddingOf(context);

    Widget iconButton(LiquidGlassRailAction action) => Semantics(
          button: true,
          label: action.label,
          excludeSemantics: true,
          onTap: action.onPressed,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              vibrateUtil.light();
              action.onPressed();
            },
            child: SizedBox.square(
              dimension: widget.rowHeight,
              child: Icon(action.icon, size: 22, color: action.color ?? text1),
            ),
          ),
        );

    final search = Semantics(
      button: true,
      label: widget.search.label,
      excludeSemantics: true,
      onTap: widget.search.onTap,
      child: GestureDetector(
        key: const ValueKey<String>('android-solid-search'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          vibrateUtil.light();
          widget.search.onTap();
        },
        child: Container(
          height: widget.rowHeight - 4,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: ShapeDecoration(
            color: palette.field.resolveFrom(context),
            shape: const StadiumBorder(),
          ),
          child: Row(
            children: <Widget>[
              Icon(CupertinoIcons.search, size: 20, color: text2),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.search.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, color: text2),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Every chip is built, so the selected one can always be scrolled to;
    // a user has a handful of groups, not hundreds.
    final chips = SingleChildScrollView(
      controller: _chips,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: <Widget>[
          for (var index = 0; index < widget.categories.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            _FilterChip(
              key: _chipKeys.putIfAbsent(index, GlobalKey.new),
              category: widget.categories[index],
              selected: index == widget.selectedIndex,
            ),
          ],
        ],
      ),
    );

    return Opacity(
      opacity: widget.opacity.clamp(0.0, 1.0),
      child: ColoredBox(
        color: palette.canvas.resolveFrom(context),
        child: Padding(
          padding: EdgeInsets.only(
            top: padding.top,
            left: padding.left,
            right: padding.right,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                height: widget.rowHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: <Widget>[
                      if (widget.leading != null)
                        SizedBox.square(
                          dimension: widget.rowHeight,
                          child: Center(child: widget.leading),
                        )
                      else
                        const SizedBox(width: 8),
                      Expanded(child: search),
                      for (final action in widget.trailing) iconButton(action),
                      if (widget.trailing.isEmpty) const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: widget.chipRowHeight,
                child: Row(
                  children: <Widget>[
                    Expanded(child: chips),
                    if (widget.categoryTrailing != null)
                      iconButton(widget.categoryTrailing!),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.category,
    required this.selected,
  });

  final LiquidGlassRailCategory category;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final text1 = palette.text1.resolveFrom(context);
    return Semantics(
      button: true,
      selected: selected,
      label: category.title,
      excludeSemantics: true,
      onTap: category.onTap,
      onLongPress: category.onLongPress,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          vibrateUtil.selection();
          category.onTap();
        },
        onLongPress: category.onLongPress == null
            ? null
            : () {
                vibrateUtil.medium();
                category.onLongPress!();
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 32,
          padding: EdgeInsets.only(left: selected ? 8 : 12, right: 12),
          decoration: ShapeDecoration(
            color: selected
                ? EhPalette.accentSoft.resolveFrom(context)
                : const Color(0x00000000),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: selected
                  ? BorderSide.none
                  : BorderSide(color: EhPalette.separator.resolveFrom(context)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (selected) ...<Widget>[
                Icon(CupertinoIcons.checkmark_alt, size: 16, color: accent),
                const SizedBox(width: 4),
              ],
              Text(
                category.title,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: selected ? accent : text1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
