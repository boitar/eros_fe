import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/adaptive/native_top_header.dart';
import 'package:eros_fe/widget/scroll_edge_effect.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget header(double extent) => CupertinoApp(
        home: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: extent,
            child: const NativeTopTabHeader(
              topInset: 50,
              railHeight: 44,
              child: SizedBox.expand(key: ValueKey('rail')),
            ),
          ),
        ),
      );

  double railOpacity(WidgetTester tester) => tester
      .widget<Opacity>(find.ancestor(
          of: find.byKey(const ValueKey('rail')),
          matching: find.byType(Opacity)))
      .opacity;

  testWidgets('rail sits at the bottom and the fade reaches past it',
      (tester) async {
    await tester.pumpWidget(header(94));
    expect(tester.getRect(find.byKey(const ValueKey('rail'))),
        const Rect.fromLTWH(0, 50, 800, 44));
    expect(railOpacity(tester), 1);
    final fade = tester.getRect(find.descendant(
        of: find.byType(NativeTopTabHeader),
        matching: find.byType(SoftScrollEdgeEffect)));
    expect(fade.top, 0);
    expect(fade.bottom, 94 + SoftScrollEdgeEffect.defaultTail);
  });

  testWidgets('rail fades out as the header collapses to the bars above',
      (tester) async {
    await tester.pumpWidget(header(72));
    expect(railOpacity(tester), closeTo(0.5, 0.01));
    await tester.pumpWidget(header(50));
    expect(railOpacity(tester), 0);
  });

  test('collapsible header keeps only the top inset', () {
    expect(
        NativeTopTabHeader.minExtentFor(
            topInset: 50, railHeight: 44, collapsible: true),
        50);
    expect(
        NativeTopTabHeader.minExtentFor(
            topInset: 50, railHeight: 44, collapsible: false),
        94);
  });

  testWidgets('scrolling down collapses the root bar and scrolling up restores',
      (tester) async {
    NativeNavigationBridge.rootBarCollapsed.value = false;
    await tester.pumpWidget(CupertinoApp(
      home: NativeBarAutoHide(
        enabled: true,
        child: ListView.builder(
          itemCount: 100,
          itemBuilder: (_, index) =>
              SizedBox(height: 60, child: Text('$index')),
        ),
      ),
    ));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump();
    expect(NativeNavigationBridge.rootBarCollapsed.value, isTrue);
    await tester.drag(find.byType(ListView), const Offset(0, 100));
    await tester.pump();
    expect(NativeNavigationBridge.rootBarCollapsed.value, isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(NativeNavigationBridge.rootBarCollapsed.value, isFalse);
  });
}
