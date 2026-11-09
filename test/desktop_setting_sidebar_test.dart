import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/browse_layout.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/tab/controller/setting_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/pages/tab/view/home_page_large.dart';
import 'package:eros_fe/pages/tab/view/setting_page.dart';
import 'package:eros_fe/route/app_pages.dart';
import 'package:eros_fe/route/main_observer.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/widget/desktop_sidebar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'support/waterfall_fixture.dart';

void main() {
  for (final host in [TargetPlatform.macOS, TargetPlatform.windows]) {
    for (final glass in [false, true]) {
      testWidgets('$host glass=$glass settings follow the real sidebar space', (
        tester,
      ) async {
        registerWaterfallFixture();
        PlatformCapabilities.debugHostPlatformOverride = host;
        SettingGlassBar.debugActive = glass;
        Get.find<EhSettingService>().liquidGlass = glass;
        final layout = Get.put<LayoutServices>(_Layout());
        layout.sideProportion = .5;
        final settings = Get.put(SettingViewController());
        final home = Get.find<TabHomeController>();
        home.tabNameList.assignAll([EHRoutes.gallery]);
        home.tabMap.assignAll({EHRoutes.gallery: true});
        Global.packageInfo = PackageInfo(
          appName: 'Eros-FE',
          packageName: 'cn.honjow.fehv',
          version: '1.9.2',
          buildNumber: '566',
        );
        final categoryRoutes = [
          EHRoutes.layoutSetting,
          EHRoutes.readSetting,
          EHRoutes.itemWidthSetting,
        ];
        final originalRoutes = AppPages.routes
            .where((page) => categoryRoutes.contains(page.name))
            .toList();
        AppPages.routes.removeWhere(
          (page) => categoryRoutes.contains(page.name),
        );
        AppPages.routes.addAll([
          for (final name in categoryRoutes)
            GetPage<void>(
              name: name,
              page: () =>
                  SettingScaffold(title: name, child: const SizedBox.expand()),
            ),
        ]);
        tester.view.devicePixelRatio = 1;
        final geometry = ValueNotifier(const Size(900, 700));
        tester.view.physicalSize = geometry.value;
        MainNavigatorObserver().resetHistory();
        addTearDown(() {
          geometry.dispose();
          PlatformCapabilities.debugHostPlatformOverride = null;
          SettingGlassBar.debugActive = null;
          tester.view.reset();
          AppPages.routes.removeWhere(
            (page) => categoryRoutes.contains(page.name),
          );
          AppPages.routes.addAll(originalRoutes);
          MainNavigatorObserver().resetHistory();
          Get.reset();
        });
        await tester.pumpWidget(
          GetCupertinoApp(
            locale: const Locale('en'),
            supportedLocales: L10n.delegate.supportedLocales,
            localizationsDelegates: const [
              L10n.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            navigatorObservers: [MainNavigatorObserver()],
            home: ValueListenableBuilder<Size>(
              valueListenable: geometry,
              builder: (_, size, _) {
                final environment = AdaptiveEnvironmentSnapshot(size: size);
                layout.layoutMode = environment.isSplit
                    ? LayoutMode.large
                    : LayoutMode.small;
                return AdaptiveEnvironmentScope(
                  snapshot: environment,
                  child: TabHomeLarge(
                    split: environment.isSplit,
                    destinationBuilder: (_, route) => route == EHRoutes.setting
                        ? const SettingTab()
                        : const SizedBox.expand(),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await home.selectRoute(EHRoutes.setting);
        await tester.pumpAndSettle();

        List<Route<dynamic>> history() =>
            layout.tabNavigation.selected!.detailObserver.history;
        Future<void> resize(Size size) async {
          tester.view.physicalSize = size;
          geometry.value = size;
          await tester.pumpAndSettle();
        }

        void expectSplit(bool expected) {
          expect(layout.isLayoutLarge, expected);
          final browse = tester.widget<AdaptiveBrowseLayout>(
            find.byType(AdaptiveBrowseLayout),
          );
          expect(browse.split, expected);
          expect(usesDesktopSettingPanes, expected);
        }

        expect(find.byType(DesktopSidebar), findsOneWidget);
        expectSplit(false);
        expect(history(), hasLength(1)); // No category over the list.
        final l10n = L10n.current;
        await tester.tap(find.text(l10n.appearance_and_layout));
        await tester.pumpAndSettle();
        expect(history(), hasLength(2));
        expect(isDesktopSettingPaneRoot(history()[1] as ModalRoute), isFalse);
        final category = history()[1];
        // The category must have a usable back button in a single column.
        expect(
          find.byType(CupertinoNavigationBarBackButton),
          glass ? findsNothing : findsOneWidget,
        );
        await tester.tap(
          glass
              ? find.byIcon(CupertinoIcons.chevron_back)
              : find.byType(CupertinoNavigationBarBackButton),
        );
        await tester.pumpAndSettle();
        expect(history(), hasLength(1));
        settings.syncDesktopPane();
        await tester.pumpAndSettle();
        expect(history(), hasLength(1)); // Back must not reopen the category.

        await resize(const Size(1024, 800));
        expectSplit(false);
        expect(history(), hasLength(1));

        // Enough usable width for both panes: opens the last category.
        await resize(const Size(1280, 700));
        expectSplit(true);
        expect(history(), hasLength(2));
        final selected = history()[1];
        expect(isDesktopSettingPaneRoot(selected as ModalRoute), isTrue);
        expect(find.byType(CupertinoNavigationBarBackButton), findsNothing);
        settings.open(EHRoutes.readSetting);
        await tester.pumpAndSettle();
        expect(history(), hasLength(2));
        expect(history()[1].settings.name, EHRoutes.readSetting);

        await resize(const Size(900, 700));
        expectSplit(false);
        expect(isDesktopSettingPaneRoot(history()[1] as ModalRoute), isFalse);
        expect(identical(history()[1], category), isFalse);
        await home.popLogicalRoute();
        await tester.pumpAndSettle();
        expect(history(), hasLength(1));

        // Crossing the sidebar boundary can restore a split, then remove it.
        await resize(const Size(899, 700));
        expect(find.byType(DesktopSidebar), findsNothing);
        expectSplit(true);
        expect(history(), hasLength(2));
        await resize(const Size(900, 700));
        expectSplit(false);
        await home.popLogicalRoute();
        await tester.pumpAndSettle();
        expect(history(), hasLength(1));
        expect(tester.takeException(), isNull);
      });
    }
  }
}

class _Layout extends LayoutServices {
  @override
  // ignore: must_call_super
  void onInit() {}
}
