import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_state.dart';
import 'package:eros_fe/pages/image_view/common.dart';
import 'package:eros_fe/pages/image_view/controller/view_controller.dart';
import 'package:eros_fe/pages/image_view/controller/view_state.dart';
import 'package:eros_fe/pages/image_view/reader_pagination.dart';
import 'package:eros_fe/pages/image_view/view/reader_desktop.dart';
import 'package:eros_fe/pages/image_view/view/view_widget.dart';
import 'package:eros_fe/widget/macos_window_chrome.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

void main() {
  late _Reader reader;
  late _State state;

  Future<void> pump(
    WidgetTester tester, {
    bool glass = false,
    TargetPlatform host = TargetPlatform.macOS,
  }) async {
    Get.testMode = true;
    PlatformCapabilities.debugHostPlatformOverride = host;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    state = _State();
    reader = _Reader(state);
    Get.put<ViewExtController>(reader);
    addTearDown(() {
      PlatformCapabilities.debugHostPlatformOverride = null;
      tester.view.reset();
      Get.reset();
    });
    const environment = AdaptiveEnvironmentSnapshot(size: Size(1280, 800));
    await tester.pumpWidget(
      CupertinoApp(
        localizationsDelegates: const [L10n.delegate],
        home: AdaptiveEnvironmentScope(
          snapshot: environment,
          child: GetBuilder<ViewExtController>(
            id: idViewBar,
            builder: (_) => ReaderDesktopLayout(
              glass: glass,
              content: const SizedBox.expand(key: ValueKey('pages')),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Rect pages(WidgetTester tester) =>
      tester.getRect(find.byKey(const ValueKey('pages')));

  testWidgets('without glass the toolbar and sidebar take their own space', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('reader-desktop-topbar')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reader-desktop-sidebar')),
      findsOneWidget,
    );
    expect(
      pages(tester),
      const Rect.fromLTRB(
        ReaderDesktopLayout.sidebarWidth,
        ReaderDesktopLayout.topBarHeight,
        1280,
        800,
      ),
    );

    // T hides the sidebar; the pages widen.
    state.showThumbList = false;
    reader.update([idViewBar]);
    await tester.pump();
    expect(find.byKey(const ValueKey('reader-desktop-sidebar')), findsNothing);
    expect(pages(tester).left, 0);

    // A click on the page hides every control and the pages fill the window.
    state.showBar = false;
    reader.update([idViewBar]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reader-desktop-topbar')), findsNothing);
    expect(
      find.byKey(const ValueKey('reader-desktop-bottombar')),
      findsNothing,
    );
    expect(pages(tester), const Rect.fromLTWH(0, 0, 1280, 800));
    expect(tester.takeException(), isNull);
  });

  testWidgets('with glass the pages fill the window under the controls', (
    tester,
  ) async {
    await pump(tester, glass: true);
    expect(pages(tester), const Rect.fromLTWH(0, 0, 1280, 800));
    expect(find.byKey(const ValueKey('reader-desktop-topbar')), findsOneWidget);
    // The filmstrip lives in the bottom panel, not a sidebar.
    expect(find.byKey(const ValueKey('reader-desktop-sidebar')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the toolbar names the spread and keeps its buttons in place', (
    tester,
  ) async {
    await pump(tester);
    final l10n = L10n.current;
    String page() => tester
        .widget<Text>(find.byKey(const ValueKey('reader-desktop-page')))
        .data!;
    expect(page(), l10n.reader_page_of('3–4', 10));
    Offset layouts() =>
        tester.getTopLeft(find.byKey(const ValueKey('reader-desktop-layouts')));
    final where = layouts();

    // Vertical scrolling dims the direction button rather than dropping it,
    // so the layout buttons do not move under the pointer.
    state.viewMode = ViewMode.topToBottom;
    reader.update([idViewTopBar, idViewBar]);
    await tester.pump();
    expect(page(), l10n.reader_page_of('3', 10));
    expect(layouts(), where);
    final direction = tester.widget<Semantics>(
      find
          .ancestor(
            of: find.byKey(
              ValueKey(
                'reader-desktop-${l10n.reading_direction}: ${l10n.left_to_right}',
              ),
            ),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(direction.properties.enabled, isFalse);
    // No page buttons beside a scrolling column.
    expect(find.byKey(const ValueKey('reader-desktop-next')), findsNothing);
  });

  testWidgets('page buttons follow the reading direction', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('reader-desktop-next')));
    await tester.tap(find.byKey(const ValueKey('reader-desktop-prev')));
    expect(reader.taps, <String>['right', 'left']);

    final l10n = L10n.current;
    String label(String key) => tester
        .widget<Semantics>(
          find
              .ancestor(
                of: find.byKey(ValueKey(key)),
                matching: find.byType(Semantics),
              )
              .first,
        )
        .properties
        .label!;
    expect(label('reader-desktop-next'), l10n.reader_next_page);

    // Right to left: the right button goes back.
    state.viewMode = ViewMode.rightToLeft;
    reader.update([idViewBar]);
    await tester.pump();
    expect(label('reader-desktop-next'), l10n.reader_previous_page);
    expect(label('reader-desktop-prev'), l10n.reader_next_page);
  });

  testWidgets('the scroll wheel turns one page per gesture', (tester) async {
    await pump(tester);
    final center = tester.getCenter(find.byKey(const ValueKey('pages')));
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(center));
    Future<void> wheel(double dy, int ms) => tester.sendEventToBinding(
      mouse.scroll(Offset(0, dy), timeStamp: Duration(milliseconds: ms)),
    );
    await wheel(60, 1000);
    // A trackpad fling sends a burst; it counts once.
    await wheel(40, 1100);
    expect(reader.turns, <String>['next']);
    await wheel(-60, 1400);
    expect(reader.turns, <String>['next', 'prev']);

    // A scrolling column scrolls itself.
    state.viewMode = ViewMode.topToBottom;
    reader.update([idViewBar]);
    await tester.pump();
    await wheel(60, 2000);
    expect(reader.turns, <String>['next', 'prev']);
  });

  group('thumbnails open at the page being read', () {
    int first(int current, {int count = 50, double viewport = 400}) =>
        ThumbnailListView.initialThumbIndex(
          current: current,
          count: count,
          viewport: viewport,
          extent: 80,
        );

    test('the current page sits in the middle of the strip', () {
      // Five thumbnails fit: page 40 (index 39) is the third.
      expect(first(39), 37);
      // Near either end the strip stays full instead of showing blank space.
      expect(first(1), 0);
      expect(first(49), 45);
      expect(first(3, count: 3), 0);
      expect(first(0, count: 0), 0);
    });

    testWidgets('a strip built later starts at the current page', (
      tester,
    ) async {
      await pump(tester);
      state.currentItemIndex = 8;
      await tester.pumpWidget(
        const CupertinoApp(
          home: Center(
            child: SizedBox(width: 300, child: ThumbnailListView()),
          ),
        ),
      );
      // 300 / 68 → four thumbnails; page 9 of 10 ends the strip.
      expect(
        tester
            .widget<ScrollablePositionedList>(
              find.byType(ScrollablePositionedList),
            )
            .initialScrollIndex,
        6,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('fullscreen keys', () {
    final calls = <String>[];
    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MacOSWindowChrome.channel, (call) async {
            calls.add(call.method);
            return null;
          });
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MacOSWindowChrome.channel, null);
      PlatformCapabilities.debugHostPlatformOverride = null;
      MacOSWindowChrome.fullscreen.value = false;
    });

    test('F toggles fullscreen; Esc leaves it before the reader', () async {
      PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.macOS;
      expect(handleDesktopReaderKey(LogicalKeyboardKey.keyF), isTrue);
      // Not fullscreen: Esc is the reader's own back.
      expect(handleDesktopReaderKey(LogicalKeyboardKey.escape), isFalse);
      MacOSWindowChrome.fullscreen.value = true;
      expect(handleDesktopReaderKey(LogicalKeyboardKey.escape), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(calls, <String>['toggleFullScreen', 'toggleFullScreen']);
      expect(handleDesktopReaderKey(LogicalKeyboardKey.keyA), isFalse);
    });

    test('the window reports whether it is fullscreen', () async {
      PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.macOS;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        MacOSWindowChrome.channel,
        (_) async => <String, Object>{
          'fullscreen': true,
          'buttons': <Object>[],
        },
      );
      await MacOSWindowChrome.initialize();
      expect(MacOSWindowChrome.fullscreen.value, isTrue);
      await messenger.handlePlatformMessage(
        'eros/window-chrome',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('changed', <String, Object>{
            'fullscreen': false,
            'buttons': <Object>[],
          }),
        ),
        (_) {},
      );
      expect(MacOSWindowChrome.fullscreen.value, isFalse);
    });

    test('Windows and phones leave the keys to the reader', () {
      for (final host in [TargetPlatform.windows, TargetPlatform.android]) {
        PlatformCapabilities.debugHostPlatformOverride = host;
        expect(handleDesktopReaderKey(LogicalKeyboardKey.keyF), isFalse);
      }
      expect(calls, isEmpty);
    });
  });
}

class _Reader extends ViewExtController {
  _Reader(_State state) : super(state: state);

  final taps = <String>[];
  final turns = <String>[];

  @override
  Future<void> tapLeft() async => taps.add('left');
  @override
  Future<void> tapRight() async => taps.add('right');
  @override
  void toNext() => turns.add('next');
  @override
  void toPrev() => turns.add('prev');

  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  // ignore: must_call_super
  void onReady() {}
  @override
  // ignore: must_call_super
  void onClose() {}
}

class _State extends Fake implements ViewExtState {
  // Real reader state is observable; the sidebar's thumbnails watch it.
  final _index = 2.obs;
  @override
  int get currentItemIndex => _index.value;
  @override
  set currentItemIndex(int value) => _index.value = value;
  @override
  ViewMode viewMode = ViewMode.leftToRight;
  @override
  bool showBar = true;
  @override
  bool showThumbList = true;
  @override
  bool autoRead = false;
  @override
  double bottomBarHeight = 0;
  @override
  double sliderValue = 2;
  @override
  int get fileCount => 10;
  @override
  ViewColumnMode get columnMode => viewMode == ViewMode.topToBottom
      ? ViewColumnMode.single
      : ViewColumnMode.oddLeft;
  @override
  ReaderPagination get pagination =>
      ReaderPagination(mode: columnMode, imageCount: fileCount);
  @override
  int get pageIndex => pagination.pageForImage(currentItemIndex);
  @override
  GalleryPageState? get pageState => null;
  @override
  LoadFrom get loadFrom => LoadFrom.gallery;
}
