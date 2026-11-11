import 'dart:math' as math;

import 'package:eros_fe/adaptive/gallery_anchor.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/debug/offline_acceptance.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/item/controller/galleryitem_controller.dart';
import 'package:eros_fe/pages/item/gallery_grid_tags.dart';
import 'package:eros_fe/pages/item/gallery_item_grid.dart';
import 'package:eros_fe/pages/item/gallery_item_grid_placeholder.dart';
import 'package:eros_fe/pages/tab/view/list/card_size.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:keframe/keframe.dart';

class EhGridView extends StatelessWidget {
  const EhGridView(
    this.galleryProviders,
    this.tabTag, {
    this.next,
    this.lastComplete,
    this.large = false,
    this.mode = ListModeEnum.grid,
    this.centerKey,
    this.firstCardKey,
    this.topPadding,
    this.lastTopItemIndex,
    super.key,
  }) : assert(mode == ListModeEnum.grid || mode == ListModeEnum.gridTags);

  final List<GalleryProvider> galleryProviders;
  final dynamic tabTag;
  final String? next;
  final VoidCallback? lastComplete;
  final bool large;
  final ListModeEnum mode;
  final Key? centerKey;
  final Key? firstCardKey;
  final double? topPadding;
  final int? lastTopItemIndex;

  EhSettingService get _ehSettingService => Get.find();

  @override
  Widget build(BuildContext context) {
    final showTags = mode == ListModeEnum.gridTags;
    final delegate = SliverChildBuilderDelegate((
      BuildContext context,
      int index,
    ) {
      if (galleryProviders.length - 1 < index) {
        return const SizedBox.shrink();
      }

      if (index == galleryProviders.length - 1 && (next?.isNotEmpty ?? false)) {
        // 加载完成最后一项的回调
        lastComplete?.call();
      }

      final GalleryProvider _provider = galleryProviders[index];
      Get.lazyReplace(() => _provider, tag: _provider.gid, fenix: true);
      Get.lazyReplace(
        () => GalleryItemController(
          galleryProvider: Get.find(tag: _provider.gid),
        ),
        tag: _provider.gid,
        fenix: true,
      );

      final card = GalleryItemGrid(
        key: index == lastTopItemIndex ? centerKey : ValueKey(_provider.gid),
        galleryProvider: _provider,
        tabTag: tabTag,
        showTags: showTags,
      );
      // The tag grid already has a known extent and lazy sliver children.
      // Build visible cards immediately; images retain their own placeholder.
      final item = showTags
          ? card
          : FrameSeparateWidget(
              index: index,
              placeHolder: const GalleryItemGridPlaceHolder(),
              child: card,
            );
      final keyed = index == 0 && firstCardKey != null
          ? KeyedSubtree(key: firstCardKey, child: item)
          : item;
      return GalleryAnchorItem(
        id: _provider.gid ?? '$index',
        index: index,
        child: offlineGallerySemantics(_provider.gid, keyed),
      );
    }, childCount: galleryProviders.length);
    return SliverPadding(
      padding: const EdgeInsets.all(EHConst.gridCrossAxisSpacing)
          .copyWith(top: topPadding),
      sliver: showTags
          ? Obx(() {
              // The tag grid sizes its tiles from the title line budget, so it
              // must rebuild when the full-title switch changes.
              _ehSettingService.fullTitleInGalleryPage;
              return GalleryGridTagsSliver(
                maxCrossAxisExtent: getMaxCrossAxisExtent(),
                delegate: delegate,
              );
            })
          : Obx(() {
              if (!_ehSettingService.fullTitleInGalleryPage) {
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: getMaxCrossAxisExtent(),
                    crossAxisSpacing: EHConst.gridCrossAxisSpacing,
                    mainAxisSpacing: EHConst.gridMainAxisSpacing,
                    childAspectRatio: EHConst.gridChildAspectRatio,
                  ),
                  delegate: delegate,
                );
              }
              final widthDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: getMaxCrossAxisExtent(),
                crossAxisSpacing: EHConst.gridCrossAxisSpacing,
                mainAxisSpacing: EHConst.gridMainAxisSpacing,
              );
              final extra = MediaQuery.textScalerOf(context)
                  .scale(14.4)
                  .ceilToDouble();
              return SliverLayoutBuilder(
                builder: (context, constraints) {
                  final layout = widthDelegate.getLayout(
                    constraints,
                  ) as SliverGridRegularTileLayout;
                  final width = layout.childCrossAxisExtent;
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: getMaxCrossAxisExtent(),
                      crossAxisSpacing: EHConst.gridCrossAxisSpacing,
                      mainAxisSpacing: EHConst.gridMainAxisSpacing,
                      // The scaled row is the baseline; narrow columns and
                      // large text need the measured text block instead.
                      mainAxisExtent: math.max(
                        width * 1.8 + extra,
                        gridFullTitleMinHeight(context, width),
                      ),
                    ),
                    delegate: delegate,
                  );
                },
              );
            }),
    );
  }

  double getMaxCrossAxisExtent() => CardSize.maxCrossAxisExtent(
    mode,
    CardSize.of(mode, _ehSettingService.getItemConfig(mode)),
  );
}
