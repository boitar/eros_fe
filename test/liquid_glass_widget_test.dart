import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:eros_fe/models/eh_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiver/core.dart';

void main() {
  test('Liquid Glass search preference survives config round-trip', () {
    final config = EhConfig.fromJson(<String, dynamic>{
      'favoritesOrder': '',
      'listMode': '',
      'catFilter': 0,
      'maxHistory': 100,
      'viewModel': '',
      'hideLiquidGlassSearchOnScroll': true,
    });

    expect(config.hideLiquidGlassSearchOnScroll, isTrue);
    expect(config.toJson()['hideLiquidGlassSearchOnScroll'], isTrue);
    expect(
      config
          .copyWith(
            hideLiquidGlassSearchOnScroll:
                const Optional<bool?>.fromNullable(false),
          )
          .hideLiquidGlassSearchOnScroll,
      isFalse,
    );
  });

  testWidgets('bottom bar motion follows real vertical scroll deltas',
      (WidgetTester tester) async {
    final motion = LiquidGlassBarMotion();
    addTearDown(motion.dispose);

    await tester.pumpWidget(const CupertinoApp(home: SizedBox.shrink()));
    final context = tester.element(find.byType(CupertinoApp));

    FixedScrollMetrics metrics(double pixels) => FixedScrollMetrics(
          minScrollExtent: 0,
          maxScrollExtent: 900,
          pixels: pixels,
          viewportDimension: 844,
          axisDirection: AxisDirection.down,
          devicePixelRatio: 3,
        );

    motion.handleScrollNotification(
      ScrollStartNotification(metrics: metrics(0), context: context),
    );
    motion.handleScrollNotification(
      ScrollUpdateNotification(
        metrics: metrics(150),
        context: context,
        scrollDelta: 150,
        dragDetails: DragUpdateDetails(
          globalPosition: Offset.zero,
          delta: const Offset(0, -150),
        ),
      ),
    );
    expect(motion.value, 1.0);

    motion.handleScrollNotification(
      ScrollUpdateNotification(
        metrics: metrics(45),
        context: context,
        scrollDelta: -105,
        dragDetails: DragUpdateDetails(
          globalPosition: Offset.zero,
          delta: const Offset(0, 105),
        ),
      ),
    );
    expect(motion.value, closeTo(0.0, 0.001));

    motion.handleScrollNotification(
      ScrollUpdateNotification(
        metrics: metrics(0),
        context: context,
        scrollDelta: -45,
        dragDetails: DragUpdateDetails(
          globalPosition: Offset.zero,
          delta: const Offset(0, 45),
        ),
      ),
    );
    expect(motion.value, 0.0);
  });

  testWidgets(
      'bottom bar motion settles to a stable expanded or collapsed state',
      (WidgetTester tester) async {
    final motion = LiquidGlassBarMotion();
    addTearDown(motion.dispose);

    await tester.pumpWidget(const CupertinoApp(home: SizedBox.shrink()));
    final context = tester.element(find.byType(CupertinoApp));

    FixedScrollMetrics metrics(double pixels) => FixedScrollMetrics(
          minScrollExtent: 0,
          maxScrollExtent: 900,
          pixels: pixels,
          viewportDimension: 844,
          axisDirection: AxisDirection.down,
          devicePixelRatio: 3,
        );

    motion.value = 0.49;
    motion.handleScrollNotification(
      ScrollEndNotification(metrics: metrics(120), context: context),
    );
    expect(motion.value, 0.0);

    motion.value = 0.51;
    motion.handleScrollNotification(
      ScrollEndNotification(metrics: metrics(120), context: context),
    );
    expect(motion.value, 1.0);

    motion.value = 1.0;
    motion.handleScrollNotification(
      ScrollEndNotification(metrics: metrics(0), context: context),
    );
    expect(motion.value, 0.0);
  });

  testWidgets('liquid glass tab bar stays finite under loose width',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: UnconstrainedBox(
          alignment: Alignment.bottomCenter,
          child: LiquidGlassTabBar(
            items: <BottomNavigationBarItem>[
              const BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.photo),
                label: 'Gallery',
              ),
              const BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.settings),
                label: 'Settings',
              ),
              const BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final RenderBox renderBox =
        tester.renderObject(find.byType(LiquidGlassTabBar));
    expect(renderBox.size.width.isFinite, isTrue);
    expect(renderBox.size.height.isFinite, isTrue);

    await tester.pumpWidget(
      CupertinoApp(
        home: UnconstrainedBox(
          child: LiquidGlassSurface(
            enabled: true,
            child: const SizedBox(width: 120, height: 44),
          ),
        ),
      ),
    );

    final RenderBox surfaceBox =
        tester.renderObject(find.byType(LiquidGlassSurface));
    expect(surfaceBox.size.width.isFinite, isTrue);
    expect(surfaceBox.size.height.isFinite, isTrue);
  });

  testWidgets('collapsed bottom bar is icon-only and keeps search by default',
      (WidgetTester tester) async {
    final motion = LiquidGlassBarMotion()..value = 1.0;
    addTearDown(motion.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: SizedBox(
          width: 390,
          height: 100,
          child: LiquidGlassTabBar(
            items: <BottomNavigationBarItem>[
              const BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.photo),
                label: 'Gallery',
              ),
              const BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.settings),
                label: 'Settings',
              ),
            ],
            motion: motion,
            onTap: (_) {},
            onSearch: () {},
          ),
        ),
      ),
    );

    final RenderBox compact = tester.renderObject(
      find.byKey(const ValueKey<String>('liquid-glass-compact-tab')),
    );
    expect(compact.size, const Size(48, 48));
    expect(find.bySemanticsLabel('Gallery'), findsOneWidget);
    expect(find.bySemanticsLabel('搜索'), findsOneWidget);
  });

  testWidgets('collapsed bottom bar can hide search when opted in',
      (WidgetTester tester) async {
    final motion = LiquidGlassBarMotion()..value = 1.0;
    addTearDown(motion.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: SizedBox(
          width: 390,
          height: 100,
          child: LiquidGlassTabBar(
            items: <BottomNavigationBarItem>[
              const BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.photo),
                label: 'Gallery',
              ),
              const BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.settings),
                label: 'Settings',
              ),
            ],
            motion: motion,
            hideSearchOnScroll: true,
            onTap: (_) {},
            onSearch: () {},
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('搜索'), findsNothing);
  });

  testWidgets(
      'collapsed bottom bar tap only expands and does not select or refresh',
      (WidgetTester tester) async {
    final motion = LiquidGlassBarMotion()..value = 1.0;
    addTearDown(motion.dispose);
    int? selected;

    await tester.pumpWidget(
      CupertinoApp(
        home: SizedBox(
          width: 390,
          height: 100,
          child: LiquidGlassTabBar(
            items: <BottomNavigationBarItem>[
              const BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.photo),
                activeIcon: Icon(CupertinoIcons.photo_fill),
                label: 'Gallery',
              ),
              const BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.heart),
                activeIcon: Icon(CupertinoIcons.heart_fill),
                label: 'Favorites',
              ),
            ],
            motion: motion,
            onTap: (int index) => selected = index,
            onSearch: () {},
          ),
        ),
      ),
    );

    final Finder compact =
        find.byKey(const ValueKey<String>('liquid-glass-compact-tab'));
    expect(compact, findsOneWidget);
    await tester.tap(compact);
    await tester.pump();

    expect(motion.value, 0.0);
    expect(selected, isNull);
    expect(find.text('Gallery'), findsOneWidget);

    motion.value = 1.0;
    await tester.pump();
    final Finder collapsedAgain =
        find.byKey(const ValueKey<String>('liquid-glass-compact-tab'));
    await tester.longPress(collapsedAgain);
    await tester.pump();
    expect(motion.value, 1.0);
    expect(selected, isNull);

    await tester.drag(collapsedAgain, const Offset(120, 0));
    await tester.pump();
    expect(motion.value, 1.0);
    expect(selected, isNull);
  });

  testWidgets('liquid glass tab bar previews and commits a horizontal drag',
      (WidgetTester tester) async {
    int? selected;

    await tester.pumpWidget(
      CupertinoApp(
        home: SizedBox(
          width: 390,
          height: 100,
          child: LiquidGlassTabBar(
            items: <BottomNavigationBarItem>[
              const BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.photo),
                activeIcon: Icon(CupertinoIcons.photo_fill),
                label: 'Gallery',
              ),
              const BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.heart),
                activeIcon: Icon(CupertinoIcons.heart_fill),
                label: 'Favorites',
              ),
              const BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.list_number),
                label: 'Toplists',
              ),
            ],
            onTap: (int index) => selected = index,
            onSearch: () {},
          ),
        ),
      ),
    );

    final Finder rail =
        find.byKey(const ValueKey<String>('liquid-glass-tab-bar'));
    expect(rail, findsOneWidget);

    final RenderBox railBox = tester.renderObject<RenderBox>(rail);
    final Offset start = railBox.localToGlobal(
      Offset(railBox.size.width * 0.2, railBox.size.height / 2),
    );
    await tester.dragFrom(start, const Offset(120, 0));
    await tester.pumpAndSettle();

    expect(selected, 1);
  });

  testWidgets('bottom glass capsule settles without overshooting its target',
      (WidgetTester tester) async {
    int? selected;

    await tester.pumpWidget(
      CupertinoApp(
        home: SizedBox(
          width: 390,
          height: 100,
          child: LiquidGlassTabBar(
            items: <BottomNavigationBarItem>[
              const BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.photo),
                activeIcon: Icon(CupertinoIcons.photo_fill),
                label: 'Gallery',
              ),
              const BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.heart),
                activeIcon: Icon(CupertinoIcons.heart_fill),
                label: 'Favorites',
              ),
              const BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.list_number),
                label: 'Toplists',
              ),
            ],
            onTap: (int index) => selected = index,
            onSearch: () {},
          ),
        ),
      ),
    );

    final Finder rail =
        find.byKey(const ValueKey<String>('liquid-glass-tab-bar'));
    final RenderBox railBox = tester.renderObject<RenderBox>(rail);
    final Offset start = railBox.localToGlobal(
      Offset(railBox.size.width * 0.2, railBox.size.height / 2),
    );
    await tester.dragFrom(start, const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(selected, 1);

    final RenderBox capsule = tester.renderObject(
      find.byKey(
        const ValueKey<String>('liquid-glass-selection-capsule'),
      ),
    );
    final double targetLeft =
        tester.getTopLeft(rail).dx + 4.0 + (railBox.size.width - 8.0) / 3.0;
    expect(
        capsule.localToGlobal(Offset.zero).dx, lessThanOrEqualTo(targetLeft));
    await tester.pump(const Duration(milliseconds: 90));
    final double midLeft = capsule.localToGlobal(Offset.zero).dx;
    await tester.pumpAndSettle();
    final double finalLeft = capsule.localToGlobal(Offset.zero).dx;
    expect(midLeft, lessThanOrEqualTo(finalLeft + 0.01));
  });

  testWidgets('top glass category drag commits the item under the finger',
      (WidgetTester tester) async {
    int? selected;
    final categories = <String>['热门', '画廊', '订阅'];

    await tester.pumpWidget(
      CupertinoApp(
        home: SizedBox(
          width: 390,
          height: 180,
          child: LiquidGlassRail(
            title: '画廊',
            safeTop: 59,
            collapseProgress: 0,
            dockingTranslation: 0,
            selectedIndex: 0,
            categories: <LiquidGlassRailCategory>[
              for (int index = 0; index < categories.length; index++)
                LiquidGlassRailCategory(
                  title: categories[index],
                  onTap: () => selected = index,
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Offset start = tester.getCenter(find.text('热门'));
    final Offset end = tester.getCenter(find.text('画廊').last);
    await tester.dragFrom(start, end - start);

    expect(selected, 1);
  });

  testWidgets('top glass capsule contains its selected category label',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: SizedBox(
          width: 390,
          height: 180,
          child: LiquidGlassRail(
            title: '画廊',
            safeTop: 59,
            collapseProgress: 0,
            dockingTranslation: 0,
            selectedIndex: 0,
            categories: <LiquidGlassRailCategory>[
              LiquidGlassRailCategory(title: '热门', onTap: () {}),
              LiquidGlassRailCategory(title: '画廊', onTap: () {}),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Rect capsule = tester.getRect(
      find.byKey(
        const ValueKey<String>('liquid-glass-category-selection'),
      ),
    );
    final Rect label = tester.getRect(find.text('热门'));
    expect(capsule.left, lessThanOrEqualTo(label.left));
    expect(capsule.right, greaterThanOrEqualTo(label.right));
    expect((capsule.center.dy - label.center.dy).abs(), lessThan(1.0));
  });

  testWidgets('top glass rail shows and animates its selected capsule',
      (WidgetTester tester) async {
    Widget app(int selectedIndex) {
      return CupertinoApp(
        home: SizedBox(
          width: 390,
          height: 180,
          child: LiquidGlassRail(
            title: '画廊',
            safeTop: 59,
            collapseProgress: 0,
            dockingTranslation: 0,
            selectedIndex: selectedIndex,
            categories: <LiquidGlassRailCategory>[
              LiquidGlassRailCategory(title: '热门', onTap: () {}),
              LiquidGlassRailCategory(title: '画廊', onTap: () {}),
            ],
          ),
        ),
      );
    }

    await tester.pumpWidget(app(0));
    await tester.pumpAndSettle();

    final Finder indicator = find.byKey(
      const ValueKey<String>('liquid-glass-category-selection-indicator'),
    );
    final Rect initialRect = tester.getRect(indicator);
    final Rect outerRect = tester.getRect(
      find.byKey(
        const ValueKey<String>('liquid-glass-category-selection'),
      ),
    );
    expect(initialRect.left, greaterThan(outerRect.left));
    expect(initialRect.right, lessThan(outerRect.right));
    expect(
      initialRect.width,
      lessThan(outerRect.width),
    );

    await tester.pumpWidget(app(1));
    await tester.pump(const Duration(milliseconds: 100));
    final double midLeft = tester.getRect(indicator).left;
    await tester.pumpAndSettle();
    final Rect finalRect = tester.getRect(indicator);
    expect(midLeft, greaterThan(initialRect.left));
    expect(midLeft, lessThan(finalRect.left));
    expect(finalRect.left, greaterThan(initialRect.left));
  });

  testWidgets('glass rail collapses without overflowing its sliver',
      (WidgetTester tester) async {
    final layout = LiquidGlassTopLayout.fromTopInset(59);

    await tester.pumpWidget(
      CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(
            viewPadding: EdgeInsets.only(top: 59),
          ),
          child: CustomScrollView(
            slivers: <Widget>[
              SliverPersistentHeader(
                pinned: true,
                delegate: _TestRailDelegate(layout),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 900),
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('glass rail uses separate collapse and restore thresholds',
      (WidgetTester tester) async {
    const railKey = ValueKey<String>('threshold-rail');

    Widget app(double progress) {
      return CupertinoApp(
        home: LiquidGlassRail(
          key: railKey,
          title: '画廊',
          safeTop: 59,
          collapseProgress: progress,
          dockingTranslation: 22,
          selectedIndex: 0,
          categories: <LiquidGlassRailCategory>[
            LiquidGlassRailCategory(title: '热门', onTap: () {}),
          ],
        ),
      );
    }

    await tester.pumpWidget(app(0));
    Finder hiddenRail = find.descendant(
      of: find.byKey(railKey),
      matching: find.byType(Offstage),
    );
    expect(hiddenRail, findsNothing);

    await tester.pumpWidget(app(1));
    expect(hiddenRail, findsNothing);

    await tester.pumpWidget(app(0.9));
    expect(hiddenRail, findsNothing);

    await tester.pumpWidget(app(0.7));
    expect(hiddenRail, findsNothing);
  });
}

class _TestRailDelegate extends SliverPersistentHeaderDelegate {
  _TestRailDelegate(this.layout);

  final LiquidGlassTopLayout layout;

  @override
  double get minExtent => layout.collapsedHeaderHeight;

  @override
  double get maxExtent =>
      layout.collapsedHeaderHeight + LiquidGlassRail.expandedHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return LiquidGlassRail(
      title: '画廊',
      safeTop: layout.safeTop,
      collapseProgress: layout.collapseProgress(
        shrinkOffset,
        LiquidGlassRail.expandedHeight,
      ),
      dockingTranslation: layout.dockingTranslation,
      selectedIndex: 0,
      categories: <LiquidGlassRailCategory>[
        LiquidGlassRailCategory(title: '热门', onTap: () {}),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _TestRailDelegate oldDelegate) => false;
}
