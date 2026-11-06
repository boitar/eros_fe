import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/global.dart' show deviceInfo;
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'logger.dart';

final VibrateUtil vibrateUtil = VibrateUtil();

class VibrateUtil {
  VibrateUtil({TargetPlatform? platform, Future<int> Function()? androidSdkInt})
      : _platformOverride = platform,
        _androidSdkInt = androidSdkInt ?? _readAndroidSdkInt;

  final TargetPlatform? _platformOverride;
  final Future<int> Function() _androidSdkInt;
  static Future<int> _readAndroidSdkInt() async =>
      (await deviceInfo.androidInfo).version.sdkInt;

  Future<bool> _supportsAndroidNotifications() async {
    try {
      return await _androidSdkInt() >= 30;
    } catch (error) {
      logger.t('Android SDK version unavailable: $error');
      return false;
    }
  }

  TargetPlatform? get _platform =>
      _platformOverride ?? PlatformCapabilities.hostPlatform;
  static const MethodChannel _hapticsChannel = MethodChannel('eros/haptics');
  bool _hapticsPrepared = false;

  bool get _isIOS => _platform == TargetPlatform.iOS;
  bool get _isAndroid => _platform == TargetPlatform.android;
  bool get _vibrateOn =>
      !Get.isRegistered<EhSettingService>() ||
      Get.find<EhSettingService>().vibrate.value;

  // Decorative feedback must never interrupt the operation it accompanies.
  Future<void> _run(Future<void> Function() action) async {
    if (!_vibrateOn || (!_isIOS && !_isAndroid)) {
      return;
    }
    try {
      await action();
    } catch (error) {
      logger.t('Haptic feedback unavailable: $error');
    }
  }

  Future<void> impact() => _run(() async {
        if (_isIOS) {
          await _hapticsChannel.invokeMethod<void>('impact');
        } else {
          await HapticFeedback.mediumImpact();
        }
      });

  Future<void> light() => _run(() async {
        if (_isIOS) {
          await _hapticsChannel.invokeMethod<void>('light');
        } else {
          await HapticFeedback.lightImpact();
        }
      });

  Future<void> medium() => _run(() async {
        if (_isIOS) {
          await _hapticsChannel.invokeMethod<void>('medium');
        } else {
          await HapticFeedback.mediumImpact();
        }
      });

  Future<void> heavy() => _run(() async {
        if (_isIOS) {
          await _hapticsChannel.invokeMethod<void>('heavy');
        } else {
          await HapticFeedback.heavyImpact();
        }
      });

  Future<void> success() => _run(() async {
        if (_isIOS) {
          await _hapticsChannel.invokeMethod<void>('success');
        } else if (await _supportsAndroidNotifications()) {
          await HapticFeedback.successNotification();
        } else {
          await HapticFeedback.mediumImpact();
        }
      });

  Future<void> error() => _run(() async {
        if (_isIOS) {
          await _hapticsChannel.invokeMethod<void>('error');
        } else if (await _supportsAndroidNotifications()) {
          await HapticFeedback.errorNotification();
        } else {
          await HapticFeedback.heavyImpact();
        }
      });

  /// A picker-like tick. On iOS it uses the app's retained generator rather
  /// than Flutter's, which builds an unprepared one for every tick.
  Future<void> selection() => _run(() async {
        if (_isIOS) {
          await _hapticsChannel.invokeMethod<void>('selection');
        } else {
          await HapticFeedback.selectionClick();
        }
      });

  /// Switching tabs in any tab bar: a crisp glass click on iOS, the light
  /// pulse elsewhere.
  Future<void> tabSwitch() => _run(() async {
        if (_isIOS) {
          await _hapticsChannel.invokeMethod<void>('tabSwitch');
        } else {
          await HapticFeedback.lightImpact();
        }
      });

  Future<void> pullTick(double progress) => _run(() async {
        if (_isIOS) {
          final p = progress.clamp(0.0, 1.0).toDouble();
          await _coreHapticsTick(
            intensity: 0.2 + 0.7 * p,
            sharpness: 0.9 - 0.5 * p,
          );
        } else {
          await HapticFeedback.selectionClick();
        }
      });

  /// Prewarm each new pull session without producing a pulse.
  Future<void> prepareHaptics() async {
    if (!_vibrateOn || !_isIOS) {
      return;
    }
    _hapticsPrepared = true;
    try {
      await _hapticsChannel.invokeMethod<void>('prepare');
    } catch (error) {
      logger.t('Haptics prepare unavailable: $error');
    }
  }

  Future<void> _coreHapticsTick({
    required double intensity,
    required double sharpness,
  }) async {
    if (!_hapticsPrepared) {
      await prepareHaptics();
    }
    try {
      await _hapticsChannel.invokeMethod<void>('tick', <String, double>{
        'intensity': intensity,
        'sharpness': sharpness,
      });
    } catch (error) {
      logger.t('Haptics tick unavailable: $error');
      await HapticFeedback.lightImpact();
    }
  }
}
