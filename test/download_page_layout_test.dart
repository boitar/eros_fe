import 'package:eros_fe/pages/tab/view/download_page.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
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
        .value = false;
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
    ValueChanged<String>? onTaskTap,
    VoidCallback? onExport,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(CupertinoApp(
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
          onTaskTap: onTaskTap,
          onExport: export ? onExport ?? () {} : null,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final layout in LiquidGlassTopBarLayout.values) {
    for (final size in const [
      Size(320, 600),
      Size(393, 852),
      Size(852, 393),
    ]) {
      testWidgets('download viewport fills $size with $layout', (tester) async {
        String? tapped;
        await mount(tester,
            size: size, layout: layout, onTaskTap: (value) => tapped = value);
        expect(tester.getSize(find.byType(PageView)), size);
        final header = tester.getRect(find.byType(DownloadGlassHeader));
        final first = tester.getRect(find.byKey(const ValueKey('task-0-0')));
        expect(first.top, greaterThanOrEqualTo(header.bottom + 12));
        expect(first.bottom, lessThan(size.height));
        await tester.tap(find.byKey(const ValueKey('task-0-1')));
        expect(tapped, 'task-0-1');
        await tester.drag(find.byType(PageView), const Offset(0, -420));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('task-0-5')).hitTestable(),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('download categories stay adjacent and centered with $layout',
        (tester) async {
      var exported = false;
      await mount(tester,
          size: const Size(393, 852),
          layout: layout,
          export: true,
          onExport: () => exported = true);
      final gallery = tester.getRect(find.text('Gallery'));
      final archive = tester.getRect(find.text('Archive'));
      expect(archive.left - gallery.right, lessThan(45));
      final surface = tester.getRect(find
          .byKey(const ValueKey<String>('liquid-glass-category-selection')));
      expect(surface.width, lessThan(320));
      expect(surface.center.dx, closeTo(196.5, 1));
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('task-1-1')).hitTestable(), findsOneWidget);
      await tester.tap(find.byIcon(CupertinoIcons.arrow_up_arrow_down));
      expect(exported, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('download large text keeps a full short viewport with $layout',
        (tester) async {
      await mount(tester,
          size: const Size(320, 380), layout: layout, scale: 2.4, dark: true);
      expect(tester.getSize(find.byType(PageView)), const Size(320, 380));
      final surface = tester.getRect(find
          .byKey(const ValueKey<String>('liquid-glass-category-selection')));
      expect(surface.width, lessThanOrEqualTo(304));
      await tester.ensureVisible(find.text('Archive'));
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('task-1-0')).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('page swipes preserve download scroll position', (tester) async {
    await mount(tester,
        size: const Size(393, 852), layout: LiquidGlassTopBarLayout.inline);
    await tester.drag(find.byType(PageView), const Offset(0, -520));
    await tester.pumpAndSettle();
    final before = tester.getRect(find.byKey(const ValueKey('task-0-6')));
    await tester.drag(find.byType(PageView), const Offset(-360, 0));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('task-1-1')).hitTestable(), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(360, 0));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const ValueKey('task-0-6'))), before);
    expect(tester.takeException(), isNull);
  });
}

class _Downloads extends StatefulWidget {
  const _Downloads({required this.layout, this.onTaskTap, this.onExport});

  final LiquidGlassTopBarLayout layout;
  final ValueChanged<String>? onTaskTap;
  final VoidCallback? onExport;

  @override
  State<_Downloads> createState() => _DownloadsState();
}

class _DownloadsState extends State<_Downloads> {
  final pages = PageController();
  var selected = 0;

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DownloadGlassScaffold(
        header: DownloadGlassHeader(
          title: 'Downloads',
          galleryLabel: 'Gallery',
          archiverLabel: 'Archive',
          safeTop: MediaQuery.paddingOf(context).top,
          layout: widget.layout,
          selectedIndex: selected,
          pageController: pages,
          onSelected: pages.jumpToPage,
          onExport: widget.onExport,
        ),
        child: PageView.builder(
          key: const PageStorageKey<String>('download-pages'),
          controller: pages,
          itemCount: 2,
          onPageChanged: (value) => setState(() => selected = value),
          itemBuilder: (_, page) => _TaskList(
            page: page,
            onTaskTap: widget.onTaskTap,
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
          child: SizedBox(
            height: 100,
            child: Center(child: Text(id)),
          ),
        );
      },
    );
  }
}
