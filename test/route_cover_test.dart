import 'package:eros_fe/adaptive/route_cover.dart';
import 'package:eros_fe/route/eh_observer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  late EhNavigatorObserver observer;
  final navigator = GlobalKey<NavigatorState>();

  Future<void> mount(WidgetTester tester) async {
    observer = EhNavigatorObserver();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(CupertinoApp(
      navigatorKey: navigator,
      navigatorObservers: [observer],
      home: CoveredPage(
        observer: observer,
        child: const ColoredBox(
          key: ValueKey('list'),
          color: CupertinoColors.white,
        ),
      ),
    ));
  }

  void push() => navigator.currentState!.push(CupertinoPageRoute<void>(
        builder: (_) => CoveredPage(
          observer: observer,
          child: const ColoredBox(color: CupertinoColors.black),
        ),
      ));

  Rect? listVisible(WidgetTester tester) =>
      RouteCoverClip.debugVisibleRectOf(tester.renderObject(find.ancestor(
          of: find.byKey(const ValueKey('list')),
          matching: find.byType(RouteCoverClip))));

  testWidgets('a page sliding in leaves only the strip it has not reached',
      (tester) async {
    await mount(tester);
    expect(listVisible(tester), isNull);

    push();
    // The new page's first frame is offstage at its final place.
    await tester.pump();
    expect(listVisible(tester), isNull);
    await tester.pump(const Duration(milliseconds: 120));
    final visible = listVisible(tester)!;
    expect(visible.left, 0);
    expect(visible.right, greaterThan(0));
    expect(visible.right, lessThan(400));
    await tester.pumpAndSettle();
  });

  testWidgets('popping uncovers the page again once the top page leaves',
      (tester) async {
    await mount(tester);
    push();
    await tester.pumpAndSettle();

    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final visible = listVisible(tester)!;
    expect(visible.right, greaterThan(0));
    expect(visible.right, lessThan(400));

    await tester.pumpAndSettle();
    expect(listVisible(tester), isNull);
  });

  testWidgets('a sliding page that still covers the page whole hides it',
      (tester) async {
    // Like the app's tab pages: Get routes without the parallax shift, so
    // the page below stays where the top page starts to slide from.
    Get.testMode = true;
    addTearDown(Get.reset);
    observer = EhNavigatorObserver();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetCupertinoApp(
      navigatorKey: navigator,
      navigatorObservers: [observer],
      home: CoveredPage(
        observer: observer,
        child: const ColoredBox(
          key: ValueKey('list'),
          color: CupertinoColors.white,
        ),
      ),
    ));
    navigator.currentState!.push(GetPageRoute<void>(
      page: () => CoveredPage(
        observer: observer,
        child: const ColoredBox(color: CupertinoColors.black),
      ),
      transition: Transition.cupertino,
      showCupertinoParallax: false,
    ));
    await tester.pumpAndSettle();

    // The first frame of a pop has the page below back on stage while the
    // top page has not moved yet; its native views must not show through.
    navigator.currentState!.pop();
    await tester.pump();
    expect(listVisible(tester), Rect.zero);
    await tester.pumpAndSettle();
    expect(listVisible(tester), isNull);
  });

  double listTop(WidgetTester tester) => MediaQuery.paddingOf(
          tester.element(find.byKey(const ValueKey('list'), skipOffstage: false)))
      .top;

  testWidgets('a covered page keeps its top inset while the bars change',
      (tester) async {
    tester.view.padding = const FakeViewPadding(top: 60);
    addTearDown(tester.view.resetPadding);
    await mount(tester);
    expect(listTop(tester), 60);

    push();
    await tester.pump();
    // The native bar hides for the page sliding in.
    tester.view.padding = const FakeViewPadding(top: 20);
    await tester.pump(const Duration(milliseconds: 120));
    expect(listTop(tester), 60);
    await tester.pumpAndSettle();

    // Back on top, the list follows the bar again.
    tester.view.padding = const FakeViewPadding(top: 60);
    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(listTop(tester), 60);
    await tester.pumpAndSettle();
    tester.view.padding = const FakeViewPadding(top: 30);
    await tester.pump();
    expect(listTop(tester), 30);
  });

  testWidgets('a covered page takes new insets after a rotation',
      (tester) async {
    tester.view.padding = const FakeViewPadding(top: 60);
    addTearDown(tester.view.resetPadding);
    await mount(tester);
    push();
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(800, 400);
    tester.view.padding = const FakeViewPadding(top: 10);
    await tester.pump();
    expect(listTop(tester), 10);
  });

  testWidgets('a page fading in place leaves the page below unclipped',
      (tester) async {
    await mount(tester);
    navigator.currentState!.push(PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => CoveredPage(
        observer: observer,
        child: const ColoredBox(color: CupertinoColors.black),
      ),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(listVisible(tester), isNull);
    await tester.pumpAndSettle();
  });
}
