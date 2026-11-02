import 'dart:io';

import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/pages/tab/view/download_page.dart';
import 'package:eros_fe/pages/tab/view/hidden_tabs_rail_action.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Settings extends EhSettingService {
  // Tests provide isolated state instead of loading the persisted profile.
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Home extends TabHomeController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

const _routes = <String>[
  EHRoutes.gallery,
  EHRoutes.favorite,
  EHRoutes.toplist,
  EHRoutes.download,
  EHRoutes.history,
];

Widget _railPage() => Builder(builder: (context) {
      return CupertinoPageScaffold(
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: 100,
            child: Obx(() => LiquidGlassRail(
                  title: 'Rail',
                  safeTop: 0,
                  fadeProgress: 0,
                  selectedIndex: 0,
                  leading: hiddenTabsRailAction(context),
                )),
          ),
        ),
      );
    });

void main() {
  late _Settings settings;
  late _Home home;

  setUp(() {
    Get.testMode = true;
    Get.put<LocaleService>(LocaleService());
    settings = _Settings();
    Get.put<EhSettingService>(settings);
    home = _Home()
      ..tabNameList = List<String>.of(_routes).obs
      ..tabMap = <String, bool>{for (final route in _routes) route: true}.obs;
    Get.put<TabHomeController>(home);
  });

  tearDown(Get.reset);

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(GetCupertinoApp(
      locale: const Locale('en'),
      localizationsDelegates: const [L10n.delegate],
      getPages: [
        for (final route in _routes)
          GetPage<void>(
            name: route,
            page: () => CupertinoPageScaffold(child: Text('opened:$route')),
          ),
      ],
      home: _railPage(),
    ));
    await tester.pumpAndSettle();
  }

  LiquidGlassRailAction? leading(WidgetTester tester) =>
      tester.widget<LiquidGlassRail>(find.byType(LiquidGlassRail)).leading;

  String title(WidgetTester tester, String route) =>
      tabPages.titlesOf(tester.element(find.byType(LiquidGlassRail)))[route]!;

  Future<void> tapLeading(WidgetTester tester) async {
    await tester.tap(find.byIcon(leading(tester)!.icon));
    await tester.pumpAndSettle();
  }

  testWidgets('no hidden tabs yields no leading action', (tester) async {
    await mount(tester);
    expect(leading(tester), isNull);
  });

  for (final route in _routes) {
    testWidgets('single hidden $route has the right icon, label and route',
        (tester) async {
      home.tabMap[route] = false;
      await mount(tester);
      final action = leading(tester)!;
      expect(action.icon, tabPages.iconDatas[route]!.data);
      expect(action.label, title(tester, route));
      await tapLeading(tester);
      expect(find.text('opened:$route'), findsOneWidget);
      expect(Get.currentRoute, route);
    });
  }

  testWidgets('visible history does not create a history shortcut',
      (tester) async {
    home.tabMap[EHRoutes.download] = false;
    await mount(tester);
    expect(leading(tester)!.label, title(tester, EHRoutes.download));
    expect(leading(tester)!.label, isNot(title(tester, EHRoutes.history)));
    expect(
        find.byIcon(tabPages.iconDatas[EHRoutes.history]!.data), findsNothing);
  });

  testWidgets('multiple hidden tabs show ordered menu and open download',
      (tester) async {
    for (final route in [
      EHRoutes.favorite,
      EHRoutes.download,
      EHRoutes.history
    ]) {
      home.tabMap[route] = false;
    }
    await mount(tester);
    final titles = [
      for (final route in home.hiddenTabRoutes) title(tester, route)
    ];
    expect(leading(tester)!.icon, CupertinoIcons.ellipsis_circle);
    expect(leading(tester)!.label,
        L10n.of(tester.element(find.byType(LiquidGlassRail))).more_actions);
    await tapLeading(tester);
    final sheet = tester.widget<EhActionSheet>(find.byType(EhActionSheet));
    final actions = sheet.actions!.cast<EhActionSheetAction>();
    expect(actions.map((action) => (action.child as Text).data), titles);
    for (var i = 0; i < actions.length; i++) {
      final route = home.hiddenTabRoutes[i];
      expect(actions[i].icon, tabPages.iconDatas[route]!.data);
      expect(actions[i].systemIcon, tabPages.liquidGlassFallbackSymbols[route]);
    }
    await tester.tap(find.text(titles[1]));
    await tester.pumpAndSettle();
    expect(find.byType(EhActionSheet), findsNothing);
    expect(find.text('opened:${EHRoutes.download}'), findsOneWidget);
    Get.back<void>();
    await tester.pumpAndSettle();
    expect(find.byType(LiquidGlassRail), findsOneWidget);
    expect(Get.currentRoute, isNot(EHRoutes.history));
  });

  testWidgets('cancel closes the menu without navigating', (tester) async {
    home.tabMap[EHRoutes.favorite] = false;
    home.tabMap[EHRoutes.download] = false;
    await mount(tester);
    final cancel = L10n.of(tester.element(find.byType(LiquidGlassRail))).cancel;
    await tapLeading(tester);
    await tester.tap(find.text(cancel));
    await tester.pumpAndSettle();
    expect(find.byType(EhActionSheet), findsNothing);
    expect(find.byType(LiquidGlassRail), findsOneWidget);
    expect(find.textContaining('opened:'), findsNothing);
  });

  testWidgets('menu order follows reordered tabs', (tester) async {
    home.tabMap[EHRoutes.favorite] = false;
    home.tabMap[EHRoutes.download] = false;
    home.tabMap[EHRoutes.history] = false;
    await mount(tester);
    home.tabNameList.assignAll(_routes.reversed);
    await tester.pump();
    final expected = [
      for (final route in home.hiddenTabRoutes) title(tester, route)
    ];
    await tapLeading(tester);
    final sheet = tester.widget<EhActionSheet>(find.byType(EhActionSheet));
    expect(
        sheet.actions!
            .cast<EhActionSheetAction>()
            .map((action) => (action.child as Text).data),
        expected);
  });

  testWidgets('visibility updates one, multiple and zero items without remount',
      (tester) async {
    await mount(tester);
    final state = tester.state(find.byType(LiquidGlassRail));
    home.tabMap[EHRoutes.download] = false;
    await tester.pump();
    expect(leading(tester)!.label, title(tester, EHRoutes.download));
    home.tabMap[EHRoutes.history] = false;
    await tester.pump();
    expect(leading(tester)!.icon, CupertinoIcons.ellipsis_circle);
    home.tabMap[EHRoutes.download] = true;
    home.tabMap[EHRoutes.history] = true;
    await tester.pump();
    expect(leading(tester), isNull);
    expect(tester.state(find.byType(LiquidGlassRail)), same(state));
    expect(tester.takeException(), isNull);
  });

  testWidgets('safe mode hides actions and normal mode restores them',
      (tester) async {
    home.tabMap[EHRoutes.download] = false;
    settings.isSafeMode.value = true;
    await mount(tester);
    expect(leading(tester), isNull);
    home.tabMap[EHRoutes.history] = false;
    await tester.pump();
    expect(leading(tester), isNull);
    settings.isSafeMode.value = false;
    await tester.pump();
    expect(leading(tester)!.icon, CupertinoIcons.ellipsis_circle);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an initially empty tab list remains reactive', (tester) async {
    home.tabNameList.clear();
    await mount(tester);
    expect(leading(tester), isNull);
    home.tabMap[EHRoutes.download] = false;
    await tester.pump();
    home.tabNameList.add(EHRoutes.download);
    await tester.pump();
    expect(leading(tester)!.label, title(tester, EHRoutes.download));
    home.tabMap[EHRoutes.download] = true;
    await tester.pump();
    expect(leading(tester), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pushed page shows back and returns to the previous page',
      (tester) async {
    home.tabMap[EHRoutes.download] = false;
    await mount(tester);
    Get.to<void>(() => _railPage());
    await tester.pumpAndSettle();
    final action = leading(tester)!;
    expect(action.icon, CupertinoIcons.chevron_back);
    expect(action.label,
        L10n.of(tester.element(find.byType(LiquidGlassRail))).back);
    await tapLeading(tester);
    expect(leading(tester)!.label, title(tester, EHRoutes.download));
  });

  testWidgets('download header updates without losing its page and returns',
      (tester) async {
    final pages = PageController();
    addTearDown(pages.dispose);

    Widget downloadPage({PageController? controller}) =>
        Builder(builder: (context) {
          return CupertinoPageScaffold(
            child: Column(children: [
              SizedBox(
                height: 100,
                child: Obx(() => DownloadGlassHeader(
                      title: 'Downloads',
                      galleryLabel: 'Gallery',
                      archiverLabel: 'Archive',
                      safeTop: 0,
                      layout: LiquidGlassTopBarLayout.twoRow,
                      selectedIndex: 0,
                      pageController: controller,
                      leading: hiddenTabsRailAction(context),
                      onSelected: (index) => controller?.jumpToPage(index),
                    )),
              ),
              if (controller != null)
                Expanded(
                  child: PageView(controller: controller, children: const [
                    Text('gallery tasks'),
                    Text('archive tasks'),
                  ]),
                ),
            ]),
          );
        });

    await tester.pumpWidget(GetCupertinoApp(
      locale: const Locale('en'),
      localizationsDelegates: const [L10n.delegate],
      home: downloadPage(controller: pages),
    ));
    await tester.pumpAndSettle();
    expect(leading(tester), isNull);
    pages.jumpToPage(1);
    await tester.pumpAndSettle();
    expect(find.text('archive tasks'), findsOneWidget);

    home.tabMap[EHRoutes.history] = false;
    await tester.pump();
    expect(leading(tester)!.label, title(tester, EHRoutes.history));
    expect(
        tester
            .widget<DownloadGlassHeader>(find.byType(DownloadGlassHeader))
            .pageController,
        same(pages));
    expect(pages.page, 1);
    expect(find.text('archive tasks'), findsOneWidget);

    Get.to<void>(() => downloadPage());
    await tester.pumpAndSettle();
    expect(leading(tester)!.icon, CupertinoIcons.chevron_back);
    await tapLeading(tester);
    expect(leading(tester)!.label, title(tester, EHRoutes.history));
    expect(pages.page, 1);
  });

  test('all legacy rail pages use the shared action and have no fixed history',
      () {
    for (final path in [
      'lib/pages/tab/view/tabbar/custom_tabbar_page.dart',
      'lib/pages/tab/view/tabbar/favorite_tabbar_page.dart',
      'lib/pages/tab/view/toplist_page.dart',
      'lib/pages/tab/view/download_page.dart',
    ]) {
      expect(File(path).readAsStringSync(), contains('hiddenTabsRailAction('),
          reason: path);
    }
    for (final file
        in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (file.path.endsWith('.dart')) {
        expect(file.readAsStringSync(), isNot(contains("label: '浏览历史'")),
            reason: file.path);
      }
    }
  });
}
