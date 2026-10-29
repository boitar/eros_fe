import 'dart:math' as math;

import 'package:eros_fe/adaptive/browse_layout.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/debug/offline_acceptance.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/item/controller/galleryitem_controller.dart';
import 'package:eros_fe/pages/item/gallery_item_flow.dart';
import 'package:eros_fe/pages/item/gallery_item_flow_large.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

class EhWaterfallFlow extends StatelessWidget {
  const EhWaterfallFlow(
    this.galleryProviders,
    this.tabTag, {
    this.next,
    this.lastComplete,
    this.large = false,
    this.centerKey,
    this.firstCardKey,
    this.lastTopItemIndex,
    super.key,
  });

  final List<GalleryProvider> galleryProviders;
  final dynamic tabTag;
  final String? next;
  final VoidCallback? lastComplete;
  final bool large;
  final Key? centerKey;
  final Key? firstCardKey;
  final int? lastTopItemIndex;

  EhSettingService get _ehSettingService => Get.find();

  LastChildLayoutType _lastChildLayoutType(int index) =>
      index == galleryProviders.length
          ? LastChildLayoutType.foot
          : LastChildLayoutType.none;

  SliverWaterfallFlowDelegate _gridDelegate(BuildContext context) {
    if (!large) {
      return SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: getMaxCrossAxisExtent(),
        crossAxisSpacing: EHConst.waterfallFlowCrossAxisSpacing,
        mainAxisSpacing: EHConst.waterfallFlowMainAxisSpacing,
        lastChildLayoutTypeBuilder: _lastChildLayoutType,
      );
    }
    final itemConfig =
        _ehSettingService.getItemConfig(ListModeEnum.waterfallLarge);
    final foldGap = largeWaterfallFoldGap(
      AdaptiveEnvironment.maybeOf(context),
      split: BrowsePaneScope.isSplit(context),
    );
    return LargeWaterfallDelegate(
      customColumnWidth: (itemConfig?.enableCustomWidth ?? false)
          ? itemConfig?.customWidth?.toDouble()
          : null,
      evenColumns: foldGap != null,
      crossAxisSpacing: foldGap ?? EHConst.waterfallFlowLargeCrossAxisSpacing,
      mainAxisSpacing: EHConst.waterfallFlowLargeMainAxisSpacing,
      lastChildLayoutTypeBuilder: _lastChildLayoutType,
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = large
        ? const EdgeInsets.all(EHConst.waterfallFlowLargeMargin)
        : const EdgeInsets.all(EHConst.waterfallFlowCrossAxisSpacing);

    return SliverPadding(
      padding: padding,
      sliver: SliverWaterfallFlow(
        key: key,
        gridDelegate: _gridDelegate(context),
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            if (galleryProviders.length - 1 < index) {
              return const SizedBox.shrink();
            }

            if (index == galleryProviders.length - 1 &&
                (next?.isNotEmpty ?? false)) {
              // 加载完成最后一项的回调
              lastComplete?.call();
            }

            final GalleryProvider _provider = galleryProviders[index];
            // 列表对象复用后每次重建都会走到这里。仅当 provider 未注册、
            // item controller 未注册，或注册 provider 与当前不是同一对象
            // （刷新产生同 gid 新数据）时才重新注册，
            // 避免 lazyReplace 每帧 delete/lazyPut 造成的注册表抖动。
            final bool needRegister = !Get.isRegistered<GalleryProvider>(
                  tag: _provider.gid,
                ) ||
                !Get.isRegistered<GalleryItemController>(tag: _provider.gid) ||
                !identical(
                  Get.find<GalleryProvider>(tag: _provider.gid),
                  _provider,
                );
            if (needRegister) {
              Get.lazyReplace(() => _provider, tag: _provider.gid, fenix: true);
              Get.lazyReplace(
                  () => GalleryItemController(
                      galleryProvider: Get.find(tag: _provider.gid)),
                  tag: _provider.gid,
                  fenix: true);
            }

            // 不包 FrameSeparateWidget：keframe 占位高度与真实高度不一致，
            // 会让 SliverWaterfallFlow 的列簿记失真，回滑时条目换列/跳动。
            // GalleryItemFlowLarge 依赖的封面尺寸随数据同步给出，首帧即可按真实比例布局。
            if (large) {
              final item = GalleryItemFlowLarge(
                key: index == lastTopItemIndex
                    ? centerKey
                    : ValueKey(_provider.gid),
                galleryProvider: _provider,
                tabTag: tabTag,
              );
              final keyed = index == 0 && firstCardKey != null
                  ? KeyedSubtree(key: firstCardKey, child: item)
                  : item;
              return offlineGallerySemantics(_provider.gid, keyed);
            } else {
              final item = GalleryItemFlow(
                key: index == lastTopItemIndex
                    ? centerKey
                    : ValueKey(_provider.gid),
                galleryProvider: _provider,
                tabTag: tabTag,
              );
              final keyed = index == 0 && firstCardKey != null
                  ? KeyedSubtree(key: firstCardKey, child: item)
                  : item;
              return offlineGallerySemantics(_provider.gid, keyed);
            }
          },
          childCount: galleryProviders.length,
        ),
      ),
    );
  }

  double getMaxCrossAxisExtent() {
    final itemConfig = _ehSettingService.getItemConfig(ListModeEnum.waterfall);
    final defaultMaxCrossAxisExtent = Get.context!.isPhone
        ? EHConst.waterfallFlowMaxCrossAxisExtent
        : EHConst.waterfallFlowMaxCrossAxisExtentTablet;
    if (itemConfig?.enableCustomWidth ?? false) {
      return itemConfig?.customWidth?.toDouble() ?? defaultMaxCrossAxisExtent;
    } else {
      return defaultMaxCrossAxisExtent;
    }
  }
}

/// Column rules for the large waterfall, resolved against the sliver's own
/// width at layout time, so rotation, split panes and Stage Manager windows
/// all get a count that fits rather than one guessed from the device.
///
/// Without a custom width: `max(2, ⌊(width + gap) ÷ (168 + gap)⌋)`.
/// A custom width keeps its old meaning of a maximum column width.
class LargeWaterfallDelegate extends SliverWaterfallFlowDelegate {
  const LargeWaterfallDelegate({
    this.minColumnWidth = EHConst.waterfallFlowLargeMinColumnWidth,
    this.customColumnWidth,
    this.evenColumns = false,
    super.mainAxisSpacing,
    super.crossAxisSpacing,
    super.lastChildLayoutTypeBuilder,
  });

  final double minColumnWidth;
  final double? customColumnWidth;

  /// Keeps the middle gap on the centre line, where a fold runs.
  final bool evenColumns;

  static int columnsFor(
    double width, {
    required double gap,
    double minColumnWidth = EHConst.waterfallFlowLargeMinColumnWidth,
    double? customColumnWidth,
    bool evenColumns = false,
  }) {
    var count = customColumnWidth != null && customColumnWidth > 0
        ? (width / (customColumnWidth + gap)).ceil()
        : math.max(2, ((width + gap) / (minColumnWidth + gap)).floor());
    count = math.max(1, count);
    if (evenColumns && count.isOdd) {
      count = count == 1 ? 2 : count - 1;
    }
    return count;
  }

  @override
  int getCrossAxisCount(SliverConstraints constraints) => columnsFor(
        constraints.crossAxisExtent,
        gap: crossAxisSpacing,
        minColumnWidth: minColumnWidth,
        customColumnWidth: customColumnWidth,
        evenColumns: evenColumns,
      );

  @override
  bool shouldRelayout(SliverWaterfallFlowDelegate oldDelegate) {
    return oldDelegate is! LargeWaterfallDelegate ||
        oldDelegate.minColumnWidth != minColumnWidth ||
        oldDelegate.customColumnWidth != customColumnWidth ||
        oldDelegate.evenColumns != evenColumns ||
        super.shouldRelayout(oldDelegate);
  }
}

/// The gap that lets the middle column gap cover a book fold, or null when
/// no fold runs down the list.
///
/// Only a full-width list can straddle the fold: split panes already sit on
/// either side of it. The list is laid out symmetrically inside the safe
/// area, so its centre gap lines up only when the fold is on that centre.
double? largeWaterfallFoldGap(
  AdaptiveEnvironmentSnapshot? environment, {
  required bool split,
}) {
  if (environment == null || split) {
    return null;
  }
  final content = environment.contentRect;
  for (final region in environment.activeDivisionRegions) {
    final fold = region.frame;
    if (fold.height < fold.width || !fold.overlaps(content)) {
      continue;
    }
    if ((fold.center.dx - content.center.dx).abs() > 4) {
      continue;
    }
    return math.max(EHConst.waterfallFlowLargeCrossAxisSpacing, fold.width);
  }
  return null;
}
