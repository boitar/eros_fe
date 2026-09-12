import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/item/controller/galleryitem_controller.dart';
import 'package:eros_fe/pages/item/gallery_item_flow.dart';
import 'package:eros_fe/pages/item/gallery_item_flow_large.dart';
import 'package:flutter/cupertino.dart';
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
    this.lastTopItemIndex,
    super.key,
  });

  final List<GalleryProvider> galleryProviders;
  final dynamic tabTag;
  final String? next;
  final VoidCallback? lastComplete;
  final bool large;
  final Key? centerKey;
  final int? lastTopItemIndex;

  EhSettingService get _ehSettingService => Get.find();

  @override
  Widget build(BuildContext context) {
    final double _padding = large
        ? EHConst.waterfallFlowLargeCrossAxisSpacing
        : EHConst.waterfallFlowCrossAxisSpacing;

    final crossAxisSpacing = large
        ? EHConst.waterfallFlowLargeCrossAxisSpacing
        : EHConst.waterfallFlowCrossAxisSpacing;

    final mainAxisSpacing = large
        ? EHConst.waterfallFlowLargeMainAxisSpacing
        : EHConst.waterfallFlowMainAxisSpacing;

    return SliverPadding(
      padding: EdgeInsets.all(_padding),
      sliver: SliverWaterfallFlow(
        key: key,
        gridDelegate: SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: getMaxCrossAxisExtent(),
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
          lastChildLayoutTypeBuilder: (int index) =>
              index == galleryProviders.length
                  ? LastChildLayoutType.foot
                  : LastChildLayoutType.none,
        ),
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
              return GalleryItemFlowLarge(
                key: index == lastTopItemIndex
                    ? centerKey
                    : ValueKey(_provider.gid),
                galleryProvider: _provider,
                tabTag: tabTag,
              );
            } else {
              return GalleryItemFlow(
                key: index == lastTopItemIndex
                    ? centerKey
                    : ValueKey(_provider.gid),
                galleryProvider: _provider,
                tabTag: tabTag,
              );
            }
          },
          childCount: galleryProviders.length,
        ),
      ),
    );
  }

  double getMaxCrossAxisExtent() {
    if (large) {
      final itemConfig =
          _ehSettingService.getItemConfig(ListModeEnum.waterfallLarge);
      const defaultMaxCrossAxisExtent =
          EHConst.waterfallFlowLargeMaxCrossAxisExtent;
      if (itemConfig?.enableCustomWidth ?? false) {
        return itemConfig?.customWidth?.toDouble() ?? defaultMaxCrossAxisExtent;
      } else {
        return defaultMaxCrossAxisExtent;
      }
    } else {
      final itemConfig =
          _ehSettingService.getItemConfig(ListModeEnum.waterfall);
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
}
