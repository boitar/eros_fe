import 'dart:async';

import 'package:collection/collection.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Negotiation is deliberately independent of theme platform and user preference.
abstract final class AppKitGlassRuntime {
  static const channel = MethodChannel('eros/appkit-glass');
  static Future<void> initialize() async {
    if (PlatformCapabilities.hostPlatform != TargetPlatform.macOS) {
      return;
    }
    channel.setMethodCallHandler((call) async {
      if (call.method == 'capabilitiesChanged') {
        _apply(call.arguments);
      }
    });
    try {
      _apply(
        await channel
            .invokeMethod<Object?>('capabilities')
            .timeout(const Duration(seconds: 2)),
      );
    } catch (error) {
      disable();
      PlatformCapabilities.appKitMenuAvailable = false;
      debugPrint('AppKit glass unavailable: $error');
    }
  }

  static void _apply(Object? value) {
    PlatformCapabilities.appKitMenuAvailable =
        value is Map && value['apiVersion'] == 1 && value['menu'] == true;
    PlatformCapabilities.appKitAvailable.value =
        value is Map &&
        value['backend'] == 'appKit' &&
        value['apiVersion'] == 1;
  }

  static void disable() => PlatformCapabilities.appKitAvailable.value = false;
}

/// A single stable AppKit view per bar. Native controls own their pointer input;
/// decorative surfaces opt out of AppKit hit testing altogether.
class AppKitGlassView extends StatefulWidget {
  const AppKitGlassView({
    super.key,
    required this.kind,
    required this.configuration,
    this.onAction,
  });
  final String kind;
  final Map<String, Object?> configuration;
  final void Function(String method, int? index)? onAction;
  @override
  State<AppKitGlassView> createState() => _AppKitGlassViewState();
}

class _AppKitGlassViewState extends State<AppKitGlassView> {
  MethodChannel? _channel;
  Timer? _timeout;
  Map<String, Object?> get _parameters => {
    'kind': widget.kind,
    ...widget.configuration,
  };
  @override
  void initState() {
    super.initState();
    _timeout = Timer(const Duration(seconds: 4), () {
      if (mounted && _channel == null) {
        AppKitGlassRuntime.disable();
      }
    });
  }

  void _created(int id) {
    if (!mounted) {
      return;
    }
    _timeout?.cancel();
    _channel = MethodChannel('eros/appkit-glass/$id')
      ..setMethodCallHandler((call) async {
        if (mounted) {
          widget.onAction?.call(
            call.method,
            call.arguments is int ? call.arguments as int : null,
          );
        }
      });
    // Update after creation as configuration may have changed while NSView was loading.
    unawaited(_update());
  }

  Future<void> _update() async {
    try {
      final channel = _channel;
      if (channel == null) {
        return;
      }
      await channel
          .invokeMethod<void>('update', _parameters)
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // Ignore late failures from a view that has already been removed.
      if (mounted) {
        AppKitGlassRuntime.disable();
      }
    }
  }

  @override
  void didUpdateWidget(AppKitGlassView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind ||
        !const DeepCollectionEquality().equals(
          oldWidget.configuration,
          widget.configuration,
        )) {
      unawaited(_update());
    }
  }

  @override
  Widget build(BuildContext context) => AppKitView(
    viewType: 'eros/appkit-glass-view',
    creationParams: _parameters,
    creationParamsCodec: const StandardMessageCodec(),
    layoutDirection: Directionality.of(context),
    onPlatformViewCreated: _created,
    hitTestBehavior: widget.kind == 'surface'
        ? PlatformViewHitTestBehavior.transparent
        : PlatformViewHitTestBehavior.opaque,
  );
  @override
  void dispose() {
    _timeout?.cancel();
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }
}
