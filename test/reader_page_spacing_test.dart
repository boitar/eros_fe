import 'dart:convert';

import 'package:eros_fe/pages/image_view/view/reader_gesture_page_view.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('two contacts zoom the image when one finger moves first',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = ExtendedPageController(
      keepPage: false,
      shouldIgnorePointerWhenScrolling: true,
    );
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8'
      '/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
    );
    await tester.pumpWidget(CupertinoApp(
      home: ReaderGesturePageView(
        controller: controller,
        pageSpacing: 20,
        itemCount: 2,
        itemBuilder: (_, index) => ExtendedImage.memory(
          bytes,
          key: ValueKey(index),
          fit: BoxFit.contain,
          mode: ExtendedImageMode.gesture,
          initGestureConfigHandler: (_) => GestureConfig(
            inPageView: true,
            initialScale: 1,
            minScale: 1,
            maxScale: 5,
            hitTestBehavior: HitTestBehavior.opaque,
          ),
        ),
      ),
    ));
    for (var attempt = 0;
        attempt < 30 && find.byType(ExtendedImageGesture).evaluate().isEmpty;
        attempt++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
    }
    expect(find.byType(ExtendedImageGesture), findsOneWidget);
    final image = tester
        .state<ExtendedImageGestureState>(find.byType(ExtendedImageGesture));
    final first = await tester.startGesture(const Offset(150, 350), pointer: 1);
    final second =
        await tester.startGesture(const Offset(250, 350), pointer: 2);
    await first.moveTo(const Offset(90, 350));
    await tester.pump(const Duration(milliseconds: 16));
    await second.moveTo(const Offset(310, 350));
    await tester.pump(const Duration(milliseconds: 16));
    await first.moveTo(const Offset(50, 350));
    await tester.pump(const Duration(milliseconds: 16));
    await second.moveTo(const Offset(350, 350));
    await tester.pump(const Duration(milliseconds: 16));
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(image.gestureDetails?.totalScale, greaterThan(1.5));
    expect(controller.page, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  for (final spacing in [0.0, 20.0]) {
    for (final reverse in [false, true]) {
      for (final textDirection in TextDirection.values) {
        testWidgets(
            'gesture spacing=$spacing reverse=$reverse text=$textDirection '
            'retains full pages through 20 resizes', (tester) async {
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final controller = ExtendedPageController(
            initialPage: 5,
            keepPage: false,
          );
          final reversed = reverse != (textDirection == TextDirection.rtl);
          const sizes = [
            Size(382, 644),
            Size(466, 678),
            Size(911, 669),
            Size(455.5, 669),
            Size(320, 480),
          ];
          for (var cycle = 0; cycle < 20; cycle++) {
            final size = sizes[cycle % sizes.length];
            tester.view.physicalSize = size;
            await tester.pumpWidget(CupertinoApp(
              home: Directionality(
                textDirection: textDirection,
                child: ReaderGesturePageView(
                  controller: controller,
                  pageSpacing: spacing,
                  reverse: reverse,
                  itemCount: 11,
                  itemBuilder: (_, index) => SizedBox.expand(
                    key: ValueKey('page-$index'),
                  ),
                ),
              ),
            ));
            await tester.pump();
            expect(tester.takeException(), isNull);
            expect(controller.page, closeTo(5, 1e-9));
            expect(tester.getRect(find.byKey(const ValueKey('page-5'))),
                Offset.zero & size);
            expect(controller.position.maxScrollExtent,
                closeTo(10 * (size.width + spacing), 1e-9));

            controller.position.jumpTo(5.5 * (size.width + spacing));
            await tester.pump();
            final current =
                tester.getRect(find.byKey(const ValueKey('page-5')));
            final next = tester.getRect(find.byKey(const ValueKey('page-6')));
            final gap = reversed
                ? current.left - next.right
                : next.left - current.right;
            expect(gap, closeTo(spacing, 1e-9));
            expect(current.size, size);
            expect(next.size, size);
            controller.jumpToPage(5);
            await tester.pump();
          }
          for (final edge in [0, 10]) {
            controller.jumpToPage(edge);
            await tester.pump();
            expect(tester.getRect(find.byKey(ValueKey('page-$edge'))),
                Offset.zero & sizes.last);
            expect(tester.takeException(), isNull);
          }
          controller.jumpToPage(5);
          await tester.pump();
          await tester.drag(
            find.byType(ReaderGesturePageView),
            Offset((reversed ? 1 : -1) * sizes.last.width * 0.75, 0),
          );
          await tester.pumpAndSettle();
          expect(controller.page, closeTo(6, 1e-9));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          controller.dispose();
        });
      }
    }
  }
}
