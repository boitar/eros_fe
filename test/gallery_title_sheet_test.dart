import 'package:eros_fe/common/parser/gallery_detail_parser.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_state.dart';
import 'package:eros_fe/pages/gallery/view/gallery_title_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/waterfall_fixture.dart';

const _english = '(C107) [Hoshikuzu Koubou (Amano Shizuku)] Stardust Observer';
const _japanese = '(C107) [ほしくず工房 (天野しずく)] 星屑の観測者';

Widget _host({
  required bool showingJapanese,
  String english = _english,
  String japanese = _japanese,
  VoidCallback? onToggle,
  VoidCallback? onSearch,
}) {
  return CupertinoApp(
    locale: const Locale('en'),
    supportedLocales: L10n.delegate.supportedLocales,
    localizationsDelegates: const [
      L10n.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    home: Builder(
      builder: (context) => CupertinoPageScaffold(
        child: Center(
          child: CupertinoButton(
            child: const Text('open'),
            onPressed: () => showGalleryTitleSheet(
              context,
              englishTitle: english,
              japaneseTitle: japanese,
              showingJapanese: showingJapanese,
              onToggleLanguage: onToggle,
              onSearch: onSearch,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(registerWaterfallFixture);
  tearDown(Get.reset);

  group('title sheet', () {
    testWidgets('lists the title on screen first and marks it', (tester) async {
      await tester.pumpWidget(_host(showingJapanese: false));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Full Title'), findsOneWidget);
      expect(find.text('English Title'), findsOneWidget);
      expect(find.text('Japanese Title'), findsOneWidget);
      expect(find.text('Showing'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(_english)).dy,
        lessThan(tester.getTopLeft(find.text(_japanese)).dy),
      );
      // The close button sits at the trailing edge, clear of the heading.
      expect(
        tester.getRect(find.bySemanticsLabel('Done')).left,
        greaterThan(tester.getRect(find.text('Full Title')).right),
      );
      expect(
        tester.getTopLeft(find.text('Showing')).dy,
        closeTo(tester.getTopLeft(find.text('English Title')).dy, 4),
      );
    });

    testWidgets('copies each title on its own', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.pumpWidget(_host(showingJapanese: true));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Copy English Title'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Copy Japanese Title'));
      await tester.pump();
      expect(copied, [_english, _japanese]);
      // Copy confirmation swaps the icon, then reverts.
      expect(find.byIcon(CupertinoIcons.checkmark_alt), findsNWidgets(2));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byIcon(CupertinoIcons.checkmark_alt), findsNothing);
    });

    testWidgets('switches the displayed language and searches', (tester) async {
      var toggles = 0;
      var searches = 0;
      await tester.pumpWidget(_host(
        showingJapanese: true,
        onToggle: () => toggles++,
        onSearch: () => searches++,
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show English Title'));
      await tester.pumpAndSettle();
      expect(toggles, 1);
      expect(find.text('Full Title'), findsNothing);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search Title'));
      await tester.pumpAndSettle();
      expect(searches, 1);
    });

    testWidgets('a single title offers no language switch', (tester) async {
      await tester.pumpWidget(_host(
        showingJapanese: false,
        japanese: '',
        onToggle: () {},
        onSearch: () {},
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Japanese Title'), findsNothing);
      expect(find.text('Show Japanese Title'), findsNothing);
      expect(find.text('Search Title'), findsOneWidget);
    });

    testWidgets('fits large text without overflow', (tester) async {
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(
            size: Size(390, 844), textScaler: TextScaler.linear(2.5)),
        child: _host(showingJapanese: false, onToggle: () {}),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('display title', () {
    GalleryPageState stateWith(String english, String japanese) =>
        GalleryPageState()
          ..galleryProvider = GalleryProvider(
            gid: '1',
            englishTitle: english,
            japaneseTitle: japanese,
          );

    test('follows the global setting until switched for this page', () {
      final state = stateWith(_english, _japanese);
      expect(state.showingJapaneseTitle, isFalse);
      expect(state.displayTitle, _english);
      state.toggleDisplayTitleLanguage();
      expect(state.displayTitle, _japanese);
      // Downloads and shares keep the setting's title.
      expect(state.mainTitle, _english);
      state.toggleDisplayTitleLanguage();
      expect(state.displayTitle, _english);
    });

    test('never shows an empty Japanese title', () {
      final state = stateWith(_english, '');
      state.toggleDisplayTitleLanguage();
      expect(state.showingJapaneseTitle, isFalse);
      expect(state.displayTitle, _english);
      expect(state.hasBothTitles, isFalse);
    });
  });

  test('detail page gives the cover its size', () async {
    final provider = await parseGalleryDetail(
      '<html><body><div id="gd1"><div style="width:250px; height:354px; '
      'background:transparent url(https://example.org/c.jpg) 0 0 no-repeat">'
      '</div></div><div id="gn">Title</div></body></html>',
    );
    expect(provider.imgUrl, 'https://example.org/c.jpg');
    expect(provider.imgWidth, 250);
    expect(provider.imgHeight, 354);
  });
}
