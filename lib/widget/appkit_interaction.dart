import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Native controls bypass Flutter's gesture arena and (for iOS UiKitViews)
/// composite above the Flutter scene. Keep their hit testing and native surface
/// usage in sync with modal routes, including pop transitions and nested
/// navigators.
abstract final class AppKitInteraction {
  static const channel = MethodChannel('eros/appkit-glass');
  static final Set<Object> _blockers = {};
  static final Set<AppKitModalObserver> _observers = {};
  static bool _revisionScheduled = false;

  /// Increments whenever the set of active modal blockers changes so iOS
  /// native platform views underneath a modal can yield to Flutter composition.
  static final ValueNotifier<int> modalRevision = ValueNotifier<int>(0);

  static bool get blocked => _blockers.isNotEmpty;

  static void _bumpRevision() {
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      modalRevision.value++;
      return;
    }
    if (_revisionScheduled) {
      return;
    }
    _revisionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revisionScheduled = false;
      modalRevision.value++;
    });
  }

  /// Whether a modal or blocking overlay currently sits above [context]'s
  /// route. Widgets inside the topmost blocking route itself remain uncovered.
  static bool isCoveredByModal(BuildContext context) {
    if (_blockers.any((owner) => owner is! AppKitModalObserver)) {
      return true;
    }
    if (_observers.isEmpty) {
      return false;
    }
    final route = ModalRoute.of(context);
    for (final observer in _observers) {
      if (observer._disposed || observer._blocking.isEmpty) {
        continue;
      }
      if (observer.root) {
        for (final blocking in observer._blocking) {
          if (identical(blocking, route)) {
            continue;
          }
          if (route == null ||
              blocking.navigator != route.navigator ||
              observer._isAbove(blocking, route)) {
            return true;
          }
        }
      } else if (route != null && observer._routes.contains(route)) {
        for (final blocking in observer._blocking) {
          if (!identical(blocking, route) &&
              observer._isAbove(blocking, route)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  static void setBlocked(Object owner, bool value) {
    final before = blocked;
    if (value) {
      _blockers.add(owner);
    } else {
      _blockers.remove(owner);
    }
    _bumpRevision();
    if (before == blocked ||
        PlatformCapabilities.hostPlatform != TargetPlatform.macOS) {
      return;
    }
    // Dispatch immediately, rather than waiting for a Flutter rebuild/frame.
    channel.invokeMethod<void>('setInteractive', !blocked).catchError((
      Object _,
    ) {
      // A failed bridge cannot guarantee modal isolation: remove native
      // controls via the existing Flutter renderer fallback.
      PlatformCapabilities.appKitAvailable.value = false;
    });
  }
}

/// Owned by the State that owns its Navigator. Dispose even when a whole
/// navigation tree disappears without emitting per-route removal callbacks.
class AppKitModalObserver extends NavigatorObserver {
  AppKitModalObserver({this.root = false}) {
    AppKitInteraction._observers.add(this);
  }
  final bool root;
  final List<Route<dynamic>> _routes = [];
  final Set<Route<dynamic>> _blocking = {};
  final Map<Route<dynamic>, VoidCallback> _cleanup = {};
  bool _disposed = false;

  bool _blocks(Route<dynamic> route) =>
      (route is ModalRoute && !route.opaque) ||
      (root && _routes.indexOf(route) > 0);

  bool _isAbove(Route<dynamic> candidate, Route<dynamic> target) {
    final targetIndex = _routes.indexOf(target);
    if (targetIndex < 0) {
      return false;
    }
    final candidateIndex = _routes.indexOf(candidate);
    // A popped blocking route stays in _blocking until its dismiss animation
    // settles, so it is no longer in _routes while still covering target.
    return candidateIndex < 0 || candidateIndex > targetIndex;
  }

  void _sync() =>
      AppKitInteraction.setBlocked(this, !_disposed && _blocking.isNotEmpty);

  void _forget(Route<dynamic> route) {
    _cleanup.remove(route)?.call();
    _blocking.remove(route);
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    AppKitInteraction._observers.remove(this);
    for (final cleanup in _cleanup.values.toList()) {
      cleanup();
    }
    _cleanup.clear();
    _blocking.clear();
    _routes.clear();
    _sync();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_disposed) {
      return;
    }
    _routes.add(route);
    if (_blocks(route)) {
      _blocking.add(route);
    }
    _sync();
  }

  void _remove(Route<dynamic> route, {bool transition = false}) {
    if (_disposed) {
      return;
    }
    _routes.remove(route);
    final animation = route is TransitionRoute ? route.animation : null;
    // Retain this observer's lease through the barrier's reverse animation.
    if (transition &&
        _blocking.contains(route) &&
        animation != null &&
        !animation.isDismissed) {
      void settle() {
        if (_disposed) {
          return;
        }
        _forget(route);
        _sync();
      }

      late AnimationStatusListener listener;
      listener = (status) {
        if (status == AnimationStatus.dismissed) {
          settle();
        }
      };
      animation.addStatusListener(listener);
      _cleanup[route] = () => animation.removeStatusListener(listener);
      (route as TransitionRoute).completed.whenComplete(settle);
    } else {
      _forget(route);
      _sync();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _remove(route, transition: true);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _remove(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (_disposed) {
      return;
    }
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (oldRoute != null) {
      _routes.remove(oldRoute);
      _forget(oldRoute);
    }
    if (newRoute != null) {
      _routes.insert(index < 0 ? _routes.length : index, newRoute);
      if (_blocks(newRoute)) {
        _blocking.add(newRoute);
      }
    }
    // Replace the lease atomically: no brief re-enable between two modals.
    _sync();
  }
}

/// SmartDialog inserts OverlayEntries rather than routes. Wrap its modal
/// content so the same guard follows the actual entry's lifetime.
class AppKitModalContent extends StatefulWidget {
  const AppKitModalContent({super.key, required this.child});
  final Widget child;
  @override
  State<AppKitModalContent> createState() => _AppKitModalContentState();
}

class _AppKitModalContentState extends State<AppKitModalContent> {
  @override
  void initState() {
    super.initState();
    AppKitInteraction.setBlocked(this, true);
  }

  @override
  void dispose() {
    AppKitInteraction.setBlocked(this, false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
