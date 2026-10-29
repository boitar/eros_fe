import 'dart:math' as math;

import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// Segment widths of a rail. Segments are equal when they fit, short ones are
/// raised to a common width when a long label needs more room, and the rail
/// scrolls with a uniform minimum once the labels no longer fit at all.
@immutable
class SegmentedRailLayout {
  const SegmentedRailLayout._(this.widths, this.trackWidth, this.scrolls);

  factory SegmentedRailLayout.compute(
    List<double> labelWidths,
    double available, {
    bool compact = false,
  }) {
    if (labelWidths.isEmpty || available <= 0) {
      return SegmentedRailLayout._(
          const <double>[], math.max(0, available), false);
    }
    final natural = <double>[
      for (final width in labelWidths) width + labelPadding * 2,
    ];
    final count = natural.length;
    final widest = natural.reduce(math.max);
    if (compact) {
      final segment =
          math.max(widest, math.min(compactMaxSegment, available / count));
      if (segment * count <= available) {
        return SegmentedRailLayout._(
            List<double>.filled(count, segment), segment * count, false);
      }
    }
    if (widest * count <= available) {
      return SegmentedRailLayout._(
          List<double>.filled(count, available / count), available, false);
    }
    final total = natural.fold<double>(0, (sum, width) => sum + width);
    if (total <= available) {
      // Water-fill: raise every narrower segment to one level so the track is
      // filled without gaps and long labels keep their natural width.
      final sorted = [...natural]..sort();
      var kept = 0.0;
      var level = sorted.first;
      // Raise the k narrowest segments; the wider ones keep their width.
      for (var k = count; k >= 1; k--) {
        final candidate = (available - kept) / k;
        if (candidate >= sorted[k - 1]) {
          level = candidate;
          break;
        }
        kept += sorted[k - 1];
      }
      return SegmentedRailLayout._(
        <double>[for (final width in natural) math.max(width, level)],
        available,
        false,
      );
    }
    return SegmentedRailLayout._(
      <double>[
        for (final width in natural) math.max(width, minScrollingSegment),
      ],
      available,
      true,
    );
  }

  /// Space between a label and the edges of its segment.
  static const double labelPadding = 12;
  static const double minScrollingSegment = 64;

  /// Upper bound of a compact segment, so two choices do not stretch across
  /// a wide screen.
  static const double compactMaxSegment = 144;

  final List<double> widths;

  /// Width of the visible track; the content may be wider when [scrolls].
  final double trackWidth;
  final bool scrolls;

  double get contentWidth => widths.fold<double>(0, (sum, w) => sum + w);

  double offsetOf(int index) {
    var offset = 0.0;
    for (var i = 0; i < index && i < widths.length; i++) {
      offset += widths[i];
    }
    return offset;
  }

  /// Measures labels the way the rail draws its selected segment.
  static List<double> measure(
    BuildContext context,
    List<String> titles, {
    double fontSize = 15,
  }) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return <double>[
      for (final title in titles)
        (TextPainter(
          text: TextSpan(
            text: title,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
          ),
          textScaler: scaler,
          textDirection: direction,
          maxLines: 1,
        )..layout())
            .width
            .ceilToDouble(),
    ];
  }
}

/// The category control shared by the gallery, favorites, ranking and
/// download tabs: a glass track with a sliding selection lens, optionally
/// followed by one accessory button.
class SegmentedRail extends StatefulWidget {
  const SegmentedRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    this.pageController,
    this.accessory,
    this.compact = false,
    this.followSystemTransparency = true,
    this.opacity = 1,
  });

  static const double margin = 16;
  static const double accessorySize = 36;

  final List<LiquidGlassRailCategory> items;
  final int selectedIndex;

  /// The lens follows this page view while it is swiped.
  final PageController? pageController;
  final LiquidGlassRailAction? accessory;

  /// Centres a short track instead of stretching it across the row.
  final bool compact;
  final bool followSystemTransparency;
  final double opacity;

  static double trackHeightFor(TextScaler scaler) =>
      math.max(36.0, scaler.scale(15) * 1.2 + 14);

  @override
  State<SegmentedRail> createState() => _SegmentedRailState();
}

class _SegmentedRailState extends State<SegmentedRail> {
  final ScrollController _scroll = ScrollController();
  double _nativeOffset = 0;
  bool _reveal = true;

  @override
  void didUpdateWidget(covariant SegmentedRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        !listEquals(_ids(oldWidget.items), _ids(widget.items))) {
      _reveal = true;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  static List<String> _ids(List<LiquidGlassRailCategory> items) =>
      <String>[for (final item in items) item.id ?? item.title];

  @override
  Widget build(BuildContext context) {
    final trackHeight =
        SegmentedRail.trackHeightFor(MediaQuery.textScalerOf(context));
    final accessory = widget.accessory;
    return Opacity(
      opacity: widget.opacity,
      child: IgnorePointer(
        ignoring: widget.opacity < 0.5,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: SegmentedRail.margin),
          child: Row(
            children: <Widget>[
              Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                  final layout = SegmentedRailLayout.compute(
                    SegmentedRailLayout.measure(context,
                        <String>[for (final item in widget.items) item.title]),
                    constraints.maxWidth,
                    compact: widget.compact,
                  );
                  return Align(
                    alignment: widget.compact
                        ? Alignment.center
                        : AlignmentDirectional.centerStart,
                    child: SizedBox(
                      width: layout.trackWidth,
                      height: trackHeight,
                      child: LiquidGlassPlatform.isSupported
                          ? NativeCategoryRail(
                              categories: widget.items,
                              selectedIndex: widget.selectedIndex,
                              followSystemTransparency:
                                  widget.followSystemTransparency,
                              brightness: CupertinoTheme.brightnessOf(context),
                              fontSize: MediaQuery.textScalerOf(context)
                                  .scale(15),
                              layout: LiquidGlassTopBarLayout.inline,
                              initialOffset: _nativeOffset,
                              onOffset: (value) => _nativeOffset = value,
                              opacity: 1,
                              interactive: widget.opacity >= 0.5,
                              pageController: widget.pageController,
                              segmentWidths: layout.widths,
                              height: trackHeight,
                            )
                          : _fallbackTrack(context, layout, trackHeight),
                    ),
                  );
                }),
              ),
              if (accessory != null) ...<Widget>[
                const SizedBox(width: 8),
                _accessoryButton(context, accessory),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _accessoryButton(BuildContext context, LiquidGlassRailAction action) {
    return Semantics(
      button: true,
      label: action.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          liquidGlassFeedback(vibrateUtil.light);
          action.onPressed();
        },
        // The visible glass is smaller than the 44pt target around it.
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: SizedBox.square(
              dimension: SegmentedRail.accessorySize,
              child: LiquidGlassSurface(
                enabled: true,
                borderRadius:
                    BorderRadius.circular(SegmentedRail.accessorySize / 2),
                followSystemTransparency: widget.followSystemTransparency,
                child: Center(
                  child: Icon(
                    action.icon,
                    size: 20,
                    color: CupertinoDynamicColor.resolve(
                        action.color ?? CupertinoColors.label, context),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Flutter-drawn track for platforms without the native category view.
  Widget _fallbackTrack(
      BuildContext context, SegmentedRailLayout layout, double height) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();
    if (_reveal) {
      _reveal = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        final index = widget.selectedIndex.clamp(0, items.length - 1);
        final left = layout.offsetOf(index);
        final right = left + layout.widths[index];
        final offset = _scroll.offset;
        final target = left < offset
            ? left
            : right > offset + layout.trackWidth
                ? right - layout.trackWidth
                : offset;
        _scroll.jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
      });
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    Widget contents() {
      final controller = widget.pageController;
      final progress = controller != null &&
              controller.hasClients &&
              controller.positions.length == 1
          ? controller.page ?? widget.selectedIndex.toDouble()
          : widget.selectedIndex.toDouble();
      final page = progress.clamp(0.0, (items.length - 1).toDouble());
      final lower = page.floor();
      final upper = page.ceil();
      final t = page - lower;
      final left = layout.offsetOf(lower) +
          (layout.offsetOf(upper) - layout.offsetOf(lower)) * t;
      final width = layout.widths[lower] +
          (layout.widths[upper] - layout.widths[lower]) * t;
      const inset = 3.0;
      return SizedBox(
        width: math.max(layout.contentWidth, layout.trackWidth),
        height: height,
        child: Stack(
          children: <Widget>[
            AnimatedPositioned(
              key: const ValueKey<String>('segmented-rail-lens'),
              duration: controller == null && !reduceMotion
                  ? const Duration(milliseconds: 300)
                  : Duration.zero,
              curve: Curves.easeOutCubic,
              left: left + inset,
              top: inset,
              width: math.max(0, width - inset * 2),
              height: height - inset * 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: CupertinoDynamicColor.resolve(
                      CupertinoColors.systemBackground, context),
                  borderRadius: BorderRadius.circular(height / 2 - inset),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(color: Color(0x1F000000), blurRadius: 6),
                  ],
                ),
              ),
            ),
            Row(
              children: <Widget>[
                for (var i = 0; i < items.length; i++)
                  _fallbackSegment(context, items[i], i, layout.widths[i],
                      height),
              ],
            ),
          ],
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoDynamicColor.resolve(
            CupertinoColors.tertiarySystemFill, context),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          physics: layout.scrolls
              ? null
              : const NeverScrollableScrollPhysics(),
          child: widget.pageController == null
              ? contents()
              : AnimatedBuilder(
                  animation: widget.pageController!,
                  builder: (_, __) => contents(),
                ),
        ),
      ),
    );
  }

  Widget _fallbackSegment(BuildContext context, LiquidGlassRailCategory item,
      int index, double width, double height) {
    final selected = index == widget.selectedIndex;
    void tap() {
      liquidGlassFeedback(vibrateUtil.selection);
      item.onTap();
    }

    final longPress = item.onLongPress == null
        ? null
        : () {
            liquidGlassFeedback(vibrateUtil.medium);
            item.onLongPress!();
          };
    return Semantics(
      button: true,
      selected: selected,
      label: item.title,
      onTap: tap,
      onLongPress: longPress,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        onLongPress: longPress,
        child: SizedBox(
          key: ValueKey<String>('segmented-rail-segment-$index'),
          width: width,
          height: height,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      fontSize: 15,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                      color: CupertinoDynamicColor.resolve(
                          selected
                              ? CupertinoColors.label
                              : CupertinoColors.secondaryLabel,
                          context),
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
