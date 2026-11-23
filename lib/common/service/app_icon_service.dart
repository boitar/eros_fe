import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// User-selectable launcher and window icon styles.
enum EhAppIconStyle {
  auto,
  light,
  dark,
  purple;

  static EhAppIconStyle parse(String? raw) {
    if (raw == 'monochrome') {
      return EhAppIconStyle.auto;
    }
    for (final value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    return EhAppIconStyle.auto;
  }
}

/// Bridges [EhAppIconStyle] selections to the native `eros/app_icon` channel.
abstract final class AppIconService {
  static const MethodChannel channel = MethodChannel('eros/app_icon');

  static Future<void> setAppIcon(EhAppIconStyle style) async {
    try {
      await channel.invokeMethod<void>('setAppIcon', style.name);
    } on MissingPluginException catch (error) {
      debugPrint('AppIconService.setAppIcon skipped (no plugin): $error');
    } on PlatformException catch (error) {
      debugPrint('AppIconService.setAppIcon failed: $error');
    }
  }

  /// Restores desktop dock/window icons at launch without calling mobile
  /// icon-switching APIs (which can trigger OS alerts or restarts).
  ///
  /// Windows always syncs at startup (including `auto`) so dark-mode systems
  /// immediately swap the default light exe icon to the dark variant; macOS
  /// uses its bundle's native adaptive `AppIcon.icon` automatically for `auto`.
  static Future<void> syncStartupIcon(EhAppIconStyle style) async {
    if (!PlatformCapabilities.isDesktop) {
      return;
    }
    if (PlatformCapabilities.hostPlatform == TargetPlatform.windows) {
      await setAppIcon(style);
      return;
    }
    if (style != EhAppIconStyle.auto) {
      await setAppIcon(style);
    }
  }
}
