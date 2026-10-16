import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:eros_fe/widget/liquid_glass_scroll_controller.dart';
import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

class _Header extends SliverPersistentHeaderDelegate {
  _Header(this.maxExtent);
  @override
  final double maxExtent;
  @override
  double get minExtent => 0;
  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      const SizedBox.expand();
  @override
  bool shouldRebuild(_Header oldDelegate) => oldDelegate.maxExtent != maxExtent;
}

Widget _page(
    ScrollController outer, GlobalKey<ExtendedNestedScrollViewState> nested,
    {required bool floating,
    bool waterfall = true,
    bool grid = false,
    LiquidGlassTopStateCoordinator? coordinator,
    GlobalKey? firstCard}) {
  final scroll = ExtendedNestedScrollView(
    key: nested,
    controller: outer,
    floatHeaderSlivers: floating,
    onlyOneScrollInBody: true,
    physics: const ClampingScrollPhysics(),
    headerSliverBuilder: (context, _) => [
      SliverOverlapAbsorber(
        handle:
            ExtendedNestedScrollView.sliverOverlapAbsorberHandleFor(context),
        sliver: SliverPersistentHeader(
          floating: floating,
          pinned: true,
          delegate: _Header(153),
        ),
      ),
    ],
    body: Builder(builder: (context) {
      final delegate = SliverChildBuilderDelegate((context, index) {
        return SizedBox(
          key: index == 0 ? firstCard : ValueKey('card-$index'),
          height: 130 + (index % 3) * 25,
          child: ColoredBox(
              color: index.isEven
                  ? CupertinoColors.activeBlue
                  : CupertinoColors.activeGreen,
              child: Text('Card $index')),
        );
      }, childCount: 90);
      return CustomScrollView(
        key: const ValueKey('inner-viewport'),
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverOverlapInjector(
              handle: ExtendedNestedScrollView.sliverOverlapAbsorberHandleFor(
                  context)),
          if (waterfall)
            SliverWaterfallFlow(
              gridDelegate:
                  const SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8),
              delegate: delegate,
            )
          else if (grid)
            SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, mainAxisExtent: 170, mainAxisSpacing: 8),
              delegate: delegate,
            )
          else
            SliverList(delegate: delegate),
        ],
      );
    }),
  );
  return CupertinoApp(
      home: NotificationListener<ScrollNotification>(
    onNotification: coordinator?.handleScrollNotification,
    child: scroll,
  ));
}

Future<void> _drag(WidgetTester tester, double dy) async {
  final gesture = await tester.startGesture(const Offset(350, 350));
  await gesture.moveBy(Offset(0, dy.sign * 20));
  await tester.pump(const Duration(milliseconds: 20));
  for (var i = 0; i < 6; i++) {
    await gesture.moveBy(Offset(0, dy / 6));
    await tester.pump(const Duration(milliseconds: 40));
  }
  // Stop before release so this tests the drag rather than a fling.
  await tester.pump(const Duration(milliseconds: 200));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'diagnostic: floating header creates empty space without any mask',
      (tester) async {
    final outer = ScrollController();
    final nested = GlobalKey<ExtendedNestedScrollViewState>();
    addTearDown(outer.dispose);
    await tester.pumpWidget(_page(outer, nested, floating: true));
    await _drag(tester, -500);
    final innerBefore = nested.currentState!.innerPositions.single.pixels;
    expect(innerBefore, greaterThan(200));
    expect(outer.offset, 153);
    await _drag(tester, 60);
    expect(outer.offset, lessThan(153));
    expect(nested.currentState!.innerPositions.single.pixels,
        closeTo(innerBefore, 0.01));
    expect(tester.getTopLeft(find.byKey(const ValueKey('inner-viewport'))).dy,
        greaterThan(0));
  });
  for (final mode in ['list', 'grid', 'waterfall']) {
    testWidgets(
        'deep return restores controls without opening space: mode=$mode',
        (tester) async {
      final outer = ScrollController();
      final nested = GlobalKey<ExtendedNestedScrollViewState>();
      final firstCard = GlobalKey();
      final coordinator = LiquidGlassTopStateCoordinator(
        scrollController: outer,
        additionalPositions: () => nested.currentState?.innerPositions ?? [],
        firstCardTopProvider: () => liquidGlassScreenTop(firstCard),
      );
      final motion = LiquidGlassBarMotion();
      coordinator.attachBarMotion(motion);
      coordinator.updateLayout(
          devicePixelRatio: 3, safeTop: 59, topBarExtent: 153);
      addTearDown(coordinator.dispose);
      addTearDown(motion.dispose);
      addTearDown(outer.dispose);
      await tester.pumpWidget(_page(outer, nested,
          floating: false,
          waterfall: mode == 'waterfall',
          grid: mode == 'grid',
          coordinator: coordinator,
          firstCard: firstCard));
      coordinator.setBarFadeEnabled(true);
      await _drag(tester, -700);
      expect(coordinator.barFadeProgress.value, 1);
      expect(coordinator.solidMaskProgress.value, 0);
      final innerBefore = nested.currentState!.innerPositions.single.pixels;
      await _drag(tester, 24);
      expect(coordinator.barFadeProgress.value, greaterThan(0));
      expect(coordinator.barFadeProgress.value, lessThan(1));
      expect(motion.value, coordinator.barFadeProgress.value);
      expect(outer.offset, 153);
      expect(nested.currentState!.innerPositions.single.pixels,
          lessThan(innerBefore));
      expect(tester.getTopLeft(find.byKey(const ValueKey('inner-viewport'))).dy,
          0);
      expect(coordinator.solidMaskProgress.value, 0);
      final stopped = motion.value;
      await tester.pump(const Duration(seconds: 1));
      expect(motion.value, stopped);
      await _drag(tester, 60);
      expect(motion.value, 0);
      expect(coordinator.solidMaskProgress.value, 0);
      await _drag(tester, -60);
      expect(motion.value, 1);
      // Return through the safe-area trigger using real gestures.
      for (var i = 0; i < 20 && coordinator.anchorDistance > 0; i++) {
        await _drag(tester, 40);
        final c = liquidGlassScreenTop(firstCard);
        if (c != null) {
          final expected = ((c - 59) / 94).clamp(0, 1);
          expect(coordinator.solidMaskProgress.value, closeTo(expected, 0.001));
        }
      }
      expect(outer.offset, 0);
      expect(coordinator.solidMaskProgress.value, 1);
      expect(motion.value, 0);
      expect(liquidGlassScreenTop(firstCard), closeTo(153, 0.01));
      expect(tester.takeException(), isNull);
    });
  }

  for (final layout in LiquidGlassTopBarLayout.values) {
    for (final reduceMotion in [false, true]) {
      testWidgets(
          'top fades while bottom remains visible: $layout reduce=$reduceMotion',
          (tester) async {
        final motion = LiquidGlassBarMotion();
        addTearDown(motion.dispose);
        await tester.pumpWidget(CupertinoApp(
            home: MediaQuery(
          data: MediaQueryData(
              size: const Size(800, 600), disableAnimations: reduceMotion),
          child: LiquidGlassBarMotionScope(
              motion: motion,
              child: Column(children: [
                LiquidGlassBarMotionBuilder(
                    enabled: true,
                    builder: (context, progress) => LiquidGlassRail(
                            title: 'Gallery',
                            safeTop: 59,
                            layout: layout,
                            selectedIndex: 0,
                            fadeProgress: progress,
                            leading: LiquidGlassRailAction(
                                icon: CupertinoIcons.clock,
                                label: 'History',
                                onPressed: () {}),
                            categories: [
                              LiquidGlassRailCategory(
                                  title: 'Category', onTap: () {})
                            ])),
                const Spacer(),
                LiquidGlassTabBar(items: const [
                  BottomNavigationBarItem(
                      icon: Icon(CupertinoIcons.home), label: 'Home'),
                  BottomNavigationBarItem(
                      icon: Icon(CupertinoIcons.heart), label: 'Favorites'),
                ], onTap: (_) {}),
              ])),
        )));
        for (final progress in [0.0, 0.25, 0.5, 0.75, 1.0]) {
          motion.value = progress;
          await tester.pump();
          final expected =
              reduceMotion ? (progress >= 0.72 ? 0.0 : 1.0) : 1 - progress;
          expect(find.text('Home'), findsOneWidget);
          expect(find.text('Favorites'), findsOneWidget);
          if (expected == 0) {
            expect(find.text('Category'), findsNothing);
          } else {
            final top = tester.widgetList<Opacity>(find.descendant(
                of: find.byType(LiquidGlassRail),
                matching: find.byType(Opacity)));
            expect(top, isNotEmpty);
            expect(top.map((o) => o.opacity), everyElement(expected));
          }
        }
      });
    }
  }
  testWidgets(
      'safe-area base stays solid through the safe area at every mask progress',
      (tester) async {
    final progress = ValueNotifier<double>(0);
    addTearDown(progress.dispose);
    await tester.pumpWidget(CupertinoApp(
      theme: const CupertinoThemeData(brightness: Brightness.light),
      home: Stack(children: [
        const Positioned.fill(
            child: ColoredBox(color: CupertinoColors.systemGrey)),
        const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LiquidGlassSafeAreaBase(
                safeTop: 59, layout: LiquidGlassTopBarLayout.twoRow)),
        LiquidGlassSolidMask(
            progressListenable: progress, safeTop: 59, height: 153),
        const LiquidGlassTopScrim(
            safeTop: 59, layout: LiquidGlassTopBarLayout.twoRow),
      ]),
    ));
    // The themed base sits below the scroll content in the page Stack. It is
    // permanent: it exists before the first reveal and at every progress,
    // solid through the safe area and only fading below it toward the shared
    // fade end (the two-row rail bottom here), so the safe area can never
    // flash the gray page background. The scrim is still one gradient from
    // screen y=0 above it.
    final status = find.byKey(const ValueKey('liquid-glass-safe-area-base'));
    expect(status, findsOneWidget);
    expect(tester.getRect(status).bottom, 153);
    final scrim = find.byKey(const ValueKey('liquid-glass-top-scrim'));
    expect(tester.getTopLeft(scrim).dy, 0);
    final baseGradient = (tester.widget<DecoratedBox>(status).decoration
            as BoxDecoration)
        .gradient! as LinearGradient;
    expect(baseGradient.colors.first.toARGB32(), 0xFFFFFFFF);
    expect(baseGradient.colors.last.a, 0.0);
    for (final value in [0.0, 0.01, 0.25, 0.5, 0.75, 1.0]) {
      progress.value = value;
      await tester.pump();
      expect(status, findsOneWidget);
      expect(find.ancestor(of: status, matching: find.byType(Opacity)),
          findsNothing);
      final mask = find.byKey(const ValueKey('liquid-glass-solid-mask'));
      if (value == 0.0) {
        expect(mask, findsNothing);
      } else {
        expect(tester.widget<ColoredBox>(mask).color.toARGB32(), 0xFFFFFFFF);
        expect(tester.getRect(mask).bottom, closeTo(59 + 94 * value, 0.001));
      }
    }
  });
  testWidgets('combined travel counts once and active-page changes rebase',
      (tester) async {
    final outer = ScrollController();
    final innerA = ScrollController();
    final innerB = ScrollController(initialScrollOffset: 400);
    var active = innerA;
    final state = LiquidGlassTopStateCoordinator(
        scrollController: outer, additionalPositions: () => active.positions);
    for (final c in [outer, innerA, innerB]) {
      addTearDown(c.dispose);
    }
    addTearDown(state.dispose);
    await tester.pumpWidget(CupertinoApp(
        home: Column(children: [
      for (final c in [outer, innerA, innerB])
        Expanded(
            child: SingleChildScrollView(
                controller: c, child: const SizedBox(height: 1600))),
    ])));
    state.setBarFadeEnabled(true);
    outer.jumpTo(12);
    innerA.jumpTo(12);
    state.refresh();
    expect(state.barFadeProgress.value, 0.5);
    state.refresh();
    state.refresh();
    expect(state.barFadeProgress.value, 0.5);
    active = innerB;
    state.refresh();
    expect(state.barFadeProgress.value, 0.5);
    innerB.jumpTo(388);
    state.refresh();
    expect(state.barFadeProgress.value, 0.25);
    state.updateLayout(devicePixelRatio: 3, topBarExtent: 180, safeTop: 59);
    outer.jumpTo(25);
    state.refresh();
    expect(state.barFadeProgress.value, 0.25);
  });
}
