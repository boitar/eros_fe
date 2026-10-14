import 'package:eros_fe/common/controller/history_controller.dart';
import 'package:eros_fe/common/controller/localfav_controller.dart';
import 'package:eros_fe/common/controller/mysql_controller.dart';
import 'package:eros_fe/common/controller/tag_controller.dart';
import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/common/controller/webdav_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/pages/controller/fav_controller.dart';
import 'package:eros_fe/pages/controller/favorite_sel_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:get/get.dart';

void registerWaterfallFixture() {
  Get.testMode = true;
  Get.put<LocaleService>(LocaleService());
  Get.put<EhSettingService>(_Settings());
  Get.put<ThemeService>(_Theme());
  Get.put<TagController>(_Tags());
  Get.put<UserController>(_User());
  Get.put<LocalFavController>(_LocalFavorites());
  Get.put<FavoriteSelectorController>(_FavoriteSelector());
  Get.put<FavController>(_Favorites());
  Get.put<WebdavController>(_Webdav());
  Get.put<MysqlController>(_Mysql());
  Get.put<HistoryController>(_History());
  Get.put<TabHomeController>(_Tabs());
}

List<GalleryProvider> waterfallProviders([int count = 50]) {
  return List.generate(
    count,
    (i) => GalleryProvider(
      gid: 'fixture-$i',
      englishTitle: 'Offline gallery $i with a long title',
      category: 'Manga',
      imgUrl: '',
      imgWidth: i % 3 == 0 ? 0 : 200,
      imgHeight: i % 3 == 0 ? 0 : 280 + i % 7 * 20,
      filecount: '20',
      rating: 3.0,
      colorRating: 'ir',
      simpleTags: const [],
    ),
  );
}

// Suppress database, account, network and synchronization side effects only.
// Production cards and GalleryItemController remain unchanged.
class _Settings extends EhSettingService {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Theme extends ThemeService {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Tags extends TagController {
  @override
  // ignore: must_call_super
  void onReady() {}
}

class _User extends UserController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _LocalFavorites extends LocalFavController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _FavoriteSelector extends FavoriteSelectorController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Favorites extends FavController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Webdav extends WebdavController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Mysql extends MysqlController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _History extends HistoryController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Tabs extends TabHomeController {
  @override
  // ignore: must_call_super
  void onInit() {}
}
