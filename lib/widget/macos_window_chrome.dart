import 'dart:math' as math;
import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/widget/canvas_grain.dart';
import 'package:eros_fe/widget/detail_window_backdrop.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// Window-local logical coordinates, never screen pixels or a theme heuristic.
@immutable
class MacOSWindowControls {
  const MacOSWindowControls({this.bounds = Rect.zero});
  factory MacOSWindowControls.fromMessage(Object? value) {
    if (value is! Map || value['fullscreen'] == true) {
      return const MacOSWindowControls();
    }
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
    return MacOSWindowControls(bounds: union ?? Rect.zero);
  }
  final Rect bounds;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MacOSWindowControls && bounds == other.bounds;

  @override
  int get hashCode => bounds.hashCode;

  double get leading => bounds.isEmpty ? 0 : bounds.right + bounds.height / 2;
  double get top =>
      bounds.isEmpty ? 0 : math.max(0, bounds.bottom) + bounds.height / 2;
}

abstract final class MacOSWindowChrome {
  static const channel = MethodChannel('eros/window-chrome');
  static final controls = ValueNotifier(const MacOSWindowControls());

  /// Whether the window is in its own fullscreen space.
  static final fullscreen = ValueNotifier(false);

  static void _apply(Object? message) {
    controls.value = MacOSWindowControls.fromMessage(message);
    fullscreen.value = message is Map && message['fullscreen'] == true;
  }

  static Future<void> initialize() async {
    if (PlatformCapabilities.hostPlatform != TargetPlatform.macOS) {
      return;
    }
    channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') {
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
      controls.value = const MacOSWindowControls();
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

/// Reserve the measured titlebar band once, outside all pages and split panes.
/// This also protects off-mode/custom headers which don't consume SafeArea.
class MacOSWindowContent extends StatelessWidget {
  const MacOSWindowContent({super.key, required this.child, this.dragRegion});
  final Widget child;
  final Widget? dragRegion;
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<MacOSWindowControls>(
        valueListenable: MacOSWindowChrome.controls,
        builder: (context, controls, _) => ValueListenableBuilder<bool>(
          valueListenable: DetailWindowBackdrop.active,
          builder: (context, transparent, _) => LayoutBuilder(
            builder: (context, constraints) {
              final media = MediaQuery.of(context);
              final band = controls.top.clamp(0.0, constraints.maxHeight);
              final top = transparent ? 0.0 : band;
              final safeTop = transparent ? band : 0.0;
              final environment = AdaptiveEnvironment.maybeOf(context) ??
                  AdaptiveEnvironmentSnapshot.fromMediaQuery(context);
              final contentEnvironment = environment
                  .inRect(
                    Rect.fromLTWH(
                      0,
                      top,
                      media.size.width,
                      math.max(0, media.size.height - top),
                    ),
                  )
                  .copyWithGeometry(
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
                      // Window chrome shares the page canvas, including its
                      // grain. An independent glass surface changes this tint.
                      child: const CanvasGrain(child: SizedBox.expand()),
                    ),
                  ),
                  // Preserve the Navigator/SmartDialog Overlay when entering
                  // fullscreen or switching to a detail backdrop.
                  Positioned.fill(
                    key: const ValueKey('macos-window-content'),
                    top: top,
                    child: AdaptiveEnvironmentScope(
                      snapshot: contentEnvironment,
                      child: MediaQuery(
                        data: media.copyWith(
                          size: Size(
                            media.size.width,
                            math.max(0, media.size.height - top),
                          ),
                          padding: media.padding.copyWith(top: safeTop),
                          viewPadding: media.viewPadding.copyWith(top: safeTop),
                        ),
                        child: child,
                      ),
                    ),
                  ),
                  if (band > 0 && dragRegion != null)
                    Positioned(
                      top: 0,
                      left: controls.leading,
                      right: 0,
                      height: band,
                      child: dragRegion!,
                    ),
                ],
              );
            },
          ),
        ),
      );
}
