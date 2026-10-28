import 'package:eros_fe/adaptive/browse_layout.dart';
import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/common/controller/quicksearch_controller.dart';
import 'package:eros_fe/common/controller/tag_controller.dart';
import 'package:eros_fe/common/controller/tag_trans_controller.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/tab/controller/search_page_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/pages/tab/view/search_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  testWidgets(
      'production search moves chrome on pane role changes without remounting its editor',
      (tester) async {
    Get.testMode = true;
    Get.put<LocaleService>(LocaleService());
    Get.put<EhSettingService>(_Settings());
    Get.put<ThemeService>(_Theme());
    Get.put<LayoutServices>(_Layout())..layoutMode = LayoutMode.large;
    Get.put<TabHomeController>(_Home());
    Get.put<TagController>(_Tags());
    Get.put<TagTransController>(_TagTranslations());
    Get.put<QuickSearchController>(_QuickSearch());
    Get.put(ControllerTagService());
    final search =
        Get.put<SearchPageController>(_Search(), tag: 'owned-search');
    final split = ValueNotifier(false);
    KeyboardVisibilityTesting.setVisibilityForTesting(false);
    NativeNavigationBridge.enabled.value = true;
    addTearDown(() {
      KeyboardVisibilityTesting.setVisibilityForTesting(false);
      NativeNavigationBridge.enabled.value = false;
      split.dispose();
      Get.reset();
    });
    await tester.pumpWidget(GetCupertinoApp(
      localizationsDelegates: const [L10n.delegate],
      home: MediaQuery(
        data: const MediaQueryData(
          viewInsets: EdgeInsets.only(bottom: 280),
        ),
        child: NativeNavigationScope(
          child: ControllerTagScope(
            snapshot: const ControllerTagSnapshot(searchTag: 'owned-search'),
            child: ValueListenableBuilder(
              valueListenable: split,
              child: const GallerySearchPage(),
              builder: (_, isSplit, child) =>
                  BrowsePaneScope(split: isSplit, child: child!),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final fieldState = tester.state(find.byType(CupertinoTextField));
    final page =
        tester.widget<NativeNavigationPage>(find.byType(NativeNavigationPage));
    expect(page.chrome.navigationBarVisible, isTrue);
    expect(find.byType(CupertinoNavigationBar), findsNothing);
    search.searchTextController.value = const TextEditingValue(
      text: 'Unsent search draft',
      selection: TextSelection(baseOffset: 1, extentOffset: 7),
      composing: TextRange(start: 1, end: 7),
    );
    final draft = search.searchTextController.value;
    for (var cycle = 0; cycle < 20; cycle++) {
      for (final isSplit in [true, false]) {
        split.value = isSplit;
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(CupertinoTextField)), same(fieldState));
        expect(search.searchTextController.value, draft);
        expect(
            tester
                .widget<NativeNavigationPage>(find.byType(NativeNavigationPage))
                .chrome
                .navigationBarVisible,
            !isSplit);
        expect(find.byType(CupertinoNavigationBar),
            isSplit ? findsOneWidget : findsNothing);
        expect(tester.takeException(), isNull);
      }
    }
    split.value = true;
    KeyboardVisibilityTesting.setVisibilityForTesting(true);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('收起键盘'), findsOneWidget);
    search.searchFocusNode.requestFocus();
    await tester.pump();
    expect(search.searchFocusNode.hasFocus, isTrue);
    await tester.tap(find.bySemanticsLabel('收起键盘'));
    await tester.pumpAndSettle();
    expect(search.searchFocusNode.hasFocus, isFalse);
    expect(search.searchTextController.text, draft.text);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Search extends SearchPageController {
  _Search() : super(controllerTag: 'owned-search');
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
