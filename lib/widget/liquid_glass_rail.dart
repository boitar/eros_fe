import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:eros_fe/widget/appkit_interaction.dart';
import 'package:eros_fe/widget/desktop_pointer_effects.dart';
import 'package:eros_fe/widget/scroll_edge_effect.dart';
import 'package:eros_fe/widget/segmented_rail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';

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
    this.id,
    required this.onTap,
    this.onLongPress,
  });

  final String? id;
  final String title;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
}

/// A search field shown as a glass capsule in the first row of a two-row rail.
/// Tapping it opens the search page; it never takes text input in place.
class LiquidGlassRailSearch {
  const LiquidGlassRailSearch({
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final VoidCallback onTap;

  /// An icon button drawn inside the capsule's right end, such as history.
  final LiquidGlassRailAction? trailing;
}

/// Four independent top controls with one adaptive category glass surface.
/// Page hosts keep the rail fixed and provide the shared scroll progress.
class LiquidGlassRail extends StatefulWidget {
  const LiquidGlassRail({
    super.key,
    required this.title,
    required this.safeTop,
    required this.fadeProgress,
    required this.selectedIndex,
    this.followSystemTransparency = true,
    this.categories = const <LiquidGlassRailCategory>[],
    this.leading,
    this.trailing = const <LiquidGlassRailAction>[],
    this.categoryTrailing = const <LiquidGlassRailAction>[],
    this.onTitleTap,
    this.refreshing = false,
    this.layout = LiquidGlassTopBarLayout.twoRow,
    this.pageController,
    this.compactCategories = false,
    this.search,
    this.showsTitle = false,
  });

  static const double controlSize = 44.0;

  /// Without categories, draws [title] in the first row between [leading]
  /// and the right-hand buttons, as the desktop list header beside the
  /// sidebar does. Tapping it calls [onTitleTap].
  final bool showsTitle;

  /// In the two-row layout with categories it fills the first row between
  /// [leading] and [trailing]; [categoryTrailing] then moves down to sit
  /// beside the categories. Otherwise it is the first round button on the
  /// right.
  final LiquidGlassRailSearch? search;
  final LiquidGlassTopBarLayout layout;
  final PageController? pageController;

  final String title;
  final double safeTop;
  final double fadeProgress;
  final int selectedIndex;
  final bool followSystemTransparency;
  final List<LiquidGlassRailCategory> categories;
  final bool compactCategories;
  final LiquidGlassRailAction? leading;
  final List<LiquidGlassRailAction> trailing;
  final List<LiquidGlassRailAction> categoryTrailing;
  final VoidCallback? onTitleTap;
  final bool refreshing;

  @override
  State<LiquidGlassRail> createState() => _LiquidGlassRailState();
}

/// Fires a selection haptic whenever the page swiping underneath the category
/// rail crosses a category boundary, but only while the user's finger drives
/// the swipe. Tap commits animate programmatically and stay silent here: they
/// already haptic in their own tap path (selection/light), so the lens gliding
/// across categories after a tap must not re-tick every boundary.
class _RailScrubTicker {
  int _lastIndex = -1;

  void update(PageController? controller) {
    if (controller == null ||
        !controller.hasClients ||
        controller.page == null) {
      return;
    }
    final double page = controller.page!;
    final int index = page.round();
    final position = controller.position;
    final bool userDriven =
        position.isScrollingNotifier.value &&
        position.userScrollDirection != ScrollDirection.idle;
    if (userDriven && index != _lastIndex) {
      liquidGlassFeedback(vibrateUtil.selection);
    }
    _lastIndex = index;
  }
}

class _LiquidGlassRailState extends State<LiquidGlassRail> {
  final ScrollController _scroll = ScrollController();
  final _RailScrubTicker _scrubTicker = _RailScrubTicker();
  double _nativeOffset = 0;
  double _fallbackOffset = 0;
  bool _restoreOffset = false;

  void _handlePageScrub() {
    _scrubTicker.update(widget.pageController);
  }

  @override
  void initState() {
    super.initState();
    widget.pageController?.addListener(_handlePageScrub);
    _scroll.addListener(() {
      if (_scroll.hasClients) {
        _fallbackOffset = _scroll.offset;
      }
    });
  }

  bool _reveal = true;

  @override
  void didUpdateWidget(covariant LiquidGlassRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageController != widget.pageController) {
      oldWidget.pageController?.removeListener(_handlePageScrub);
      widget.pageController?.addListener(_handlePageScrub);
    }
    final progress = widget.fadeProgress.clamp(0.0, 1.0);
    if (oldWidget.fadeProgress >= 1.0 && progress < 1.0) {
      _restoreOffset = true;
    }
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.layout != widget.layout ||
        !listEquals(
          oldWidget.categories.map((e) => e.id ?? e.title).toList(),
          widget.categories.map((e) => e.id ?? e.title).toList(),
        )) {
      _reveal = true;
    }
  }

  @override
  void dispose() {
    widget.pageController?.removeListener(_handlePageScrub);
    _scroll.dispose();
    super.dispose();
  }

  bool get _isAndroidChrome =>
      PlatformCapabilities.hostPlatform == TargetPlatform.android;

  bool get _sharesBackdrop => _isAndroidChrome;

  Widget _fadeRail({required double opacity, required Widget child}) {
    if (!_sharesBackdrop) {
      return child;
    }
    // These surfaces do not overlap and fade together. Keep the fade above
    // the group: even Opacity(1) between a surface and its group prevents
    // sharing, since it may open a separate render pass on a later frame.
    // A rail owns its group; routes and retained tabs must not share it.
    return Opacity(
      opacity: opacity,
      child: GlassBackdropGroup(child: child),
    );
  }

  Widget _fadeControl({required double opacity, required Widget child}) =>
      _sharesBackdrop ? child : Opacity(opacity: opacity, child: child);

  /// Pure GPU transform motion for Android single-row auto-hide (KF-B1):
  /// never introduces a [RenderOpacity] inside [GlassBackdropGroup].
  Widget _androidSingleRowMotion(double progress, Widget child) {
    if (!_isAndroidChrome || progress <= 0.0) {
      return child;
    }
    return Transform.translate(
      offset: Offset(0, -14.0 * progress),
      child: Transform.scale(
        alignment: Alignment.topCenter,
        scale: 1.0 - 0.06 * progress,
        child: child,
      ),
    );
  }

  /// Staggered parallax motion for Android two-row Row 1 (KF-B1/B2).
  Widget _androidSearchRowMotion(double progress, Widget child) {
    if (!_isAndroidChrome || progress <= 0.0) {
      return child;
    }
    final p1a = (progress / 0.55).clamp(0.0, 1.0);
    final p1b = ((progress - 0.55) / 0.45).clamp(0.0, 1.0);
    return Transform.translate(
      offset: Offset(0, -5.0 * p1a - 11.0 * p1b),
      child: Transform.scale(
        alignment: Alignment.topCenter,
        scale: 1.0 - 0.03 * p1a - 0.05 * p1b,
        child: child,
      ),
    );
  }

  /// Staggered parallax motion for Android two-row Row 2 (KF-B1): tucks ahead
  /// of Row 1 using a pure GPU transform so backdrop sharing stays intact.
  Widget _androidSecondaryRowMotion(double progress, Widget child) {
    if (!_isAndroidChrome || progress <= 0.0) {
      return child;
    }
    final p2 = (progress / 0.55).clamp(0.0, 1.0);
    return Transform.translate(
      offset: Offset(0, -12.0 * p2),
      child: Transform.scale(
        alignment: Alignment.topCenter,
        scale: 1.0 - 0.06 * p2,
        child: child,
      ),
    );
  }

  double _fusedCapsuleWidth(int count, double height) {
    if (count <= 0) {
      return 0.0;
    }
    if (count == 1) {
      return height;
    }
    final slotWidth = height <= 32.0 ? 28.0 : 34.0;
    return 8.0 + count * slotWidth + (count - 1) * 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.fadeProgress.clamp(0.0, 1.0).toDouble();
    final fadeOpacity = (1.0 - progress).clamp(0.0, 1.0).toDouble();
    final fullyHidden = fadeOpacity == 0.0;

    final shownCategories = widget.categories;
    final twoRow = widget.layout == LiquidGlassTopBarLayout.twoRow;
    final textScaler = MediaQuery.textScalerOf(context);
    final categoryHeight = widget.layout.categoryHeight(textScaler);
    final searchRow =
        widget.search != null && twoRow && shownCategories.isNotEmpty;
    if (searchRow) {
      return _buildSearchLayout(
        context,
        shownCategories,
        categoryHeight: categoryHeight,
        fadeProgress: progress,
        fadeOpacity: fadeOpacity,
        fullyHidden: fullyHidden,
      );
    }
    final search = widget.search;
    final rightActions = <LiquidGlassRailAction>[
      // Without the search row (single-row layout, or no categories) the
      // search stays reachable in the top-right glass control group.
      if (search != null)
        LiquidGlassRailAction(
          icon: CupertinoIcons.search,
          label: search.label,
          onPressed: search.onTap,
        ),
      ...widget.categoryTrailing,
      ...widget.trailing,
    ];
    final android = _isAndroidChrome;
    final double edge = android ? 12.0 : 8.0;
    final double gap = android ? 7.0 : 6.0;
    final double controlHeight = android
        ? widget.layout.primaryRowHeight
        : LiquidGlassRail.controlSize;
    final bool fuseRightActions = android && rightActions.length >= 2;
    final double leftInset = widget.leading == null
        ? edge
        : edge + controlHeight + gap;
    final double rightButtonsWidth = rightActions.isEmpty
        ? 0.0
        : fuseRightActions
        ? _fusedCapsuleWidth(rightActions.length, controlHeight)
        : rightActions.length * controlHeight + (rightActions.length - 1) * 4.0;
    final double rightInset = rightActions.isEmpty
        ? edge
        : edge + rightButtonsWidth + gap;
    final double categoryLeftInset = widget.compactCategories
        ? math.max(leftInset, rightInset)
        : leftInset;
    final double categoryRightInset = widget.compactCategories
        ? math.max(leftInset, rightInset)
        : rightInset;
    final double categoryTop =
        widget.safeTop + (twoRow ? widget.layout.secondRowOffset : 0.0);

    Widget railContent = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (widget.leading != null)
          Positioned(
            left: edge,
            top: widget.safeTop,
            width: controlHeight,
            height: controlHeight,
            child: _androidSingleRowMotion(
              progress,
              _actionButton(
                widget.leading!,
                opacity: fadeOpacity,
                size: controlHeight,
              ),
            ),
          ),
        if (shownCategories.isEmpty && widget.showsTitle)
          Positioned(
            left: widget.leading == null ? 16.0 : leftInset + 4.0,
            right: rightInset,
            top: widget.safeTop,
            height: controlHeight,
            child: _androidSingleRowMotion(
              progress,
              _fadeControl(
                opacity: fadeOpacity,
                child: Semantics(
                  header: true,
                  button: widget.onTitleTap != null,
                  child: GestureDetector(
                    key: const ValueKey<String>('liquid-glass-rail-title'),
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onTitleTap,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CupertinoTheme.of(context)
                            .textTheme
                            .navLargeTitleTextStyle
                            .copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (shownCategories.isNotEmpty)
          Positioned(
            left: twoRow ? edge : categoryLeftInset,
            right: twoRow ? edge : categoryRightInset,
            top: categoryTop,
            height: categoryHeight,
            child: twoRow
                ? _androidSecondaryRowMotion(
                    progress,
                    _categorySurface(
                      context,
                      shownCategories,
                      opacity: fadeOpacity,
                    ),
                  )
                : _androidSingleRowMotion(
                    progress,
                    _categorySurface(
                      context,
                      shownCategories,
                      opacity: fadeOpacity,
                    ),
                  ),
          ),
        if (rightActions.isNotEmpty)
          Positioned(
            right: edge,
            top: widget.safeTop,
            height: controlHeight,
            child: _androidSingleRowMotion(
              progress,
              fuseRightActions
                  ? _fusedActionCapsule(
                      rightActions,
                      height: controlHeight,
                      opacity: fadeOpacity,
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (
                          int index = 0;
                          index < rightActions.length;
                          index++
                        )
                          if (index == 0)
                            _actionButton(
                              rightActions[index],
                              opacity: fadeOpacity,
                              size: controlHeight,
                            )
                          else ...<Widget>[
                            const SizedBox(width: 4.0),
                            _actionButton(
                              rightActions[index],
                              opacity: fadeOpacity,
                              size: controlHeight,
                            ),
                          ],
                      ],
                    ),
            ),
          ),
      ],
    );

    if (fullyHidden) {
      // Dispose the platform-view subtree at the terminal state. Offstage is
      // not sufficient for every UiKitView composition path: an already
      // mounted native glass view can otherwise remain visible for a frame.
      railContent = const SizedBox.shrink();
    }

    return SizedBox(
      height:
          widget.safeTop +
          widget.layout.expandedHeight(
            textScaler,
            hasCategories: widget.categories.isNotEmpty,
          ),
      child: _fadeRail(
        opacity: fadeOpacity,
        child: Stack(fit: StackFit.expand, children: <Widget>[railContent]),
      ),
    );
  }

  /// Row one: [leading] · search capsule · [trailing]. Row two: categories ·
  /// [categoryTrailing].
  Widget _buildSearchLayout(
    BuildContext context,
    List<LiquidGlassRailCategory> categories, {
    required double categoryHeight,
    required double fadeProgress,
    required double fadeOpacity,
    required bool fullyHidden,
  }) {
    final android = _isAndroidChrome;
    final double size = android
        ? widget.layout.primaryRowHeight
        : LiquidGlassRail.controlSize;
    final double edge = android ? 12.0 : 8.0;
    final double gap = android ? 7.0 : 6.0;
    final double catButtonSize = android ? categoryHeight : size;

    double rowWidth(int count, double buttonSize) {
      if (count == 0) {
        return 0.0;
      }
      if (android && count >= 2) {
        return _fusedCapsuleWidth(count, buttonSize);
      }
      return count * buttonSize + (count - 1) * 4.0;
    }

    Widget actionRow(List<LiquidGlassRailAction> actions, double buttonSize) {
      if (android && actions.length >= 2) {
        return _fusedActionCapsule(
          actions,
          height: buttonSize,
          opacity: fadeOpacity,
        );
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int index = 0; index < actions.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: 4.0),
            _actionButton(
              actions[index],
              opacity: fadeOpacity,
              size: buttonSize,
            ),
          ],
        ],
      );
    }

    final searchLeft = widget.leading == null ? edge : edge + size + gap;
    final searchRight = widget.trailing.isEmpty
        ? edge
        : edge + rowWidth(widget.trailing.length, size) + gap;
    final categoryRight = widget.categoryTrailing.isEmpty
        ? edge
        : edge + rowWidth(widget.categoryTrailing.length, catButtonSize) + gap;
    final categoryTop = widget.safeTop + widget.layout.secondRowOffset;

    final Widget railContent = fullyHidden
        ? const SizedBox.shrink()
        : Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (widget.leading != null)
                Positioned(
                  left: edge,
                  top: widget.safeTop,
                  width: size,
                  height: size,
                  child: _androidSearchRowMotion(
                    fadeProgress,
                    _actionButton(
                      widget.leading!,
                      opacity: fadeOpacity,
                      size: size,
                    ),
                  ),
                ),
              Positioned(
                left: searchLeft,
                right: searchRight,
                top: widget.safeTop,
                height: size,
                child: _androidSearchRowMotion(
                  fadeProgress,
                  _searchCapsule(
                    widget.search!,
                    opacity: fadeOpacity,
                    height: size,
                  ),
                ),
              ),
              if (widget.trailing.isNotEmpty)
                Positioned(
                  right: edge,
                  top: widget.safeTop,
                  height: size,
                  child: _androidSearchRowMotion(
                    fadeProgress,
                    actionRow(widget.trailing, size),
                  ),
                ),
              Positioned(
                left: edge,
                right: categoryRight,
                top: categoryTop,
                height: categoryHeight,
                child: _androidSecondaryRowMotion(
                  fadeProgress,
                  _categorySurface(context, categories, opacity: fadeOpacity),
                ),
              ),
              if (widget.categoryTrailing.isNotEmpty)
                Positioned(
                  right: edge,
                  top: categoryTop + (categoryHeight - catButtonSize) / 2,
                  height: catButtonSize,
                  child: _androidSecondaryRowMotion(
                    fadeProgress,
                    actionRow(widget.categoryTrailing, catButtonSize),
                  ),
                ),
            ],
          );

    return SizedBox(
      height:
          widget.safeTop +
          widget.layout.expandedHeight(
            MediaQuery.textScalerOf(context),
            hasCategories: categories.isNotEmpty,
          ),
      child: _fadeRail(opacity: fadeOpacity, child: railContent),
    );
  }

  Widget _searchCapsule(
    LiquidGlassRailSearch search, {
    required double opacity,
    double height = LiquidGlassRail.controlSize,
  }) {
    final android = _isAndroidChrome;
    final labelColor = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    final iconColor = CupertinoDynamicColor.resolve(
      CupertinoColors.label,
      context,
    );
    final radius = BorderRadius.circular(height / 2);
    final trailing = search.trailing;
    final Widget innerRow = Row(
      children: <Widget>[
        Expanded(
          child: Semantics(
            button: true,
            label: search.label,
            excludeSemantics: true,
            onTap: search.onTap,
            child: NavigationHover(
              borderRadius: radius,
              child: _AndroidGlassTapRegion(
                enabled: android,
                borderRadius: radius,
                onTap: () {
                  liquidGlassFeedback(vibrateUtil.light);
                  search.onTap();
                },
                child: Padding(
                  padding: EdgeInsetsDirectional.only(start: android ? 13 : 14),
                  child: Row(
                    children: <Widget>[
                      EhSvgIcon(
                        CupertinoIcons.search,
                        size: android ? 17 : 20,
                        color: iconColor,
                      ),
                      SizedBox(width: android ? 8 : 10),
                      Expanded(
                        child: Text(
                          search.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CupertinoTheme.of(context).textTheme.textStyle
                              .copyWith(
                                fontSize: android ? 14.5 : 16,
                                color: labelColor,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (trailing != null)
          Semantics(
            button: true,
            label: trailing.label,
            excludeSemantics: true,
            onTap: trailing.onPressed,
            child: NavigationHover(
              borderRadius: radius,
              child: _AndroidGlassTapRegion(
                enabled: android,
                borderRadius: radius,
                onTap: () {
                  liquidGlassFeedback(vibrateUtil.light);
                  trailing.onPressed();
                },
                child: SizedBox(
                  width: height,
                  height: height,
                  child: Center(
                    child: EhSvgIcon(
                      trailing.icon,
                      size: android ? 19 : 22,
                      color: CupertinoDynamicColor.resolve(
                        trailing.color ?? CupertinoColors.label,
                        context,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    return _fadeControl(
      opacity: opacity,
      child: LiquidGlassSurface(
        key: const ValueKey<String>('liquid-glass-rail-search'),
        enabled: true,
        borderRadius: radius,
        style: LiquidGlassStyle.regular,
        interactive: false,
        useNativeGlass: false,
        followSystemTransparency: widget.followSystemTransparency,
        child: android
            ? _AndroidGlassChromeRim(radius: height / 2, child: innerRow)
            : innerRow,
      ),
    );
  }

  Widget _categorySurface(
    BuildContext context,
    List<LiquidGlassRailCategory> categories, {
    required double opacity,
  }) {
    final wantsNative =
        GlassMode.of(context).forComponent(flutterImplemented: true) ==
        GlassMode.native;
    return _buildCategorySurface(
      context,
      categories,
      opacity: opacity,
      useNative: wantsNative,
    );
  }

  Widget _buildCategorySurface(
    BuildContext context,
    List<LiquidGlassRailCategory> categories, {
    required double opacity,
    required bool useNative,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fontSize =
            _isAndroidChrome && widget.layout == LiquidGlassTopBarLayout.twoRow
            ? 13.5
            : 15.0;
        final layout = SegmentedRailLayout.compute(
          SegmentedRailLayout.measure(
            context,
            categories.map((category) => category.title).toList(),
            fontSize: fontSize,
          ),
          constraints.maxWidth,
          compact: widget.compactCategories,
        );
        final widths = layout.widths;
        final surfaceWidth = layout.trackWidth;
        final fitIntrinsicWidth =
            widget.compactCategories || !constraints.maxWidth.isFinite;
        Widget fitSurface(Widget child) => fitIntrinsicWidth
            ? Align(
                child: SizedBox(width: surfaceWidth, child: child),
              )
            : child;
        if (useNative) {
          return fitSurface(
            NativeCategoryRail(
              categories: categories,
              selectedIndex: widget.selectedIndex,
              followSystemTransparency: widget.followSystemTransparency,
              brightness: CupertinoTheme.brightnessOf(context),
              fontSize: MediaQuery.textScalerOf(context).scale(15),
              opacity: opacity,
              interactive: widget.fadeProgress < 1.0,
              pageController: widget.pageController,
              layout: widget.layout,
              initialOffset: _nativeOffset,
              onOffset: (value) => _nativeOffset = value,
              segmentWidths: widths,
              modalFallbackBuilder: (context) {
                if (!_scroll.hasClients ||
                    (_scroll.offset - _nativeOffset).abs() > 0.5) {
                  _fallbackOffset = _nativeOffset;
                  _restoreOffset = true;
                }
                return _buildCategorySurface(
                  context,
                  categories,
                  opacity: opacity,
                  useNative: false,
                );
              },
            ),
          );
        }
        final height = constraints.maxHeight;
        final fits = !layout.scrolls;
        final positions = <double>[
          for (var index = 0; index < widths.length; index++)
            layout.offsetOf(index),
        ];
        final contentWidth = fits ? surfaceWidth : layout.contentWidth;
        if (_isAndroidChrome) {
          final double inset = height <= 32.0 ? 2.5 : 3.0;
          final categorySurface = LiquidGlassSurface(
            key: const ValueKey<String>('liquid-glass-category-selection'),
            enabled: true,
            useNativeGlass: false,
            followSystemTransparency: widget.followSystemTransparency,
            borderRadius: BorderRadius.circular(height / 2),
            child: _AndroidGlassChromeRim(
              radius: height / 2,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(height / 2),
                child: _AndroidGlassCategoryTrack(
                  scrollController: _scroll,
                  categories: categories,
                  selectedIndex: widget.selectedIndex,
                  pageController: widget.pageController,
                  widths: widths,
                  positions: positions,
                  surfaceWidth: surfaceWidth,
                  contentWidth: contentWidth,
                  height: height,
                  inset: inset,
                  scrolls: layout.scrolls,
                  fontSize: fontSize,
                  revealRequested: _reveal,
                  restoreOffset: _restoreOffset ? _fallbackOffset : null,
                  onConsumeScrollSync: () {
                    _reveal = false;
                    _restoreOffset = false;
                  },
                ),
              ),
            ),
          );
          return fitSurface(
            _fadeControl(opacity: opacity, child: categorySurface),
          );
        }
        if ((_reveal || _restoreOffset) && categories.isNotEmpty) {
          final revealSelection = _reveal;
          final restoreOffset = _fallbackOffset;
          _reveal = false;
          _restoreOffset = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_scroll.hasClients) {
              return;
            }
            final index = widget.selectedIndex.clamp(0, widths.length - 1);
            final left = positions[index];
            final right = left + widths[index];
            final offset = _scroll.offset;
            final target = !revealSelection
                ? restoreOffset
                : left < offset
                ? left
                : right > offset + surfaceWidth
                ? right - surfaceWidth
                : offset;
            _scroll.jumpTo(target.clamp(0, _scroll.position.maxScrollExtent));
          });
        }
        Widget contents() {
          final progress = widget.pageController?.hasClients == true
              ? widget.pageController!.page ?? widget.selectedIndex.toDouble()
              : widget.selectedIndex.toDouble();
          final page = progress.clamp(0.0, (categories.length - 1).toDouble());
          final lower = page.floor();
          final upper = page.ceil();
          final fraction = page - lower;
          final left =
              positions[lower] +
              (positions[upper] - positions[lower]) * fraction;
          final width =
              widths[lower] + (widths[upper] - widths[lower]) * fraction;
          return SizedBox(
            width: contentWidth,
            height: height,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: widget.pageController == null
                      ? const Duration(milliseconds: 240)
                      : Duration.zero,
                  curve: Curves.easeOutCubic,
                  key: const ValueKey<String>(
                    'liquid-glass-category-selection-indicator',
                  ),
                  left: left + 3,
                  top: 3,
                  width: math.max(0.0, width - 6),
                  height: math.max(0.0, height - 6),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: CupertinoDynamicColor.resolve(
                        CupertinoColors.tertiarySystemFill,
                        context,
                      ),
                      borderRadius: BorderRadius.circular(height / 2),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Row(
                    children: [
                      for (var i = 0; i < categories.length; i++)
                        _categorySlot(context, categories[i], i, widths[i]),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final categorySurface = LiquidGlassSurface(
          key: const ValueKey<String>('liquid-glass-category-selection'),
          enabled: true,
          useNativeGlass: false,
          followSystemTransparency: widget.followSystemTransparency,
          borderRadius: BorderRadius.circular(height / 2),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              child: HorizontalMouseWheel(
                controller: _scroll,
                child: widget.pageController == null
                    ? contents()
                    : AnimatedBuilder(
                        animation: widget.pageController!,
                        builder: (_, __) => contents(),
                      ),
              ),
            ),
          ),
        );
        return fitSurface(
          _fadeControl(opacity: opacity, child: categorySurface),
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
    final selected = index == widget.selectedIndex;
    // Glass bars stay monochrome over colourful covers. Every label keeps
    // one colour and weight; the pill alone marks the selection, so nothing
    // reflows while it moves.
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle.copyWith(
      fontSize: 15.0,
      fontWeight: FontWeight.w500,
      color: CupertinoDynamicColor.resolve(CupertinoColors.label, context),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: category.title,
      child: NavigationHover(
        borderRadius: BorderRadius.circular(
          widget.layout.categoryHeight(MediaQuery.textScalerOf(context)) / 2,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            liquidGlassFeedback(vibrateUtil.selection);
            category.onTap();
          },
          onLongPress: category.onLongPress == null
              ? null
              : () {
                  liquidGlassFeedback(vibrateUtil.medium);
                  category.onLongPress!();
                },
          child: SizedBox(
            key: ValueKey<String>('liquid-glass-category-slot-$index'),
            width: slotWidth,
            height: widget.layout.categoryHeight(
              MediaQuery.textScalerOf(context),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  category.title,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: textStyle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Android iOS-26-inspired fused glass capsule for 2+ right-hand actions:
  /// shares a single [GlassContainer] surface (reducing GPU refraction passes)
  /// and saves horizontal room for the category track.
  Widget _fusedActionCapsule(
    List<LiquidGlassRailAction> actions, {
    required double height,
    required double opacity,
  }) {
    final radius = BorderRadius.circular(height / 2);
    final double slotWidth = height <= 32.0 ? 28.0 : 34.0;
    final double iconSize = height <= 32.0 ? 15.5 : 18.5;
    final bool isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final dividerColor = isDark
        ? const Color(0x28FFFFFF)
        : const Color(0x1E14161C);

    return _fadeControl(
      opacity: opacity,
      child: SizedBox(
        width: _fusedCapsuleWidth(actions.length, height),
        height: height,
        child: LiquidGlassSurface(
          key: const ValueKey<String>('liquid-glass-rail-fused-actions'),
          enabled: true,
          borderRadius: radius,
          style: LiquidGlassStyle.regular,
          interactive: false,
          followSystemTransparency: widget.followSystemTransparency,
          child: _AndroidGlassChromeRim(
            radius: height / 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (
                    int index = 0;
                    index < actions.length;
                    index++
                  ) ...<Widget>[
                    if (index > 0)
                      Container(
                        width: 1.0,
                        height: height * 0.36,
                        color: dividerColor,
                      ),
                    Semantics(
                      button: true,
                      label: actions[index].label,
                      child: NavigationHover(
                        borderRadius: BorderRadius.circular(height / 2),
                        child: _AndroidGlassTapRegion(
                          enabled: true,
                          borderRadius: BorderRadius.circular(height / 2),
                          onTap: () {
                            liquidGlassFeedback(vibrateUtil.light);
                            actions[index].onPressed();
                          },
                          child: SizedBox(
                            width: slotWidth,
                            height: height,
                            child: Center(
                              child: EhSvgIcon(
                                actions[index].icon,
                                size: iconSize,
                                color: CupertinoDynamicColor.resolve(
                                  actions[index].color ?? CupertinoColors.label,
                                  context,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(
    LiquidGlassRailAction action, {
    required double opacity,
    double size = LiquidGlassRail.controlSize,
  }) {
    final android = _isAndroidChrome;
    final color = CupertinoDynamicColor.resolve(
      action.color ?? CupertinoColors.label,
      context,
    );
    final radius = BorderRadius.circular(size / 2);
    final double iconSize = !android
        ? 25.0
        : size <= 32.0
        ? 16.0
        : 19.0;
    final Widget buttonBody = Semantics(
      button: true,
      label: action.label,
      child: NavigationHover(
        borderRadius: radius,
        child: _AndroidGlassTapRegion(
          enabled: android,
          borderRadius: radius,
          onTap: () {
            liquidGlassFeedback(vibrateUtil.light);
            action.onPressed();
          },
          child: Center(
            child: EhSvgIcon(action.icon, size: iconSize, color: color),
          ),
        ),
      ),
    );
    return _fadeControl(
      opacity: opacity,
      child: SizedBox(
        width: size,
        height: size,
        child: LiquidGlassSurface(
          enabled: true,
          borderRadius: radius,
          // Top actions are navigation chrome with icons, not media controls.
          // Regular avoids the dark clear-glass edge seen over bright content.
          style: LiquidGlassStyle.regular,
          interactive: false,
          followSystemTransparency: widget.followSystemTransparency,
          child: android
              ? _AndroidGlassChromeRim(radius: size / 2, child: buttonBody)
              : buttonBody,
        ),
      ),
    );
  }
}

/// Temporary top-area diagnostics switch, compiled in only for ad-hoc device
/// builds with `--dart-define=LIQUID_GLASS_TOP_DIAGNOSTICS=true`. It records
/// the native accessibility callback value, the fixed top gradient geometry
/// and the running build for real-device comparison. Candidate deliveries
/// never set the define, so no diagnostic output ships with them.
const bool kLiquidGlassTopDiagnostics = bool.fromEnvironment(
  'LIQUID_GLASS_TOP_DIAGNOSTICS',
);

double _topDiagSafeTop = 0;
double _topDiagFadeEnd = 0;
bool _topDiagDark = false;
String? _topDiagSignature;
bool _topDiagListening = false;
String? _topDiagVersion;

void _logLiquidGlassTopState({
  required double safeTop,
  required double fadeEnd,
  required bool dark,
}) {
  if (!kLiquidGlassTopDiagnostics) {
    return;
  }
  _topDiagSafeTop = safeTop;
  _topDiagFadeEnd = fadeEnd;
  _topDiagDark = dark;
  // Evidence collection only: the bridge value never feeds any visual state.
  LiquidGlassAccessibilitySettings.watch();
  if (!_topDiagListening) {
    _topDiagListening = true;
    LiquidGlassAccessibilitySettings.reduceTransparency.addListener(
      _emitLiquidGlassTopDiag,
    );
  }
  _emitLiquidGlassTopDiag();
}

void _emitLiquidGlassTopDiag() {
  final value = LiquidGlassAccessibilitySettings.reduceTransparency.value;
  final signature = '$_topDiagSafeTop|$_topDiagFadeEnd|$_topDiagDark|$value';
  if (signature == _topDiagSignature) {
    return;
  }
  _topDiagSignature = signature;
  unawaited(_printLiquidGlassTopDiag(value));
}

Future<void> _printLiquidGlassTopDiag(bool? reduceTransparency) async {
  if (_topDiagVersion == null) {
    try {
      final info = await PackageInfo.fromPlatform();
      _topDiagVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      _topDiagVersion = 'unknown';
    }
  }
  debugPrint(
    '[LiquidGlassTopDiag] version=$_topDiagVersion '
    'safeTop=$_topDiagSafeTop fadeEnd=$_topDiagFadeEnd '
    'gradientHeight=${math.max(0.0, _topDiagFadeEnd)} '
    'dark=$_topDiagDark reduceTransparency=$reduceTransparency',
  );
}

/// Shared geometry for Flutter-hosted list headers.
abstract final class LiquidGlassEdgeTokens {
  static double get reveal => PlatformCapabilities.isDesktop ? 8 : 16;

  /// Desktop keeps 12pt; Android uses a crisp 6pt gap below the seamless
  /// floating top bar so first-screen gallery viewport ratio matches iOS.
  static double? contentGapFor(BuildContext context) {
    if (PlatformCapabilities.isDesktop) {
      return 12;
    }
    if (PlatformCapabilities.hostPlatform == TargetPlatform.android) {
      return 6;
    }
    return null;
  }

  static double tailFor(BuildContext context) =>
      PlatformCapabilities.isDesktop ? 16 : 0;

  /// The scroll-only soft edge used by Flutter-hosted mobile headers.
  /// iPad keeps its device token even when an AdaptivePane is narrow.
  static double softTailFor(BuildContext context) {
    if (PlatformCapabilities.isDesktop) {
      return 0;
    }
    if (PlatformCapabilities.hostPlatform == TargetPlatform.android) {
      return 20;
    }
    return AdaptiveEnvironment.windowSizeOf(context).shortestSide >= 600
        ? 28
        : 24;
  }
}

const _restingEdge = AlwaysStoppedAnimation<double>(0);

/// Tracks the rail's visible height, keeping the status area and soft tail
/// after its controls have fully faded away.
double _liquidGlassTopFadeEnd({
  required double safeTop,
  required LiquidGlassTopBarLayout layout,
  required bool hasCategories,
  required double screenHeight,
  required TextScaler textScaler,
  double barFadeProgress = 0,
  double tail = 0,
}) {
  final hidden = SoftScrollEdgeEffect.quantizeStrength(barFadeProgress);
  final double activeRailBottom =
      safeTop +
      layout.expandedHeight(textScaler, hasCategories: hasCategories) *
          (1 - hidden);
  return math.min(screenHeight, activeRailBottom + tail).toDouble();
}

// Mobile Flutter headers retain the fixed wash, capped at the resting card.
double _flutterFadeEnd(
  BuildContext context,
  double safeTop,
  LiquidGlassTopBarLayout layout,
  bool hasCategories,
  double progress,
  double? cardTop,
) {
  final screenHeight = MediaQuery.sizeOf(context).height;
  final barBottom =
      safeTop +
      layout.expandedHeight(
        MediaQuery.textScalerOf(context),
        hasCategories: hasCategories,
      );
  final target = math.min(
    screenHeight,
    math.max(barBottom, screenHeight * .17),
  );
  final rest = math.min(target, cardTop ?? barBottom);
  return rest + (target - rest) * progress;
}

/// The themed base layer that sits below the scroll content across the whole
/// top fade region.
///
/// Mobile Flutter headers retain their static legacy wash, capped at the
/// resting first card; desktop has no base layer.
class LiquidGlassSafeAreaBase extends StatelessWidget {
  const LiquidGlassSafeAreaBase({
    super.key,
    required this.safeTop,
    required this.layout,
    this.hasCategories = true,
    this.edgeProgress,
    this.barFadeProgress = 0,
    this.firstCardRestTop,
  });

  final double safeTop;
  final LiquidGlassTopBarLayout layout;
  final bool hasCategories;
  final ValueListenable<double>? edgeProgress;

  /// The same displayed collapse progress supplied to [LiquidGlassRail].
  final double barFadeProgress;
  final ValueListenable<double?>? firstCardRestTop;

  /// Theme-background opacity from the safe-area lower edge down. The first
  /// value continues the solid band; the remaining three sit at 25%, 65% and
  /// 100% of the distance from the safe area to the shared fade end, so both
  /// ends of the fade are continuous.
  static const List<double> _fadeOpacities = <double>[1.0, 0.84, 0.28, 0.0];

  /// Positions of [_fadeOpacities] after the first, as fractions of the
  /// remaining distance between the safe area and the fade end.
  static const List<double> _fadeStopFractions = <double>[0.0, 0.25, 0.65, 1.0];

  @override
  Widget build(BuildContext context) {
    if (safeTop <= 0.0 ||
        PlatformCapabilities.isDesktop ||
        PlatformCapabilities.hostPlatform == TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: Listenable.merge([
        edgeProgress ?? _restingEdge,
        if (firstCardRestTop != null) firstCardRestTop!,
      ]),
      builder: (context, _) => _buildBase(
        context,
        SoftScrollEdgeEffect.quantizeStrength(edgeProgress?.value ?? 0),
      ),
    );
  }

  Widget _buildBase(BuildContext context, double progress) {
    final effectiveEnd = _flutterFadeEnd(
      context,
      safeTop,
      layout,
      hasCategories,
      progress,
      firstCardRestTop?.value,
    );
    final Color background = CupertinoDynamicColor.resolve(
      CupertinoColors.systemBackground,
      context,
    );
    // Solid from the top of the screen through the safe area, then the fade
    // sequence across the remaining distance to the fade end.
    final double solidStop = (safeTop / effectiveEnd).clamp(0.0, 1.0);
    final double remaining = 1.0 - solidStop;
    return IgnorePointer(
      child: SizedBox(
        width: double.infinity,
        height: effectiveEnd,
        child: DecoratedBox(
          key: const ValueKey<String>('liquid-glass-safe-area-base'),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                for (final opacity in <double>[1.0, ..._fadeOpacities])
                  background.withValues(alpha: opacity),
              ],
              stops: <double>[
                0.0,
                for (final fraction in _fadeStopFractions)
                  (solidStop + remaining * fraction).clamp(0.0, 1.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Scroll-only support for the fixed mobile header.
///
/// The legacy Base/Scrim/Mask stack remains the complete resting appearance.
/// This layer is omitted at p=0, then sits above that stack and below the
/// controls so content that has moved under the header is softened without
/// changing the resting first-card geometry.
class LiquidGlassTopSoftEdge extends StatelessWidget {
  const LiquidGlassTopSoftEdge({
    super.key,
    required this.safeTop,
    required this.layout,
    this.hasCategories = true,
    this.edgeProgress,
    this.barFadeProgress = 0,
  });

  final double safeTop;
  final LiquidGlassTopBarLayout layout;
  final bool hasCategories;
  final ValueListenable<double>? edgeProgress;
  final double barFadeProgress;

  @override
  Widget build(BuildContext context) {
    if (PlatformCapabilities.isDesktop) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: edgeProgress ?? _restingEdge,
      builder: (context, _) => _buildEdge(
        context,
        SoftScrollEdgeEffect.quantizeStrength(edgeProgress?.value ?? 0),
      ),
    );
  }

  Widget _buildEdge(BuildContext context, double progress) {
    if (progress <= 0.0) {
      return const SizedBox.shrink();
    }
    final barBottom = _liquidGlassTopFadeEnd(
      safeTop: safeTop,
      layout: layout,
      hasCategories: hasCategories,
      screenHeight: MediaQuery.sizeOf(context).height,
      textScaler: MediaQuery.textScalerOf(context),
      barFadeProgress: barFadeProgress,
    );
    final inset = math.min(safeTop, barBottom);
    final bars = math.max(0.0, barBottom - inset);
    final tail = LiquidGlassEdgeTokens.softTailFor(context) * progress;
    final surfaceColor = CupertinoDynamicColor.resolve(
      CupertinoTheme.of(context).scaffoldBackgroundColor,
      context,
    );
    return IgnorePointer(
      child: SoftScrollEdgeEffect(
        edge: SoftEdge.top,
        inset: inset,
        bars: bars,
        tail: tail,
        strength: progress,
        surfaceColor: surfaceColor,
        decorationKey: const ValueKey<String>('liquid-glass-top-soft-edge'),
      ),
    );
  }
}

/// The legacy mobile wash or scroll-driven desktop tint below the glass rail.
class LiquidGlassTopScrim extends StatelessWidget {
  const LiquidGlassTopScrim({
    super.key,
    required this.safeTop,
    required this.layout,
    this.hasCategories = true,
    this.edgeProgress,
    this.barFadeProgress = 0,
    this.firstCardRestTop,
  });

  final double safeTop;
  final LiquidGlassTopBarLayout layout;
  final bool hasCategories;
  final ValueListenable<double>? edgeProgress;

  /// The same displayed collapse progress supplied to [LiquidGlassRail].
  final double barFadeProgress;
  final ValueListenable<double?>? firstCardRestTop;

  @override
  Widget build(BuildContext context) {
    if (PlatformCapabilities.hostPlatform == TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: Listenable.merge([
        edgeProgress ?? _restingEdge,
        if (firstCardRestTop != null) firstCardRestTop!,
        if (PlatformCapabilities.isDesktop)
          LiquidGlassAccessibilitySettings.reduceTransparency,
      ]),
      builder: (context, _) => _buildScrim(
        context,
        SoftScrollEdgeEffect.quantizeStrength(edgeProgress?.value ?? 0),
      ),
    );
  }

  Widget _buildScrim(BuildContext context, double progress) {
    final double barBottom = _liquidGlassTopFadeEnd(
      safeTop: safeTop,
      layout: layout,
      hasCategories: hasCategories,
      screenHeight: MediaQuery.sizeOf(context).height,
      textScaler: MediaQuery.textScalerOf(context),
      barFadeProgress: barFadeProgress,
    );
    final double fadeEnd = _liquidGlassTopFadeEnd(
      safeTop: safeTop,
      layout: layout,
      hasCategories: hasCategories,
      screenHeight: MediaQuery.sizeOf(context).height,
      textScaler: MediaQuery.textScalerOf(context),
      barFadeProgress: barFadeProgress,
      tail: LiquidGlassEdgeTokens.tailFor(context) * progress,
    );
    final desktop = PlatformCapabilities.isDesktop;
    final effectiveEnd = !desktop
        ? _flutterFadeEnd(
            context,
            safeTop,
            layout,
            hasCategories,
            progress,
            firstCardRestTop?.value,
          )
        : fadeEnd;
    final bool isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    _logLiquidGlassTopState(
      safeTop: safeTop,
      fadeEnd: effectiveEnd,
      dark: isDark,
    );

    final Color background = CupertinoDynamicColor.resolve(
      CupertinoColors.systemBackground,
      context,
    );
    final end = effectiveEnd;
    final List<double> alphas;
    final List<double> stops;
    if (!desktop) {
      alphas = [
        for (final a in [1.0, .55, .22, 0.0]) a * (isDark ? .37 : .32),
      ];
      stops = [0, .35, .70, 1];
    } else {
      final reduced =
          LiquidGlassAccessibilitySettings.reduceTransparency.value ?? false;
      final curve = SoftEdgeCurve(
        reduced
            ? [1, 1, .96, .40, 0]
            : isDark
            ? [.94, .90, .84, .36, 0]
            : [.92, .88, .80, .32, 0],
        maxSigma: 0,
      );
      alphas = curve
          .sample(
            inset: safeTop,
            bars: math.max(0, barBottom - safeTop),
            tail: end - barBottom,
          )
          .map((a) => a * progress)
          .toList();
      stops = List.generate(alphas.length, (i) => i / (alphas.length - 1));
    }
    return IgnorePointer(
      child: SizedBox(
        width: double.infinity,
        height: end,
        child: DecoratedBox(
          key: const ValueKey<String>('liquid-glass-top-scrim'),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                for (final a in alphas)
                  (desktop
                          ? CupertinoTheme.of(context).scaffoldBackgroundColor
                          : background)
                      .withValues(alpha: a),
              ],
              stops: stops,
            ),
          ),
        ),
      ),
    );
  }
}

/// The page's solid initial-position background.
///
/// The page places this fixed layer above its scroll content and below the
/// fixed top scrim and rail. It begins at the safe-area lower edge, and its
/// lower edge follows the first card until it reaches the category rail's
/// bottom. It is not list spacing and never changes scroll offsets. The top
/// scrim covers the safe area with a continuous gradient, independent of the
/// reveal progress.
class LiquidGlassSolidMask extends StatelessWidget {
  const LiquidGlassSolidMask({
    super.key,
    required this.progressListenable,
    required this.safeTop,
    required this.height,
  });

  final ValueListenable<double> progressListenable;
  final double safeTop;
  final double height;

  /// Fixed upper corner radius of the revealed background. The drawing region
  /// keeps this size at every progress so the painter can never shrink the
  /// radius indirectly; only the opacity follows the reveal. Mobile Flutter
  /// headers retain the full region below the rail for the inverse corners.
  static const double _cornerRadius = 20.0;

  @override
  Widget build(BuildContext context) {
    if (PlatformCapabilities.isDesktop ||
        PlatformCapabilities.hostPlatform == TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: SizedBox(
        height: height + _cornerRadius,
        child: ValueListenableBuilder<double>(
          valueListenable: progressListenable,
          builder: (BuildContext context, double progress, Widget? child) {
            final double reveal = progress.clamp(0.0, 1.0);
            final double safeAreaHeight = safeTop.clamp(0.0, height);
            final double maskHeight =
                (height - safeAreaHeight).clamp(0.0, height) * reveal;
            if (reveal <= 0.0) {
              // Fully retracted: no mask and zero corner opacity, so nothing
              // may leave a white block at the top.
              return const SizedBox.shrink();
            }
            final Color background = CupertinoDynamicColor.resolve(
              CupertinoColors.systemBackground,
              context,
            );
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (maskHeight > 0.0)
                  Positioned(
                    top: safeAreaHeight,
                    left: 0.0,
                    right: 0.0,
                    height: maskHeight,
                    child: ColoredBox(
                      key: const ValueKey<String>('liquid-glass-solid-mask'),
                      color: background,
                    ),
                  ),
                Positioned(
                  top: safeAreaHeight + maskHeight,
                  left: 0.0,
                  right: 0.0,
                  height: _cornerRadius,
                  child: Opacity(
                    opacity: reveal,
                    child: CustomPaint(
                      key: const ValueKey<String>(
                        'liquid-glass-content-corners',
                      ),
                      painter: _ContentCornerPainter(
                        background,
                        radius: _cornerRadius,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Paint only the area outside the content's upper quarter circles.
/// This never changes the viewport or intercepts scroll gestures.
class _ContentCornerPainter extends CustomPainter {
  const _ContentCornerPainter(this.color, {required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    // The radius is explicit; the region size cannot degrade it into a
    // square corner while the corners fade.
    final double r = math.min(radius, size.width / 2);
    if (r <= 0) {
      return;
    }
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(r, 0)
      ..arcToPoint(Offset(0, r), radius: Radius.circular(r), clockwise: false)
      ..close()
      ..moveTo(size.width - r, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, r)
      ..arcToPoint(
        Offset(size.width - r, 0),
        radius: Radius.circular(r),
        clockwise: false,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ContentCornerPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

/// UIKit owns the entire category control, including its labels, so native
/// glass never has to be composited behind sibling Flutter text.
class NativeCategoryRail extends StatefulWidget {
  const NativeCategoryRail({
    super.key,
    required this.categories,
    required this.selectedIndex,
    required this.followSystemTransparency,
    required this.brightness,
    required this.fontSize,
    required this.layout,
    required this.initialOffset,
    required this.onOffset,
    required this.opacity,
    required this.interactive,
    this.pageController,
    this.segmentWidths,
    this.height,
    this.modalFallbackBuilder,
  });

  final List<LiquidGlassRailCategory> categories;
  final int selectedIndex;
  final bool followSystemTransparency;
  final Brightness brightness;
  final double fontSize;
  final LiquidGlassTopBarLayout layout;
  final double initialOffset;
  final ValueChanged<double> onOffset;
  final double opacity;
  final bool interactive;
  final PageController? pageController;

  /// Widths from [SegmentedRailLayout]; UIKit sizes the labels otherwise.
  final List<double>? segmentWidths;

  /// Height of the glass track; defaults to the rail layout's row height.
  final double? height;

  /// Optional translucent Flutter fallback rendered underneath while a modal
  /// covers this route and held until UIKit commits unhide on dismissal.
  final WidgetBuilder? modalFallbackBuilder;

  @override
  State<NativeCategoryRail> createState() => _NativeCategoryRailState();
}

class _NativeCategoryRailState extends State<NativeCategoryRail> {
  static const MethodChannel _cacheChannel = MethodChannel(
    'eros/liquid-glass-cache',
  );
  static int _nextCacheId = 1;

  late final int _cacheId = _nextCacheId++;
  MethodChannel? _channel;
  String? _lastParameters;
  bool _scheduled = false;
  bool _covered = false;
  bool _showUnderlay = false;
  bool _modalInitialized = false;
  int _hiddenSyncSeq = 0;
  final _RailScrubTicker _scrubTicker = _RailScrubTicker();

  @override
  void initState() {
    super.initState();
    widget.pageController?.addListener(_progress);
    AppKitInteraction.modalRevision.addListener(_onModalRevisionChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final covered = _shouldHideForModal(context);
    if (!_modalInitialized) {
      _modalInitialized = true;
      _covered = covered;
      _showUnderlay = covered;
      return;
    }
    _updateCovered(covered);
  }

  bool _shouldHideForModal(BuildContext context) {
    if (widget.modalFallbackBuilder == null ||
        !PlatformCapabilities.uiKitGlass ||
        GlassMode.of(context) == GlassMode.off ||
        GlassMode.of(context).forComponent(flutterImplemented: true) ==
            GlassMode.flutter) {
      return false;
    }
    return AppKitInteraction.isCoveredByModal(context);
  }

  void _onModalRevisionChanged() {
    if (!mounted) {
      return;
    }
    _updateCovered(_shouldHideForModal(context));
  }

  void _updateCovered(bool covered) {
    if (covered == _covered) {
      return;
    }
    ++_hiddenSyncSeq;
    _covered = covered;
    if (covered) {
      _channel?.setMethodCallHandler(null);
      _channel = null;
      setState(() {
        _showUnderlay = true;
      });
    } else {
      // Remount the native rail while keeping the Flutter underlay rendered
      // until the restored platform view commits its first frame.
      setState(() {});
    }
  }

  Future<void> _completeRestore(int seq, MethodChannel channel) async {
    try {
      await channel.invokeMethod<void>('update', _parameters);
    } on MissingPluginException {
      // Tests without a platform view messenger ignore plugin calls.
    }
    if (!mounted || seq != _hiddenSyncSeq || _covered || !_showUnderlay) {
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || seq != _hiddenSyncSeq || _covered || !_showUnderlay) {
        return;
      }
      setState(() {
        _showUnderlay = false;
      });
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _progress() {
    final controller = widget.pageController;
    if (controller == null || !controller.hasClients) {
      return;
    }
    // Only a swipe drives the lens. A selection made by tapping animates it
    // natively, and following the page animation too would move it twice.
    if (controller.position.userScrollDirection == ScrollDirection.idle) {
      _scrubTicker.update(controller);
      return;
    }
    if (_scheduled) {
      return;
    }
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || widget.pageController?.hasClients != true) {
        return;
      }
      final page = widget.pageController!.page;
      if (page == null || !page.isFinite) {
        return;
      }
      _scrubTicker.update(widget.pageController);
      _channel?.invokeMethod<void>('progress', page);
    });
  }

  Map<String, Object> get _parameters => <String, Object>{
    'ids': widget.categories.map((e) => e.id ?? e.title).toList(),
    'selectedId':
        widget.selectedIndex >= 0 &&
            widget.selectedIndex < widget.categories.length
        ? widget.categories[widget.selectedIndex].id ??
              widget.categories[widget.selectedIndex].title
        : '',
    'layout': widget.layout.name,
    'offset': widget.initialOffset,
    'titles': widget.categories.map((item) => item.title).toList(),
    'longPressEnabled': widget.categories
        .map((item) => item.onLongPress != null)
        .toList(),
    'selectedIndex': widget.selectedIndex,
    'followSystemTransparency': widget.followSystemTransparency,
    'dark': widget.brightness == Brightness.dark,
    'fontSize': widget.fontSize,
    'opacity': widget.opacity,
    'interactive': widget.interactive,
    'cacheId': _cacheId,
    if (widget.segmentWidths != null) 'segmentWidths': widget.segmentWidths!,
  };

  void _created(int viewId) {
    final channel = MethodChannel('eros/liquid-glass-categories/$viewId');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (!mounted) {
        return;
      }
      if (call.method == 'offset' && call.arguments is num) {
        widget.onOffset((call.arguments as num).toDouble());
        return;
      }
      if (call.arguments is! String) {
        return;
      }
      final index = widget.categories.indexWhere(
        (e) => (e.id ?? e.title) == call.arguments,
      );
      if (index < 0 || index >= widget.categories.length) {
        return;
      }
      switch (call.method) {
        case 'select':
          liquidGlassFeedback(vibrateUtil.selection);
          widget.categories[index].onTap();
          break;
        case 'longPress':
          liquidGlassFeedback(vibrateUtil.medium);
          widget.categories[index].onLongPress?.call();
          break;
      }
    });
    _lastParameters = jsonEncode(_parameters);
    if (!_covered && _showUnderlay) {
      unawaited(_completeRestore(_hiddenSyncSeq, channel));
    } else {
      unawaited(
        channel
            .invokeMethod<void>('update', _parameters)
            .catchError((Object _) {}),
      );
    }
  }

  @override
  void didUpdateWidget(covariant NativeCategoryRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageController != widget.pageController) {
      oldWidget.pageController?.removeListener(_progress);
      widget.pageController?.addListener(_progress);
    }
    if (oldWidget.modalFallbackBuilder != widget.modalFallbackBuilder) {
      _updateCovered(_shouldHideForModal(context));
    }
    final encoded = jsonEncode(_parameters);
    if (_lastParameters != encoded) {
      _channel?.invokeMethod<void>('update', _parameters);
      _lastParameters = encoded;
    }
  }

  @override
  void dispose() {
    AppKitInteraction.modalRevision.removeListener(_onModalRevisionChanged);
    widget.pageController?.removeListener(_progress);
    _channel?.setMethodCallHandler(null);
    _channel = null;
    unawaited(
      _cacheChannel
          .invokeMethod<void>('release', <String, Object>{
            'kind': 'category',
            'cacheId': _cacheId,
          })
          .catchError((Object _) {}),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (GlassMode.of(context).forComponent(flutterImplemented: true) ==
        GlassMode.flutter) {
      return SegmentedRail(
        interactive: widget.interactive,
        initialOffset: widget.initialOffset,
        onOffset: widget.onOffset,
        items: widget.categories,
        selectedIndex: widget.selectedIndex,
        pageController: widget.pageController,
        opacity: widget.opacity,
        followSystemTransparency: widget.followSystemTransparency,
      );
    }
    if (!PlatformCapabilities.uiKitGlass ||
        GlassMode.of(context) == GlassMode.off) {
      return Wrap(
        children: [
          for (final category in widget.categories)
            CupertinoButton(
              onPressed: widget.interactive ? category.onTap : null,
              child: Text(category.title),
            ),
        ],
      );
    }
    final Widget? nativeRail = _covered
        ? null
        : UiKitView(
            viewType: 'eros/liquid-glass-categories',
            creationParams: _parameters,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _created,
            // Claim horizontal category drags without taking vertical list scrolls.
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
              Factory<HorizontalDragGestureRecognizer>(
                HorizontalDragGestureRecognizer.new,
              ),
            },
          );
    final fallbackBuilder = widget.modalFallbackBuilder;
    final Widget child = fallbackBuilder == null
        ? (nativeRail ?? const SizedBox.shrink())
        : Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (_showUnderlay)
                KeyedSubtree(
                  key: const ValueKey<String>(
                    'native-category-rail-modal-underlay',
                  ),
                  child: fallbackBuilder(context),
                )
              else
                const SizedBox.shrink(),
              if (nativeRail != null) nativeRail,
            ],
          );
    return SizedBox(
      height:
          widget.height ??
          widget.layout.categoryHeight(MediaQuery.textScalerOf(context)),
      child: child,
    );
  }
}

/// Paints a lightweight 0.75pt optical specular rim strictly INSIDE a glass
/// surface (below [GlassContainer]) so it never interrupts [GlassBackdropGroup]
/// sharing, and adapts to both [GlassMaterial.liquid] and [GlassMaterial.frosted].
class _AndroidGlassChromeRim extends StatelessWidget {
  const _AndroidGlassChromeRim({required this.radius, required this.child});

  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final bool highContrast = MediaQuery.highContrastOf(context);
    final bool frosted = !GlassPreference.materialOf(context).isLiquid;
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _SpecularRimPainter(
                radius: radius,
                isDark: isDark,
                frosted: frosted,
                highContrast: highContrast,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpecularRimPainter extends CustomPainter {
  const _SpecularRimPainter({
    required this.radius,
    required this.isDark,
    required this.frosted,
    required this.highContrast,
  });

  final double radius;
  final bool isDark;
  final bool frosted;
  final bool highContrast;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final double r = math.min(radius, math.min(size.width, size.height) / 2);
    final Rect rect = Offset.zero & size;
    final RRect outer = RRect.fromRectAndRadius(rect, Radius.circular(r));

    // In frosted mode, add a delicate top-down optical sheen so frosted pills
    // stay crisp and luminous on light/dark canvases without an extra shader.
    if (frosted && !highContrast) {
      final Paint sheen = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const <Color>[Color(0x14FFFFFF), Color(0x00FFFFFF)]
              : const <Color>[Color(0x28FFFFFF), Color(0x00FFFFFF)],
        ).createShader(rect);
      canvas.drawRRect(outer, sheen);
    }

    final double strokeWidth = highContrast ? 1.0 : 0.75;
    final RRect strokeRect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(math.max(0.0, r - strokeWidth / 2)),
    );
    final Paint rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    if (highContrast) {
      rimPaint.color = isDark
          ? const Color(0x66FFFFFF)
          : const Color(0x4D14161C);
    } else {
      rimPaint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? <Color>[
                Color(frosted ? 0x47FFFFFF : 0x40FFFFFF),
                const Color(0x12FFFFFF),
                const Color(0x08FFFFFF),
              ]
            : <Color>[
                Color(frosted ? 0xE6FFFFFF : 0xCCFFFFFF),
                const Color(0x4DFFFFFF),
                const Color(0x1A14161C),
              ],
        stops: const <double>[0.0, 0.55, 1.0],
      ).createShader(rect);
    }
    canvas.drawRRect(strokeRect, rimPaint);
  }

  @override
  bool shouldRepaint(_SpecularRimPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.isDark != isDark ||
      oldDelegate.frosted != frosted ||
      oldDelegate.highContrast != highContrast;
}

/// Micro-interaction wrapper for Android top-bar controls (KF-D):
/// 90ms scale down to 0.93 with an internal radial specular bloom, springing
/// back cleanly on release. Zero [RenderOpacity] above [GlassContainer].
class _AndroidGlassTapRegion extends StatefulWidget {
  const _AndroidGlassTapRegion({
    required this.enabled,
    required this.borderRadius,
    required this.onTap,
    required this.child,
  });

  final bool enabled;
  final BorderRadius borderRadius;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_AndroidGlassTapRegion> createState() => _AndroidGlassTapRegionState();
}

class _AndroidGlassTapRegionState extends State<_AndroidGlassTapRegion> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: widget.child,
      );
    }
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final bool isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: !reduceMotion && _pressed ? 0.93 : 1.0,
        duration: reduceMotion
            ? Duration.zero
            : _pressed
            ? const Duration(milliseconds: 90)
            : const Duration(milliseconds: 180),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: Stack(
          fit: StackFit.passthrough,
          children: <Widget>[
            widget.child,
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: reduceMotion
                      ? Duration.zero
                      : _pressed
                      ? const Duration(milliseconds: 70)
                      : const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    borderRadius: widget.borderRadius,
                    gradient: _pressed
                        ? RadialGradient(
                            center: const Alignment(0, -0.1),
                            radius: 0.85,
                            colors: <Color>[
                              CupertinoColors.white.withValues(
                                alpha: isDark ? 0.16 : 0.32,
                              ),
                              const Color(0x00FFFFFF),
                            ],
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Android optical category track implementing:
/// - Strict concentric inner selection capsule (`R_inner = height/2 - inset`)
///   with clear light/dark contrast over both Liquid and Frosted glass.
/// - Dynamic 24pt horizontal edge fade mask (mounted ONLY when overflowing,
///   and strictly inside [LiquidGlassSurface] so [GlassBackdropGroup] stays
///   unobstructed).
/// - iOS-inspired KF-C0..C3 lifted optical lens spring glide on category taps
///   and 1:1 flat tracking during PageView swipes.
class _AndroidGlassCategoryTrack extends StatefulWidget {
  const _AndroidGlassCategoryTrack({
    required this.scrollController,
    required this.categories,
    required this.selectedIndex,
    required this.pageController,
    required this.widths,
    required this.positions,
    required this.surfaceWidth,
    required this.contentWidth,
    required this.height,
    required this.inset,
    required this.scrolls,
    required this.fontSize,
    required this.revealRequested,
    required this.restoreOffset,
    required this.onConsumeScrollSync,
  });

  final ScrollController scrollController;
  final List<LiquidGlassRailCategory> categories;
  final int selectedIndex;
  final PageController? pageController;
  final List<double> widths;
  final List<double> positions;
  final double surfaceWidth;
  final double contentWidth;
  final double height;
  final double inset;
  final bool scrolls;
  final double fontSize;
  final bool revealRequested;
  final double? restoreOffset;
  final VoidCallback onConsumeScrollSync;

  @override
  State<_AndroidGlassCategoryTrack> createState() =>
      _AndroidGlassCategoryTrackState();
}

class _AndroidGlassCategoryTrackState extends State<_AndroidGlassCategoryTrack>
    with SingleTickerProviderStateMixin {
  static const double _edgeFadeWidth = 24.0;
  // Matches iOS LiquidGlassCategoryCore spring feel (damping ratio ~0.82).
  static const SpringDescription _lensSpring = SpringDescription(
    mass: 1.0,
    stiffness: 320.0,
    damping: 29.3,
  );

  late final AnimationController _lensController =
      AnimationController.unbounded(vsync: this)
        ..addStatusListener(_handleLensStatus);

  bool _lensAnimating = false;
  double _fromLeft = 0.0;
  double _fromWidth = 0.0;
  double _toLeft = 0.0;
  double _toWidth = 0.0;

  @override
  void initState() {
    super.initState();
    widget.pageController?.addListener(_handlePageScroll);
    _scheduleScrollSync(animate: false);
  }

  @override
  void didUpdateWidget(covariant _AndroidGlassCategoryTrack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageController != widget.pageController) {
      oldWidget.pageController?.removeListener(_handlePageScroll);
      widget.pageController?.addListener(_handlePageScroll);
    }
    final bool indexChanged = oldWidget.selectedIndex != widget.selectedIndex;
    final bool sameCount =
        oldWidget.positions.length == widget.positions.length &&
        widget.positions.isNotEmpty;
    if (indexChanged && sameCount) {
      final int oldIndex = oldWidget.selectedIndex.clamp(
        0,
        oldWidget.positions.length - 1,
      );
      final int newIndex = widget.selectedIndex.clamp(
        0,
        widget.positions.length - 1,
      );
      final bool userSwiping =
          widget.pageController?.hasClients == true &&
          widget.pageController!.position.userScrollDirection !=
              ScrollDirection.idle;
      if (!userSwiping && oldIndex != newIndex) {
        _startLensGlide(
          fromLeft: _lensAnimating
              ? _currentLensLeft()
              : oldWidget.positions[oldIndex],
          fromWidth: _lensAnimating
              ? _currentLensWidth()
              : oldWidget.widths[oldIndex],
          toLeft: widget.positions[newIndex],
          toWidth: widget.widths[newIndex],
        );
      } else {
        _stopLens();
      }
    } else if (!sameCount) {
      _stopLens();
    }
    if (widget.revealRequested || widget.restoreOffset != null) {
      _scheduleScrollSync(animate: indexChanged);
    }
  }

  @override
  void dispose() {
    widget.pageController?.removeListener(_handlePageScroll);
    _lensController.dispose();
    super.dispose();
  }

  void _handlePageScroll() {
    final controller = widget.pageController;
    if (!_lensAnimating || controller == null || !controller.hasClients) {
      return;
    }
    if (controller.position.userScrollDirection != ScrollDirection.idle) {
      _stopLens();
    }
  }

  void _handleLensStatus(AnimationStatus status) {
    if ((status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) &&
        _lensAnimating &&
        mounted) {
      setState(() => _lensAnimating = false);
    }
  }

  void _stopLens() {
    if (!_lensAnimating) {
      return;
    }
    _lensController.stop();
    _lensAnimating = false;
  }

  void _startLensGlide({
    required double fromLeft,
    required double fromWidth,
    required double toLeft,
    required double toWidth,
  }) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _stopLens();
      return;
    }
    _fromLeft = fromLeft;
    _fromWidth = fromWidth;
    _toLeft = toLeft;
    _toWidth = toWidth;
    _lensAnimating = true;
    _lensController.value = 0.0;
    _lensController.animateWith(SpringSimulation(_lensSpring, 0.0, 1.0, 0.0));
  }

  double _currentLensLeft() {
    final t = _lensController.value;
    return _fromLeft + (_toLeft - _fromLeft) * t;
  }

  double _currentLensWidth() {
    final t = _lensController.value;
    return math.max(0.0, _fromWidth + (_toWidth - _fromWidth) * t);
  }

  void _scheduleScrollSync({required bool animate}) {
    if (widget.categories.isEmpty) {
      return;
    }
    final bool reveal = widget.revealRequested;
    final double? restoreOffset = widget.restoreOffset;
    if (!reveal && restoreOffset == null) {
      return;
    }
    widget.onConsumeScrollSync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.scrollController.hasClients) {
        return;
      }
      final scroller = widget.scrollController;
      final maxOffset = scroller.position.maxScrollExtent;
      if (maxOffset <= 0.0) {
        return;
      }
      final int index = widget.selectedIndex.clamp(0, widget.widths.length - 1);
      final double itemLeft = widget.positions[index];
      final double itemRight = itemLeft + widget.widths[index];
      final double offset = scroller.offset;
      final double margin = math.min(_edgeFadeWidth, widget.surfaceWidth / 4);
      final double target;
      if (restoreOffset != null && !reveal) {
        target = restoreOffset.clamp(0.0, maxOffset);
      } else {
        final bool clearLeading = offset <= 0.5 || itemLeft >= offset + margin;
        final bool clearTrailing =
            offset >= maxOffset - 0.5 ||
            itemRight <= offset + widget.surfaceWidth - margin;
        if (clearLeading && clearTrailing) {
          return;
        }
        final double centerTarget =
            itemLeft + widget.widths[index] / 2 - widget.surfaceWidth / 2;
        target = centerTarget.clamp(0.0, maxOffset);
      }
      if (animate && !MediaQuery.disableAnimationsOf(context)) {
        scroller.animateTo(
          target,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      } else {
        scroller.jumpTo(target);
      }
    });
  }

  Widget _buildTrackContents(BuildContext context) {
    final bool isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final bool frosted = !GlassPreference.materialOf(context).isLiquid;
    final double inset = widget.inset;
    final double height = widget.height;
    final double innerHeight = math.max(0.0, height - inset * 2);
    final double innerRadius = math.max(0.0, height / 2 - inset);

    final double page;
    if (widget.pageController?.hasClients == true && !_lensAnimating) {
      page = (widget.pageController!.page ?? widget.selectedIndex.toDouble())
          .clamp(0.0, (widget.categories.length - 1).toDouble());
    } else {
      page = widget.selectedIndex
          .clamp(0, widget.categories.length - 1)
          .toDouble();
    }
    final int lower = page.floor();
    final int upper = page.ceil();
    final double fraction = page - lower;
    final double restingLeft =
        widget.positions[lower] +
        (widget.positions[upper] - widget.positions[lower]) * fraction;
    final double restingWidth =
        widget.widths[lower] +
        (widget.widths[upper] - widget.widths[lower]) * fraction;

    final double t = _lensAnimating
        ? _lensController.value.clamp(0.0, 1.0)
        : 0.0;
    // KF-C1 lift (0 -> 0.22), KF-C2 glide (0.22 -> 0.72), KF-C3 settle (0.72 -> 1.0).
    final double liftStrength;
    if (!_lensAnimating) {
      liftStrength = 0.0;
    } else if (t < 0.22) {
      liftStrength = Curves.easeOut.transform(t / 0.22);
    } else if (t <= 0.72) {
      liftStrength = 1.0;
    } else {
      liftStrength = 1.0 - Curves.easeOutCubic.transform((t - 0.72) / 0.28);
    }

    final double pillLeft = _lensAnimating ? _currentLensLeft() : restingLeft;
    final double pillWidth = _lensAnimating
        ? _currentLensWidth()
        : restingWidth;
    final double expandX = 3.0 * liftStrength;
    final double expandY = math.min(inset, 2.0) * liftStrength;
    final double indicatorLeft = (pillLeft + inset - expandX).clamp(
      0.0,
      math.max(0.0, widget.contentWidth),
    );
    final double indicatorWidth = math.max(
      0.0,
      pillWidth - inset * 2 + expandX * 2,
    );
    final double indicatorTop = math.max(0.0, inset - expandY);
    final double indicatorHeight = math.min(height, innerHeight + expandY * 2);
    final double indicatorRadius = math.max(innerRadius, indicatorHeight / 2);

    final Color restingFillColor = isDark
        ? Color(frosted ? 0x33FFFFFF : 0x2BFFFFFF)
        : Color(frosted ? 0xF5FFFFFF : 0xF0FFFFFF);
    final Color liftedFillColor = isDark
        ? const Color(0x3DFFFFFF)
        : const Color(0x88FFFFFF);
    final Color activeColor =
        Color.lerp(restingFillColor, liftedFillColor, liftStrength) ??
        restingFillColor;

    final Color borderColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.22 + 0.16 * liftStrength)
        : CupertinoColors.white.withValues(alpha: 0.90 + 0.08 * liftStrength);

    return SizedBox(
      width: widget.contentWidth,
      height: height,
      child: Stack(
        children: <Widget>[
          Positioned(
            key: const ValueKey<String>(
              'liquid-glass-category-selection-indicator',
            ),
            left: indicatorLeft,
            top: indicatorTop,
            width: indicatorWidth,
            height: indicatorHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(indicatorRadius),
                border: Border.all(
                  color: borderColor,
                  width: 0.75 + 0.25 * liftStrength,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: isDark
                        ? CupertinoColors.black.withValues(
                            alpha: 0.28 + 0.12 * liftStrength,
                          )
                        : const Color(0xFF0F172A)
                              .withValues(alpha: 0.075 + 0.045 * liftStrength),
                    blurRadius: 5.0 + 6.0 * liftStrength,
                    offset: Offset(0, 1.5 + 1.5 * liftStrength),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: Row(
              children: <Widget>[
                for (var i = 0; i < widget.categories.length; i++)
                  _buildSlot(
                    context,
                    widget.categories[i],
                    i,
                    widget.widths[i],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlot(
    BuildContext context,
    LiquidGlassRailCategory category,
    int index,
    double slotWidth,
  ) {
    final bool selected = index == widget.selectedIndex;
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle.copyWith(
      fontSize: widget.fontSize,
      fontWeight: FontWeight.w500,
      color: CupertinoDynamicColor.resolve(CupertinoColors.label, context),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: category.title,
      child: NavigationHover(
        borderRadius: BorderRadius.circular(widget.height / 2),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            liquidGlassFeedback(vibrateUtil.selection);
            category.onTap();
          },
          onLongPress: category.onLongPress == null
              ? null
              : () {
                  liquidGlassFeedback(vibrateUtil.medium);
                  category.onLongPress!();
                },
          child: SizedBox(
            key: ValueKey<String>('liquid-glass-category-slot-$index'),
            width: slotWidth,
            height: widget.height,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  category.title,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: textStyle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Listenable trackAnimation = Listenable.merge(<Listenable?>[
      _lensController,
      widget.pageController,
    ]);
    final Widget scrollChild = SingleChildScrollView(
      controller: widget.scrollController,
      scrollDirection: Axis.horizontal,
      child: HorizontalMouseWheel(
        controller: widget.scrollController,
        child: AnimatedBuilder(
          animation: trackAnimation,
          builder: (context, _) => _buildTrackContents(context),
        ),
      ),
    );
    if (!widget.scrolls || widget.surfaceWidth <= 0) {
      return scrollChild;
    }
    return AnimatedBuilder(
      animation: widget.scrollController,
      child: scrollChild,
      builder: (context, child) {
        final double overflow = math.max(
          0.0,
          widget.contentWidth - widget.surfaceWidth,
        );
        if (overflow <= 0.5) {
          return child!;
        }
        final double offset = widget.scrollController.hasClients
            ? widget.scrollController.offset.clamp(0.0, overflow)
            : 0.0;
        final double fade = math.min(_edgeFadeWidth, widget.surfaceWidth / 4);
        final double leadingStrength = (offset / fade).clamp(0.0, 1.0);
        final double trailingStrength = ((overflow - offset) / fade).clamp(
          0.0,
          1.0,
        );
        final double stop = (fade / widget.surfaceWidth).clamp(0.0, 0.45);
        return ShaderMask(
          key: const ValueKey<String>('android-glass-category-edge-fade'),
          blendMode: BlendMode.dstIn,
          shaderCallback: (Rect bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: <Color>[
              Color.fromRGBO(0, 0, 0, 1.0 - leadingStrength),
              const Color(0xFF000000),
              const Color(0xFF000000),
              Color.fromRGBO(0, 0, 0, 1.0 - trailingStrength),
            ],
            stops: <double>[0.0, stop, 1.0 - stop, 1.0],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}
