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

  static Widget wrap(Widget child,
          {bool enabled = true,
          GlassMaterial material = GlassMaterial.liquid}) =>
      PlatformCapabilities.uiKitGlass
          ? child
          : GlassCapabilityScope(child: GlassPreference(
              enabled: enabled,
              material: material,
              child: available
                  ? LiquidGlassWidgets.wrap(
                      child: child,
                      adaptiveQuality: false,
                      // Package widgets without an explicit quality (the tab
                      // bar defaults to premium) follow the chosen material.
                      theme: themeFor(material))
                  : child));

  @visibleForTesting
  static GlassThemeData themeFor(GlassMaterial material) => GlassThemeData(
        light: GlassThemeVariant.light.copyWith(quality: material.quality),
        dark: GlassThemeVariant.dark.copyWith(quality: material.quality),
      );
}

extension FlutterGlassMaterial on GlassMaterial {
  /// The refractive Impeller shader, or the lightweight frosted shader.
  GlassQuality get quality =>
      isLiquid ? GlassQuality.premium : GlassQuality.standard;
}

/// One refractive surface per local control group. Selection indicators inside
/// it use a plain tint, retaining their gestures without double refraction.
class FlutterGlassPanel extends StatefulWidget {
  const FlutterGlassPanel(
      {super.key, required this.child, required this.borderRadius});
  final Widget child;
  final BorderRadius borderRadius;

  @override
  State<FlutterGlassPanel> createState() => _FlutterGlassPanelState();
}

class _FlutterGlassPanelState extends State<FlutterGlassPanel> {
  /// Liquid and frosted glass are different render subtrees; the key moves
  /// the content across a material change so scroll offsets, focus and other
  /// state inside the panel survive it.
  final GlobalKey _content = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final content = KeyedSubtree(key: _content, child: widget.child);
    if (context.dependOnInheritedWidgetOfExactType<_GlassPanelScope>() !=
        null) {
      return DecoratedBox(
        decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            color: CupertinoDynamicColor.resolve(
                CupertinoColors.tertiarySystemFill, context)),
        child: content,
      );
    }
    return _GlassPanelScope(
        child: GlassContainer(
      useOwnLayer: true,
      quality: GlassPreference.materialOf(context).quality,
      shape: LiquidRoundedSuperellipse(
          borderRadius: widget.borderRadius.topLeft.x),
      child: content,
    ));
  }
}

class _GlassPanelScope extends InheritedWidget {
  const _GlassPanelScope({required super.child});
  @override
  bool updateShouldNotify(_GlassPanelScope oldWidget) => false;
}
