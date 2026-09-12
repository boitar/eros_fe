import 'package:eros_fe/pages/item/cover_ratio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

/// 比例不变式的布局层验证：
/// GalleryItemFlowLarge 大卡首帧以
/// `AspectRatio(aspectRatio: coverAspectRatio(...))` 布局
/// （lib/pages/item/gallery_item_flow_large.dart _CoverWidget）。
/// 若比例计算退回 NaN/Infinity/非正值，AspectRatio 会在 debug 下断言失败，
/// 本测试即拦截该缺陷形态（原 bug：占位符比例表达式恒 1.0 的家族问题）。
void main() {
  const double cellWidth = 200.0;
  const double defaultRatio = 210 / 300;

  Future<double> pumpCoverHeight(WidgetTester tester, int imgWidth,
      int imgHeight) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: cellWidth,
            child: AspectRatio(
              aspectRatio: coverAspectRatio(
                imgWidth: imgWidth,
                imgHeight: imgHeight,
              ),
              child: const ColoredBox(color: Color(0xFF000000)),
            ),
          ),
        ),
      ),
    );
    return tester.getSize(find.byType(AspectRatio)).height;
  }

  testWidgets('imgWidth=0/imgHeight=0 正常构建，高度为默认比例对应值', (tester) async {
    final height = await pumpCoverHeight(tester, 0, 0);
    expect(height.isFinite, isTrue, reason: '高度不应为 NaN/Infinity');
    expect(height, closeTo(cellWidth / defaultRatio, 0.01));
  });

  testWidgets('imgWidth=300/imgHeight=0 正常构建，高度为默认比例对应值', (tester) async {
    final height = await pumpCoverHeight(tester, 300, 0);
    expect(height.isFinite, isTrue, reason: '高度不应为 NaN/Infinity');
    expect(height, closeTo(cellWidth / defaultRatio, 0.01));
  });

  testWidgets('已知比例 400x600 高度等于宽度/(2/3)', (tester) async {
    final height = await pumpCoverHeight(tester, 400, 600);
    expect(height, closeTo(cellWidth / (2 / 3), 0.01));
  });

  testWidgets('已知比例 600x200 高度等于宽度/3', (tester) async {
    final height = await pumpCoverHeight(tester, 600, 200);
    expect(height, closeTo(cellWidth / 3.0, 0.01));
  });
}
