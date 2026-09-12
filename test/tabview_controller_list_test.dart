import 'package:eros_fe/common/controller/tag_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/models/gallery_list.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/pages/tab/controller/tabview_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// 列表对象不变式（fix 165ff971 第 2 条的回归防线）：
/// loadDataMore / loadPrevious 必须**复用同一个 List 对象**追加/前插，
/// 不得每次生成新 List（否则瀑布流整体重建、列簿记失真）。
void main() {
  setUpAll(() {
    Get.testMode = true;
    // TabViewController 构造依赖。EhSettingService.onInit 会访问 Isar
    // （tag 翻译版本号等），测试环境无数据库，用空 onInit 的子类替代；
    // TagController.onReady 会拉取 mytag，同样以空实现替代。
    // 注意 GetX 按注册时显式给出的泛型类型索引，须以基类类型注册。
    Get.put<LocaleService>(LocaleService());
    Get.put<EhSettingService>(_TestEhSettingService());
    Get.put<TagController>(_TestTagController());
  });

  tearDownAll(() {
    Get.reset();
  });

  GalleryProvider provider(String gid) => GalleryProvider(gid: gid);

  testWidgets('loadDataMore 追加时复用同一列表对象', (tester) async {
    final controller = _TestTabViewController(
      moreResult: GalleryList(gallerys: [provider('m1'), provider('m2')]),
    );
    final initial = <GalleryProvider>[provider('a'), provider('b')];
    controller.change(initial, status: RxStatus.success());
    controller.canLoadMore = true;
    final before = controller.state;

    final future = controller.loadDataMore();
    // loadDataMore 内部有 100ms 延迟
    await tester.pump(const Duration(milliseconds: 200));
    await future;

    expect(controller.state, isNotNull);
    expect(identical(controller.state, before), isTrue,
        reason: 'loadDataMore 必须复用同一 List 对象');
    expect(controller.state!.length, 4);
    expect(controller.state![2].gid, 'm1');
    expect(controller.state!.last.gid, 'm2');
  });

  testWidgets('loadPrevious 前插时复用同一列表对象', (tester) async {
    final controller = _TestTabViewController(
      prevResult: GalleryList(gallerys: [provider('p1'), provider('p2')]),
    );
    final initial = <GalleryProvider>[provider('a')];
    controller.change(initial, status: RxStatus.success());
    controller.canLoadMore = true;
    final before = controller.state;

    final future = controller.loadPrevious();
    // loadPrevious 内部有 100ms 延迟
    await tester.pump(const Duration(milliseconds: 200));
    await future;
    // 前插发生在 addPostFrameCallback 中，需显式排帧后 pump 才会触发
    tester.binding.scheduleFrame();
    await tester.pump();

    expect(controller.state, isNotNull);
    expect(identical(controller.state, before), isTrue,
        reason: 'loadPrevious 必须复用同一 List 对象');
    expect(controller.state!.length, 3);
    expect(controller.state!.first.gid, 'p1');
    expect(controller.state!.last.gid, 'a');
  });
}

class _TestEhSettingService extends EhSettingService {
  // 有意不调用 super：基类 onInit 会访问 Isar 数据库，测试环境不可用
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _TestTagController extends TagController {
  // 有意不调用 super：基类 onReady 会请求 mytag 页面，测试环境不可达
  @override
  // ignore: must_call_super
  void onReady() {}
}

class _TestTabViewController extends TabViewController {
  _TestTabViewController({this.moreResult, this.prevResult});

  final GalleryList? moreResult;
  final GalleryList? prevResult;

  @override
  Future<GalleryList?> fetchMoreData() async => moreResult;

  @override
  Future<GalleryList?> fetchPrevData() async => prevResult;
}
