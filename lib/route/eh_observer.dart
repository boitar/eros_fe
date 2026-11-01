import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';

class EhNavigatorObserver extends NavigatorObserver {
  static int _navigationVersion = 0;
  List<Route<dynamic>> history = <Route<dynamic>>[];
  final Map<Route<dynamic>, int> _routeVersions = {};
  int get activeRouteVersion =>
      history.isEmpty ? 0 : _routeVersions[history.last] ?? 0;
  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  bool _notificationScheduled = false;
  final Map<Route<dynamic>, RouteCoverAnimation> _covers = {};

  void resetHistory() {
    history.clear();
    _routeVersions.clear();
    _covers.clear();
  }

  /// Follows the page that slides over [route]: the one pushed onto it, and
  /// the one leaving it while that page pops. Route secondary animations
  /// can't stand in for this, as routes without Cupertino parallax never
  /// set them.
  RouteCoverAnimation coverOf(Route<dynamic> route) =>
      _covers.putIfAbsent(route, RouteCoverAnimation.new);

  void _coverWith(Route<dynamic>? below, Route<dynamic> above) {
    final animation = above is TransitionRoute ? above.animation : null;
    if (below == null || animation == null) return;
    coverOf(below)
      ..route = above
      ..parent = animation;
  }

  /// Once the leaving page has gone, nothing covers the page below it.
  void _uncoverAfter(Route<dynamic>? below, Route<dynamic> above) {
    final cover = _covers[below];
    final animation = above is TransitionRoute ? above.animation : null;
    if (cover == null || animation == null) return;
    void settle() {
      if (identical(cover.route, above)) {
        cover
          ..route = null
          ..parent = kAlwaysDismissedAnimation;
      }
    }

    if (animation.isDismissed) {
      settle();
      return;
    }
    late final AnimationStatusListener listener;
    listener = (status) {
      if (!status.isDismissed) return;
      animation.removeStatusListener(listener);
      settle();
    };
    animation.addStatusListener(listener);
  }

  void _historyChanged() {
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      revision.value++;
      return;
    }
    if (_notificationScheduled) return;
    _notificationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationScheduled = false;
      revision.value++;
    });
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    history.remove(route);
    _routeVersions.remove(route);
    _covers.remove(route);
    // A replaced page may still be the one on record below.
    _coverWith(previousRoute, route);
    _uncoverAfter(previousRoute, route);
    _historyChanged();
    // logger.d('didPop: \n${route.settings}');

    ///调用Navigator.of(context).pop() 出栈时回调
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    history.add(route);
    _routeVersions[route] = ++_navigationVersion;
    _coverWith(previousRoute, route);
    _historyChanged();
    // logger.d('didPush: \n${route.settings}');

    ///调用Navigator.of(context).push(Route()) 进栈时回调
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    super.didRemove(route, previousRoute);
    history.remove(route);
    _routeVersions.remove(route);
    _covers.remove(route);
    final below = _covers[previousRoute];
    if (below != null && identical(below.route, route)) {
      below
        ..route = null
        ..parent = kAlwaysDismissedAnimation;
    }
    _historyChanged();
    // logger.d('didRemove: \n${route.settings}');

    ///调用Navigator.of(context).removeRoute(Route()) 移除某个路由回调
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    final index = oldRoute == null ? -1 : history.indexOf(oldRoute);
    _routeVersions.remove(oldRoute);
    _covers.remove(oldRoute);
    if (index >= 0) history.removeAt(index);
    if (newRoute != null) {
      history.insert(index >= 0 ? index : history.length, newRoute);
      _routeVersions[newRoute] = ++_navigationVersion;
    }
    _historyChanged();
    // logger.d('didReplace: \n${newRoute?.settings}');

    ///调用Navigator.of(context).replace( oldRoute:Route("old"),newRoute:Route("new")) 替换路由时回调
  }

  @override
  void didStartUserGesture(Route route, Route? previousRoute) {
    super.didStartUserGesture(route, previousRoute);

    ///iOS侧边手势滑动触发回调 手势开始时回调
  }

  @override
  void didStopUserGesture() {
    super.didStopUserGesture();

    ///iOS侧边手势滑动触发停止时回调 不管页面是否退出了都会调用
  }
}

/// The motion of the page covering another, and which page that is.
class RouteCoverAnimation extends ProxyAnimation {
  RouteCoverAnimation() : super(kAlwaysDismissedAnimation);

  /// The page sliding over, or null when nothing covers the page.
  Route<dynamic>? route;
}
