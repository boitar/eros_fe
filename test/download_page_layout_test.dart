import 'package:eros_fe/adaptive/native_top_header.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/pages/tab/view/download_page.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:eros_fe/widget/scroll_edge_effect.dart';
import 'package:eros_fe/widget/scroll_edge_progress.dart';
import 'package:eros_fe/widget/segmented_rail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('eros/accessibility-settings'),
          (_) async => null,
        );
    (LiquidGlassAccessibilitySettings.reduceTransparency
                as ValueNotifier<bool?>)
            .value =
        false;
  });

  tearDown(() async {
    await LiquidGlassAccessibilitySettings.stopWatching();
  });

  Future<void> mount(
    WidgetTester tester, {
    required Size size,
    required LiquidGlassTopBarLayout layout,
    double scale = 1,
    bool dark = false,
    bool export = false,
    LiquidGlassRailAction? leading,
    String title = 'Downloads',
    ValueChanged<String>? onTaskTap,
    VoidCallback? onExport,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      CupertinoApp(
        theme: CupertinoThemeData(
          brightness: dark ? Brightness.dark : Brightness.light,
        ),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: EdgeInsets.only(
              top: size.width < size.height ? 59 : 0,
              bottom: 90,
            ),
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: _Downloads(
            layout: layout,
            leading: leading,
            title: title,
            onTaskTap: onTaskTap,
            onExport: export ? onExport ?? () {} : null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final hasLeading in [false, true]) {
    for (final hasExport in [false, true]) {
      testWidgets(
        'two-row title reserves symmetric space, leading=$hasLeading export=$hasExport',
        (tester) async {
          const title = 'A deliberately long download page title';
          await mount(
            tester,
            size: const Size(320, 600),
            layout: LiquidGlassTopBarLayout.twoRow,
            title: title,
            leading: hasLeading
                ? LiquidGlassRailAction(
                    icon: CupertinoIcons.chevron_back,
                    label: 'Back',
                    onPressed: () {},
                  )
                : null,
            export: hasExport,
          );
          final titleFinder = find.text(title);
          final position = tester.widget<Positioned>(
            find
                .ancestor(of: titleFinder, matching: find.byType(Positioned))
                .first,
          );
          final expectedInset = hasLeading || hasExport ? 60.0 : 16.0;
          expect(position.left, expectedInset);
          expect(position.right, expectedInset);
          final titleRect = tester.getRect(titleFinder);
          expect(titleRect.center.dx, closeTo(160, 0.5));
          if (hasLeading) {
            expect(
              titleRect.left,
              greaterThan(
                tester.getRect(find.byIcon(CupertinoIcons.chevron_back)).right,
              ),
            );
          }
          if (hasExport) {
            expect(
              titleRect.right,
              lessThan(
                tester
                    .getRect(find.byIcon(CupertinoIcons.arrow_up_arrow_down))
                    .left,
              ),
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('inline categories avoid the leading and trailing actions', (
    tester,
  ) async {
    await mount(
      tester,
      size: const Size(320, 600),
      layout: LiquidGlassTopBarLayout.inline,
      leading: LiquidGlassRailAction(
        icon: CupertinoIcons.chevron_back,
        label: 'Back',
        onPressed: () {},
      ),
      export: true,
    );
    final categories = tester.getRect(
      find.byKey(const ValueKey<String>('liquid-glass-category-selection')),
    );
    expect(
      categories.left,
      greaterThan(
        tester.getRect(find.byIcon(CupertinoIcons.chevron_back)).right,
      ),
    );
    expect(
      categories.right,
      lessThan(
        tester.getRect(find.byIcon(CupertinoIcons.arrow_up_arrow_down)).left,
      ),
    );
    expect(find.text('Downloads'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final layout in LiquidGlassTopBarLayout.values) {
    for (final size in const [Size(320, 600), Size(393, 852), Size(852, 393)]) {
      testWidgets('download viewport fills $size with $layout', (tester) async {
        String? tapped;
        await mount(
          tester,
          size: size,
          layout: layout,
          onTaskTap: (value) => tapped = value,
        );
        expect(tester.getSize(find.byType(PageView)), size);
        final header = tester.getRect(find.byType(DownloadGlassHeader));
        final first = tester.getRect(find.byKey(const ValueKey('task-0-0')));
        expect(first.top, greaterThanOrEqualTo(header.bottom + 12));
        expect(first.bottom, lessThan(size.height));
        await tester.tap(find.byKey(const ValueKey('task-0-1')));
        expect(tapped, 'task-0-1');
        await tester.drag(find.byType(PageView), const Offset(0, -420));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('task-0-5')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('download categories stay adjacent and centered with $layout', (
      tester,
    ) async {
      var exported = false;
      await mount(
        tester,
        size: const Size(393, 852),
        layout: layout,
        export: true,
        onExport: () => exported = true,
      );
      final gallery = tester.getRect(find.text('Gallery'));
      final archive = tester.getRect(find.text('Archive'));
      expect(archive.left - gallery.right, lessThan(45));
      final surface = tester.getRect(
        find.byKey(const ValueKey<String>('liquid-glass-category-selection')),
      );
      expect(surface.width, lessThan(320));
      expect(surface.center.dx, closeTo(196.5, 1));
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('task-1-1')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(CupertinoIcons.arrow_up_arrow_down));
      expect(exported, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'download large text keeps a full short viewport with $layout',
      (tester) async {
        await mount(
          tester,
          size: const Size(320, 380),
          layout: layout,
          scale: 2.4,
          dark: true,
        );
        expect(tester.getSize(find.byType(PageView)), const Size(320, 380));
        final surface = tester.getRect(
          find.byKey(const ValueKey<String>('liquid-glass-category-selection')),
        );
        expect(surface.width, lessThanOrEqualTo(304));
        await tester.ensureVisible(find.text('Archive'));
        await tester.tap(find.text('Archive'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('task-1-0')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('page swipes preserve download scroll position', (tester) async {
    await mount(
      tester,
      size: const Size(393, 852),
      layout: LiquidGlassTopBarLayout.inline,
    );
    await tester.drag(find.byType(PageView), const Offset(0, -520));
    await tester.pumpAndSettle();
    final before = tester.getRect(find.byKey(const ValueKey('task-0-6')));
    await tester.drag(find.byType(PageView), const Offset(-360, 0));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('task-1-1')).hitTestable(),
      findsOneWidget,
    );
    await tester.drag(find.byType(PageView), const Offset(360, 0));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const ValueKey('task-0-6'))), before);
    expect(tester.takeException(), isNull);
  });

  for (final (platform, size, gap, tail) in [
    (TargetPlatform.android, const Size(393, 852), 12.0, 20.0),
    (TargetPlatform.iOS, const Size(393, 852), 12.0, 24.0),
    (TargetPlatform.iOS, const Size(820, 1180), 12.0, 28.0),
    (TargetPlatform.windows, const Size(820, 900), 12.0, 16.0),
  ]) {
    testWidgets('glass download tracks selected list on $platform $size', (
      tester,
    ) async {
      PlatformCapabilities.debugHostPlatformOverride = platform;
      addTearDown(() => PlatformCapabilities.debugHostPlatformOverride = null);
      await mount(tester, size: size, layout: LiquidGlassTopBarLayout.twoRow);
      final header = tester.getRect(find.byType(DownloadGlassHeader));
      expect(
        tester.getRect(find.byKey(const ValueKey('task-0-0'))).top,
        header.bottom + gap,
      );
      const key = ValueKey<String>('liquid-glass-top-scrim');
      LinearGradient gradient() =>
          (tester.widget<DecoratedBox>(find.byKey(key)).decoration
                      as BoxDecoration)
                  .gradient!
              as LinearGradient;
      final mobile = !PlatformCapabilities.isDesktop;
      expect(find.byType(SoftScrollEdgeEffect), findsNothing);
      expect(gradient().colors.first.a, closeTo(mobile ? .32 : 0, .001));
      await tester.drag(find.byType(PageView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(gradient().colors.first.a, closeTo(mobile ? .32 : .92, .001));
      if (mobile) {
        final state = tester.state<_DownloadsState>(find.byType(_Downloads));
        state.edge.update(
          FixedScrollMetrics(
            minScrollExtent: 0,
            maxScrollExtent: 1000,
            pixels: LiquidGlassEdgeTokens.reveal,
            viewportDimension: size.height,
            axisDirection: AxisDirection.down,
            devicePixelRatio: 1,
          ),
        );
        await tester.pump();
        final effect = tester.widget<SoftScrollEdgeEffect>(
          find.byType(SoftScrollEdgeEffect),
        );
        expect(effect.inset, 59);
        expect(effect.bars, 94);
        expect(effect.tail, tail);
        expect(effect.strength, 1);
      }
      if (platform == TargetPlatform.windows) {
        expect(tester.getRect(find.byKey(key)).bottom, header.bottom + tail);
      }
      final state = tester.state<_DownloadsState>(find.byType(_Downloads));
      state.pages.jumpToPage(1);
      await tester.pumpAndSettle();
      expect(gradient().colors.first.a, closeTo(mobile ? .32 : 0, .001));
      state.pages.jumpToPage(0);
      await tester.pumpAndSettle();
      expect(gradient().colors.first.a, closeTo(mobile ? .32 : .92, .001));
    });
  }

  testWidgets('native shell download uses the shared rail and soft edge', (
    tester,
  ) async {
    const size = Size(393, 852);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pages = PageController();
    addTearDown(pages.dispose);
    var selected = <int>[];
    await tester.pumpWidget(
      CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: size,
            padding: EdgeInsets.only(top: 59, bottom: 34),
            viewPadding: EdgeInsets.only(top: 59, bottom: 34),
            disableAnimations: true,
          ),
          child: DownloadNativeScaffold(
            rail: SegmentedRail(
              compact: true,
              selectedIndex: 0,
              pageController: pages,
              items: [
                LiquidGlassRailCategory(
                  title: 'Gallery',
                  onTap: () => selected.add(0),
                ),
                LiquidGlassRailCategory(
                  title: 'Archive',
                  onTap: () => selected.add(1),
                ),
              ],
            ),
            child: PageView.builder(
              controller: pages,
              itemCount: 2,
              itemBuilder: (_, page) => _TaskList(page: page),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final header = tester.getRect(find.byType(NativeTopTabHeader));
    expect(header.top, 0);
    expect(header.height, 59 + 44);
    expect(find.byType(SoftScrollEdgeEffect), findsOneWidget);
    final gallery = tester.getRect(
      find.byKey(const ValueKey<String>('segmented-rail-segment-0')),
    );
    final archive = tester.getRect(
      find.byKey(const ValueKey<String>('segmented-rail-segment-1')),
    );
    expect(gallery.width, archive.width);
    expect(gallery.width, lessThanOrEqualTo(144));
    expect((gallery.left + archive.right) / 2, closeTo(size.width / 2, 0.5));
    final first = tester.getRect(find.byKey(const ValueKey('task-0-0')));
    expect(first.top, header.bottom + 8);
    expect(
      tester
          .widget<SoftScrollEdgeEffect>(find.byType(SoftScrollEdgeEffect))
          .strength,
      0,
    );
    await tester.tap(find.text('Archive'));
    expect(selected, [1]);
  });

  for (final tablet in [false, true]) {
    testWidgets('native download gap and edge follow the selected task list, '
        'tablet=$tablet', (tester) async {
      final size = tablet ? const Size(1024, 1366) : const Size(393, 852);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final edge = ScrollEdgeProgressController();
      final pages = PageController();
      addTearDown(edge.dispose);
      addTearDown(pages.dispose);
      var selected = 0;
      await tester.pumpWidget(
        CupertinoApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              padding: const EdgeInsets.only(top: 59),
              viewPadding: const EdgeInsets.only(top: 59),
            ),
            child: DownloadNativeScaffold(
              edgeProgress: edge,
              rail: const SizedBox.expand(),
              child: StatefulBuilder(
                builder: (context, setState) {
                  return ScrollEdgeProgressListener(
                    controller: edge,
                    activePage: selected,
                    child: PageView(
                      controller: pages,
                      onPageChanged: (page) {
                        edge.selectPage(page);
                        setState(() => selected = page);
                      },
                      children: [
                        for (var page = 0; page < 2; page++)
                          ScrollEdgeProgressListener(
                            controller: edge,
                            page: page,
                            child: _TaskList(page: page),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final header = tester.getRect(find.byType(NativeTopTabHeader));
      expect(
        tester.getRect(find.byKey(const ValueKey('task-0-0'))).top,
        header.bottom + (tablet ? 12 : 8),
      );
      expect(edge.value, 0);
      await tester.drag(find.byType(PageView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(edge.value, 1);
      expect(
        tester
            .widget<SoftScrollEdgeEffect>(find.byType(SoftScrollEdgeEffect))
            .tail,
        tablet ? 28 : 24,
      );
      pages.jumpToPage(1);
      await tester.pumpAndSettle();
      expect(edge.value, 0);
      pages.jumpToPage(0);
      await tester.pumpAndSettle();
      expect(edge.value, 1);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

class _Downloads extends StatefulWidget {
  const _Downloads({
    required this.layout,
    this.onTaskTap,
    this.onExport,
    this.leading,
    this.title = 'Downloads',
  });

  final LiquidGlassTopBarLayout layout;
  final ValueChanged<String>? onTaskTap;
  final VoidCallback? onExport;
  final LiquidGlassRailAction? leading;
  final String title;

  @override
  State<_Downloads> createState() => _DownloadsState();
}

class _DownloadsState extends State<_Downloads> {
  final pages = PageController();
  late final edge = ScrollEdgeProgressController(
    revealDistance: LiquidGlassEdgeTokens.reveal,
  );
  var selected = 0;

  @override
  void dispose() {
    pages.dispose();
    edge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DownloadGlassScaffold(
    edgeProgress: edge,
    header: DownloadGlassHeader(
      title: widget.title,
      galleryLabel: 'Gallery',
      archiverLabel: 'Archive',
      safeTop: MediaQuery.paddingOf(context).top,
      layout: widget.layout,
      selectedIndex: selected,
      pageController: pages,
      onSelected: pages.jumpToPage,
      onExport: widget.onExport,
      leading: widget.leading,
    ),
    child: ScrollEdgeProgressListener(
      controller: edge,
      activePage: selected,
      child: PageView.builder(
        key: const PageStorageKey<String>('download-pages'),
        controller: pages,
        itemCount: 2,
        onPageChanged: (value) {
          edge.selectPage(value);
          setState(() => selected = value);
        },
        itemBuilder: (_, page) => ScrollEdgeProgressListener(
          controller: edge,
          page: page,
          child: _TaskList(page: page, onTaskTap: widget.onTaskTap),
        ),
      ),
    ),
  );
}

class _TaskList extends StatefulWidget {
  const _TaskList({required this.page, this.onTaskTap});

  final int page;
  final ValueChanged<String>? onTaskTap;

  @override
  State<_TaskList> createState() => _TaskListState();
}

class _TaskListState extends State<_TaskList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView.builder(
      key: PageStorageKey<String>('download-task-list-${widget.page}'),
      padding: MediaQuery.paddingOf(context),
      itemCount: 30,
      itemBuilder: (_, row) {
        final id = 'task-${widget.page}-$row';
        return GestureDetector(
          key: ValueKey(id),
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onTaskTap?.call(id),
          child: SizedBox(height: 100, child: Center(child: Text(id))),
        );
      },
    );
  }
}
