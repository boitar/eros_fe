import 'dart:math' as math;

import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/models/item_config.dart';
import 'package:eros_fe/pages/tab/view/list/waterfall_flow.dart';

/// 卡片大小: five steps, small to large, for each list style that lays cards
/// out in columns. The middle step is the automatic size each style has always
/// had and the others scale it, while the column count still comes from the
/// width of the pane the list is in, so it follows a display change, rotation
/// or the split divider.
abstract final class CardSize {
  static const int steps = 5;
  static const int standard = 2;

  /// The large waterfall's narrowest column at each step. The other styles
  /// scale their own standard width by the same ratios.
  static const List<double> largeColumnWidths = [102, 132, 168, 205, 250];

  static const List<ListModeEnum> modes = [
    ListModeEnum.waterfallLarge,
    ListModeEnum.waterfall,
    ListModeEnum.grid,
    ListModeEnum.gridTags,
  ];

  static int _clamp(int step) => step.clamp(0, steps - 1);

  static double _ratio(int step) =>
      largeColumnWidths[_clamp(step)] / largeColumnWidths[standard];

  static double _standardExtent(ListModeEnum mode, {bool phone = true}) =>
      switch (mode) {
        ListModeEnum.waterfallLarge => largeColumnWidths[standard],
        ListModeEnum.waterfall => phone
            ? EHConst.waterfallFlowMaxCrossAxisExtent
            : EHConst.waterfallFlowMaxCrossAxisExtentTablet,
        _ => EHConst.gridMaxCrossAxisExtent,
      };

  /// The step [mode] uses. A custom width from the old setting becomes the
  /// step nearest to it, measured from the width that setting started at.
  static int of(ListModeEnum mode, ItemConfig? config, {bool phone = true}) {
    final step = config?.cardSize;
    if (step != null) {
      return _clamp(step);
    }
    final width = config?.customWidth;
    if (!(config?.enableCustomWidth ?? false) || width == null || width <= 0) {
      return standard;
    }
    final start = mode == ListModeEnum.waterfallLarge
        ? EHConst.waterfallFlowLargeMaxCrossAxisExtent
        : _standardExtent(mode, phone: phone);
    final target = math.log(width / start);
    double distance(int step) => (math.log(_ratio(step)) - target).abs();
    var nearest = standard;
    for (var step = 0; step < steps; step++) {
      if (distance(step) < distance(nearest)) {
        nearest = step;
      }
    }
    return nearest;
  }

  /// The large waterfall's narrowest column.
  static double largeColumnWidth(int step) => largeColumnWidths[_clamp(step)];

  /// The widest a card may be in the other styles, which fit as many columns
  /// as that allows. Only the small waterfall is wider off a phone.
  static double maxCrossAxisExtent(ListModeEnum mode, int step,
          {bool phone = true}) =>
      _standardExtent(mode, phone: phone) * _ratio(step);

  /// The columns [mode] lays out in a pane [paneWidth] wide, by the rules the
  /// list itself uses, its margins included.
  static int columns(
    ListModeEnum mode,
    int step,
    double paneWidth, {
    bool phone = true,
    bool immersive = false,
  }) {
    if (mode == ListModeEnum.waterfallLarge) {
      return LargeWaterfallDelegate.columnsFor(
        paneWidth - EHConst.waterfallFlowLargeMargin * 2,
        gap: immersive
            ? EHConst.waterfallFlowImmersiveSpacing
            : EHConst.waterfallFlowLargeCrossAxisSpacing,
        minColumnWidth: largeColumnWidth(step),
      );
    }
    final spacing = mode == ListModeEnum.waterfall
        ? EHConst.waterfallFlowCrossAxisSpacing
        : EHConst.gridCrossAxisSpacing;
    final extent = maxCrossAxisExtent(mode, step, phone: phone);
    // SliverGridDelegateWithMaxCrossAxisExtent and its waterfall twin.
    return math.max(1, ((paneWidth - spacing * 2) / (extent + spacing)).ceil());
  }
}
