import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/pages/tab/controller/setting_controller.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  late LayoutServices layout;
  late SettingViewController controller;

  List<String?> pane() => layout.tabNavigation.selected!.detailObserver.history
      .map((route) => route.settings.name)
      .toList();

  Future<void> pump(
    WidgetTester tester, {
    TargetPlatform host = TargetPlatform.macOS,
    LayoutMode mode = LayoutMode.large,
  }) async {
    Get.testMode = true;
    PlatformCapabilities.debugHostPlatformOverride = host;
    layout = Get.put<LayoutServices>(_Layout());
    layout.layoutMode = mode;
    controller = Get.put(SettingViewController());
    final stack = layout.tabNavigation.select(EHRoutes.setting);
    addTearDown(() {
      PlatformCapabilities.debugHostPlatformOverride = null;
      // Observers are shared by navigator id; start each test clean.
      layout.tabNavigation.reset();
      Get.reset();
    });
    await tester.pumpWidget(
      CupertinoApp(
        home: Navigator(
          key: Get.nestedKey(stack.detailId),
          observers: <NavigatorObserver>[stack.detailObserver],
          // Like the app's detail navigator: one empty page, no '/' root.
          onGenerateInitialRoutes: (_, _) => <Route<void>>[
            PageRouteBuilder<void>(
              settings: const RouteSettings(name: EHRoutes.empty),
              pageBuilder: (_, _, _) => const SizedBox.expand(),
            ),
          ],
          onGenerateRoute: (settings) => PageRouteBuilder<void>(
            settings: settings,
            pageBuilder: (_, _, _) => const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('a category is the first settings page on the stack', () {
    Route<void> route(String name) => PageRouteBuilder<void>(
      settings: RouteSettings(name: name),
      pageBuilder: (_, _, _) => const SizedBox(),
    );
    expect(
      SettingViewController.categoryIn(<Route<void>>[
        route(EHRoutes.empty),
        route(EHRoutes.layoutSetting),
        route(EHRoutes.itemWidthSetting),
      ]),
      EHRoutes.layoutSetting,
    );
    expect(
      SettingViewController.categoryIn(<Route<void>>[route(EHRoutes.empty)]),
      isNull,
    );
  });

  testWidgets('an empty desktop pane opens the last category', (tester) async {
    await pump(tester);
    expect(pane(), <String>[EHRoutes.empty]);

    controller.syncDesktopPane();
    await tester.pumpAndSettle();
    expect(pane(), <String>[EHRoutes.empty, EHRoutes.layoutSetting]);
    controller.syncDesktopPane();
    expect(controller.openCategory.value, EHRoutes.layoutSetting);

    // Going back from a category reopens it rather than leaving a blank pane.
    controller.open(EHRoutes.readSetting);
    await tester.pumpAndSettle();
    Get.nestedKey(layout.tabNavigation.selected!.detailId)!.currentState!.pop();
    await tester.pumpAndSettle();
    controller.syncDesktopPane();
    await tester.pumpAndSettle();
    expect(pane(), <String>[EHRoutes.empty, EHRoutes.readSetting]);
  });

  testWidgets('a category replaces the pages the pane had opened', (
    tester,
  ) async {
    await pump(tester);
    controller.open(EHRoutes.layoutSetting);
    await tester.pumpAndSettle();
    Get.toNamed<void>(
      EHRoutes.itemWidthSetting,
      id: layout.tabNavigation.selected!.detailId,
    );
    await tester.pumpAndSettle();
    controller.syncDesktopPane();
    // A page the category opened keeps the category selected.
    expect(controller.openCategory.value, EHRoutes.layoutSetting);

    controller.open(EHRoutes.searchSetting);
    await tester.pumpAndSettle();
    expect(pane(), <String>[EHRoutes.empty, EHRoutes.searchSetting]);
    controller.syncDesktopPane();
    expect(controller.openCategory.value, EHRoutes.searchSetting);
  });

  testWidgets('only the category page drops its back button', (tester) async {
    await pump(tester);
    controller.open(EHRoutes.layoutSetting);
    await tester.pumpAndSettle();
    Get.toNamed<void>(
      EHRoutes.itemWidthSetting,
      id: layout.tabNavigation.selected!.detailId,
    );
    await tester.pumpAndSettle();
    final history = layout.tabNavigation.selected!.detailObserver.history;
    expect(isDesktopSettingPaneRoot(history[1] as ModalRoute), isTrue);
    expect(isDesktopSettingPaneRoot(history[2] as ModalRoute), isFalse);

    // One column: the category is a page pushed over the list.
    layout.layoutMode = LayoutMode.small;
    expect(isDesktopSettingPaneRoot(history[1] as ModalRoute), isFalse);
  });

  for (final (host, mode) in <(TargetPlatform, LayoutMode)>[
    (TargetPlatform.iOS, LayoutMode.large),
    (TargetPlatform.android, LayoutMode.large),
    (TargetPlatform.macOS, LayoutMode.small),
  ]) {
    testWidgets('$host ${mode.name} keeps settings as pages', (tester) async {
      await pump(tester, host: host, mode: mode);
      controller.syncDesktopPane();
      await tester.pumpAndSettle();
      expect(pane(), <String>[EHRoutes.empty]);
      expect(controller.openCategory.value, isNull);
    });
  }
}

class _Layout extends LayoutServices {
  // Stubs skip the service setup on purpose.
  @override
  // ignore: must_call_super
  void onInit() {}
}
