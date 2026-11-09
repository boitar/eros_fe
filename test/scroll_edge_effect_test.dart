import 'dart:ui' as ui;

import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/widget/scroll_edge_effect.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SoftEdgeCurve', () {
    const inset = 62.0;
    const bars = 44.0;
    const tail = 36.0;

    for (final entry in <String, SoftEdgeCurve>{
      'light': SoftEdgeCurve.light,
      'dark': SoftEdgeCurve.dark,
      'reduced transparency': SoftEdgeCurve.reducedTransparency,
      'media': SoftEdgeCurve.media,
      'without blur': SoftEdgeCurve.withoutBlur,
      'media without blur': SoftEdgeCurve.mediaWithoutBlur,
    }.entries) {
      test('${entry.key} fades monotonically to zero', () {
        final alphas =
            entry.value.sample(inset: inset, bars: bars, tail: tail);
        expect(alphas.first, entry.value.alphas.first);
        expect(alphas.last, 0);
        for (var i = 1; i < alphas.length; i++) {
          expect(alphas[i], lessThanOrEqualTo(alphas[i - 1] + 1e-9));
        }
      });
    }

    test('surface fade has no cliff', () {
      const extent = inset + bars + tail;
      final alphas = SoftEdgeCurve.light
          .sample(inset: inset, bars: bars, tail: tail, count: 200);
      const step = extent / 199;
      for (var i = 1; i < alphas.length; i++) {
        expect((alphas[i - 1] - alphas[i]) / step, lessThan(0.03));
      }
    });

    test('collapsed bars and a missing inset still produce a fade', () {
      final alphas = SoftEdgeCurve.light.sample(inset: 0, bars: 0, tail: tail);
      expect(alphas.first, SoftEdgeCurve.light.alphas.first);
      expect(alphas.last, 0);
    });

    test('control points sit at the bars and the tail', () {
      expect(
          SoftEdgeCurve.positions(inset: inset, bars: bars, tail: tail),
          <double>[0, 84, 106, 124, 142]);
    });
  });

  group('SoftScrollEdgeEffect', () {
    Widget host(Widget child, {Brightness brightness = Brightness.light}) =>
        CupertinoApp(
          theme: CupertinoThemeData(brightness: brightness),
          home: Stack(children: [
            Positioned(left: 0, right: 0, top: 0, child: child),
          ]),
        );

    testWidgets('is as tall as the inset, bars and tail and ignores touches',
        (tester) async {
      await tester.pumpWidget(host(const SoftScrollEdgeEffect(
        edge: SoftEdge.top,
        inset: 50,
        bars: 44,
      )));
      final rect = tester.getRect(find.byType(SoftScrollEdgeEffect));
      expect(rect.height, 50 + 44 + SoftScrollEdgeEffect.defaultTail);
      expect(
          find.descendant(
              of: find.byType(SoftScrollEdgeEffect),
              matching: find.byType(IgnorePointer)),
          findsWidgets);
    });

    testWidgets('falls back to banded blur without shader filters',
        (tester) async {
      expect(ui.ImageFilter.isShaderFilterSupported, isFalse);
      await tester.pumpWidget(host(const SoftScrollEdgeEffect(
        edge: SoftEdge.top,
        inset: 50,
        bars: 44,
      )));
      expect(
          find.descendant(
              of: find.byType(SoftScrollEdgeEffect),
              matching: find.byType(BackdropFilter)),
          findsNWidgets(3));
    });

    for (final brightness in Brightness.values) {
      testWidgets('strength scales tint and blur together in $brightness', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(
            const SoftScrollEdgeEffect(
              edge: SoftEdge.top,
              inset: 50,
              bars: 44,
              tail: 12,
              strength: 0.5,
            ),
            brightness: brightness,
          ),
        );
        final curve = brightness == Brightness.dark
            ? SoftEdgeCurve.dark
            : SoftEdgeCurve.light;
        final box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(SoftScrollEdgeEffect),
            matching: find.byType(DecoratedBox),
          ),
        );
        final gradient =
            (box.decoration as BoxDecoration).gradient! as LinearGradient;
        expect(
          gradient.colors.first.a,
          closeTo(curve.alphas.first * 0.5, 0.001),
        );
        expect(gradient.colors.last.a, 0);
        final blur = tester.widgetList<BackdropFilter>(
          find.descendant(
            of: find.byType(SoftScrollEdgeEffect),
            matching: find.byType(BackdropFilter),
          ),
        );
        expect(
          blur.first.filter,
          ui.ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
        );
      });
    }

    testWidgets(
      'zero strength disables blur and leaves every tint transparent',
      (tester) async {
        await tester.pumpWidget(
          host(
            const SoftScrollEdgeEffect(
              edge: SoftEdge.top,
              inset: 50,
              bars: 44,
              tail: 0,
              strength: 0,
            ),
          ),
        );
        expect(find.byType(BackdropFilter), findsNothing);
        final box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(SoftScrollEdgeEffect),
            matching: find.byType(DecoratedBox),
          ),
        );
        final gradient =
            (box.decoration as BoxDecoration).gradient! as LinearGradient;
        expect(gradient.colors.every((color) => color.a == 0), isTrue);
      },
    );

    test('nearby progress values share one shader strength', () {
      expect(SoftScrollEdgeEffect.quantizeStrength(0.5001), 0.5);
      expect(SoftScrollEdgeEffect.quantizeStrength(0.501), 0.5);
      expect(SoftScrollEdgeEffect.quantizeStrength(-1), 0);
      expect(SoftScrollEdgeEffect.quantizeStrength(2), 1);
    });

    testWidgets('Android fades without any blur', (tester) async {
      PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
      addTearDown(() => PlatformCapabilities.debugHostPlatformOverride = null);
      for (final tone in SoftEdgeTone.values) {
        await tester.pumpWidget(host(SoftScrollEdgeEffect(
          edge: SoftEdge.top,
          inset: 50,
          bars: 44,
          tone: tone,
        )));
        expect(
            find.descendant(
                of: find.byType(SoftScrollEdgeEffect),
                matching: find.byType(BackdropFilter)),
            findsNothing,
            reason: '$tone');
        final box = tester.widget<DecoratedBox>(find.descendant(
            of: find.byType(SoftScrollEdgeEffect),
            matching: find.byType(DecoratedBox)));
        final gradient =
            (box.decoration as BoxDecoration).gradient! as LinearGradient;
        expect(gradient.colors.last.a, 0, reason: '$tone');
      }
    });

    testWidgets('bottom media edge dims toward black from the bottom',
        (tester) async {
      await tester.pumpWidget(host(const SoftScrollEdgeEffect(
        edge: SoftEdge.bottom,
        inset: 0,
        bars: 80,
        tail: 40,
        tone: SoftEdgeTone.media,
      )));
      final box = tester.widget<DecoratedBox>(find.descendant(
          of: find.byType(SoftScrollEdgeEffect),
          matching: find.byType(DecoratedBox)));
      final gradient =
          (box.decoration as BoxDecoration).gradient! as LinearGradient;
      expect(gradient.begin, Alignment.bottomCenter);
      expect(gradient.colors.first,
          CupertinoColors.black.withValues(alpha: 0.5));
      expect(gradient.colors.last.a, 0);
    });

    testWidgets('dark surfaces start from a denser tint', (tester) async {
      await tester.pumpWidget(host(
        const SoftScrollEdgeEffect(edge: SoftEdge.top, inset: 50, bars: 44),
        brightness: Brightness.dark,
      ));
      final box = tester.widget<DecoratedBox>(find.descendant(
          of: find.byType(SoftScrollEdgeEffect),
          matching: find.byType(DecoratedBox)));
      final gradient =
          (box.decoration as BoxDecoration).gradient! as LinearGradient;
      expect(gradient.colors.first.a, closeTo(0.86, 0.01));
    });
  });
}
