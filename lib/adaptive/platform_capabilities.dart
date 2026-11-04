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

  /// AppKit remains unavailable until its platform-view plugin is installed.
  static NativeGlassBackend get nativeGlassBackend =>
      hostPlatform == TargetPlatform.iOS
          ? NativeGlassBackend.uiKit
          : NativeGlassBackend.none;

  static bool get nativeGlass => nativeGlassBackend != NativeGlassBackend.none;
  static bool get uiKitGlass => nativeGlassBackend == NativeGlassBackend.uiKit;
  static bool get glassStyle => switch (hostPlatform) {
        TargetPlatform.iOS ||
        TargetPlatform.android ||
        TargetPlatform.macOS ||
        TargetPlatform.windows =>
          true,
        _ => false,
      };

  /// iOS keeps its existing opt-in default; other supported platforms opt in.
  static bool get defaultGlassStyle => glassStyle && !uiKitGlass;
}

enum GlassMode {
  native,
  flutter,
  off;

  /// [performanceAllowsGlass] is the future automatic degradation hook.
  static GlassMode resolve(
      {required bool enabled, bool performanceAllowsGlass = true}) {
    if (!enabled ||
        !performanceAllowsGlass ||
        !PlatformCapabilities.glassStyle) {
      return off;
    }
    return PlatformCapabilities.nativeGlass ? native : flutter;
  }

  static GlassMode of(BuildContext context,
          {bool? enabled, bool performanceAllowsGlass = true}) =>
      resolve(
          enabled: enabled ?? GlassPreference.of(context),
          performanceAllowsGlass: performanceAllowsGlass);

  /// Components without a Flutter renderer must retain their existing UI.
  GlassMode forComponent({bool flutterImplemented = false}) =>
      this == flutter && !flutterImplemented ? off : this;
}

/// Optional inherited preference keeps the capability layer independent of DI.
class GlassPreference extends InheritedWidget {
  const GlassPreference(
      {super.key, required this.enabled, required super.child});
  final bool enabled;
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassPreference>()?.enabled ??
      true;
  @override
  bool updateShouldNotify(GlassPreference oldWidget) =>
      enabled != oldWidget.enabled;
}
