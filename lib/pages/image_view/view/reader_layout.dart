import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/widget/scroll_edge_effect.dart';
import 'package:flutter/cupertino.dart';

import '../common.dart';

class ReaderSpreadPage {
  const ReaderSpreadPage({
    required this.slot,
    required this.aspectRatio,
    required this.child,
  });

  final int slot;
  final double aspectRatio;
  final Widget child;
}

/// Fits each original image independently into its physical book pane. The
/// paper treatment is entirely outside the image, with no color or warp filter.
class ReaderSpreadLayout extends StatelessWidget {
  const ReaderSpreadLayout({
    super.key,
    required this.environment,
    required this.pages,
    this.reverse = false,
  });

  final AdaptiveEnvironmentSnapshot environment;
  final List<ReaderSpreadPage> pages;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) return const SizedBox.shrink();
    final panes = environment.paneRects;
    final book = environment.isBookFolded && panes.length == 2;
    final rects = <Rect>[];
    if (book) {
      for (final page in pages) {
        rects.add(panes[reverse ? 1 - page.slot : page.slot].deflate(8));
      }
    } else {
      final available = environment.contentRect.deflate(4);
      final sum = pages.fold<double>(0, (sum, page) => sum + page.aspectRatio);
      final height = math.min(available.height, available.width / sum);
      var left = available.center.dx - height * sum / 2;
      final ordered = reverse ? pages.reversed.toList() : pages;
      final byPage = <ReaderSpreadPage, Rect>{};
      for (final page in ordered) {
        final width = height * page.aspectRatio;
        byPage[page] = Rect.fromLTWH(
            left, available.center.dy - height / 2, width, height);
        left += width;
      }
      rects.addAll(pages.map((page) => byPage[page]!));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        for (var index = 0; index < pages.length; index++)
          Positioned.fromRect(
            rect: rects[index],
            child: AdaptivePane(
              environment: environment,
              rect: rects[index],
              child: book
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: CupertinoColors.white.withValues(alpha: 0.12),
                          width: 0.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x44000000),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: pages[index].child,
                      ),
                    )
                  : pages[index].child,
            ),
          ),
      ],
    );
  }
}

/// Keeps the reading subtree in the same Stack slot through every pose.
class ReaderSurfaceLayout extends StatefulWidget {
  const ReaderSurfaceLayout({
    super.key,
    required this.environment,
    required this.content,
    required this.topBar,
    required this.bottomBar,
    required this.showBars,
    required this.topBarHeight,
    required this.bottomBarHeight,
    this.preference = ReaderSurfacePreference.automatic,
    this.singlePage = false,
    this.fillScreen = false,
    this.nativeChrome = false,
  });

  final AdaptiveEnvironmentSnapshot environment;
  final Widget content;
  final Widget topBar;
  final Widget bottomBar;
  final bool showBars;
  final double topBarHeight;
  final double bottomBarHeight;
  final ReaderSurfacePreference preference;
  final bool singlePage;

  /// Images ignore the safe area; the bars still avoid it.
  final bool fillScreen;

  /// UIKit draws the navigation bar and toolbar. Content then follows the
  /// stable safe area so it stays put while those bars come and go, and only
  /// [bottomBar] is drawn here, fading over soft edges instead of a slab.
  final bool nativeChrome;

  static const Duration fadeDuration = Duration(milliseconds: 250);
  static const double edgeTail = 40;

  @override
  State<ReaderSurfaceLayout> createState() => _ReaderSurfaceLayoutState();
}

class _ReaderSurfaceLayoutState extends State<ReaderSurfaceLayout> {
  // Native bars change the live insets as soon as they start to hide; the
  // fading controls keep the geometry they were shown with.
  Rect? _shownBottomRect;
  EdgeInsets _shownInsets = EdgeInsets.zero;

  @override
  Widget build(BuildContext context) {
    final environment = widget.environment;
    final hardwareTabletop =
        environment.isTabletop && environment.paneRects.length == 2;
    final tabletop = widget.preference == ReaderSurfacePreference.tabletop ||
        (widget.preference == ReaderSurfacePreference.automatic &&
            hardwareTabletop);
    final stableInsets = widget.nativeChrome
        ? environment.stableSafeArea
        : environment.safeArea;
    final contentEnvironment = widget.fillScreen && !tabletop
        ? environment.copyWithGeometry(
            safeArea: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
          )
        : widget.nativeChrome
            ? environment.copyWithGeometry(
                safeArea: stableInsets,
                viewPadding: stableInsets,
              )
            : environment;
    var contentRect = contentEnvironment.contentRect;
    var controlsRect = environment.contentRect;
    if (tabletop) {
      if (hardwareTabletop) {
        contentRect = environment.paneRects.first;
        controlsRect = environment.paneRects.last;
      } else {
        // This is an explicit manual arrangement, never an inferred hinge.
        final safe = environment.contentRect;
        contentRect = Rect.fromLTRB(
            safe.left, safe.top, safe.right, safe.top + safe.height * 0.6 - 12);
        controlsRect = Rect.fromLTRB(
            safe.left, contentRect.bottom + 24, safe.right, safe.bottom);
      }
    } else if (environment.paneRects.length > 1) {
      controlsRect = environment.paneRects.last;
      if (environment.isBookFolded && widget.singlePage) {
        contentRect = contentEnvironment.paneRects.last;
      }
    }
    final topPreferred = Rect.fromLTWH(controlsRect.left, controlsRect.top,
        controlsRect.width, math.min(controlsRect.height, widget.topBarHeight));
    final topRect = environment.unoccludedControlRect(topPreferred);
    final bottomPreferred = Rect.fromLTRB(
        controlsRect.left,
        tabletop
            ? math.min(controlsRect.bottom, topRect.bottom)
            : math.max(
                controlsRect.top, controlsRect.bottom - widget.bottomBarHeight),
        controlsRect.right,
        controlsRect.bottom);
    var bottomRect = environment.unoccludedControlRect(bottomPreferred);

    Widget local(Rect rect, Widget child) => AdaptivePane(
          environment: environment,
          rect: rect,
          child: child,
        );
    final visible = widget.showBars || tabletop;
    final contentLayer = Positioned.fromRect(
      rect: contentRect,
      child: AdaptivePane(
        environment: contentEnvironment,
        rect: contentRect,
        child: widget.content,
      ),
    );

    if (widget.nativeChrome) {
      var insets = environment.safeArea;
      if (visible || _shownBottomRect == null) {
        _shownBottomRect = bottomRect;
        _shownInsets = insets;
      } else {
        bottomRect = _shownBottomRect!;
        insets = _shownInsets;
      }
      final size = environment.size;
      return ColoredBox(
        color: CupertinoColors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            contentLayer,
            Positioned.fill(
              child: ReaderChromeFade(
                visible: visible,
                child: IgnorePointer(
                  child: Stack(
                    children: [
                      if (!tabletop && insets.top > 0.5)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: SoftScrollEdgeEffect(
                            edge: SoftEdge.top,
                            inset: 0,
                            bars: insets.top,
                            tail: ReaderSurfaceLayout.edgeTail,
                            tone: SoftEdgeTone.media,
                          ),
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: SoftScrollEdgeEffect(
                          edge: SoftEdge.bottom,
                          inset: 0,
                          bars: math.max(0, size.height - bottomRect.top),
                          tail: ReaderSurfaceLayout.edgeTail,
                          tone: SoftEdgeTone.media,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: bottomRect,
              child: ReaderChromeFade(
                visible: visible,
                slide: const Offset(0, 0.15),
                child: local(
                  bottomRect,
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SingleChildScrollView(child: widget.bottomBar),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ColoredBox(
      color: CupertinoColors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          contentLayer,
          Positioned.fill(
            child: Offstage(
              offstage: !visible,
              child: IgnorePointer(
                child: ReaderChromeBackground(
                  controlRects: [topRect, bottomRect],
                  safeArea: widget.fillScreen && !tabletop
                      ? environment.safeArea
                      : EdgeInsets.zero,
                ),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: topRect,
            child: Offstage(
              offstage: !visible,
              child: ExcludeFocus(
                excluding: !visible,
                child: local(
                  topRect,
                  widget.topBar,
                ),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: bottomRect,
            child: Offstage(
              offstage: !visible,
              child: ExcludeFocus(
                excluding: !visible,
                child: local(
                  bottomRect,
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SingleChildScrollView(child: widget.bottomBar),
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

/// Fades reader controls in and out with the system bars. Hidden controls
/// leave the tree once the fade ends, so they neither take focus nor keep
/// semantics, and nothing composites behind full-screen media.
class ReaderChromeFade extends StatefulWidget {
  const ReaderChromeFade({
    super.key,
    required this.visible,
    required this.child,
    this.slide = Offset.zero,
  });

  final bool visible;
  final Widget child;

  /// Offset, as a fraction of the child's size, while hidden.
  final Offset slide;

  @override
  State<ReaderChromeFade> createState() => _ReaderChromeFadeState();
}

class _ReaderChromeFadeState extends State<ReaderChromeFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ReaderSurfaceLayout.fadeDuration,
    value: widget.visible ? 1 : 0,
  )..addStatusListener((_) => setState(() {}));

  @override
  void didUpdateWidget(ReaderChromeFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible == widget.visible) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = widget.visible ? 1 : 0;
    } else if (widget.visible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isDismissed) return const SizedBox.shrink();
    final curve =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    Widget child = ExcludeSemantics(
      excluding: !widget.visible,
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: ExcludeFocus(excluding: !widget.visible, child: widget.child),
      ),
    );
    if (widget.slide != Offset.zero && !reduceMotion) {
      child = SlideTransition(
        position: Tween<Offset>(begin: widget.slide, end: Offset.zero)
            .animate(curve),
        child: child,
      );
    }
    return FadeTransition(opacity: curve, child: child);
  }
}

/// A single material for the controls and exposed safe-area edges. Painting
/// their union once avoids dark seams where a bar meets the side or bottom.
/// Only the material bleeds; controls retain their unoccluded safe rectangles.
class ReaderChromeBackground extends StatelessWidget {
  const ReaderChromeBackground({
    super.key,
    required this.controlRects,
    required this.safeArea,
  });

  final List<Rect> controlRects;
  final EdgeInsets safeArea;

  @override
  Widget build(BuildContext context) => ClipPath(
        clipper: _ReaderChromeClipper(controlRects, safeArea),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: const ColoredBox(color: Color(0x80000000)),
        ),
      );
}

class _ReaderChromeClipper extends CustomClipper<Path> {
  const _ReaderChromeClipper(this.controlRects, this.safeArea);

  final List<Rect> controlRects;
  final EdgeInsets safeArea;

  @override
  Path getClip(Size size) {
    final bounds = Offset.zero & size;
    final rects = [
      ...controlRects,
      Rect.fromLTWH(0, 0, safeArea.left, size.height),
      Rect.fromLTWH(
          size.width - safeArea.right, 0, safeArea.right, size.height),
      Rect.fromLTWH(0, 0, size.width, safeArea.top),
      Rect.fromLTWH(
          0, size.height - safeArea.bottom, size.width, safeArea.bottom),
    ];
    final path = Path();
    for (final rect in rects) {
      final clipped = rect.intersect(bounds);
      if (!clipped.isEmpty) {
        path.addRect(clipped);
      }
    }
    return path;
  }

  @override
  bool shouldReclip(_ReaderChromeClipper oldClipper) =>
      oldClipper.safeArea != safeArea ||
      oldClipper.controlRects.length != controlRects.length ||
      Iterable<int>.generate(controlRects.length)
          .any((i) => oldClipper.controlRects[i] != controlRects[i]);
}
