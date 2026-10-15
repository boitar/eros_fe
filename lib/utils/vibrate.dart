import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:vibration/vibration.dart';

import 'logger.dart';

final VibrateUtil vibrateUtil = VibrateUtil();

class VibrateUtil {
  VibrateUtil({TargetPlatform? platform})
      : _platform = platform ?? defaultTargetPlatform;

  final TargetPlatform _platform;
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

  Future<void> _androidPulse(int duration,
      {int? amplitude, int? customDuration}) async {
    var amplitudeSupported = false;
    try {
      amplitudeSupported = await Vibration.hasAmplitudeControl();
    } catch (_) {}
    if (amplitudeSupported && amplitude != null) {
      await Vibration.vibrate(
          duration: customDuration ?? duration, amplitude: amplitude);
    } else {
      await Vibration.vibrate(duration: duration);
    }
  }

  Future<void> impact() => _run(() async {
        if (_isIOS) {
          await _hapticsChannel.invokeMethod<void>('impact');
        } else {
          await _androidPulse(2);
        }
      });

  Future<void> light() => _run(() async {
        if (_isIOS) {
          await _hapticsChannel.invokeMethod<void>('light');
        } else {
          await _androidPulse(5, amplitude: 100);
        }
      });

  Future<void> medium() => _run(() async {
        if (_isIOS) {
          await _hapticsChannel.invokeMethod<void>('medium');
        } else {
          await _androidPulse(20, amplitude: 120, customDuration: 15);
        }
      });

  Future<void> heavy() => _run(() async {
        if (_isIOS) {
          await _hapticsChannel.invokeMethod<void>('heavy');
        } else {
          await _androidPulse(35, amplitude: 255, customDuration: 10);
        }
      });

  Future<void> success() => _run(() async {
        if (_isIOS) {
          await _hapticsChannel.invokeMethod<void>('success');
        }
      });

  Future<void> error() => _run(() async {
        if (_isIOS) {
          await _hapticsChannel.invokeMethod<void>('error');
        }
      });

  Future<void> selection() => _run(HapticFeedback.selectionClick);

  Future<void> pullTick(double progress) => _run(() async {
        if (_isIOS) {
          final p = progress.clamp(0.0, 1.0).toDouble();
          await _coreHapticsTick(
            intensity: 0.2 + 0.7 * p,
            sharpness: 0.9 - 0.5 * p,
          );
        } else {
          await HapticFeedback.lightImpact();
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
