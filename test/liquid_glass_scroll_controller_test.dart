import 'dart:math' as math;

import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/liquid_glass_scroll_controller.dart';
import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiquidGlassInitialContentAnchor', () {
    testWidgets('initial anchor observes outer and active inner positions', (
      WidgetTester tester,
    ) async {
      final outer = ScrollController();
      final inner = ScrollController();
      final anchor = LiquidGlassInitialContentAnchor(
        scrollController: outer,
        devicePixelRatio: 3,
        additionalPositions: () => inner.positions,
      );
      addTearDown(anchor.dispose);
      addTearDown(outer.dispose);
      addTearDown(inner.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          home: Column(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  controller: outer,
                  child: const SizedBox(height: 1200),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: inner,
                  child: const SizedBox(height: 1200),
                ),
              ),
            ],
          ),
        ),
      );

      anchor.refresh();
      expect(anchor.isAtInitialPosition, isTrue);
      expect(anchor.distanceFromAnchor, 0);

      outer.jumpTo(80);
      await tester.pump();
      anchor.refresh();
      expect(anchor.isAtInitialPosition, isFalse);
      expect(anchor.distanceFromAnchor, 80);

      outer.jumpTo(0);
      inner.jumpTo(80);
      await tester.pump();
      anchor.refresh();
      expect(anchor.isAtInitialPosition, isFalse);
      expect(anchor.distanceFromAnchor, 80);

      inner.jumpTo(0);
      await tester.pump();
      anchor.refresh();
      expect(anchor.isAtInitialPosition, isTrue);
    });

    testWidgets('nested distance uses the larger position, never the sum', (
      WidgetTester tester,
    ) async {
      final outer = ScrollController();
      final inner = ScrollController();
      final anchor = LiquidGlassInitialContentAnchor(
        scrollController: outer,
        devicePixelRatio: 3,
        additionalPositions: () => inner.positions,
      );
      addTearDown(anchor.dispose);
      addTearDown(outer.dispose);
      addTearDown(inner.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          home: Column(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  controller: outer,
                  child: const SizedBox(height: 1200),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: inner,
                  child: const SizedBox(height: 1200),
                ),
              ),
            ],
          ),
        ),
      );

      outer.jumpTo(30);
      inner.jumpTo(40);
      await tester.pump();
      anchor.refresh();
      expect(anchor.distanceFromAnchor, 40);
    });

    testWidgets('anchor uses separate enter and exit thresholds', (
      WidgetTester tester,
    ) async {
      final outer = ScrollController();
      final anchor = LiquidGlassInitialContentAnchor(
        scrollController: outer,
        devicePixelRatio: 3,
      );
      addTearDown(anchor.dispose);
      addTearDown(outer.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          home: SingleChildScrollView(
            controller: outer,
            child: const SizedBox(height: 1200),
          ),
        ),
      );

      // At dpr 3 the entry threshold is max(1.5pt, 2px/3) = 1.5pt and the
      // exit band is max(6pt, 4 x entry) = 6pt.
      outer.jumpTo(0);
      await tester.pump();
      anchor.refresh();
      expect(anchor.isAtInitialPosition, isTrue);

      // While at the anchor the wider exit band applies.
      outer.jumpTo(6);
      await tester.pump();
      anchor.refresh();
      expect(anchor.isAtInitialPosition, isTrue);

      outer.jumpTo(6.1);
      await tester.pump();
      anchor.refresh();
      expect(anchor.isAtInitialPosition, isFalse);

      // Between the bands the state is sticky: away until the entry band.
      outer.jumpTo(5);
      await tester.pump();
      anchor.refresh();
      expect(anchor.isAtInitialPosition, isFalse);

      outer.jumpTo(1.6);
      await tester.pump();
      anchor.refresh();
      expect(anchor.isAtInitialPosition, isFalse);

      outer.jumpTo(1.5);
      await tester.pump();
      anchor.refresh();
      expect(anchor.isAtInitialPosition, isTrue);
    });

    testWidgets('top negative bounce keeps the current anchor state', (
      WidgetTester tester,
    ) async {
      final outer = ScrollController();
      final anchor = LiquidGlassInitialContentAnchor(
        scrollController: outer,
        devicePixelRatio: 3,
      );
      addTearDown(anchor.dispose);
      addTearDown(outer.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          home: SingleChildScrollView(
            controller: outer,
            child: const SizedBox(height: 1200),
          ),
        ),
      );

      outer.jumpTo(30);
      await tester.pump();
      anchor.refresh();
      expect(anchor.isAtInitialPosition, isFalse);

      // A rubber band above the top edge reports negative pixels. The state
      // must stay where it was instead of reading the bounce as "at anchor".
      outer.jumpTo(-8);
      await tester.pump();
      anchor.refresh();
      expect(anchor.isAtInitialPosition, isFalse);

      outer.jumpTo(0);
      await tester.pump();
      anchor.refresh();
      expect(anchor.isAtInitialPosition, isTrue);

      outer.jumpTo(-3);
      await tester.pump();
      anchor.refresh();
      expect(anchor.isAtInitialPosition, isTrue);
    });

    testWidgets('initial reset animates to the scroll controller minimum', (
      WidgetTester tester,
    ) async {
      final outer = ScrollController();
      final anchor = LiquidGlassInitialContentAnchor(
        scrollController: outer,
        devicePixelRatio: 3,
      );
      addTearDown(anchor.dispose);
      addTearDown(outer.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          home: SingleChildScrollView(
            controller: outer,
            child: const SizedBox(height: 1200),
          ),
        ),
      );

      outer.jumpTo(180);
      await tester.pump();
      anchor.refresh();
      expect(anchor.isAtInitialPosition, isFalse);

      final reset = anchor.animateToInitialAnchor(
        duration: const Duration(milliseconds: 1),
      );
      await tester.pumpAndSettle();
      await reset;

      expect(outer.offset, outer.position.minScrollExtent);
      expect(anchor.isAtInitialPosition, isTrue);
    });

    testWidgets('nested reset returns to the expanded header content anchor', (
      WidgetTester tester,
    ) async {
      final outer = LiquidGlassScrollController();
      final nestedKey = GlobalKey<ExtendedNestedScrollViewState>();
      final anchor = LiquidGlassInitialContentAnchor(
        scrollController: outer,
        devicePixelRatio: 3,
        additionalPositions: () =>
            nestedKey.currentState?.innerPositions ?? const <ScrollPosition>[],
      );
      addTearDown(anchor.dispose);
      addTearDown(outer.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          home: ExtendedNestedScrollView(
            key: nestedKey,
            controller: outer,
            onlyOneScrollInBody: true,
            headerSliverBuilder: (context, innerBoxIsScrolled) => <Widget>[
              const SliverToBoxAdapter(
                child: SizedBox(height: 180, key: ValueKey('initial-spacer')),
              ),
            ],
            body: CustomScrollView(
              slivers: <Widget>[
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => SizedBox(
                      key: ValueKey('content-$index'),
                      height: 100,
                      child: Text('Content $index'),
                    ),
                    childCount: 40,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(nestedKey.currentState?.innerPositions, isNotEmpty);

      final scroll = outer.animateTo(
        320,
        duration: const Duration(milliseconds: 1),
        curve: Curves.linear,
      );
      await tester.pumpAndSettle();
      await scroll;
      anchor.refresh();
      expect(anchor.isAtInitialPosition, isFalse);

      final reset = anchor.animateToInitialAnchor(
        duration: const Duration(milliseconds: 1),
      );
      await tester.pumpAndSettle();
      await reset;

      expect(outer.position.pixels, outer.position.minScrollExtent);
      for (final position in nestedKey.currentState!.innerPositions) {
        expect(position.pixels, position.minScrollExtent);
      }
      expect(anchor.isAtInitialPosition, isTrue);
    });
  });

  group('LiquidGlassTopStateCoordinator', () {
    FixedScrollMetrics fixedMetrics(double pixels) => FixedScrollMetrics(
          minScrollExtent: 0,
          maxScrollExtent: 1200,
          pixels: pixels,
          viewportDimension: 600,
          devicePixelRatio: 3,
          axisDirection: AxisDirection.down,
        );

    Future<BuildContext> pumpNotificationHost(
      WidgetTester tester,
      LiquidGlassTopStateCoordinator coordinator,
      ScrollController outer,
    ) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: NotificationListener<ScrollNotification>(
            onNotification: coordinator.handleScrollNotification,
            child: SingleChildScrollView(
              controller: outer,
              child: const SizedBox(height: 1200),
            ),
          ),
        ),
      );
      return tester.element(find.byType(SingleChildScrollView));
    }

    Future<
        (
          LiquidGlassTopStateCoordinator,
          LiquidGlassBarMotion,
          ScrollController,
          ScrollController,
          ValueNotifier<double?>
        )> build(WidgetTester tester) async {
      final motion = LiquidGlassBarMotion();
      final outer = ScrollController();
      final inner = ScrollController();
      final firstCardTop = ValueNotifier<double?>(200.0);
      final coordinator = LiquidGlassTopStateCoordinator(
        scrollController: outer,
        devicePixelRatio: 3,
        additionalPositions: () => inner.positions,
        firstCardTopProvider: () => firstCardTop.value,
      );
      coordinator.attachBarMotion(motion);
      addTearDown(coordinator.dispose);
      addTearDown(motion.dispose);
      addTearDown(outer.dispose);
      addTearDown(inner.dispose);
      addTearDown(firstCardTop.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          home: Column(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  controller: outer,
                  child: const SizedBox(height: 1200),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: inner,
                  child: const SizedBox(height: 1200),
                ),
              ),
            ],
          ),
        ),
      );
      return (coordinator, motion, outer, inner, firstCardTop);
    }

    testWidgets(
        'bar fade follows effective travel in both directions across 48pt', (
      WidgetTester tester,
    ) async {
      final (coordinator, motion, outer, _, _) = await build(tester);
      coordinator.setBarFadeEnabled(true);

      coordinator.refresh();
      expect(coordinator.barFadeProgress.value, 0.0);
      expect(motion.value, 0.0);
      expect(motion.isTopBarVisible, isTrue);

      // Twelve points consume one quarter of the shared fade.
      outer.jumpTo(12);
      await tester.pump();
      coordinator.refresh();
      expect(coordinator.barFadeProgress.value, 0.25);

      outer.jumpTo(24);
      await tester.pump();
      coordinator.refresh();
      expect(coordinator.barFadeProgress.value, closeTo(0.5, 0.001));

      outer.jumpTo(48);
      await tester.pump();
      coordinator.refresh();
      expect(coordinator.barFadeProgress.value, 1.0);
      expect(motion.isTopBarVisible, isFalse);

      // Four points of reverse jitter stay inside the debounce band: the
      // hidden rail does not flash back.
      outer.jumpTo(44);
      await tester.pump();
      coordinator.refresh();
      expect(coordinator.barFadeProgress.value, 1.0);
      expect(motion.isTopBarVisible, isFalse);

      // Crossing the band counts only the distance past its 8pt: 4pt banked
      // plus 12pt now leaves 8pt of excess reveal travel.
      outer.jumpTo(32);
      await tester.pump();
      coordinator.refresh();
      expect(coordinator.barFadeProgress.value, closeTo(1 - 8 / 48, 0.001));
      expect(motion.isTopBarVisible, isTrue);

      // The turned-around direction keeps revealing along the same progress.
      outer.jumpTo(8);
      await tester.pump();
      coordinator.refresh();
      expect(coordinator.barFadeProgress.value, closeTo(1 - 32 / 48, 0.001));

      // Back at the very top the fade and the motion memory clear.
      outer.jumpTo(0);
      await tester.pump();
      coordinator.refresh();
      expect(coordinator.barFadeProgress.value, 0.0);
      expect(motion.isTopBarVisible, isTrue);
    });

    testWidgets('first up-scroll from the list top never waits', (
      WidgetTester tester,
    ) async {
      final (coordinator, _, outer, _, _) = await build(tester);
      coordinator.setBarFadeEnabled(true);

      outer.jumpTo(120);
      await tester.pump();
      coordinator.refresh();
      expect(coordinator.barFadeProgress.value, 1.0);

      outer.jumpTo(0);
      await tester.pump();
      coordinator.refresh();
      expect(coordinator.barFadeProgress.value, 0.0);

      // The previous gesture ended in the reveal direction, but returning to
      // the top cleared the motion memory: the first hiding travel applies
      // immediately instead of filling another debounce band first.
      outer.jumpTo(12);
      await tester.pump();
      coordinator.refresh();
      expect(coordinator.barFadeProgress.value, 0.25);
    });

    testWidgets('a finished gesture restarts the reverse budget', (
      WidgetTester tester,
    ) async {
      final (coordinator, motion, outer, _, _) = await build(tester);
      coordinator.setBarFadeEnabled(true);
      final context = await pumpNotificationHost(tester, coordinator, outer);
      // The re-pumped tree swaps the ScrollPosition; one refresh consumes
      // the swap as a baseline before the gesture travel below.
      coordinator.refresh();

      outer.jumpTo(48);
      await tester.pump();
      coordinator.refresh();
      expect(coordinator.barFadeProgress.value, 1.0);

      // Two separate short reverse gestures each stay under the band because
      // every scroll end clears the banked distance.
      for (var i = 0; i < 2; i++) {
        outer.jumpTo(44.0 - 4.0 * i);
        await tester.pump();
        coordinator.handleScrollNotification(ScrollEndNotification(
          metrics: fixedMetrics(outer.offset),
          context: context,
        ));
        coordinator.refresh();
        expect(coordinator.barFadeProgress.value, 1.0,
            reason: 'gesture $i must not reveal the rail');
      }
      expect(motion.isTopBarVisible, isFalse);

      // One sustained reverse gesture past the band reveals continuously:
      // 16pt of travel spends the 8pt band and applies the 8pt excess.
      outer.jumpTo(24);
      await tester.pump();
      coordinator.refresh();
      expect(coordinator.barFadeProgress.value, closeTo(1 - 8 / 48, 0.001));
      expect(motion.isTopBarVisible, isTrue);
    });

    testWidgets('an active page switch clears the reverse budget', (
      WidgetTester tester,
    ) async {
      final motion = LiquidGlassBarMotion();
      final outer = ScrollController();
      final innerA = ScrollController();
      final innerB = ScrollController(initialScrollOffset: 400);
      var active = innerA;
      final coordinator = LiquidGlassTopStateCoordinator(
        scrollController: outer,
        devicePixelRatio: 3,
        additionalPositions: () => active.positions,
      );
      coordinator.attachBarMotion(motion);
      addTearDown(coordinator.dispose);
      addTearDown(motion.dispose);
      addTearDown(outer.dispose);
      addTearDown(innerA.dispose);
      addTearDown(innerB.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          home: Column(
            children: <Widget>[
              for (final controller in <ScrollController>[outer, innerA, innerB])
                Expanded(
                  child: SingleChildScrollView(
                    controller: controller,
                    child: const SizedBox(height: 1200),
                  ),
                ),
            ],
          ),
        ),
      );
      coordinator.setBarFadeEnabled(true);

      outer.jumpTo(0);
      innerA.jumpTo(48);
      await tester.pump();
      coordinator.refresh();
      expect(coordinator.barFadeProgress.value, 1.0);

      // A 4pt counter-jitter banks without turning the fade.
      innerA.jumpTo(44);
      await tester.pump();
      coordinator.refresh();
      expect(coordinator.barFadeProgress.value, 1.0);

      // Switching the active page rebases and drops the banked jitter.
      active = innerB;
      await tester.pump();
      coordinator.refresh();
      expect(coordinator.barFadeProgress.value, 1.0);

      // The next reveal applies fully instead of paying the band again.
      innerB.jumpTo(388);
      await tester.pump();
      coordinator.refresh();
      expect(coordinator.barFadeProgress.value, closeTo(1 - 12 / 48, 0.001));
    });

    testWidgets(
        'bar fade follows the mask while the first card is inside the top band',
        (WidgetTester tester) async {
      final (coordinator, _, outer, _, firstCardTop) = await build(tester);
      coordinator.updateLayout(
        devicePixelRatio: 3,
        topBarExtent: 200,
        safeTop: 50,
      );
      coordinator.setBarFadeEnabled(true);

      // The card rides the scroll one-to-one: entering and leaving the band
      // between safeTop and the expanded rail must never jump the progress.
      final cases = <(double, double)>[
        (0, 200),
        (12, 188),
        (24, 176),
        (60, 140),
        (120, 80),
        (149, 51),
        (151, 49),
        (240, 0),
      ];
      double? previous;
      for (final (offset, card) in cases) {
        outer.jumpTo(offset);
        firstCardTop.value = card;
        await tester.pump();
        coordinator.refresh();
        final direction = (offset / 48).clamp(0.0, 1.0);
        final mask = ((card - 50) / 150).clamp(0.0, 1.0);
        expect(
          coordinator.barFadeProgress.value,
          closeTo(math.min(direction, 1 - mask), 0.001),
          reason: 'offset $offset card $card',
        );
        expect(
          coordinator.solidMaskProgress.value,
          closeTo(mask, 0.001),
          reason: 'offset $offset card $card',
        );
        if (previous != null) {
          expect(
            coordinator.barFadeProgress.value - previous,
            greaterThanOrEqualTo(-0.001),
            reason: 'progress must not jump at offset $offset',
          );
        }
        previous = coordinator.barFadeProgress.value;
      }
    });

    testWidgets('bar fade combines effective outer and active inner travel', (
      WidgetTester tester,
    ) async {
      final (coordinator, _, outer, inner, _) = await build(tester);
      coordinator.setBarFadeEnabled(true);

      outer.jumpTo(0);
      inner.jumpTo(36);
      await tester.pump();
      coordinator.refresh();
      expect(coordinator.barFadeProgress.value, closeTo(0.75, 0.001));
    });

    testWidgets('disabled bar fade keeps the top bar fully visible', (
      WidgetTester tester,
    ) async {
      final (coordinator, motion, outer, _, _) = await build(tester);
      coordinator.setBarFadeEnabled(true);
      outer.jumpTo(120);
      await tester.pump();
      coordinator.refresh();
      expect(coordinator.barFadeProgress.value, 1.0);

      coordinator.setBarFadeEnabled(false);
      expect(coordinator.barFadeProgress.value, 0.0);
      expect(motion.value, 0.0);
      expect(motion.isTopBarVisible, isTrue);
      expect(coordinator.isAtInitialPosition.value, isFalse);
    });

    testWidgets('solid mask follows the first card between safe top and rail', (
      WidgetTester tester,
    ) async {
      final (coordinator, _, _, _, firstCardTop) = await build(tester);
      coordinator.updateLayout(
        devicePixelRatio: 3,
        topBarExtent: 200,
        safeTop: 50,
      );

      expect(coordinator.solidMaskProgress.value, 1.0);

      firstCardTop.value = 50;
      coordinator.refresh();
      expect(coordinator.solidMaskProgress.value, 0.0);

      firstCardTop.value = 125;
      coordinator.refresh();
      expect(coordinator.solidMaskProgress.value, 0.5);

      firstCardTop.value = 200;
      coordinator.refresh();
      expect(coordinator.solidMaskProgress.value, 1.0);

      firstCardTop.value = 125;
      coordinator.refresh();
      expect(coordinator.solidMaskProgress.value, 0.5);

      firstCardTop.value = 49;
      coordinator.refresh();
      expect(coordinator.solidMaskProgress.value, 0.0);
    });

    testWidgets('missing first card retracts the mask without a distance gate',
        (WidgetTester tester) async {
      final (coordinator, _, outer, inner, firstCardTop) = await build(tester);
      coordinator.updateLayout(
          devicePixelRatio: 3, topBarExtent: 200, safeTop: 50);
      firstCardTop.value = 125;
      coordinator.refresh();
      expect(coordinator.solidMaskProgress.value, 0.5);
      outer.jumpTo(180);
      inner.jumpTo(180);
      await tester.pump();
      firstCardTop.value = null;
      coordinator.refresh();
      expect(coordinator.solidMaskProgress.value, 0);
      firstCardTop.value = 125;
      coordinator.refresh();
      expect(coordinator.solidMaskProgress.value, 0.5);
    });

    testWidgets('top bounce keeps anchor hysteresis and clamps mask to card', (
      WidgetTester tester,
    ) async {
      final (coordinator, _, outer, _, firstCardTop) = await build(tester);
      coordinator.updateLayout(
        devicePixelRatio: 3,
        topBarExtent: 200,
        safeTop: 50,
      );

      outer.jumpTo(40);
      await tester.pump();
      coordinator.refresh();
      firstCardTop.value = 80;
      coordinator.refresh();
      expect(coordinator.solidMaskProgress.value, closeTo(0.2, 0.001));

      outer.jumpTo(-5);
      await tester.pump();
      firstCardTop.value = 205;
      coordinator.refresh();
      expect(coordinator.isAtInitialPosition.value, isFalse);
      expect(coordinator.solidMaskProgress.value, 1.0);
    });

    testWidgets('coordinated reset restores anchor, bar and solid mask', (
      WidgetTester tester,
    ) async {
      final (coordinator, motion, outer, _, firstCardTop) = await build(tester);
      coordinator.updateLayout(
        devicePixelRatio: 3,
        topBarExtent: 200,
        safeTop: 50,
      );
      coordinator.setBarFadeEnabled(true);

      // The card rides the scroll: at 200pt of travel it has left the band,
      // so the direction fade and the mask both end fully retracted.
      outer.jumpTo(200);
      firstCardTop.value = 0;
      await tester.pump();
      coordinator.refresh();
      expect(coordinator.barFadeProgress.value, 1.0);
      expect(coordinator.solidMaskProgress.value, 0.0);

      final reset = coordinator.resetToInitialAnchor(
        duration: const Duration(milliseconds: 1),
      );
      await tester.pumpAndSettle();
      await reset;
      firstCardTop.value = 200;
      coordinator.refresh();

      expect(outer.offset, outer.position.minScrollExtent);
      expect(coordinator.isAtInitialPosition.value, isTrue);
      expect(coordinator.barFadeProgress.value, 0.0);
      expect(motion.value, 0.0);
      expect(motion.isTopBarVisible, isTrue);
      expect(coordinator.solidMaskProgress.value, 1.0);
    });

    testWidgets('scroll notifications are the single refresh entry', (
      WidgetTester tester,
    ) async {
      final (coordinator, motion, outer, _, _) = await build(tester);
      coordinator.setBarFadeEnabled(true);

      await tester.pumpWidget(
        CupertinoApp(
          home: NotificationListener<ScrollNotification>(
            onNotification: coordinator.handleScrollNotification,
            child: SingleChildScrollView(
              controller: outer,
              child: const SizedBox(height: 1200),
            ),
          ),
        ),
      );

      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -36));
      await tester.pumpAndSettle();

      // Touch slop consumes part of the gesture; use effective content travel
      // rather than pointer travel for the notification-driven fade.
      final double distance = coordinator.anchorDistance;
      expect(distance, greaterThan(0));
      expect(
        coordinator.barFadeProgress.value,
        closeTo((distance / 48).clamp(0, 1), 0.001),
      );
      expect(motion.value, coordinator.barFadeProgress.value);
    });
  });
}
