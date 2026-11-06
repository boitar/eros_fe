import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// AppKit controls bypass Flutter's gesture arena. Keep their hit testing in
/// sync with modal routes, including pop transitions and nested navigators.
abstract final class AppKitInteraction {
  static const channel = MethodChannel('eros/appkit-glass');
  static final Set<Object> _blockers = {};
  static bool get blocked => _blockers.isNotEmpty;

  static void setBlocked(Object owner, bool value) {
    if (value && PlatformCapabilities.hostPlatform != TargetPlatform.macOS) {
      return;
    }
    final before = blocked;
    if (value) {
      _blockers.add(owner);
    } else {
      _blockers.remove(owner);
    }
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
  AppKitModalObserver({this.root = false});
  final bool root;
  final List<Route<dynamic>> _routes = [];
  final Set<Route<dynamic>> _blocking = {};
  final Map<Route<dynamic>, VoidCallback> _cleanup = {};
  bool _disposed = false;

  bool _blocks(Route<dynamic> route) =>
      (route is ModalRoute && !route.opaque) ||
      (root && _routes.indexOf(route) > 0);

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
