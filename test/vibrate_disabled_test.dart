import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _DisabledSettings extends GetxService implements EhSettingService {
  @override
  final vibrate = false.obs;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected disabled haptic setting');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('disabled medium feedback never probes or calls a vibration plugin',
      () async {
    Get.testMode = true;
    Get.put<EhSettingService>(_DisabledSettings());
    final calls = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call.method);
      return false;
    });
    try {
      PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
      await VibrateUtil().medium();
      expect(calls, isEmpty);
    } finally {
      PlatformCapabilities.debugHostPlatformOverride = null;
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      Get.reset();
    }
  });
}
