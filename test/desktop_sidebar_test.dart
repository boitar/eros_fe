import 'dart:ui' show Tristate;

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
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/desktop_sidebar.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

const _channel = MethodChannel('eros/native-navigation');

/// The bottom bar in any of its forms (the glass bar extends it).
final Finder _tabBar = find.byWidgetPredicate((w) => w is CupertinoTabBar);

void main() {
  tearDown(() => PlatformCapabilities.debugHostPlatformOverride = null);

  test('only wide macOS and Windows windows use the sidebar', () {
    const wide = AdaptiveEnvironmentSnapshot(size: Size(1200, 800));
    const narrow = AdaptiveEnvironmentSnapshot(size: Size(800, 800));
    for (final host in TargetPlatform.values) {
      PlatformCapabilities.debugHostPlatformOverride = host;
      final desktop =
          host == TargetPlatform.macOS || host == TargetPlatform.windows;
      expect(usesDesktopSidebar(environment: wide), desktop, reason: '$host');
      expect(usesDesktopSidebar(environment: narrow), isFalse, reason: '$host');
    }
  });

  test('the search shortcut is ⌘F on macOS and Ctrl+F on Windows', () {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.macOS;
    expect(DesktopSidebar.searchShortcut.meta, isTrue);
    expect(DesktopSidebar.searchShortcut.control, isFalse);
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.windows;
    expect(DesktopSidebar.searchShortcut.meta, isFalse);
    expect(DesktopSidebar.searchShortcut.control, isTrue);
  });

  testWidgets('beside the sidebar the top bar names the group, not chips',
      (tester) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.macOS;
    var titleTaps = 0;
    Widget rail({required bool showsTitle}) => CupertinoApp(
          home: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 480,
              child: LiquidGlassRail(
                title: 'Non-H',
                safeTop: 0,
                fadeProgress: 0,
                selectedIndex: 0,
                showsTitle: showsTitle,
                onTitleTap: () => titleTaps++,
                layout: LiquidGlassTopBarLayout.twoRow,
                leading: LiquidGlassRailAction(
                  icon: CupertinoIcons.clock,
                  label: 'History',
                  onPressed: () {},
                ),
              ),
            ),
          ),
        );
    await tester.pumpWidget(rail(showsTitle: false));
    expect(find.text('Non-H'), findsNothing);

    await tester.pumpWidget(rail(showsTitle: true));
    await tester.pump();
    expect(find.text('Non-H'), findsOneWidget);
    // One row only: there are no chips beneath it.
    expect(tester.getSize(find.byType(LiquidGlassRail)).height,
        LiquidGlassTopBarLayout.twoRow
            .expandedHeight(TextScaler.noScaling, hasCategories: false));
    await tester.tap(find.byKey(const ValueKey('liquid-glass-rail-title')));
    expect(titleTaps, 1);
    expect(tester.takeException(), isNull);
  });

  group('sidebar', () {
    late List<String> taps;

    Future<void> pump(WidgetTester tester, {required bool glass}) async {
      Get.testMode = true;
      Get.put<LocaleService>(LocaleService());
      Get.put<EhSettingService>(_Settings());
      Get.put<ThemeService>(_Theme());
      addTearDown(Get.reset);
      taps = <String>[];
      const routes = <String>[
        EHRoutes.gallery,
        EHRoutes.favorite,
        EHRoutes.toplist,
        EHRoutes.download,
        EHRoutes.setting,
      ];
      await tester.pumpWidget(
        CupertinoApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              height: 700,
              child: DesktopSidebar(
                routes: routes,
                items: <BottomNavigationBarItem>[
                  for (final route in routes)
                    BottomNavigationBarItem(
                      icon: const Icon(CupertinoIcons.circle),
                      label: route,
                    ),
                ],
                currentIndex: 1,
                onTap: (index) => taps.add(routes[index]),
                glass: glass,
                searchLabel: 'Search',
                onSearch: () => taps.add('search'),
                browseLabel: 'Browse',
                libraryLabel: 'Library',
                groupsLabel: 'Groups',
                groups: const <DesktopSidebarGroup>[
                  DesktopSidebarGroup(title: 'Non-H', selected: true),
                  DesktopSidebarGroup(title: 'Anthology', selected: false),
                ],
                onGroupTap: (index) => taps.add('group $index'),
              ),
            ),
          ),
        ),
      );
    }

    for (final glass in [true, false]) {
      testWidgets('sorts destinations into sections (glass: $glass)', (
        tester,
      ) async {
        await pump(tester, glass: glass);
        final y = <String, double>{
          for (final key in <String>[
            EHRoutes.gallery,
            EHRoutes.toplist,
            EHRoutes.favorite,
            EHRoutes.download,
            EHRoutes.setting,
          ])
            key: tester
                .getTopLeft(find.byKey(ValueKey('desktop-sidebar-$key')))
                .dy,
        };
        double header(String text) => tester.getTopLeft(find.text(text)).dy;
        // Browse: gallery, toplist; Library: favorite, download.
        expect(header('Browse'), lessThan(y[EHRoutes.gallery]!));
        expect(y[EHRoutes.gallery]!, lessThan(y[EHRoutes.toplist]!));
        expect(y[EHRoutes.toplist]!, lessThan(header('Library')));
        expect(header('Library'), lessThan(y[EHRoutes.favorite]!));
        expect(y[EHRoutes.favorite]!, lessThan(y[EHRoutes.download]!));
        expect(y[EHRoutes.download]!, lessThan(header('Groups')));
        // Settings stays pinned to the bottom of the panel, well below the
        // last group.
        expect(
          y[EHRoutes.setting]!,
          greaterThan(tester.getTopLeft(find.text('Anthology')).dy + 100),
        );

        final selected = tester.getSemantics(
          find.byKey(const ValueKey('desktop-sidebar-${EHRoutes.favorite}')),
        );
        expect(selected.flagsCollection.isSelected, Tristate.isTrue);

        await tester.tap(find.text(EHRoutes.download));
        await tester.tap(find.text('Anthology'));
        await tester.tap(find.byKey(const ValueKey('desktop-sidebar-search')));
        expect(taps, <String>[EHRoutes.download, 'group 1', 'search']);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('home shell', () {
    late ValueNotifier<AdaptiveEnvironmentSnapshot> geometry;

    Future<void> mount(
      WidgetTester tester,
      Size size, {
      TargetPlatform host = TargetPlatform.macOS,
    }) async {
      Get.testMode = true;
      PlatformCapabilities.debugHostPlatformOverride = host;
      Get.put<LocaleService>(LocaleService());
      Get.put<EhSettingService>(_Settings());
      Get.put<ThemeService>(_Theme());
      final layout = Get.put<LayoutServices>(_Layout());
      final home = Get.put<TabHomeController>(_Home());
      home.tabNameList.assignAll([EHRoutes.gallery, EHRoutes.favorite]);
      home.tabMap.assignAll({EHRoutes.gallery: true, EHRoutes.favorite: true});
      Get.put(ControllerTagService());
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _channel,
        (call) async => call.method == 'getShellState' ? false : null,
      );
      geometry = ValueNotifier(AdaptiveEnvironmentSnapshot(size: size));
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      MainNavigatorObserver().resetHistory();
      addTearDown(() {
        NativeNavigationBridge.enabled.value = false;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _channel,
          null,
        );
        geometry.dispose();
        Get.reset();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        GetCupertinoApp(
          localizationsDelegates: const [L10n.delegate],
          navigatorObservers: [MainNavigatorObserver()],
          home: ValueListenableBuilder(
            valueListenable: geometry,
            builder: (_, environment, _) {
              layout.layoutMode = environment.isSplit
                  ? LayoutMode.large
                  : LayoutMode.small;
              return AdaptiveEnvironmentScope(
                snapshot: environment,
                child: TabHomeLarge(
                  split: environment.isSplit,
                  destinationBuilder: (_, route) => CupertinoPageScaffold(
                    child: Center(child: Text('$route root')),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a wide macOS window shows the sidebar instead of the bar', (
      tester,
    ) async {
      await mount(tester, const Size(1280, 800));
      expect(find.byKey(const ValueKey('desktop-sidebar')), findsOneWidget);
      expect(_tabBar, findsNothing);
      // The page starts to the right of the sidebar.
      final page = tester.getTopLeft(find.text('/gallery root'));
      expect(
        page.dx,
        greaterThan(DesktopSidebar.reservedWidth(glass: false) - 1),
      );

      await tester.tap(
        find.byKey(const ValueKey('desktop-sidebar-${EHRoutes.favorite}')),
      );
      await tester.pumpAndSettle();
      expect(Get.find<TabHomeController>().currRoute, EHRoutes.favorite);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a narrow window keeps the bottom bar', (tester) async {
      await mount(tester, const Size(800, 800));
      expect(find.byKey(const ValueKey('desktop-sidebar')), findsNothing);
      expect(_tabBar, findsOneWidget);
    });

    testWidgets('Android tablets keep their rail', (tester) async {
      await mount(tester, const Size(1280, 800), host: TargetPlatform.android);
      expect(find.byKey(const ValueKey('desktop-sidebar')), findsNothing);
    });
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
  // Stubs skip the service setup on purpose.
  @override
  // ignore: must_call_super
  void onInit() {}
}
