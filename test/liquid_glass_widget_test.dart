import 'package:eros_fe/models/eh_config.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:eros_fe/widget/liquid_glass_scroll_controller.dart';
import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy bottom-search preference is ignored when loading config', () {
    final config = EhConfig.fromJson(const <String, dynamic>{
      'favoritesOrder': '',
      'listMode': '',
      'catFilter': 0,
      'maxHistory': 100,
      'viewModel': '',
      'hideLiquidGlassSearchOnScroll': true,
    });

    expect(
        config.toJson().containsKey('hideLiquidGlassSearchOnScroll'), isFalse);
  });

  /// A minimal glass page: scroll content, a fixed solid mask above it, and
  /// the scrim plus the fading rail on top, all driven by one coordinator.
  Widget glassPageHarness(
    LiquidGlassTopStateCoordinator coordinator,
    LiquidGlassBarMotion motion,
    ScrollController scrollController, {
    required bool enabled,
    required GlobalKey firstCardKey,
    LiquidGlassTopBarLayout layout = LiquidGlassTopBarLayout.twoRow,
  }) {
    const safeTop = 59.0;
    final headerExtent = safeTop + layout.expandedHeight(TextScaler.noScaling);
    coordinator.updateLayout(
      devicePixelRatio: 3,
      topBarExtent: headerExtent,
      safeTop: safeTop,
    );
    return CupertinoApp(
      home: LiquidGlassBarMotionScope(
        motion: motion,
        child: NotificationListener<ScrollNotification>(
          onNotification: coordinator.handleScrollNotification,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              SingleChildScrollView(
                controller: scrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                child: Column(
                  children: <Widget>[
                    SizedBox(height: headerExtent),
                    SizedBox(key: firstCardKey, height: 2400),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LiquidGlassSolidMask(
                  progressListenable: coordinator.solidMaskProgress,
                  safeTop: safeTop,
                  height: headerExtent,
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LiquidGlassTopScrim(
                  safeTop: safeTop,
                  layout: layout,
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LiquidGlassBarMotionBuilder(
                  enabled: enabled,
                  builder: (context, progress) => LiquidGlassRail(
                    title: '画廊',
                    safeTop: safeTop,
                    fadeProgress: progress,
                    selectedIndex: 0,
                    layout: layout,
                    categories: <LiquidGlassRailCategory>[
                      LiquidGlassRailCategory(title: '热门', onTap: () {}),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Finder solidMask() =>
      find.byKey(const ValueKey<String>('liquid-glass-solid-mask'));

  Finder statusColorBlock() =>
      find.byKey(const ValueKey<String>('liquid-glass-status-background'));

  Finder railOpacities() => find.descendant(
        of: find.byType(LiquidGlassRail),
        matching: find.byType(Opacity),
      );

  testWidgets(
    'top bar fade rides the mask while the first card is inside the rail band',
    (WidgetTester tester) async {
      final motion = LiquidGlassBarMotion();
      final scrollController = ScrollController();
      final firstCardKey = GlobalKey();
      final headerExtent = 59 +
          LiquidGlassTopBarLayout.twoRow.expandedHeight(TextScaler.noScaling);
      final coordinator = LiquidGlassTopStateCoordinator(
        scrollController: scrollController,
        firstCardTopProvider: () => liquidGlassScreenTop(firstCardKey),
        devicePixelRatio: 3,
      );
      coordinator.attachBarMotion(motion);
      coordinator.setBarFadeEnabled(true);
      addTearDown(coordinator.dispose);
      addTearDown(motion.dispose);
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        glassPageHarness(
          coordinator,
          motion,
          scrollController,
          enabled: true,
          firstCardKey: firstCardKey,
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('liquid-glass-top-scrim')),
        findsOneWidget,
      );
      expect(tester.getTopLeft(find.byKey(firstCardKey)).dy,
          closeTo(headerExtent, 0.01));
      expect(tester.getTopLeft(solidMask()).dy, 59.0);
      expect(tester.getRect(solidMask()).bottom, closeTo(headerExtent, 0.01));
      // The scrim is one gradient from screen y=0; there is no separate
      // opaque status-bar color block.
      expect(statusColorBlock(), findsNothing);

      // Establish the initial layout baseline before effective travel.
      coordinator.refresh();
      // Inside the band the controls never fade ahead of the collapsing
      // solid area: the final fade is the mask coverage consumed by the
      // card (12pt of the 94pt band), not the full 48pt direction travel.
      scrollController.jumpTo(12);
      await tester.pump();
      coordinator.refresh();
      await tester.pump();
      expect(coordinator.barFadeProgress.value, closeTo(12 / 94, 0.001));
      expect(
        tester.getRect(solidMask()).bottom,
        closeTo(tester.getTopLeft(find.byKey(firstCardKey)).dy, 0.01),
      );

      // Past the safe-area trigger the card has left the band, so the
      // direction-driven fade alone controls the rail and the mask retracts.
      scrollController.jumpTo(headerExtent - 24);
      await tester.pump();
      coordinator.refresh();
      await tester.pump();
      expect(coordinator.barFadeProgress.value, 1.0);
      expect(solidMask(), findsNothing);
      // The gradient remains a single continuous layer while the solid mask
      // retracts.
      expect(statusColorBlock(), findsNothing);

      // Returning through the safe-area-to-category interval reveals the
      // mask with its lower edge aligned to the card, then restores the rail.
      final double halfwayOffset = (headerExtent - 59) / 2;
      scrollController.jumpTo(halfwayOffset);
      await tester.pump();
      coordinator.refresh();
      await tester.pump();
      expect(
        tester.getRect(solidMask()).bottom,
        closeTo(tester.getTopLeft(find.byKey(firstCardKey)).dy, 0.01),
      );
      expect(tester.getTopLeft(find.byKey(firstCardKey)).dy, greaterThan(59));

      scrollController.jumpTo(0);
      await tester.pump();
      coordinator.refresh();
      await tester.pump();
      expect(coordinator.solidMaskProgress.value, 1.0);
      expect(tester.getRect(solidMask()).bottom, closeTo(headerExtent, 0.01));
      expect(find.text('热门'), findsOneWidget);
    },
  );

  testWidgets(
    'mask retracts before the safe-area trigger and follows reverse scroll in both layouts',
    (WidgetTester tester) async {
      for (final layout in LiquidGlassTopBarLayout.values) {
        final motion = LiquidGlassBarMotion();
        final scrollController = ScrollController();
        final firstCardKey = GlobalKey();
        const safeTop = 59.0;
        final headerExtent =
            safeTop + layout.expandedHeight(TextScaler.noScaling);
        final coordinator = LiquidGlassTopStateCoordinator(
          scrollController: scrollController,
          firstCardTopProvider: () => liquidGlassScreenTop(firstCardKey),
          devicePixelRatio: 3,
        );
        coordinator.attachBarMotion(motion);
        coordinator.setBarFadeEnabled(true);
        addTearDown(coordinator.dispose);
        addTearDown(motion.dispose);
        addTearDown(scrollController.dispose);

        await tester.pumpWidget(
          glassPageHarness(
            coordinator,
            motion,
            scrollController,
            enabled: true,
            firstCardKey: firstCardKey,
            layout: layout,
          ),
        );
        expect(tester.getTopLeft(find.byKey(firstCardKey)).dy,
            closeTo(headerExtent, 0.01));

        final double middleOffset = (headerExtent - safeTop) / 2;
        scrollController.jumpTo(middleOffset);
        await tester.pump();
        coordinator.refresh();
        await tester.pump();
        final double cardTop = tester.getTopLeft(find.byKey(firstCardKey)).dy;
        expect(coordinator.solidMaskProgress.value, closeTo(0.5, 0.01));
        expect(tester.getRect(solidMask()).bottom, closeTo(cardTop, 0.01));

        // One point above the trigger retracts the entire mask.
        scrollController.jumpTo(headerExtent - safeTop + 1);
        await tester.pump();
        coordinator.refresh();
        await tester.pump();
        expect(
            tester.getTopLeft(find.byKey(firstCardKey)).dy, lessThan(safeTop));
        expect(coordinator.solidMaskProgress.value, 0.0);
        expect(solidMask(), findsNothing);

        // Pulling back down restores the same midpoint geometry, not an
        // anchor-triggered full-height block.
        scrollController.jumpTo(middleOffset);
        await tester.pump();
        coordinator.refresh();
        await tester.pump();
        expect(
          tester.getRect(solidMask()).bottom,
          closeTo(tester.getTopLeft(find.byKey(firstCardKey)).dy, 0.01),
        );

        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  /// A glass page shaped like the real tab pages: the active rail reserves its
  /// exact expanded height, the inner list injects that overlap, and the fixed
  /// mask/scrim/rail overlays sit above the content.
  Widget glassNestedPageHarness(
    LiquidGlassTopStateCoordinator coordinator,
    LiquidGlassBarMotion motion,
    LiquidGlassScrollController headerScrollController,
    GlobalKey<ExtendedNestedScrollViewState> nestedKey, {
    required bool enabled,
    required GlobalKey firstCardKey,
    LiquidGlassTopBarLayout layout = LiquidGlassTopBarLayout.twoRow,
  }) {
    final double reservedHeaderExtent =
        59 + layout.expandedHeight(TextScaler.noScaling);
    headerScrollController.headerExtent = reservedHeaderExtent;
    coordinator.updateLayout(
      devicePixelRatio: 3,
      topBarExtent: reservedHeaderExtent,
      safeTop: 59,
    );
    return CupertinoApp(
      home: LiquidGlassBarMotionScope(
        motion: motion,
        child: NotificationListener<ScrollNotification>(
          onNotification: coordinator.handleScrollNotification,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ExtendedNestedScrollView(
                key: nestedKey,
                controller: headerScrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                floatHeaderSlivers: false,
                onlyOneScrollInBody: true,
                headerSliverBuilder: (context, innerBoxIsScrolled) => <Widget>[
                  SliverOverlapAbsorber(
                    handle:
                        ExtendedNestedScrollView.sliverOverlapAbsorberHandleFor(
                      context,
                    ),
                    sliver: SliverPersistentHeader(
                      floating: false,
                      pinned: true,
                      delegate:
                          _ExpandedGlassHeaderDelegate(reservedHeaderExtent),
                    ),
                  ),
                ],
                body: Builder(
                  builder: (context) => CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: <Widget>[
                      SliverOverlapInjector(
                        handle: ExtendedNestedScrollView
                            .sliverOverlapAbsorberHandleFor(
                          context,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: ColoredBox(
                          key: firstCardKey,
                          color: const Color(0xFF202020),
                          child: const SizedBox(height: 2400),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LiquidGlassSolidMask(
                  progressListenable: coordinator.solidMaskProgress,
                  safeTop: 59,
                  height: reservedHeaderExtent,
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LiquidGlassTopScrim(
                  safeTop: 59,
                  layout: layout,
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LiquidGlassBarMotionBuilder(
                  enabled: enabled,
                  builder: (context, progress) => LiquidGlassRail(
                    title: '画廊',
                    safeTop: 59,
                    fadeProgress: progress,
                    selectedIndex: 0,
                    layout: layout,
                    categories: <LiquidGlassRailCategory>[
                      LiquidGlassRailCategory(title: '热门', onTap: () {}),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets(
    'expanded glass header places the first item below each layout and scrolls it behind the rail',
    (tester) async {
      final motion = LiquidGlassBarMotion();
      final headerController = LiquidGlassScrollController();
      final nestedKey = GlobalKey<ExtendedNestedScrollViewState>();
      GlobalKey firstCardKey = GlobalKey();
      final coordinator = LiquidGlassTopStateCoordinator(
        scrollController: headerController,
        additionalPositions: () =>
            nestedKey.currentState?.innerPositions ?? const <ScrollPosition>[],
        firstCardTopProvider: () => liquidGlassScreenTop(firstCardKey),
        devicePixelRatio: 3,
      );
      coordinator.attachBarMotion(motion);
      coordinator.setBarFadeEnabled(true);
      addTearDown(coordinator.dispose);
      addTearDown(motion.dispose);
      addTearDown(headerController.dispose);

      for (final layout in LiquidGlassTopBarLayout.values) {
        firstCardKey = GlobalKey();
        await tester.pumpWidget(
          glassNestedPageHarness(
            coordinator,
            motion,
            headerController,
            nestedKey,
            enabled: true,
            firstCardKey: firstCardKey,
            layout: layout,
          ),
        );
        coordinator.refresh();
        await tester.pump();

        final Finder firstItem = find.byKey(firstCardKey);
        final double expectedHeaderExtent =
            59 + layout.expandedHeight(TextScaler.noScaling);

        // Each layout reserves exactly its own rail height. This keeps the
        // first item entirely below the bar at offset zero without a shared
        // extra top inset.
        expect(
          tester.getTopLeft(firstItem).dy,
          closeTo(expectedHeaderExtent, 0.01),
        );
        expect(tester.getTopLeft(solidMask()).dy, 59.0);
        expect(
          tester.getRect(solidMask()).height,
          closeTo(expectedHeaderExtent - 59, 0.01),
        );
        expect(
          tester.widget<ColoredBox>(solidMask()).color.a,
          greaterThan(0.99),
        );

        // Leaving the anchor collapses the reserved header and moves content
        // 1:1 behind the fixed rail in both compact and expanded layouts.
        final ScrollPosition innerPosition =
            nestedKey.currentState!.innerPositions.first;
        await tester.dragFrom(const Offset(400, 250), const Offset(0, -80));
        await tester.pumpAndSettle();
        coordinator.refresh();
        await tester.pump();
        await tester.pump();
        final double cardTopAfterDrag = tester.getTopLeft(firstItem).dy;
        expect(cardTopAfterDrag, lessThan(expectedHeaderExtent));
        if (cardTopAfterDrag <= 59) {
          expect(solidMask(), findsNothing);
        } else {
          expect(tester.getRect(solidMask()).bottom,
              closeTo(cardTopAfterDrag, 0.01));
        }
        // The rail has started fading behind the card. Inside the band it
        // stays partially visible by design until the card passes the
        // safe-area trigger, so only the progress is asserted here; the full
        // hide is asserted after the jump below leaves the band.
        expect(coordinator.barFadeProgress.value, greaterThan(0));

        // Content continues to consume the initial spacer without floating
        // it back, and leaving the band hides the rail completely.
        final ScrollPosition outerPosition = headerController.position;
        outerPosition.jumpTo(expectedHeaderExtent - 24.0);
        await tester.pump();
        coordinator.refresh();
        await tester.pump();
        await tester.pump();
        expect(coordinator.barFadeProgress.value, 1.0);
        expect(tester.getTopLeft(firstItem).dy, closeTo(24.0, 0.01));
        expect(find.text('热门'), findsNothing);
        expect(solidMask(), findsNothing);

        outerPosition.jumpTo(expectedHeaderExtent);
        await tester.pumpAndSettle();
        coordinator.refresh();
        await tester.pump();
        await tester.pump();
        expect(coordinator.barFadeProgress.value, 1.0);
        expect(tester.getTopLeft(firstItem).dy, closeTo(0.0, 0.01));
        expect(find.text('热门'), findsNothing);
        expect(solidMask(), findsNothing);

        innerPosition.jumpTo(200);
        await tester.pump();
        coordinator.refresh();
        await tester.pump();
        await tester.pump();
        expect(find.text('热门'), findsNothing);
        expect(coordinator.barFadeProgress.value, 1.0);
        expect(solidMask(), findsNothing);
        expect(tester.getTopLeft(firstItem).dy, lessThan(0.0));

        final Future<void> reset = coordinator.resetToInitialAnchor();
        await tester.pumpAndSettle();
        await reset;
        await tester.pump();
        expect(
          tester.getTopLeft(firstItem).dy,
          closeTo(expectedHeaderExtent, 0.01),
        );
        expect(tester.getRect(solidMask()).bottom,
            closeTo(expectedHeaderExtent, 0.01));
        expect(
          tester.widget<ColoredBox>(solidMask()).color.a,
          greaterThan(0.99),
        );

        await tester.dragFrom(const Offset(400, 120), const Offset(0, 35));
        await tester.pump();
        coordinator.refresh();
        await tester.pump();
        await tester.pump();
        expect(
          tester.getRect(solidMask()).bottom,
          lessThanOrEqualTo(tester.getTopLeft(firstItem).dy + 0.01),
        );
        final Future<void> resetAfterBounce =
            coordinator.resetToInitialAnchor();
        await tester.pumpAndSettle();
        await resetAfterBounce;
      }
    },
  );

  testWidgets(
    'top bar opacity stays fixed at 1 with the hide setting off',
    (WidgetTester tester) async {
      final motion = LiquidGlassBarMotion();
      final scrollController = ScrollController();
      final firstCardKey = GlobalKey();
      final coordinator = LiquidGlassTopStateCoordinator(
        scrollController: scrollController,
        firstCardTopProvider: () => liquidGlassScreenTop(firstCardKey),
        devicePixelRatio: 3,
      );
      coordinator.attachBarMotion(motion);
      coordinator.setBarFadeEnabled(false);
      addTearDown(coordinator.dispose);
      addTearDown(motion.dispose);
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        glassPageHarness(
          coordinator,
          motion,
          scrollController,
          enabled: false,
          firstCardKey: firstCardKey,
        ),
      );

      scrollController.jumpTo(200);
      await tester.pump();
      coordinator.refresh();
      await tester.pump();
      expect(coordinator.barFadeProgress.value, 0.0);
      expect(motion.value, 0.0);
      expect(motion.isTopBarVisible, isTrue);
      expect(
        tester
            .widgetList<Opacity>(railOpacities())
            .map((opacity) => opacity.opacity),
        everyElement(1.0),
      );
      expect(coordinator.barFadeProgress.value, lessThan(1.0));
      expect(find.text('热门'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('liquid-glass-top-scrim')),
        findsOneWidget,
      );

      // Mask reveal follows the card coordinate even when the bar itself is
      // configured to remain visible.
      expect(coordinator.solidMaskProgress.value, 0.0);
    },
  );

  testWidgets('liquid glass tab bar stays finite under loose width', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: UnconstrainedBox(
          alignment: Alignment.bottomCenter,
          child: LiquidGlassTabBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.photo),
                label: 'Gallery',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.settings),
                label: 'Settings',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final RenderBox renderBox = tester.renderObject(
      find.byType(LiquidGlassTabBar),
    );
    expect(renderBox.size.width.isFinite, isTrue);
    expect(renderBox.size.height.isFinite, isTrue);

    await tester.pumpWidget(
      const CupertinoApp(
        home: UnconstrainedBox(
          child: LiquidGlassSurface(
            enabled: true,
            child: SizedBox(width: 120, height: 44),
          ),
        ),
      ),
    );

    final RenderBox surfaceBox = tester.renderObject(
      find.byType(LiquidGlassSurface),
    );
    expect(surfaceBox.size.width.isFinite, isTrue);
    expect(surfaceBox.size.height.isFinite, isTrue);
  });

  testWidgets('Flutter glass fallback follows Reduce Transparency updates', (
    WidgetTester tester,
  ) async {
    final previousTargetPlatform = debugDefaultTargetPlatformOverride;
    addTearDown(LiquidGlassAccessibilitySettings.stopWatching);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = previousTargetPlatform;
    });

    MockStreamHandlerEventSink? settings;
    tester.binding.defaultBinaryMessenger.setMockStreamHandler(
      const EventChannel('eros/accessibility-settings'),
      MockStreamHandler.inline(
        onListen: (Object? _, MockStreamHandlerEventSink events) {
          settings = events;
        },
      ),
    );

    await tester.pumpWidget(
      const CupertinoApp(
        home: LiquidGlassSurface(
          enabled: true,
          useNativeGlass: false,
          child: SizedBox(width: 180, height: 48),
        ),
      ),
    );
    await tester.pump();
    expect(settings, isNotNull);
    expect(find.byType(BackdropFilter), findsNothing);

    settings!.success(false);
    await tester.pump();
    await tester.pump();
    expect(LiquidGlassAccessibilitySettings.reduceTransparency.value, isFalse);
    expect(find.byType(BackdropFilter), findsOneWidget);

    settings!.success(true);
    await tester.pump();
    await tester.pump();
    expect(find.byType(BackdropFilter), findsNothing);
    debugDefaultTargetPlatformOverride = previousTargetPlatform;
  });

  testWidgets('bottom bar stays expanded with search available', (
    WidgetTester tester,
  ) async {
    final motion = LiquidGlassBarMotion()..value = 1.0;
    addTearDown(motion.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: LiquidGlassBarMotionScope(
          motion: motion,
          child: SizedBox(
            width: 390,
            height: 100,
            child: LiquidGlassTabBar(
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.photo),
                  label: 'Gallery',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.heart),
                  label: 'Favorites',
                ),
              ],
              onTap: (_) {},
              onSearch: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.bySemanticsLabel('搜索'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('liquid-glass-compact-tab')),
        findsNothing);

    motion.value = 0.8;
    await tester.pump();
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.bySemanticsLabel('搜索'), findsOneWidget);
  });

  testWidgets('liquid glass tab bar previews and commits a horizontal drag', (
    WidgetTester tester,
  ) async {
    int? selected;

    await tester.pumpWidget(
      CupertinoApp(
        home: SizedBox(
          width: 390,
          height: 100,
          child: LiquidGlassTabBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.photo),
                activeIcon: Icon(CupertinoIcons.photo_fill),
                label: 'Gallery',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.heart),
                activeIcon: Icon(CupertinoIcons.heart_fill),
                label: 'Favorites',
              ),
              BottomNavigationBarItem(
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

    final Finder rail = find.byKey(
      const ValueKey<String>('liquid-glass-tab-bar'),
    );
    expect(rail, findsOneWidget);

    final RenderBox railBox = tester.renderObject<RenderBox>(rail);
    final Offset start = railBox.localToGlobal(
      Offset(railBox.size.width * 0.2, railBox.size.height / 2),
    );
    await tester.dragFrom(start, const Offset(120, 0));
    await tester.pumpAndSettle();

    expect(selected, 1);
  });

  testWidgets('bottom glass capsule settles without overshooting its target', (
    WidgetTester tester,
  ) async {
    int? selected;

    await tester.pumpWidget(
      CupertinoApp(
        home: SizedBox(
          width: 390,
          height: 100,
          child: LiquidGlassTabBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.photo),
                activeIcon: Icon(CupertinoIcons.photo_fill),
                label: 'Gallery',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.heart),
                activeIcon: Icon(CupertinoIcons.heart_fill),
                label: 'Favorites',
              ),
              BottomNavigationBarItem(
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

    final Finder rail = find.byKey(
      const ValueKey<String>('liquid-glass-tab-bar'),
    );
    final RenderBox railBox = tester.renderObject<RenderBox>(rail);
    final Offset start = railBox.localToGlobal(
      Offset(railBox.size.width * 0.2, railBox.size.height / 2),
    );
    await tester.dragFrom(start, const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(selected, 1);

    final RenderBox capsule = tester.renderObject(
      find.byKey(const ValueKey<String>('liquid-glass-selection-capsule')),
    );
    final double targetLeft =
        tester.getTopLeft(rail).dx + 4.0 + (railBox.size.width - 8.0) / 3.0;
    expect(
      capsule.localToGlobal(Offset.zero).dx,
      lessThanOrEqualTo(targetLeft),
    );
    await tester.pump(const Duration(milliseconds: 90));
    final double midLeft = capsule.localToGlobal(Offset.zero).dx;
    await tester.pumpAndSettle();
    final double finalLeft = capsule.localToGlobal(Offset.zero).dx;
    expect(midLeft, lessThanOrEqualTo(finalLeft + 0.01));
  });

  testWidgets('top glass category browsing never commits a selection', (
    WidgetTester tester,
  ) async {
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
            fadeProgress: 0,
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

    expect(selected, isNull);
  });

  testWidgets('top glass capsule contains its selected category label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: SizedBox(
          width: 390,
          height: 180,
          child: LiquidGlassRail(
            title: '画廊',
            safeTop: 59,
            fadeProgress: 0,
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
      find.byKey(const ValueKey<String>('liquid-glass-category-selection')),
    );
    final Rect label = tester.getRect(find.text('热门'));
    expect(capsule.left, lessThanOrEqualTo(label.left));
    expect(capsule.right, greaterThanOrEqualTo(label.right));
    expect((capsule.center.dy - label.center.dy).abs(), lessThan(1.0));
  });

  testWidgets('top glass rail shows and animates its selected capsule', (
    WidgetTester tester,
  ) async {
    Widget app(int selectedIndex) {
      return CupertinoApp(
        home: SizedBox(
          width: 390,
          height: 180,
          child: LiquidGlassRail(
            title: '画廊',
            safeTop: 59,
            fadeProgress: 0,
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
      find.byKey(const ValueKey<String>('liquid-glass-category-selection')),
    );
    expect(initialRect.left, greaterThan(outerRect.left));
    expect(initialRect.right, lessThan(outerRect.right));
    expect(initialRect.width, lessThan(outerRect.width));

    await tester.pumpWidget(app(1));
    await tester.pump(const Duration(milliseconds: 100));
    final double midLeft = tester.getRect(indicator).left;
    await tester.pumpAndSettle();
    final Rect finalRect = tester.getRect(indicator);
    expect(midLeft, greaterThan(initialRect.left));
    expect(midLeft, lessThan(finalRect.left));
    expect(finalRect.left, greaterThan(initialRect.left));
  });

  testWidgets('glass rail collapses without overflowing its sliver', (
    WidgetTester tester,
  ) async {
    final layout = LiquidGlassTopLayout.fromTopInset(59);

    await tester.pumpWidget(
      CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(viewPadding: EdgeInsets.only(top: 59)),
          child: CustomScrollView(
            slivers: <Widget>[
              SliverPersistentHeader(
                pinned: true,
                delegate: _TestRailDelegate(layout),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 900)),
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

  testWidgets('glass rail hides controls only at the fully faded endpoint', (
    WidgetTester tester,
  ) async {
    const railKey = ValueKey<String>('threshold-rail');

    Widget app(double progress) {
      return CupertinoApp(
        home: LiquidGlassRail(
          key: railKey,
          title: '画廊',
          safeTop: 59,
          fadeProgress: progress,
          selectedIndex: 0,
          categories: <LiquidGlassRailCategory>[
            LiquidGlassRailCategory(title: '热门', onTap: () {}),
          ],
        ),
      );
    }

    await tester.pumpWidget(app(0));
    expect(find.text('热门'), findsOneWidget);

    await tester.pumpWidget(app(1));
    expect(find.text('热门'), findsNothing);

    await tester.pumpWidget(app(0.9));
    expect(find.text('热门'), findsOneWidget);

    await tester.pumpWidget(app(0.7));
    expect(find.text('热门'), findsOneWidget);
    expect(
      tester.widget<LiquidGlassRail>(find.byKey(railKey)).fadeProgress,
      0.7,
    );
  });
}

class _ExpandedGlassHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ExpandedGlassHeaderDelegate(this.extent);

  final double extent;

  @override
  double get minExtent => 0;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) =>
      const SizedBox.expand();

  @override
  bool shouldRebuild(covariant _ExpandedGlassHeaderDelegate oldDelegate) =>
      extent != oldDelegate.extent;
}

class _TestRailDelegate extends SliverPersistentHeaderDelegate {
  _TestRailDelegate(this.layout);

  final LiquidGlassTopLayout layout;

  @override
  double get minExtent => layout.collapsedHeaderHeight;

  @override
  double get maxExtent =>
      layout.collapsedHeaderHeight +
      LiquidGlassTopBarLayout.twoRow.expandedHeight(TextScaler.noScaling);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return LiquidGlassRail(
      title: '画廊',
      safeTop: layout.safeTop,
      fadeProgress: layout.collapseProgress(
        shrinkOffset,
        LiquidGlassTopBarLayout.twoRow.expandedHeight(TextScaler.noScaling),
      ),
      selectedIndex: 0,
      categories: <LiquidGlassRailCategory>[
        LiquidGlassRailCategory(title: '热门', onTap: () {}),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _TestRailDelegate oldDelegate) => false;
}
