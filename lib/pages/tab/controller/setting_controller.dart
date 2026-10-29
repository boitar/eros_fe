import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/index.dart';
import 'package:get/get.dart';

class SettingViewController extends GetxController {
  /// The large title has scrolled under the bar, so the bar names the page.
  final RxBool titleInBar = false.obs;

  /// Content has scrolled under the bar, which shows its soft edge.
  final RxBool contentUnderBar = false.obs;

  void open(String route) {
    if (isLayoutLarge) {
      final topRoute =
          SecondNavigatorObserver().history.lastOrNull?.settings.name;
      if (topRoute?.startsWith('/setting') ?? false) {
        Get.offNamed(route, id: detailNavigatorId);
      } else {
        Get.toNamed(route, id: detailNavigatorId);
      }
    } else {
      Get.toNamed(route, id: detailNavigatorId);
    }
  }
}
