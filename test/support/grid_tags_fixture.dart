import 'package:eros_fe/common/controller/history_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/models/item_config.dart';
import 'package:eros_fe/models/simple_tag.dart';
import 'package:eros_fe/pages/controller/fav_controller.dart';
import 'package:eros_fe/pages/item/controller/galleryitem_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:get/get.dart';

/// Offline dependencies for exercising the production grid without user data.
class GridTagsFixtureSettings extends GetxService implements EhSettingService {
  @override
  final listMode = ListModeEnum.gridTags.obs;
  final translation = false.obs;
  final tagLimit = (-1).obs;
  final configs = <ListModeEnum, ItemConfig>{}.obs;

  @override
  bool get isTagTranslate => translation.value;
  @override
  set isTagTranslate(bool value) => translation.value = value;
  @override
  int get listViewTagLimit => tagLimit.value;
  @override
  set listViewTagLimit(int value) => tagLimit.value = value;
  @override
  bool get isPureDarkTheme => false;
  @override
  bool get debugMode => false;
  @override
  final isGalleryImgBlur = false.obs;
  @override
  ItemConfig? getItemConfig([ListModeEnum? mode]) =>
      configs[mode ?? listMode.value];
  @override
  void setItemConfig(
      ListModeEnum mode, ItemConfig Function(ItemConfig) change) {
    configs[mode] = change(configs[mode] ?? ItemConfig(type: mode.name));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class GridTagsFixtureTheme extends GetxService implements ThemeService {
  final dark = false.obs;

  @override
  ThemesModeEnum get themeModel =>
      dark.value ? ThemesModeEnum.darkMode : ThemesModeEnum.lightMode;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class GridTagsFixtureLayout extends LayoutServices {
  // Deliberately skip LayoutServices' Hive initialization in the offline host.
  @override
  // ignore: must_call_super
  void onInit() {}
}

class GridTagsFixtureController extends GalleryItemController {
  GridTagsFixtureController(GalleryProvider galleryProvider)
      : super(galleryProvider: galleryProvider);

  int taps = 0;
  int longPresses = 0;

  @override
  void onTap(dynamic tabTag) => taps++;
  @override
  void onLongPress() => longPresses++;
}

List<GalleryProvider> gridTagsFixtureGalleries({int count = 6}) {
  const titles = [
    '[Studio Sora] 星海旅行者画集 Vol.02',
    '雨后的小巷',
    '(C108) [花庭] 春日来信 · 插画集与创作手记',
    '[Moonlight] 夜航 · 城市光影与梦境',
    '山间的夏天',
    '[Paperworks] 水彩练习簿 03',
  ];
  final tags = [
    const SimpleTag(
      text: 'language:chinese',
      translat: '汉语',
      color: '#ffffff',
      backgrondColor: '#d72533',
    ),
    const SimpleTag(text: 'full color', translat: '全彩'),
    const SimpleTag(text: 'science fiction', translat: '科幻'),
    const SimpleTag(text: 'studio sora', translat: 'studio sora'),
    for (var i = 0; i < 18; i++)
      SimpleTag(text: 'tag-$i with a long label', translat: '长标签 $i'),
  ];

  return [
    for (var i = 0; i < count; i++)
      GalleryProvider(
        gid: 'grid-tags-fixture-$i',
        token: 'offline',
        englishTitle: titles[i % titles.length],
        category: 'Manga',
        imgUrl: '',
        imgWidth: i % 3 == 0 ? 600 : (i % 3 == 1 ? 300 : 0),
        imgHeight: i % 3 == 0 ? 200 : (i % 3 == 1 ? 600 : 0),
        filecount: '${24 + i * 20}',
        translated: i.isEven ? 'ZH' : 'JP',
        postTime: '2026-10-12 08:26',
        simpleTags:
            i % 6 == 5 ? [] : (i % 6 == 4 ? tags.take(1).toList() : tags),
        expunged: i % 6 == 5,
        favcat: i % 6 == 0 ? '4' : '',
      ),
  ];
}

void registerGridMasterDependencies() {
  Get.put<FavController>(_GridFavorites());
  Get.put<HistoryController>(_GridHistory());
  Get.put<TabHomeController>(_GridTabs());
}
class _GridFavorites extends GetxController implements FavController {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('$invocation');
}
class _GridHistory extends GetxController implements HistoryController {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('$invocation');
}
class _GridTabs extends GetxController implements TabHomeController {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('$invocation');
}
