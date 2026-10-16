import 'dart:ui' as ui;

import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const safeTop = 59.0;
  // Default 800x600 test surface: 17% of the height (102) loses to the
  // expanded rail's lower edge in both layouts, so the fade end is the rail.
  const twoRowFadeEnd = 153.0; // safeTop + 44 + 50.
  const inlineFadeEnd = 103.0; // safeTop + 44.
  // Stands in for whatever is behind the transparent CupertinoPageScaffold.
  const underlyingGray = Color(0xFF888888);
  const cardColor = Color(0xFFFF0000);
  const baseKey = ValueKey<String>('liquid-glass-safe-area-base');
  const scrimKey = ValueKey<String>('liquid-glass-top-scrim');

  double fadeEndFor(LiquidGlassTopBarLayout layout) =>
      layout == LiquidGlassTopBarLayout.twoRow ? twoRowFadeEnd : inlineFadeEnd;

  /// Theme-background opacity of the base at logical y: solid through the
  /// safe area, then 100% → 84% → 28% → 0% with the three fade points at
  /// 25%, 65% and 100% of the distance from the safe area to the fade end.
  double expectedBaseAlpha(double y, LiquidGlassTopBarLayout layout) {
    final double fadeEnd = fadeEndFor(layout);
    if (y <= safeTop) {
      return 1.0;
    }
    final double remaining = fadeEnd - safeTop;
    final double first = safeTop + remaining * 0.25;
    final double second = safeTop + remaining * 0.65;
    if (y <= first) {
      return 1.0 - 0.16 * (y - safeTop) / (first - safeTop);
    }
    if (y <= second) {
      return 0.84 - 0.56 * (y - first) / (second - first);
    }
    return 0.28 * (fadeEnd - y) / (fadeEnd - second);
  }

  int blendChannel(int src, int dst, double alpha) =>
      (src * alpha + dst * (1 - alpha)).round();

  List<int> expectedBlend(List<int> rgb, Brightness brightness, double alpha) {
    final int src = brightness == Brightness.light ? 255 : 0;
    return <int>[for (final channel in rgb) blendChannel(src, channel, alpha)];
  }

  Future<List<int>> rgbAt(
    GlobalKey boundary,
    int x,
    int y,
  ) async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final offset = (y * image.width + x) * 4;
    final result = <int>[
      bytes!.getUint8(offset),
      bytes.getUint8(offset + 1),
      bytes.getUint8(offset + 2),
    ];
    image.dispose();
    return result;
  }

  bool isThemeBackground(List<int> rgb, Brightness brightness) {
    final expected = brightness == Brightness.light ? 255 : 0;
    return rgb.every((channel) => (channel - expected).abs() <= 1);
  }

  void expectCloseToBlend(
    List<int> actual,
    Brightness brightness,
    double alpha,
    String reason,
  ) {
    final expected = expectedBlend(<int>[136, 136, 136], brightness, alpha);
    for (var i = 0; i < 3; i++) {
      expect(
        actual[i],
        closeTo(expected[i], 3),
        reason: '$reason channel $i: $actual vs $expected',
      );
    }
  }

  for (final brightness in Brightness.values) {
    for (final layout in LiquidGlassTopBarLayout.values) {
      final fadeEnd = fadeEndFor(layout);
      final remaining = fadeEnd - safeTop;

      testWidgets(
          'base fades continuously below the safe area and ends fully '
          'transparent: $brightness $layout', (tester) async {
        final boundary = GlobalKey();
        // The base alone over the underlying gray, as the page Stack places
        // it below the scroll content.
        await tester.pumpWidget(CupertinoApp(
          theme: CupertinoThemeData(brightness: brightness),
          home: RepaintBoundary(
            key: boundary,
            child: ColoredBox(
              color: underlyingGray,
              child: Stack(
                children: <Widget>[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LiquidGlassSafeAreaBase(
                      safeTop: safeTop,
                      layout: layout,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
        await tester.pump();

        expect(
          tester.getRect(find.byKey(baseKey)).bottom,
          fadeEnd,
          reason: 'The base must reach the shared fade end',
        );

        // Solid theme background from the top of the screen through the safe
        // area.
        for (final y in [1, 30, 58]) {
          final pixel = (await tester.runAsync(() => rgbAt(boundary, 100, y)))!;
          expect(
            isThemeBackground(pixel, brightness),
            isTrue,
            reason: 'Base at y=$y must be the solid theme background, '
                'got $pixel',
          );
        }

        // No seam at the safe-area lower edge: the pixel just below is the
        // continuation of the solid band, not a jump to the underlying gray.
        final above = (await tester.runAsync(() => rgbAt(boundary, 100, 58)))!;
        final below = (await tester.runAsync(() => rgbAt(boundary, 100, 60)))!;
        for (var i = 0; i < 3; i++) {
          expect(
            (above[i] - below[i]).abs(),
            lessThanOrEqualTo(3),
            reason: 'The base must not form a fixed line at the safe-area '
                'edge: above $above vs below $below',
          );
        }

        // The exact fade profile: 84% at 25%, 28% at 65% and nearly zero at
        // the end of the remaining distance.
        expectCloseToBlend(
          (await tester.runAsync(
            () => rgbAt(boundary, 100, (safeTop + remaining * 0.25).round()),
          ))!,
          brightness,
          0.84,
          'The 25% fade point must carry 84% opacity',
        );
        expectCloseToBlend(
          (await tester.runAsync(
            () => rgbAt(boundary, 100, (safeTop + remaining * 0.65).round()),
          ))!,
          brightness,
          0.28,
          'The 65% fade point must carry 28% opacity',
        );
        expectCloseToBlend(
          (await tester.runAsync(
            () => rgbAt(boundary, 100, fadeEnd.round() - 1),
          ))!,
          brightness,
          expectedBaseAlpha((fadeEnd - 1).toDouble(), layout),
          'The pixel above the fade end must be almost transparent',
        );

        // Fully transparent at the fade end: below it only the underlying
        // gray remains.
        final pastEnd = (await tester.runAsync(
          () => rgbAt(boundary, 100, fadeEnd.round() + 2),
        ))!;
        expect(
          pastEnd,
          <int>[136, 136, 136],
          reason: 'The base must paint nothing below the fade end: $pastEnd',
        );
      });

      testWidgets(
          'base fade end matches the top scrim fade end: $brightness $layout',
          (tester) async {
        await tester.pumpWidget(CupertinoApp(
          theme: CupertinoThemeData(brightness: brightness),
          home: ColoredBox(
            color: underlyingGray,
            child: Stack(
              children: <Widget>[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LiquidGlassSafeAreaBase(
                    safeTop: safeTop,
                    layout: layout,
                  ),
                ),
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LiquidGlassTopScrim(
                    safeTop: safeTop,
                    layout: LiquidGlassTopBarLayout.twoRow,
                  ),
                ),
              ],
            ),
          ),
        ));
        await tester.pump();
        // Same shared computation: the base recedes exactly where the top
        // scrim ends, in both layouts.
        expect(
          tester.getRect(find.byKey(scrimKey)).bottom,
          fadeEndFor(LiquidGlassTopBarLayout.twoRow),
        );
        // The harness scrim pins twoRow, so this layout's equality is
        // checked on the widget sizes with matching parameters below.
        await tester.pumpWidget(CupertinoApp(
          theme: CupertinoThemeData(brightness: brightness),
          home: ColoredBox(
            color: underlyingGray,
            child: Stack(
              children: <Widget>[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LiquidGlassSafeAreaBase(
                    safeTop: safeTop,
                    layout: layout,
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LiquidGlassTopScrim(
                    safeTop: safeTop,
                    layout: layout,
                  ),
                ),
              ],
            ),
          ),
        ));
        await tester.pump();
        expect(
          tester.getRect(find.byKey(baseKey)).bottom,
          fadeEnd,
        );
        expect(
          tester.getRect(find.byKey(scrimKey)).bottom,
          fadeEnd,
          reason: 'The base must end exactly at the top scrim fade end',
        );
      });
    }

    testWidgets(
        'cards stay untouched and gap background fades without a fixed '
        'line: $brightness', (tester) async {
      final boundary = GlobalKey();
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      // Full-width cards separated by gaps, scrolled so the first gap
      // straddles the safe-area edge: the geometry that produced the fixed
      // gray line in the reported defect.
      Widget buildHarness({required bool withBase}) {
        return CupertinoApp(
          theme: CupertinoThemeData(brightness: brightness),
          home: RepaintBoundary(
            key: boundary,
            child: ColoredBox(
              color: underlyingGray,
              child: Stack(
                children: <Widget>[
                  if (withBase)
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LiquidGlassSafeAreaBase(
                        safeTop: safeTop,
                        layout: LiquidGlassTopBarLayout.twoRow,
                      ),
                    ),
                  SingleChildScrollView(
                    controller: scrollController,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    child: Column(
                      children: <Widget>[
                        Container(height: 200, color: cardColor),
                        const SizedBox(height: 24),
                        Container(height: 200, color: cardColor),
                        const SizedBox(height: 24),
                        Container(height: 200, color: cardColor),
                        Container(height: 2000, color: underlyingGray),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // Offset 150 puts the first gap at screen y=50..74, across safeTop.
      const scrollOffset = 150.0;
      await tester.pumpWidget(buildHarness(withBase: true));
      scrollController.jumpTo(scrollOffset);
      await tester.pump();

      // In the gap the base shows through: theme background just above the
      // safe area and still near-theme below it — no fixed line at the old
      // seam.
      final gapAbove =
          (await tester.runAsync(() => rgbAt(boundary, 400, 57)))!;
      expect(
        isThemeBackground(gapAbove, brightness),
        isTrue,
        reason: 'Gap above the safe area must show the theme background, '
            'got $gapAbove',
      );
      final gapBelow =
          (await tester.runAsync(() => rgbAt(boundary, 400, 61)))!;
      expectCloseToBlend(
        gapBelow,
        brightness,
        expectedBaseAlpha(61.0, LiquidGlassTopBarLayout.twoRow),
        'Gap just below the safe area must continue the fade, not jump to '
        'the underlying gray',
      );

      // The second gap lies below the fade end: the base paints nothing
      // there, so it shows the plain underlying gray.
      final gapPastEnd =
          (await tester.runAsync(() => rgbAt(boundary, 400, 286)))!;
      expect(
        gapPastEnd,
        <int>[136, 136, 136],
        reason: 'The base must not tint below the fade end: $gapPastEnd',
      );

      // Card pixels are identical with and without the base: the base sits
      // below the content and never tints cards, including inside the fade
      // region.
      await tester.pumpWidget(buildHarness(withBase: false));
      scrollController.jumpTo(scrollOffset);
      await tester.pump();
      final cardPointsWithoutBase = <int, List<int>>{
        for (final y in [10, 30, 45, 80, 250])
          y: (await tester.runAsync(() => rgbAt(boundary, 400, y)))!,
      };
      await tester.pumpWidget(buildHarness(withBase: true));
      scrollController.jumpTo(scrollOffset);
      await tester.pump();
      for (final y in [10, 30, 45, 80, 250]) {
        final withBase =
            (await tester.runAsync(() => rgbAt(boundary, 400, y)))!;
        expect(
          withBase,
          cardPointsWithoutBase[y],
          reason: 'Card pixel at y=$y must be unaffected by the base: '
              'with base $withBase vs without ${cardPointsWithoutBase[y]}',
        );
      }
    });
  }

  testWidgets('safe-area base draws nothing when safeTop is zero',
      (tester) async {
    await tester.pumpWidget(const CupertinoApp(
      home: Stack(
        children: <Widget>[
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LiquidGlassSafeAreaBase(
              safeTop: 0,
              layout: LiquidGlassTopBarLayout.twoRow,
            ),
          ),
        ],
      ),
    ));
    expect(find.byKey(const ValueKey('liquid-glass-safe-area-base')),
        findsNothing);
  });

  testWidgets('full page stack keeps the previous top appearance with the '
      'fading base', (tester) async {
    // Mirrors the page Stack order: fading base, scroll content, solid mask,
    // top scrim. At rest the safe area and the revealed mask show the theme
    // background; scrolled cards stay visible through the scrim.
    const safeTop = 59.0;
    const headerExtent = 153.0;
    final progress = ValueNotifier<double>(1.0);
    addTearDown(progress.dispose);
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    final boundary = GlobalKey();

    Widget buildHarness({required bool withBase}) {
      return CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.light),
        home: RepaintBoundary(
          key: boundary,
          child: ColoredBox(
            color: underlyingGray,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (withBase)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LiquidGlassSafeAreaBase(
                      safeTop: safeTop,
                      layout: LiquidGlassTopBarLayout.twoRow,
                    ),
                  ),
                SingleChildScrollView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  child: Column(
                    children: <Widget>[
                      const SizedBox(height: headerExtent),
                      Container(height: 240, color: cardColor),
                      Container(height: 2400, color: underlyingGray),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LiquidGlassSolidMask(
                    progressListenable: progress,
                    safeTop: safeTop,
                    height: headerExtent,
                  ),
                ),
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LiquidGlassTopScrim(
                    safeTop: safeTop,
                    layout: LiquidGlassTopBarLayout.twoRow,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildHarness(withBase: true));
    await tester.pump();
    for (final y in [1, 30, 58]) {
      final pixel = (await tester.runAsync(() => rgbAt(boundary, 100, y)))!;
      expect(
        isThemeBackground(pixel, Brightness.light),
        isTrue,
        reason: 'Safe area at y=$y must show the theme background, got $pixel',
      );
    }
    final belowSafeArea =
        (await tester.runAsync(() => rgbAt(boundary, 100, 100)))!;
    expect(
      isThemeBackground(belowSafeArea, Brightness.light),
      isTrue,
      reason: 'The solid mask below the safe area must stay theme-colored, '
          'got $belowSafeArea',
    );

    // Scroll the first card into the safe area; the mask retracts and the
    // card stays visible through the scrim.
    progress.value = 0.0;
    scrollController.jumpTo(headerExtent - 20);
    await tester.pump();
    final cardWithBase =
        (await tester.runAsync(() => rgbAt(boundary, 100, 30)))!;
    expect(
      isThemeBackground(cardWithBase, Brightness.light),
      isFalse,
      reason: 'The card drawn inside the safe area must stay visible '
          'through the scrim: $cardWithBase',
    );

    // The same scrolled frame without the base must render identically over
    // the card: the base sits below the content.
    await tester.pumpWidget(buildHarness(withBase: false));
    scrollController.jumpTo(headerExtent - 20);
    await tester.pump();
    final cardWithoutBase =
        (await tester.runAsync(() => rgbAt(boundary, 100, 30)))!;
    expect(
      cardWithoutBase,
      cardWithBase,
      reason: 'The base must not occlude or tint scrolled content: '
          'with base $cardWithBase vs without $cardWithoutBase',
    );
  });
}
