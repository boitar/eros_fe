import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/pages/item/controller/galleryitem_controller.dart';
import 'package:eros_fe/pages/item/gallery_item_flow.dart';
import 'package:eros_fe/pages/item/gallery_item_flow_large.dart';
import 'package:eros_fe/pages/tab/view/list/waterfall_flow.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/waterfall_fixture.dart';

void main() {
  setUp(registerWaterfallFixture);
  tearDown(Get.reset);

  for (final large in [false, true]) {
    for (final size in [const Size(390, 844), const Size(844, 390)]) {
      for (final scale in [1.0, 1.6]) {
        testWidgets(
            'real waterfall stays stable: large=$large size=$size scale=$scale',
            (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final scroll = ScrollController();
          addTearDown(scroll.dispose);
          final providers = waterfallProviders();
          late StateSetter rebuild;

          await tester.pumpWidget(
            GetMaterialApp(
              home: StatefulBuilder(
                builder: (context, setState) {
                  rebuild = setState;
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: CupertinoPageScaffold(
                      child: CustomScrollView(
                        controller: scroll,
                        slivers: [
                          EhWaterfallFlow(providers, 'fixture', large: large),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          final first = large
              ? find.byType(GalleryItemFlowLarge).first
              : find.byType(GalleryItemFlow).first;
          final beforeRect = tester.getRect(first);
          final controller =
              Get.find<GalleryItemController>(tag: providers.first.gid);
          controller.rating = 4.5;

          providers.add(const GalleryProvider(
            gid: 'appended',
            imgUrl: '',
            englishTitle: 'Appended gallery',
            imgWidth: 200,
            imgHeight: 300,
          ));
          rebuild(() {});
          await tester.pumpAndSettle();
          expect(
            identical(
              controller,
              Get.find<GalleryItemController>(tag: providers.first.gid),
            ),
            isTrue,
          );
          expect(controller.rating, 4.5);
          expectRectClose(tester.getRect(first), beforeRect);

          scroll.jumpTo(1600);
          await tester.pumpAndSettle();
          scroll.jumpTo(0);
          await tester.pumpAndSettle();
          expectRectClose(tester.getRect(first), beforeRect);
          expect(tester.takeException(), isNull);

          Get.find<ThemeService>().themeModel = ThemesModeEnum.darkMode;
          rebuild(() {});
          await tester.pumpAndSettle();
          expectRectClose(tester.getRect(first), beforeRect);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
}

void expectRectClose(Rect actual, Rect expected) {
  expect(actual.left, closeTo(expected.left, 0.001));
  expect(actual.top, closeTo(expected.top, 0.001));
  expect(actual.width, closeTo(expected.width, 0.001));
  expect(actual.height, closeTo(expected.height, 0.001));
}
