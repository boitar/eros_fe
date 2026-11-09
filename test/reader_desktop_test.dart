import 'dart:io';
import 'dart:ui' show SemanticsAction;

import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_state.dart';
import 'package:eros_fe/pages/image_view/common.dart';
import 'package:eros_fe/pages/image_view/controller/view_controller.dart';
import 'package:eros_fe/pages/image_view/controller/view_state.dart';
import 'package:eros_fe/pages/image_view/reader_pagination.dart';
import 'package:eros_fe/pages/image_view/view/reader_desktop.dart';
import 'package:eros_fe/pages/image_view/view/reader_layout.dart';
import 'package:eros_fe/pages/image_view/view/view_image.dart';
import 'package:eros_fe/pages/image_view/view/view_widget.dart';
import 'package:eros_fe/widget/macos_window_chrome.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'support/gallery_save_fixture.dart';

void main() {
  late _Reader reader;
  late _State state;

  Future<void> pump(
    WidgetTester tester, {
    bool glass = false,
    TargetPlatform host = TargetPlatform.macOS,
    Size size = const Size(1280, 800),
    Locale locale = const Locale('en'),
    double textScale = 1,
    Widget? content,
    void Function(_State)? configure,
  }) async {
    Get.testMode = true;
    PlatformCapabilities.debugHostPlatformOverride = host;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    Get.put<LocaleService>(LocaleService());
    state = _State(Get.put<EhSettingService>(_Settings()));
    state.ehSettingService.liquidGlass = glass;
    configure?.call(state);
    reader = _Reader(state);
    Get.put<ViewExtController>(reader);
    addTearDown(() {
      PlatformCapabilities.debugHostPlatformOverride = null;
      tester.view.reset();
      Get.reset();
    });
    final environment = AdaptiveEnvironmentSnapshot(size: size);
    await tester.pumpWidget(
      GetCupertinoApp(
        locale: locale,
        supportedLocales: L10n.delegate.supportedLocales,
        localizationsDelegates: const [
          L10n.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: AdaptiveEnvironmentScope(
          snapshot: environment,
          child: GetBuilder<ViewExtController>(
            id: idViewBar,
            builder: (_) => ReaderDesktopLayout(
              glass: glass,
              content: content ?? const SizedBox.expand(key: ValueKey('pages')),
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

  for (final glass in [false, true]) {
    for (final locale in [const Locale('en'), const Locale('ru')]) {
      for (final host in [TargetPlatform.macOS, TargetPlatform.windows]) {
        testWidgets(
          '400px $host $locale glass=$glass keeps all controls reachable',
          (tester) async {
            await pump(
              tester,
              glass: glass,
              host: host,
              locale: locale,
              size: const Size(400, 600),
              textScale: 1.6,
              configure: (state) => state.pageState = _GalleryState(),
            );
            expect(tester.takeException(), isNull);
            for (final key in [
              'reader-layout-single',
              'reader-layout-double',
              'reader-layout-vertical',
              'reader-desktop-${L10n.current.more_actions}',
            ]) {
              final bounds = tester.getRect(find.byKey(ValueKey(key)));
              expect(bounds.left, greaterThanOrEqualTo(0));
              expect(bounds.right, lessThanOrEqualTo(400));
            }
            await tester.tap(
              find.byKey(
                ValueKey('reader-desktop-${L10n.current.more_actions}'),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text(L10n.current.save_current_image), findsOneWidget);
            expect(find.text(L10n.current.share_image), findsOneWidget);
            expect(find.text(L10n.current.reader_auto_read), findsOneWidget);
            expect(find.text(L10n.current.read_setting), findsOneWidget);
            expect(
              find.text(L10n.current.fullscreen),
              host == TargetPlatform.macOS ? findsOneWidget : findsNothing,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    for (final width in [400.0, 1280.0]) {
      testWidgets(
        '${width}px glass=$glass semantic actions operate layouts and page buttons',
        (tester) async {
          final semantics = tester.ensureSemantics();
          await pump(tester, glass: glass, size: Size(width, 800));
          void activate(String key) {
            final node = tester.getSemantics(find.byKey(ValueKey(key)));
            expect(
              node.getSemanticsData().hasAction(SemanticsAction.tap),
              isTrue,
            );
            node.owner!.performAction(node.id, SemanticsAction.tap);
          }

          activate('reader-layout-single');
          await tester.pump();
          expect(reader.columns, [ReaderColumnPreference.single]);
          activate('reader-layout-double');
          await tester.pump();
          expect(reader.columns.last, ReaderColumnPreference.oddLeft);
          activate('reader-layout-vertical');
          await tester.pump();
          expect(state.viewMode, ViewMode.topToBottom);
          activate('reader-layout-single');
          await tester.pump();
          expect(state.viewMode, isNot(ViewMode.topToBottom));
          activate('reader-desktop-next');
          activate('reader-desktop-prev');
          expect(reader.taps, ['right', 'left']);
          state.viewMode = ViewMode.rightToLeft;
          reader.update([idViewBar]);
          await tester.pump();
          activate('reader-desktop-next');
          activate('reader-desktop-prev');
          expect(reader.taps, ['right', 'left', 'right', 'left']);
          semantics.dispose();
        },
      );
    }
  }

  for (final mode in [ViewColumnMode.single, ViewColumnMode.oddLeft]) {
    for (final direction in [ViewMode.leftToRight, ViewMode.rightToLeft]) {
      testWidgets('real downloaded image wheel arbitration $mode $direction', (
        tester,
      ) async {
        final directory = Directory('tmpfile')
            .createTempSync('desktop-reader-test-');
        addTearDown(() => directory.deleteSync(recursive: true));
        final file = File('${directory.path}/page.png').absolute;
        file.writeAsBytesSync(saveCurrentPng);
        // Start and await the real file decode outside the fake clock.
        await tester.runAsync(() async {
          await pump(
            tester,
            content: mode == ViewColumnMode.single
                ? const ViewImage(imageSer: 3, enableSlideOutPage: false)
                : Builder(
                    builder: (context) => ReaderSpreadLayout(
                      environment: AdaptiveEnvironment.of(context),
                      reverse: direction == ViewMode.rightToLeft,
                      pages: const [
                        ReaderSpreadPage(
                          slot: 0,
                          aspectRatio: 1,
                          child: ViewImage(
                            imageSer: 3,
                            enableSlideOutPage: false,
                          ),
                        ),
                        ReaderSpreadPage(
                          slot: 1,
                          aspectRatio: 1,
                          child: ViewImage(
                            imageSer: 4,
                            enableSlideOutPage: false,
                          ),
                        ),
                      ],
                    ),
                  ),
            configure: (state) {
              state.loadFrom = LoadFrom.download;
              state.imagePathList = List.filled(10, file.absolute.path);
              state.viewMode = direction;
              state.columns = mode;
            },
          );
          await precacheImage(
            ExtendedFileImageProvider(file),
            tester.element(find.byType(ViewImage).first),
          );
        });
        await tester.pumpAndSettle();
        final image = tester.state<ExtendedImageGestureState>(
          find
              .byWidgetPredicate((widget) => widget is ExtendedImageGesture)
              .first,
        );
        final fitted = image.gestureDetails!.totalScale!;
        final mouse = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(
          mouse.hover(tester.getCenter(find.byType(ViewImage).first)),
        );
        Future<void> wheel(double dy, int ms) => tester.sendEventToBinding(
          mouse.scroll(Offset(0, dy), timeStamp: Duration(milliseconds: ms)),
        );

        await wheel(60, 1000);
        await wheel(40, 1100);
        expect(reader.turns, ['next']);
        expect(image.gestureDetails!.totalScale, fitted);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await wheel(200, 1500);
        await tester.pumpAndSettle();
        expect(image.gestureDetails!.totalScale, greaterThan(fitted));
        expect(reader.turns, ['next']);
        final zoomed = image.gestureDetails!.totalScale;
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await wheel(-60, 2000);
        await wheel(-40, 2100);
        expect(reader.turns, ['next', 'prev']);
        expect(image.gestureDetails!.totalScale, zoomed);

        // Local images have no long-press menu: export remains in the toolbar.
        reader.useRealExports = true;
        await tester.tap(
          find.byKey(ValueKey('reader-desktop-${L10n.current.more_actions}')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(
            CupertinoMenuItem,
            L10n.current.save_current_image,
          ),
        );
        await tester.pumpAndSettle();
        expect(reader.exportPaths, [file.absolute.path]);
        expect(find.text(L10n.current.save_current_image), findsOneWidget);
        await tester.tap(find.text(L10n.current.cancel));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(ValueKey('reader-desktop-${L10n.current.more_actions}')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(CupertinoMenuItem, L10n.current.share_image),
        );
        await tester.pumpAndSettle();
        expect(reader.exportPaths, [file.absolute.path, file.absolute.path]);
        expect(find.text(L10n.current.share_image), findsOneWidget);
        await tester.tap(find.text(L10n.current.cancel));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('vertical images scroll normally and Ctrl+wheel only zooms', (
    tester,
  ) async {
    final directory = Directory('tmpfile')
        .createTempSync('desktop-reader-vertical-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/page.png').absolute
      ..writeAsBytesSync(saveCurrentPng);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.runAsync(() async {
      await pump(
        tester,
        content: SingleChildScrollView(
          controller: scroll,
          child: const SizedBox(
            height: 1600,
            child: ViewImage(imageSer: 3, enableSlideOutPage: false),
          ),
        ),
        configure: (state) {
          state.loadFrom = LoadFrom.download;
          state.imagePathList = List.filled(10, file.absolute.path);
          state.viewMode = ViewMode.topToBottom;
          state.showThumbList = false;
        },
      );
      await precacheImage(
        ExtendedFileImageProvider(file),
        tester.element(find.byType(ViewImage)),
      );
    });
    await tester.pumpAndSettle();
    final image = tester.state<ExtendedImageGestureState>(
      find.byWidgetPredicate((widget) => widget is ExtendedImageGesture),
    );
    final fitted = image.gestureDetails!.totalScale!;
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    const position = Offset(700, 300);
    await tester.sendEventToBinding(mouse.hover(position));
    Future<void> wheel(double dy) =>
        tester.sendEventToBinding(mouse.scroll(Offset(0, dy)));
    await wheel(100);
    await tester.pumpAndSettle();
    expect(scroll.offset, 100);
    expect(image.gestureDetails!.totalScale, fitted);
    expect(reader.turns, isEmpty);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await wheel(200);
    await tester.pumpAndSettle();
    expect(image.gestureDetails!.totalScale, greaterThan(fitted));
    expect(scroll.offset, 100);
    expect(reader.turns, isEmpty);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await wheel(-60);
    await tester.pumpAndSettle();
    expect(scroll.offset, 40);
    expect(reader.turns, isEmpty);

    // Replacing the library's signal listener keeps double-tap zoom intact.
    await tester.tapAt(position);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(position);
    await tester.pumpAndSettle();
    expect(image.gestureDetails!.totalScale, closeTo(fitted, .0001));
    expect(tester.takeException(), isNull);
  });

  group('thumbnails open at the page being read', () {
    int first(int current, {int count = 50, double viewport = 400}) =>
        ThumbnailListView.initialThumbIndex(
          current: current,
          count: count,
          viewport: viewport,
          extent: 80,
        );

    test('a fraction of a thumbnail still centres the page', () {
      // 4.9 thumbnails fit (the phone's strip): page 95 of 119 is centred,
      // 93–97 around it, not second as when only whole thumbnails counted.
      expect(
        ThumbnailListView.initialThumbIndex(
          current: 94,
          count: 119,
          viewport: 333.2,
          extent: 68,
        ),
        92,
      );
    });

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
          home: Center(child: SizedBox(width: 300, child: ThumbnailListView())),
        ),
      );
      // 300 / 68 → 4.4 thumbnails; page 9 of 10 is near the end, so the
      // strip ends with page 10 rather than centring past it.
      expect(
        tester
            .widget<ScrollablePositionedList>(
              find.byType(ScrollablePositionedList),
            )
            .initialScrollIndex,
        5,
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
  final columns = <ReaderColumnPreference>[];
  final exportPaths = <String>[];
  bool useRealExports = false;

  @override
  Future<GalleryImage?> fetchThumb(
    int itemSer, {
    bool refresh = false,
    bool changeSource = false,
  }) async => null;

  @override
  void setColumnPreference(ReaderColumnPreference preference) {
    columns.add(preference);
    (vState as _State).columns = preference == ReaderColumnPreference.single
        ? ViewColumnMode.single
        : ViewColumnMode.oddLeft;
    update([idViewTopBar, idViewBar]);
  }

  @override
  Future<void> handOnViewModeChanged(ViewMode mode) async =>
      update([idViewTopBar, idViewBar]);

  @override
  void tapSave(BuildContext context) {
    exportPaths.add(vState.imagePathList[vState.currentItemIndex]);
    if (useRealExports) {
      super.tapSave(context);
    }
  }

  @override
  void tapShare(BuildContext context) {
    exportPaths.add(vState.imagePathList[vState.currentItemIndex]);
    if (useRealExports) {
      super.tapShare(context);
    }
  }

  @override
  Future<void> onLoadCompleted(int ser) async {}

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
  _State(this.ehSettingService);
  @override
  final EhSettingService ehSettingService;
  // Real reader state is observable; the sidebar's thumbnails watch it.
  final _index = 2.obs;
  @override
  int get currentItemIndex => _index.value;
  @override
  set currentItemIndex(int value) => _index.value = value;
  @override
  ViewMode get viewMode => ehSettingService.viewMode.value;
  @override
  set viewMode(ViewMode value) => ehSettingService.viewMode.value = value;
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
  ViewColumnMode columns = ViewColumnMode.oddLeft;
  @override
  ViewColumnMode get columnMode =>
      viewMode == ViewMode.topToBottom ? ViewColumnMode.single : columns;
  @override
  ReaderPagination get pagination =>
      ReaderPagination(mode: columnMode, imageCount: fileCount);
  @override
  int get pageIndex => pagination.pageForImage(currentItemIndex);
  @override
  GalleryPageState? pageState;
  @override
  LoadFrom loadFrom = LoadFrom.gallery;
  @override
  List<String> imagePathList = [];
  @override
  final Map<int, Size> imageSizeMap = {};
  @override
  final Map<int, double> readerZoomRatios = {};
  @override
  final List<double> doubleTapScales = [1, 2, 3];
  @override
  bool fade = false;
  @override
  bool needRebuild = false;
  @override
  String? get gid => 'offline-desktop-fixture';
}

class _Settings extends EhSettingService {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _GalleryState extends Fake implements GalleryPageState {
  @override
  String get displayTitle =>
      'A long gallery title that must leave the desktop controls reachable';
}
