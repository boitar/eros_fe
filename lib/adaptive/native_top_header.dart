import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../widget/scroll_edge_effect.dart';
import 'adaptive_environment.dart';
import 'native_navigation.dart';

/// Header for list pages under the native shell. The tab rail and the
/// transparent navigation/status bar above it share one soft scroll edge
/// effect that blurs and fades into the content.
class NativeTopTabHeader extends StatelessWidget {
  const NativeTopTabHeader({
    super.key,
    required this.topInset,
    required this.railHeight,
    required this.child,
    this.fadeExtent,
    this.edgeProgress,
  });

  final double topInset;
  final double railHeight;
  final Widget child;
  final double? fadeExtent;
  final ValueListenable<double>? edgeProgress;

  static bool _wideWindow(BuildContext context) =>
      AdaptiveEnvironment.windowSizeOf(context).shortestSide >= 600;

  static double contentGapFor(BuildContext context) =>
      _wideWindow(context) ? 12 : 8;

  static double tailFor(BuildContext context) => _wideWindow(context) ? 28 : 24;

  /// A collapsible header keeps only the bars above it while scrolling down.
  static double minExtentFor({
    required double topInset,
    required double railHeight,
    required bool collapsible,
  }) =>
      collapsible ? topInset : topInset + railHeight;

  @override
  Widget build(BuildContext context) {
    final progress = edgeProgress;
    if (progress == null) {
      return _buildHeader(context, 0);
    }
    return ValueListenableBuilder<double>(
      valueListenable: progress,
      builder: (context, value, _) => _buildHeader(context, value),
    );
  }

  Widget _buildHeader(BuildContext context, double value) {
    final progress = SoftScrollEdgeEffect.quantizeStrength(value);
    return LayoutBuilder(builder: (context, constraints) {
      final height = constraints.maxHeight;
      final shown = railHeight <= 0
          ? 1.0
          : ((height - topInset) / railHeight).clamp(0.0, 1.0);
      return Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SoftScrollEdgeEffect(
              edge: SoftEdge.top,
              inset: topInset,
              bars: (height - topInset).clamp(0.0, railHeight),
              tail: (fadeExtent ?? tailFor(context)) * progress,
              strength: progress,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: railHeight,
            child: Opacity(
              opacity: shown,
              child: IgnorePointer(ignoring: shown < 0.5, child: child),
            ),
          ),
        ],
      );
    });
  }
}

/// Hides the native navigation bar of a root list while the user scrolls down
/// and brings it back when they scroll up or reach the top.
class NativeBarAutoHide extends StatefulWidget {
  const NativeBarAutoHide({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  State<NativeBarAutoHide> createState() => _NativeBarAutoHideState();
}

class _NativeBarAutoHideState extends State<NativeBarAutoHide> {
  bool _collapsed = false;

  void _set(bool collapsed) {
    if (_collapsed == collapsed) {
      return;
    }
    _collapsed = collapsed;
    NativeNavigationBridge.rootBarCollapsed.value = collapsed;
  }

  bool _onNotification(ScrollNotification notification) {
    if (!widget.enabled || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.reverse) {
        _set(true);
      } else if (notification.direction == ScrollDirection.forward) {
        _set(false);
      }
    } else if (notification.metrics.pixels <=
        notification.metrics.minScrollExtent) {
      _set(false);
    }
    return false;
  }

  @override
  void didUpdateWidget(NativeBarAutoHide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _set(false);
    }
  }

  @override
  void dispose() {
    _set(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onNotification,
        child: widget.child,
      );
}
