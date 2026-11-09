import 'dart:io';

import 'package:archive_async/archive_async.dart';
import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/controller/gallerycache_controller.dart';
import 'package:eros_fe/common/enum.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_controller.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_state.dart';
import 'package:eros_fe/pages/image_view/common.dart';
import 'package:eros_fe/pages/image_view/controller/view_controller.dart';
import 'package:eros_fe/pages/image_view/controller/view_state.dart';
import 'package:eros_fe/pages/image_view/view/image_list_view.dart';
import 'package:eros_fe/pages/image_view/view/image_page_view.dart';
import 'package:eros_fe/pages/image_view/view/view_image.dart';
import 'package:eros_fe/pages/image_view/view/view_page.dart';
import 'package:eros_fe/widget/macos_window_chrome.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';

import 'support/gallery_save_fixture.dart';
import 'support/waterfall_fixture.dart';

void main() {
  const modes = [
    (ViewColumnMode.single, ViewMode.leftToRight),
    (ViewColumnMode.single, ViewMode.rightToLeft),
    (ViewColumnMode.oddLeft, ViewMode.leftToRight),
    (ViewColumnMode.oddLeft, ViewMode.rightToLeft),
    (ViewColumnMode.single, ViewMode.topToBottom),
  ];
  for (final host in [TargetPlatform.macOS, TargetPlatform.windows]) {
    for (final source in LoadFrom.values) {
      for (final (columns, direction) in modes) {
        testWidgets('real ViewPage $host $source $columns $direction wheel', (
          tester,
        ) async {
          final fixture = await _Harness.open(
            tester,
            host: host,
            source: source,
            columns: columns,
            direction: direction,
          );
          final reader = fixture.reader;
          final state = reader.vState;
          final vertical = direction == ViewMode.topToBottom;
          expect(find.byType(ViewKeyboardListener), findsOneWidget);
          expect(find.byType(ImageView), findsOneWidget);
          expect(
            find.byType(ImageListView),
            vertical ? findsOneWidget : findsNothing,
          );
          expect(
            find.byType(ImagePageView),
            vertical ? findsNothing : findsOneWidget,
          );
          if (vertical || columns != ViewColumnMode.single) {
            // Exercise the actual PhotoView mode:none product branch.
            expect(find.byType(PhotoView), findsWidgets);
            expect(
              tester
                  .widgetList<ViewImage>(find.byType(ViewImage))
                  .every((image) => image.mode == ExtendedImageMode.none),
              isTrue,
            );
          }

          final initialPage = state.pageIndex;
          final fitted = fixture.scale();
          final beforeZoom = fixture.scrollPositions();
          final photo = fixture.photoController();
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await fixture.wheel(200);
          await tester.pumpAndSettle();
          expect(fixture.scale(), greaterThan(fitted));
          expect(state.pageIndex, initialPage);
          expect(fixture.scrollPositions(), beforeZoom);
          // A long reverse wheel is clamped at the backend's fitted scale.
          await fixture.wheel(-10000);
          await tester.pumpAndSettle();
          expect(fixture.scale(), closeTo(fitted, .0001));
          expect(state.pageIndex, initialPage);
          expect(fixture.scrollPositions(), beforeZoom);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

          await fixture.wheel(vertical ? 100 : 60);
          await tester.pump(const Duration(milliseconds: 300));
          // The real ViewImage keeps a short loading placeholder while the
          // newly selected page is decoded; advance that timer explicitly.
          await tester.pump(const Duration(milliseconds: 300));
          if (vertical) {
            expect(fixture.scrollPositions(), isNot(beforeZoom));
            expect(photo!.scale, closeTo(fitted, .0001));
            await fixture.wheel(1600);
            await tester.pump(const Duration(milliseconds: 300));
            await tester.pump(const Duration(milliseconds: 300));
            expect(state.pageIndex, greaterThan(initialPage));
            expect(photo.scale, closeTo(fitted, .0001));
          } else {
            expect(state.pageIndex, initialPage + 1);
          }
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final backend in [
    PageViewType.photoView,
    PageViewType.preloadPhotoView,
  ]) {
    testWidgets('real single page $backend also owns Ctrl+wheel', (
      tester,
    ) async {
      final fixture = await _Harness.open(tester, backend: backend);
      final initial = fixture.reader.vState.pageIndex;
      final fitted = fixture.scale();
      final positions = fixture.scrollPositions();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await fixture.wheel(200);
      await tester.pumpAndSettle();
      expect(fixture.scale(), greaterThan(fitted));
      expect(fixture.reader.vState.pageIndex, initial);
      expect(fixture.scrollPositions(), positions);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await fixture.wheel(60);
      await tester.pumpAndSettle();
      expect(fixture.reader.vState.pageIndex, initial + 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final glass in [false, true]) {
    for (final fullscreen in [false, true]) {
      testWidgets('real keyboard menu glass=$glass fullscreen=$fullscreen', (
        tester,
      ) async {
        final fixture = await _Harness.open(tester, glass: glass);
        final reader = fixture.reader;
        final initialPage = reader.vState.pageIndex;
        MacOSWindowChrome.fullscreen.value = fullscreen;
        final fullscreenCalls = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          MacOSWindowChrome.channel,
          (call) async {
            fullscreenCalls.add(call.method);
            if (call.method == 'toggleFullScreen') {
              MacOSWindowChrome.fullscreen.value =
                  !MacOSWindowChrome.fullscreen.value;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            MacOSWindowChrome.channel,
            null,
          ),
        );

        await tester.tap(
          find.byKey(ValueKey('reader-desktop-${L10n.current.more_actions}')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CupertinoMenuItem), findsWidgets);
        expect(reader.keyboardShortcutsSuspended, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
        await tester.pumpAndSettle();
        expect(reader.vState.pageIndex, initialPage);
        expect(fullscreenCalls, isEmpty);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
        // Keys during the closing animation must remain isolated too.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(CupertinoMenuItem), findsNothing);
        expect(reader.keyboardShortcutsSuspended, isFalse);
        expect(find.byType(ViewPage), findsOneWidget);
        expect(reader.vState.pageIndex, initialPage);
        expect(MacOSWindowChrome.fullscreen.value, fullscreen);
        expect(fullscreenCalls, isEmpty);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(reader.vState.pageIndex, initialPage + 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        if (fullscreen) {
          expect(fullscreenCalls, ['toggleFullScreen']);
          expect(find.byType(ViewPage), findsOneWidget);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
        }
        expect(find.byType(ViewPage), findsNothing);
        expect(find.text('Library root'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

class _Harness {
  _Harness(this.tester, this.reader);

  final WidgetTester tester;
  final _Reader reader;
  Duration _clock = const Duration(seconds: 1);
  static const position = Offset(450, 300);

  static Future<_Harness> open(
    WidgetTester tester, {
    TargetPlatform host = TargetPlatform.macOS,
    LoadFrom source = LoadFrom.download,
    ViewColumnMode columns = ViewColumnMode.single,
    ViewMode direction = ViewMode.leftToRight,
    PageViewType backend = PageViewType.extendedImageGesturePageView,
    bool glass = false,
  }) async {
    registerWaterfallFixture();
    PlatformCapabilities.debugHostPlatformOverride = host;
    const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProvider,
      (call) async => Directory('tmpfile/reader-path-provider')
          .absolute
          .path,
    );
    Get.put<GalleryCacheController>(_Cache());
    final settings = Get.find<EhSettingService>()
      ..liquidGlass = glass
      ..viewMode.value = direction
      ..pageViewType = backend
      ..turnPageAnimations = false
      ..enableSlideOutPage = false
      ..preloadImage.value = 0;
    settings.setManualReaderColumnMode(columns);
    final directory = Directory('tmpfile')
        .createTempSync('reader-real-backend-');
    final file = File('${directory.path}/page.png').absolute
      ..writeAsBytesSync(saveCurrentPng);
    const count = 12;
    final gallery = GalleryPageState()
      ..galleryProvider = const GalleryProvider(
        gid: '991',
        filecount: '$count',
        englishTitle: 'Offline reader backend fixture',
        showKey: 'offline',
      );
    gallery.images.assignAll([
      for (var ser = 1; ser <= count; ser++)
        GalleryImage(
          ser: ser,
          filePath: file.path,
          imageWidth: 12,
          imageHeight: 12,
        ),
    ]);
    Get.put<GalleryPageController>(_Gallery(gallery), tag: 'backend-fixture');
    final repository = ViewRepository(
      gid: '991',
      index: 2,
      loadType: source,
      files: List.filled(count, file.path),
      galleryControllerTag: 'backend-fixture',
      asyncArchives: [
        for (var ser = 1; ser <= count; ser++) _Archive('$ser.png'),
      ],
    );
    final state = _State(repository: repository)
      ..showBar = true
      ..showThumbList = false
      ..syncThumbList = false
      ..fade = false;
    state.showPageInterval = false;
    state.imageSizeMap.addAll({
      for (var ser = 1; ser <= count; ser++) ser: const Size(12, 12),
    });
    final reader = Get.put<ViewExtController>(_Reader(state, file)) as _Reader;
    // The production session persists the reading position with a 3 second
    // debounce. This fixture asserts navigation directly and owns teardown,
    // so disable that external persistence worker before mounting the page.
    state.dispose();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      Get.reset();
      await tester.pump(const Duration(seconds: 1));
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProvider, null);
      PlatformCapabilities.debugHostPlatformOverride = null;
      MacOSWindowChrome.fullscreen.value = false;
      tester.view.reset();
      directory.deleteSync(recursive: true);
    });
    await tester.pumpWidget(
      GetCupertinoApp(
        locale: const Locale('en'),
        supportedLocales: L10n.delegate.supportedLocales,
        localizationsDelegates: const [
          L10n.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        builder: (_, child) => AdaptiveEnvironmentScope(
          snapshot: const AdaptiveEnvironmentSnapshot(size: Size(1280, 800)),
          child: child!,
        ),
        home: const CupertinoPageScaffold(child: Text('Library root')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await precacheImage(
        ExtendedFileImageProvider(file),
        tester.element(find.text('Library root')),
      );
      Get.to<void>(() => const ViewPage(), transition: Transition.noTransition);
      await tester.pump();
    });
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    return _Harness(tester, reader);
  }

  Future<void> wheel(
    double dy, {
    Duration elapsed = const Duration(milliseconds: 400),
  }) async {
    _clock += elapsed;
    await tester.sendEventToBinding(
      const PointerHoverEvent(
        pointer: 1,
        kind: PointerDeviceKind.mouse,
        position: position,
      ),
    );
    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: position,
        scrollDelta: Offset(0, dy),
        timeStamp: _clock,
      ),
    );
  }

  PhotoViewControllerBase? photoController() {
    final photos = find.byType(PhotoView, skipOffstage: false).evaluate();
    return photos.isEmpty
        ? null
        : (photos.first.widget as PhotoView).controller;
  }

  double scale() {
    final gestures = find.byWidgetPredicate(
      (widget) => widget is ExtendedImageGesture,
      skipOffstage: false,
    );
    if (gestures.evaluate().isNotEmpty) {
      return tester
          .state<ExtendedImageGestureState>(gestures.first)
          .gestureDetails!
          .totalScale!;
    }
    return photoController()!.scale!;
  }

  Map<ScrollableState, double> scrollPositions() => {
    for (final element in find.byType(Scrollable).evaluate())
      (element as StatefulElement).state as ScrollableState:
          (element.state as ScrollableState).position.pixels,
  };
}

class _State extends ViewExtState {
  _State({required super.repository});

  @override
  void saveLastIndex({bool saveToStore = false}) {}
}

class _Reader extends ViewExtController {
  _Reader(_State state, this.file) : super(state: state);

  final File file;

  @override
  // Avoid the production delayed system-bar cleanup in a widget fixture.
  // The test owns the controller lifecycle and tears down the tree directly.
  void onClose() {
    vState.speedTimer?.cancel();
    vState.dispose();
  }

  @override
  // Suppress network/orientation startup only; paging, lifecycle and zoom are real.
  // ignore: must_call_super
  void onReady() {}

  @override
  Future<GalleryImage?> fetchImage(
    int itemSer, {
    bool changeSource = false,
  }) async => vState.imageMap?[itemSer];

  @override
  Future<File> getArchiveFile(String? gid, AsyncArchiveFile file) async =>
      this.file;

  @override
  Future<void> unsetFullscreen() async {}
}

mixin _InertLifecycle {
  final onStart = InternalFinalCallback<void>(callback: () {});
  final onDelete = InternalFinalCallback<void>(callback: () {});
}

class _Cache extends Fake
    with _InertLifecycle
    implements GalleryCacheController {
  @override
  void saveAll() {}
}

class _Gallery extends Fake
    with _InertLifecycle
    implements GalleryPageController {
  _Gallery(this.gState);

  @override
  final GalleryPageState gState;

  @override
  GalleryImage? uptImageBySer({
    required int ser,
    required ImageCallback imageCallback,
  }) => imageCallback(gState.imageMap[ser]!);
}

class _Archive extends Fake implements AsyncArchiveFile {
  _Archive(this.name);

  @override
  final String name;
}
