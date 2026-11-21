import 'package:eros_fe/adaptive/browse_layout.dart';
import 'package:eros_fe/adaptive/native_sheet.dart';
import 'package:eros_fe/adaptive/native_top_header.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/controller/quicksearch_controller.dart';
import 'package:eros_fe/common/controller/tag_controller.dart';
import 'package:eros_fe/common/controller/tag_trans_controller.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/tab/controller/search_page_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/pages/tab/view/search_page.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/eh_sheet.dart';
import 'package:eros_fe/widget/scroll_edge_effect.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Search extends SearchPageController {
  _Search() : super(controllerTag: 'split-search') {
    searchHistory.assignAll(
      List.generate(30, (i) => 'history query item $i with extra text'),
    );
  }

  @override
  void onInit() {}

  @override
  void onReady() {}
}

class _Layout extends LayoutServices {
  @override
  void onInit() {}
}

class _Settings extends EhSettingService {
  _Settings({this.glassEnabled = false});

  final bool glassEnabled;

  @override
  bool get liquidGlass => glassEnabled;

  @override
  bool get liquidGlassMaterial => true;

  @override
  GlassMaterial get glassMaterial => GlassMaterial.liquid;

  @override
  void onInit() {}
}

class _Theme extends ThemeService {
  @override
  void onInit() {}
}

class _Home extends TabHomeController {
  @override
  void onInit() {}
}

class _Tags extends TagController {
  @override
  void onReady() {}
}

class _TagTranslations extends GetxController implements TagTransController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _QuickSearch extends GetxController implements QuickSearchController {
  @override
  RxList<String> searchTextList = <String>[].obs;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
    Global.profile = kDefProfile;
    Get.put<LocaleService>(LocaleService());
    Get.put<EhSettingService>(_Settings());
    Get.put<ThemeService>(_Theme());
    Get.put<LayoutServices>(_Layout()).layoutMode = LayoutMode.large;
    Get.put<TabHomeController>(_Home());
    Get.put<TagController>(_Tags());
    Get.put<TagTransController>(_TagTranslations());
    Get.put<QuickSearchController>(_QuickSearch());
    Get.put(ControllerTagService());
    Get.put<SearchPageController>(_Search(), tag: 'split-search');
    KeyboardVisibilityTesting.setVisibilityForTesting(false);
    NativeNavigationBridge.enabled.value = true;
    NativeSheet.debugAvailable = false;
  });

  tearDown(() {
    KeyboardVisibilityTesting.setVisibilityForTesting(false);
    NativeNavigationBridge.enabled.value = false;
    NativeSheet.debugAvailable = null;
    Get.reset();
  });

  testWidgets(
    'Duo split floating bar, poppable back button, capsule & scroll fade',
    (tester) async {
      const size = Size(600, 800);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final keyboardInsets = ValueNotifier(EdgeInsets.zero);
      addTearDown(keyboardInsets.dispose);

      const duoViewPadding = EdgeInsets.only(
        left: 80,
        top: 20,
        right: 16,
        bottom: 20,
      );

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
            builder: (context) => CupertinoPageScaffold(
              child: Center(
                child: CupertinoButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => ValueListenableBuilder<EdgeInsets>(
                          valueListenable: keyboardInsets,
                          builder: (_, insets, _) => MediaQuery(
                            data: MediaQueryData(
                              size: size,
                              padding: duoViewPadding,
                              viewPadding: duoViewPadding,
                              viewInsets: insets,
                            ),
                            child: NativeNavigationScope(
                              child: const ControllerTagScope(
                                snapshot: ControllerTagSnapshot(
                                  searchTag: 'split-search',
                                ),
                                child: BrowsePaneScope(
                                  split: true,
                                  child: GallerySearchPage(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('push search'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('push search'));
      await tester.pumpAndSettle();

      // Floating bar + 44pt back button + trailing capsule present, clearing left viewPadding.
      final navPage = tester.widget<NativeNavigationPage>(
        find.byType(NativeNavigationPage),
      );
      expect(navPage.chrome.navigationBarVisible, isFalse);
      expect(navPage.chrome.ownBar, isTrue);

      expect(
        find.byKey(const ValueKey('search.floatingTopBar')),
        findsOneWidget,
      );
      final backFinder = find.byKey(const ValueKey('search.splitBack'));
      expect(backFinder, findsOneWidget);
      final backRect = tester.getRect(backFinder);
      expect(backRect.left, greaterThanOrEqualTo(94));
      expect(backRect.size, const Size(44, 44));

      final capsuleFinder = find.byKey(
        const ValueKey('search.trailingCapsule'),
      );
      expect(capsuleFinder, findsOneWidget);
      final widthWithoutKeyboard = tester.getSize(capsuleFinder).width;
      expect(find.byKey(const ValueKey('search.hideKeyboard')), findsNothing);
      expect(find.byKey(const ValueKey('search.filterAction')), findsOneWidget);
      expect(find.byKey(const ValueKey('search.moreAction')), findsOneWidget);

      // Show keyboard -> dismiss action joins capsule and animates width wider.
      keyboardInsets.value = const EdgeInsets.only(bottom: 260);
      KeyboardVisibilityTesting.setVisibilityForTesting(true);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('search.hideKeyboard')), findsOneWidget);
      expect(
        tester.getSize(capsuleFinder).width,
        greaterThan(widthWithoutKeyboard),
      );

      KeyboardVisibilityTesting.setVisibilityForTesting(false);
      keyboardInsets.value = EdgeInsets.zero;
      await tester.pumpAndSettle();

      // Scroll Edge Effect covers safeTop + topBar + searchField, and activates on scroll.
      var effect = tester.widget<SoftScrollEdgeEffect>(
        find.byType(SoftScrollEdgeEffect),
      );
      expect(effect.strength, 0);
      expect(
        tester.getRect(find.byType(SoftScrollEdgeEffect)).bottom,
        greaterThan(duoViewPadding.top + 80),
      );

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -180));
      await tester.pumpAndSettle();
      effect = tester.widget<SoftScrollEdgeEffect>(
        find.byType(SoftScrollEdgeEffect),
      );
      expect(effect.strength, 1.0);
      expect(
        effect.tail,
        closeTo(
          NativeTopTabHeader.tailFor(
            tester.element(find.byType(GallerySearchPage)),
          ),
          0.5,
        ),
      );

      // Tapping moreAction presents the modern EhSheet instead of CupertinoMenuAnchor.
      await tester.tap(find.byKey(const ValueKey('search.moreAction')));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoMenuAnchor), findsNothing);
      expect(find.byType(EhSheetHeader), findsOneWidget);
      expect(find.byType(EhSheetGroup), findsOneWidget);
      expect(
        find.byKey(const Key('search.moreOption.imageSearch')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('search.moreOption.quickSearchList')),
        findsOneWidget,
      );
      // Disabled action when search query is empty does not dismiss the sheet.
      await tester.tap(
        find.byKey(const Key('search.moreOption.addQuickSearch')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EhSheetHeader), findsOneWidget);
    },
  );

  testWidgets('saved quick search can be selected with keyboard traversal', (
    tester,
  ) async {
    Get.find<QuickSearchController>().searchTextList.assignAll(['saved query']);
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
        home: const ControllerTagScope(
          snapshot: ControllerTagSnapshot(searchTag: 'split-search'),
          child: GallerySearchPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final row = find.ancestor(
      of: find.text('saved query'),
      matching: find.byType(EhPressable),
    );
    expect(row, findsOneWidget);
    final target = tester.element(row);
    var reached = false;
    for (var i = 0; i < 50 && !reached; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.context?.visitAncestorElements((e) {
        reached = identical(e, target);
        return !reached;
      });
    }
    expect(reached, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(
      Get.find<SearchPageController>(tag: 'split-search')
          .searchTextController
          .text,
      'saved query ',
    );
  });

  testWidgets(
    'Duo split top buttons render native Liquid Glass on iOS and fall back when glass is off',
    (tester) async {
      PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => PlatformCapabilities.debugHostPlatformOverride = null);

      Future<void> pumpSplitSearch({required bool glassEnabled}) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await Get.delete<EhSettingService>(force: true);
        Get.put<EhSettingService>(_Settings(glassEnabled: glassEnabled));
        if (!Get.isRegistered<SearchPageController>(tag: 'split-search')) {
          Get.put<SearchPageController>(_Search(), tag: 'split-search');
        }
        const size = Size(600, 800);
        const duoViewPadding = EdgeInsets.only(
          left: 80,
          top: 20,
          right: 16,
          bottom: 20,
        );
        await tester.pumpWidget(
          GetCupertinoApp(
            key: UniqueKey(),
            navigatorKey: GlobalKey<NavigatorState>(),
            locale: const Locale('zh', 'CN'),
            supportedLocales: L10n.delegate.supportedLocales,
            localizationsDelegates: const [
              L10n.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            home: GlassPreference(
              enabled: glassEnabled,
              child: Builder(
                builder: (context) => CupertinoPageScaffold(
                  child: Center(
                    child: CupertinoButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute<void>(
                            builder: (_) => GlassPreference(
                              enabled: glassEnabled,
                              child: MediaQuery(
                                data: const MediaQueryData(
                                  size: size,
                                  padding: duoViewPadding,
                                  viewPadding: duoViewPadding,
                                ),
                                child: NativeNavigationScope(
                                  child: const ControllerTagScope(
                                    snapshot: ControllerTagSnapshot(
                                      searchTag: 'split-search',
                                    ),
                                    child: BrowsePaneScope(
                                      split: true,
                                      child: GallerySearchPage(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: const Text('push glass search'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('push glass search'));
        await tester.pumpAndSettle();
      }

      await pumpSplitSearch(glassEnabled: true);
      final backFinder = find.byKey(const ValueKey('search.splitBack'));
      final capsuleFinder = find.byKey(
        const ValueKey('search.trailingCapsule'),
      );
      expect(
        find.descendant(
          of: backFinder,
          matching: find.byWidgetPredicate(
            (w) => w is UiKitView && w.viewType == LiquidGlassPlatform.viewType,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: capsuleFinder,
          matching: find.byWidgetPredicate(
            (w) => w is UiKitView && w.viewType == LiquidGlassPlatform.viewType,
          ),
        ),
        findsOneWidget,
      );

      // The Flutter control drawn over the native glass remains keyboard usable.
      final target = tester.element(backFinder);
      var reached = false;
      for (var i = 0; i < 40 && !reached; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        FocusManager.instance.primaryFocus?.context?.visitAncestorElements((e) {
          reached = identical(e, target);
          return !reached;
        });
      }
      expect(reached, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(GallerySearchPage), findsNothing);

      await pumpSplitSearch(glassEnabled: false);
      expect(tester.widget<EhButton>(backFinder).style, EhButtonStyle.glass);
      expect(
        find.descendant(of: backFinder, matching: find.byType(UiKitView)),
        findsNothing,
      );
      expect(
        find.descendant(of: capsuleFinder, matching: find.byType(UiKitView)),
        findsNothing,
      );
    },
  );

  testWidgets(
    'iPhone Duo vertical-bar split moves Search filter & more actions to native toolbar and hides inline top bar',
    (tester) async {
      PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => PlatformCapabilities.debugHostPlatformOverride = null);
      await Get.delete<EhSettingService>(force: true);
      Get.put<EhSettingService>(_Settings(glassEnabled: true));
      const size = Size(600, 800);
      const duoViewPadding = EdgeInsets.only(
        left: 16,
        top: 20,
        right: 80,
        bottom: 20,
      );
      await tester.pumpWidget(
        GetCupertinoApp(
          navigatorKey: GlobalKey<NavigatorState>(),
          locale: const Locale('zh', 'CN'),
          supportedLocales: L10n.delegate.supportedLocales,
          localizationsDelegates: const [
            L10n.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: AdaptiveEnvironmentScope(
            snapshot: const AdaptiveEnvironmentSnapshot(
              size: size,
              safeArea: duoViewPadding,
              viewPadding: duoViewPadding,
              systemBarEdge: 'right',
            ),
            child: MediaQuery(
              data: const MediaQueryData(
                size: size,
                padding: duoViewPadding,
                viewPadding: duoViewPadding,
              ),
              child: NativeNavigationScope(
                child: const ControllerTagScope(
                  snapshot: ControllerTagSnapshot(searchTag: 'split-search'),
                  child: BrowsePaneScope(
                    split: true,
                    child: GallerySearchPage(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('search.splitBack')), findsNothing);
      expect(
        find.byKey(const ValueKey('search.trailingCapsule')),
        findsNothing,
      );
      final navPage = tester.widget<NativeNavigationPage>(
        find.byType(NativeNavigationPage),
      );
      expect(navPage.chrome.navigationBarVisible, isTrue);
      expect(navPage.chrome.ownBar, isFalse);
      expect(navPage.chrome.actions.map((a) => a.id).toList(), <String>[
        'filter',
        'search.more',
      ]);
    },
  );
}
