import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/component/setting/setting_menu.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/models/simple_tag.dart';
import 'package:eros_fe/pages/item/gallery_item_flow_large.dart';
import 'package:eros_fe/pages/setting/setting_items/selector_Item.dart';
import 'package:eros_fe/pages/tab/view/list/waterfall_flow.dart';
import 'package:eros_fe/widget/canvas_grain.dart';
import 'package:eros_fe/widget/cupertino/list_tile.dart';
import 'package:eros_fe/widget/cupertino/sliver_list_section.dart';
import 'package:eros_fe/widget/scroll_edge_effect.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/waterfall_fixture.dart';

const GalleryProvider _gallery = GalleryProvider(
  gid: 'card',
  englishTitle: '[Circle (Artist)] A long neutral title that runs past '
      'two lines on a phone card [Chinese]',
  category: 'Doujinshi',
  translated: 'ZH',
  imgUrl: '',
  imgWidth: 200,
  imgHeight: 280,
  filecount: '48',
  rating: 4.5,
  ratingFallBack: 4.5,
  colorRating: 'ir',
  postTime: '2026-10-15 12:30',
  simpleTags: [
    SimpleTag(text: 'full color', backgrondColor: '#d03030'),
    SimpleTag(text: 'neutral'),
    SimpleTag(text: 'illustration'),
  ],
);

const GalleryProvider _second = GalleryProvider(
  gid: 'card-2',
  englishTitle: 'Short title',
  category: 'Manga',
  imgUrl: '',
  imgWidth: 200,
  imgHeight: 300,
  filecount: '20',
  rating: 3.0,
  ratingFallBack: 3.0,
  colorRating: 'ir',
  postTime: '2025-01-02 08:00',
  simpleTags: [SimpleTag(text: 'tag')],
);

void _phone(WidgetTester tester, {double height = 874}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(402, height);
  addTearDown(tester.view.reset);
}

CupertinoThemeData _theme(Brightness brightness) =>
    EhPalette.graphite.themeData(brightness, ehTextTheme);

Widget _cards(Brightness brightness) {
  return GetMaterialApp(
    debugShowCheckedModeBanner: false,
    home: CupertinoTheme(
      data: _theme(brightness),
      child: MediaQuery(
        data: MediaQueryData(
          size: const Size(402, 874),
          platformBrightness: brightness,
        ),
        child: const CupertinoPageScaffold(
          child: CustomScrollView(slivers: [
            EhWaterfallFlow([_gallery, _second], 'fixture', large: true),
          ]),
        ),
      ),
    ),
  );
}

Widget _settings(Brightness brightness, List<Widget> slivers) {
  return CupertinoApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('en'),
    theme: _theme(brightness),
    supportedLocales: L10n.delegate.supportedLocales,
    localizationsDelegates: const [
      L10n.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    home: CupertinoPageScaffold(
      child: CustomScrollView(slivers: [
        SliverSafeArea(sliver: SliverList.list(children: const [])),
        ...slivers,
      ]),
    ),
  );
}

List<Widget> _settingSections() => <Widget>[
      SliverCupertinoListSection.listInsetGrouped(
        header: const Text('Browsing'),
        hasLeading: true,
        children: const [
          EhCupertinoListTile(
            leading: Icon(CupertinoIcons.square_grid_2x2, size: 22),
            title: Text('Appearance'),
            additionalInfo: Text('Waterfall'),
            trailing: CupertinoListTileChevron(),
          ),
          EhCupertinoListTile(
            leading: Icon(CupertinoIcons.book, size: 22),
            title: Text('Reading'),
            trailing: CupertinoListTileChevron(),
          ),
        ],
      ),
      SliverCupertinoListSection.listInsetGrouped(
        footer: const Text('Only effective in gallery page'),
        children: [
          SelectorCupertinoListTile<bool>(
            title: 'Card Style',
            actionMap: const {false: 'Standard', true: 'Immersive'},
            initVal: false,
          ),
          EhCupertinoListTile(
            title: const Text('Japanese title'),
            trailing: CupertinoSwitch(value: true, onChanged: (_) {}),
          ),
        ],
      ),
    ];

void main() {
  setUp(registerWaterfallFixture);
  tearDown(() {
    SettingGlassBar.debugActive = null;
    Get.reset();
  });

  group('switches', () {
    test('take the accent from the theme', () {
      for (final brightness in Brightness.values) {
        final theme = _theme(brightness);
        expect(theme.applyThemeToAll, isTrue);
        expect(theme.primaryColor, EhPalette.accent);
      }
    });
  });

  group('glass bar', () {
    Future<void> pushSetting(WidgetTester tester, Widget page) async {
      await tester.pumpWidget(_settings(Brightness.light, const []));
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(CupertinoPageRoute<void>(builder: (_) => page));
      await tester.pumpAndSettle();
    }

    testWidgets('replaces the Flutter bar when Liquid Glass is on',
        (tester) async {
      _phone(tester);
      SettingGlassBar.debugActive = true;
      var added = 0;
      await pushSetting(
        tester,
        SettingScaffold(
          title: 'Appearance',
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => added++,
            child: const Icon(CupertinoIcons.add),
          ),
          child: CustomScrollView(slivers: [
            SliverSafeArea(
              sliver: SliverToBoxAdapter(
                child: Container(key: const ValueKey('first'), height: 1200),
              ),
            ),
          ]),
        ),
      );

      expect(find.byType(CupertinoNavigationBar), findsNothing);
      expect(find.byType(SettingGlassBar), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      // Content starts under the transparent bar, below its 44pt row.
      expect(tester.getTopLeft(find.byKey(const ValueKey('first'))).dy,
          SettingGlassBar.barHeight);

      // The soft edge waits until content slides under the bar.
      double edgeOpacity() => tester
          .widget<AnimatedOpacity>(find.ancestor(
              of: find.byType(SoftScrollEdgeEffect),
              matching: find.byType(AnimatedOpacity)))
          .opacity;
      expect(edgeOpacity(), 0);
      await tester.drag(find.byKey(const ValueKey('first')),
          const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(edgeOpacity(), 1);

      await tester.tap(find.byIcon(CupertinoIcons.add));
      expect(added, 1);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingGlassBar), findsNothing);
    });

    testWidgets('keeps the Flutter bar when Liquid Glass is off',
        (tester) async {
      _phone(tester);
      SettingGlassBar.debugActive = false;
      await pushSetting(
        tester,
        const SettingScaffold(title: 'Appearance', child: SizedBox.expand()),
      );
      expect(find.byType(CupertinoNavigationBar), findsOneWidget);
      expect(find.byType(SettingGlassBar), findsNothing);
    });

    testWidgets('a root page has no back button', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_settings(Brightness.light, const []));
      await tester.pumpWidget(CupertinoApp(
        home: CupertinoPageScaffold(
          navigationBar: const SettingGlassBar(
            title: 'Settings',
            titleVisible: false,
          ),
          child: Container(),
        ),
      ));
      expect(find.byIcon(CupertinoIcons.chevron_back), findsNothing);
      final title = tester.widget<AnimatedOpacity>(find.ancestor(
          of: find.text('Settings'), matching: find.byType(AnimatedOpacity)));
      expect(title.opacity, 0);
    });
  });

  group('canvas grain', () {
    test('is 3% in light, 2.5% in graphite and off on pure black', () {
      expect(
          CanvasGrain.opacityFor(EhPalette.graphite.canvas.color, dark: false),
          0.03);
      expect(
          CanvasGrain.opacityFor(EhPalette.graphite.canvas.darkColor,
              dark: true),
          0.025);
      expect(
          CanvasGrain.opacityFor(EhPalette.oled.canvas.darkColor, dark: true),
          0);
    });

    testWidgets('steps aside for increased contrast', (tester) async {
      Widget grain({required bool highContrast}) => CupertinoTheme(
            data: _theme(Brightness.light),
            child: MediaQuery(
              data: MediaQueryData(highContrast: highContrast),
              child: const CanvasGrain(child: SizedBox.expand()),
            ),
          );
      Finder painter() => find.descendant(
          of: find.byType(CanvasGrain), matching: find.byType(CustomPaint));

      await tester.pumpWidget(grain(highContrast: false));
      expect(painter(), findsOneWidget);
      await tester.pumpWidget(grain(highContrast: true));
      expect(painter(), findsNothing);
    });
  });

  group('immersive large cards', () {
    testWidgets('keep only the cover, with the title on it', (tester) async {
      _phone(tester);
      Get.find<EhSettingService>().immersiveLargeCards = true;
      await tester.pumpWidget(_cards(Brightness.dark));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final card = find.byType(GalleryItemFlowLarge).first;
      // 402 − 2×12 margin − a 6pt seam, over two columns.
      expect(tester.getSize(card).width, closeTo(186, 0.01));
      expect(find.textContaining('A long neutral title'), findsOneWidget);
      expect(find.text('ZH · 48P'), findsOneWidget);
      expect(find.text('4.5'), findsOneWidget);
      // No info block: tags and the date stay off the card.
      expect(find.text('full color'), findsNothing);
      expect(find.text('10-15'), findsNothing);

      // The card is the cover's height alone.
      final cardRect = tester.getRect(card);
      expect(cardRect.height, closeTo(186 * 280 / 200, 0.5));
    });

    testWidgets('switch back to the standard card', (tester) async {
      _phone(tester);
      final settings = Get.find<EhSettingService>();
      settings.immersiveLargeCards = true;
      await tester.pumpWidget(_cards(Brightness.light));
      await tester.pumpAndSettle();
      settings.immersiveLargeCards = false;
      await tester.pumpAndSettle();
      expect(find.text('full color'), findsOneWidget);
      expect(tester.getSize(find.byType(GalleryItemFlowLarge).first).width,
          closeTo(184, 0.01));
    });
  });

  group('goldens', () {
    for (final brightness in Brightness.values) {
      final name = brightness.name;
      testWidgets('large cards, standard, $name', (tester) async {
        _phone(tester, height: 420);
        await tester.pumpWidget(_cards(brightness));
        await tester.pumpAndSettle();
        await expectLater(find.byType(CupertinoPageScaffold),
            matchesGoldenFile('goldens/large_cards_standard_$name.png'));
      });

      testWidgets('large cards, immersive, $name', (tester) async {
        _phone(tester, height: 420);
        Get.find<EhSettingService>().immersiveLargeCards = true;
        await tester.pumpWidget(_cards(brightness));
        await tester.pumpAndSettle();
        await expectLater(find.byType(CupertinoPageScaffold),
            matchesGoldenFile('goldens/large_cards_immersive_$name.png'));
      });

      testWidgets('setting rows, $name', (tester) async {
        _phone(tester, height: 420);
        await tester.pumpWidget(_settings(brightness, _settingSections()));
        await tester.pumpAndSettle();
        expect(find.byType(SettingMenuButton<bool>), findsOneWidget);
        await expectLater(find.byType(CupertinoPageScaffold),
            matchesGoldenFile('goldens/setting_rows_$name.png'));
      });
    }
  });
}
