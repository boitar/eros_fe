import 'package:eros_fe/common/controller/advance_search_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/filter/filter.dart';
import 'package:eros_fe/pages/tab/controller/gallery_filter_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Settings extends GetxService implements EhSettingService {
  @override
  bool get liquidGlass => false;
  @override
  final RxBool vibrate = false.obs;
  @override
  bool get isPureDarkTheme => false;
  @override
  RxBool get pureDarkThemeObs => false.obs;
  @override
  final RxInt catFilter = 0.obs;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected setting $invocation');
}

class _FakeAdvanceSearchController extends GetxController
    implements AdvanceSearchController {
  final RxBool _enableAdvance = false.obs;
  @override
  bool get enableAdvance => _enableAdvance.value;
  @override
  set enableAdvance(bool val) => _enableAdvance.value = val;

  @override
  Rx<AdvanceSearch> advanceSearch = kDefAdvanceSearch.obs;

  @override
  void reset() {
    advanceSearch(kDefAdvanceSearch);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Settings settings;
  late _FakeAdvanceSearchController adv;

  setUp(() {
    Get.testMode = true;
    Global.profile = kDefProfile;
    settings = Get.put<_Settings>(_Settings());
    Get.put<EhSettingService>(settings);
    Get.put(ThemeService());
    adv = _FakeAdvanceSearchController();
    Get.put<AdvanceSearchController>(adv);
  });

  tearDown(() {
    Get.reset();
  });

  Widget host() => GetCupertinoApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: L10n.delegate.supportedLocales,
        localizationsDelegates: const [
          L10n.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: CupertinoPageScaffold(
          child: Builder(
            builder: (context) => CupertinoButton(
              onPressed: () => presentFilterSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      );

  testWidgets('category bitmask, invert, select all, reset and done work', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Tap Doujinshi (bit 2) to exclude it.
    await tester.tap(find.byKey(const ValueKey('filter_cat_Doujinshi')));
    await tester.pumpAndSettle();
    expect(settings.catFilter.value, EHConst.cats['Doujinshi']);

    // Invert selection -> Doujinshi active, all other 9 excluded (1023 - 2 = 1021).
    await tester.tap(find.byKey(const ValueKey('filter_invert')));
    await tester.pumpAndSettle();
    expect(settings.catFilter.value, 1023 - EHConst.cats['Doujinshi']!);

    // Enable advanced options and toggle torrent-only.
    await tester.tap(find.byType(CupertinoSwitch).first);
    await tester.pumpAndSettle();
    expect(adv.enableAdvance, isTrue);
    await tester.ensureVisible(find.text('仅显示有种子的画廊'));
    await tester.tap(find.byType(CupertinoSwitch).at(1));
    await tester.pumpAndSettle();
    expect(adv.advanceSearch.value.requireGalleryTorrent, isTrue);

    // Reset clears catFilter, disables advance, and clears page range text.
    final filterCtrl = Get.find<GalleryFilterController>();
    filterCtrl.statrPageCtrl.text = '10';
    await tester.tap(find.byKey(const ValueKey('filter_reset')));
    await tester.pumpAndSettle();
    expect(settings.catFilter.value, 0);
    expect(adv.enableAdvance, isFalse);
    expect(adv.advanceSearch.value.requireGalleryTorrent, isFalse);
    expect(filterCtrl.statrPageCtrl.text, isEmpty);

    // Select all button disabled when catFilter == 0, enabled after excluding one.
    await tester.tap(find.byKey(const ValueKey('filter_cat_Manga')));
    await tester.pumpAndSettle();
    expect(settings.catFilter.value, EHConst.cats['Manga']);
    await tester.tap(find.byKey(const ValueKey('filter_select_all')));
    await tester.pumpAndSettle();
    expect(settings.catFilter.value, 0);

    await tester.tap(find.byKey(const ValueKey('filter_done')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filter_done')), findsNothing);
  });
}
