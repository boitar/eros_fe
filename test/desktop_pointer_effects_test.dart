import 'package:eros_fe/widget/desktop_pointer_effects.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'mouse wheel scrolls horizontally then passes the boundary outward',
    (tester) async {
      final outer = ScrollController();
      final inner = ScrollController();
      await tester.pumpWidget(
        CupertinoApp(
          home: SizedBox(
            height: 300,
            child: SingleChildScrollView(
              controller: outer,
              child: Column(
                children: [
                  SizedBox(
                    height: 100,
                    child: SingleChildScrollView(
                      controller: inner,
                      scrollDirection: Axis.horizontal,
                      child: HorizontalMouseWheel(
                        controller: inner,
                        child: const SizedBox(width: 2000, height: 100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2000),
                ],
              ),
            ),
          ),
        ),
      );
      final location =
          tester.getTopLeft(find.byType(HorizontalMouseWheel)) +
          const Offset(20, 20);
      Future<void> wheel(Offset delta) async {
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: location,
            scrollDelta: delta,
            kind: PointerDeviceKind.mouse,
          ),
        );
        await tester.pump();
      }

      await wheel(const Offset(0, 80));
      expect(inner.offset, 80);
      expect(outer.offset, 0);
      inner.jumpTo(inner.position.maxScrollExtent);
      await wheel(const Offset(0, 80));
      expect(outer.offset, 80);
      outer.jumpTo(0);
      await tester.pump();
      final previous = inner.offset;
      await wheel(const Offset(-40, 0));
      expect(inner.offset, previous - 40);
    },
  );

  testWidgets(
    'hover highlight and click cursor are mouse-only and disabled-aware',
    (tester) async {
      Widget app(bool enabled) => CupertinoApp(
        home: Center(
          child: NavigationHover(
            enabled: enabled,
            child: const SizedBox(width: 100, height: 50),
          ),
        ),
      );
      Color? color() =>
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(NavigationHover),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              is BoxDecoration
          ? (tester
                        .widget<DecoratedBox>(
                          find
                              .descendant(
                                of: find.byType(NavigationHover),
                                matching: find.byType(DecoratedBox),
                              )
                              .first,
                        )
                        .decoration
                    as BoxDecoration)
                .color
          : null;
      await tester.pumpWidget(app(true));
      await tester.tap(find.byType(NavigationHover));
      await tester.pump();
      expect(color()!.a, 0);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: tester.getCenter(find.byType(NavigationHover)),
      );
      await tester.pump();
      expect(color()!.a, greaterThan(0));
      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.click,
      );
      await tester.pumpWidget(app(false));
      await tester.pump();
      expect(color()!.a, 0);
      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        isNot(SystemMouseCursors.click),
      );
      await mouse.removePointer();
    },
  );
}
