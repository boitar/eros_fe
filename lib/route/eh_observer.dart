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

  void resetHistory() {
    history.clear();
    _routeVersions.clear();
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
    _historyChanged();
    // logger.d('didPop: \n${route.settings}');

    ///调用Navigator.of(context).pop() 出栈时回调
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    history.add(route);
    _routeVersions[route] = ++_navigationVersion;
    _historyChanged();
    // logger.d('didPush: \n${route.settings}');

    ///调用Navigator.of(context).push(Route()) 进栈时回调
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    super.didRemove(route, previousRoute);
    history.remove(route);
    _routeVersions.remove(route);
    _historyChanged();
    // logger.d('didRemove: \n${route.settings}');

    ///调用Navigator.of(context).removeRoute(Route()) 移除某个路由回调
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    final index = oldRoute == null ? -1 : history.indexOf(oldRoute);
    _routeVersions.remove(oldRoute);
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
