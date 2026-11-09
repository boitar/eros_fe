import 'dart:ui' as ui;

import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:eros_fe/widget/scroll_edge_effect.dart';
import 'package:eros_fe/widget/scroll_edge_progress.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(
    () => PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android,
  );
  tearDown(() => PlatformCapabilities.debugHostPlatformOverride = null);
  const safeTop = 59.0;
  // The fade end follows the expanded rail's lower edge in both layouts.
  const twoRowFadeEnd = 153.0; // safeTop + 44 + 50.
  const inlineFadeEnd = 103.0; // safeTop + 44.
  // Stands in for whatever is behind the transparent CupertinoPageScaffold.
  const underlyingGray = Color(0xFF888888);
  const cardColor = Color(0xFFFF0000);
  const baseKey = ValueKey<String>('liquid-glass-safe-area-base');
  const scrimKey = ValueKey<String>('liquid-glass-top-scrim');

  double fadeEndFor(LiquidGlassTopBarLayout layout) =>
      layout == LiquidGlassTopBarLayout.twoRow ? twoRowFadeEnd : inlineFadeEnd;

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final brightness in Brightness.values) {
      for (final cardTop in [161.0, 300.0]) {
        testWidgets(
          '$platform $brightness keeps static layers with resting card $cardTop',
          (tester) async {
            PlatformCapabilities.debugHostPlatformOverride = platform;
            tester.view.physicalSize = const Size(800, 1200);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final edge = ScrollEdgeProgressController();
            final rest = ValueNotifier<double?>(cardTop);
            addTearDown(edge.dispose);
            addTearDown(rest.dispose);
            await tester.pumpWidget(
              CupertinoApp(
                theme: CupertinoThemeData(brightness: brightness),
                home: Stack(
                  children: [
                    LiquidGlassSafeAreaBase(
                      safeTop: safeTop,
                      layout: LiquidGlassTopBarLayout.twoRow,
                      edgeProgress: edge,
                      firstCardRestTop: rest,
                    ),
                    const LiquidGlassSolidMask(
                      progressListenable: AlwaysStoppedAnimation(1),
                      safeTop: safeTop,
                      height: twoRowFadeEnd,
                    ),
                    LiquidGlassTopScrim(
                      safeTop: safeTop,
                      layout: LiquidGlassTopBarLayout.twoRow,
                      edgeProgress: edge,
                      firstCardRestTop: rest,
                    ),
                    LiquidGlassTopSoftEdge(
                      safeTop: safeTop,
                      layout: LiquidGlassTopBarLayout.twoRow,
                      edgeProgress: edge,
                    ),
                  ],
                ),
              ),
            );
            LinearGradient gradient(Key key) =>
                (tester.widget<DecoratedBox>(find.byKey(key)).decoration
                            as BoxDecoration)
                        .gradient!
                    as LinearGradient;
            final background = CupertinoDynamicColor.resolve(
              CupertinoColors.systemBackground,
              tester.element(find.byType(LiquidGlassTopScrim)),
            );
            const target = 1200 * .17;
            final resting = cardTop < target ? cardTop : target;
            for (final (offset, progress) in [
              (0.0, 0.0),
              (8.0, .5),
              (16.0, 1.0),
              (-8.0, 0.0),
            ]) {
              edge.update(
                FixedScrollMetrics(
                  minScrollExtent: 0,
                  maxScrollExtent: 1000,
                  pixels: offset,
                  viewportDimension: 1200,
                  axisDirection: AxisDirection.down,
                  devicePixelRatio: 1,
                ),
              );
              await tester.pump();
              expect(edge.value, progress);
              final end = resting + (target - resting) * progress;
              for (final key in [baseKey, scrimKey]) {
                expect(find.byKey(key), findsOneWidget);
                expect(
                  tester.getRect(find.byKey(key)).bottom,
                  closeTo(end, .001),
                );
                for (final color in gradient(key).colors) {
                  expect(
                    color.withValues(alpha: 1).toARGB32(),
                    background.toARGB32(),
                  );
                }
              }
              final base = gradient(baseKey);
              expect(
                base.colors.map((c) => c.a),
                orderedEquals([1, 1, .84, .28, 0]),
              );
              final solidStop = safeTop / end;
              final expectedStops = [
                0.0,
                for (final fraction in [0.0, .25, .65, 1.0])
                  solidStop + (1 - solidStop) * fraction,
              ];
              expect(base.stops, orderedEquals(expectedStops));
              final scrim = gradient(scrimKey);
              final alpha = brightness == Brightness.dark ? .37 : .32;
              expect(
                scrim.colors.map((c) => c.a),
                orderedEquals([alpha, alpha * .55, alpha * .22, 0]),
              );
              expect(scrim.stops, [0, .35, .70, 1]);
              final soft = find.byType(SoftScrollEdgeEffect);
              if (progress == 0) {
                expect(soft, findsNothing);
                expect(find.byType(BackdropFilter), findsNothing);
              } else {
                expect(soft, findsOneWidget);
                final effect = tester.widget<SoftScrollEdgeEffect>(soft);
                expect(effect.inset, safeTop);
                expect(effect.bars, 94);
                expect(
                  effect.tail,
                  closeTo(
                    (platform == TargetPlatform.android ? 20 : 28) * progress,
                    .001,
                  ),
                );
                expect(effect.strength, progress);
                if (platform == TargetPlatform.iOS) {
                  expect(find.byType(BackdropFilter), findsWidgets);
                } else {
                  expect(find.byType(BackdropFilter), findsNothing);
                }
              }
              expect(
                tester.getSize(find.byType(LiquidGlassSolidMask)).height,
                twoRowFadeEnd + 20,
              );
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final platform in [TargetPlatform.macOS, TargetPlatform.windows]) {
    for (final brightness in Brightness.values) {
      testWidgets('$platform $brightness preserves the desktop canvas fade', (
        tester,
      ) async {
        PlatformCapabilities.debugHostPlatformOverride = platform;
        const canvas = Color(0xFF324654);
        final progress = ValueNotifier<double>(0);
        addTearDown(progress.dispose);
        final reduced =
            LiquidGlassAccessibilitySettings.reduceTransparency
                as ValueNotifier<bool?>;
        reduced.value = false;
        addTearDown(() => reduced.value = null);
        await tester.pumpWidget(
          CupertinoApp(
            theme: CupertinoThemeData(
              brightness: brightness,
              scaffoldBackgroundColor: canvas,
            ),
            home: Stack(
              children: [
                LiquidGlassSafeAreaBase(
                  safeTop: safeTop,
                  layout: LiquidGlassTopBarLayout.twoRow,
                  edgeProgress: progress,
                ),
                const LiquidGlassSolidMask(
                  progressListenable: AlwaysStoppedAnimation(1),
                  safeTop: safeTop,
                  height: twoRowFadeEnd,
                ),
                LiquidGlassTopScrim(
                  safeTop: safeTop,
                  layout: LiquidGlassTopBarLayout.twoRow,
                  edgeProgress: progress,
                ),
                LiquidGlassTopSoftEdge(
                  safeTop: safeTop,
                  layout: LiquidGlassTopBarLayout.twoRow,
                  edgeProgress: progress,
                ),
              ],
            ),
          ),
        );
        for (final p in [0.0, .5, 1.0]) {
          progress.value = p;
          await tester.pump();
          expect(find.byKey(baseKey), findsNothing);
          expect(
            find.byKey(const ValueKey('liquid-glass-solid-mask')),
            findsNothing,
          );
          expect(find.byType(SoftScrollEdgeEffect), findsNothing);
          expect(find.byType(BackdropFilter), findsNothing);
          expect(
            find.byKey(const ValueKey('liquid-glass-edge-hairline')),
            findsNothing,
          );
          expect(
            tester.getRect(find.byKey(scrimKey)).bottom,
            twoRowFadeEnd + 16 * p,
          );
          final decoration =
              tester.widget<DecoratedBox>(find.byKey(scrimKey)).decoration
                  as BoxDecoration;
          final gradient = decoration.gradient! as LinearGradient;
          final curve = SoftEdgeCurve(
            brightness == Brightness.dark
                ? [.94, .90, .84, .36, 0]
                : [.92, .88, .80, .32, 0],
            maxSigma: 0,
          );
          final expected = curve.sample(inset: safeTop, bars: 94, tail: 16 * p);
          for (var i = 0; i < expected.length; i++) {
            expect(gradient.colors[i].withValues(alpha: 1), canvas);
            expect(gradient.colors[i].a, closeTo(expected[i] * p, .001));
          }
        }
      });
    }
  }

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

  Future<List<int>> rgbAt(GlobalKey boundary, int x, int y) async {
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

      testWidgets('base fades continuously below the safe area and ends fully '
          'transparent: $brightness $layout', (tester) async {
        final boundary = GlobalKey();
        // The base alone over the underlying gray, as the page Stack places
        // it below the scroll content.
        await tester.pumpWidget(
          CupertinoApp(
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
                        edgeProgress: const AlwaysStoppedAnimation<double>(1),
                        safeTop: safeTop,
                        layout: layout,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
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
            reason:
                'Base at y=$y must be the solid theme background, '
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
            reason:
                'The base must not form a fixed line at the safe-area '
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
        expect(pastEnd, <int>[
          136,
          136,
          136,
        ], reason: 'The base must paint nothing below the fade end: $pastEnd');
      });

      testWidgets(
        'base fade end matches the top scrim fade end: $brightness $layout',
        (tester) async {
          await tester.pumpWidget(
            CupertinoApp(
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
                        edgeProgress: const AlwaysStoppedAnimation<double>(1),
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
            ),
          );
          await tester.pump();
          // Same shared computation: the base recedes exactly where the top
          // scrim ends, in both layouts.
          expect(
            tester.getRect(find.byKey(scrimKey)).bottom,
            fadeEndFor(LiquidGlassTopBarLayout.twoRow),
          );
          // The harness scrim pins twoRow, so this layout's equality is
          // checked on the widget sizes with matching parameters below.
          await tester.pumpWidget(
            CupertinoApp(
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
                        edgeProgress: const AlwaysStoppedAnimation<double>(1),
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
            ),
          );
          await tester.pump();
          expect(tester.getRect(find.byKey(baseKey)).bottom, fadeEnd);
          expect(
            tester.getRect(find.byKey(scrimKey)).bottom,
            fadeEnd,
            reason: 'The base must end exactly at the top scrim fade end',
          );
        },
      );
    }

    testWidgets('cards stay untouched and gap background fades without a fixed '
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
                        edgeProgress: AlwaysStoppedAnimation<double>(1),
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
      final gapAbove = (await tester.runAsync(() => rgbAt(boundary, 400, 57)))!;
      expect(
        isThemeBackground(gapAbove, brightness),
        isTrue,
        reason:
            'Gap above the safe area must show the theme background, '
            'got $gapAbove',
      );
      final gapBelow = (await tester.runAsync(() => rgbAt(boundary, 400, 61)))!;
      expectCloseToBlend(
        gapBelow,
        brightness,
        expectedBaseAlpha(61.0, LiquidGlassTopBarLayout.twoRow),
        'Gap just below the safe area must continue the fade, not jump to '
        'the underlying gray',
      );

      // The second gap lies below the fade end: the base paints nothing
      // there, so it shows the plain underlying gray.
      final gapPastEnd = (await tester.runAsync(
        () => rgbAt(boundary, 400, 286),
      ))!;
      expect(gapPastEnd, <int>[
        136,
        136,
        136,
      ], reason: 'The base must not tint below the fade end: $gapPastEnd');

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
        final withBase = (await tester.runAsync(
          () => rgbAt(boundary, 400, y),
        ))!;
        expect(
          withBase,
          cardPointsWithoutBase[y],
          reason:
              'Card pixel at y=$y must be unaffected by the base: '
              'with base $withBase vs without ${cardPointsWithoutBase[y]}',
        );
      }
    });
  }

  testWidgets('safe-area base draws nothing when safeTop is zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: Stack(
          children: <Widget>[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LiquidGlassSafeAreaBase(
                edgeProgress: AlwaysStoppedAnimation<double>(1),
                safeTop: 0,
                layout: LiquidGlassTopBarLayout.twoRow,
              ),
            ),
          ],
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('liquid-glass-safe-area-base')),
      findsNothing,
    );
  });

  testWidgets(
    'base and scrim end at the rail on tall screens and scaled text',
    (tester) async {
      for (final layout in LiquidGlassTopBarLayout.values) {
        for (final hasCategories in [true, false]) {
          for (final scale in [1.0, 1.8]) {
            final textScaler = TextScaler.linear(scale);
            await tester.pumpWidget(
              CupertinoApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(440, 1200),
                    textScaler: textScaler,
                  ),
                  child: Stack(
                    children: <Widget>[
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LiquidGlassSafeAreaBase(
                          edgeProgress: const AlwaysStoppedAnimation<double>(0),
                          safeTop: safeTop,
                          layout: layout,
                          hasCategories: hasCategories,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LiquidGlassTopScrim(
                          safeTop: safeTop,
                          layout: layout,
                          hasCategories: hasCategories,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            final expected =
                safeTop +
                layout.expandedHeight(textScaler, hasCategories: hasCategories);
            expect(
              tester.getRect(find.byKey(baseKey)).bottom,
              closeTo(expected, 0.001),
            );
            expect(
              tester.getRect(find.byKey(scrimKey)).bottom,
              closeTo(expected, 0.001),
            );
          }
        }
      }
    },
  );

  for (final brightness in Brightness.values) {
    for (final layout in LiquidGlassTopBarLayout.values) {
      testWidgets('initial content below the rail is untinted: '
          '$brightness $layout', (tester) async {
        PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.iOS;
        tester.view.physicalSize = const Size(440, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundary = GlobalKey();
        final maskProgress = ValueNotifier<double>(1);
        addTearDown(maskProgress.dispose);
        final headerHeight = fadeEndFor(layout);
        await tester.pumpWidget(
          CupertinoApp(
            theme: CupertinoThemeData(brightness: brightness),
            home: MediaQuery(
              data: const MediaQueryData(size: Size(440, 1200)),
              child: RepaintBoundary(
                key: boundary,
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LiquidGlassSafeAreaBase(
                        edgeProgress: const AlwaysStoppedAnimation<double>(1),
                        safeTop: safeTop,
                        layout: layout,
                      ),
                    ),
                    const Positioned.fill(child: ColoredBox(color: cardColor)),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LiquidGlassSolidMask(
                        progressListenable: maskProgress,
                        safeTop: safeTop,
                        height: headerHeight,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LiquidGlassTopScrim(
                        safeTop: safeTop,
                        layout: layout,
                        firstCardRestTop: AlwaysStoppedAnimation<double?>(
                          headerHeight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          // The inverse 20pt corners occupy the outer canvas, not the card.
          for (final x in [20, 220, 419]) {
            for (final y in [
              headerHeight.toInt(),
              headerHeight.toInt() + 10,
              headerHeight.toInt() + 20,
            ]) {
              final offset = (y * image.width + x) * 4;
              final pixel = <int>[
                bytes.getUint8(offset),
                bytes.getUint8(offset + 1),
                bytes.getUint8(offset + 2),
              ];
              expect(pixel, <int>[
                255,
                0,
                0,
              ], reason: 'Content at ($x, $y) must not be tinted');
            }
          }
          image.dispose();
        });
      });
    }
  }

  for (final width in [320.0, 400.0, 500.0]) {
    testWidgets('iPad pane keeps the 28pt mobile soft tail at $width',
        (tester) async {
      PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.iOS;
      const windowSize = Size(820, 1180);
      tester.view.physicalSize = windowSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final progress = ValueNotifier<double>(1);
      addTearDown(progress.dispose);
      await tester.pumpWidget(
        CupertinoApp(
          home: SizedBox(
            width: width,
            child: AdaptivePane(
              environment: const AdaptiveEnvironmentSnapshot(
                size: windowSize,
                safeArea: EdgeInsets.only(top: 59),
                viewPadding: EdgeInsets.only(top: 59),
              ),
              rect: Rect.fromLTWH(0, 0, width, windowSize.height),
              child: LiquidGlassTopSoftEdge(
                safeTop: 59,
                layout: LiquidGlassTopBarLayout.twoRow,
                edgeProgress: progress,
              ),
            ),
          ),
        ),
      );
      final effect = tester.widget<SoftScrollEdgeEffect>(
        find.byType(SoftScrollEdgeEffect),
      );
      expect(effect.inset, 59);
      expect(effect.bars, 94);
      expect(effect.tail, 28);
      expect(effect.strength, 1);
      expect(tester.takeException(), isNull);
    });
  }

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
                      edgeProgress: AlwaysStoppedAnimation<double>(1),
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
    final belowSafeArea = (await tester.runAsync(
      () => rgbAt(boundary, 100, 100),
    ))!;
    expect(
      isThemeBackground(belowSafeArea, Brightness.light),
      isTrue,
      reason:
          'The solid mask below the safe area must stay theme-colored, '
          'got $belowSafeArea',
    );

    // Scroll the first card into the safe area; the mask retracts and the
    // card stays visible through the scrim.
    progress.value = 0.0;
    scrollController.jumpTo(headerExtent - 20);
    await tester.pump();
    final cardWithBase = (await tester.runAsync(
      () => rgbAt(boundary, 100, 30),
    ))!;
    expect(
      isThemeBackground(cardWithBase, Brightness.light),
      isFalse,
      reason:
          'The card drawn inside the safe area must stay visible '
          'through the scrim: $cardWithBase',
    );

    // The same scrolled frame without the base must render identically over
    // the card: the base sits below the content.
    await tester.pumpWidget(buildHarness(withBase: false));
    scrollController.jumpTo(headerExtent - 20);
    await tester.pump();
    final cardWithoutBase = (await tester.runAsync(
      () => rgbAt(boundary, 100, 30),
    ))!;
    expect(
      cardWithoutBase,
      cardWithBase,
      reason:
          'The base must not occlude or tint scrolled content: '
          'with base $cardWithBase vs without $cardWithoutBase',
    );
  });
}
