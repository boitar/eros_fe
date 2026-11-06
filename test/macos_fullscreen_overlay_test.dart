import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/widget/macos_window_chrome.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Settings extends EhSettingService {
  @override
  // Avoid persistence and platform initialization in this focused fixture.
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  testWidgets('fullscreen preserves SmartDialog overlay and active route', (
    tester,
  ) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.macOS;
    Get.testMode = true;
    Get.put<LocaleService>(LocaleService());
    Get.put<EhSettingService>(_Settings());
    addTearDown(() async {
      PlatformCapabilities.debugHostPlatformOverride = null;
      MacOSWindowChrome.controls.value = const MacOSWindowControls();
      Get.reset();
    });
    const windowed = MacOSWindowControls(bounds: Rect.fromLTWH(10, 6, 60, 16));
    MacOSWindowChrome.controls.value = windowed;
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      CupertinoApp(
        navigatorKey: navigator,
        builder: FlutterSmartDialog.init(
          styleBuilder: (child) => MacOSWindowContent(
            dragRegion: const SizedBox.expand(),
            child: child,
          ),
        ),
        home: const CupertinoPageScaffold(child: Text('home')),
      ),
    );
    navigator.currentState!.push(
      CupertinoPageRoute<void>(
        builder: (_) => const CupertinoPageScaffold(child: Text('settings')),
      ),
    );
    await tester.pumpAndSettle();
    final overlay = tester.state(find.byType(Overlay).first);
    for (var i = 0; i < 3; i++) {
      MacOSWindowChrome.controls.value = const MacOSWindowControls();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.state(find.byType(Overlay).first), same(overlay));
      expect(find.text('settings'), findsOneWidget);
      MacOSWindowChrome.controls.value = windowed;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.state(find.byType(Overlay).first), same(overlay));
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
