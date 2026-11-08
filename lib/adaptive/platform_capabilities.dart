import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Native renderers are independent of Flutter's theme platform.
enum NativeGlassBackend { none, uiKit, appKit }

abstract final class PlatformCapabilities {
  @visibleForTesting
  static TargetPlatform? debugHostPlatformOverride;

  static TargetPlatform? get hostPlatform {
    if (kDebugMode && debugHostPlatformOverride != null) {
      return debugHostPlatformOverride;
    }
    if (kIsWeb) {
      return null;
    }
    if (Platform.isIOS) {
      return TargetPlatform.iOS;
    }
    if (Platform.isAndroid) {
      return TargetPlatform.android;
    }
    if (Platform.isMacOS) {
      return TargetPlatform.macOS;
    }
    if (Platform.isWindows) {
      return TargetPlatform.windows;
    }
    if (Platform.isLinux) {
      return TargetPlatform.linux;
    }
    return null;
  }

  /// Set only after the real macOS plugin confirms OS and view-factory support.
  static final ValueNotifier<bool> appKitAvailable = ValueNotifier(false);
  static bool appKitMenuAvailable = false;
  static bool get appKitGlass =>
      nativeGlassBackend == NativeGlassBackend.appKit;

  /// AppKit is runtime negotiated; a theme override never enables a plugin.
  static NativeGlassBackend get nativeGlassBackend =>
      hostPlatform == TargetPlatform.iOS
      ? NativeGlassBackend.uiKit
      : hostPlatform == TargetPlatform.macOS && appKitAvailable.value
      ? NativeGlassBackend.appKit
      : NativeGlassBackend.none;

  static bool get nativeGlass => nativeGlassBackend != NativeGlassBackend.none;
  static bool get uiKitGlass => nativeGlassBackend == NativeGlassBackend.uiKit;
  static bool get glassStyle => switch (hostPlatform) {
    TargetPlatform.iOS ||
    TargetPlatform.android ||
    TargetPlatform.macOS ||
    TargetPlatform.windows => true,
    _ => false,
  };

  /// Android puts search in a capsule at the top of list pages instead of a
  /// separate button beside the bottom bar, leaving the bar five destinations.
  static bool get topSearchCapsule => hostPlatform == TargetPlatform.android;

  /// iOS keeps its existing opt-in default; other supported platforms opt in.
  static bool get defaultGlassStyle => glassStyle && !uiKitGlass;
}

enum GlassMode {
  native,
  flutter,
  off;

  /// [performanceAllowsGlass] is the future automatic degradation hook.
  static GlassMode resolve({
    required bool enabled,
    bool performanceAllowsGlass = true,
  }) {
    if (!enabled ||
        !performanceAllowsGlass ||
        !PlatformCapabilities.glassStyle) {
      return off;
    }
    return PlatformCapabilities.nativeGlass ? native : flutter;
  }

  static GlassMode of(
    BuildContext context, {
    bool? enabled,
    bool performanceAllowsGlass = true,
  }) => _resolveContext(context, enabled, performanceAllowsGlass);

  static GlassMode _resolveContext(
    BuildContext context,
    bool? enabled,
    bool performanceAllowsGlass,
  ) {
    context.dependOnInheritedWidgetOfExactType<GlassCapabilityScope>();
    return resolve(
      enabled: enabled ?? GlassPreference.of(context),
      performanceAllowsGlass: performanceAllowsGlass,
    );
  }

  /// Components without a Flutter renderer must retain their existing UI.
  GlassMode forComponent({
    bool flutterImplemented = false,
    Set<NativeGlassBackend> nativeBackends = const {NativeGlassBackend.uiKit},
  }) {
    if (this == off) {
      return off;
    }
    if (this == native &&
        nativeBackends.contains(PlatformCapabilities.nativeGlassBackend)) {
      return native;
    }
    return flutterImplemented ? flutter : off;
  }
}

/// The material every glass surface uses while the glass effect is on.
///
/// Each renderer maps it to its own implementation: the refractive shader or
/// the lightweight frosted one in Flutter, `UIGlassEffect` or `UIBlurEffect`
/// in UIKit, `NSGlassEffectView` or `NSVisualEffectView` in AppKit.
enum GlassMaterial {
  /// Refraction and specular highlights; the heavier renderer.
  liquid,

  /// A frosted blur; cheaper to draw.
  frosted;

  bool get isLiquid => this == liquid;

  static GlassMaterial? tryParse(String? name) {
    for (final material in values) {
      if (material.name == name) {
        return material;
      }
    }
    return null;
  }

  /// A stored material wins; older profiles only kept the "system Liquid
  /// Glass appearance" switch, whose off state drew the frosted blur.
  static GlassMaterial migrate({String? stored, bool? legacyFollowSystem}) =>
      tryParse(stored) ?? (legacyFollowSystem == false ? frosted : liquid);
}

/// Optional inherited preference keeps the capability layer independent of DI.
class GlassPreference extends InheritedWidget {
  const GlassPreference({
    super.key,
    required this.enabled,
    this.material = GlassMaterial.liquid,
    required super.child,
  });
  final bool enabled;
  final GlassMaterial material;
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassPreference>()?.enabled ??
      true;
  static GlassMaterial materialOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassPreference>()?.material ??
      GlassMaterial.liquid;
  @override
  bool updateShouldNotify(GlassPreference oldWidget) =>
      enabled != oldWidget.enabled || material != oldWidget.material;
}

/// Rebuilds component decisions when the negotiated native backend fails or changes.
class GlassCapabilityScope extends InheritedNotifier<ValueNotifier<bool>> {
  GlassCapabilityScope({super.key, required super.child})
    : super(notifier: PlatformCapabilities.appKitAvailable);
}
