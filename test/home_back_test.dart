import 'dart:io';

import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/pages/tab/view/home_page_large.dart';
import 'package:eros_fe/route/main_observer.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

const _channel = MethodChannel('eros/native-navigation');

void main() {
  late _Home home;
  late List<MethodCall> platform;

  Future<void> mount(WidgetTester tester) async {
    Get.testMode = true;
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
    Get.put<LocaleService>(LocaleService());
    Get.put<EhSettingService>(_Settings());
    Get.put<ThemeService>(_Theme());
    final layout = Get.put<LayoutServices>(_Layout());
    home = Get.put<TabHomeController>(_Home()) as _Home;
    home.tabNameList.assignAll([EHRoutes.gallery, EHRoutes.favorite]);
    home.tabMap.assignAll({EHRoutes.gallery: true, EHRoutes.favorite: true});
    Get.put(ControllerTagService());
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (call) async => call.method == 'getShellState' ? false : null,
    );
    platform = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platform.add(call);
        return null;
      },
    );
    const size = Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    MainNavigatorObserver().resetHistory();
    addTearDown(() {
      NativeNavigationBridge.enabled.value = false;
      PlatformCapabilities.debugHostPlatformOverride = null;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _channel,
        null,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      Get.reset();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    layout.layoutMode = LayoutMode.small;
    await tester.pumpWidget(
      GetCupertinoApp(
        localizationsDelegates: const [L10n.delegate],
        navigatorObservers: [MainNavigatorObserver()],
        // The same scope HomePage puts around the tabs.
        home: PopScope(
          canPop: false,
          onPopInvokedWithResult: home.onPopInvokedWithResult,
          child: AdaptiveEnvironmentScope(
            snapshot: const AdaptiveEnvironmentSnapshot(size: size),
            child: TabHomeLarge(
              split: false,
              destinationBuilder: (_, route) => CupertinoPageScaffold(
                child: Center(child: Text('$route root')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// What Android sends for the back button or an edge swipe.
  Future<void> systemBack(WidgetTester tester) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
      (_) {},
    );
    await tester.pumpAndSettle();
  }

  bool exited() => platform.any((c) => c.method == 'SystemNavigator.pop');

  bool? frameworkHandlesBack() =>
      platform
              .lastWhere(
                (c) => c.method == 'SystemNavigator.setFrameworkHandlesBack',
                orElse: () => const MethodCall('none'),
              )
              .arguments
          as bool?;

  testWidgets('back closes a pushed page, then needs two backs to leave', (
    tester,
  ) async {
    await mount(tester);
    Get.to<void>(
      () => const CupertinoPageScaffold(child: Center(child: Text('detail'))),
      id: detailNavigatorId,
    );
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);

    await systemBack(tester);
    expect(find.text('detail'), findsNothing);
    expect(find.text('/gallery root'), findsOneWidget);
    expect(home.hints, 0);

    await systemBack(tester);
    expect(home.hints, 1, reason: 'the first back at home only warns');
    expect(exited(), isFalse);

    await systemBack(tester);
    expect(exited(), isTrue);
  });

  testWidgets('another tab returns to the gallery before any exit', (
    tester,
  ) async {
    await mount(tester);
    await home.onTap(1, useLiquidGlass: false);
    await tester.pumpAndSettle();
    expect(home.currRoute, EHRoutes.favorite);

    await systemBack(tester);
    expect(home.currRoute, EHRoutes.gallery);
    expect(home.hints, 0);
    expect(exited(), isFalse);

    await systemBack(tester);
    expect(home.hints, 1);
    expect(exited(), isFalse);
    await systemBack(tester);
    expect(exited(), isTrue);
  });

  testWidgets('a slow second back warns again instead of leaving', (
    tester,
  ) async {
    await mount(tester);
    await systemBack(tester);
    home.lastPressedAt = DateTime.now().subtract(const Duration(seconds: 3));
    await systemBack(tester);
    expect(home.hints, 2);
    expect(exited(), isFalse);
  });

  testWidgets('the framework, not the system, owns back at the home root', (
    tester,
  ) async {
    // With predictive back on Android 16 the system finishes the activity
    // whenever Flutter says it cannot handle back.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await mount(tester);
    expect(frameworkHandlesBack(), isTrue);
    debugDefaultTargetPlatformOverride = null;
  });

  test('HomePage keeps the system from popping the home route', () {
    final source = File('lib/pages/tab/view/home_page.dart').readAsStringSync();
    expect(source, contains('canPop: false'));
    expect(
      source,
      contains('onPopInvokedWithResult: controller.onPopInvokedWithResult'),
    );
    expect(source, isNot(contains('WillPopScope')));
  });
}

class _Layout extends LayoutServices {
  // Stubs skip the service setup on purpose.
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Settings extends EhSettingService {
  // Stubs skip the service setup on purpose.
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Theme extends ThemeService {
  // Stubs skip the service setup on purpose.
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Home extends TabHomeController {
  int hints = 0;

  // Stubs skip the service setup on purpose.
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  void showExitHint() => hints++;
}
