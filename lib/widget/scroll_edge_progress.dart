import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';

import 'scroll_edge_effect.dart';

/// Shares one edge between the outer header and the selected inner list.
/// Offstage pages retain their own offsets without changing the visible edge.
class ScrollEdgeProgressController extends ValueNotifier<double> {
  ScrollEdgeProgressController({this.revealDistance = reveal})
    : assert(revealDistance > 0),
      super(0);

  static const double reveal = 16;

  final double revealDistance;
  final Map<Object, double> _pageOffsets = <Object, double>{};
  Object? _activePage;
  double _outerOffset = 0;
  bool _scheduled = false;
  bool _disposed = false;

  void selectPage(Object? page) {
    if (_activePage == page) {
      return;
    }
    _activePage = page;
    _publish();
  }

  void update(ScrollMetrics metrics, {Object? page}) {
    if (metrics.axis != Axis.vertical || !metrics.hasPixels) {
      return;
    }
    final offset = metrics.pixels - metrics.minScrollExtent;
    if (page == null) {
      _outerOffset = offset;
    } else {
      _pageOffsets[page] = offset;
    }
    _publish();
  }

  double get _progress {
    final inner = _pageOffsets[_activePage] ?? 0;
    // A pull to refresh must stay clear even if a nested header was collapsed.
    if (_outerOffset < 0 || inner < 0) {
      return 0;
    }
    final t = (math.max(_outerOffset, inner) / revealDistance).clamp(0.0, 1.0);
    return SoftScrollEdgeEffect.quantizeStrength(t * t * (3 - 2 * t));
  }

  void _publish() {
    if (_disposed) {
      return;
    }
    // Page selection and scroll dimensions can change during layout. Coalesce
    // those updates; ordinary position changes are published immediately.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_scheduled) {
        return;
      }
      _scheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _scheduled = false;
        if (!_disposed) {
          value = _progress;
        }
      });
    } else {
      value = _progress;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Place one listener outside a nested scroll view, and one around each page
/// with its stable [page] ID. Only the nearest vertical viewport is sampled.
class ScrollEdgeProgressListener extends StatefulWidget {
  const ScrollEdgeProgressListener({
    super.key,
    required this.controller,
    required this.child,
    this.page,
    this.activePage,
    this.enabled = true,
  });

  final ScrollEdgeProgressController controller;
  final Widget child;
  final Object? page;
  final Object? activePage;
  final bool enabled;

  @override
  State<ScrollEdgeProgressListener> createState() =>
      _ScrollEdgeProgressListenerState();
}

class _ScrollEdgeProgressListenerState
    extends State<ScrollEdgeProgressListener> {
  ScrollPosition? _position;

  @override
  void initState() {
    super.initState();
    _selectPage();
  }

  @override
  void didUpdateWidget(ScrollEdgeProgressListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectPage();
    _updatePosition();
  }

  void _selectPage() {
    if (widget.enabled && widget.page == null) {
      widget.controller.selectPage(widget.activePage);
    }
  }

  void _updatePosition() {
    final position = _position;
    if (widget.enabled &&
        position != null &&
        position.hasPixels &&
        position.hasContentDimensions) {
      widget.controller.update(position, page: widget.page);
    }
  }

  void _record(ScrollMetrics metrics, BuildContext? context, int depth) {
    if (!widget.enabled || depth != 0 || metrics.axis != Axis.vertical) {
      return;
    }
    final position = context == null
        ? null
        : Scrollable.maybeOf(context, axis: Axis.vertical)?.position;
    if (_position != position) {
      _position?.removeListener(_updatePosition);
      _position = position;
      _position?.addListener(_updatePosition);
    }
    widget.controller.update(metrics, page: widget.page);
  }

  @override
  void dispose() {
    _position?.removeListener(_updatePosition);
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => NotificationListener<ScrollMetricsNotification>(
    onNotification: (notification) {
      _record(notification.metrics, notification.context, notification.depth);
      return false;
    },
    child: NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _record(notification.metrics, notification.context, notification.depth);
        return false;
      },
      child: widget.child,
    ),
  );
}
