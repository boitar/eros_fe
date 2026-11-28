import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/theme_service.dart';
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

/// Material density preset for [FlutterGlassPanel].
enum FlutterGlassVariant {
  /// Default airy chrome material for controls, rails, and capsules.
  control,

  /// High-legibility material for text-bearing popups, menus, and sheets.
  readable,
}

/// One refractive surface per local control group. Selection indicators inside
/// it use a plain tint, retaining their gestures without double refraction.
class FlutterGlassPanel extends StatefulWidget {
  const FlutterGlassPanel({
    super.key,
    required this.child,
    required this.borderRadius,
    this.variant = FlutterGlassVariant.control,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final FlutterGlassVariant variant;

  /// High-legibility [LiquidGlassSettings] for text-bearing popups and menus.
  ///
  /// Uses [GlassBodyMode.clear] so the `0.78` light / `0.80` dark body tint is
  /// alpha-composited without backdrop luminance drift across both `liquid`
  /// ([GlassQuality.premium]) and `frosted` ([GlassQuality.standard]) modes,
  /// while retaining specular rim highlights, Fresnel sheen, and subtle bevel
  /// refraction.
  @visibleForTesting
  static LiquidGlassSettings readableSettingsFor(BuildContext context) {
    final dark = GlassTheme.brightnessOf(context) == Brightness.dark;
    if (dark) {
      final raised =
          CupertinoDynamicColor.resolve(ehTheme.palette.raised, context);
      return LiquidGlassSettings(
        bodyMode: GlassBodyMode.clear,
        glassColor: raised.withValues(alpha: 0.80),
        blur: 24.0,
        saturation: 1.0,
        thickness: 8.0,
        refractiveIndex: 1.14,
        chromaticAberration: 0.004,
        lightAngle: 2.356,
        lightIntensity: 0.72,
        ambientStrength: 0.0,
        fresnelStrength: 1.0,
      );
    }
    return const LiquidGlassSettings(
      bodyMode: GlassBodyMode.clear,
      glassColor: Color.fromRGBO(248, 248, 250, 0.78),
      blur: 24.0,
      saturation: 1.0,
      thickness: 8.0,
      refractiveIndex: 1.14,
      chromaticAberration: 0.005,
      lightAngle: 2.356,
      lightIntensity: 0.85,
      ambientStrength: 0.12,
      fresnelStrength: 1.0,
      shadow: <BoxShadow>[
        BoxShadow(
          color: Color(0x26000000),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
        BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    );
  }

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
        clipBehavior: widget.variant == FlutterGlassVariant.readable
            ? Clip.antiAlias
            : Clip.none,
        quality: GlassPreference.materialOf(context).quality,
        settings: widget.variant == FlutterGlassVariant.readable
            ? FlutterGlassPanel.readableSettingsFor(context)
            : null,
        shape: LiquidRoundedSuperellipse(
          borderRadius: widget.borderRadius.topLeft.x,
        ),
        child: content,
      ),
    );
  }
}

class _GlassPanelScope extends InheritedWidget {
  const _GlassPanelScope({required super.child});
  @override
  bool updateShouldNotify(_GlassPanelScope oldWidget) => false;
}
