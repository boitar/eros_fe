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
    final initialErrors = <FlutterErrorDetails>[];
    final errorHandler = FlutterError.onError;
    try {
      FlutterError.onError = initialErrors.add;
      await tester.pumpWidget(CupertinoApp(
        home: Column(
            children: children
                .map((child) => SizedBox(
                    key: child.key, width: 400, height: 50, child: child))
                .toList()),
      ));
    } finally {
      FlutterError.onError = errorHandler;
    }
    // The inherited rail measures its width in the first layout notification.
    for (final error in initialErrors) {
      expect(error.exceptionAsString(), contains('A RenderFlex overflowed'));
    }
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
}
