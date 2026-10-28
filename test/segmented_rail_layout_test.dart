import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:eros_fe/widget/segmented_rail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SegmentedRailLayout', () {
    double sum(List<double> values) =>
        values.fold<double>(0, (total, value) => total + value);

    test('equal segments fill the track when every label fits', () {
      // 日排行 / 月排行 / 年排行 / 总排行 on a 370pt track.
      final layout =
          SegmentedRailLayout.compute(<double>[45, 45, 45, 45], 370);
      expect(layout.scrolls, isFalse);
      expect(layout.widths.toSet(), hasLength(1));
      expect(layout.widths.first, closeTo(370 / 4, 1e-9));
      expect(sum(layout.widths), closeTo(370, 1e-9));
    });

    test('short groups share one width beside a long one', () {
      // 热门 / 画廊 / 订阅 / 汉语 / Anthology / nh on a 370pt track.
      final layout = SegmentedRailLayout.compute(
          <double>[30, 30, 30, 30, 66, 17], 370);
      expect(layout.scrolls, isFalse);
      expect(layout.widths[5], layout.widths[0]);
      expect(layout.widths[4], 66 + 24);
      expect(sum(layout.widths), closeTo(370, 1e-9));
    });

    test('a long label keeps its width and short ones share the rest', () {
      final layout =
          SegmentedRailLayout.compute(<double>[30, 30, 140], 300);
      expect(layout.scrolls, isFalse);
      expect(layout.widths[2], 140 + SegmentedRailLayout.labelPadding * 2);
      expect(layout.widths[0], layout.widths[1]);
      expect(layout.widths[0], greaterThan(30 + 24));
      expect(sum(layout.widths), closeTo(300, 1e-9));
    });

    test('labels that no longer fit scroll with a uniform minimum', () {
      final layout = SegmentedRailLayout.compute(
          <double>[10, 30, 30, 30, 30, 66, 120, 90], 320);
      expect(layout.scrolls, isTrue);
      expect(layout.widths.first, SegmentedRailLayout.minScrollingSegment);
      expect(layout.widths[6], 120 + 24);
      expect(layout.contentWidth, greaterThan(320));
      expect(layout.trackWidth, 320);
    });

    test('compact rails stay short and centred-sized', () {
      final layout =
          SegmentedRailLayout.compute(<double>[30, 30], 600, compact: true);
      expect(layout.widths,
          <double>[SegmentedRailLayout.compactMaxSegment, 144]);
      expect(layout.trackWidth, 288);
      final narrow =
          SegmentedRailLayout.compute(<double>[30, 30], 200, compact: true);
      expect(narrow.widths, <double>[100, 100]);
    });

    test('offsets accumulate segment widths', () {
      final layout = SegmentedRailLayout.compute(<double>[30, 30, 30], 300);
      expect(layout.offsetOf(0), 0);
      expect(layout.offsetOf(2), closeTo(200, 1e-9));
    });

    test('empty rails have no segments', () {
      final layout = SegmentedRailLayout.compute(const <double>[], 300);
      expect(layout.widths, isEmpty);
      expect(layout.trackWidth, 300);
    });
  });

  group('SegmentedRail fallback', () {
    Widget host(Widget child, {double width = 400}) => CupertinoApp(
          home: Center(
            child: SizedBox(width: width, height: 44, child: child),
          ),
        );

    testWidgets('segments are equal, selectable and long-pressable',
        (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(host(SegmentedRail(
        selectedIndex: 1,
        items: [
          for (final title in <String>['热门', 'Anthology', 'nh'])
            LiquidGlassRailCategory(
              title: title,
              onTap: () => taps.add(title),
              onLongPress: () => taps.add('long $title'),
            ),
        ],
      )));
      final widths = <double>[
        for (var i = 0; i < 3; i++)
          tester
              .getSize(find.byKey(ValueKey<String>('segmented-rail-segment-$i')))
              .width,
      ];
      // The long label keeps its width; the short ones match each other.
      expect(widths[0], widths[2]);
      expect(widths[1], greaterThanOrEqualTo(widths[0]));
      expect(widths.reduce((a, b) => a + b), closeTo(400 - 32, 0.01));
      await tester.tap(find.text('nh'));
      await tester.longPress(find.text('热门'));
      expect(taps, <String>['nh', 'long 热门']);
      expect(
        tester.getSemantics(find.byKey(
            const ValueKey<String>('segmented-rail-segment-1'))),
        matchesSemantics(
          label: 'Anthology',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
          hasLongPressAction: true,
        ),
      );
    });

    testWidgets('the lens follows the page view between segments',
        (tester) async {
      final pages = PageController();
      addTearDown(pages.dispose);
      await tester.pumpWidget(CupertinoApp(
        home: Column(children: [
          SizedBox(
            width: 400,
            height: 44,
            child: SegmentedRail(
              selectedIndex: 0,
              pageController: pages,
              items: [
                for (final title in <String>['A', 'B', 'C', 'D'])
                  LiquidGlassRailCategory(title: title, onTap: () {}),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: pages,
              children: List.generate(4, (i) => Text('page $i')),
            ),
          ),
        ]),
      ));
      double lensLeft() => tester
          .getTopLeft(find.byKey(const ValueKey<String>('segmented-rail-lens')))
          .dx;
      final start = lensLeft();
      pages.jumpTo(pages.position.viewportDimension * 1.5);
      await tester.pump();
      final segment = tester
          .getSize(find.byKey(const ValueKey<String>('segmented-rail-segment-0')))
          .width;
      expect(lensLeft() - start, closeTo(segment * 1.5, 0.5));
    });

    testWidgets('accessory is a labelled 44pt button', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(host(SegmentedRail(
        selectedIndex: 0,
        accessory: LiquidGlassRailAction(
          icon: CupertinoIcons.line_horizontal_3,
          label: 'Manage Groups',
          onPressed: () => pressed++,
        ),
        items: [LiquidGlassRailCategory(title: 'A', onTap: () {})],
      )));
      final button = find.bySemanticsLabel('Manage Groups');
      expect(button, findsOneWidget);
      expect(tester.getSize(button), const Size(44, 44));
      await tester.tap(button);
      expect(pressed, 1);
    });
  });
}
