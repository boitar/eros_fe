import 'dart:ui' as ui;

import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:eros_fe/widget/scroll_edge_effect.dart';
import 'package:eros_fe/widget/scroll_edge_progress.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

ValueKey<String> _edgeCardKey(int page, int row) =>
    ValueKey('edge-card-$page-$row');

void main() {
  const baseKey = ValueKey<String>('liquid-glass-safe-area-base');
  const scrimKey = ValueKey<String>('liquid-glass-top-scrim');
  const lineKey = ValueKey<String>('liquid-glass-edge-hairline');
  const safeTop = 59.0;
  const barBottom = 153.0;

  setUp(() {
    (LiquidGlassAccessibilitySettings.reduceTransparency
                as ValueNotifier<bool?>)
            .value =
        false;
  });
  tearDown(() async {
    PlatformCapabilities.debugHostPlatformOverride = null;
    await LiquidGlassAccessibilitySettings.stopWatching();
  });

  final cases = [
    (TargetPlatform.iOS, const Size(393, 852), 24.0, 8.0, 16.0),
    (TargetPlatform.iOS, const Size(820, 1180), 28.0, 12.0, 16.0),
  ];

  for (final (platform, size, tail, gap, reveal) in cases) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '$platform $size $brightness follows the edge geometry and curve',
        (tester) async {
          PlatformCapabilities.debugHostPlatformOverride = platform;
          tester.view.physicalSize = size * 2;
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);
          final progress = ValueNotifier<double>(0);
          addTearDown(progress.dispose);
          double? actualGap;
          await tester.pumpWidget(
            CupertinoApp(
              theme: CupertinoThemeData(brightness: brightness),
              home: MediaQuery(
                data: MediaQueryData(size: size, devicePixelRatio: 2),
                child: Builder(
                  builder: (context) {
                    actualGap = LiquidGlassEdgeTokens.contentGapFor(context);
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: Color(0xFFAA2200)),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: LiquidGlassSafeAreaBase(
                            safeTop: safeTop,
                            layout: LiquidGlassTopBarLayout.twoRow,
                            edgeProgress: progress,
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: LiquidGlassTopScrim(
                            safeTop: safeTop,
                            layout: LiquidGlassTopBarLayout.twoRow,
                            edgeProgress: progress,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );

          LinearGradient gradient(Key key) =>
              (tester.widget<DecoratedBox>(find.byKey(key)).decoration
                          as BoxDecoration)
                      .gradient!
                  as LinearGradient;

          expect(actualGap, gap);
          expect(LiquidGlassEdgeTokens.reveal, reveal);
          expect(tester.getRect(find.byKey(baseKey)).bottom, barBottom);
          expect(tester.getRect(find.byKey(scrimKey)).bottom, barBottom);
          expect(
            gradient(baseKey).colors.every((color) => color.a == 0),
            isTrue,
          );
          expect(
            gradient(scrimKey).colors.every((color) => color.a == 0),
            isTrue,
          );
          expect(find.byKey(lineKey), findsNothing);
          expect(find.byType(BackdropFilter), findsNothing);

          progress.value = .5;
          await tester.pump();
          expect(
            tester.getRect(find.byKey(baseKey)).bottom,
            barBottom + tail / 2,
          );
          expect(
            tester.getRect(find.byKey(scrimKey)).bottom,
            barBottom + tail / 2,
          );
          expect(gradient(baseKey).colors.first.a, closeTo(.5, .001));
          if (platform == TargetPlatform.macOS) {
            final blur = tester.widget<BackdropFilter>(
              find.byType(BackdropFilter),
            );
            expect(blur.filter, ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10));
            expect(
              tester.getRect(find.byType(BackdropFilter)).bottom,
              barBottom,
            );
          }

          // A sub-step update must keep geometry and tint on the same cached
          // strength as the shader, including whether the line is visible.
          final halfColors = gradient(scrimKey).colors;
          progress.value = .5001;
          await tester.pump();
          expect(
            tester.getRect(find.byKey(scrimKey)).bottom,
            barBottom + tail / 2,
          );
          expect(
            tester.getRect(find.byKey(baseKey)).bottom,
            barBottom + tail / 2,
          );
          expect(gradient(scrimKey).colors, halfColors);
          expect(gradient(baseKey).colors.first.a, closeTo(.5, .001));

          progress.value = 1;
          await tester.pump();
          expect(tester.getRect(find.byKey(baseKey)).bottom, barBottom + tail);
          expect(tester.getRect(find.byKey(scrimKey)).bottom, barBottom + tail);
          expect(gradient(baseKey).colors.first.a, closeTo(1, .001));

          final desktop =
              platform == TargetPlatform.macOS ||
              platform == TargetPlatform.windows;
          final curve = desktop
              ? SoftEdgeCurve(
                  brightness == Brightness.dark
                      ? const [.96, .94, .92, 0, 0]
                      : const [.94, .92, .90, 0, 0],
                  maxSigma: platform == TargetPlatform.macOS ? 20 : 0,
                )
              : platform == TargetPlatform.android
              ? SoftEdgeCurve.withoutBlur
              : brightness == Brightness.dark
              ? SoftEdgeCurve.dark
              : SoftEdgeCurve.light;
          final expected = curve.sample(inset: safeTop, bars: 94, tail: tail);
          final colors = gradient(scrimKey).colors;
          expect(colors, hasLength(expected.length));
          for (var i = 0; i < colors.length; i++) {
            expect(colors[i].a, closeTo(expected[i], .001), reason: 'stop $i');
          }
          if (desktop) {
            expect(find.byKey(lineKey), findsOneWidget);
            expect(tester.getSize(find.byKey(lineKey)).height, .5);
            final line = tester.widget<ColoredBox>(find.byKey(lineKey));
            expect(
              line.color.a,
              closeTo(brightness == Brightness.dark ? .12 : .18, .001),
            );
          } else {
            expect(find.byKey(lineKey), findsNothing);
          }
          if (platform == TargetPlatform.android ||
              platform == TargetPlatform.windows) {
            expect(find.byType(BackdropFilter), findsNothing);
          } else if (platform == TargetPlatform.macOS) {
            expect(find.byType(BackdropFilter), findsOneWidget);
            expect(
              tester.widget<BackdropFilter>(find.byType(BackdropFilter)).filter,
              ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            );
            expect(
              tester.getRect(find.byType(BackdropFilter)).bottom,
              barBottom,
            );
          } else {
            expect(find.byType(BackdropFilter), findsWidgets);
          }
          progress.value = .0001;
          await tester.pump();
          expect(tester.getRect(find.byKey(scrimKey)).bottom, barBottom);
          expect(tester.getRect(find.byKey(baseKey)).bottom, barBottom);
          expect(
            gradient(baseKey).colors.every((color) => color.a == 0),
            isTrue,
          );
          expect(
            gradient(scrimKey).colors.every((color) => color.a == 0),
            isTrue,
          );
          expect(find.byKey(lineKey), findsNothing);
          expect(find.byType(BackdropFilter), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final (platform, size, tail, gap, reveal) in cases) {
    testWidgets(
      '$platform $size follows real scroll positions and page changes',
      (tester) async {
        PlatformCapabilities.debugHostPlatformOverride = platform;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final edge = ScrollEdgeProgressController(revealDistance: reveal);
        final pages = PageController();
        final lists = [ScrollController(), ScrollController()];
        addTearDown(edge.dispose);
        addTearDown(pages.dispose);
        for (final list in lists) {
          addTearDown(list.dispose);
        }
        var selected = 0;
        await tester.pumpWidget(
          CupertinoApp(
            home: MediaQuery(
              data: MediaQueryData(size: size),
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LiquidGlassSafeAreaBase(
                          safeTop: safeTop,
                          layout: LiquidGlassTopBarLayout.twoRow,
                          edgeProgress: edge,
                        ),
                      ),
                      Positioned.fill(
                        child: ScrollEdgeProgressListener(
                          controller: edge,
                          activePage: selected,
                          child: PageView(
                            controller: pages,
                            onPageChanged: (page) {
                              edge.selectPage(page);
                              setState(() => selected = page);
                            },
                            children: [
                              for (var page = 0; page < 2; page++)
                                ScrollEdgeProgressListener(
                                  controller: edge,
                                  page: page,
                                  child: ListView.builder(
                                    key: PageStorageKey('edge-list-$page'),
                                    controller: lists[page],
                                    padding: EdgeInsets.only(
                                      top: barBottom + gap,
                                    ),
                                    itemCount: 50,
                                    itemBuilder: (_, row) => SizedBox(
                                      key: _edgeCardKey(page, row),
                                      height: 100,
                                      child: const ColoredBox(
                                        color: CupertinoColors.activeBlue,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LiquidGlassTopScrim(
                          safeTop: safeTop,
                          layout: LiquidGlassTopBarLayout.twoRow,
                          edgeProgress: edge,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(edge.value, 0);
        final firstCard = find.byKey(_edgeCardKey(0, 0));
        expect(firstCard, findsOneWidget);
        expect(tester.getRect(firstCard).top, barBottom + gap);
        lists.first.jumpTo(reveal / 2);
        await tester.pump();
        expect(edge.value, .5);
        expect(
          tester.getRect(find.byKey(scrimKey)).bottom,
          barBottom + tail / 2,
        );
        lists.first.jumpTo(reveal);
        await tester.pump();
        expect(edge.value, 1);
        pages.jumpToPage(1);
        await tester.pumpAndSettle();
        expect(edge.value, 0);
        expect(find.byKey(lineKey), findsNothing);
        expect(tester.getRect(find.byKey(scrimKey)).bottom, barBottom);
        pages.jumpToPage(0);
        await tester.pumpAndSettle();
        expect(edge.value, 1);
        lists.first.jumpTo(0);
        await tester.pumpAndSettle();
        expect(edge.value, 0);
        expect(find.byKey(lineKey), findsNothing);
        expect(find.byType(BackdropFilter), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final width in [320.0, 400.0, 500.0]) {
    testWidgets('iPad Flutter edge keeps its tokens in a $width pt pane', (
      tester,
    ) async {
      PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.iOS;
      const size = Size(820, 1180);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final progress = ValueNotifier<double>(0);
      addTearDown(progress.dispose);
      await tester.pumpWidget(
        CupertinoApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: AdaptivePane(
                environment: const AdaptiveEnvironmentSnapshot(size: size),
                rect: Rect.fromLTWH(0, 0, width, size.height),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LiquidGlassSafeAreaBase(
                        safeTop: safeTop,
                        layout: LiquidGlassTopBarLayout.twoRow,
                        edgeProgress: progress,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LiquidGlassTopScrim(
                        safeTop: safeTop,
                        layout: LiquidGlassTopBarLayout.twoRow,
                        edgeProgress: progress,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final context = tester.element(find.byType(LiquidGlassTopScrim));
      expect(MediaQuery.sizeOf(context).width, width);
      expect(LiquidGlassEdgeTokens.contentGapFor(context), 12);
      expect(tester.getRect(find.byKey(baseKey)).bottom, barBottom);
      expect(tester.getRect(find.byKey(scrimKey)).bottom, barBottom);
      progress.value = 1;
      await tester.pump();
      expect(tester.getRect(find.byKey(baseKey)).bottom, barBottom + 28);
      expect(tester.getRect(find.byKey(scrimKey)).bottom, barBottom + 28);
      expect(tester.takeException(), isNull);
    });
  }

  for (final platform in [TargetPlatform.iOS]) {
    testWidgets('$platform scrolled edge respects reduced transparency', (
      tester,
    ) async {
      PlatformCapabilities.debugHostPlatformOverride = platform;
      await tester.pumpWidget(
        const CupertinoApp(
          home: Align(
            alignment: Alignment.topCenter,
            child: LiquidGlassTopScrim(
              safeTop: safeTop,
              layout: LiquidGlassTopBarLayout.twoRow,
              edgeProgress: AlwaysStoppedAnimation<double>(1),
            ),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsWidgets);
      (LiquidGlassAccessibilitySettings.reduceTransparency
                  as ValueNotifier<bool?>)
              .value =
          true;
      await tester.pump();
      expect(find.byType(BackdropFilter), findsNothing);
      final decoration = tester.widget<DecoratedBox>(find.byKey(scrimKey));
      final gradient =
          (decoration.decoration as BoxDecoration).gradient! as LinearGradient;
      expect(
        gradient.colors.first.a,
        closeTo(platform == TargetPlatform.macOS ? 1 : .97, .001),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'progress uses the selected offset, smoothstep and desktop reveal',
    (tester) async {
      final edge = ScrollEdgeProgressController(revealDistance: 8);
      addTearDown(edge.dispose);
      ScrollMetrics metrics(double offset) => FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 300,
        pixels: offset,
        viewportDimension: 400,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 2,
      );
      edge.selectPage('first');
      edge.update(metrics(2), page: 'first');
      expect(edge.value, .15625);
      edge.update(metrics(4), page: 'first');
      expect(edge.value, .5);
      edge.update(metrics(8), page: 'first');
      expect(edge.value, 1);
      edge.update(metrics(0), page: 'second');
      expect(edge.value, 1);
      edge.selectPage('second');
      expect(edge.value, 0);
      edge.selectPage('first');
      expect(edge.value, 1);
      edge.update(metrics(-1));
      expect(edge.value, 0);
      edge.update(metrics(0));
      expect(edge.value, 1);
      edge.update(metrics(-1), page: 'first');
      expect(edge.value, 0);
    },
  );
}
