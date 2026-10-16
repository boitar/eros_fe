import 'package:eros_fe/common/controller/history_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/models/simple_tag.dart';
import 'package:eros_fe/pages/controller/fav_controller.dart';
import 'package:eros_fe/pages/item/controller/galleryitem_controller.dart';
import 'package:eros_fe/pages/item/gallery_item.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';

void main() {
  Logger.level = Level.off;
  final settings = _Settings();
  final theme = _Theme();
  setUp(() {
    Get.put<EhSettingService>(settings);
    Get.put<ThemeService>(theme);
    Get.put<LayoutServices>(_Layout());
    Get.put<FavController>(_Favorites());
    Get.put<HistoryController>(_History());
    Get.put<TabHomeController>(_Tabs());
  });
  tearDown(Get.reset);
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('production card fits width=$width scale=$scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        theme.dark.value = scale > 1;
        const gallery = GalleryProvider(
            gid: 'offline-card',
            englishTitle: 'Neutral illustration collection with a long title',
            category: 'Manga',
            imgUrl: '',
            imgWidth: 400,
            imgHeight: 600,
            filecount: '48',
            postTime: '2026-10-15',
            simpleTags: [
              SimpleTag(text: 'full color'),
              SimpleTag(text: 'long neutral illustration label'),
            ]);
        Get.put<GalleryItemController>(
            GalleryItemController(galleryProvider: gallery),
            tag: gallery.gid);
        await tester.pumpWidget(GetCupertinoApp(
          theme: CupertinoThemeData(textTheme: ehTextTheme),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: const CupertinoPageScaffold(
              child: SingleChildScrollView(
                  child: GalleryItemWidget(
                      tabTag: 'offline-card', galleryProvider: gallery))),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
        final height = tester.getSize(find.byType(GalleryItemWidget)).height;
        expect(height, scale == 1 ? 216 : greaterThan(216));
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}

class _Settings extends GetxService implements EhSettingService {
  final fixed = true.obs;
  final limit = 2.obs;
  final translation = false.obs;
  final blur = false.obs;
  @override
  bool get fixedHeightOfListItems => fixed.value;
  @override
  int get listViewTagLimit => limit.value;
  @override
  bool get isTagTranslate => translation.value;
  @override
  bool get isPureDarkTheme => false;
  @override
  bool get blurringOfCoverBackground => blur.value;
  @override
  bool get debugMode => false;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('$invocation');
}

class _Theme extends GetxService implements ThemeService {
  final dark = false.obs;
  @override
  ThemesModeEnum get themeModel =>
      dark.value ? ThemesModeEnum.darkMode : ThemesModeEnum.lightMode;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('$invocation');
}

class _Layout extends LayoutServices {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Favorites extends GetxController implements FavController {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('$invocation');
}

class _History extends GetxController implements HistoryController {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('$invocation');
}

class _Tabs extends GetxController implements TabHomeController {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('$invocation');
}
