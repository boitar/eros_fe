import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/extension.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/models/simple_tag.dart';
import 'package:eros_fe/pages/item/cover_ratio.dart';
import 'package:eros_fe/pages/item/gallery_item_flow_large.dart';
import 'package:eros_fe/pages/item/item_base.dart';
import 'package:eros_fe/pages/tab/view/list/waterfall_flow.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/waterfall_fixture.dart';

Widget _wrap(Widget child, {TextDirection direction = TextDirection.ltr}) {
  return Directionality(
    textDirection: direction,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 200, child: child),
      ),
    ),
  );
}

List<Widget> _boxes(int count) => List<Widget>.generate(
      count,
      (i) => SizedBox(key: ValueKey(i), width: 60, height: 20),
    );

RenderLimitedWrap _wrapRender(WidgetTester tester) =>
    tester.renderObject<RenderLimitedWrap>(find.byType(LimitedWrap));

void main() {
  group('LimitedWrap', () {
    testWidgets('keeps everything when two rows are enough', (tester) async {
      await tester.pumpWidget(_wrap(LimitedWrap(children: _boxes(4))));
      final render = _wrapRender(tester);
      expect(render.hiddenCount, 0);
      expect(render.size.height, 44);
      expect(tester.getTopLeft(find.byKey(const ValueKey(3))),
          const Offset(0, 24));
    });

    testWidgets('caps at two rows and makes room for the count',
        (tester) async {
      await tester.pumpWidget(_wrap(LimitedWrap(children: _boxes(10))));
      final render = _wrapRender(tester);
      // Six fit in two rows; the sixth makes way for "+5".
      expect(render.hiddenCount, 5);
      expect(render.size.height, 44);
      expect(render.size.width, lessThanOrEqualTo(200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('hidden children are neither painted nor hit', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(LimitedWrap(children: [
        ..._boxes(5),
        GestureDetector(
          key: const ValueKey('hidden'),
          onTap: () => taps++,
          child: const SizedBox(width: 190, height: 20),
        ),
      ])));
      expect(_wrapRender(tester).hiddenCount, 1);
      await tester.tapAt(const Offset(100, 50));
      expect(taps, 0);
    });

    testWidgets('mirrors runs for right-to-left text', (tester) async {
      await tester.pumpWidget(_wrap(LimitedWrap(children: _boxes(2)),
          direction: TextDirection.rtl));
      // The 200pt box is tight, so runs start from its right edge.
      expect(_wrapRender(tester).size.width, 200);
      expect(tester.getTopLeft(find.byKey(const ValueKey(0))).dx, 140);
      expect(tester.getTopLeft(find.byKey(const ValueKey(1))).dx, 76);
    });
  });

  group('LargeWaterfallDelegate', () {
    const gap = EHConst.waterfallFlowLargeCrossAxisSpacing;

    test('phones keep two columns, wider windows add more', () {
      // Inner widths after the 12pt margins.
      expect(LargeWaterfallDelegate.columnsFor(296, gap: gap), 2);
      expect(LargeWaterfallDelegate.columnsFor(378, gap: gap), 2);
      expect(LargeWaterfallDelegate.columnsFor(726, gap: gap), 4);
      expect(LargeWaterfallDelegate.columnsFor(1000, gap: gap), 5);
    });

    test('columns never fall below the minimum width', () {
      for (var width = 346.0; width < 1400; width += 7) {
        final count = LargeWaterfallDelegate.columnsFor(width, gap: gap);
        final column = (width - gap * (count - 1)) / count;
        expect(column, greaterThanOrEqualTo(168), reason: 'width $width');
      }
    });

    test('the card size sets the narrowest column, never below two', () {
      expect(
          LargeWaterfallDelegate.columnsFor(378, gap: gap, minColumnWidth: 102),
          3);
      expect(
          LargeWaterfallDelegate.columnsFor(378, gap: gap, minColumnWidth: 250),
          2);
    });

    test('even columns put a gap on the centre line', () {
      expect(
          LargeWaterfallDelegate.columnsFor(1000, gap: gap, evenColumns: true),
          4);
      expect(
          LargeWaterfallDelegate.columnsFor(1000,
              gap: gap, minColumnWidth: 132, evenColumns: true),
          6);
    });
  });

  group('largeWaterfallFoldGap', () {
    AdaptiveEnvironmentSnapshot duo(Rect fold) => AdaptiveEnvironmentSnapshot(
          size: const Size(580, 760),
          reservedRegions: [
            AdaptiveRegion(frame: fold, kind: AdaptiveRegionKind.division),
          ],
        );

    test('widens the gap to cover a centred book fold', () {
      expect(
          largeWaterfallFoldGap(duo(const Rect.fromLTWH(278, 0, 24, 760)),
              split: false),
          24);
      expect(
          largeWaterfallFoldGap(duo(const Rect.fromLTWH(287, 0, 6, 760)),
              split: false),
          EHConst.waterfallFlowLargeCrossAxisSpacing);
    });

    test('ignores split panes, off-centre and horizontal folds', () {
      final centred = duo(const Rect.fromLTWH(278, 0, 24, 760));
      expect(largeWaterfallFoldGap(centred, split: true), isNull);
      expect(
          largeWaterfallFoldGap(duo(const Rect.fromLTWH(200, 0, 24, 760)),
              split: false),
          isNull);
      expect(
          largeWaterfallFoldGap(duo(const Rect.fromLTWH(0, 368, 580, 24)),
              split: false),
          isNull);
      expect(
          largeWaterfallFoldGap(
              const AdaptiveEnvironmentSnapshot(size: Size(402, 874)),
              split: false),
          isNull);
      expect(largeWaterfallFoldGap(null, split: false), isNull);
    });
  });

  test('card dates drop the current year only', () {
    final now = DateTime(2026, 10, 29);
    expect(compactCardDate('2026-10-15 12:30', now: now), '10-15');
    expect(compactCardDate('2025-12-31 23:59', now: now), '2025-12-31');
    expect(compactCardDate('', now: now), '');
    expect(compactCardDate(null, now: now), '');
  });

  test('large covers are capped at 4:3', () {
    expect(
        coverAspectRatio(
            imgWidth: 600, imgHeight: 200, maxRatio: kMaxLargeCoverAspectRatio),
        kMaxLargeCoverAspectRatio);
    expect(
        coverAspectRatio(
            imgWidth: 100, imgHeight: 400, maxRatio: kMaxLargeCoverAspectRatio),
        0.5);
    expect(coverAspectRatio(imgWidth: 600, imgHeight: 200), 3.0);
  });

  group('GalleryItemFlowLarge', () {
    setUp(registerWaterfallFixture);
    tearDown(Get.reset);

    const gallery = GalleryProvider(
      gid: 'card',
      englishTitle: '[Circle (Artist)] An extremely long neutral title that '
          'keeps going well past two lines on a phone card [Chinese]',
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
        SimpleTag(text: 'chinese'),
        SimpleTag(text: 'full color', backgrondColor: '#d03030'),
        SimpleTag(text: 'neutral'),
        SimpleTag(text: 'illustration'),
        SimpleTag(text: 'long neutral label'),
        SimpleTag(text: 'tag five'),
        SimpleTag(text: 'tag six'),
        SimpleTag(text: 'tag seven'),
        SimpleTag(text: 'tag eight'),
        SimpleTag(text: 'tag nine'),
        SimpleTag(text: 'tag ten'),
      ],
    );

    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('lays out in a phone column at text scale $scale',
          (tester) async {
        tester.view.physicalSize = const Size(402, 874);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(GetMaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(402, 874),
              textScaler: TextScaler.linear(scale),
            ),
            child: const CupertinoPageScaffold(
              child: CustomScrollView(slivers: [
                EhWaterfallFlow([gallery], 'fixture', large: true),
              ]),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final card = find.byType(GalleryItemFlowLarge);
        // 402 − 2×12 margin − 10 gap, split over two columns.
        expect(tester.getSize(card).width, closeTo(184, 0.01));
        expect(find.text('48P'), findsOneWidget);
        expect(find.text('ZH'), findsOneWidget);
        expect(find.text('Doujinshi'), findsOneWidget);
        expect(find.text('4.5'), findsOneWidget);
        expect(find.text(compactCardDate('2026-10-15 12:30')), findsOneWidget);
        // The cover's "ZH" already says it; no "chinese" chip.
        expect(find.text('chinese'), findsNothing);
        expect(find.text('full color'), findsOneWidget);

        final title = tester.widget<Text>(find.textContaining('extremely'));
        expect(title.maxLines, kTitleMaxLines);
        expect(_wrapRender(tester).hiddenCount, greaterThan(0));
        await tester.pumpWidget(const SizedBox());
      });
    }

    for (final (width, runs) in [(402.0, 3), (300.0, 4)]) {
      testWidgets('$width wide: $runs rows of tags, watched ones first',
          (tester) async {
        tester.view.physicalSize = Size(width, 874);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final watchedLast = gallery.copyWith(
          simpleTags: [
            ...gallery.simpleTags!,
            const SimpleTag(text: 'watched last', backgrondColor: '#3060d0'),
          ].oN,
        );

        await tester.pumpWidget(GetMaterialApp(
          home: CupertinoPageScaffold(
            child: CustomScrollView(slivers: [
              EhWaterfallFlow([watchedLast], 'fixture', large: true),
            ]),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        expect(_wrapRender(tester).maxRuns, runs);
        // The tags the user follows lead, so the count never hides them.
        final labels = tester
            .widgetList<Text>(find.descendant(
                of: find.byType(LimitedWrap), matching: find.byType(Text)))
            .map((text) => text.data)
            .toList();
        expect(labels.take(2), ['full color', 'watched last']);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('press shrinks the card and release restores it',
        (tester) async {
      await tester.pumpWidget(const GetMaterialApp(
        home: CupertinoPageScaffold(
          child: CustomScrollView(slivers: [
            EhWaterfallFlow([gallery], 'fixture', large: true),
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      final scale = find.descendant(
          of: find.byType(GalleryItemFlowLarge),
          matching: find.byType(AnimatedScale));
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('ZH')));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedScale>(scale).scale, 0.97);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedScale>(scale).scale, 1);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
