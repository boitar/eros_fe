import 'dart:math' as math;

import 'package:flutter/widgets.dart';

const double kHeightPreview = 180.0;
const double kPadding = 12.0;

const double kHeaderHeight = 200.0;
const double kHeaderPaddingTop = 12.0;

const double kMaxCrossAxisExtent = 135.0;
const double kMainAxisSpacing = 0; //主轴方向的间距
const double kCrossAxisSpacing = 4; //交叉轴方向子元素的间距
const double kChildAspectRatio = 0.55; //显示区域宽高比

double galleryHeaderHeightFor(BuildContext context) {
  final textScale = MediaQuery.textScalerOf(context).scale(1);
  final titleHeight = 16 * 1.2 * 6 * textScale;
  final uploaderHeight = 13 * 1.2 * textScale + 12;
  final actionsHeight = 15 * 1.2 * textScale + 22;
  return math.max(
    kHeaderHeight,
    titleHeight + uploaderHeight + 8 + actionsHeight,
  );
}
