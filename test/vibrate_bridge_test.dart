import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Settings extends GetxService implements EhSettingService {
  @override
  final vibrate = true.obs;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected haptic setting');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('eros/haptics');
  const legacy = MethodChannel('vibrate');
  const vibration = MethodChannel('vibration');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _Settings settings;
  late List<MethodCall> nativeCalls, legacyCalls, systemCalls, vibrationCalls;
  setUp(() {
    Get.testMode = true;
    settings = Get.put<EhSettingService>(_Settings()) as _Settings;
    nativeCalls = [];
    legacyCalls = [];
    systemCalls = [];
    vibrationCalls = [];
    for (final item in [
      (native, nativeCalls),
      (legacy, legacyCalls),
      (SystemChannels.platform, systemCalls),
      (vibration, vibrationCalls)
    ]) {
      messenger.setMockMethodCallHandler(item.$1, (call) async {
        item.$2.add(call);
        return call.method.startsWith('has') ? false : null;
      });
    }
  });
  tearDown(() {
    for (final channel in [
      native,
      legacy,
      SystemChannels.platform,
      vibration
    ]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    Get.reset();
  });

  Future<void> everyMethod(VibrateUtil util) async {
    await util.impact();
    await util.light();
    await util.medium();
    await util.heavy();
    await util.success();
    await util.error();
    await util.selection();
    await util.tabSwitch();
    await util.prepareHaptics();
    await util.pullTick(.5);
  }

  test('iOS native feedback calls return with their existing style names',
      () async {
    final util = VibrateUtil(platform: TargetPlatform.iOS);
    await util.impact();
    await util.light();
    await util.medium();
    await util.heavy();
    await util.success();
    await util.error();
    await util.tabSwitch();
    await util.selection();
    expect(nativeCalls.map((c) => c.method), [
      'impact',
      'light',
      'medium',
      'heavy',
      'success',
      'error',
      'tabSwitch',
      'selection'
    ]);
    expect(legacyCalls, isEmpty);
    // Selection ticks use the app's retained generator, not Flutter's.
    expect(systemCalls, isEmpty);
  });

  test('disabled iOS and Android feedback produce no plugin or platform calls',
      () async {
    settings.vibrate.value = false;
    await everyMethod(VibrateUtil(platform: TargetPlatform.iOS));
    await everyMethod(VibrateUtil(platform: TargetPlatform.android));
    expect([...nativeCalls, ...legacyCalls, ...systemCalls, ...vibrationCalls],
        isEmpty);
  });

  test('progressive iOS ticks prewarm once, clamp progress and ramp parameters',
      () async {
    final util = VibrateUtil(platform: TargetPlatform.iOS);
    await util.pullTick(-1);
    await util.pullTick(.5);
    await util.pullTick(2);
    expect(
        nativeCalls.map((c) => c.method), ['prepare', 'tick', 'tick', 'tick']);
    final args = nativeCalls.skip(1).map((c) => c.arguments as Map).toList();
    expect(args[0]['intensity'], closeTo(.2, 1e-9));
    expect(args[1]['intensity'], closeTo(.55, 1e-9));
    expect(args[2]['intensity'], closeTo(.9, 1e-9));
    expect(args[0]['sharpness'], closeTo(.9, 1e-9));
    expect(args[2]['sharpness'], closeTo(.4, 1e-9));
    expect(systemCalls, isEmpty);
  });

  test('explicit new pull sessions can rewarm an already used engine',
      () async {
    final util = VibrateUtil(platform: TargetPlatform.iOS);
    await util.prepareHaptics();
    await util.pullTick(.2);
    await util.prepareHaptics();
    await util.pullTick(.2);
    expect(nativeCalls.map((c) => c.method),
        ['prepare', 'tick', 'prepare', 'tick']);
  });

  test('a missing progressive bridge falls back once for each tick', () async {
    messenger.setMockMethodCallHandler(
        native, (_) async => throw MissingPluginException());
    final util = VibrateUtil(platform: TargetPlatform.iOS);
    await util.pullTick(.2);
    await util.pullTick(.4);
    expect(systemCalls.map((c) => c.method),
        ['HapticFeedback.vibrate', 'HapticFeedback.vibrate']);
    expect(systemCalls.map((c) => c.arguments),
        ['HapticFeedbackType.lightImpact', 'HapticFeedbackType.lightImpact']);
  });

  test('failed bridge, fallback and style plugins cannot fail their UI action',
      () async {
    for (final channel in [native, legacy, SystemChannels.platform]) {
      messenger.setMockMethodCallHandler(
          channel,
          (_) async =>
              throw PlatformException(code: 'unsupported-test-device'));
    }
    await expectLater(
        everyMethod(VibrateUtil(platform: TargetPlatform.iOS)), completes);
  });

  test('unsupported desktop targets safely skip every feedback path', () async {
    for (final platform in [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.fuchsia
    ]) {
      await everyMethod(VibrateUtil(platform: platform));
    }
    expect([...nativeCalls, ...legacyCalls, ...systemCalls, ...vibrationCalls],
        isEmpty);
  });

  test(
      'Android selection and pull ticks use platform feedback without the iOS bridge',
      () async {
    final util = VibrateUtil(platform: TargetPlatform.android);
    await util.selection();
    await util.pullTick(.5);
    expect(nativeCalls, isEmpty);
    expect(legacyCalls, isEmpty);
    expect(systemCalls.map((c) => c.arguments), [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.lightImpact'
    ]);
  });
}
