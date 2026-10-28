import 'package:eros_fe/adaptive/gallery_anchor.dart';
import 'package:eros_fe/pages/item/gallery_grid_tags.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('gallery identity survives 20 list/grid/column-count cycles',
      (tester) async {
    final fixture = await _mount(tester);
    fixture.scroll.jumpTo(1347);
    await tester.pumpAndSettle();
    final before = fixture.anchor.anchor!;
    expect(before.index, greaterThan(10));
    expect(before.leading, lessThan(0));

    for (var cycle = 0; cycle < 20; cycle++) {
      for (final size in [
        const Size(900, 1200),
        const Size(700, 1100),
        const Size(390, 700),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        final after = fixture.anchor.anchor!;
        expect(after.id, before.id, reason: 'cycle=$cycle size=$size');
        expect(after.leading / after.extent,
            closeTo(before.leading / before.extent, 0.001));
        // FlutterSliverList does not expose debugVisitOnstageChildren; verify
        // actual render bounds even for the otherwise skipped test elements.
        final bounds = tester
            .getRect(find.byKey(ValueKey(before.id), skipOffstage: false));
        expect(bounds.bottom, greaterThan(0));
        expect(bounds.top, lessThan(size.height));
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('user scrolling replaces a restored grid-row identity',
      (tester) async {
    final fixture = await _mount(tester);
    fixture.scroll.jumpTo(1347);
    await tester.pumpAndSettle();
    final old = fixture.anchor.anchor!;
    tester.view.physicalSize = const Size(900, 1200);
    await tester.pumpAndSettle();
    expect(fixture.anchor.anchor!.id, old.id);
    fixture.scroll.jumpTo(fixture.scroll.offset + 600);
    await tester.pumpAndSettle();
    final moved = fixture.anchor.anchor!;
    expect(moved.id, isNot(old.id));
    tester.view.physicalSize = const Size(390, 700);
    await tester.pumpAndSettle();
    expect(fixture.anchor.anchor!.id, moved.id);
    final after = fixture.anchor.anchor!;
    expect(after.leading / after.extent,
        closeTo(moved.leading / moved.extent, 0.001));
  });

  testWidgets('top remains top and data append does not replay restoration',
      (tester) async {
    final fixture = await _mount(tester);
    for (final size in [
      const Size(900, 1200),
      const Size(390, 700),
      const Size(700, 1100),
      const Size(390, 700),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(fixture.scroll.offset, 0);
      expect(fixture.anchor.anchor!.index, 0);
    }
    fixture.scroll.jumpTo(1347);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(900, 1200);
    await tester.pumpAndSettle();
    fixture.scroll.jumpTo(fixture.scroll.offset + 600);
    await tester.pumpAndSettle();
    final before = fixture.anchor.anchor!;
    final offset = fixture.scroll.offset;
    fixture.ids.value = [...fixture.ids.value, 'appended-gallery'];
    await tester.pumpAndSettle();
    expect(fixture.anchor.anchor!.id, before.id);
    expect(fixture.scroll.offset, offset);
  });
}

class _Fixture {
  final scroll = ScrollController();
  final anchor = GalleryAnchorController();
  final ids = ValueNotifier(List.generate(200, (index) => 'gallery-$index'));
}

Future<_Fixture> _mount(WidgetTester tester) async {
  final fixture = _Fixture();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 700);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(fixture.scroll.dispose);
  addTearDown(fixture.ids.dispose);
  await tester.pumpWidget(CupertinoApp(
    home: ValueListenableBuilder(
      valueListenable: fixture.ids,
      builder: (context, ids, _) {
        final grid = MediaQuery.sizeOf(context).width >= 600;
        Widget item(int index) => GalleryAnchorItem(
              key: ValueKey(ids[index]),
              id: ids[index],
              index: index,
              child: SizedBox(
                height: 62 + (index % 4) * 13,
                child: Text(ids[index]),
              ),
            );
        return CustomScrollView(
          controller: fixture.scroll,
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
            AnchoredGallerySliver(
              controller: fixture.anchor,
              itemIds: ids,
              layout: grid,
              sliver: grid
                  ? SliverPadding(
                      padding: const EdgeInsets.all(8),
                      sliver: GalleryGridTagsSliver(
                        maxCrossAxisExtent: 230,
                        delegate: SliverChildBuilderDelegate(
                          (_, index) => item(index),
                          childCount: ids.length,
                        ),
                      ),
                    )
                  : Builder(builder: (context) {
                      final restoration =
                          GalleryAnchorScope.maybeOf(context)?.restoration;
                      return FlutterSliverList(
                        delegate: FlutterListViewDelegate(
                          (_, index) => item(index),
                          childCount: ids.length,
                          onItemKey: (index) => ids[index],
                          initIndex: restoration?.anchor.index ?? 0,
                          initOffset: 0,
                          forceToExecuteInitIndex: restoration?.generation,
                        ),
                      );
                    }),
            ),
          ],
        );
      },
    ),
  ));
  await tester.pumpAndSettle();
  return fixture;
}
