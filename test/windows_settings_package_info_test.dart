import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/tab/controller/setting_controller.dart';
import 'package:eros_fe/pages/tab/view/setting_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/waterfall_fixture.dart';

void main() {
  setUp(() {
    registerWaterfallFixture();
    Get.put<LayoutServices>(_Layout());
    Get.put(SettingViewController());
  });

  tearDown(() {
    PlatformCapabilities.debugHostPlatformOverride = null;
    Get.reset();
  });

  testWidgets('Windows SettingTab renders even when packageInfo uses default', (
    tester,
  ) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 820);
    addTearDown(tester.view.reset);

    // Must not throw LateInitializationError when read before init completes.
    expect(() => Global.packageInfo.version, returnsNormally);

    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('en'),
        supportedLocales: L10n.delegate.supportedLocales,
        localizationsDelegates: const [
          L10n.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: const MediaQuery(
          data: MediaQueryData(size: Size(420, 820)),
          child: SettingTab(),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SettingTab), findsOneWidget);
    expect(find.text(L10n.current.tab_setting), findsWidgets);
    expect(find.text(L10n.current.appearance_and_layout), findsOneWidget);
    expect(find.text(L10n.current.about), findsOneWidget);
  });
}

class _Layout extends LayoutServices {
  @override
  // ignore: must_call_super
  void onInit() {}
}
