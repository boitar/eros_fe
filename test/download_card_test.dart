import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/item/download_gallery_item.dart';
import 'package:eros_fe/pages/tab/controller/download_view_controller.dart';
import 'package:eros_fe/store/db/entity/gallery_task.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

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

class _Downloads extends GetxController implements DownloadViewController {
  final paused = <int>[];
  final resumed = <int>[];
  final unavailable = <int>{};

  @override
  final galleryTaskMap = <int, GalleryTask>{};

  @override
  bool filesUnavailable(int gid) => unavailable.contains(gid);

  @override
  void pauseGalleryDownload(int? gid) {
    if (gid != null) {
      paused.add(gid);
    }
  }

  @override
  void resumeGalleryDownload(int? gid) {
    if (gid != null) {
      resumed.add(gid);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected card dependency: ${invocation.memberName}');
}

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put<LocaleService>(LocaleService());
    Get.put<EhSettingService>(_Settings());
    Get.put<ThemeService>(_Theme());
    Get.put<DownloadViewController>(_Downloads());
  });
  tearDown(Get.reset);

  GalleryTask task(int status) => GalleryTask(
        gid: 42,
        token: 'fixture',
        title: 'Neutral download fixture with a deliberately long title',
        dirPath: null,
        fileCount: 20,
        completCount: 4,
        status: status,
        uploader: 'A deliberately long uploader name',
        addTime: 0,
      );

  Future<void> mount(WidgetTester tester,
      {required Size size, required double scale, required bool dark,
      required int status}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final view = Get.find<DownloadViewController>() as _Downloads;
    final gallery = task(status);
    view.galleryTaskMap[42] = gallery;
    Get.find<ThemeService>().themeModel =
        dark ? ThemesModeEnum.darkMode : ThemesModeEnum.lightMode;
    await tester.pumpWidget(GetMaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [L10n.delegate],
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: CupertinoPageScaffold(
          child: ListView(children: [
            DownloadGalleryItem(
              galleryTask: gallery,
              taskIndex: 0,
              speed: '2 MB/s',
              errInfo: 'A deliberately long transient error',
            ),
          ]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final size in [const Size(320, 600), const Size(844, 390)]) {
    for (final scale in [1.0, 1.6]) {
      for (final dark in [false, true]) {
        testWidgets('traditional download card: $size $scale dark=$dark',
            (tester) async {
          await mount(tester,
              size: size, scale: scale, dark: dark, status: 1);
          expect(tester.takeException(), isNull);
          expect(find.text('4/20'), findsOneWidget);
          final pause = find.byType(CupertinoButton).last;
          await tester.tap(pause);
          final view = Get.find<DownloadViewController>() as _Downloads;
          expect(view.paused, [42]);
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }

  testWidgets('unavailable complete files expose the recheck action',
      (tester) async {
    final view = Get.find<DownloadViewController>() as _Downloads;
    view.unavailable.add(42);
    await mount(tester,
        size: const Size(390, 844), scale: 1, dark: false, status: 3);
    expect(find.text('Files temporarily unavailable'), findsOneWidget);
    await tester.tap(find.byType(CupertinoButton).last);
    expect(view.resumed, [42]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
