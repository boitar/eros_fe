import 'dart:math' as math;

import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/widget/canvas_grain.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// Window-local logical coordinates, never screen pixels or a theme heuristic.
@immutable
class MacOSWindowControls {
  const MacOSWindowControls({
    this.bounds = Rect.zero,
    this.systemSafeTop = 0,
    this.isKeyWindow = true,
  });
  const MacOSWindowControls.unknown()
    : bounds = const Rect.fromLTWH(8, 8, 64, 16),
      systemSafeTop = 0,
      isKeyWindow = true;
  factory MacOSWindowControls.fromMessage(Object? value) {
    if (value is! Map) return const MacOSWindowControls.unknown();
    Rect? union;
    for (final item in (value['buttons'] as List? ?? const [])) {
      if (item is! Map || item['hidden'] == true) {
        continue;
      }
      final coordinates = [item['x'], item['y'], item['width'], item['height']];
      if (coordinates.any((v) => v is! num || !v.isFinite)) {
        continue;
      }
      final rect = Rect.fromLTWH(
        (coordinates[0] as num).toDouble(),
        (coordinates[1] as num).toDouble(),
        (coordinates[2] as num).toDouble(),
        (coordinates[3] as num).toDouble(),
      );
      if (rect.isEmpty || rect.bottom <= 0) {
        continue;
      }
      union = union == null ? rect : union.expandToInclude(rect);
    }
    final safe = value['safeTop'];
    return MacOSWindowControls(
      bounds: union ?? Rect.zero,
      systemSafeTop: safe is num && safe.isFinite
          ? math.max(0, safe.toDouble())
          : 0,
      isKeyWindow: value['keyWindow'] != false,
    );
  }
  final Rect bounds;
  final double systemSafeTop;
  final bool isKeyWindow;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MacOSWindowControls &&
          bounds == other.bounds &&
          systemSafeTop == other.systemSafeTop &&
          isKeyWindow == other.isKeyWindow;

  @override
  int get hashCode => Object.hash(bounds, systemSafeTop, isKeyWindow);

  double get leading => bounds.isEmpty ? 0 : bounds.right + bounds.height / 2;
  double get top =>
      bounds.isEmpty ? 0 : math.max(0, bounds.bottom) + bounds.height / 2;
}

abstract final class MacOSWindowChrome {
  static const channel = MethodChannel('eros/window-chrome');
  static final controls = ValueNotifier(const MacOSWindowControls.unknown());

  /// Whether the window is in its own fullscreen space.
  static final fullscreen = ValueNotifier(false);
  static VoidCallback? manageGroups;
  static (String, String)? _menuLabels;

  static Future<void> configureBrowseMenu(String title, String manage) async {
    if (_menuLabels == (title, manage)) return;
    try {
      await channel.invokeMethod<void>('browseMenu', {
        'title': title,
        'manage': manage,
      });
      _menuLabels = (title, manage);
    } on MissingPluginException {
      /* Widget hosts have no native menu. */
    }
  }

  static void _apply(Object? message) {
    controls.value = MacOSWindowControls.fromMessage(message);
    fullscreen.value = message is Map && message['fullscreen'] == true;
  }

  static Future<void> initialize() async {
    if (PlatformCapabilities.hostPlatform != TargetPlatform.macOS) {
      return;
    }
    channel.setMethodCallHandler((call) async {
      if (call.method == 'manageGroups') {
        manageGroups?.call();
      } else if (call.method == 'changed') {
        _apply(call.arguments);
      }
    });
    try {
      _apply(
        await channel
            .invokeMethod<Object?>('get')
            .timeout(const Duration(seconds: 2)),
      );
    } catch (_) {
      controls.value = const MacOSWindowControls.unknown();
    }
  }

  /// Enters or leaves the fullscreen space, like the green window button.
  static Future<void> toggleFullscreen() async {
    if (PlatformCapabilities.hostPlatform != TargetPlatform.macOS) {
      return;
    }
    try {
      await channel.invokeMethod<void>('toggleFullScreen');
    } on MissingPluginException {
      // Older native hosts lack the method; the green button still works.
    }
  }
}

/// The window stays in one coordinate system. Ordinary routes receive a safe
/// inset; the desktop browse shell consumes it locally in the sidebar/left pane.
/// Drag targets belong to toolbar whitespace, never an overlay above controls.
class MacOSWindowContent extends StatelessWidget {
  const MacOSWindowContent({super.key, required this.child, this.dragRegion});
  final Widget child;
  // Retained for source compatibility; page chrome owns local drag targets.
  final Widget? dragRegion;
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<MacOSWindowControls>(
        valueListenable: MacOSWindowChrome.controls,
        builder: (context, controls, _) => LayoutBuilder(
          builder: (context, constraints) {
            final media = MediaQuery.of(context);
            final safeTop = math
                .max(
                  media.viewPadding.top,
                  math.max(controls.top, controls.systemSafeTop),
                )
                .clamp(0.0, constraints.maxHeight);
            final environment =
                AdaptiveEnvironment.maybeOf(context) ??
                AdaptiveEnvironmentSnapshot.fromMediaQuery(context);
            final contentEnvironment = environment.copyWithGeometry(
              safeArea: media.padding.copyWith(top: safeTop),
              viewPadding: media.viewPadding.copyWith(top: safeTop),
              viewInsets: media.viewInsets,
            );
            return Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    key: const ValueKey('macos-window-canvas'),
                    color: CupertinoTheme.of(context).scaffoldBackgroundColor,
                    child: const CanvasGrain(child: SizedBox.expand()),
                  ),
                ),
                Positioned.fill(
                  key: const ValueKey('macos-window-content'),
                  child: AdaptiveEnvironmentScope(
                    snapshot: contentEnvironment,
                    child: MediaQuery(
                      data: media.copyWith(
                        padding: media.padding.copyWith(top: safeTop),
                        viewPadding: media.viewPadding.copyWith(top: safeTop),
                      ),
                      child: child,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
}
