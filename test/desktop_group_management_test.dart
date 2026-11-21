import 'dart:io';

import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/controller/tag_controller.dart';
import 'package:eros_fe/common/controller/webdav_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/tab/controller/group/custom_tabbar_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/pages/tab/fetch_list.dart';
import 'package:eros_fe/pages/tab/view/tabbar/custom_profile_setting_page.dart';
import 'package:eros_fe/pages/tab/view/tabbar/custom_profiles_page.dart';
import 'package:eros_fe/store/hive/hive.dart';
import 'package:eros_fe/widget/desktop_browse_style.dart';
import 'package:eros_fe/widget/desktop_control.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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
  bool get debugMode => false;
  @override
  final Rx<ListModeEnum> listMode = ListModeEnum.list.obs;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected setting access: ${invocation.memberName}');
}

class _Tabs extends GetxController implements TabHomeController {
  @override
  void resetTabTapSequence() {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected tab access: ${invocation.memberName}');
}

class _Webdav extends GetxController implements WebdavController {
  @override
  bool get syncGroupProfile => false;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected sync call: ${invocation.memberName}');
}

class _Tags extends GetxController implements TagController {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected tag call: ${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late hive.Box<String> config;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('eros-desktop-groups-');
    hive.Hive.init(root.path);
    config = await hive.Hive.openBox<String>(configBox, bytes: Uint8List(0));
  });

  tearDownAll(() async {
    await hive.Hive.close();
    await root.delete(recursive: true);
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    PlatformCapabilities.debugHostPlatformOverride = null;
    Get.reset();
    await config.clear();
  });

  Future<CustomTabbarController> mountProfiles(
    WidgetTester tester, {
    required TargetPlatform platform,
    Brightness brightness = Brightness.light,
    List<CustomProfile>? items,
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    PlatformCapabilities.debugHostPlatformOverride = platform;
    Get.testMode = true;
    Get.put<EhSettingService>(_Settings());
    Get.put<TagController>(_Tags());
    Get.put<TabHomeController>(_Tabs());
    Get.put<WebdavController>(_Webdav());
    Global.profile = kDefProfile.copyWith(
      customTabConfig: CustomTabConfig(
        lastIndex: 0,
        profiles:
            items ??
            [
              CustomProfile(
                uuid: 'pop-1',
                name: 'Popular Feed',
                listTypeValue: GalleryListType.popular.name,
              ),
              CustomProfile(
                uuid: 'gal-2',
                name: 'Chinese',
                listTypeValue: GalleryListType.gallery.name,
                listModeValue: ListModeEnum.waterfall.name,
                cats: 2, // Doujinshi excluded -> 9/10 included
                searchText: const ['l:chinese', 'o:anthology', 'full_color'],
                enableAdvance: true,
              ),
              CustomProfile(
                uuid: 'wat-3',
                name: 'Watched Hidden',
                listTypeValue: GalleryListType.watched.name,
                hideTab: true,
              ),
            ],
      ).oN,
    );
    Get.put(ThemeService());
    final controller = Get.put(CustomTabbarController());

    addTearDown(() async {
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    await tester.pumpWidget(
      CupertinoApp(
        key: ValueKey('$platform-$brightness'),
        locale: const Locale('en'),
        localizationsDelegates: const [
          L10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: L10n.delegate.supportedLocales,
        theme: CupertinoThemeData(brightness: brightness),
        home: const CustomProfilesPage(),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  for (final platform in [TargetPlatform.macOS, TargetPlatform.windows]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets(
        'Desktop CustomProfilesPage on $platform ($brightness) uses 48px header and shows metadata',
        (tester) async {
          await mountProfiles(tester, platform: platform, brightness: brightness);

          expect(find.byType(SettingGlassBar), findsNothing);
          expect(find.byType(DesktopPaneHeader), findsOneWidget);
          expect(
            tester.getSize(find.byType(DesktopPaneHeader)).height,
            DesktopBrowseStyle.toolbarHeight,
          );
          expect(find.text('Manage Groups'), findsOneWidget);
          expect(find.text('3'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('desktop-groups-add')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('desktop-groups-reorder')),
            findsOneWidget,
          );

          expect(find.text('Current group'), findsOneWidget);
          expect(find.text('Waterfall', findRichText: true), findsNothing);
          expect(find.text('· Waterfall'), findsOneWidget);
          expect(find.text('Categories 9/10'), findsOneWidget);
          expect(find.text('l:chinese'), findsOneWidget);
          expect(find.text('o:anthology'), findsOneWidget);
          expect(find.text('+1'), findsOneWidget);
          expect(find.text('Advanced Options'), findsOneWidget);
          expect(find.text('Hide'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          debugDefaultTargetPlatformOverride = null;
          PlatformCapabilities.debugHostPlatformOverride = null;
        },
      );
    }
  }

  testWidgets(
    'Desktop CustomProfilesPage reveals hover actions, confirms delete, and supports reorder steppers',
    (tester) async {
      final controller = await mountProfiles(
        tester,
        platform: TargetPlatform.macOS,
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      addTearDown(mouse.removePointer);

      await mouse.moveTo(
        tester.getCenter(find.byKey(const ValueKey('desktop-group-card-gal-2'))),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('desktop-group-edit-gal-2')),
        findsOneWidget,
      );
      final deleteBtn = find.byKey(
        const ValueKey('desktop-group-delete-gal-2'),
      );
      expect(deleteBtn, findsOneWidget);

      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      await tester.tap(
        find.widgetWithText(CupertinoDialogAction, 'Delete'),
      );
      await tester.pumpAndSettle();

      expect(controller.profiles.map((e) => e.uuid).toList(), [
        'pop-1',
        'wat-3',
      ]);

      await tester.tap(find.byKey(const ValueKey('desktop-groups-reorder')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('desktop-groups-reorder-done')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('desktop-group-up-wat-3')));
      await tester.pumpAndSettle();
      expect(controller.profiles.map((e) => e.uuid).toList(), [
        'wat-3',
        'pop-1',
      ]);

      await tester.tap(
        find.byKey(const ValueKey('desktop-groups-reorder-done')),
      );
      await tester.pumpAndSettle();
      expect(controller.reorderable, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
      PlatformCapabilities.debugHostPlatformOverride = null;
    },
  );

  testWidgets('iOS keeps SettingScaffold on CustomProfilesPage', (
    tester,
  ) async {
    await mountProfiles(tester, platform: TargetPlatform.iOS);
    expect(find.byType(SettingScaffold), findsOneWidget);
    expect(find.byType(DesktopPaneHeader), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
    PlatformCapabilities.debugHostPlatformOverride = null;
  });

  testWidgets(
    'Desktop CustomProfileSettingPage updates title, removes keywords inline, and returns saved profile',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.windows;
      Get.testMode = true;
      Get.put<EhSettingService>(_Settings());
      Get.put<TagController>(_Tags());
      Get.put<TabHomeController>(_Tabs());
      Get.put<WebdavController>(_Webdav());
      const edited = CustomProfile(
        uuid: 'gal-edit',
        name: 'Original Group',
        searchText: ['l:chinese', 'o:anthology'],
      );
      Global.profile = kDefProfile.copyWith(
        customTabConfig: const CustomTabConfig(profiles: [edited]).oN,
      );
      Get.put(ThemeService());
      Get.put(CustomTabbarController());
      Get.replace<CustomProfile>(edited);

      CustomProfile? poppedResult;

      await tester.pumpWidget(
        CupertinoApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            L10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: L10n.delegate.supportedLocales,
          home: Builder(
            builder: (context) => CupertinoButton(
              onPressed: () async {
                poppedResult = await Navigator.of(context).push<CustomProfile>(
                  CupertinoPageRoute(
                    builder: (_) => const CustomProfileSettingPage(),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingGlassBar), findsNothing);
      expect(find.byType(DesktopPaneHeader), findsOneWidget);
      expect(find.text('Original Group'), findsWidgets);
      expect(
        find.byKey(const ValueKey('desktop-profile-delete')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('desktop-profile-name-input')),
        'Renamed Group',
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(DesktopPaneHeader),
          matching: find.text('Renamed Group'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('desktop-search-text-remove-o:anthology')),
      );
      await tester.pumpAndSettle();
      expect(find.text('o:anthology'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('desktop-profile-save')));
      await tester.pumpAndSettle();

      expect(poppedResult, isNotNull);
      expect(poppedResult!.name, 'Renamed Group');
      expect(poppedResult!.searchText, ['l:chinese']);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
      PlatformCapabilities.debugHostPlatformOverride = null;
    },
  );
}
