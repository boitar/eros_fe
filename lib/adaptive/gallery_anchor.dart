import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A gallery identity and its leading edge, not a layout-dependent pixel offset.
class GalleryScrollAnchor {
  const GalleryScrollAnchor({
    required this.id,
    required this.index,
    required this.leading,
    required this.extent,
    this.atStart = false,
  });

  final String id;
  final int index;
  final double leading;
  final double extent;
  final bool atStart;

  double leadingForExtent(double nextExtent) => leading < 0 && extent > 0
      ? -(-leading / extent).clamp(0.0, 0.999) * nextExtent
      : leading;
}

class GalleryAnchorRestoration {
  const GalleryAnchorRestoration(this.anchor, this.generation);

  final GalleryScrollAnchor anchor;
  final int generation;
}

/// Shared by the sliver and its currently materialized cards only.
class GalleryAnchorController {
  GalleryScrollAnchor? get anchor => _anchor;
  GalleryScrollAnchor? _anchor;
  final _items = <_RenderGalleryAnchorItem>{};
}

/// Keeps the visible gallery when an adaptive list becomes a grid or resizes.
/// The original scroll position still owns scrolling, refresh and pagination.
class AnchoredGallerySliver extends StatefulWidget {
  const AnchoredGallerySliver({
    super.key,
    required this.itemIds,
    required this.layout,
    required this.sliver,
    this.controller,
  });

  final List<String> itemIds;
  final Object layout;
  final Widget sliver;
  final GalleryAnchorController? controller;

  @override
  State<AnchoredGallerySliver> createState() => _AnchoredGallerySliverState();
}

class _AnchoredGallerySliverState extends State<AnchoredGallerySliver> {
  late final _ownedController = GalleryAnchorController();
  GalleryAnchorController get _controller =>
      widget.controller ?? _ownedController;
  Object? _layout;
  GalleryAnchorRestoration? _restoration;
  int _generation = 0;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
        builder: (context, constraints) {
          final layout = (
            widget.layout,
            constraints.crossAxisExtent,
            constraints.viewportMainAxisExtent,
            MediaQuery.textScalerOf(context),
          );
          final anchor = _controller.anchor;
          if (_layout != null &&
              layout != _layout &&
              anchor != null &&
              widget.itemIds.isNotEmpty) {
            final found = widget.itemIds.indexOf(anchor.id);
            final index = found >= 0
                ? found
                : math.min(anchor.index, widget.itemIds.length - 1);
            _restoration = GalleryAnchorRestoration(
              GalleryScrollAnchor(
                id: widget.itemIds[index],
                index: index,
                leading: anchor.leading,
                extent: anchor.extent,
                atStart: anchor.atStart,
              ),
              ++_generation,
            );
          }
          _layout = layout;
          return GalleryAnchorScope(
            controller: _controller,
            restoration: _restoration,
            child: _GalleryAnchorSliver(
              controller: _controller,
              restoration: _restoration,
              child: widget.sliver,
            ),
          );
        },
      );
}

class GalleryAnchorScope extends InheritedWidget {
  const GalleryAnchorScope({
    super.key,
    required this.controller,
    required this.restoration,
    required super.child,
  });

  final GalleryAnchorController controller;
  final GalleryAnchorRestoration? restoration;

  static GalleryAnchorScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GalleryAnchorScope>();

  @override
  bool updateShouldNotify(GalleryAnchorScope oldWidget) =>
      controller != oldWidget.controller ||
      restoration != oldWidget.restoration;
}

/// Lightweight render markers avoid retaining a GlobalKey for every gallery.
class GalleryAnchorItem extends StatelessWidget {
  const GalleryAnchorItem({
    super.key,
    required this.id,
    required this.index,
    required this.child,
  });

  final String id;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = GalleryAnchorScope.maybeOf(context);
    return scope == null
        ? child
        : _GalleryAnchorMarker(
            controller: scope.controller,
            id: id,
            index: index,
            child: child,
          );
  }
}

class _GalleryAnchorMarker extends SingleChildRenderObjectWidget {
  const _GalleryAnchorMarker({
    required this.controller,
    required this.id,
    required this.index,
    required super.child,
  });

  final GalleryAnchorController controller;
  final String id;
  final int index;

  @override
  _RenderGalleryAnchorItem createRenderObject(BuildContext context) =>
      _RenderGalleryAnchorItem(controller, id, index);

  @override
  void updateRenderObject(
      BuildContext context, _RenderGalleryAnchorItem renderObject) {
    renderObject
      ..controller = controller
      ..id = id
      ..index = index;
  }
}

class _RenderGalleryAnchorItem extends RenderProxyBox {
  _RenderGalleryAnchorItem(this._controller, this.id, this.index);

  GalleryAnchorController _controller;
  String id;
  int index;
  Rect layoutBounds = Rect.zero;

  @override
  void performLayout() {
    super.performLayout();
    layoutBounds = Offset.zero & Size(size.width, size.height);
  }

  set controller(GalleryAnchorController value) {
    if (_controller == value) {
      return;
    }
    if (attached) {
      _controller._items.remove(this);
    }
    _controller = value;
    if (attached) {
      _controller._items.add(this);
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller._items.add(this);
  }

  @override
  void detach() {
    _controller._items.remove(this);
    super.detach();
  }
}

class _GalleryAnchorSliver extends SingleChildRenderObjectWidget {
  const _GalleryAnchorSliver({
    required this.controller,
    required this.restoration,
    required super.child,
  });

  final GalleryAnchorController controller;
  final GalleryAnchorRestoration? restoration;

  @override
  _RenderGalleryAnchorSliver createRenderObject(BuildContext context) =>
      _RenderGalleryAnchorSliver(controller, restoration);

  @override
  void updateRenderObject(
      BuildContext context, _RenderGalleryAnchorSliver renderObject) {
    renderObject
      ..controller = controller
      ..restoration = restoration
      ..markNeedsLayout();
  }
}

class _RenderGalleryAnchorSliver extends RenderProxySliver {
  _RenderGalleryAnchorSliver(this.controller, this.restoration);

  GalleryAnchorController controller;
  GalleryAnchorRestoration? restoration;
  int? _restoredGeneration;
  double? _lastScrollOffset;
  String? _preferredId;
  bool _restoring = false;

  RenderSliverGrid? _grid(RenderObject object) {
    if (object is RenderSliverGrid) {
      return object;
    }
    RenderSliverGrid? result;
    object.visitChildren((child) {
      if (result == null && child is RenderSliver) {
        result = _grid(child);
      }
    });
    return result;
  }

  @override
  void performLayout() {
    super.performLayout();
    if (geometry?.scrollOffsetCorrection != null ||
        constraints.axisDirection != AxisDirection.down) {
      return;
    }
    final restore = restoration;
    if (restore != null && restore.generation != _restoredGeneration) {
      _restoredGeneration = restore.generation;
      _preferredId = restore.anchor.id;
      _restoring = true;
      final grid = _grid(child!);
      if (grid != null) {
        final tile = grid.gridDelegate
            .getLayout(grid.constraints)
            .getGeometryForChildIndex(restore.anchor.index);
        final origin =
            MatrixUtils.transformPoint(grid.getTransformTo(this), Offset.zero);
        final correction = restore.anchor.atStart
            ? -constraints.scrollOffset
            : origin.dy +
                tile.scrollOffset -
                grid.constraints.scrollOffset -
                restore.anchor.leadingForExtent(tile.mainAxisExtent);
        if (correction.isFinite && correction.abs() > precisionErrorTolerance) {
          // Correct in the viewport's layout pass, before a mismatched frame
          // can be painted or a user scroll notification can trigger refresh.
          geometry = SliverGeometry(scrollOffsetCorrection: correction);
          return;
        }
      } else {
        for (final item in controller._items) {
          if (item.id != restore.anchor.id || !item.attached || !item.hasSize) {
            continue;
          }
          final bounds = MatrixUtils.transformRect(
              item.getTransformTo(this), item.layoutBounds);
          final correction = restore.anchor.atStart
              ? -constraints.scrollOffset
              : bounds.top - restore.anchor.leadingForExtent(bounds.height);
          if (correction.isFinite &&
              correction.abs() > precisionErrorTolerance) {
            geometry = SliverGeometry(scrollOffsetCorrection: correction);
            return;
          }
          break;
        }
      }
    }
    _capture();
  }

  void _capture() {
    if (!_restoring && _lastScrollOffset != constraints.scrollOffset) {
      _preferredId = null;
    }
    _RenderGalleryAnchorItem? first;
    Rect? firstBounds;
    _RenderGalleryAnchorItem? preferred;
    Rect? preferredBounds;
    for (final item in controller._items) {
      if (!item.attached || !item.hasSize) {
        continue;
      }
      final bounds = MatrixUtils.transformRect(
          item.getTransformTo(this), item.layoutBounds);
      if (!bounds.isFinite ||
          bounds.bottom <= math.max(0, constraints.overlap) ||
          bounds.top >= geometry!.paintExtent) {
        continue;
      }
      if (item.id == _preferredId) {
        preferred = item;
        preferredBounds = bounds;
      }
      if (first == null ||
          bounds.top < firstBounds!.top - precisionErrorTolerance ||
          ((bounds.top - firstBounds.top).abs() < precisionErrorTolerance &&
              item.index < first.index)) {
        first = item;
        firstBounds = bounds;
      }
    }
    if (preferred != null) {
      first = preferred;
      firstBounds = preferredBounds;
    }
    if (first != null) {
      controller._anchor = GalleryScrollAnchor(
        id: first.id,
        index: first.index,
        leading: firstBounds!.top,
        extent: firstBounds.height,
        atStart: constraints.scrollOffset <= precisionErrorTolerance,
      );
    }
    _lastScrollOffset = constraints.scrollOffset;
    _restoring = false;
  }
}
