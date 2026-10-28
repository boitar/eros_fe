import 'package:flutter/cupertino.dart';

const double kNavBarBackButtonTapWidth = 50.0;
const double kNavBarLargeTitleHeightExtension = 52.0;

const double kTopTabbarHeight = kMinInteractiveDimensionCupertino;

double topTabbarHeightFor(BuildContext context) {
  final scaledTextHeight = MediaQuery.textScalerOf(context).scale(14) * 1.2;
  final desiredHeight = scaledTextHeight + 16;
  return desiredHeight > kTopTabbarHeight ? desiredHeight : kTopTabbarHeight;
}

const double kHeaderMaxHeight =
    kMinInteractiveDimensionCupertino + kTopTabbarHeight - 2.0;

const Color _kDefaultNavBarBorderColor = Color(0x4D000000);
const Border kDefaultNavBarBorder = Border(
  bottom: BorderSide(
    color: _kDefaultNavBarBorderColor,
    width: 0.0, // One physical pixel.
    style: BorderStyle.solid,
  ),
);
