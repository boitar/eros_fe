import 'package:enum_to_string/enum_to_string.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/extension.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/custom_profile.dart';
import 'package:eros_fe/models/item_config.dart';
import 'package:eros_fe/pages/item/controller/galleryitem_controller.dart';
import 'package:eros_fe/pages/item/gallery_grid_tags.dart';
import 'package:eros_fe/pages/item/gallery_item.dart';
import 'package:eros_fe/pages/item/gallery_item_grid.dart';
import 'package:eros_fe/pages/item/gallery_item_grid_placeholder.dart';
import 'package:eros_fe/pages/setting/item_width_setting_page.dart';
import 'package:eros_fe/pages/tab/view/list/grid.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import 'support/grid_tags_fixture.dart';

void main() {
  Logger.level = Level.off;
  late GridTagsFixtureSettings settings;
  late GridTagsFixtureTheme theme;
  final galleries = gridTagsFixtureGalleries();
  final controllers = <GridTagsFixtureController>[];

  setUp(() {
    settings = Get.put<EhSettingService>(GridTagsFixtureSettings())
        as GridTagsFixtureSettings;
    theme =
        Get.put<ThemeService>(GridTagsFixtureTheme()) as GridTagsFixtureTheme;
    Get.put<LayoutServices>(GridTagsFixtureLayout());
    registerGridMasterDependencies();
    controllers.clear();
    for (final gallery in galleries) {
      final controller = GridTagsFixtureController(gallery);
      controllers.add(controller);
      Get.put<GalleryItemController>(controller, tag: gallery.gid);
    }
  });
  tearDown(() => Get.reset());

  Future<void> mount(
    WidgetTester tester, {
    double width = 390,
    double height = 1700,
    double scale = 1,
    bool dark = false,
    bool placeholders = false,
    Widget? home,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    theme.dark.value = dark;
    await tester.pumpWidget(GetCupertinoApp(
      locale: const Locale('zh', 'CN'),
      supportedLocales: L10n.delegate.supportedLocales,
      localizationsDelegates: const [
        L10n.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
      ],
      theme: CupertinoThemeData(
        brightness: dark ? Brightness.dark : Brightness.light,
        textTheme: ehTextTheme,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: home ??
          CupertinoPageScaffold(
            child: CustomScrollView(slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(6),
                sliver: GalleryGridTagsSliver(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => placeholders
                        ? GalleryItemGridPlaceHolder(
                            key: ValueKey('placeholder-$index'), showTags: true)
                        : GalleryItemGrid(
                            key: ValueKey('card-$index'),
                            galleryProvider: galleries[index],
                            tabTag: 'grid-tags-test',
                            showTags: true,
                          ),
                    childCount: galleries.length,
                  ),
                ),
              ),
            ]),
          ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  for (final width in [375.0, 390.0, 430.0, 844.0, 1024.0]) {
    testWidgets('real cards align across covers and tag counts at width=$width',
        (tester) async {
      await mount(tester, width: width);
      final cards = [
        for (var i = 0; i < galleries.length; i++)
          tester.getRect(find.byKey(ValueKey('card-$i'))),
      ];
      for (final rect in cards) {
        expect(rect.size.width, closeTo(cards.first.width, .01));
        expect(rect.size.height, closeTo(cards.first.height, .01));
      }
      if (width <= 430) {
        expect(cards.take(3).map((r) => r.top).toSet(), hasLength(1));
        expect(cards[3].top, greaterThan(cards[0].bottom));
      }
      final card = find.byKey(const ValueKey('card-0'));
      final info =
          find.descendant(of: card, matching: find.byType(GalleryGridTagsInfo));
      final tags = find.descendant(
          of: card, matching: find.byKey(const ValueKey('grid-tags-tags')));
      expect(tester.getSize(info).height, closeTo(112, .01));
      expect(tester.getSize(tags).height, closeTo(40, .01));
      expect(tester.takeException(), isNull);
    });
  }

  for (final scale in [1.0, 2.4, 3.2]) {
    for (final dark in [false, true]) {
      testWidgets('scaled title and both tag rows fit, scale=$scale dark=$dark',
          (tester) async {
        await mount(tester, width: 375, scale: scale, dark: dark);
        final card = find.byKey(const ValueKey('card-0'));
        final tags = find.descendant(
            of: card, matching: find.byKey(const ValueKey('grid-tags-tags')));
        final tagBounds = tester.getRect(tags);
        final pills = find.descendant(of: tags, matching: find.byType(TagItem));
        for (final pill in pills.evaluate()) {
          final box = pill.renderObject as RenderBox;
          final position = box.localToGlobal(Offset.zero);
          expect(position.dy, greaterThanOrEqualTo(tagBounds.top - .01));
          expect(position.dy + box.size.height,
              lessThanOrEqualTo(tagBounds.bottom + .01));
        }
        final time = tester.widget<Text>(find.descendant(
          of: card,
          matching: find.descendant(
            of: find.byKey(const ValueKey('grid-tags-time')),
            matching: find.byType(Text),
          ),
        ));
        final background =
            dark ? const Color(0xff202020) : CupertinoColors.white;
        final foreground = Color.alphaBlend(time.style!.color!, background);
        final luminances = [
          foreground.computeLuminance(),
          background.computeLuminance()
        ]..sort();
        expect((luminances.last + .05) / (luminances.first + .05),
            greaterThanOrEqualTo(4.5));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'horizontal tags do not trigger the card and vertical browsing works',
      (tester) async {
    await mount(tester, height: 500);
    final tags = find.descendant(
        of: find.byKey(const ValueKey('card-0')),
        matching: find.byKey(const ValueKey('grid-tags-tags')));
    final horizontal =
        find.descendant(of: tags, matching: find.byType(Scrollable));
    final position = tester.state<ScrollableState>(horizontal).position;
    await tester.drag(tags, const Offset(-90, 0));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
    expect(controllers[0].taps, 0);
    expect(controllers[0].longPresses, 0);
    await tester.tap(find.text(galleries[0].englishTitle!));
    expect(controllers[0].taps, 1);
    await tester.longPress(find.text(galleries[0].englishTitle!));
    expect(controllers[0].longPresses, 1);
    final vertical = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((state) => state.position.axis == Axis.vertical)
        .position;
    await tester.drag(
        find.byKey(const ValueKey('card-0')), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(vertical.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('translation, custom tag colors, and tag limit stay reactive',
      (tester) async {
    await mount(tester);
    final info = find.descendant(
        of: find.byKey(const ValueKey('card-0')),
        matching: find.byType(GalleryGridTagsInfo));
    final before = tester.getSize(info);
    settings.isTagTranslate = true;
    settings.listViewTagLimit = 1;
    await tester.pumpAndSettle();
    expect(
        find.descendant(of: info, matching: find.text('汉语')), findsOneWidget);
    final tag = tester.widget<TagItem>(
        find.descendant(of: info, matching: find.byType(TagItem)));
    expect(tag.color, const Color(0xffffffff));
    expect(tag.backgroundColor, const Color(0xffd72533));
    settings.listViewTagLimit = 0;
    await tester.pumpAndSettle();
    expect(find.descendant(of: info, matching: find.byType(TagItem)),
        findsNothing);
    expect(tester.getSize(info), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('skeleton-to-card replacement preserves row positions',
      (tester) async {
    await mount(tester, placeholders: true);
    final before = tester.getRect(find.byKey(const ValueKey('placeholder-3')));
    await mount(tester);
    expect(tester.getRect(find.byKey(const ValueKey('card-3'))), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'production grid reacts to its saved width without changing the old grid',
      (tester) async {
    await mount(tester,
        home: CupertinoPageScaffold(
          child: CustomScrollView(slivers: [
            EhGridView(galleries, 'production-grid-test',
                mode: ListModeEnum.gridTags),
          ]),
        ));
    final tile = find.byWidgetPredicate((widget) =>
        widget is GalleryItemGrid || widget is GalleryItemGridPlaceHolder);
    expect(tester.getSize(tile.first).width, closeTo(122, .01));
    settings.configs[ListModeEnum.gridTags] =
        const ItemConfig(type: 'gridTags', cardSize: 4);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(tile.first).width, closeTo(186, .01));
    // A width from the old setting lands on the nearest card size.
    settings.configs[ListModeEnum.gridTags] = const ItemConfig(
        type: 'gridTags', enableCustomWidth: true, customWidth: 220);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(tile.first).width, closeTo(186, .01));
    expect(const EhGridView([], 'old-grid').getMaxCrossAxisExtent(), 150);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each mode keeps its own card size', (tester) async {
    settings.configs[ListModeEnum.grid] =
        const ItemConfig(type: 'grid', cardSize: 0);
    expect(const EhGridView([], 'test').getMaxCrossAxisExtent(),
        closeTo(150 * 102 / 168, .01));
    expect(
        const EhGridView([], 'test', mode: ListModeEnum.gridTags)
            .getMaxCrossAxisExtent(),
        150);
    await mount(tester,
        home: const ItemWidthSettingPage(screen: Size(390, 844)));
    // The value shares one text run with its pull-down chevron.
    expect(find.textContaining('网格 - 标签'), findsOneWidget);
    await tester.tap(find.text('较大'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(settings.configs[ListModeEnum.gridTags]?.cardSize, 3);
    expect(settings.configs[ListModeEnum.grid]?.cardSize, 0);
    expect(tester.takeException(), isNull);
  });

  test('mode and custom-tab/width settings survive string serialization', () {
    expect(EnumToString.fromString(ListModeEnum.values, 'gridTags'),
        ListModeEnum.gridTags);
    const profile = CustomProfile(
        uuid: 'fixture', name: 'Tagged', listModeValue: 'gridTags');
    expect(CustomProfile.fromJson(profile.toJson()).listMode,
        ListModeEnum.gridTags);
    const size = ItemConfig(type: 'gridTags', cardSize: 4);
    final restored = ItemConfig.fromJson(size.toJson());
    expect(restored, size);
    settings.configs[
            EnumToString.fromString(ListModeEnum.values, restored.type)!] =
        restored;
    expect(
        const EhGridView([], 'test', mode: ListModeEnum.gridTags)
            .getMaxCrossAxisExtent(),
        closeTo(150 * 250 / 168, .01));
    expect(const EhGridView([], 'test').getMaxCrossAxisExtent(), 150);
  });
}
