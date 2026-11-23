import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/browse_layout.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/adaptive/tab_navigation.dart';
import 'package:eros_fe/common/service/desktop_ui_preferences.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/eh_layout.dart';
import 'package:eros_fe/pages/tab/view/home_page_large.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/widget/desktop_browse_style.dart';
import 'package:eros_fe/widget/desktop_sidebar.dart';
import 'package:eros_fe/widget/desktop_split_handle.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:quiver/core.dart';

class _TestLayoutServices extends LayoutServices {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _TestEhSettingService extends EhSettingService {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _TestThemeService extends ThemeService {
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  group('EhLayout serialization and copyWith', () {
    test('preserves sideProportion and settingSideProportion independently', () {
      const original = EhLayout(
        sideProportion: 0.55,
        settingSideProportion: 0.25,
      );

      final roundTripped = EhLayout.fromJson(original.toJson());
      expect(roundTripped, original);
      expect(roundTripped.hashCode, original.hashCode);
      expect(roundTripped.sideProportion, 0.55);
      expect(roundTripped.settingSideProportion, 0.25);

      final updatedSetting = original.copyWith(
        settingSideProportion: Optional.of(0.42),
      );
      expect(updatedSetting.sideProportion, 0.55);
      expect(updatedSetting.settingSideProportion, 0.42);
      expect(updatedSetting, isNot(original));

      final updatedBrowse = original.copyWith(
        sideProportion: Optional.of(0.75),
      );
      expect(updatedBrowse.sideProportion, 0.75);
      expect(updatedBrowse.settingSideProportion, 0.25);

      final cloned = updatedSetting.clone();
      expect(cloned, updatedSetting);
      expect(cloned.sideProportion, 0.55);
      expect(cloned.settingSideProportion, 0.42);
    });

    test('omitted settingSideProportion parses as null and defaults service to 0.0', () {
      final legacy = EhLayout.fromJson(const {'sideProportion': 0.6});
      expect(legacy.sideProportion, 0.6);
      expect(legacy.settingSideProportion, isNull);

      final layout = _TestLayoutServices();
      expect(layout.settingSideProportion, 0.0);
    });
  });

  group('LayoutServices settings split isolation', () {
    test('isolates setting and safe setting stacks from browse stacks', () {
      expect(LayoutServices.isSettingStack(EHRoutes.setting), isTrue);
      expect(LayoutServices.isSettingStack('safe:${EHRoutes.setting}'), isTrue);
      expect(LayoutServices.isSettingStack(EHRoutes.gallery), isFalse);
      expect(LayoutServices.isSettingStack(EHRoutes.favorite), isFalse);
      expect(LayoutServices.isSettingStack(null), isFalse);

      final layout = _TestLayoutServices();
      layout.sideProportion = 0.55;
      expect(layout.settingSideProportion, 0.0);
      expect(layout.sideProportionFor(EHRoutes.setting), 0.0);
      expect(layout.sideProportionFor('safe:${EHRoutes.setting}'), 0.0);
      expect(layout.sideProportionFor(EHRoutes.gallery), 0.55);
      expect(layout.sideProportionFor(EHRoutes.favorite), 0.55);

      layout.setSideProportionFor(EHRoutes.setting, 0.3);
      expect(layout.settingSideProportion, 0.3);
      expect(layout.sideProportionFor('safe:${EHRoutes.setting}'), 0.3);
      expect(layout.sideProportion, 0.55);
      expect(layout.sideProportionFor(EHRoutes.gallery), 0.55);

      layout.setSideProportionFor('safe:${EHRoutes.setting}', 0.45);
      expect(layout.settingSideProportion, 0.45);
      expect(layout.sideProportion, 0.55);

      layout.setSideProportionFor(EHRoutes.gallery, 0.7);
      expect(layout.sideProportion, 0.7);
      expect(layout.sideProportionFor(EHRoutes.favorite), 0.7);
      expect(layout.settingSideProportion, 0.45);

      // Clamping stays within [0.0, 1.0].
      layout.setSideProportionFor(EHRoutes.setting, 2.5);
      expect(layout.settingSideProportion, 1.0);
      layout.setSideProportionFor(EHRoutes.setting, -0.5);
      expect(layout.settingSideProportion, 0.0);
    });
  });

  group('DesktopUiPreferences & DesktopSplitHandle settings isolation', () {
    test('persists settingSplitRatio independently of splitRatio', () async {
      String? persisted;
      final first = DesktopUiPreferences(
        read: () => null,
        write: (value) async => persisted = value,
      );
      first.load();
      first.setSplitRatio(0.52);
      first.setSettingSplitRatio(0.36);
      await first.pendingWrites;

      final second = DesktopUiPreferences(read: () => persisted);
      second.load();
      expect(second.splitRatio, 0.52);
      expect(second.settingSplitRatio, 0.36);

      second.setSettingSplitRatio(null);
      expect(second.splitRatio, 0.52);
      expect(second.settingSplitRatio, isNull);
    });

    testWidgets(
      'DesktopSplitHandle adjusts and resets settings ratio without touching browse ratio',
      (tester) async {
        Get.testMode = true;
        Get.put<LocaleService>(LocaleService());
        Get.put<EhSettingService>(_TestEhSettingService());
        Get.put<ThemeService>(_TestThemeService());
        addTearDown(Get.reset);

        final prefs = DesktopUiPreferences(
          read: () => null,
          write: (_) async {},
        )..load();
        prefs.setSplitRatio(0.52);
        prefs.setSettingSplitRatio(0.40);

        await tester.pumpWidget(
          GetCupertinoApp(
            locale: const Locale('en'),
            supportedLocales: L10n.delegate.supportedLocales,
            localizationsDelegates: const [
              L10n.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            home: CupertinoPageScaffold(
              child: Center(
                child: SizedBox(
                  width: 12,
                  height: 200,
                  child: DesktopSplitHandle(
                    availableWidth: 1200,
                    listWidth: 480,
                    preferences: prefs,
                    isSettings: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final handle = find.byKey(const ValueKey('desktop-split-handle'));
        await tester.drag(handle, const Offset(60, 0));
        await tester.pumpAndSettle();
        expect(prefs.settingSplitRatio, greaterThan(0.40));
        expect(prefs.splitRatio, 0.52);

        await tester.tap(handle);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(handle);
        await tester.pumpAndSettle();
        expect(prefs.settingSplitRatio, DesktopBrowseStyle.defaultSettingRatio);
        expect(prefs.splitRatio, 0.52);
      },
    );

    for (final host in const <TargetPlatform>[
      TargetPlatform.macOS,
      TargetPlatform.windows,
    ]) {
      testWidgets(
        '$host desktop settings default split ratio matches double-tap reset (${DesktopBrowseStyle.defaultSettingRatio}) while browse stays ${DesktopBrowseStyle.defaultRatio}',
        (tester) async {
          Get.testMode = true;
          PlatformCapabilities.debugHostPlatformOverride = host;
          Get.put<LocaleService>(LocaleService());
          Get.put<EhSettingService>(_TestEhSettingService());
          Get.put<ThemeService>(_TestThemeService());
          final layout = Get.put<LayoutServices>(_TestLayoutServices());
          layout.layoutMode = LayoutMode.large;

          final prefs = DesktopUiPreferences.instance;
          final savedSplitRatio = prefs.splitRatio;
          final savedSettingSplitRatio = prefs.settingSplitRatio;
          final savedLegacyProportion = prefs.legacyProportion;
          prefs.splitRatio = null;
          prefs.settingSplitRatio = null;
          prefs.legacyProportion = null;

          const env = AdaptiveEnvironmentSnapshot(size: Size(1400, 900));
          final activeTab = ValueNotifier<String>(EHRoutes.setting);
          final settingStack = layout.tabNavigation.stackFor(EHRoutes.setting);
          final galleryStack = layout.tabNavigation.stackFor(EHRoutes.gallery);

          tester.view.devicePixelRatio = 1.0;
          tester.view.physicalSize = env.size;
          addTearDown(() {
            activeTab.dispose();
            prefs.splitRatio = savedSplitRatio;
            prefs.settingSplitRatio = savedSettingSplitRatio;
            prefs.legacyProportion = savedLegacyProportion;
            PlatformCapabilities.debugHostPlatformOverride = null;
            layout.tabNavigation.reset();
            Get.reset();
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          const settingPrimaryKey = ValueKey<String>(
            'desktop-setting-primary-pane',
          );
          const galleryPrimaryKey = ValueKey<String>(
            'desktop-gallery-primary-pane',
          );

          await tester.pumpWidget(
            GetCupertinoApp(
              locale: const Locale('en'),
              supportedLocales: L10n.delegate.supportedLocales,
              localizationsDelegates: const [
                L10n.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              home: AdaptiveEnvironmentScope(
                snapshot: env,
                child: DesktopSidebarScope(
                  desktop: true,
                  visible: true,
                  onShow: () {},
                  child: ValueListenableBuilder<String>(
                    valueListenable: activeTab,
                    builder: (context, currentTab, _) => Stack(
                      fit: StackFit.expand,
                      children: [
                        RetainedTab(
                          key: const ValueKey<String>(EHRoutes.setting),
                          active: currentTab == EHRoutes.setting,
                          child: AdaptiveTabNavigator(
                            stack: settingStack,
                            split: true,
                            primaryRoot: const CupertinoPageScaffold(
                              child: SizedBox.expand(key: settingPrimaryKey),
                            ),
                          ),
                        ),
                        RetainedTab(
                          key: const ValueKey<String>(EHRoutes.gallery),
                          active: currentTab == EHRoutes.gallery,
                          child: AdaptiveTabNavigator(
                            stack: galleryStack,
                            split: true,
                            primaryRoot: const CupertinoPageScaffold(
                              child: SizedBox.expand(key: galleryPrimaryKey),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final expectedSettingWidth = DesktopBrowseStyle.listWidth(
            env.contentRect.width,
            DesktopBrowseStyle.defaultSettingRatio,
          );
          final expectedBrowseWidth = DesktopBrowseStyle.listWidth(
            env.contentRect.width,
            DesktopBrowseStyle.defaultRatio,
          );

          // 1. Settings initially renders with defaultSettingRatio (0.34).
          final initialSettingWidth =
              tester.getRect(find.byKey(settingPrimaryKey)).width;
          expect(initialSettingWidth, closeTo(expectedSettingWidth, 0.01));
          expect(initialSettingWidth, lessThan(expectedBrowseWidth));

          // 2. Gallery keeps its defaultRatio (0.44) unchanged.
          activeTab.value = EHRoutes.gallery;
          await tester.pumpAndSettle();
          final initialGalleryWidth =
              tester.getRect(find.byKey(galleryPrimaryKey)).width;
          expect(initialGalleryWidth, closeTo(expectedBrowseWidth, 0.01));

          // 3. Drag Settings handle, then double-tap to reset: returns to exact initial width.
          activeTab.value = EHRoutes.setting;
          await tester.pumpAndSettle();
          final handle = find.descendant(
            of: find.byKey(const ValueKey<String>(EHRoutes.setting)),
            matching: find.byKey(const ValueKey('desktop-split-handle')),
          );
          await tester.drag(handle, const Offset(120, 0));
          await tester.pumpAndSettle();
          expect(
            tester.getRect(find.byKey(settingPrimaryKey)).width,
            greaterThan(initialSettingWidth + 80),
          );
          expect(prefs.splitRatio, isNull);

          await tester.tap(handle);
          await tester.pump(const Duration(milliseconds: 50));
          await tester.tap(handle);
          await tester.pumpAndSettle();
          expect(
            prefs.settingSplitRatio,
            DesktopBrowseStyle.defaultSettingRatio,
          );
          expect(
            tester.getRect(find.byKey(settingPrimaryKey)).width,
            closeTo(initialSettingWidth, 0.01),
          );

          // 4. Gallery remains untouched at defaultRatio (0.44).
          activeTab.value = EHRoutes.gallery;
          await tester.pumpAndSettle();
          expect(
            tester.getRect(find.byKey(galleryPrimaryKey)).width,
            closeTo(expectedBrowseWidth, 0.01),
          );
        },
      );
    }
  });

  group('AdaptiveTabNavigator independent settings split divider', () {
    final profiles = <({
      String name,
      TargetPlatform platform,
      AdaptiveEnvironmentSnapshot environment,
    })>[
      (
        name: 'iOS Duo landscape',
        platform: TargetPlatform.iOS,
        environment: const AdaptiveEnvironmentSnapshot(
          size: Size(1024, 720),
          safeArea: EdgeInsets.only(right: 92),
          viewPadding: EdgeInsets.only(right: 92),
          duoVerticalBar: true,
          systemBarEdge: 'right',
          nativeSupported: true,
        ),
      ),
      (
        name: 'iPad landscape',
        platform: TargetPlatform.iOS,
        environment: const AdaptiveEnvironmentSnapshot(
          size: Size(1180, 820),
        ),
      ),
      (
        name: 'Android tablet landscape',
        platform: TargetPlatform.android,
        environment: const AdaptiveEnvironmentSnapshot(
          size: Size(1120, 800),
        ),
      ),
    ];

    for (final profile in profiles) {
      testWidgets(
        '${profile.name}: Settings defaults to 320px and drags independently of Gallery',
        (tester) async {
          Get.testMode = true;
          PlatformCapabilities.debugHostPlatformOverride = profile.platform;
          Get.put<LocaleService>(LocaleService());
          Get.put<EhSettingService>(_TestEhSettingService());
          Get.put<ThemeService>(_TestThemeService());
          final layout = Get.put<LayoutServices>(_TestLayoutServices());
          layout.layoutMode = LayoutMode.large;
          layout.sideProportion = 0.55;

          final activeTab = ValueNotifier<String>(EHRoutes.setting);
          final settingStack = layout.tabNavigation.stackFor(EHRoutes.setting);
          final galleryStack = layout.tabNavigation.stackFor(EHRoutes.gallery);

          tester.view.devicePixelRatio = 1.0;
          tester.view.physicalSize = profile.environment.size;
          addTearDown(() {
            activeTab.dispose();
            PlatformCapabilities.debugHostPlatformOverride = null;
            layout.tabNavigation.reset();
            Get.reset();
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          const settingPrimaryKey = ValueKey<String>('setting-primary-pane');
          const galleryPrimaryKey = ValueKey<String>('gallery-primary-pane');

          await tester.pumpWidget(
            GetCupertinoApp(
              home: AdaptiveEnvironmentScope(
                snapshot: profile.environment,
                child: ValueListenableBuilder<String>(
                  valueListenable: activeTab,
                  builder: (context, currentTab, _) => Stack(
                    fit: StackFit.expand,
                    children: [
                      RetainedTab(
                        key: const ValueKey<String>(EHRoutes.setting),
                        active: currentTab == EHRoutes.setting,
                        child: AdaptiveTabNavigator(
                          stack: settingStack,
                          split: true,
                          primaryRoot: const CupertinoPageScaffold(
                            child: SizedBox.expand(key: settingPrimaryKey),
                          ),
                        ),
                      ),
                      RetainedTab(
                        key: const ValueKey<String>(EHRoutes.gallery),
                        active: currentTab == EHRoutes.gallery,
                        child: AdaptiveTabNavigator(
                          stack: galleryStack,
                          split: true,
                          primaryRoot: const CupertinoPageScaffold(
                            child: SizedBox.expand(key: galleryPrimaryKey),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // 1. Settings defaults to leftmost 320.0px compact width.
          expect(layout.settingSideProportion, 0.0);
          final initialSettingWidth =
              tester.getRect(find.byKey(settingPrimaryKey)).width;
          expect(
            initialSettingWidth,
            closeTo(AdaptiveEnvironmentSnapshot.minimumPaneWidth, 0.01),
          );

          // 2. Gallery keeps its wider browse split width (> 480px).
          activeTab.value = EHRoutes.gallery;
          await tester.pumpAndSettle();
          final initialGalleryWidth =
              tester.getRect(find.byKey(galleryPrimaryKey)).width;
          expect(initialGalleryWidth, greaterThan(480.0));
          expect(
            initialGalleryWidth,
            closeTo(
              AdaptiveBrowseLayout.primaryPaneWidth(
                profile.environment.contentRect.width,
                0.55,
              ),
              0.01,
            ),
          );

          // 3. Drag Settings divider rightward by +120px: widens Settings only.
          activeTab.value = EHRoutes.setting;
          await tester.pumpAndSettle();
          await tester.drag(
            find.byType(SideControllerbar),
            const Offset(120, 0),
          );
          await tester.pumpAndSettle();

          final settingProportionAfterDrag = layout.settingSideProportion;
          expect(settingProportionAfterDrag, greaterThan(0.0));
          expect(layout.sideProportion, 0.55);

          final widenedSettingWidth =
              tester.getRect(find.byKey(settingPrimaryKey)).width;
          expect(widenedSettingWidth, greaterThan(initialSettingWidth + 50));

          // 4. Switch to Gallery, verify width unchanged, then drag leftward -80px.
          activeTab.value = EHRoutes.gallery;
          await tester.pumpAndSettle();
          expect(
            tester.getRect(find.byKey(galleryPrimaryKey)).width,
            closeTo(initialGalleryWidth, 0.01),
          );

          await tester.drag(
            find.byType(SideControllerbar),
            const Offset(-80, 0),
          );
          await tester.pumpAndSettle();

          expect(layout.sideProportion, lessThan(0.55));
          expect(layout.settingSideProportion, settingProportionAfterDrag);
          expect(
            tester.getRect(find.byKey(galleryPrimaryKey)).width,
            lessThan(initialGalleryWidth),
          );

          // 5. Switch back to Settings: width stays untouched.
          activeTab.value = EHRoutes.setting;
          await tester.pumpAndSettle();
          expect(
            tester.getRect(find.byKey(settingPrimaryKey)).width,
            closeTo(widenedSettingWidth, 0.01),
          );
        },
      );
    }
  });
}
