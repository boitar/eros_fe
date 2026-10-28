import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show FlutterExceptionHandler;
import 'package:flutter/widgets.dart';

import '../utils/logger.dart';
import 'offline_acceptance.dart';

Widget offlineDuoHealth({required Widget child}) => offlineAcceptanceEnabled &&
        const bool.fromEnvironment('EROS_DUO_ACCEPTANCE')
    ? OfflineDuoHealth(child: child)
    : child;

/// A read-only acceptance signal. Keep the existing error handlers and rendering
/// intact so XCTest cannot accept a red Flutter error page as a successful route.
class OfflineDuoHealth extends StatefulWidget {
  const OfflineDuoHealth({super.key, required this.child});
  final Widget child;

  @override
  State<OfflineDuoHealth> createState() => _OfflineDuoHealthState();
}

class _OfflineDuoHealthState extends State<OfflineDuoHealth> {
  FlutterExceptionHandler? _previousFramework;
  bool Function(Object, StackTrace)? _previousPlatform;
  late final FlutterExceptionHandler _frameworkHandler;
  late final bool Function(Object, StackTrace) _platformHandler;
  int _frameworkErrors = 0;
  int _platformErrors = 0;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _previousFramework = FlutterError.onError;
    _previousPlatform = PlatformDispatcher.instance.onError;
    _frameworkHandler = (details) {
      _frameworkErrors++;
      _record('FRAMEWORK', details, details.stack);
      _previousFramework?.call(details);
    };
    _platformHandler = (error, stack) {
      _platformErrors++;
      _record('PLATFORM', error, stack);
      return _previousPlatform?.call(error, stack) ?? false;
    };
    FlutterError.onError = _frameworkHandler;
    PlatformDispatcher.instance.onError = _platformHandler;
  }

  void _record(String kind, Object error, StackTrace? stack) {
    logger.e('OFFLINE_DUO_${kind}_ERROR: $error\n$stack');
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _scheduled = false);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    if (identical(FlutterError.onError, _frameworkHandler)) {
      FlutterError.onError = _previousFramework;
    }
    if (identical(PlatformDispatcher.instance.onError, _platformHandler)) {
      PlatformDispatcher.instance.onError = _previousPlatform;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        explicitChildNodes: true,
        identifier: 'offline-duo-health-probe',
        label: 'framework=$_frameworkErrors;platform=$_platformErrors',
        child: widget.child,
      );
}
