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
    const channel = MethodChannel('vibration');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return false;
    });
    try {
      await VibrateUtil().medium();
      expect(calls, isEmpty);
    } finally {
      messenger.setMockMethodCallHandler(channel, null);
      Get.reset();
    }
  });
}
