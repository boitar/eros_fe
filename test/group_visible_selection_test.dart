import 'dart:io';
import 'dart:typed_data';

import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/controller/tag_controller.dart';
import 'package:eros_fe/common/controller/webdav_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/tab/controller/group/custom_tabbar_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/pages/tab/view/tabbar/custom_tabbar_page.dart';
import 'package:eros_fe/store/hive/hive.dart';
import 'package:eros_fe/widget/desktop_browse_style.dart';
import 'package:eros_fe/widget/desktop_control.dart';
import 'package:eros_fe/widget/desktop_gallery_actions.dart';
import 'package:eros_fe/widget/desktop_gallery_toolbar.dart';
import 'package:eros_fe/widget/desktop_sidebar.dart';
import 'package:eros_fe/widget/macos_window_chrome.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart' as hive;

class _Settings extends GetxService implements EhSettingService {
  @override
  bool get liquidGlass => _glass.value;
  final _glass = false.obs;
  @override
  bool get isPureDarkTheme => false;
  @override
  RxBool get pureDarkThemeObs => false.obs;
  @override
  bool get liquidGlassMaterial => true;
  @override
  final Rx<ListModeEnum> listMode = ListModeEnum.list.obs;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected group setting');
}

class _Tags extends GetxController implements TagController {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected tag access');
}

class _Tabs extends GetxController implements TabHomeController {
  @override
  void resetTabTapSequence() {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected main tab access');
}

class _Webdav extends GetxController implements WebdavController {
  @override
  bool get syncGroupProfile => false;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected cloud sync');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late hive.Box<String> config;
  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('eros-group-selection-');
    hive.Hive.init(root.path);
    config = await hive.Hive.openBox<String>(configBox, bytes: Uint8List(0));
  });
  tearDownAll(() async {
    await hive.Hive.close();
    await root.delete(recursive: true);
  });

  const profiles = [
    CustomProfile(uuid: 'a', name: 'Visible A'),
    CustomProfile(uuid: 'b', name: 'Hidden B', hideTab: true),
    CustomProfile(uuid: 'c', name: 'Visible C'),
    CustomProfile(uuid: 'd', name: 'Visible D'),
  ];

  Future<CustomTabbarController> mount(
    WidgetTester tester, {
    int savedIndex = 0,
    List<CustomProfile> items = profiles,
    bool attach = true,
    bool useBar = false,
    bool preserveProfileList = false,
  }) async {
    Get.testMode = true;
    Get.put<EhSettingService>(_Settings());
    Get.put<TagController>(_Tags());
    Get.put<TabHomeController>(_Tabs());
    Get.put<WebdavController>(_Webdav());
    Global.profile = kDefProfile.copyWith(
      customTabConfig: CustomTabConfig(
        profiles: preserveProfileList ? items : List.of(items),
        lastIndex: savedIndex,
      ).oN,
    );
    Get.put(ThemeService());
    final controller = Get.put(
      CustomTabbarController()..pageController = PageController(),
    );
    addTearDown(() async {
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
      Get.reset();
      await config.clear();
    });
    if (attach) {
      controller.pageController.dispose();
      controller.pageController = PageController(initialPage: controller.index);
      await tester.pumpWidget(
        CupertinoApp(
          home: Column(
            children: [
              if (useBar) CustomTabBar(controller: controller),
              Expanded(
                child: Obx(
                  () => PageView(
                    key: const PageStorageKey('custom-visible-group-pages'),
                    controller: controller.pageController,
                    onPageChanged: controller.onPageChanged,
                    children: controller.profilesShow
                        .map((profile) => Center(child: Text(profile.uuid)))
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (useBar) {
        expect(tester.takeException(), isNull);
      }
    }
    return controller;
  }

  testWidgets('compact gallery toolbar clears the live macOS window controls', (
    tester,
  ) async {
    final controller = await mount(tester, attach: false);
    final previousControls = MacOSWindowChrome.controls.value;
    addTearDown(() {
      MacOSWindowChrome.controls.value = previousControls;
      PlatformCapabilities.debugHostPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.devicePixelRatio = 1;
    const controls = MacOSWindowControls(bounds: Rect.fromLTWH(8, 8, 60, 14));
    MacOSWindowChrome.controls.value = controls;
    Future<void> render(TargetPlatform host, {required bool wide}) async {
      PlatformCapabilities.debugHostPlatformOverride = host;
      tester.view.physicalSize = Size(wide ? 900 : 400, 400);
      await tester.pumpWidget(
        CupertinoApp(
          localizationsDelegates: const [
            L10n.delegate,
            GlobalMaterialLocalizations.delegate,
          ],
          home: DesktopSidebarScope(
            desktop: wide,
            visible: wide,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                height: 44,
                child: DesktopGalleryToolbar(controller: controller),
              ),
            ),
          ),
        ),
      );
    }

    final group = find.ancestor(
      of: find.text('Visible A'),
      matching: find.byType(DesktopControl),
    );
    await render(TargetPlatform.macOS, wide: false);
    expect(tester.getRect(group).left, greaterThan(controls.bounds.right));
    expect(tester.getRect(group).center.dy, 22);
    MacOSWindowChrome.controls.value = const MacOSWindowControls();
    await tester.pump();
    final unobstructed = tester.getRect(group).left;
    expect(unobstructed, lessThan(controls.bounds.left));

    MacOSWindowChrome.controls.value = controls;
    await render(TargetPlatform.macOS, wide: true);
    expect(tester.getRect(group).left, unobstructed);
    await render(TargetPlatform.windows, wide: false);
    expect(tester.getRect(group).left, unobstructed);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop toolbar keeps right cluster flush and restores sidebar on macOS and Windows',
    (tester) async {
      final controller = await mount(tester, attach: false);
      final previousControls = MacOSWindowChrome.controls.value;
      addTearDown(() {
        MacOSWindowChrome.controls.value = previousControls;
        PlatformCapabilities.debugHostPlatformOverride = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(960, 500);
      const controls = MacOSWindowControls(bounds: Rect.fromLTWH(22, 24, 54, 16));
      MacOSWindowChrome.controls.value = controls;

      for (final host in [TargetPlatform.macOS, TargetPlatform.windows]) {
        PlatformCapabilities.debugHostPlatformOverride = host;
        var restores = 0;
        await tester.pumpWidget(
          CupertinoApp(
            localizationsDelegates: const [
              L10n.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: L10n.delegate.supportedLocales,
            home: DesktopSidebarScope(
              desktop: true,
              visible: false,
              onShow: () => restores++,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 440,
                  height: DesktopBrowseStyle.toolbarHeight,
                  child: DesktopGalleryToolbar(controller: controller),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final toolbarRect = tester.getRect(find.byType(DesktopGalleryToolbar));
        final restoreFinder = find.byKey(const ValueKey('desktop-show-sidebar'));
        final moreFinder = find.byKey(const ValueKey('desktop-more-actions'));
        expect(restoreFinder, findsOneWidget);
        expect(moreFinder, findsOneWidget);
        expect(
          find.byKey(const ValueKey('desktop-jump-page')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('desktop-refresh-list')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('desktop-view-list')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('desktop-display-mode')),
          findsOneWidget,
        );

        if (host == TargetPlatform.macOS) {
          expect(
            tester.getRect(restoreFinder).left,
            greaterThanOrEqualTo(controls.leading - DesktopBrowseStyle.inset),
          );
        }
        expect(
          toolbarRect.right - tester.getRect(moreFinder).right,
          lessThanOrEqualTo(12),
        );

        await tester.tap(restoreFinder);
        await tester.pump();
        expect(restores, 1);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'desktop toolbar segmented view switch and group menu update active state',
    (tester) async {
      final controller = await mount(tester, useBar: false);
      addTearDown(() => PlatformCapabilities.debugHostPlatformOverride = null);
      PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.windows;

      await tester.pumpWidget(
        GetCupertinoApp(
          localizationsDelegates: const [
            L10n.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: L10n.delegate.supportedLocales,
          home: DesktopSidebarScope(
            desktop: true,
            visible: true,
            child: Column(
              children: [
                SizedBox(
                  height: DesktopBrowseStyle.toolbarHeight,
                  child: DesktopGalleryToolbar(controller: controller),
                ),
                Expanded(
                  child: Obx(
                    () => PageView(
                      controller: controller.pageController,
                      onPageChanged: controller.onPageChanged,
                      children: controller.profilesShow
                          .map((p) => Center(child: Text(p.uuid)))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.currentListMode, ListModeEnum.list);
      await tester.tap(find.byKey(const ValueKey('desktop-display-mode')));
      await tester.pumpAndSettle();
      expect(controller.currentListMode, ListModeEnum.grid);

      await tester.tap(find.byKey(const ValueKey('desktop-view-list')));
      await tester.pumpAndSettle();
      expect(controller.currentListMode, ListModeEnum.list);

      await tester.tap(find.byKey(const ValueKey('desktop-group-menu')));
      await tester.pumpAndSettle();
      expect(find.byType(DesktopGalleryMenu), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('desktop-menu-Visible D')));
      await tester.pumpAndSettle();
      expect(controller.currProfileUuid, 'd');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'traditional group rail excludes hidden profiles and selects its actual page',
    (tester) async {
      final controller = await mount(tester, useBar: true);
      expect(find.text('Hidden B'), findsNothing);
      await tester.tap(find.text('Visible D'));
      await tester.pumpAndSettle();
      expect(controller.currProfileUuid, 'd');
      expect(controller.index, 2);
      expect(controller.pageController.page, 2);
      expect(find.text('d'), findsOneWidget);
    },
  );

  testWidgets(
    'display mode changes copy const profiles and keep the loaded list',
    (tester) async {
      final controller = await mount(
        tester,
        attach: false,
        preserveProfileList: true,
      );
      final before = controller.profiles.singleWhere(
        (profile) => profile.uuid == 'a',
      );

      await controller.setGroupListMode('a', ListModeEnum.gridTags);

      expect(controller.profileMap['a']!.listMode, ListModeEnum.gridTags);
      expect(controller.profiles, hasLength(profiles.length));
      expect(
        controller.profiles.singleWhere((profile) => profile.uuid == 'a'),
        isNot(same(before)),
      );
      expect(
        Global.profile.customTabConfig!.profiles!
            .singleWhere((profile) => profile.uuid == 'a')
            .listMode,
        ListModeEnum.gridTags,
      );
    },
  );

  testWidgets(
    'selecting after the traditional rail is removed keeps the actual page',
    (tester) async {
      final controller = await mount(tester, useBar: true);
      await tester.pumpWidget(
        CupertinoApp(
          home: Obx(
            () => PageView(
              controller: controller.pageController,
              onPageChanged: controller.onPageChanged,
              children: controller.profilesShow
                  .map((profile) => Center(child: Text(profile.uuid)))
                  .toList(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final selection = controller.selectPage(2);
      await tester.pumpAndSettle();
      await selection;
      expect(controller.currProfileUuid, 'd');
      expect(controller.index, 2);
      expect(controller.pageController.page, 2);
      expect(find.text('d'), findsOneWidget);
    },
  );

  testWidgets('a tapped group stays selected while its page passes others', (
    tester,
  ) async {
    final controller = await mount(tester, useBar: true);
    await tester.pumpWidget(
      CupertinoApp(
        home: Obx(
          () => PageView(
            controller: controller.pageController,
            onPageChanged: controller.onPageChanged,
            children: controller.profilesShow
                .map((profile) => Center(child: Text(profile.uuid)))
                .toList(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.index, 0);
    final selection = controller.selectPage(2);
    expect(controller.index, 2);
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.index, 2, reason: 'frame $frame');
    }
    await tester.pumpAndSettle();
    await selection;
    expect(controller.currProfileUuid, 'd');
    expect(controller.pageController.page, 2);
  });

  testWidgets('a visible page index skips a hidden middle group', (
    tester,
  ) async {
    final controller = await mount(tester);
    controller.pageController.jumpToPage(1);
    await tester.pumpAndSettle();
    expect(controller.index, 1);
    expect(controller.currProfileUuid, 'c');
    expect(find.text('c'), findsOneWidget);
  });

  testWidgets('restored indices refer to visible groups', (tester) async {
    final controller = await mount(tester, savedIndex: 2, attach: false);
    expect(controller.index, 2);
    expect(controller.currProfileUuid, 'd');
  });

  testWidgets('an oversized saved index clamps to the visible list', (
    tester,
  ) async {
    final controller = await mount(tester, savedIndex: 99, attach: false);
    expect(controller.index, 2);
    expect(controller.currProfileUuid, 'd');
  });

  testWidgets(
    'reordering retains the selected UUID and its real visible page',
    (tester) async {
      final controller = await mount(tester, savedIndex: 2);
      final reordering = controller.onReorder(3, 0);
      await tester.pump(const Duration(milliseconds: 250));
      await reordering;
      await tester.pumpAndSettle();
      expect(controller.currProfileUuid, 'd');
      expect(controller.index, 0);
      expect(controller.pageController.page, 0);
      expect(find.text('d'), findsOneWidget);
    },
  );

  testWidgets(
    'deleting the current group selects its nearest visible neighbor',
    (tester) async {
      final controller = await mount(tester);
      controller.onPageChanged(1);
      final deleting = controller.deleteProfile(uuid: 'c');
      await tester.pump(const Duration(milliseconds: 250));
      await deleting;
      await tester.pumpAndSettle();
      expect(controller.currProfileUuid, 'd');
      expect(controller.index, 1);
      expect(controller.pageController.page, 1);
      expect(find.text('d'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('hiding the current group keeps page and UUID consistent', (
    tester,
  ) async {
    final controller = await mount(tester);
    controller.pageController.jumpToPage(1);
    await tester.pumpAndSettle();
    controller.profiles[2] = controller.profiles[2].copyWith(hideTab: true.oN);
    await tester.pumpAndSettle();
    expect(controller.currProfileUuid, 'd');
    expect(controller.index, 1);
    expect(find.text('d'), findsOneWidget);
  });

  testWidgets('invalid page notifications preserve the current selection', (
    tester,
  ) async {
    final controller = await mount(tester, attach: false);
    controller.onPageChanged(-1);
    controller.onPageChanged(99);
    expect(controller.index, 0);
    expect(controller.currProfileUuid, 'a');
  });

  testWidgets('reorder before a page is attached is safe', (tester) async {
    final controller = await mount(tester, savedIndex: 2, attach: false);
    final reordering = controller.onReorder(3, 0);
    await tester.pump(const Duration(milliseconds: 250));
    await reordering;
    expect(controller.index, 0);
    expect(controller.currProfileUuid, 'd');
  });

  testWidgets(
    'deleting the selected final page after reorder reveals its real neighbor',
    (tester) async {
      final controller = await mount(tester, savedIndex: 1);
      await controller.onReorder(3, 0);
      await tester.pumpAndSettle();
      expect(controller.currProfileUuid, 'c');
      expect(controller.pageController.page, 2);
      final deletion = controller.deleteProfile(uuid: 'c');
      await tester.pump(const Duration(milliseconds: 250));
      await deletion;
      await tester.pumpAndSettle();
      expect(controller.currProfileUuid, 'a');
      expect(controller.pageController.page, 1);
      expect(find.text('a'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('empty imported groups clear selection and ignore page events', (
    tester,
  ) async {
    final controller = await mount(
      tester,
      items: const [],
      savedIndex: 99,
      attach: false,
    );
    controller.onPageChanged(0);
    expect(controller.index, 0);
    expect(controller.currProfileUuid, isEmpty);
  });

  testWidgets('deleting the last visible group clears selection', (
    tester,
  ) async {
    final controller = await mount(
      tester,
      items: profiles.take(2).toList(),
      attach: false,
    );
    final deleting = controller.deleteProfile(uuid: 'a');
    await tester.pump(const Duration(milliseconds: 250));
    await deleting;
    await tester.pumpAndSettle();
    expect(controller.profilesShow, isEmpty);
    expect(controller.index, 0);
    expect(controller.currProfileUuid, isEmpty);
    await tester.pump(const Duration(seconds: 3));
  });
}
