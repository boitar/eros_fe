import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/debug/offline_acceptance.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/item/controller/galleryitem_controller.dart';
import 'package:eros_fe/pages/item/gallery_grid_tags.dart';
import 'package:eros_fe/pages/item/gallery_item_grid.dart';
import 'package:eros_fe/pages/item/gallery_item_grid_placeholder.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:keframe/keframe.dart';

class EhGridView extends StatelessWidget {
  const EhGridView(this.galleryProviders, this.tabTag,
      {this.next,
      this.lastComplete,
      this.large = false,
      this.mode = ListModeEnum.grid,
      this.centerKey,
      this.firstCardKey,
      this.lastTopItemIndex,
      super.key})
      : assert(mode == ListModeEnum.grid || mode == ListModeEnum.gridTags);

  final List<GalleryProvider> galleryProviders;
  final dynamic tabTag;
  final String? next;
  final VoidCallback? lastComplete;
  final bool large;
  final ListModeEnum mode;
  final Key? centerKey;
  final Key? firstCardKey;
  final int? lastTopItemIndex;

  EhSettingService get _ehSettingService => Get.find();

  @override
  Widget build(BuildContext context) {
    final showTags = mode == ListModeEnum.gridTags;
    final delegate = SliverChildBuilderDelegate(
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
        Get.lazyReplace(() => _provider, tag: _provider.gid, fenix: true);
        Get.lazyReplace(
            () => GalleryItemController(
                galleryProvider: Get.find(tag: _provider.gid)),
            tag: _provider.gid,
            fenix: true);

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
        return offlineGallerySemantics(_provider.gid, keyed);
      },
      childCount: galleryProviders.length,
    );
    return SliverPadding(
      padding: const EdgeInsets.all(EHConst.gridCrossAxisSpacing),
      sliver: showTags
          ? Obx(() => GalleryGridTagsSliver(
                maxCrossAxisExtent: getMaxCrossAxisExtent(),
                delegate: delegate,
              ))
          : SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: getMaxCrossAxisExtent(),
                crossAxisSpacing: EHConst.gridCrossAxisSpacing,
                mainAxisSpacing: EHConst.gridMainAxisSpacing,
                childAspectRatio: EHConst.gridChildAspectRatio,
              ),
              delegate: delegate,
            ),
    );
  }

  double getMaxCrossAxisExtent() {
    final itemConfig = _ehSettingService.getItemConfig(mode);
    const defaultMaxCrossAxisExtent = EHConst.gridMaxCrossAxisExtent;
    if (itemConfig?.enableCustomWidth ?? false) {
      return itemConfig?.customWidth?.toDouble() ?? defaultMaxCrossAxisExtent;
    } else {
      return defaultMaxCrossAxisExtent;
    }
  }
}
