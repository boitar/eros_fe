import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:eros_fe/widget/segmented_rail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  });

  static const double controlSize = 44.0;
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
    final bool userDriven = position.isScrollingNotifier.value &&
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

  @override
  Widget build(BuildContext context) {
    final progress = widget.fadeProgress.clamp(0.0, 1.0).toDouble();
    final fadeOpacity = (1.0 - progress).clamp(0.0, 1.0).toDouble();
    final fullyHidden = fadeOpacity == 0.0;

    final shownCategories = widget.categories;
    final twoRow = widget.layout == LiquidGlassTopBarLayout.twoRow;
    final categoryHeight = widget.layout.categoryHeight(
      MediaQuery.textScalerOf(context),
    );
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
    final categoryLeftInset =
        widget.compactCategories ? math.max(leftInset, rightInset) : leftInset;
    final categoryRightInset =
        widget.compactCategories ? math.max(leftInset, rightInset) : rightInset;

    Widget railContent = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (widget.leading != null)
          Positioned(
            left: 8.0,
            top: widget.safeTop,
            width: LiquidGlassRail.controlSize,
            height: LiquidGlassRail.controlSize,
            child: _actionButton(widget.leading!, opacity: fadeOpacity),
          ),
        if (shownCategories.isNotEmpty)
          Positioned(
            left: twoRow ? 8 : categoryLeftInset,
            right: twoRow ? 8 : categoryRightInset,
            top: widget.safeTop + (twoRow ? 50 : 0),
            height: categoryHeight,
            child: _categorySurface(
              context,
              shownCategories,
              opacity: fadeOpacity,
            ),
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
                    _actionButton(rightActions[index], opacity: fadeOpacity)
                  else ...<Widget>[
                    const SizedBox(width: 4.0),
                    _actionButton(rightActions[index], opacity: fadeOpacity),
                  ],
              ],
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
      height: widget.safeTop +
          widget.layout.expandedHeight(
            MediaQuery.textScalerOf(context),
            hasCategories: widget.categories.isNotEmpty,
          ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[railContent],
      ),
    );
  }

  Widget _categorySurface(
    BuildContext context,
    List<LiquidGlassRailCategory> categories, {
    required double opacity,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = SegmentedRailLayout.compute(
          SegmentedRailLayout.measure(
              context, categories.map((category) => category.title).toList()),
          constraints.maxWidth,
          compact: widget.compactCategories,
        );
        final widths = layout.widths;
        final surfaceWidth = layout.trackWidth;
        Widget fitSurface(Widget child) => widget.compactCategories
            ? Align(child: SizedBox(width: surfaceWidth, child: child))
            : child;
        if (LiquidGlassPlatform.isSupported) {
          return fitSurface(NativeCategoryRail(
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
          ));
        }
        final height = constraints.maxHeight;
        final fits = !layout.scrolls;
        final positions = <double>[
          for (var index = 0; index < widths.length; index++)
            layout.offsetOf(index),
        ];
        final contentWidth = fits ? surfaceWidth : layout.contentWidth;
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
          final left = positions[lower] +
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
                  left: left + 4,
                  top: 4,
                  width: width - 8,
                  height: height - 8,
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
              child: widget.pageController == null
                  ? contents()
                  : AnimatedBuilder(
                      animation: widget.pageController!,
                      builder: (_, __) => contents(),
                    ),
            ),
          ),
        );
        return fitSurface(Opacity(opacity: opacity, child: categorySurface));
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
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          fontSize: 15.0,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected
              ? CupertinoDynamicColor.resolve(
                  CupertinoColors.activeBlue, context)
              : CupertinoDynamicColor.resolve(CupertinoColors.label, context),
        );
    return Semantics(
      button: true,
      selected: selected,
      label: category.title,
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
    );
  }

  Widget _actionButton(
    LiquidGlassRailAction action, {
    required double opacity,
  }) {
    final color = CupertinoDynamicColor.resolve(
      action.color ?? CupertinoColors.label,
      context,
    );
    return Opacity(
      opacity: opacity,
      child: SizedBox(
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
              onTap: () {
                liquidGlassFeedback(vibrateUtil.light);
                action.onPressed();
              },
              child: Center(child: Icon(action.icon, size: 25, color: color)),
            ),
          ),
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
const bool kLiquidGlassTopDiagnostics =
    bool.fromEnvironment('LIQUID_GLASS_TOP_DIAGNOSTICS');

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
    LiquidGlassAccessibilitySettings.reduceTransparency
        .addListener(_emitLiquidGlassTopDiag);
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

/// The shared fade-out end for the fixed top-area base and scrim: the larger
/// of the expanded rail's lower edge and 17% of the screen height, clamped to
/// the screen so neither layer becomes a full-screen veil.
const double _topFadeEndScreenHeightFraction = 0.17;

double _liquidGlassTopFadeEnd({
  required double safeTop,
  required LiquidGlassTopBarLayout layout,
  required bool hasCategories,
  required double screenHeight,
  required TextScaler textScaler,
}) {
  final double activeRailBottom =
      safeTop + layout.expandedHeight(textScaler, hasCategories: hasCategories);
  return math
      .min(
        screenHeight,
        math.max(
          activeRailBottom,
          screenHeight * _topFadeEndScreenHeightFraction,
        ),
      )
      .toDouble();
}

/// The themed base layer that sits below the scroll content across the whole
/// top fade region.
///
/// Pages place this layer below their scroll content so the top shows the
/// current theme background where no card is drawn, instead of the
/// transparent scaffold's underlying gray: solid from the top of the screen
/// through the safe area, then fading out continuously toward the shared top
/// fade end. The previous hard edge at the safe-area lower seam is gone, so
/// the gap background between scrolling cards recedes smoothly. Cards
/// scrolling into the safe area are painted above it and stay visible through
/// the top scrim.
class LiquidGlassSafeAreaBase extends StatelessWidget {
  const LiquidGlassSafeAreaBase({
    super.key,
    required this.safeTop,
    required this.layout,
    this.hasCategories = true,
  });

  final double safeTop;
  final LiquidGlassTopBarLayout layout;
  final bool hasCategories;

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
    if (safeTop <= 0.0) {
      return const SizedBox.shrink();
    }
    final double fadeEnd = _liquidGlassTopFadeEnd(
      safeTop: safeTop,
      layout: layout,
      hasCategories: hasCategories,
      screenHeight: MediaQuery.sizeOf(context).height,
      textScaler: MediaQuery.textScalerOf(context),
    );
    final Color background = CupertinoDynamicColor.resolve(
      CupertinoColors.systemBackground,
      context,
    );
    // Solid from the top of the screen through the safe area, then the fade
    // sequence across the remaining distance to the fade end.
    final double solidStop = (safeTop / fadeEnd).clamp(0.0, 1.0);
    final double remaining = 1.0 - solidStop;
    return IgnorePointer(
      child: SizedBox(
        width: double.infinity,
        height: fadeEnd,
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

/// The fixed top-area background that stays behind the glass rail.
///
/// One persistent layer sits above the scroll content and below the rail for
/// the whole time Liquid Glass is on: a fixed four-stop gradient of the theme
/// background color, drawn continuously from the top of the screen through the
/// safe area and rail. The layer never reacts to scroll position, mask
/// progress, control visibility or native accessibility callbacks, and it
/// composites no blur. The solid background shown at the page's initial
/// position is the separate page-level solid mask driven by the top state
/// coordinator.
class LiquidGlassTopScrim extends StatelessWidget {
  const LiquidGlassTopScrim({
    super.key,
    required this.safeTop,
    required this.layout,
    this.hasCategories = true,
  });

  final double safeTop;
  final LiquidGlassTopBarLayout layout;
  final bool hasCategories;

  /// The four opacity multipliers applied to the mode-specific top opacity.
  static const List<double> _gradientOpacities = <double>[
    1.0,
    0.55,
    0.22,
    0.0,
  ];
  static const List<double> _gradientStops = <double>[0.0, 0.35, 0.70, 1.0];
  static const double _lightTopOpacity = 0.32;
  static const double _darkTopOpacity = 0.37;

  @override
  Widget build(BuildContext context) {
    // The gradient keeps the previous top coverage: the larger of the
    // expanded rail's lower edge and 17% of the screen height, never a
    // full-screen veil. The fading base layer below the content ends at the
    // same height so the two layers recede together.
    final double fadeEnd = _liquidGlassTopFadeEnd(
      safeTop: safeTop,
      layout: layout,
      hasCategories: hasCategories,
      screenHeight: MediaQuery.sizeOf(context).height,
      textScaler: MediaQuery.textScalerOf(context),
    );
    final bool isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    _logLiquidGlassTopState(
      safeTop: safeTop,
      fadeEnd: fadeEnd,
      dark: isDark,
    );

    final Color background = CupertinoDynamicColor.resolve(
      CupertinoColors.systemBackground,
      context,
    );
    final double topOpacity = isDark ? _darkTopOpacity : _lightTopOpacity;
    return IgnorePointer(
      child: SizedBox(
        width: double.infinity,
        height: fadeEnd,
        child: DecoratedBox(
          key: const ValueKey<String>('liquid-glass-top-scrim'),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                for (final opacity in _gradientOpacities)
                  background.withValues(alpha: topOpacity * opacity),
              ],
              stops: _gradientStops,
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
  /// radius indirectly; only the opacity follows the reveal.
  static const double _cornerRadius = 20.0;

  @override
  Widget build(BuildContext context) {
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
                          'liquid-glass-content-corners'),
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
      ..arcToPoint(Offset(size.width - r, 0),
          radius: Radius.circular(r), clockwise: false)
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

  @override
  State<NativeCategoryRail> createState() => _NativeCategoryRailState();
}

class _NativeCategoryRailState extends State<NativeCategoryRail> {
  MethodChannel? _channel;
  String? _lastParameters;
  bool _scheduled = false;
  final _RailScrubTicker _scrubTicker = _RailScrubTicker();

  @override
  void initState() {
    super.initState();
    widget.pageController?.addListener(_progress);
  }

  void _progress() {
    if (_scheduled) {
      return;
    }
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || widget.pageController?.hasClients != true) {
        return;
      }
      _scrubTicker.update(widget.pageController);
      _channel?.invokeMethod<void>('progress', widget.pageController!.page);
    });
  }

  Map<String, Object> get _parameters => <String, Object>{
        'ids': widget.categories.map((e) => e.id ?? e.title).toList(),
        'selectedId': widget.selectedIndex >= 0 &&
                widget.selectedIndex < widget.categories.length
            ? widget.categories[widget.selectedIndex].id ??
                widget.categories[widget.selectedIndex].title
            : '',
        'layout': widget.layout.name,
        'offset': widget.initialOffset,
        'titles': widget.categories.map((item) => item.title).toList(),
        'longPressEnabled':
            widget.categories.map((item) => item.onLongPress != null).toList(),
        'selectedIndex': widget.selectedIndex,
        'followSystemTransparency': widget.followSystemTransparency,
        'dark': widget.brightness == Brightness.dark,
        'fontSize': widget.fontSize,
        'opacity': widget.opacity,
        'interactive': widget.interactive,
        if (widget.segmentWidths != null)
          'segmentWidths': widget.segmentWidths!,
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
    channel.invokeMethod<void>('update', _parameters);
  }

  @override
  void didUpdateWidget(covariant NativeCategoryRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageController != widget.pageController) {
      oldWidget.pageController?.removeListener(_progress);
      widget.pageController?.addListener(_progress);
    }
    if (_lastParameters != jsonEncode(_parameters)) {
      _channel?.invokeMethod<void>('update', _parameters);
      _lastParameters = jsonEncode(_parameters);
    }
  }

  @override
  void dispose() {
    widget.pageController?.removeListener(_progress);
    _channel?.setMethodCallHandler(null);
    _channel = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height ??
          widget.layout.categoryHeight(MediaQuery.textScalerOf(context)),
      child: UiKitView(
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
      ),
    );
  }
}
