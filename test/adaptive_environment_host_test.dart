import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const events = MethodChannel(AdaptiveEnvironmentService.eventChannelName);
  const methods = MethodChannel(AdaptiveEnvironmentService.methodChannelName);

  for (final host in <TargetPlatform>[
    TargetPlatform.android,
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    testWidgets('$host host uses Flutter geometry without native channels', (
      tester,
    ) async {
      PlatformCapabilities.debugHostPlatformOverride = host;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final calls = <String>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(events, (call) async {
        calls.add(call.method);
        return null;
      });
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call.method);
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(events, null);
        messenger.setMockMethodCallHandler(methods, null);
        PlatformCapabilities.debugHostPlatformOverride = null;
        debugDefaultTargetPlatformOverride = null;
      });

      final service = AdaptiveEnvironmentService();
      try {
        service.onInit();
        await service.refreshNativeSnapshot();
        await tester.pump();
        expect(calls, isEmpty);
        expect(service.snapshot.value.size, Size.zero);
        expect(service.snapshot.value.nativeSupported, isFalse);
        service.onClose();
        await tester.pump();
      } finally {
        PlatformCapabilities.debugHostPlatformOverride = null;
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets('iOS host subscribes and receives native geometry', (
    tester,
  ) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.iOS;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(events, (call) async {
      calls.add(call.method);
      return null;
    });
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call.method);
      return <String, Object>{'width': 500.0, 'height': 600.0};
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(events, null);
      messenger.setMockMethodCallHandler(methods, null);
      PlatformCapabilities.debugHostPlatformOverride = null;
      debugDefaultTargetPlatformOverride = null;
    });

    final service = AdaptiveEnvironmentService();
    try {
      service.onInit();
      await tester.pump();
      expect(calls, contains('listen'));
      await messenger.handlePlatformMessage(
        events.name,
        const StandardMethodCodec().encodeSuccessEnvelope(<String, Object>{
          'width': 390.0,
          'height': 844.0,
        }),
        (_) {},
      );
      await tester.pump();
      expect(service.snapshot.value.size, const Size(390, 844));
      await service.refreshNativeSnapshot();
      expect(calls, contains('getSnapshot'));
      expect(service.snapshot.value.size, const Size(500, 600));
      service.onClose();
      await tester.pump();
      expect(calls, contains('cancel'));
    } finally {
      PlatformCapabilities.debugHostPlatformOverride = null;
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
