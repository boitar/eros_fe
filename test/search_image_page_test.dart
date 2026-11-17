import 'package:eros_fe/common/controller/block_controller.dart';
import 'package:eros_fe/common/controller/tag_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/tab/controller/search_image_controller.dart';
import 'package:eros_fe/pages/tab/controller/search_page_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/pages/tab/view/search_image_page.dart';
import 'package:eros_fe/widget/scroll_edge_effect.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

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

class _Layout extends LayoutServices {
  @override
  void onInit() {}
}

class _Block extends BlockController {
  @override
  void onInit() {}
}

class _FakeSearchImageController extends SearchImageController {
  int startSearchCount = 0;
  int pickCount = 0;

  @override
  void onInit() {}

  @override
  void onReady() {}

  @override
  Future<void> selectSearchImage(BuildContext context) async {
    pickCount += 1;
    imagePath = '/tmp/nonexistent_cover_sample.png';
  }

  @override
  Future<void> startSearch({bool clear = true}) async {
    startSearchCount += 1;
    listType = ListType.gallery;
    change(const <GalleryProvider>[], status: RxStatus.success());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSearchImageController controller;

  setUp(() {
    Get.testMode = true;
    Global.profile = kDefProfile;
    Get.put<LocaleService>(LocaleService());
    final settings = Get.put<_Settings>(_Settings());
    Get.put<EhSettingService>(settings);
    Get.put<ThemeService>(_Theme());
    Get.put<LayoutServices>(_Layout()).layoutMode = LayoutMode.large;
    Get.put<TabHomeController>(_Home());
    Get.put<TagController>(_Tags());
    Get.put<BlockController>(_Block());
    controller = _FakeSearchImageController();
    Get.put<SearchImageController>(controller);
  });

  tearDown(() {
    Get.reset();
  });

  Widget host({EdgeInsets viewPadding = EdgeInsets.zero}) => GetCupertinoApp(
    locale: const Locale('zh', 'CN'),
    supportedLocales: L10n.delegate.supportedLocales,
    localizationsDelegates: const [
      L10n.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(padding: viewPadding, viewPadding: viewPadding),
        child: const SearchImagePage(),
      ),
    ),
  );

  testWidgets('narrow flow picks image, toggles options, collapses on search', (
    tester,
  ) async {
    const size = Size(390, 844);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('search_image_narrow_layout')),
      findsOneWidget,
    );
    expect(controller.similarScan.value, isTrue);
    expect(controller.onlyCovers.value, isFalse);
    expect(controller.includeExpunged.value, isFalse);

    // Disabled when no image selected.
    await tester.tap(find.byKey(const ValueKey('search_image_start_button')));
    await tester.pumpAndSettle();
    expect(controller.startSearchCount, 0);

    // Pick image -> preview + change + clear appear.
    await tester.tap(find.byKey(const ValueKey('search_image_picker_card')));
    await tester.pumpAndSettle();
    expect(controller.pickCount, 1);
    expect(find.byKey(const ValueKey('search_image_preview')), findsOneWidget);
    expect(find.byKey(const ValueKey('search_image_change')), findsOneWidget);
    expect(find.byKey(const ValueKey('search_image_clear')), findsOneWidget);

    // Toggle switches.
    await tester.tap(find.byKey(const ValueKey('search_image_covers_switch')));
    await tester.tap(find.byKey(const ValueKey('search_image_expunged_switch')));
    await tester.pumpAndSettle();
    expect(controller.onlyCovers.value, isTrue);
    expect(controller.includeExpunged.value, isTrue);

    // Clear resets back to empty picker.
    await tester.tap(find.byKey(const ValueKey('search_image_clear')));
    await tester.pumpAndSettle();
    expect(controller.imagePath, isEmpty);
    expect(find.byKey(const ValueKey('search_image_preview')), findsNothing);

    // Pick again and start search -> collapses to compact summary bar + edge fade.
    await tester.tap(find.byKey(const ValueKey('search_image_picker_card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('search_image_start_button')));
    await tester.pumpAndSettle();

    expect(controller.startSearchCount, 1);
    expect(
      find.byKey(const ValueKey('search_image_summary_bar')),
      findsOneWidget,
    );
    expect(find.byType(SoftScrollEdgeEffect), findsWidgets);
  });

  testWidgets('wide / Duo landscape uses 2-column layout and respects viewPadding', (
    tester,
  ) async {
    const size = Size(900, 600);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const duoViewPadding = EdgeInsets.only(left: 120, top: 24, right: 20, bottom: 20);
    await tester.pumpWidget(host(viewPadding: duoViewPadding));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('search_image_wide_layout')),
      findsOneWidget,
    );
    final cardRect = tester.getRect(
      find.byKey(const ValueKey('search_image_picker_card')),
    );
    expect(cardRect.left, greaterThanOrEqualTo(136));
  });
}
