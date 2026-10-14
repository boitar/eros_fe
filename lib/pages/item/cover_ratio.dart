import 'dart:math';

/// 封面默认宽高比（宽/高），取常规画廊封面比例约 210/300。
/// 封面尺寸缺失或非法时布局层用它兜底，避免 NaN/Infinity 或裸用像素高度。
const double kDefaultCoverAspectRatio = 210 / 300;

/// 计算瀑布流封面宽高比（宽/高），并保持不低于 1/2 的钳制。
///
/// imgWidth/imgHeight 任一非正值（本地收藏、历史记录等数据源可能缺失
/// 封面尺寸字段）时回退到 [kDefaultCoverAspectRatio]，
/// 防止 `0/0 = NaN`、`x/0 = Infinity` 直接进入 [AspectRatio] 布局。
double coverAspectRatio({required int imgWidth, required int imgHeight}) {
  if (imgWidth <= 0 || imgHeight <= 0) {
    return kDefaultCoverAspectRatio;
  }
  return max(imgWidth / imgHeight, 1 / 2);
}
