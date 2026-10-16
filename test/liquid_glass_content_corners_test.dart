import 'dart:ui' as ui;

import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
        'content corners keep a fixed 20pt shape and fade only: $brightness',
        (tester) async {
      final progress = ValueNotifier(1.0);
      addTearDown(progress.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(CupertinoApp(
        theme: CupertinoThemeData(brightness: brightness),
        home: Center(
            child: RepaintBoundary(
                key: boundary,
                child: SizedBox(
                  width: 200,
                  height: 240,
                  child: Stack(children: [
                    const Positioned.fill(
                        child: ColoredBox(color: Color(0xFF888888))),
                    Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LiquidGlassSolidMask(
                          progressListenable: progress,
                          safeTop: 40,
                          height: 140,
                        )),
                  ]),
                ))),
      ));
      // The mask bottom follows the first card from safeTop (40) to the
      // expanded rail's lower edge (140); the corners ride on that edge.
      for (final value in [1.0, 0.75, 0.5, 0.25, 0.0]) {
        progress.value = value;
        await tester.pump();
        final corners =
            find.byKey(const ValueKey('liquid-glass-content-corners'));
        if (value == 0) {
          expect(corners, findsNothing);
        } else {
          // The drawing region keeps its fixed 20pt size at every progress;
          // only the opacity follows the reveal, so the radius can never
          // degrade into a square corner.
          expect(tester.getSize(corners).height, 20);
          expect(
              tester.getTopLeft(corners).dy -
                  tester.getTopLeft(find.byKey(boundary)).dy,
              40 + 100 * value);
          expect(
            tester
                .widget<Opacity>(
                  find.ancestor(of: corners, matching: find.byType(Opacity)),
                )
                .opacity,
            value,
          );
        }
        await tester.runAsync(() async {
          final render = boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await render.toImage();
          final bytes =
              (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          int channel(int x, int y) =>
              bytes.getUint8((y * image.width + x) * 4);
          if (value == 0) {
            // Fully retracted: no white corner block may remain.
            expect(channel(0, 40), 136);
            expect(channel(0, 140), 136);
          } else {
            final edge = (40 + 100 * value).round();
            final opaque = brightness == Brightness.light ? 255 : 0;
            int blend(int fg) => (fg * value + 136 * (1 - value)).round();
            // The ears hug both upper corners of the region.
            expect((channel(0, edge) - blend(opaque)).abs(), lessThanOrEqualTo(2));
            expect(
                (channel(199, edge) - blend(opaque)).abs(), lessThanOrEqualTo(2));
            // A fixed 20pt radius keeps the ear reaching 10pt into the region
            // even at low progress; a progress-scaled radius would not.
            expect(
                (channel(0, edge + 10) - blend(opaque)).abs(),
                lessThanOrEqualTo(2));
            // The middle and the area below the 20pt region stay unpainted.
            expect(channel(100, edge + 2), 136);
            expect(channel(0, edge + 21), 136);
          }
          image.dispose();
        });
      }
    });
  }
}
