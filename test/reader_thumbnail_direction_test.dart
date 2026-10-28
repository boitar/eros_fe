import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/common/enum.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/image_view/common.dart';
import 'package:eros_fe/pages/image_view/controller/view_controller.dart';
import 'package:eros_fe/pages/image_view/controller/view_state.dart';
import 'package:eros_fe/pages/image_view/view/reader_layout.dart';
import 'package:eros_fe/pages/image_view/view/view_page.dart';
import 'package:eros_fe/pages/image_view/view/view_widget.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:preload_page_view/preload_page_view.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

void main() {
  testWidgets('reader controls use intrinsic height through pane resizes',
      (tester) async {
    Get.testMode = true;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final reader = _Reader(_State());
    Get.put<ViewExtController>(reader);
    addTearDown(Get.reset);
    for (final width in [382.0, 867.0, 420.0, 911.0, 382.0]) {
      final size = Size(width, 644);
      tester.view.physicalSize = size;
      final environment = AdaptiveEnvironmentSnapshot(size: size);
      await tester.pumpWidget(CupertinoApp(
        localizationsDelegates: const [L10n.delegate],
        home: AdaptiveEnvironmentScope(
          snapshot: environment,
          child: ReaderSurfaceLayout(
            environment: environment,
            content: const SizedBox.expand(),
            topBar: const SizedBox(height: 56),
            bottomBar: const ViewBottomBar(),
            showBars: true,
            topBarHeight: 56,
            bottomBarHeight: 204,
          ),
        ),
      ));
      for (var frame = 0; frame < 24; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
        // An empty fixture uses the compact half-height progress track.
        expect(tester.getSize(find.byType(ViewBottomBar)).height,
            environment.isWide ? 172 : 236);
      }
    }
    await tester.pumpWidget(const SizedBox());
    reader.photoViewController.dispose();
    reader.photoViewScaleStateController.dispose();
  });

  testWidgets('continuous reader forwards a center tap to its controls',
      (tester) async {
    Get.testMode = true;
    final state = _State()..viewMode = ViewMode.topToBottom;
    final reader = _Reader(state);
    reader.pageController = PageController(keepPage: false);
    reader.preloadPageController = PreloadPageController(keepPage: false);
    reader.extendedPageController = ExtendedPageController(keepPage: false);
    Get.put<ViewExtController>(reader);
    addTearDown(Get.reset);
    await tester.pumpWidget(const CupertinoApp(
      home: ImageGestureDetector(child: ImageView()),
    ));
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.byType(ImageView)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(reader.centerTaps, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    reader.pageController.dispose();
    reader.preloadPageController.dispose();
    reader.extendedPageController.dispose();
    reader.photoViewController.dispose();
    reader.photoViewScaleStateController.dispose();
  });

  testWidgets('reselecting a direction reconnects the mounted page controller',
      (tester) async {
    Get.testMode = true;
    final state = _State();
    final reader = _Reader(state);
    reader.pageController = PageController(keepPage: false);
    reader.preloadPageController = PreloadPageController(keepPage: false);
    reader.extendedPageController = ExtendedPageController(keepPage: false);
    Get.put<ViewExtController>(reader);
    addTearDown(Get.reset);
    await tester.pumpWidget(const CupertinoApp(home: ImageView()));
    await tester.pump();
    expect(reader.extendedPageController.hasClients, isTrue);
    final oldController = reader.extendedPageController;

    await reader.handOnViewModeChanged(state.viewMode);
    await tester.pump();
    expect(reader.extendedPageController, isNot(same(oldController)));
    expect(reader.extendedPageController.hasClients, isTrue);
    expect(find.byKey(ValueKey(reader.paginationGeneration)), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    reader.pageController.dispose();
    reader.preloadPageController.dispose();
    reader.extendedPageController.dispose();
    reader.photoViewController.dispose();
    reader.photoViewScaleStateController.dispose();
  });

  testWidgets('changing reading direction updates the mounted thumbnail rail',
      (tester) async {
    Get.testMode = true;
    final state = _State();
    final reader = _Reader(state);
    reader.pageController = PageController(keepPage: false);
    reader.preloadPageController = PreloadPageController(keepPage: false);
    reader.extendedPageController = ExtendedPageController(keepPage: false);
    Get.put<ViewExtController>(reader);
    addTearDown(Get.reset);

    await tester.pumpWidget(const CupertinoApp(
      home: Center(child: ThumbnailListView()),
    ));
    expect(
        tester
            .widget<ScrollablePositionedList>(
                find.byType(ScrollablePositionedList))
            .reverse,
        isTrue);

    for (final mode in [
      ViewMode.topToBottom,
      ViewMode.rightToLeft,
      ViewMode.leftToRight,
    ]) {
      state.viewMode = mode;
      await reader.handOnViewModeChanged(mode);
      await tester.pump();
      expect(
        tester
            .widget<ScrollablePositionedList>(
                find.byType(ScrollablePositionedList))
            .reverse,
        mode == ViewMode.rightToLeft,
      );
      expect(tester.takeException(), isNull);
    }

    await tester.pumpWidget(const SizedBox());
    reader.pageController.dispose();
    reader.preloadPageController.dispose();
    reader.extendedPageController.dispose();
    reader.photoViewController.dispose();
    reader.photoViewScaleStateController.dispose();
  });
}

class _Reader extends ViewExtController {
  _Reader(_State state) : super(state: state);

  int centerTaps = 0;

  @override
  Future<void> handOnTapCent() async {
    centerTaps++;
  }

  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  // ignore: must_call_super
  void onReady() {}
  @override
  // ignore: must_call_super
  void onClose() {}

  @override
  PageViewType get pageViewType => PageViewType.extendedImageGesturePageView;
}

class _State extends Fake implements ViewExtState {
  @override
  int currentItemIndex = 0;
  @override
  ViewMode viewMode = ViewMode.rightToLeft;
  @override
  int get fileCount => 0;
  @override
  int get pageCount => 0;
  @override
  int get pageIndex => 0;
  @override
  ViewColumnMode get columnMode => ViewColumnMode.single;
  @override
  bool get showPageInterval => false;
  @override
  bool get showThumbList => true;
  @override
  bool get autoRead => false;
  @override
  Size? viewportSize;
  @override
  bool? viewportAllowsDoublePage;
  @override
  bool bookFolded = false;
  @override
  double sliderValue = 0;
}
