import 'package:eros_fe/widget/link_scroll_bar.dart';
import 'package:eros_fe/widget/link_scroll_bar_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  LinkScrollBar rail(LinkScrollBarController controller, String key) =>
      LinkScrollBar(
        key: ValueKey(key),
        controller: controller,
        initIndex: 0,
        items: [LinkTabItem(title: 'First'), LinkTabItem(title: 'Second')],
      );

  Future<void> show(WidgetTester tester, List<Widget> children) async {
    await tester.pumpWidget(CupertinoApp(
      home: Column(
          children: children
              .map((child) => SizedBox(
                  key: child.key, width: 400, height: 50, child: child))
              .toList()),
    ));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
  }

  testWidgets('removing a traditional rail releases its callback',
      (tester) async {
    final controller = LinkScrollBarController();
    await show(tester, [rail(controller, 'old')]);
    final retained = controller.scrollToItemCall!;
    await show(tester, []);
    expect(controller.scrollToItemCall, isNull);
    controller.scrollToItem(1);
    retained(1);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('replacing the controller leaves the live rail selectable',
      (tester) async {
    final oldController = LinkScrollBarController();
    final nextController = LinkScrollBarController();
    await show(tester, [rail(oldController, 'same')]);
    await show(tester, [rail(nextController, 'same')]);
    expect(oldController.scrollToItemCall, isNull);
    expect(nextController.scrollToItemCall, isNotNull);
    nextController.scrollToItem(1);
    await tester.pumpAndSettle();
    final second = tester
        .widgetList<InnerLinkTabItem>(find.byType(InnerLinkTabItem))
        .singleWhere((item) => item.title == 'Second');
    expect(second.selected, isTrue);
    await show(tester, []);
    oldController.dispose();
    nextController.dispose();
  });

  testWidgets('disposing an older rail preserves the newer binding',
      (tester) async {
    final controller = LinkScrollBarController();
    await show(tester, [rail(controller, 'old'), rail(controller, 'new')]);
    final live = controller.scrollToItemCall;
    await show(tester, [rail(controller, 'new')]);
    expect(identical(controller.scrollToItemCall, live), isTrue);
    controller.scrollToItem(1);
    await tester.pumpAndSettle();
    final second = tester
        .widgetList<InnerLinkTabItem>(find.byType(InnerLinkTabItem))
        .singleWhere((item) => item.title == 'Second');
    expect(second.selected, isTrue);
    await show(tester, []);
    controller.dispose();
  });

  testWidgets('first frame and 20 resizes never overflow the group rail',
      (tester) async {
    final controller = LinkScrollBarController();
    final width = ValueNotifier(320.0);
    addTearDown(controller.dispose);
    addTearDown(width.dispose);
    await tester.pumpWidget(CupertinoApp(
      home: ValueListenableBuilder(
        valueListenable: width,
        builder: (context, value, _) => Center(
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(value == 466 ? 1.6 : 1)),
            child: SizedBox(
              width: value,
              height: 60,
              child: LinkScrollBar(
                controller: controller,
                initIndex: 0,
                items: List.generate(
                    10, (i) => LinkTabItem(title: 'Long group title $i')),
              ),
            ),
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    for (var cycle = 0; cycle < 20; cycle++) {
      for (final size in [320.0, 466.0, 720.0]) {
        width.value = size;
        await tester.pumpAndSettle();
        controller.scrollToItem(9);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final item = tester
            .widgetList<InnerLinkTabItem>(find.byType(InnerLinkTabItem))
            .last;
        expect(item.selected, isTrue);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
