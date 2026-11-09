import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:eros_fe/widget/liquid_glass_scroll_controller.dart';
import 'package:eros_fe/widget/scroll_edge_effect.dart';
import 'package:eros_fe/widget/scroll_edge_progress.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = ValueKey('liquid-glass-safe-area-base');
  const scrim = ValueKey('liquid-glass-top-scrim');
  const canvas = Color(0xFF324654);
  tearDown(() {
    PlatformCapabilities.debugHostPlatformOverride = null;
    (LiquidGlassAccessibilitySettings.reduceTransparency
                as ValueNotifier<bool?>)
            .value =
        false;
  });
  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.macOS,
    TargetPlatform.windows,
  ]) {
    for (final brightness in Brightness.values) {
      for (final cardTop in [161.0, 300.0]) {
        testWidgets(
          '$platform $brightness resting card $cardTop v2 geometry and tint',
          (tester) async {
            PlatformCapabilities.debugHostPlatformOverride = platform;
            tester.view.physicalSize = const Size(800, 1200);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final p = ValueNotifier<double>(0);
            final rest = ValueNotifier<double?>(cardTop);
            addTearDown(p.dispose);
            addTearDown(rest.dispose);
            await tester.pumpWidget(
              CupertinoApp(
                theme: CupertinoThemeData(
                  brightness: brightness,
                  scaffoldBackgroundColor: canvas,
                ),
                home: Stack(
                  children: [
                    LiquidGlassSafeAreaBase(
                      safeTop: 59,
                      layout: LiquidGlassTopBarLayout.twoRow,
                      edgeProgress: p,
                      firstCardRestTop: rest,
                    ),
                    const LiquidGlassSolidMask(
                      progressListenable: AlwaysStoppedAnimation(1),
                      safeTop: 59,
                      height: 153,
                    ),
                    LiquidGlassTopScrim(
                      safeTop: 59,
                      layout: LiquidGlassTopBarLayout.twoRow,
                      edgeProgress: p,
                      firstCardRestTop: rest,
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
            final android = platform == TargetPlatform.android;
            const target = 1200 * .17;
            final resting = cardTop < target ? cardTop : target;
            for (final progress in [0.0, .5, 1.0]) {
              p.value = progress;
              await tester.pump();
              final end = android
                  ? resting + (target - resting) * progress
                  : 153 + 16 * progress;
              expect(find.byKey(scrim), findsOneWidget);
              expect(
                tester.getRect(find.byKey(scrim)).bottom,
                closeTo(end, .001),
              );
              final g = gradient(scrim);
              if (android) {
                expect(
                  tester.getRect(find.byKey(base)).bottom,
                  closeTo(end, .001),
                );
                expect(
                  gradient(base).colors.map((c) => c.a),
                  orderedEquals([1, 1, .84, .28, 0]),
                );
                final alpha = brightness == Brightness.dark ? .37 : .32;
                for (var i = 0; i < 4; i++) {
                  expect(
                    g.colors[i].a,
                    closeTo(alpha * [1, .55, .22, 0][i], .001),
                  );
                }
                expect(g.stops, [0, .35, .70, 1]);
                expect(
                  find.byKey(const ValueKey('liquid-glass-solid-mask')),
                  findsOneWidget,
                );
                expect(
                  tester.getSize(find.byType(LiquidGlassSolidMask)).height,
                  173,
                );
              } else {
                expect(find.byKey(base), findsNothing);
                expect(
                  find.byKey(const ValueKey('liquid-glass-solid-mask')),
                  findsNothing,
                );
                expect(
                  find.byKey(const ValueKey('liquid-glass-content-corners')),
                  findsNothing,
                );
                final curve = SoftEdgeCurve(
                  brightness == Brightness.dark
                      ? [.94, .90, .84, .36, 0]
                      : [.92, .88, .80, .32, 0],
                  maxSigma: 0,
                );
                final expected = curve.sample(
                  inset: 59,
                  bars: 94,
                  tail: 16 * progress,
                );
                for (var i = 0; i < g.colors.length; i++) {
                  expect(g.colors[i].a, closeTo(expected[i] * progress, .001));
                  expect(g.colors[i].withValues(alpha: 1), canvas);
                }
              }
              expect(find.byType(BackdropFilter), findsNothing);
              expect(find.byType(SoftScrollEdgeEffect), findsNothing);
              expect(
                find.byKey(const ValueKey('liquid-glass-edge-hairline')),
                findsNothing,
              );
            }
            if (!android) {
              (LiquidGlassAccessibilitySettings.reduceTransparency
                          as ValueNotifier<bool?>)
                      .value =
                  true;
              await tester.pump();
              final expected = const SoftEdgeCurve([
                1,
                1,
                .96,
                .40,
                0,
              ], maxSigma: 0).sample(inset: 59, bars: 94, tail: 16);
              final colors = gradient(scrim).colors;
              for (var i = 0; i < colors.length; i++) {
                expect(colors[i].a, closeTo(expected[i], .001));
              }
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
  testWidgets(
    'Android cap keeps an unknown keyed root through scrolling and bounce',
    (tester) async {
      PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final scroll = ScrollController();
      final edge = ScrollEdgeProgressController();
      final key = GlobalKey();
      final state = LiquidGlassTopStateCoordinator(
        scrollController: scroll,
        firstCardTopProvider: () => liquidGlassScreenTop(key),
        firstCardRestTopProvider: () => liquidGlassCardScreenTop(key),
      );
      state.updateLayout(devicePixelRatio: 1, topBarExtent: 153, safeTop: 59);
      addTearDown(state.dispose);
      addTearDown(edge.dispose);
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        CupertinoApp(
          home: Stack(
            children: [
              ScrollEdgeProgressListener(
                controller: edge,
                child: SingleChildScrollView(
                  controller: scroll,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 153),
                      Container(
                        key: key,
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: CupertinoColors.activeBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        height: 1600,
                      ),
                    ],
                  ),
                ),
              ),
              LiquidGlassTopScrim(
                safeTop: 59,
                layout: LiquidGlassTopBarLayout.twoRow,
                edgeProgress: edge,
                firstCardRestTop: state.firstCardRestTop,
              ),
            ],
          ),
        ),
      );
      state.refresh();
      await tester.pump();
      expect(state.firstCardRestTop.value, 153);
      expect(tester.getRect(find.byKey(scrim)).bottom, 153);
      scroll.jumpTo(8);
      await tester.pump();
      state.refresh();
      await tester.pump();
      expect(edge.value, .5);
      expect(state.firstCardRestTop.value, 153);
      expect(tester.getRect(find.byKey(scrim)).bottom, 178.5);
      scroll.jumpTo(16);
      await tester.pump();
      expect(tester.getRect(find.byKey(scrim)).bottom, closeTo(204, .001));
      scroll.jumpTo(-8);
      state.refresh();
      await tester.pump();
      expect(edge.value, 0);
      expect(state.firstCardRestTop.value, 153);
      expect(tester.getRect(find.byKey(scrim)).bottom, 153);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final platform in [TargetPlatform.macOS, TargetPlatform.windows]) {
    testWidgets(
      '$platform single title scrim stays inside the rounded content pane',
      (tester) async {
        PlatformCapabilities.debugHostPlatformOverride = platform;
        tester.view.physicalSize = const Size(900, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final p = ValueNotifier<double>(0);
        addTearDown(p.dispose);
        await tester.pumpWidget(
          CupertinoApp(
            theme: const CupertinoThemeData(scaffoldBackgroundColor: canvas),
            home: Stack(
              children: [
                Positioned(
                  left: 120,
                  top: 0,
                  width: 400,
                  height: 900,
                  child: AdaptivePane(
                    environment: const AdaptiveEnvironmentSnapshot(
                      size: Size(900, 900),
                    ),
                    rect: const Rect.fromLTWH(120, 0, 400, 900),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          ListView(
                            padding: const EdgeInsets.only(top: 56),
                            children: const [
                              SizedBox(
                                key: ValueKey('desktop-first-card'),
                                height: 100,
                              ),
                            ],
                          ),
                          LiquidGlassTopScrim(
                            safeTop: 0,
                            layout: LiquidGlassTopBarLayout.twoRow,
                            hasCategories: false,
                            edgeProgress: p,
                          ),
                          const LiquidGlassRail(
                            title: '热门',
                          fadeProgress: 0,
                            safeTop: 0,
                            showsTitle: true,
                            selectedIndex: 0,
                            categories: [],
                            layout: LiquidGlassTopBarLayout.twoRow,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        expect(find.text('热门'), findsOneWidget);
        expect(
          tester.getRect(find.byKey(const ValueKey('desktop-first-card'))).top,
          56,
        );
        expect(find.byType(LiquidGlassSolidMask), findsNothing);
        LinearGradient gradient() =>
            (tester.widget<DecoratedBox>(find.byKey(scrim)).decoration
                        as BoxDecoration)
                    .gradient!
                as LinearGradient;
        expect(gradient().colors.every((c) => c.a == 0), isTrue);
        p.value = 1;
        await tester.pump();
        expect(
          tester.getRect(find.byKey(scrim)),
          const Rect.fromLTWH(120, 0, 400, 60),
        );
        final expected = const SoftEdgeCurve([
          .92,
          .88,
          .80,
          .32,
          0,
        ], maxSigma: 0).sample(inset: 0, bars: 44, tail: 16);
        for (var i = 0; i < expected.length; i++) {
          expect(gradient().colors[i].a, closeTo(expected[i], .001));
        }
        expect(find.byType(BackdropFilter), findsNothing);
        expect(
          find.byKey(const ValueKey('liquid-glass-edge-hairline')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
