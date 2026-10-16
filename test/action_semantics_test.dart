import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/tab/controller/favorite/favorite_tabbar_controller.dart';
import 'package:eros_fe/pages/tab/controller/search_page_controller.dart';
import 'package:eros_fe/pages/tab/view/search_page.dart';
import 'package:eros_fe/pages/tab/view/tabbar/favorite_tabbar_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Settings extends GetxService implements EhSettingService {
  @override
  bool get liquidGlass => _glass.value;
  final _glass = false.obs;
  @override
  bool get isPureDarkTheme => false;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected setting $invocation');
}

class _Search extends GetxController implements SearchPageController {
  _Search(String text, {this.textIsGalleryUrl = false}) {
    searchTextController.text = text;
  }
  @override
  final searchTextController = TextEditingController();
  @override
  final searchFocusNode = FocusNode();
  @override
  final bool textIsGalleryUrl;
  @override
  bool get autofocus => false;
  @override
  bool get textIsNotEmpty => searchTextController.text.isNotEmpty;
  int added = 0, opened = 0, lists = 0, cleared = 0, refreshed = 0;
  @override
  void addToQuickSearch() => added++;
  @override
  void jumpToGallery() => opened++;
  @override
  Future<void> quickSearchList() async => lists++;
  @override
  void clearText() {
    cleared++;
    searchTextController.clear();
    update([GetIds.SEARCH_CLEAR_BTN]);
  }

  @override
  Future<void> reloadData() async => refreshed++;
  @override
  Future<void> onEditingComplete({bool clear = true}) async {}
  @override
  void onClose() {
    searchTextController.dispose();
    searchFocusNode.dispose();
    super.onClose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected search operation $invocation');
}

class _Favorites extends GetxController implements FavoriteTabBarController {
  final loading = false.obs;
  final jumped = true.obs;
  final order = 'P'.obs;
  int sorted = 0, topped = 0, jumps = 0;
  @override
  bool get isBackgroundRefresh => loading.value;
  @override
  bool get afterJump => jumped.value;
  @override
  String get orderText => order.value;
  @override
  Widget? getLeading(BuildContext context) => null;
  @override
  Future<void> setOrder(BuildContext context) async => sorted++;
  @override
  Future<void> jumpToTop() async => topped++;
  @override
  Future<void> showJumpDialog(BuildContext context) async => jumps++;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected favorite operation $invocation');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    Get.testMode = true;
    Global.profile = kDefProfile;
    Get.put(ControllerTagService());
    Get.put<EhSettingService>(_Settings());
    Get.put(ThemeService());
    KeyboardVisibilityTesting.setVisibilityForTesting(false);
  });
  tearDown(() {
    Get.reset();
  });

  void semanticsTest(String name, Future<void> Function(WidgetTester) action) {
    testWidgets(name, (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await action(tester);
      } finally {
        semantics.dispose();
      }
    });
  }

  Future<void> mount(WidgetTester tester, _Search controller,
      {double scale = 1, bool dark = false, Widget? content}) async {
    Get.put<SearchPageController>(controller, tag: searchPageCtrlTag);
    // The existing widget probes an untyped registration before typed lookup.
    Get.put<dynamic>(controller, tag: searchPageCtrlTag);
    await tester.pumpWidget(GetCupertinoApp(
      locale: const Locale('zh', 'CN'),
      supportedLocales: L10n.delegate.supportedLocales,
      localizationsDelegates: const [
        L10n.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate
      ],
      theme: CupertinoThemeData(
          brightness: dark ? Brightness.dark : Brightness.light),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: content ??
          const CupertinoPageScaffold(
              child: Center(child: SearchTextFieldIn(iconOpacity: 1))),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> activate(WidgetTester tester, String label) async {
    final action = find.bySemanticsLabel(label);
    expect(action, findsOneWidget);
    expect(
        tester
            .getSemantics(action)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue);
    await tester.tap(action);
    await tester.pumpAndSettle();
  }

  semanticsTest('the decorative search prefix exposes no phantom button action',
      (tester) async {
    await mount(tester, _Search(''));
    expect(
        find.ancestor(
            of: find.bySemanticsLabel('搜索'),
            matching: find.byType(CupertinoButton)),
        findsNothing);
    expect(find.byType(CupertinoTextField), findsOneWidget);
  });

  semanticsTest(
      'empty input exposes the quick search list without edit actions',
      (tester) async {
    final controller = _Search('');
    await mount(tester, controller);
    expect(find.bySemanticsLabel('清空搜索词'), findsNothing);
    expect(find.bySemanticsLabel('加入快速搜索'), findsNothing);
    expect(find.bySemanticsLabel('打开画廊链接'), findsNothing);
    await activate(tester, '快速搜索列表');
    expect(controller.lists, 1);
  });

  for (final stress in [false, true]) {
    semanticsTest(
        'text actions retain their callbacks with readable semantics, stress=$stress',
        (tester) async {
      final controller = _Search('neutral query');
      await mount(tester, controller, dark: stress, scale: stress ? 2.5 : 1);
      await activate(tester, '加入快速搜索');
      expect(controller.added, 1);
      await activate(tester, '清空搜索词');
      expect(controller.cleared, 1);
      expect(controller.searchTextController.text, isEmpty);
      expect(find.bySemanticsLabel('加入快速搜索'), findsNothing);
      expect(find.bySemanticsLabel('清空搜索词'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  semanticsTest(
      'gallery URL opens its own action instead of adding quick search',
      (tester) async {
    final controller = _Search('https://e-hentai.org/g/9100000/offline/',
        textIsGalleryUrl: true);
    await mount(tester, controller);
    expect(find.bySemanticsLabel('加入快速搜索'), findsNothing);
    await activate(tester, '打开画廊链接');
    expect(controller.opened, 1);
    expect(controller.added, 0);
  });

  semanticsTest(
      'favorite navigation labels preserve sorting, jump and top actions',
      (tester) async {
    final favorites =
        Get.put<FavoriteTabBarController>(_Favorites()) as _Favorites;
    // Render the actual navigation builder without unrelated network subpages.
    final dynamic state = const FavoriteTabTabBarPage().createState();
    await mount(tester, _Search(''),
        content: Builder(
            builder: (context) => CupertinoPageScaffold(
                    child: Column(children: [
                  state.getNavigationBar(context) as Widget,
                  const Expanded(child: SizedBox.expand())
                ]))));
    final sort = find.bySemanticsLabel(RegExp('收藏排序'));
    expect(sort, findsOneWidget);
    expect(
        tester
            .getSemantics(sort)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue);
    await tester.tap(sort);
    await tester.pumpAndSettle();
    expect(favorites.sorted, 1);
    await activate(tester, '回到顶部');
    await activate(tester, '跳转/搜寻');
    expect(favorites.topped, 1);
    expect(favorites.jumps, 1);
    expect(find.bySemanticsLabel('搜索'), findsOneWidget);
  });

  semanticsTest('desktop refresh remains actionable through its new label',
      (tester) async {
    final controller = _Search('query');
    await mount(tester, controller);
    expect(GetPlatform.isDesktop, isTrue);
    await activate(tester, '刷新');
    expect(controller.refreshed, 1);
  });
}
