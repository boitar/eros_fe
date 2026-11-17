import 'package:flutter/cupertino.dart';

import '../widget/scroll_edge_effect.dart';
import '../widget/scroll_edge_progress.dart';
import 'native_navigation.dart';
import 'native_top_header.dart';

/// Adds the shared top scroll edge to a page whose only floating bar is the
/// native navigation row.
class NativeSingleBarEdge extends StatefulWidget {
  const NativeSingleBarEdge({
    super.key,
    required this.child,
    this.bars = 0,
    this.inset,
    this.surfaceColor,
    this.foreground,
    this.enabled,
  });

  final Widget child;

  /// Flutter-owned bar height between the top inset and the scroll content.
  final double bars;

  /// Overrides the top inset passed to [SoftScrollEdgeEffect]. Defaults to
  /// `MediaQuery.viewPaddingOf(context).top`.
  final double? inset;

  /// The surface visible below the scrolling content, when it differs from
  /// the Cupertino scaffold background.
  final Color? surfaceColor;

  /// Optional Stack child painted above the effect, used by floating controls.
  final Widget? foreground;

  /// Overrides [NativeNavigationScope.isEnabled] so Flutter floating bars can
  /// share the same fade geometry when native chrome is off (e.g. split view).
  final bool? enabled;

  @override
  State<NativeSingleBarEdge> createState() => _NativeSingleBarEdgeState();
}

class _NativeSingleBarEdgeState extends State<NativeSingleBarEdge> {
  ScrollEdgeProgressController? _progress;

  bool get _isEnabled => widget.enabled ?? NativeNavigationScope.isEnabled(context);

  void _syncProgress() {
    final enabled = _isEnabled;
    if (enabled && _progress == null) {
      _progress = ScrollEdgeProgressController();
    } else if (!enabled && _progress != null) {
      _progress!.dispose();
      _progress = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncProgress();
  }

  @override
  void didUpdateWidget(covariant NativeSingleBarEdge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      _syncProgress();
    }
  }

  @override
  void dispose() {
    _progress?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    if (!_isEnabled || progress == null) {
      if (widget.foreground == null) {
        return widget.child;
      }
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          widget.child,
          widget.foreground!,
        ],
      );
    }

    final inset = widget.inset ?? MediaQuery.viewPaddingOf(context).top;
    return ScrollEdgeProgressListener(
      controller: progress,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          widget.child,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (context, value, _) => SoftScrollEdgeEffect(
                edge: SoftEdge.top,
                inset: inset,
                bars: widget.bars,
                tail: NativeTopTabHeader.tailFor(context) * value,
                strength: value,
                surfaceColor: widget.surfaceColor,
              ),
            ),
          ),
          if (widget.foreground != null) widget.foreground!,
        ],
      ),
    );
  }
}
