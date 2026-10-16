import 'dart:async';

import 'package:eros_fe/common/controller/tag_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/pages/tab/comm.dart';
import 'package:eros_fe/pages/tab/controller/group/custom_tabbar_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabview_controller.dart';
import 'package:eros_fe/widget/liquid_glass_scroll_controller.dart';
import 'package:eros_fe/widget/refresh.dart';
import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:keframe/keframe.dart';

void main() {
  late TabHomeController home;
  late _ListController list;
  late GlobalKey<_NestedPageState> pageKey;

  void reselectionTest(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        home.resetTabTapSequence();
      }
    });
  }

  setUp(() {
    Get.testMode = true;
    Get.put<LocaleService>(LocaleService());
    Get.put<EhSettingService>(_Settings());
    Get.put<TagController>(_Tag());
    home = Get.put<TabHomeController>(_Home());
    list = _ListController();
    Get.put<CustomTabbarController>(_Gallery(list));
    pageKey = GlobalKey<_NestedPageState>();
  });

  tearDown(() {
    Get.reset();
    tabPages.scrollControllerMap.clear();
  });

  Future<void> mount(WidgetTester tester,
      {bool glass = false, Widget? rows}) async {
    final page =
        _NestedPage(key: pageKey, controller: list, glass: glass, rows: rows);
    await tester.pumpWidget(
      CupertinoApp(
          home: rows == null
              ? page
              : Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                      width: 320, child: SizeCacheWidget(child: page)))),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollDeep(WidgetTester tester) async {
    await tester.drag(
        find.byKey(const ValueKey('nested-list')), const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(
        pageKey.currentState!.nested.currentState!.innerPositions.single.pixels,
        greaterThan(300));
  }

  reselectionTest(
      'standard nested reselect resets outer/inner without refreshing',
      (tester) async {
    await mount(tester);
    await scrollDeep(tester);
    await home.onTap(0, useLiquidGlass: false);
    await tester.pumpAndSettle();
    final page = pageKey.currentState!;
    expect(page.outer.offset, closeTo(0, 0.01));
    expect(page.nested.currentState!.innerPositions.single.pixels,
        closeTo(0, 0.01));
    expect(list.refreshes, 0);
  });

  reselectionTest(
      'repeat tap interrupts return animation and refreshes exactly once',
      (tester) async {
    await mount(tester);
    await scrollDeep(tester);
    await home.onTap(0, useLiquidGlass: false);
    await tester.pump(const Duration(milliseconds: 100));
    await home.onTap(0, useLiquidGlass: false);
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(list.refreshes, 1);
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    list.refreshComplete.complete();
    await tester.pumpAndSettle();
    expect(pageKey.currentState!.outer.offset, closeTo(0, 0.01));
  });

  reselectionTest(
      'title tap uses explicit outer controller and does not refresh',
      (tester) async {
    await mount(tester);
    await scrollDeep(tester);
    await tester.tap(find.byKey(const ValueKey('title-top')));
    await tester.pumpAndSettle();
    expect(pageKey.currentState!.outer.offset, closeTo(0, 0.01));
    expect(
        pageKey.currentState!.nested.currentState!.innerPositions.single.pixels,
        closeTo(0, 0.01));
    expect(list.refreshes, 0);
  });

  reselectionTest(
      'fast traditional refresh finishes at the actual nested-list origin',
      (tester) async {
    await mount(tester);
    await scrollDeep(tester);
    await home.onTap(0, useLiquidGlass: false);
    await tester.pump(const Duration(milliseconds: 100));
    list.refreshComplete.complete();
    await home.onTap(0, useLiquidGlass: false);
    await tester.pumpAndSettle();
    expect(list.refreshes, 1);
    expect(pageKey.currentState!.outer.offset, closeTo(0, 0.01));
    expect(
        pageKey.currentState!.nested.currentState!.innerPositions.single.pixels,
        closeTo(0, 0.01));
  });

  reselectionTest(
      'fast refresh with production sliver and deferred tall cards preserves origin',
      (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(834, 1210);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final revision = ValueNotifier<int>(0);
    addTearDown(revision.dispose);
    list.onReloaded = () => revision.value++;
    await mount(tester,
        rows: ValueListenableBuilder<int>(
          valueListenable: revision,
          builder: (context, generation, _) => FlutterSliverList(
            delegate: FlutterListViewDelegate(
              (context, index) => FrameSeparateWidget(
                index: index,
                placeHolder: const SizedBox(height: 200),
                child: SizedBox(
                    height: 372,
                    child: Text('Card $index revision $generation')),
              ),
              onItemKey: (index) => '$index',
              childCount: 60,
            ),
          ),
        ));
    await scrollDeep(tester);
    await home.onTap(0, useLiquidGlass: false);
    await tester.pump(const Duration(milliseconds: 100));
    list.refreshComplete.complete();
    await home.onTap(0, useLiquidGlass: false);
    await tester.pumpAndSettle();
    expect(list.refreshes, 1);
    expect(revision.value, 1);
    expect(pageKey.currentState!.outer.offset, closeTo(0, 0.01));
    expect(
        pageKey.currentState!.nested.currentState!.innerPositions.single.pixels,
        closeTo(0, 0.01));
  });

  reselectionTest('glass reselect restores anchor then calls refresh',
      (tester) async {
    await mount(tester, glass: true);
    await scrollDeep(tester);
    final action = home.onTap(0, useLiquidGlass: true);
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(pageKey.currentState!.outer.offset, closeTo(0, 0.01));
    expect(
        pageKey.currentState!.nested.currentState!.innerPositions.single.pixels,
        closeTo(0, 0.01));
    expect(list.refreshes, 1);
    list.refreshComplete.complete();
    await action;
    await tester.pumpAndSettle();
  });

  reselectionTest(
      'detaching the page prevents stale scroll callbacks and refreshes',
      (tester) async {
    await mount(tester);
    final target = list.tabScrollController!;
    await tester.pumpWidget(const CupertinoApp(home: SizedBox()));
    expect(target.canScrollToTop, isFalse);
    await home.onTap(0, useLiquidGlass: false);
    await home.onTap(0, useLiquidGlass: false);
    await target.scrollToTopAndRefresh();
    expect(list.refreshes, 0);
    expect(tester.takeException(), isNull);
  });

  reselectionTest(
      'detaching during glass return does not refresh a closed page',
      (tester) async {
    await mount(tester, glass: true);
    await scrollDeep(tester);
    final action = home.onTap(0, useLiquidGlass: true);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const CupertinoApp(home: SizedBox()));
    await tester.pump();
    await action;
    expect(list.refreshes, 0);
    expect(tester.takeException(), isNull);
  });
}

class _NestedPage extends StatefulWidget {
  const _NestedPage(
      {super.key, required this.controller, required this.glass, this.rows});
  final _ListController controller;
  final bool glass;
  final Widget? rows;
  @override
  State<_NestedPage> createState() => _NestedPageState();
}

class _NestedPageState extends State<_NestedPage> {
  final outer = ScrollController();
  final nested = GlobalKey<ExtendedNestedScrollViewState>();
  final tab = EhTabController();
  late final anchor = LiquidGlassInitialContentAnchor(
    scrollController: outer,
    devicePixelRatio: 1,
    additionalPositions: () => nested.currentState?.innerPositions ?? [],
  );

  Future<void> scrollToTop() async {
    if (widget.glass) {
      await anchor.animateToInitialAnchor();
    } else if (outer.hasClients) {
      await outer.animateTo(0,
          duration: const Duration(milliseconds: 500), curve: Curves.ease);
    }
  }

  @override
  void dispose() {
    tab.dispose();
    anchor.dispose();
    outer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        CupertinoButton(
          key: const ValueKey('title-top'),
          onPressed: scrollToTop,
          child: const Text('Title'),
        ),
        Expanded(
          child: ExtendedNestedScrollView(
            key: nested,
            controller: outer,
            floatHeaderSlivers: !widget.glass,
            onlyOneScrollInBody: true,
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            headerSliverBuilder: (context, _) => [
              SliverOverlapAbsorber(
                handle: ExtendedNestedScrollView.sliverOverlapAbsorberHandleFor(
                    context),
                sliver: SliverPersistentHeader(
                  floating: !widget.glass,
                  pinned: true,
                  delegate: _Header(),
                ),
              ),
            ],
            body: Builder(builder: (context) {
              widget.controller.initEhTabController(
                context: context,
                ehTabController: tab,
                scrollToInitialAnchor: scrollToTop,
              );
              return CustomScrollView(
                key: const ValueKey('nested-list'),
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  EhCupertinoSliverRefreshControl(
                      onRefresh: widget.controller.onRefresh),
                  SliverOverlapInjector(
                    handle:
                        ExtendedNestedScrollView.sliverOverlapAbsorberHandleFor(
                            context),
                  ),
                  widget.rows ??
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              SizedBox(height: 70, child: Text('Card $index')),
                          childCount: 60,
                        ),
                      ),
                ],
              );
            }),
          ),
        ),
      ]);
}

class _Header extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => 0;
  @override
  double get maxExtent => 100;
  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      const SizedBox.expand();
  @override
  bool shouldRebuild(_Header oldDelegate) => false;
}

class _Settings extends EhSettingService {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Home extends TabHomeController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Tag extends GetxController implements TagController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ListController extends TabViewController {
  int refreshes = 0;
  late final refreshComplete = Completer<void>();
  VoidCallback? onReloaded;
  @override
  Future<void> reloadData() async {
    refreshes++;
    await refreshComplete.future;
    onReloaded?.call();
  }
}

class _Gallery extends GetxController implements CustomTabbarController {
  _Gallery(this.controller);
  final TabViewController controller;
  @override
  EhTabController? get currentPageScrollController =>
      controller.tabScrollController;
  @override
  Future<void> reselectCurrentPage() async {
    await currentPageScrollController?.scrollToTopAndRefresh();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
