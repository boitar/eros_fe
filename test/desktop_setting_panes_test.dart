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
    String stackId = EHRoutes.setting,
  }) async {
    Get.testMode = true;
    PlatformCapabilities.debugHostPlatformOverride = host;
    layout = Get.put<LayoutServices>(_Layout());
    layout.layoutMode = mode;
    controller = Get.put(SettingViewController());
    final owner = Object();
    final navigation = layout.mountNavigation(owner);
    final stack = navigation.select(stackId);
    addTearDown(() {
      PlatformCapabilities.debugHostPlatformOverride = null;
      layout.unmountNavigation(owner, navigation);
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
      // Only desktop uses the post-sidebar result for its global pane logic.
      layout.updateNavigationSplit(false);
      expect(layout.isLayoutLarge, mode == LayoutMode.large);
      controller.syncDesktopPane();
      await tester.pumpAndSettle();
      expect(pane(), <String>[EHRoutes.empty]);
      expect(controller.openCategory.value, isNull);
    });
  }

  testWidgets(
    'iOS split syncs selected category and account without auto-opening when empty',
    (tester) async {
      await pump(tester, host: TargetPlatform.iOS, mode: LayoutMode.large);

      // Empty pane stays empty on iOS split view.
      controller.syncPane(split: true);
      await tester.pumpAndSettle();
      expect(pane(), <String>[EHRoutes.empty]);
      expect(controller.openCategory.value, isNull);

      // Opening a category selects it and keeps it selected across sub-pages.
      controller.open(EHRoutes.layoutSetting, split: true);
      await tester.pumpAndSettle();
      expect(pane(), <String>[EHRoutes.empty, EHRoutes.layoutSetting]);
      expect(controller.openCategory.value, EHRoutes.layoutSetting);

      Get.toNamed<void>(
        EHRoutes.itemWidthSetting,
        id: layout.tabNavigation.selected!.detailId,
      );
      await tester.pumpAndSettle();
      controller.syncPane(split: true);
      expect(controller.openCategory.value, EHRoutes.layoutSetting);

      // Switching categories replaces both the old category and any non-/setting/ sub-page.
      controller.open(EHRoutes.advancedSetting, split: true);
      await tester.pumpAndSettle();
      expect(pane(), <String>[EHRoutes.empty, EHRoutes.advancedSetting]);
      expect(controller.openCategory.value, EHRoutes.advancedSetting);

      Get.toNamed<void>(
        EHRoutes.customHosts,
        id: layout.tabNavigation.selected!.detailId,
      );
      await tester.pumpAndSettle();
      controller.syncPane(split: true);
      expect(controller.openCategory.value, EHRoutes.advancedSetting);

      // Opening account session selects account and replaces previous sub-pages.
      controller.open(EHRoutes.accountSession, split: true);
      await tester.pumpAndSettle();
      expect(pane(), <String>[EHRoutes.empty, EHRoutes.accountSession]);
      controller.syncPane(split: true);
      expect(controller.openCategory.value, EHRoutes.accountSession);

      // Popping back to empty clears selection without auto-reopening.
      Get.nestedKey(layout.tabNavigation.selected!.detailId)!
          .currentState!
          .pop();
      await tester.pumpAndSettle();
      controller.syncPane(split: true);
      await tester.pumpAndSettle();
      expect(pane(), <String>[EHRoutes.empty]);
      expect(controller.openCategory.value, isNull);

      // Switching to single-column clears any active selection.
      controller.open(EHRoutes.about, split: true);
      await tester.pumpAndSettle();
      expect(controller.openCategory.value, EHRoutes.about);
      controller.syncPane(split: false);
      expect(controller.openCategory.value, isNull);
    },
  );

  testWidgets('Android large layout keeps openCategory null', (tester) async {
    await pump(tester, host: TargetPlatform.android, mode: LayoutMode.large);
    controller.open(EHRoutes.layoutSetting);
    await tester.pumpAndSettle();
    expect(pane(), <String>[EHRoutes.empty, EHRoutes.layoutSetting]);
    controller.syncPane(split: true);
    expect(controller.openCategory.value, isNull);
  });

  testWidgets('desktop safe mode never reopens the normal account page', (
    tester,
  ) async {
    await pump(tester, stackId: 'safe:${EHRoutes.setting}');
    controller.lastCategory = EHRoutes.accountSession;

    controller.syncPane(split: true);
    await tester.pumpAndSettle();
    expect(pane(), <String>[EHRoutes.empty, EHRoutes.layoutSetting]);
    expect(controller.openCategory.value, EHRoutes.layoutSetting);
    expect(controller.lastCategory, EHRoutes.accountSession);

    controller.open(EHRoutes.readSetting, split: true);
    await tester.pumpAndSettle();
    expect(pane(), <String>[EHRoutes.empty, EHRoutes.readSetting]);
    expect(controller.openCategory.value, EHRoutes.readSetting);
    expect(controller.lastCategory, EHRoutes.accountSession);
  });

  testWidgets('Android large layout keeps its legacy nested route behavior', (
    tester,
  ) async {
    await pump(tester, host: TargetPlatform.android);
    controller.open(EHRoutes.advancedSetting);
    await tester.pumpAndSettle();
    Get.toNamed<void>(
      EHRoutes.customHosts,
      id: layout.tabNavigation.selected!.detailId,
    );
    await tester.pumpAndSettle();

    controller.open(EHRoutes.searchSetting);
    await tester.pumpAndSettle();
    expect(pane(), <String>[
      EHRoutes.empty,
      EHRoutes.advancedSetting,
      EHRoutes.customHosts,
      EHRoutes.searchSetting,
    ]);
    expect(controller.openCategory.value, isNull);
  });
}

class _Layout extends LayoutServices {
  // Stubs skip the service setup on purpose.
  @override
  // ignore: must_call_super
  void onInit() {}
}
