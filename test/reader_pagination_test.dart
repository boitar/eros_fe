import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/pages/image_view/common.dart';
import 'package:eros_fe/pages/image_view/reader_pagination.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  for (final count in <int>[0, 1, 2, 3, 10, 11, 12]) {
    for (final mode in ViewColumnMode.values) {
      test('$mode maps $count images exactly once without filler pages', () {
        final mapping = ReaderPagination(mode: mode, imageCount: count);
        final images = [
          for (var page = 0; page < mapping.pageCount; page++)
            ...mapping.imagesForPage(page),
        ];
        expect(images, List<int>.generate(count, (index) => index));
        for (var image = 0; image < count; image++) {
          expect(mapping.imagesForPage(mapping.pageForImage(image)),
              contains(image));
        }
      });
    }
  }

  test('cover and trailing single pages are not duplicated', () {
    const paired =
        ReaderPagination(mode: ViewColumnMode.evenLeft, imageCount: 6);
    expect(paired.imagesForPage(0), [0]);
    expect(paired.imagesForPage(1), [1, 2]);
    expect(paired.imagesForPage(3), [5]);
    expect(paired.imagesForPage(4), isEmpty);
  });

  test('20 single/paired remaps preserve every original image anchor', () {
    for (var anchor = 0; anchor < 11; anchor++) {
      var current = anchor;
      for (var cycle = 0; cycle < 20; cycle++) {
        for (final mode in <ViewColumnMode>[
          ViewColumnMode.oddLeft,
          ViewColumnMode.evenLeft,
          ViewColumnMode.single,
        ]) {
          final mapping = ReaderPagination(mode: mode, imageCount: 11);
          current = mapping.imageAfterPageChange(
            mapping.pageForImage(current),
            currentImage: current,
          );
          expect(current, anchor);
        }
      }
    }
  });

  test('a genuine page turn changes the anchor, a remap does not', () {
    const mapping =
        ReaderPagination(mode: ViewColumnMode.oddLeft, imageCount: 11);
    expect(mapping.imageAfterPageChange(2, currentImage: 5), 5);
    expect(mapping.imageAfterPageChange(3, currentImage: 5), 6);
    expect(mapping.imageAfterPageChange(5, currentImage: 6), 10);
  });

  test('automatic and explicit user intent are independent from geometry', () {
    Get.testMode = true;
    Get.put<LocaleService>(LocaleService());
    addTearDown(Get.reset);
    final settings = EhSettingService();
    expect(settings.resolveReaderColumnMode(canUseDoublePage: false),
        ViewColumnMode.single);
    expect(settings.resolveReaderColumnMode(canUseDoublePage: true),
        ViewColumnMode.oddLeft);
    for (final mode in ViewColumnMode.values) {
      settings.setManualReaderColumnMode(mode);
      for (var index = 0; index < 20; index++) {
        expect(settings.resolveReaderColumnMode(canUseDoublePage: index.isEven),
            mode);
      }
    }
    settings.setManualReaderColumnMode(ViewColumnMode.evenLeft);
    settings.setReaderColumnPreference(ReaderColumnPreference.automatic);
    expect(settings.resolveReaderColumnMode(canUseDoublePage: true),
        ViewColumnMode.evenLeft);
    expect(settings.resolveReaderColumnMode(canUseDoublePage: false),
        ViewColumnMode.single);
  });
}
