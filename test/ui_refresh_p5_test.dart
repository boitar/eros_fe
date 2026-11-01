import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/native_navigation.dart';
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
import 'package:flutter/rendering.dart';
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

    testWidgets('a page with its own bar starts where the native bar leaves it',
        (tester) async {
      _phone(tester);
      tester.view.padding = const FakeViewPadding(top: 70);
      addTearDown(tester.view.resetPadding);
      SettingGlassBar.debugActive = true;
      NativeNavigationBridge.enabled.value = true;
      addTearDown(() => NativeNavigationBridge.enabled.value = false);
      Widget group(String barEdge) => NativeNavigationScope(
            child: AdaptiveEnvironmentScope(
              snapshot: AdaptiveEnvironmentSnapshot(
                size: const Size(402, 874),
                safeArea: const EdgeInsets.only(top: 70),
                windowSafeArea: const EdgeInsets.only(top: 20),
                systemBarEdge: barEdge,
              ),
              child: const SettingScaffold(
                title: 'Group',
                nativeChrome: false,
                child: SizedBox.expand(),
              ),
            ),
          );

      // Across the top the shell's bar is still there while this page
      // slides in; the page starts under the window's own inset at once.
      await pushSetting(tester, group('top'));
      expect(tester.getCenter(find.text('Group')).dy,
          20 + SettingGlassBar.barHeight / 2);
      final route = ModalRoute.of(tester.element(find.text('Group')))!;
      expect(NativeNavigationBridge.chromeFor(route)!.ownBar, isTrue);

      // Beside the vertical bar the shell keeps its empty band for the
      // page, so it follows the live inset like its neighbours.
      await pushSetting(tester, group('right'));
      expect(tester.getCenter(find.text('Group')).dy,
          70 + SettingGlassBar.barHeight / 2);
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
      CustomPainter? painter() => tester
          .widget<CustomPaint>(find.descendant(
              of: find.byType(CanvasGrain),
              matching: find.byType(CustomPaint)))
          .painter;

      await tester.pumpWidget(grain(highContrast: false));
      expect(painter(), isNotNull);
      await tester.pumpWidget(grain(highContrast: true));
      expect(painter(), isNull);
    });

    testWidgets('keeps what it covers when the canvas turns pure black',
        (tester) async {
      var mounts = 0;
      Widget grain(EhPalette palette) => CupertinoTheme(
            data: palette.themeData(Brightness.dark, ehTextTheme),
            child: CanvasGrain(child: _MountCounter(onMount: () => mounts++)),
          );

      await tester.pumpWidget(grain(EhPalette.graphite));
      await tester.pumpWidget(grain(EhPalette.oled));
      await tester.pumpWidget(grain(EhPalette.graphite));
      // The tabs' navigators sit under the grain; rebuilding them drops the
      // pages' routes from their records.
      expect(mounts, 1);
    });

    testWidgets('shades the canvas evenly, across every tile seam',
        (tester) async {
      tester.view.physicalSize = const Size(300, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      for (final brightness in Brightness.values) {
        final dark = brightness == Brightness.dark;
        final canvas = dark
            ? EhPalette.graphite.canvas.darkColor
            : EhPalette.graphite.canvas.color;
        await tester.pumpWidget(RepaintBoundary(
          key: boundary,
          child: CupertinoTheme(
            data: EhPalette.graphite.themeData(brightness, ehTextTheme),
            child: ColoredBox(
              color: canvas,
              child: const CanvasGrain(child: SizedBox.expand()),
            ),
          ),
        ));
        // The noise tile decodes outside the frame.
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
        final pixels = (await tester.runAsync(() async {
          final image = await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
          return image.toByteData();
        }))!;
        final base = (canvas.r * 255).round();
        // White grain over graphite, black grain over light: on average half
        // the strength of a full-alpha texel.
        final opacity = CanvasGrain.opacityFor(canvas, dark: dark);
        final expected =
            (dark ? 255 - base : base) * opacity * 0.5 * (dark ? 1 : -1);
        final columns = List<double>.filled(300, 0);
        final rows = List<double>.filled(300, 0);
        for (var y = 0; y < 300; y++) {
          for (var x = 0; x < 300; x++) {
            final shift = pixels.getUint8((y * 300 + x) * 4) - base;
            columns[x] += shift / 300;
            rows[y] += shift / 300;
          }
        }
        // A seam left bare, or a texture of the wrong strength, puts a whole
        // line of pixels outside this band.
        for (final line in [...columns, ...rows]) {
          expect(line / expected, inInclusiveRange(.5, 1.5),
              reason: '$brightness');
        }
      }
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

class _MountCounter extends StatefulWidget {
  const _MountCounter({required this.onMount});

  final VoidCallback onMount;

  @override
  State<_MountCounter> createState() => _MountCounterState();
}

class _MountCounterState extends State<_MountCounter> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
