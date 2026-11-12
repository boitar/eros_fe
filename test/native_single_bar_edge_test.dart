import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/adaptive/native_single_bar_edge.dart';
import 'package:eros_fe/adaptive/native_top_header.dart';
import 'package:eros_fe/widget/scroll_edge_effect.dart';
import 'package:eros_fe/widget/scroll_edge_progress.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => NativeNavigationBridge.enabled.value = false);

  testWidgets('rest, reveal and full-strength tail use the shared controller', (
    tester,
  ) async {
    const size = Size(390, 844);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);

    await tester.pumpWidget(
      _host(
        native: true,
        size: size,
        child: NativeSingleBarEdge(child: _scroll(scroll)),
      ),
    );
    await tester.pumpAndSettle();

    var effect = tester.widget<SoftScrollEdgeEffect>(
      find.byType(SoftScrollEdgeEffect),
    );
    expect(effect.strength, 0);
    expect(effect.tail, 0);
    expect(tester.getRect(find.byType(SoftScrollEdgeEffect)).bottom, 50);

    scroll.jumpTo(4);
    await tester.pump();
    effect = tester.widget<SoftScrollEdgeEffect>(
      find.byType(SoftScrollEdgeEffect),
    );
    expect(effect.strength, closeTo(0.15625, 1 / 64));
    expect(
      effect.tail,
      closeTo(
        NativeTopTabHeader.tailFor(
              tester.element(find.byType(NativeSingleBarEdge)),
            ) *
            effect.strength,
        1 / 64,
      ),
    );

    scroll.jumpTo(16);
    await tester.pump();
    effect = tester.widget<SoftScrollEdgeEffect>(
      find.byType(SoftScrollEdgeEffect),
    );
    expect(effect.strength, 1);
    expect(effect.tail, 24);
    expect(tester.getRect(find.byType(SoftScrollEdgeEffect)).bottom, 74);
  });

  testWidgets('negative overscroll leaves the native top edge clear', (
    tester,
  ) async {
    const size = Size(390, 844);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);

    await tester.pumpWidget(
      _host(
        native: true,
        size: size,
        child: NativeSingleBarEdge(child: _scroll(scroll)),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('edge-scroll'))),
    );
    await gesture.moveBy(const Offset(0, 100));
    await tester.pump();
    expect(scroll.position.pixels, lessThan(0));
    expect(
      tester
          .widget<SoftScrollEdgeEffect>(find.byType(SoftScrollEdgeEffect))
          .strength,
      0,
    );
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('non-native path returns the scroll child without edge layers', (
    tester,
  ) async {
    const size = Size(390, 844);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final child = _scroll(scroll);

    await tester.pumpWidget(
      _host(
        native: false,
        size: size,
        child: NativeSingleBarEdge(child: child),
      ),
    );

    expect(
      tester.widget(find.byKey(const ValueKey('edge-scroll'))),
      same(child),
    );
    expect(find.byType(ScrollEdgeProgressListener), findsNothing);
    expect(find.byType(SoftScrollEdgeEffect), findsNothing);
  });

  testWidgets('inset follows live view padding changes', (tester) async {
    const size = Size(390, 844);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final scroll = ScrollController(initialScrollOffset: 16);
    addTearDown(scroll.dispose);
    final child = NativeSingleBarEdge(child: _scroll(scroll));

    await tester.pumpWidget(
      _host(
        native: true,
        size: size,
        viewPadding: const EdgeInsets.only(top: 50),
        child: child,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SoftScrollEdgeEffect>(find.byType(SoftScrollEdgeEffect))
          .inset,
      50,
    );

    await tester.pumpWidget(
      _host(
        native: true,
        size: size,
        viewPadding: const EdgeInsets.only(top: 72),
        child: child,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SoftScrollEdgeEffect>(find.byType(SoftScrollEdgeEffect))
          .inset,
      72,
    );
  });

  for (final geometry
      in <({Size size, Size? windowSize, double gap, double tail})>[
        (size: const Size(390, 844), windowSize: null, gap: 8, tail: 24),
        (
          size: const Size(360, 844),
          windowSize: const Size(820, 1180),
          gap: 12,
          tail: 28,
        ),
      ]) {
    testWidgets(
      'uses shared content gap and tail in ${geometry.windowSize == null ? 'iPhone' : 'narrow iPad'} geometry',
      (tester) async {
        tester.view.physicalSize = geometry.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        final firstItem = GlobalKey();

        await tester.pumpWidget(
          _host(
            native: true,
            size: geometry.size,
            windowSize: geometry.windowSize,
            child: NativeSingleBarEdge(
              child: Builder(
                builder: (context) {
                  final inset = MediaQuery.viewPaddingOf(context).top;
                  final gap = NativeTopTabHeader.contentGapFor(context);
                  return CustomScrollView(
                    controller: scroll,
                    slivers: <Widget>[
                      SliverToBoxAdapter(child: SizedBox(height: inset)),
                      SliverToBoxAdapter(child: SizedBox(height: gap)),
                      SliverToBoxAdapter(
                        child: SizedBox(key: firstItem, height: 20),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(height: geometry.size.height * 2),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(NativeSingleBarEdge));
        expect(NativeTopTabHeader.contentGapFor(context), geometry.gap);
        expect(tester.getTopLeft(find.byKey(firstItem)).dy, 50 + geometry.gap);
        scroll.jumpTo(16);
        await tester.pump();
        expect(
          tester
              .widget<SoftScrollEdgeEffect>(find.byType(SoftScrollEdgeEffect))
              .tail,
          geometry.tail,
        );
      },
    );
  }
}

Widget _host({
  required bool native,
  required Size size,
  required Widget child,
  EdgeInsets viewPadding = const EdgeInsets.only(top: 50),
  Size? windowSize,
}) {
  NativeNavigationBridge.enabled.value = native;
  return CupertinoApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        padding: viewPadding,
        viewPadding: viewPadding,
      ),
      child: AdaptiveEnvironmentScope(
        snapshot: AdaptiveEnvironmentSnapshot(
          size: size,
          windowSize: windowSize,
        ),
        child: NativeNavigationScope(child: SizedBox.expand(child: child)),
      ),
    ),
  );
}

Widget _scroll(ScrollController controller) => CustomScrollView(
  key: const ValueKey('edge-scroll'),
  controller: controller,
  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
  slivers: <Widget>[
    SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, _) => const SizedBox(height: 60),
        childCount: 100,
      ),
    ),
  ],
);
