import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/pages/image_view/common.dart';
import 'package:eros_fe/pages/image_view/controller/view_controller.dart';
import 'package:eros_fe/pages/image_view/controller/view_state.dart';
import 'package:eros_fe/pages/image_view/reader_pagination.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:preload_page_view/preload_page_view.dart';

void main() {
  test('reader zoom is stored relative to the fitted scale', () {
    Get.testMode = true;
    Get.put<LocaleService>(LocaleService());
    addTearDown(Get.reset);
    final state = _State(EhSettingService());
    final reader = ViewExtController(state: state);

    reader.recordReaderZoom(
      imageSer: 6,
      totalScale: 2.5,
      fittedScale: 1.25,
    );
    expect(state.readerZoomRatios[6], 2.0);
    expect(reader.readerZoomRatioFor(6), 2.0);

    reader.recordReaderZoom(
      imageSer: 6,
      totalScale: 1.25,
      fittedScale: 1.25,
    );
    expect(state.readerZoomRatios.containsKey(6), isFalse);
    expect(reader.readerZoomRatioFor(6), 1.0);
  });

  testWidgets('reader discards stale callbacks during 20 rapid viewport remaps',
      (tester) async {
    Get.testMode = true;
    Get.put<LocaleService>(LocaleService());
    addTearDown(Get.reset);
    final state = _State(EhSettingService());
    final reader = ViewExtController(state: state);
    reader.recordReaderZoom(
      imageSer: 6,
      totalScale: 3.0,
      fittedScale: 1.5,
    );
    reader.pageController = PageController(initialPage: 5, keepPage: false);
    reader.preloadPageController =
        PreloadPageController(initialPage: 5, keepPage: false);
    reader.extendedPageController =
        ExtendedPageController(initialPage: 5, keepPage: false);
    reader.updateViewport(const Size(390, 844), canUseDoublePage: false);

    for (var index = 0; index < 20; index++) {
      final oldCallback = reader.pageChangedCallback;
      reader.updateViewport(
        const Size(900, 650),
        canUseDoublePage: true,
        bookFolded: index.isEven,
      );
      expect(reader.preloadPageController.initialPage, 2);
      oldCallback(4);
      reader.pageChangedCallback(2);
      expect(state.currentItemIndex, 5);
      expect(reader.readerZoomRatioFor(6), closeTo(2.0, 0.0001));
      final pairedCallback = reader.pageChangedCallback;
      reader.updateViewport(const Size(390, 844), canUseDoublePage: false);
      pairedCallback(3);
      reader.pageChangedCallback(5);
      expect(reader.pageController.initialPage, 5);
      expect(state.currentItemIndex, 5);
      expect(reader.readerZoomRatioFor(6), closeTo(2.0, 0.0001));
    }
    reader.setColumnPreference(ReaderColumnPreference.evenLeft);
    expect(state.pageIndex, 3);
    reader.pageChangedCallback(3);
    expect(state.currentItemIndex, 5);
    reader.setColumnPreference(ReaderColumnPreference.single);
    reader.pageChangedCallback(5);
    expect(state.currentItemIndex, 5);
    reader.setColumnPreference(ReaderColumnPreference.oddLeft);
    reader.jumpToPage(4);
    expect(state.pageIndex, 2);
    reader.jumpToPage(5);
    expect(state.pageIndex, 2);
    expect(state.currentItemIndex, 5);
    expect(state.sliderValue, 5);
    reader.setColumnPreference(ReaderColumnPreference.single);
    reader.pageChangedCallback(6);
    expect(state.currentItemIndex, 6);
    expect(reader.readerZoomRatioFor(6), closeTo(2.0, 0.0001));
    state.viewMode = ViewMode.topToBottom;
    reader.setColumnPreference(ReaderColumnPreference.automatic);
    reader.updateViewport(const Size(900, 650), canUseDoublePage: true);
    expect(state.columnMode, ViewColumnMode.single);
    expect(state.pageIndex, 6);
    await tester.pump();
    reader.pageController.dispose();
    reader.preloadPageController.dispose();
    reader.extendedPageController.dispose();
    reader.photoViewController.dispose();
    reader.photoViewScaleStateController.dispose();
  });
}

class _State extends Fake implements ViewExtState {
  _State(this.ehSettingService);
  @override
  final EhSettingService ehSettingService;
  @override
  int currentItemIndex = 5;
  @override
  Size? viewportSize;
  @override
  bool? viewportAllowsDoublePage;
  @override
  bool bookFolded = false;
  @override
  ViewMode viewMode = ViewMode.leftToRight;
  @override
  double sliderValue = 5;
  @override
  final Map<int, double> readerZoomRatios = <int, double>{};
  @override
  int get fileCount => 11;
  @override
  LoadFrom get loadFrom => LoadFrom.download;
  @override
  bool get showPageInterval => false;
  @override
  bool get syncThumbList => false;
  @override
  ViewColumnMode get columnMode => viewMode == ViewMode.topToBottom
      ? ViewColumnMode.single
      : ehSettingService.resolveReaderColumnMode(
          canUseDoublePage: viewportAllowsDoublePage ?? false);
  @override
  ReaderPagination get pagination =>
      ReaderPagination(mode: columnMode, imageCount: fileCount);
  @override
  int get pageIndex => pagination.pageForImage(currentItemIndex);
  @override
  int get pageCount => pagination.pageCount;
}
