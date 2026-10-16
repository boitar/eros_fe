import 'package:eros_fe/widget/refresh.dart';
import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

/// 复现画廊/收藏子页在 ExtendedNestedScrollView 中的内层列表结构。
///
/// CupertinoSliverRefreshControl 依赖顶部下拉越界时 viewport 给出负 overlap
/// 才会激活；刷新控件位于 SliverOverlapInjector 之前是下拉手势能到达刷新
/// 控件的关键（见 custom_sub_page.dart / favorite_sub_page.dart 注释）。
Widget buildNestedBody({
  required Future<void> Function() onRefresh,
  required bool refreshControlBeforeInjector,
}) {
  return ExtendedNestedScrollView(
    floatHeaderSlivers: true,
    onlyOneScrollInBody: true,
    physics: const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    ),
    headerSliverBuilder: (context, innerBoxIsScrolled) {
      return [
        SliverOverlapAbsorber(
          handle: ExtendedNestedScrollView.sliverOverlapAbsorberHandleFor(
            context,
          ),
          sliver: SliverPersistentHeader(
            floating: true,
            pinned: true,
            delegate: _TestHeaderDelegate(),
          ),
        ),
      ];
    },
    body: Builder(
      builder: (context) {
        final refreshControl = SliverSafeArea(
          top: false,
          bottom: false,
          sliver: EhCupertinoSliverRefreshControl(onRefresh: onRefresh),
        );
        final injector = SliverOverlapInjector(
          handle: ExtendedNestedScrollView.sliverOverlapAbsorberHandleFor(
            context,
          ),
        );
        return CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            if (refreshControlBeforeInjector) ...[
              refreshControl,
              injector,
            ] else ...[
              injector,
              refreshControl,
            ],
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => SizedBox(
                  height: 40,
                  child: Center(child: Text('item $index')),
                ),
                childCount: 40,
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _TestHeaderDelegate extends SliverPersistentHeaderDelegate {
  @override
  double get maxExtent => 100;

  @override
  double get minExtent => 0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return const SizedBox.expand();
  }

  @override
  bool shouldRebuild(_TestHeaderDelegate oldDelegate) => false;
}

Future<void> pullDown(WidgetTester tester) async {
  // BouncingScrollPhysics 在越界区有阻尼，手指位移需要明显大于
  // refreshTriggerPullDistance（100px）才能让越界量达到触发阈值。
  final gesture = await tester.startGesture(const Offset(200, 200));
  for (var i = 0; i < 14; i++) {
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
  }
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets(
      'refresh control before overlap injector engages on pull down',
      (tester) async {
    var refreshCalled = false;
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: buildNestedBody(
            onRefresh: () async {
              refreshCalled = true;
            },
            refreshControlBeforeInjector: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 吸顶头栏仍通过 overlap injector 把列表推到头栏下方。
    final itemTop = tester.getTopLeft(find.text('item 0')).dy;
    expect(itemTop, greaterThanOrEqualTo(100));

    await pullDown(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(refreshCalled, isTrue);
  });

  testWidgets(
      'injector before refresh control swallows the pull gesture (regression guard)',
      (tester) async {
    var refreshCalled = false;
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: buildNestedBody(
            onRefresh: () async {
              refreshCalled = true;
            },
            refreshControlBeforeInjector: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await pullDown(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(refreshCalled, isFalse);
  });
}
