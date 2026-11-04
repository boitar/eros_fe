import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Shader initialization is optional: the existing blur remains usable if it fails.
abstract final class FlutterGlassRuntime {
  static bool _available = true;
  @visibleForTesting
  static bool? debugAvailable;
  static bool get available =>
      kDebugMode && debugAvailable != null ? debugAvailable! : _available;

  static Future<void> initialize() async {
    if (!PlatformCapabilities.glassStyle || PlatformCapabilities.uiKitGlass) {
      return;
    }
    try {
      await LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
    } catch (error) {
      _available = false;
      debugPrint('Flutter glass initialization failed: $error');
    }
  }

  static Widget wrap(Widget child, {bool enabled = true}) =>
      PlatformCapabilities.uiKitGlass
          ? child
          : GlassCapabilityScope(child: GlassPreference(
              enabled: enabled,
              child: available
                  ? LiquidGlassWidgets.wrap(
                      child: child, adaptiveQuality: false)
                  : child));
}

/// One refractive surface per local control group. Selection indicators inside
/// it use a plain tint, retaining their gestures without double refraction.
class FlutterGlassPanel extends StatelessWidget {
  const FlutterGlassPanel(
      {super.key, required this.child, required this.borderRadius});
  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    if (context.dependOnInheritedWidgetOfExactType<_GlassPanelScope>() !=
        null) {
      return DecoratedBox(
        decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: CupertinoDynamicColor.resolve(
                CupertinoColors.tertiarySystemFill, context)),
        child: child,
      );
    }
    return _GlassPanelScope(
        child: GlassContainer(
      useOwnLayer: true,
      quality: GlassQuality.standard,
      shape: LiquidRoundedSuperellipse(borderRadius: borderRadius.topLeft.x),
      child: child,
    ));
  }
}

class _GlassPanelScope extends InheritedWidget {
  const _GlassPanelScope({required super.child});
  @override
  bool updateShouldNotify(_GlassPanelScope oldWidget) => false;
}
