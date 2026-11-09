import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/adaptive/native_top_header.dart';
import 'package:eros_fe/widget/scroll_edge_effect.dart';
import 'package:eros_fe/widget/scroll_edge_progress.dart';
import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget header(
    double extent, {
    ValueNotifier<double>? progress,
    Size size = const Size(393, 852),
  }) =>
      CupertinoApp(
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: extent,
              child: NativeTopTabHeader(
                  topInset: 50,
                  railHeight: 44,
                  edgeProgress: progress,
                  child: const SizedBox.expand(key: ValueKey('rail'))),
            ),
          ),
        ),
      );

  double railOpacity(WidgetTester tester) => tester
      .widget<Opacity>(find.ancestor(
          of: find.byKey(const ValueKey('rail')),
          matching: find.byType(Opacity)))
      .opacity;

  testWidgets('resting rail is clear and the edge ends at the header',
      (tester) async {
    await tester.pumpWidget(header(94));
    expect(tester.getRect(find.byKey(const ValueKey('rail'))),
        const Rect.fromLTWH(0, 50, 800, 44));
    expect(railOpacity(tester), 1);
    final fade = tester.getRect(find.descendant(
        of: find.byType(NativeTopTabHeader),
        matching: find.byType(SoftScrollEdgeEffect)));
    expect(fade.top, 0);
    expect(fade.bottom, 94);
    expect(
      tester
          .widget<SoftScrollEdgeEffect>(find.byType(SoftScrollEdgeEffect))
          .strength,
      0,
    );
    expect(find.byType(BackdropFilter), findsNothing);
    final decoration = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(SoftScrollEdgeEffect),
        matching: find.byType(DecoratedBox),
      ),
    );
    final gradient =
        (decoration.decoration as BoxDecoration).gradient! as LinearGradient;
    expect(gradient.colors.every((color) => color.a == 0), isTrue);
  });

  for (final tablet in [false, true]) {
    testWidgets('scrolled edge has the approved tail, tablet=$tablet', (
      tester,
    ) async {
      final progress = ValueNotifier<double>(1);
      addTearDown(progress.dispose);
      await tester.pumpWidget(
        header(
          94,
          progress: progress,
          size: tablet ? const Size(1024, 1366) : const Size(393, 852),
        ),
      );
      expect(
        tester.getRect(find.byType(SoftScrollEdgeEffect)).bottom,
        94 + (tablet ? 28 : 24),
      );
      expect(
        tester
            .widget<SoftScrollEdgeEffect>(find.byType(SoftScrollEdgeEffect))
            .strength,
        1,
      );
      progress.value = 0.5;
      await tester.pump();
      expect(
        tester.getRect(find.byType(SoftScrollEdgeEffect)).bottom,
        94 + (tablet ? 14 : 12),
      );
      progress.value = 0;
      await tester.pump();
      expect(tester.getRect(find.byType(SoftScrollEdgeEffect)).bottom, 94);
      expect(find.byType(BackdropFilter), findsNothing);
    });
  }

  for (final width in [320.0, 400.0, 500.0]) {
    testWidgets('iPad native edge keeps its tokens in a $width pt pane', (
      tester,
    ) async {
      const size = Size(820, 1180);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final progress = ValueNotifier<double>(0);
      addTearDown(progress.dispose);
      await tester.pumpWidget(
        CupertinoApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: AdaptivePane(
                environment: const AdaptiveEnvironmentSnapshot(size: size),
                rect: Rect.fromLTWH(0, 0, width, size.height),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    height: 94,
                    child: NativeTopTabHeader(
                      topInset: 50,
                      railHeight: 44,
                      edgeProgress: progress,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final context = tester.element(find.byType(NativeTopTabHeader));
      expect(MediaQuery.sizeOf(context).width, width);
      expect(NativeTopTabHeader.contentGapFor(context), 12);
      expect(tester.getRect(find.byType(SoftScrollEdgeEffect)).bottom, 94);
      progress.value = 1;
      await tester.pump();
      expect(tester.getRect(find.byType(SoftScrollEdgeEffect)).bottom, 122);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('collapsed header keeps a soft tail below the status area', (
    tester,
  ) async {
    final progress = ValueNotifier<double>(1);
    addTearDown(progress.dispose);
    await tester.pumpWidget(header(50, progress: progress));
    final effect = tester.widget<SoftScrollEdgeEffect>(
      find.byType(SoftScrollEdgeEffect),
    );
    expect(effect.bars, 0);
    expect(effect.tail, 24);
    expect(tester.getRect(find.byType(SoftScrollEdgeEffect)).bottom, 74);
    final alphas = SoftEdgeCurve.light.sample(
      inset: 50,
      bars: 0,
      tail: 24,
      count: 200,
    );
    for (var i = 1; i < alphas.length; i++) {
      expect((alphas[i] - alphas[i - 1]).abs(), lessThan(0.03));
    }
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

  testWidgets('progress follows nested scrolling with and without collapsing', (
    tester,
  ) async {
    for (final collapsible in [false, true]) {
      final edge = ScrollEdgeProgressController();
      final pages = PageController();
      final outer = ScrollController();
      await tester.pumpWidget(
        _EdgePages(
          key: ValueKey(collapsible),
          edge: edge,
          pages: pages,
          outer: outer,
          collapsible: collapsible,
        ),
      );
      await tester.pumpAndSettle();
      expect(edge.value, 0);
      await tester.drag(
        find.byKey(const ValueKey('inner-0')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(edge.value, 1);
      expect(outer.offset, collapsible ? 44 : 0);
      if (collapsible) {
        // The outer offset alone still reveals the edge on a new inner page.
        pages.jumpToPage(1);
        await tester.pumpAndSettle();
        expect(edge.value, 1);
        outer.jumpTo(0);
        await tester.pumpAndSettle();
        expect(edge.value, 0);
      }
      await tester.pumpWidget(const SizedBox());
      edge.dispose();
      pages.dispose();
      outer.dispose();
    }
  });

  testWidgets('switching pages clears the edge and restores a scrolled page', (
    tester,
  ) async {
    final edge = ScrollEdgeProgressController();
    final pages = PageController();
    final outer = ScrollController();
    addTearDown(edge.dispose);
    addTearDown(pages.dispose);
    addTearDown(outer.dispose);
    await tester.pumpWidget(
      _EdgePages(edge: edge, pages: pages, outer: outer, collapsible: false),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('inner-0')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(edge.value, 1);
    pages.jumpToPage(1);
    await tester.pumpAndSettle();
    expect(edge.value, 0);
    expect(
      tester
          .widget<SoftScrollEdgeEffect>(find.byType(SoftScrollEdgeEffect))
          .tail,
      0,
    );
    pages.jumpToPage(0);
    await tester.pumpAndSettle();
    expect(edge.value, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('restored scroll position is sampled before a user scroll', (
    tester,
  ) async {
    final edge = ScrollEdgeProgressController();
    final scroll = ScrollController(initialScrollOffset: 100);
    addTearDown(edge.dispose);
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: ScrollEdgeProgressListener(
          controller: edge,
          child: ListView.builder(
            controller: scroll,
            itemCount: 100,
            itemBuilder: (_, index) =>
                SizedBox(height: 50, child: Text('$index')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(edge.value, 1);
    scroll.jumpTo(0);
    await tester.pump();
    expect(edge.value, 0);
    await tester.pumpWidget(const SizedBox());
  });

  test(
    'nested offsets use smoothstep, quantization and overscroll clearing',
    () {
      final edge = ScrollEdgeProgressController();
      addTearDown(edge.dispose);
      FixedScrollMetrics metrics(
        double offset, {
        AxisDirection axis = AxisDirection.down,
      }) =>
          FixedScrollMetrics(
            minScrollExtent: 0,
            maxScrollExtent: 1000,
            pixels: offset,
            viewportDimension: 600,
            axisDirection: axis,
            devicePixelRatio: 1,
          );
      edge.selectPage('a');
      edge.update(metrics(8));
      expect(edge.value, 0.5);
      edge.update(metrics(4), page: 'a');
      expect(edge.value, 0.5);
      edge.update(metrics(-1), page: 'a');
      expect(edge.value, 0);
      edge.update(metrics(0), page: 'a');
      edge.update(metrics(0));
      edge.update(metrics(16), page: 'a');
      expect(edge.value, 1);
      edge.update(metrics(0), page: 'b');
      expect(
        edge.value,
        1,
        reason: 'offstage metrics cannot replace the active page',
      );
      edge.selectPage('b');
      expect(edge.value, 0);
      edge.update(metrics(200, axis: AxisDirection.right));
      expect(edge.value, 0, reason: 'horizontal PageView scrolling is ignored');
      edge.selectPage('a');
      expect(edge.value, 1);
    },
  );
}

class _EdgePages extends StatefulWidget {
  const _EdgePages({
    super.key,
    required this.edge,
    required this.pages,
    required this.outer,
    required this.collapsible,
  });
  final ScrollEdgeProgressController edge;
  final PageController pages;
  final ScrollController outer;
  final bool collapsible;

  @override
  State<_EdgePages> createState() => _EdgePagesState();
}

class _EdgePagesState extends State<_EdgePages> {
  int selected = 0;

  @override
  Widget build(BuildContext context) => CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(393, 852)),
          child: ScrollEdgeProgressListener(
            controller: widget.edge,
            activePage: selected,
            child: ExtendedNestedScrollView(
              controller: widget.outer,
              onlyOneScrollInBody: true,
              floatHeaderSlivers: true,
              headerSliverBuilder: (context, _) => [
                SliverOverlapAbsorber(
                  handle:
                      ExtendedNestedScrollView.sliverOverlapAbsorberHandleFor(
                    context,
                  ),
                  sliver: SliverPersistentHeader(
                    pinned: true,
                    delegate: _EdgeHeader(widget.edge, widget.collapsible),
                  ),
                ),
              ],
              body: PageView(
                controller: widget.pages,
                onPageChanged: (page) {
                  widget.edge.selectPage(page);
                  setState(() => selected = page);
                },
                children: [
                  for (var page = 0; page < 2; page++)
                    _EdgeInnerPage(page: page, edge: widget.edge),
                ],
              ),
            ),
          ),
        ),
      );
}

class _EdgeHeader extends SliverPersistentHeaderDelegate {
  _EdgeHeader(this.edge, this.collapsible);
  final ScrollEdgeProgressController edge;
  final bool collapsible;
  @override
  double get minExtent => collapsible ? 50 : 94;
  @override
  double get maxExtent => 94;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) =>
      NativeTopTabHeader(
        topInset: 50,
        railHeight: 44,
        edgeProgress: edge,
        child: const SizedBox.expand(),
      );
  @override
  bool shouldRebuild(_EdgeHeader oldDelegate) => false;
}

class _EdgeInnerPage extends StatefulWidget {
  const _EdgeInnerPage({required this.page, required this.edge});
  final int page;
  final ScrollEdgeProgressController edge;
  @override
  State<_EdgeInnerPage> createState() => _EdgeInnerPageState();
}

class _EdgeInnerPageState extends State<_EdgeInnerPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScrollEdgeProgressListener(
      controller: widget.edge,
      page: widget.page,
      child: CustomScrollView(
        key: ValueKey('inner-${widget.page}'),
        slivers: [
          SliverOverlapInjector(
            handle: ExtendedNestedScrollView.sliverOverlapAbsorberHandleFor(
              context,
            ),
          ),
          SliverFixedExtentList(
            itemExtent: 60,
            delegate: SliverChildBuilderDelegate(
              (_, index) => Text('$index'),
              childCount: 100,
            ),
          ),
        ],
      ),
    );
  }
}
