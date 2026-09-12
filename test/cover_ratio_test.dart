import 'package:eros_fe/pages/item/cover_ratio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('coverAspectRatio 正常尺寸', () {
    test('常规竖图 400x600 → 2/3', () {
      expect(coverAspectRatio(imgWidth: 400, imgHeight: 600),
          closeTo(2 / 3, 1e-9));
    });

    test('宽图不设上限 600x200 → 3.0', () {
      expect(coverAspectRatio(imgWidth: 600, imgHeight: 200), 3.0);
    });

    test('极窄图被 1/2 钳制 100x400 → 0.5', () {
      expect(coverAspectRatio(imgWidth: 100, imgHeight: 400), 0.5);
    });

    test('恰好 1:2 保持不变 200x400 → 0.5', () {
      expect(coverAspectRatio(imgWidth: 200, imgHeight: 400), 0.5);
    });
  });

  group('coverAspectRatio 异常输入回退默认比例（P0-1）', () {
    test('0x0 不产生 NaN', () {
      expect(coverAspectRatio(imgWidth: 0, imgHeight: 0),
          kDefaultCoverAspectRatio);
    });

    test('imgHeight=0 不产生 Infinity', () {
      expect(coverAspectRatio(imgWidth: 300, imgHeight: 0),
          kDefaultCoverAspectRatio);
    });

    test('imgWidth=0 回退', () {
      expect(coverAspectRatio(imgWidth: 0, imgHeight: 300),
          kDefaultCoverAspectRatio);
    });

    test('负值回退', () {
      expect(coverAspectRatio(imgWidth: -100, imgHeight: 300),
          kDefaultCoverAspectRatio);
    });
  });

  test('默认比例值约 210/300 且为正有限数', () {
    expect(kDefaultCoverAspectRatio, closeTo(210 / 300, 1e-9));
    expect(kDefaultCoverAspectRatio.isFinite, isTrue);
    expect(kDefaultCoverAspectRatio, greaterThan(0));
  });
}
