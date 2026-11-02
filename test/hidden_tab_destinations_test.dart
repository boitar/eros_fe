import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/route/main_observer.dart';
import 'package:eros_fe/route/routes.dart';
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

class _Layout extends LayoutServices {
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
      home: Builder(builder: (context) {
        home.init(inContext: context);
        return const CupertinoPageScaffold(child: Text('home'));
      }),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'all 31 valid visibility combinations publish hidden destinations',
      (tester) async {
    await mount(tester);
    for (var mask = 1; mask < 32; mask++) {
      home.tabMap.assignAll({
        for (var i = 0; i < _routes.length; i++)
          _routes[i]: mask & (1 << i) != 0,
      });
      final expected = _routes.where((route) => !home.tabMap[route]!).toList();
      expect(home.hiddenTabRoutes, expected, reason: 'mask=$mask');
      final actions = home.nativeHiddenTabActions;
      expect(actions.map((action) => action.id),
          expected.map((route) => 'destination:$route'),
          reason: 'mask=$mask');
      expect(actions.map((action) => action.title),
          expected.map((route) => tabPages.tabTitles[route]),
          reason: 'mask=$mask');
      expect(actions.map((action) => action.symbol),
          expected.map((route) => tabPages.liquidGlassFallbackSymbols[route]),
          reason: 'mask=$mask');
      expect(home.visibleTabRoutes, [
        ..._routes.where((route) => home.tabMap[route]!),
        EHRoutes.setting,
      ]);
    }
  });

  testWidgets('each single hidden native action opens its own route',
      (tester) async {
    await mount(tester);
    for (final route in _routes) {
      home.tabMap.assignAll({
        for (final candidate in _routes) candidate: candidate != route,
      });
      final pending = home.nativeHiddenTabActions.single.onPressed!();
      await tester.pumpAndSettle();
      expect(find.text('opened:$route'), findsOneWidget, reason: route);
      expect(Get.currentRoute, route);
      Get.back<void>();
      await tester.pumpAndSettle();
      await pending;
    }
  });

  testWidgets('openHiddenTab opens each requested route', (tester) async {
    await mount(tester);
    for (final route in _routes) {
      final pending = home.openHiddenTab(route);
      await tester.pumpAndSettle();
      expect(find.text('opened:$route'), findsOneWidget, reason: route);
      Get.back<void>();
      await tester.pumpAndSettle();
      await pending;
    }
  });

  testWidgets('openHiddenTab uses the selected primary nested navigator',
      (tester) async {
    final layout = Get.put<LayoutServices>(_Layout());
    final owner = Object();
    final navigation = layout.mountNavigation(owner);
    final stack = navigation.select(EHRoutes.gallery);
    MainNavigatorObserver().resetHistory();
    addTearDown(() {
      layout.unmountNavigation(owner, navigation);
      MainNavigatorObserver().resetHistory();
    });
    await tester.pumpWidget(GetCupertinoApp(
      home: Navigator(
        key: Get.nestedKey(stack.primaryId),
        onGenerateRoute: (settings) => CupertinoPageRoute<void>(
          settings: settings,
          builder: (_) => CupertinoPageScaffold(
            child: Text('nested:${settings.name}'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(primaryNavigatorId, stack.primaryId);
    final pending = home.openHiddenTab(EHRoutes.download);
    await tester.pumpAndSettle();
    expect(find.text('nested:${EHRoutes.download}'), findsOneWidget);
    expect(Get.nestedKey(stack.primaryId)!.currentState!.canPop(), isTrue);
    expect(Get.key.currentState!.canPop(), isFalse);
    Get.nestedKey(stack.primaryId)!.currentState!.pop();
    await tester.pumpAndSettle();
    await pending;
  });

  testWidgets('hidden routes follow reordering and disappear in safe mode',
      (tester) async {
    await mount(tester);
    home.tabMap.assignAll(
        {for (final route in _routes) route: route == EHRoutes.gallery});
    home.tabNameList.assignAll(_routes.reversed);
    final expected =
        _routes.reversed.where((route) => route != EHRoutes.gallery);
    expect(home.hiddenTabRoutes, expected);
    expect(home.nativeHiddenTabActions.map((action) => action.id),
        expected.map((route) => 'destination:$route'));
    settings.isSafeMode.value = true;
    expect(home.hiddenTabRoutes, isEmpty);
    expect(home.nativeHiddenTabActions, isEmpty);
  });

  testWidgets('a route absent from the visibility map is hidden',
      (tester) async {
    await mount(tester);
    home.tabMap.remove(EHRoutes.download);
    expect(home.hiddenTabRoutes, [EHRoutes.download]);
  });
}
