import 'dart:async';
import 'dart:math' as math;

import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Updates offsets before the new sliver geometry is laid out. This also works
/// with ExtendedNestedScrollView, which attaches its own ScrollPosition to the
/// supplied parent controller rather than calling createScrollPosition on it.
class LiquidGlassScrollController extends ScrollController {
  double _headerExtent = 0;
  double get headerExtent => _headerExtent;

  set headerExtent(double value) {
    final previous = _headerExtent;
    _headerExtent = value;
    if (previous <= 0 || value <= 0 || previous == value) {
      return;
    }
    for (final position in positions) {
      if (!position.hasPixels) {
        continue;
      }
      final pixels = position.pixels;
      position.correctPixels(pixels <= previous
          ? pixels / previous * value
          : pixels + value - previous);
    }
  }
}

/// Tracks the page's true initial position independently from top-rail motion.
/// For an ExtendedNestedScrollView, [additionalPositions] supplies the active
/// inner position(s) as well as the outer controller positions.
class LiquidGlassInitialContentAnchor extends ValueNotifier<bool> {
  LiquidGlassInitialContentAnchor({
    required ScrollController scrollController,
    required double devicePixelRatio,
    Iterable<ScrollPosition> Function()? additionalPositions,
  })  : _scrollController = scrollController,
        _devicePixelRatio = devicePixelRatio,
        _additionalPositions = additionalPositions,
        super(true);

  /// Distance in logical points the content may drift from the initial
  /// position before it stops counting as "at the anchor".
  static double entryThresholdFor(double devicePixelRatio) =>
      math.max(1.5, 2.0 / math.max(1.0, devicePixelRatio));

  /// A wider band keeps the anchor sticky on the way back so sub-threshold
  /// settle jitter near the top does not flip the solid background.
  static double exitThresholdFor(double devicePixelRatio) =>
      math.max(6.0, 4.0 * entryThresholdFor(devicePixelRatio));

  final ScrollController _scrollController;
  final Iterable<ScrollPosition> Function()? _additionalPositions;
  double _devicePixelRatio;
  double _distanceFromAnchor = 0.0;

  bool get isAtInitialPosition => value;

  /// Logical distance from the initial position: the largest non-negative
  /// offset among the outer and active inner positions. Nested scrolling never
  /// sums the two distances.
  double get distanceFromAnchor => _distanceFromAnchor;

  void updateLayout({required double devicePixelRatio}) {
    _devicePixelRatio = devicePixelRatio;
  }

  /// Re-evaluates every position that defines the page anchor. While at the
  /// anchor it uses a wider exit band than the entry band to absorb iOS bounce.
  /// A negative (top-edge) bounce keeps the current anchor state.
  void refresh() {
    if (!_scrollController.hasClients) {
      return;
    }

    final positions = <ScrollPosition>[
      ..._scrollController.positions,
      ...?_additionalPositions?.call(),
    ].where((position) => position.hasPixels).toList(growable: false);
    if (positions.isEmpty) {
      return;
    }

    var distanceFromAnchor = 0.0;
    var hasTopBounce = false;
    for (final position in positions) {
      final delta = position.pixels - position.minScrollExtent;
      if (delta < 0.0) {
        // Negative pixels are top-edge bounce; they never move the page away
        // from the anchor and must not flip the tracked state.
        hasTopBounce = true;
        continue;
      }
      distanceFromAnchor = math.max(distanceFromAnchor, delta);
    }
    _distanceFromAnchor = distanceFromAnchor;

    if (hasTopBounce) {
      return;
    }
    final threshold = value
        ? exitThresholdFor(_devicePixelRatio)
        : entryThresholdFor(_devicePixelRatio);
    final next = distanceFromAnchor <= threshold;
    if (next != value) {
      value = next;
    }
  }

  /// Scrolls the outer/nested coordinator to its initial logical position.
  /// With ExtendedNestedScrollView this also returns its active inner position
  /// to the beginning while restoring the expanded header spacer.
  Future<void> animateToInitialAnchor({
    Duration duration = const Duration(milliseconds: 500),
  }) async {
    if (!_scrollController.hasClients) {
      return;
    }
    final target = _scrollController.position.minScrollExtent;
    await _scrollController.animateTo(
      target,
      duration: duration,
      curve: Curves.ease,
    );
    refresh();
  }
}

/// Page-level coordinator for every top-area visual state.
///
/// The coordinator is the single consumer of page scroll notifications: it
/// derives anchor distance and top-bar fade from outer/active-inner positions,
/// and derives mask reveal from the active first card's screen position. Pages
/// only read the exposed listenables; they do not recompute those states, and
/// the top-bar fade, anchor, and mask do not process scroll notifications
/// independently.
class LiquidGlassTopStateCoordinator {
  LiquidGlassTopStateCoordinator({
    required ScrollController scrollController,
    Iterable<ScrollPosition> Function()? additionalPositions,
    double? Function()? firstCardTopProvider,
    double devicePixelRatio = 1.0,
  })  : _anchor = LiquidGlassInitialContentAnchor(
          scrollController: scrollController,
          devicePixelRatio: devicePixelRatio,
          additionalPositions: additionalPositions,
        ),
        _firstCardTopProvider = firstCardTopProvider,
        barFadeProgress = ValueNotifier<double>(0.0),
        solidMaskProgress = ValueNotifier<double>(1.0);

  /// Effective content travel needed to fully hide or reveal the top rail.
  static const double barFadeRange = 48.0;

  /// Reverse travel a gesture must spend before the direction-driven fade
  /// turns around, so short counter-jitters cannot flash the rail back in.
  static const double reverseDebounceDistance = 8.0;

  final LiquidGlassInitialContentAnchor _anchor;
  final double? Function()? _firstCardTopProvider;

  /// Final top-rail fade the controls display. It is derived once per refresh
  /// from the direction-driven fade below and the solid mask coverage, and the
  /// same value reaches the side buttons and the native category rail.
  final ValueNotifier<double> barFadeProgress;

  /// Reveal progress for the solid mask below the safe area. The mask bottom
  /// tracks the first gallery card's actual screen y-coordinate, independently
  /// from the logical initial-anchor state.
  final ValueNotifier<double> solidMaskProgress;

  LiquidGlassBarMotion? _barMotion;
  bool _barFadeEnabled = false;
  double _topBarExpandedExtent = 0.0;
  double _safeTop = 0.0;
  bool _refreshScheduled = false;
  bool _disposed = false;
  int _resetDepth = 0;
  List<ScrollPosition> _lastPositions = <ScrollPosition>[];
  double? _lastScrollDistance;

  /// Direction-driven fade accumulated from scroll travel. This is the memory
  /// of the motion; the displayed [barFadeProgress] is derived from it.
  double _directionFade = 0.0;

  /// Reverse travel accumulated inside the current debounce band.
  double _pendingReverseDistance = 0.0;

  /// Sign of the last applied fade motion: 1 hiding, -1 revealing, 0 none.
  int _fadeDirection = 0;

  ValueListenable<bool> get isAtInitialPosition => _anchor;
  bool get isBarFadeEnabled => _barFadeEnabled;
  double get anchorDistance => _anchor.distanceFromAnchor;

  /// The shared rail fade store. The coordinator is its only writer while a
  /// glass page is active.
  void attachBarMotion(LiquidGlassBarMotion? motion) {
    if (identical(_barMotion, motion)) {
      return;
    }
    _barMotion = motion;
    _pushBarProgress(barFadeProgress.value);
  }

  /// Updates the geometry used only by the independent solid background.
  void updateLayout({
    required double devicePixelRatio,
    double? topBarExtent,
    double? safeTop,
  }) {
    _anchor.updateLayout(devicePixelRatio: devicePixelRatio);
    if ((topBarExtent != null && topBarExtent != _topBarExpandedExtent) ||
        (safeTop != null && safeTop != _safeTop)) {
      _lastScrollDistance = null;
    }
    if (topBarExtent != null && topBarExtent.isFinite) {
      _topBarExpandedExtent = math.max(0.0, topBarExtent);
    }
    if (safeTop != null && safeTop.isFinite) {
      _safeTop = math.max(0.0, safeTop);
    }
  }

  /// Enables the distance-driven top bar fade. With the setting off the bar
  /// opacity stays fixed at 1.
  void setBarFadeEnabled(bool enabled) {
    if (_barFadeEnabled == enabled) {
      return;
    }
    _barFadeEnabled = enabled;
    _lastScrollDistance = null;
    _directionFade = 0.0;
    _pendingReverseDistance = 0.0;
    _fadeDirection = 0;
    if (!enabled) {
      _barMotion?.reset();
      _pushBarProgress(0.0);
      return;
    }
    refresh();
  }

  /// The single scroll notification entry for a glass page.
  bool handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is ScrollStartNotification) {
      // Establish the new position baseline before its first update, even
      // when start and update are delivered before the next frame.
      final positions = _currentPositions();
      if (_lastScrollDistance == null ||
          !listEquals(positions, _lastPositions)) {
        _lastPositions = positions;
        _lastScrollDistance = _distanceFor(positions);
      }
    }
    if (notification is ScrollEndNotification) {
      // A finished gesture starts a fresh reverse-debounce budget; separate
      // short counter-flicks must not add up across gestures.
      _pendingReverseDistance = 0.0;
    }
    if (!_refreshScheduled) {
      // Outer and inner notifications can arrive during the same layout.
      // Read their combined offsets and the card transform only after layout.
      _refreshScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshScheduled = false;
        if (!_disposed) {
          refresh();
        }
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
    return false;
  }

  /// Re-derives every state from the current scroll positions. The first
  /// card's position and the mask progress are computed before the final bar
  /// progress so the rail reads the mask value from the same layout pass.
  void refresh() {
    if (_disposed) {
      return;
    }
    _anchor.refresh();
    final firstCardTop = _firstCardTopProvider?.call();
    if (_firstCardTopProvider != null) {
      _updateSolidMaskProgress(firstCardTop);
    }
    final directionFade = _computeBarProgress();
    var fade = directionFade;
    if (_firstCardTopProvider != null && _topBarExpandedExtent > 0.0) {
      // While the first card travels the band between the safe-area lower
      // edge and the expanded rail's lower edge, the rail must not fade out
      // ahead of the solid area above the card: the final visibility is the
      // larger of the direction-driven visibility and the mask coverage.
      final maskVisibility = (1.0 - solidMaskProgress.value).clamp(0.0, 1.0);
      fade = math.min(fade, maskVisibility);
    }
    _pushBarProgress(fade.clamp(0.0, 1.0));
  }

  /// Computes the mask reveal from the first card's real screen coordinate.
  /// At or above the safe-area trigger the mask is fully retracted; as the
  /// card returns between [safeTop] and the expanded rail's lower edge, the
  /// mask bottom follows it one-to-one. A missing card after it has once been
  /// measured means it has left the list cache and retracts the mask.
  void _updateSolidMaskProgress(double? firstCardTop) {
    if (firstCardTop == null || !firstCardTop.isFinite) {
      // Empty/loading pages at their origin still have a solid initial header.
      // Missing/recycled first children while browsing cannot revive it.
      solidMaskProgress.value = _anchor.distanceFromAnchor <= 0.0 ? 1.0 : 0.0;
      return;
    }

    final range = _topBarExpandedExtent - _safeTop;
    if (range <= 0.0) {
      solidMaskProgress.value =
          firstCardTop >= _topBarExpandedExtent ? 1.0 : 0.0;
      return;
    }
    solidMaskProgress.value =
        ((firstCardTop - _safeTop) / range).clamp(0.0, 1.0);
  }

  /// Shared anchor flow for category switches, title taps, same-tab
  /// reselection and refresh resets: restore the expanded outer header and the
  /// active inner start, then re-derive the state once the target has settled.
  Future<void> resetToInitialAnchor({
    Duration duration = const Duration(milliseconds: 500),
  }) async {
    _resetDepth++;
    try {
      await _anchor.animateToInitialAnchor(duration: duration);
    } finally {
      _resetDepth--;
      if (!_disposed) {
        _lastScrollDistance = null;
        _directionFade = 0.0;
        _pendingReverseDistance = 0.0;
        _fadeDirection = 0;
        refresh();
        _pushBarProgress(0.0);
      }
    }
  }

  List<ScrollPosition> _currentPositions() => <ScrollPosition>{
        ..._anchor._scrollController.positions,
        ...?_anchor._additionalPositions?.call(),
      }.where((p) => p.hasPixels && p.hasContentDimensions).toList();

  double _distanceFor(List<ScrollPosition> positions) =>
      positions.fold<double>(0.0, (sum, position) {
        final extent =
            math.max(0.0, position.maxScrollExtent - position.minScrollExtent);
        return sum +
            (position.pixels - position.minScrollExtent).clamp(0.0, extent);
      });

  /// Advances the direction-driven fade from the travel delta since the last
  /// refresh. Reverse travel must first fill an 8pt debounce band, so short
  /// counter-jitters keep the current progress; only the distance past the
  /// band turns the fade around.
  double _computeBarProgress() {
    final positions = _currentPositions();
    final samePositions = listEquals(positions, _lastPositions);
    // Nested scrolling transfers travel between outer and active inner.
    // Summing once avoids losing that travel or counting notifications twice.
    final distance = _distanceFor(positions);
    final previous = samePositions ? _lastScrollDistance : null;
    _lastPositions = positions;
    _lastScrollDistance = distance;
    if (!_barFadeEnabled || _resetDepth > 0 || distance <= 0.0) {
      // Back at the very top the rail is fully visible and the motion memory
      // clears, so the first up-scroll from the list top never waits.
      _directionFade = 0.0;
      _pendingReverseDistance = 0.0;
      _fadeDirection = 0;
      return 0.0;
    }
    // A changed active page/ScrollPosition establishes a new baseline; its
    // retained offset must not masquerade as a user scroll delta, and the
    // new page starts a fresh motion direction.
    if (previous == null) {
      _pendingReverseDistance = 0.0;
      _fadeDirection = 0;
      return _directionFade;
    }
    _directionFade =
        _advanceDirectionFade(_directionFade, distance - previous);
    return _directionFade;
  }

  double _advanceDirectionFade(double current, double delta) {
    if (delta == 0.0) {
      return current;
    }
    // Hiding from the fully visible state never waits: the first up-scroll
    // from the list top starts the fade immediately.
    if (current <= 0.0 && delta > 0.0) {
      _fadeDirection = 1;
      _pendingReverseDistance = 0.0;
      return (current + delta / barFadeRange).clamp(0.0, 1.0);
    }
    final direction = delta > 0.0 ? 1 : -1;
    if (direction == _fadeDirection) {
      _pendingReverseDistance = 0.0;
      return (current + delta / barFadeRange).clamp(0.0, 1.0);
    }
    if (_fadeDirection == 0) {
      _fadeDirection = direction;
      _pendingReverseDistance = 0.0;
      return (current + delta / barFadeRange).clamp(0.0, 1.0);
    }
    _pendingReverseDistance += delta.abs();
    if (_pendingReverseDistance < reverseDebounceDistance) {
      return current;
    }
    final excess = _pendingReverseDistance - reverseDebounceDistance;
    _pendingReverseDistance = 0.0;
    _fadeDirection = direction;
    final signed = direction > 0 ? excess : -excess;
    return (current + signed / barFadeRange).clamp(0.0, 1.0);
  }

  void _pushBarProgress(double progress) {
    barFadeProgress.value = progress;
    final motion = _barMotion;
    if (motion == null) {
      return;
    }
    motion.value = progress;
    motion.setTopBarVisible(progress < 1.0);
  }

  void dispose() {
    _disposed = true;
    _anchor.dispose();
    barFadeProgress.dispose();
    solidMaskProgress.dispose();
  }
}

/// Reads the screen-space top edge of a keyed gallery card when it is mounted.
double? liquidGlassScreenTop(GlobalKey key) {
  final renderObject = key.currentContext?.findRenderObject();
  if (renderObject is! RenderBox ||
      !renderObject.attached ||
      !renderObject.hasSize) {
    return null;
  }
  // Kept-alive sliver children can remain mounted with obsolete transforms.
  // Offstage pages must never supply the active page's first-card geometry.
  RenderObject? ancestor = renderObject;
  while (ancestor != null) {
    final data = ancestor.parentData;
    if ((data is SliverMultiBoxAdaptorParentData && data.keptAlive) ||
        (ancestor is RenderOffstage && ancestor.offstage)) {
      return null;
    }
    ancestor = ancestor.parent;
  }
  final top = renderObject.localToGlobal(Offset.zero).dy;
  return top.isFinite ? top : null;
}
