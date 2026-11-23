import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/controller/block_controller.dart';
import 'package:eros_fe/common/controller/history_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/extension.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/models/tab_config.dart';
import 'package:eros_fe/models/tab_item.dart';
import 'package:eros_fe/pages/setting/controller/tab_setting_controller.dart';
import 'package:eros_fe/pages/setting/tabbar_setting_page.dart';
import 'package:eros_fe/pages/tab/controller/history_view_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/pages/tab/view/history_page.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Settings extends EhSettingService {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Layout extends LayoutServices {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Blocks extends BlockController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _History extends GetxController implements HistoryController {
  final List<GalleryProvider> _items = <GalleryProvider>[];

  @override
  bool get historiesInitialized => true;

  @override
  List<GalleryProvider> get histories => _items;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HistoryView extends GetxController implements HistoryViewController {
  @override
  String? heroTag = EHRoutes.history;

  @override
  final GlobalKey<SliverAnimatedListState> sliverAnimatedListKey =
      GlobalKey<SliverAnimatedListState>();

  @override
  Widget? getLeading(BuildContext context) => const SizedBox.shrink();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Adaptive extends AdaptiveEnvironmentService {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Home extends TabHomeController {
  @override
  // ignore: must_call_super
  void onInit() {
    bindAdaptiveEnvironment();
  }
}

const _duoVerticalBarSnapshot = AdaptiveEnvironmentSnapshot(
  size: Size(430, 620),
  safeArea: EdgeInsets.only(right: 80),
  systemBarEdge: 'right',
  duoVerticalBar: true,
  nativeSupported: true,
);

const _duoInnerPortraitSnapshot = AdaptiveEnvironmentSnapshot(
  size: Size(669, 892),
  safeArea: EdgeInsets.only(top: 54, bottom: 34),
  systemBarEdge: 'bottom',
  duoVerticalBar: false,
  nativeSupported: true,
);

const _allRoutes = <String>[
  EHRoutes.gallery,
  EHRoutes.favorite,
  EHRoutes.toplist,
  EHRoutes.download,
  EHRoutes.history,
];

void main() {
  late _Settings settings;
  late _Adaptive adaptive;
  late _Home home;

  setUp(() {
    Get.testMode = true;
    Get.put<LocaleService>(LocaleService());
    settings = _Settings();
    Get.put<EhSettingService>(settings);
    adaptive = _Adaptive();
    Get.put<AdaptiveEnvironmentService>(adaptive);
    home = _Home()
      ..tabNameList = List<String>.of(_allRoutes).obs
      ..tabMap = <String, bool>{
        for (final route in _allRoutes) route: true,
      }.obs;
    Get.put<TabHomeController>(home);
    home.onInit();
  });

  tearDown(() {
    PlatformCapabilities.debugHostPlatformOverride = null;
    Get.reset();
  });

  Future<void> mount(WidgetTester tester, {Widget? child}) async {
    await tester.pumpWidget(
      GetCupertinoApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: L10n.delegate.supportedLocales,
        localizationsDelegates: const [
          L10n.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) {
            home.init(inContext: context);
            return child ?? const CupertinoPageScaffold(child: Text('home'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'iPhone Duo vertical side bar ignores enabled History tab and keeps it in hidden actions',
    (tester) async {
      await mount(tester);

      // Inner portrait shows all 6 tabs when History is enabled.
      adaptive.snapshot.value = _duoInnerPortraitSnapshot;
      expect(home.suppressesHistoryTabInDuoSidebar, isFalse);
      expect(home.visibleTabRoutes, [
        EHRoutes.gallery,
        EHRoutes.favorite,
        EHRoutes.toplist,
        EHRoutes.download,
        EHRoutes.history,
        EHRoutes.setting,
      ]);
      expect(home.hiddenTabRoutes, isEmpty);
      expect(home.nativeHiddenTabActions, isEmpty);

      // Duo vertical side bar excludes History so Settings stays in slot 5.
      adaptive.snapshot.value = _duoVerticalBarSnapshot;
      expect(home.suppressesHistoryTabInDuoSidebar, isTrue);
      expect(home.visibleTabRoutes, [
        EHRoutes.gallery,
        EHRoutes.favorite,
        EHRoutes.toplist,
        EHRoutes.download,
        EHRoutes.setting,
      ]);
      expect(home.hiddenTabRoutes, [EHRoutes.history]);
      expect(
        home.nativeHiddenTabActions.map((action) => action.id),
        ['destination:${EHRoutes.history}'],
      );
    },
  );

  testWidgets(
    'rotating from inner portrait into Duo side bar keeps Settings selected and falls back from History',
    (tester) async {
      await mount(tester);
      adaptive.snapshot.value = _duoInnerPortraitSnapshot;

      // Selected on Settings (index 5 in 6-tab portrait).
      home.currentIndex = 5;
      home.tabController.index = 5;
      expect(home.currRoute, EHRoutes.setting);

      // Rotate to Duo side bar (5 tabs): Settings remains selected at index 4.
      adaptive.snapshot.value = _duoVerticalBarSnapshot;
      expect(home.currRoute, EHRoutes.setting);
      expect(home.currentIndex, 4);
      expect(home.tabController.index, 4);

      // Rotate back to inner portrait and select History (index 4).
      adaptive.snapshot.value = _duoInnerPortraitSnapshot;
      home.currentIndex = 4;
      home.tabController.index = 4;
      expect(home.currRoute, EHRoutes.history);

      // Rotate to Duo side bar: History is suppressed, falls back to Gallery.
      adaptive.snapshot.value = _duoVerticalBarSnapshot;
      expect(home.currRoute, EHRoutes.gallery);
      expect(home.currentIndex, 0);
      expect(home.tabController.index, 0);
      expect(home.hiddenTabRoutes, [EHRoutes.history]);
    },
  );

  testWidgets(
    'if only History is enabled, Duo side bar falls back to Gallery + Settings and exposes History action',
    (tester) async {
      await mount(tester);
      home.tabMap.assignAll({
        for (final route in _allRoutes) route: route == EHRoutes.history,
      });
      adaptive.snapshot.value = _duoVerticalBarSnapshot;

      expect(home.visibleTabRoutes, [EHRoutes.gallery, EHRoutes.setting]);
      expect(home.hiddenTabRoutes, [
        EHRoutes.favorite,
        EHRoutes.toplist,
        EHRoutes.download,
        EHRoutes.history,
      ]);
    },
  );

  testWidgets(
    'TabbarSettingPage shows Duo sidebar note on iOS and hides it on Android',
    (tester) async {
      PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.iOS;
      await mount(tester, child: const TabbarSettingPage());
      final zh = await L10n.load(const Locale('zh', 'CN'));
      expect(find.textContaining(zh.tab_history_duo_sidebar_note), findsOneWidget);

      PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
      await mount(tester, child: const TabbarSettingPage());
      expect(find.textContaining(zh.tab_history_duo_sidebar_note), findsNothing);
    },
  );

  test('TabConfig keeps History preference intact regardless of Duo suppression', () {
    final config = TabConfig(
      tabItemList: [
        for (final route in _allRoutes) TabItem(name: route, enable: true),
      ],
    );
    expect(config.tabMap[EHRoutes.history], isTrue);
  });

  testWidgets(
    'only-History preference can still be turned off on Duo side bar and restores Gallery',
    (tester) async {
      await mount(tester);
      home.tabMap.assignAll({
        for (final route in _allRoutes) route: route == EHRoutes.history,
      });
      adaptive.snapshot.value = _duoVerticalBarSnapshot;
      final settingController = Get.put(TabSettingController());

      expect(settingController.isSwitchDisabled(EHRoutes.history), isFalse);
      settingController.onChanged(false, EHRoutes.history);
      expect(home.tabMap[EHRoutes.history], isFalse);
      expect(home.tabMap[EHRoutes.gallery], isTrue);
      expect(home.visibleTabRoutes, [EHRoutes.gallery, EHRoutes.setting]);
    },
  );

  testWidgets(
    'mounted offstage HistoryTab and pushed HistoryTab never collide on SliverAnimatedList GlobalKey',
    (tester) async {
      Get.put<LayoutServices>(_Layout());
      Get.put<BlockController>(_Blocks());
      final historyController = Get.put<HistoryController>(_History());
      final historyViewController = Get.put<HistoryViewController>(
        _HistoryView(),
      );

      await mount(
        tester,
        child: Stack(
          children: const [
            Offstage(offstage: true, child: HistoryTab()),
            HistoryTab(),
          ],
        ),
      );
      expect(tester.takeException(), isNull);

      historyController.histories.add(
        const GalleryProvider(gid: '100', token: 'abc', englishTitle: 'Test'),
      );
      HistoryViewController.insertAnimatedListItem(historyViewController, 0);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  test('NativeNavigationState serializes moreTitle and cancelTitle', () {
    const state = NativeNavigationState(
      tabId: EHRoutes.gallery,
      selectedTabId: EHRoutes.gallery,
      title: '画廊',
      moreTitle: '更多',
      cancelTitle: '取消',
    );
    final map = state.toMap();
    expect(map['moreTitle'], '更多');
    expect(map['cancelTitle'], '取消');
  });
}
