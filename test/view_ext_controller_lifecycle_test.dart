import 'package:eros_fe/common/controller/gallerycache_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_controller.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_state.dart';
import 'package:eros_fe/pages/image_view/common.dart';
import 'package:eros_fe/pages/image_view/controller/view_controller.dart';
import 'package:eros_fe/pages/image_view/controller/view_state.dart';
import 'package:eros_fe/pages/image_view/view/view_page.dart';
import 'package:eros_fe/route/app_pages.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// Fakes registered with `Get.put` still walk GetX's lifecycle, whose
/// `onStart`/`onDelete` are callable fields that null-crash without a callback.
mixin _InertLifecycle {
  final onStart = InternalFinalCallback<void>(callback: () {});
  final onDelete = InternalFinalCallback<void>(callback: () {});

  void onInit() {}
  void onReady() {}
  void onClose() {}
}

class _FakeGalleryCacheController extends Fake
    with _InertLifecycle
    implements GalleryCacheController {}

class _FakeEhSettings extends Fake with _InertLifecycle
    implements EhSettingService {}

class _FakeGalleryState extends Fake implements GalleryPageState {
  _FakeGalleryState(this.gid);

  @override
  final String gid;
}

class _FakeGalleryPageController extends Fake
    with _InertLifecycle
    implements GalleryPageController {
  _FakeGalleryPageController(String gid) : gState = _FakeGalleryState(gid);

  @override
  final GalleryPageState gState;
}

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put<EhSettingService>(_FakeEhSettings());
    Get.put<GalleryCacheController>(_FakeGalleryCacheController());
  });

  tearDown(Get.reset);

  test('reader binding delete removes the registration for good', () async {
    // With `fenix: true` this delete only cleared `isInit`, left the factory
    // in place, and let the next Get.find revive an empty controller.
    bindViewExtController();
    expect(Get.isRegistered<ViewExtController>(), isTrue);

    await Get.delete<ViewExtController>();
    expect(Get.isRegistered<ViewExtController>(), isFalse);
  });

  test('injected repository builds the session even with cleared arguments',
      () {
    final repository = ViewRepository(
      index: 3,
      loadType: LoadFrom.gallery,
      gid: 'g1',
      galleryControllerTag: 'tag-x',
    );
    final gallery = _FakeGalleryPageController('g1');
    Get.put<GalleryPageController>(gallery, tag: 'tag-x');

    final state = ViewExtState(repository: repository);
    expect(identical(state.galleryPageController, gallery), isTrue);
    expect(state.gid, 'g1');
    expect(state.loadFrom, LoadFrom.gallery);
    expect(state.currentItemIndex, 3);
  });

  test('empty arguments yield an unbound session', () {
    // This is the state a revived zombie used to carry silently.
    final state = ViewExtState();
    expect(state.galleryPageController, isNull);
  });
}
