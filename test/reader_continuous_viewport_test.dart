import 'package:eros_fe/pages/image_view/view/reader_continuous_viewport.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

void main() {
  for (final start in [0, 5]) {
    for (final spacing in [0.0, 8.0]) {
      testWidgets(
          '20 resizes preserve image progress (start=$start, gap=$spacing)',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1200, 1200);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        late ScrollOffsetController scrollOffset;
        final positions = ItemPositionsListener.create();
        final controller = ItemScrollController();
        final size = ValueNotifier(const Size(382, 644));
        addTearDown(size.dispose);
        await tester.pumpWidget(CupertinoApp(
          home: Center(
            child: ValueListenableBuilder<Size>(
              valueListenable: size,
              builder: (_, size, __) => SizedBox.fromSize(
                size: size,
                child: ReaderContinuousViewport(
                  positions: positions,
                  itemScrollController: controller,
                  trailingSpacing: spacing,
                  builder: (_, offset) {
                    scrollOffset = offset;
                    return ScrollablePositionedList.builder(
                      initialScrollIndex: start,
                      itemScrollController: controller,
                      scrollOffsetController: offset,
                      itemPositionsListener: positions,
                      itemCount: 9,
                      itemBuilder: (_, index) => SizedBox(
                        height: size.width * (index == 5 ? 10 : 1.5) + spacing,
                        child: Text('Image $index'),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        final moved = scrollOffset.animateScroll(
          offset: (start == 0 ? 5 * (382 * 1.5 + spacing) : 0) + 300,
          duration: const Duration(milliseconds: 1),
        );
        await tester.pumpAndSettle();
        await moved;
        double progress() {
          final item =
              positions.itemPositions.value.singleWhere((p) => p.index == 5);
          return -item.itemLeadingEdge /
              (item.itemTrailingEdge -
                  item.itemLeadingEdge -
                  spacing /
                      tester
                          .getSize(find.byType(ReaderContinuousViewport))
                          .height);
        }

        final original = progress();
        expect(original, greaterThan(0.05));
        for (var cycle = 0; cycle < 20; cycle++) {
          size.value =
              cycle.isEven ? const Size(700, 420) : const Size(382, 644);
          await tester.pumpAndSettle();
          expect(progress(), closeTo(original, 0.001), reason: 'resize $cycle');
          expect(tester.takeException(), isNull);
        }
        // Another resize before the first restore callback must retain the original.
        size.value = const Size(911, 867);
        await tester.pump();
        size.value = const Size(420, 500);
        await tester.pumpAndSettle();
        expect(progress(), closeTo(original, 0.001));
        controller.jumpTo(index: 6);
        await tester.pumpAndSettle();
        size.value = const Size(700, 420);
        await tester.pumpAndSettle();
        expect(
            positions.itemPositions.value
                .any((p) => p.index == 6 && p.itemLeadingEdge.abs() < 0.01),
            isTrue);
        size.value = const Size(911, 867);
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
