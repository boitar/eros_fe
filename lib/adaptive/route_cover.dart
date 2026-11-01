import 'package:flutter/cupertino.dart' show CupertinoRouteTransitionMixin;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../route/eh_observer.dart';

/// iOS 27 composites native views above the Flutter scene, so a page sliding
/// over another can't hide the lower page's native glass, such as the group
/// rail. Each page reports where it is drawn, and a covered page clips itself
/// to the part the covering page hasn't reached yet.
class CoveredPage extends StatelessWidget {
  const CoveredPage({super.key, required this.observer, required this.child});

  /// The observer of the navigator this page lives in.
  final EhNavigatorObserver observer;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final cover = route == null ? null : observer.coverOf(route);
    return RouteSurface(
      route: route,
      child: RouteCoverClip(
        cover: cover,
        child: CoveredInsets(cover: cover, child: child),
      ),
    );
  }
}

/// The native bars follow the top page, so their insets change while a page
/// slides over another or off it again. A covered page keeps the insets it
/// had on top instead of jumping inside the strip that still shows.
class CoveredInsets extends StatefulWidget {
  const CoveredInsets({super.key, required this.cover, required this.child});

  /// Runs while a page covers this one; dismissed when nothing does.
  final Animation<double>? cover;
  final Widget child;

  @override
  State<CoveredInsets> createState() => _CoveredInsetsState();
}

class _CoveredInsetsState extends State<CoveredInsets> {
  bool _covered = false;
  MediaQueryData? _onTop;

  bool get _isCovered => !(widget.cover?.isDismissed ?? true);

  @override
  void initState() {
    super.initState();
    _covered = _isCovered;
    widget.cover?.addStatusListener(_statusChanged);
  }

  @override
  void didUpdateWidget(CoveredInsets oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cover != widget.cover) {
      oldWidget.cover?.removeStatusListener(_statusChanged);
      widget.cover?.addStatusListener(_statusChanged);
      _covered = _isCovered;
    }
  }

  @override
  void dispose() {
    widget.cover?.removeStatusListener(_statusChanged);
    super.dispose();
  }

  void _statusChanged(AnimationStatus _) {
    if (_isCovered == _covered) return;
    // A push reports the cover while the navigator builds.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _covered = _isCovered);
      });
    } else {
      setState(() => _covered = _isCovered);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final onTop = _onTop;
    // A rotation while covered makes the old insets meaningless.
    final keep = _covered && onTop != null && onTop.size == media.size;
    if (!keep) _onTop = media;
    return MediaQuery(
      data: keep
          ? media.copyWith(
              padding: onTop.padding,
              viewPadding: onTop.viewPadding,
            )
          : media,
      child: widget.child,
    );
  }
}

/// Marks where [route]'s page is drawn, so the pages it covers can find it.
class RouteSurface extends SingleChildRenderObjectWidget {
  const RouteSurface({super.key, required this.route, super.child});

  final Route<dynamic>? route;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRouteSurface(route);

  @override
  void updateRenderObject(
      BuildContext context, _RenderRouteSurface renderObject) {
    renderObject.route = route;
  }
}

/// Clips [child] to the part the page driven by [cover] doesn't cover.
class RouteCoverClip extends SingleChildRenderObjectWidget {
  const RouteCoverClip({super.key, required this.cover, super.child});

  final Animation<double>? cover;

  /// The part [renderObject] of a [RouteCoverClip] leaves visible, or null
  /// when nothing covers it.
  @visibleForTesting
  static Rect? debugVisibleRectOf(RenderObject renderObject) =>
      (renderObject as _RenderRouteCoverClip)._visible();

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRouteCoverClip(cover);

  @override
  void updateRenderObject(
      BuildContext context, _RenderRouteCoverClip renderObject) {
    renderObject.cover = cover;
  }
}

/// Whether [route] slides its page over the one below instead of fading it
/// in place. Get routes without a transition use the app's Cupertino one.
bool _slides(Route<dynamic> route) {
  if (route is CupertinoRouteTransitionMixin) return true;
  if (route is GetPageRoute) {
    return switch (route.transition) {
      null ||
      Transition.cupertino ||
      Transition.native ||
      Transition.rightToLeft ||
      Transition.leftToRight ||
      Transition.rightToLeftWithFade ||
      Transition.leftToRightWithFade =>
        true,
      _ => false,
    };
  }
  return false;
}

/// The page covering whatever [cover] follows, found through any proxies.
Route<dynamic>? _coveringRoute(Animation<double>? cover) {
  var current = cover;
  while (current is ProxyAnimation) {
    if (current is RouteCoverAnimation) return current.route;
    current = current.parent;
  }
  return null;
}

class _RenderRouteSurface extends RenderProxyBox {
  _RenderRouteSurface(this._route);

  static final Map<Route<dynamic>, _RenderRouteSurface> _surfaces = {};

  Route<dynamic>? _route;
  set route(Route<dynamic>? value) {
    if (identical(value, _route)) return;
    _unregister();
    _route = value;
    if (attached) _register();
  }

  void _register() {
    final route = _route;
    if (route != null) _surfaces[route] = this;
  }

  void _unregister() {
    final route = _route;
    if (route != null && identical(_surfaces[route], this)) {
      _surfaces.remove(route);
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _register();
  }

  @override
  void detach() {
    _unregister();
    super.detach();
  }
}

class _RenderRouteCoverClip extends RenderProxyBox {
  _RenderRouteCoverClip(this._cover);

  Animation<double>? _cover;
  set cover(Animation<double>? value) {
    if (identical(value, _cover)) return;
    if (attached) _cover?.removeListener(markNeedsPaint);
    _cover = value;
    if (attached) _cover?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  final LayerHandle<ClipRectLayer> _clip = LayerHandle<ClipRectLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _cover?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _cover?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }

  /// The uncovered part in local coordinates, or null when nothing covers
  /// this box.
  Rect? _visible() {
    final cover = _cover;
    if (cover == null || cover.value <= 0) return null;
    final route = _coveringRoute(cover);
    // A page pushed a moment ago spends its first frame offstage at its
    // final place; it covers nothing yet.
    if (route is ModalRoute && route.offstage) return null;
    final surface = route == null ? null : _RenderRouteSurface._surfaces[route];
    if (surface == null || !surface.attached || !surface.hasSize) {
      return null;
    }
    final toLocal = Matrix4.tryInvert(getTransformTo(null));
    if (toLocal == null) return null;
    final covering = MatrixUtils.transformRect(
      toLocal * surface.getTransformTo(null),
      Offset.zero & surface.size,
    );
    final bounds = Offset.zero & size;
    // Keep the strip on the side the covering page slides in from.
    if (covering.left > bounds.left && covering.left < bounds.right) {
      return Rect.fromLTRB(
          bounds.left, bounds.top, covering.left, bounds.bottom);
    }
    if (covering.right < bounds.right && covering.right > bounds.left) {
      return Rect.fromLTRB(
          covering.right, bounds.top, bounds.right, bounds.bottom);
    }
    final overlaps = covering.left <= bounds.left &&
        covering.right >= bounds.right;
    // A sliding page that covers this one whole, as it starts to pop, hides
    // its native views too. A page fading in place always overlaps it, and
    // this one must stay visible under it.
    return overlaps && route != null && _slides(route) ? Rect.zero : null;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final visible = _visible();
    if (child == null || visible == null) {
      _clip.layer = null;
      super.paint(context, offset);
      return;
    }
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      visible,
      super.paint,
      oldLayer: _clip.layer,
    );
  }
}
