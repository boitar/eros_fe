import 'dart:math' as math;

import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:flutter/cupertino.dart';

/// A small, local control in the transparent Glass Rail.
class LiquidGlassRailAction {
  const LiquidGlassRailAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;
}

/// One item in the horizontal category rail.
class LiquidGlassRailCategory {
  const LiquidGlassRailCategory({
    required this.title,
    required this.onTap,
    this.onLongPress,
  });

  final String title;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
}

/// Glass Rail v2: four independent top controls with one adaptive category
/// glass surface. The rail owns the collapse geometry so every list page uses
/// the same island/notch behavior.
class LiquidGlassRail extends StatefulWidget {
  const LiquidGlassRail({
    super.key,
    required this.title,
    required this.safeTop,
    required this.collapseProgress,
    required this.dockingTranslation,
    required this.selectedIndex,
    this.followSystemTransparency = true,
    this.categories = const <LiquidGlassRailCategory>[],
    this.leading,
    this.trailing = const <LiquidGlassRailAction>[],
    this.categoryTrailing = const <LiquidGlassRailAction>[],
    this.onTitleTap,
    this.refreshing = false,
  });

  static const double controlSize = 44.0;
  static const double categoryHeight = 48.0;
  static const double expandedHeight = controlSize;
  static const int maxVisibleCategories = 4;

  /// Returns the largest prefix that can be presented in equal-width slots.
  ///
  /// The last visible item may be truncated. Earlier items must fit their
  /// equal slot, otherwise the trailing item is removed and the remaining
  /// prefix gets wider slots.
  static int visibleCategoryCount({
    required List<double> preferredWidths,
    required double availableWidth,
  }) {
    if (preferredWidths.isEmpty || availableWidth <= 0.0) return 0;
    final int maxCount = math.min(
      maxVisibleCategories,
      preferredWidths.length,
    );
    for (int count = maxCount; count >= 1; count--) {
      final slotWidth = availableWidth / count;
      var precedingCategoriesFit = true;
      for (int index = 0; index < count - 1; index++) {
        if (preferredWidths[index] > slotWidth) {
          precedingCategoriesFit = false;
          break;
        }
      }
      if (precedingCategoriesFit) return count;
    }
    return 1;
  }

  final String title;
  final double safeTop;
  final double collapseProgress;
  final double dockingTranslation;
  final int selectedIndex;
  final bool followSystemTransparency;
  final List<LiquidGlassRailCategory> categories;
  final LiquidGlassRailAction? leading;
  final List<LiquidGlassRailAction> trailing;
  final List<LiquidGlassRailAction> categoryTrailing;
  final VoidCallback? onTitleTap;
  final bool refreshing;

  @override
  State<LiquidGlassRail> createState() => _LiquidGlassRailState();
}

class _LiquidGlassRailState extends State<LiquidGlassRail> {
  static const double _collapseThreshold = 0.98;
  static const double _restoreThreshold = 0.72;

  bool _collapsed = false;
  int _previewCategoryIndex = 0;
  int? _categoryPointerId;
  double _categoryPointerStartX = 0.0;
  bool _categoryDragging = false;

  @override
  void initState() {
    super.initState();
    _collapsed = widget.collapseProgress >= _collapseThreshold;
    _previewCategoryIndex = _clampCategoryIndex(widget.selectedIndex);
  }

  @override
  void didUpdateWidget(covariant LiquidGlassRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final progress = widget.collapseProgress.clamp(0.0, 1.0);
    if (progress >= _collapseThreshold) {
      _collapsed = true;
    } else if (progress <= _restoreThreshold) {
      _collapsed = false;
    }
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      if (!_categoryDragging) {
        _previewCategoryIndex = _clampCategoryIndex(widget.selectedIndex);
      }
    }
  }

  int _clampCategoryIndex(int index) {
    if (widget.categories.isEmpty) return 0;
    return index.clamp(0, widget.categories.length - 1);
  }

  int get _displayedCategoryIndex => _clampCategoryIndex(
        _categoryDragging ? _previewCategoryIndex : widget.selectedIndex,
      );

  void _onCategoryPointerDown(PointerDownEvent event) {
    if (widget.categories.length < 2) return;
    _categoryPointerId = event.pointer;
    _categoryPointerStartX = event.localPosition.dx;
    _categoryDragging = false;
    _previewCategoryIndex = _clampCategoryIndex(widget.selectedIndex);
  }

  void _onCategoryPointerMove(
    PointerMoveEvent event,
    List<double> itemWidths,
  ) {
    if (_categoryPointerId != event.pointer || itemWidths.length < 2) return;
    final delta = event.localPosition.dx - _categoryPointerStartX;
    if (!_categoryDragging && delta.abs() < 6.0) return;

    final nextIndex = _categoryIndexForPosition(
      event.localPosition.dx,
      itemWidths,
    );
    if (_categoryDragging && nextIndex == _previewCategoryIndex) return;
    setState(() {
      _categoryDragging = true;
      _previewCategoryIndex = nextIndex;
    });
  }

  void _onCategoryPointerUp(PointerUpEvent event) {
    if (_categoryPointerId != event.pointer) return;
    _categoryPointerId = null;
    if (!_categoryDragging) return;

    final target = _clampCategoryIndex(_previewCategoryIndex);
    final shouldNotify = target != _clampCategoryIndex(widget.selectedIndex);
    setState(() {
      _categoryDragging = false;
      _previewCategoryIndex = target;
    });
    if (shouldNotify) {
      widget.categories[target].onTap();
    }
  }

  void _onCategoryPointerCancel(PointerCancelEvent event) {
    if (_categoryPointerId != event.pointer) return;
    _categoryPointerId = null;
    if (!_categoryDragging) return;
    setState(() {
      _categoryDragging = false;
      _previewCategoryIndex = _clampCategoryIndex(widget.selectedIndex);
    });
  }

  int _categoryIndexForPosition(
    double x,
    List<double> itemWidths,
  ) {
    double cursor = 0.0;
    int nearestIndex = 0;
    double nearestDistance = double.infinity;
    for (int index = 0; index < itemWidths.length; index++) {
      final itemWidth = itemWidths[index];
      final visualCenter = cursor + itemWidth / 2.0;
      final left = visualCenter - itemWidth / 2.0;
      final right = visualCenter + itemWidth / 2.0;
      if (x >= left && x <= right) {
        return index;
      }
      final distance = (x - visualCenter).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
      cursor += itemWidth;
    }
    return nearestIndex;
  }

  @override
  Widget build(BuildContext context) {
    final rawProgress = widget.collapseProgress.clamp(0.0, 1.0);
    // Keep the collapsed state stable while the scroll physics bounces around
    // the boundary. The rail only becomes visible again after a deliberate
    // downward movement past the lower restore threshold.
    final progress =
        _collapsed && rawProgress > _restoreThreshold ? 1.0 : rawProgress;
    final eased = Curves.easeInOutCubic.transform(progress);
    final shouldHideSemantics = _collapsed;
    final opacity = (1.0 - Curves.easeOut.transform(progress)).clamp(0.0, 1.0);
    final translationY = -widget.dockingTranslation * eased;

    final shownCategories = widget.categories
        .take(LiquidGlassRail.maxVisibleCategories)
        .toList(growable: false);
    final rightActions = <LiquidGlassRailAction>[
      ...widget.categoryTrailing,
      ...widget.trailing,
    ];
    final leftInset =
        widget.leading == null ? 8.0 : 8.0 + LiquidGlassRail.controlSize + 6.0;
    final rightButtonsWidth = rightActions.isEmpty
        ? 0.0
        : rightActions.length * LiquidGlassRail.controlSize +
            (rightActions.length - 1) * 4.0;
    final rightInset = 8.0 + rightButtonsWidth + 6.0;

    Widget railContent = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (widget.leading != null)
          Positioned(
            left: 8.0,
            top: widget.safeTop,
            width: LiquidGlassRail.controlSize,
            height: LiquidGlassRail.controlSize,
            child: _actionButton(widget.leading!),
          ),
        if (shownCategories.isNotEmpty)
          Positioned(
            left: leftInset,
            right: rightInset,
            top: widget.safeTop,
            height: LiquidGlassRail.controlSize,
            child: _categorySurface(context, shownCategories),
          ),
        if (rightActions.isNotEmpty)
          Positioned(
            right: 8.0,
            top: widget.safeTop,
            height: LiquidGlassRail.controlSize,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int index = 0; index < rightActions.length; index++)
                  if (index == 0)
                    _actionButton(rightActions[index])
                  else ...<Widget>[
                    const SizedBox(width: 4.0),
                    _actionButton(rightActions[index]),
                  ],
              ],
            ),
          ),
      ],
    );

    railContent = Transform.translate(
      offset: Offset(0.0, translationY),
      child: Opacity(opacity: opacity, child: railContent),
    );

    if (progress >= 0.995) {
      // Dispose the platform-view subtree at the terminal state. Offstage is
      // not sufficient for every UiKitView composition path: an already
      // mounted native glass view can otherwise remain visible for a frame.
      railContent = const SizedBox.shrink();
    } else if (shouldHideSemantics) {
      railContent = IgnorePointer(
        child: ExcludeSemantics(child: railContent),
      );
    }

    return SizedBox(
      height: widget.safeTop + LiquidGlassRail.expandedHeight,
      child: railContent,
    );
  }

  Widget _categorySurface(
    BuildContext context,
    List<LiquidGlassRailCategory> categories,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final preferredWidths = <double>[
          for (int index = 0; index < categories.length; index++)
            _categoryItemWidth(context, categories[index], index),
        ];
        final visibleCount = LiquidGlassRail.visibleCategoryCount(
          preferredWidths: preferredWidths,
          availableWidth: availableWidth,
        );
        if (visibleCount == 0) return const SizedBox.shrink();

        final visibleCategories = categories.take(visibleCount).toList();
        final slotWidth = availableWidth / visibleCount;
        final itemWidths = List<double>.filled(visibleCount, slotWidth);
        return LiquidGlassSurface(
          key: const ValueKey<String>('liquid-glass-category-selection'),
          enabled: true,
          borderRadius: BorderRadius.circular(22.0),
          // The category rail is a legibility-first navigation surface. Its
          // labels remain in Flutter for composition safety, so use the same
          // regular material intent as the native action circles and give the
          // fallback an explicit capsule edge/highlight.
          style: LiquidGlassStyle.regular,
          followSystemTransparency: widget.followSystemTransparency,
          useNativeGlass: false,
          emphasizeFallbackEdge: true,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onCategoryPointerDown,
            onPointerMove: (event) => _onCategoryPointerMove(
              event,
              itemWidths,
            ),
            onPointerUp: _onCategoryPointerUp,
            onPointerCancel: _onCategoryPointerCancel,
            child: SizedBox(
              height: LiquidGlassRail.controlSize,
              child: Row(
                children: <Widget>[
                  for (int index = 0; index < visibleCategories.length; index++)
                    _categorySlot(
                      context,
                      visibleCategories[index],
                      index,
                      slotWidth,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _categorySlot(
    BuildContext context,
    LiquidGlassRailCategory category,
    int index,
    double slotWidth,
  ) {
    final selected = index == _displayedCategoryIndex;
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          fontSize: 15.0,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected
              ? CupertinoDynamicColor.resolve(
                  CupertinoColors.activeBlue,
                  context,
                )
              : CupertinoDynamicColor.resolve(
                  CupertinoColors.label,
                  context,
                ),
        );
    return Semantics(
      button: true,
      selected: selected,
      label: category.title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: category.onTap,
        onLongPress: category.onLongPress,
        child: SizedBox(
          width: slotWidth,
          height: LiquidGlassRail.controlSize,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                category.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _categoryItemWidth(
    BuildContext context,
    LiquidGlassRailCategory category,
    int index,
  ) {
    final selected = index == widget.selectedIndex;
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          fontSize: 15,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        );
    final painter = TextPainter(
      text: TextSpan(text: category.title, style: textStyle),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout(
        maxWidth: math.max(40.0, MediaQuery.sizeOf(context).width - 32.0),
      );
    return (painter.width + 20.0).clamp(44.0, 220.0).toDouble();
  }

  Widget _actionButton(LiquidGlassRailAction action) {
    final color = CupertinoDynamicColor.resolve(
      action.color ?? CupertinoColors.label,
      context,
    );
    return SizedBox(
      width: LiquidGlassRail.controlSize,
      height: LiquidGlassRail.controlSize,
      child: LiquidGlassSurface(
        enabled: true,
        borderRadius: BorderRadius.circular(LiquidGlassRail.controlSize / 2),
        // Top actions are navigation chrome with icons, not media controls.
        // Regular avoids the dark clear-glass edge seen over bright content.
        style: LiquidGlassStyle.regular,
        interactive: false,
        followSystemTransparency: widget.followSystemTransparency,
        child: Semantics(
          button: true,
          label: action.label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: action.onPressed,
            child: Center(
              child: Icon(action.icon, size: 25, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
