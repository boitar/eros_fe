import 'dart:math' as math;

import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/pages/image_view/view/view_widget.dart';
import 'package:eros_fe/utils/logger.dart';
import 'package:eros_fe/widget/image/eh_cached_network_image.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../controller/view_controller.dart';
import '../controller/view_state.dart';
import 'reader_continuous_viewport.dart';
import 'view_image.dart';

class ImageListView extends StatefulWidget {
  const ImageListView({super.key});

  @override
  State<ImageListView> createState() => _ImageListViewState();
}

class _ImageListViewState extends State<ImageListView> {
  final ViewExtController controller = Get.find();

  late Offset downPosition;

  @override
  Widget build(BuildContext context) {
    final vState = controller.vState;
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = MediaQuery.paddingOf(context);
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final contentWidth = math.max(1.0, width - padding.horizontal);

        final listView = ReaderContinuousViewport(
          positions: controller.itemPositionsListener,
          itemScrollController: controller.itemScrollController,
          trailingSpacing: vState.showPageInterval ? 8 : 0,
          reflowKey: (contentWidth, padding),
          builder: (context, offsetController) =>
              ScrollablePositionedList.builder(
            initialScrollIndex: vState.currentItemIndex,
            minCacheExtent: 0.0,
            padding: EdgeInsets.fromLTRB(
              padding.left,
              padding.top,
              padding.right,
              padding.bottom,
            ),
            itemScrollController: controller.itemScrollController,
            scrollOffsetController: offsetController,
            itemPositionsListener: controller.itemPositionsListener,
            itemCount: vState.fileCount,
            itemBuilder: itemBuilder(contentWidth),
          ),
        );
        final imageListView = Container(
          color: CupertinoTheme.of(context).scaffoldBackgroundColor,
          child: listView,
        );

        return PhotoViewGallery.builder(
          itemCount: 1,
          builder: (_, __) {
            return PhotoViewGalleryPageOptions.customChild(
              scaleStateController: controller.photoViewScaleStateController,
              initialScale: PhotoViewComputedScale.contained * 1.0,
              minScale: PhotoViewComputedScale.contained * 1.0,
              maxScale: PhotoViewComputedScale.contained * 3.0,
              scaleStateCycle: listViewScaleStateCycle,
              child: imageListView,
            );
          },
        );
      },
    );
  }

  PhotoViewScaleState listViewScaleStateCycle(PhotoViewScaleState actual) {
    logger.d('actual $actual');
    switch (actual) {
      case PhotoViewScaleState.initial:
        return PhotoViewScaleState.originalSize;
      default:
        return PhotoViewScaleState.initial;
    }
  }

  // 计算图片容器高度
  double? calcHeight(
    int itemSer,
    ViewExtState vState,
    double contentWidth,
  ) {
    // 从已下载进入阅读的情况 imageMap 会未初始化
    try {
      if (vState.imageMap?[itemSer]?.hide ?? false) {
        return 150.0;
      }
    } catch (_) {}

    // 如果存在缓存的图片尺寸信息
    if (vState.imageSizeMap[itemSer] != null) {
      final imageSize = vState.imageSizeMap[itemSer]!;
      return imageSize.height * (contentWidth / imageSize.width);
    }

    // 不存在则根据大图进行计算
    try {
      final curImage = vState.imageMap?[itemSer];
      return curImage!.imageHeight! * (contentWidth / curImage.imageWidth!);
    } on Exception catch (_) {
      // 根据缩略图进行计算
      final curImage = vState.imageMap?[itemSer];
      return curImage!.thumbHeight! * (contentWidth / curImage.thumbWidth!);
    } catch (e) {
      return null;
    }
  }

  Widget Function(BuildContext context, int index) itemBuilder(
    double contentWidth,
  ) {
    return (BuildContext context, int index) {
      final Size size = MediaQuery.sizeOf(context);
      final int itemSer = index + 1;

      // return Padding(
      //   padding: const EdgeInsets.symmetric(vertical: 100),
      //   child: Text(
      //     '$itemSer',
      //     style: TextStyle(color: Colors.white),
      //   ),
      // );

      return ConstrainedBox(
        key: ValueKey(itemSer),
        constraints: BoxConstraints(
          minWidth: contentWidth,
        ),
        child: GetBuilder<ViewExtController>(
            id: '$idImageListView$itemSer',
            builder: (logic) {
              loggerSimple.t('builder itemBuilder $itemSer');

              final vState = logic.vState;

              // 计算容器高度
              double? height = calcHeight(itemSer, vState, contentWidth);

              if (height != null) {
                height += vState.showPageInterval ? 8 : 0;
              }

              loggerSimple.t('builder itemBuilder $itemSer $height');

              final viewImage = ViewImage(
                imageSer: itemSer,
                enableDoubleTap: false,
                mode: ExtendedImageMode.none,
              );

              final int gid = int.tryParse(logic.vState.gid ?? '') ?? 0;
              final ser = index + 1;
              final viewImage2 = ExtendedImage(
                  image: getEhImageProvider('${gid}_${ser}_', ser: ser),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  mode: ExtendedImageMode.none,
                  loadStateChanged: (ExtendedImageState state) {
                    final ImageInfo? imageInfo = state.extendedImageInfo;
                    if (state.extendedImageLoadState == LoadState.completed ||
                        imageInfo != null) {
                      // 加载完成 显示图片
                      controller.setScale100(imageInfo!, size);

                      // 重新设置图片容器大小
                      if (vState.imageSizeMap[ser] == null) {
                        vState.imageSizeMap[ser] = Size(
                            imageInfo.image.width.toDouble(),
                            imageInfo.image.height.toDouble());
                        Future.delayed(const Duration(milliseconds: 100)).then(
                            (value) =>
                                controller.update(['$idImageListView${ser}']));
                      }

                      controller.onLoadCompleted(ser);

                      return controller.vState.viewMode != ViewMode.topToBottom
                          ? Hero(
                              tag: '$ser',
                              child: state.completedWidget,
                              createRectTween: (Rect? begin, Rect? end) =>
                                  MaterialRectCenterArcTween(
                                      begin: begin, end: end),
                            )
                          : state.completedWidget;
                    } else if (state.extendedImageLoadState ==
                        LoadState.loading) {
                      // 显示加载中
                      final ImageChunkEvent? loadingProgress =
                          state.loadingProgress;
                      final double? progress =
                          loadingProgress?.expectedTotalBytes != null
                              ? (loadingProgress?.cumulativeBytesLoaded ?? 0) /
                                  (loadingProgress?.expectedTotalBytes ?? 1)
                              : null;

                      return ViewLoading(
                        ser: ser,
                        // progress: progress,
                        duration: vState.viewMode != ViewMode.topToBottom
                            ? const Duration(milliseconds: 100)
                            : null,
                        debugLabel: '### Widget fileImage 加载图片文件',
                      );
                    }
                  });

              return Container(
                padding:
                    EdgeInsets.only(bottom: vState.showPageInterval ? 8 : 0),
                height: height ?? context.mediaQueryShortestSide,
                // child: !kDebugMode ? viewImage : viewImage2,
                child: viewImage,
              );
            }),
      );
    };
  }

  double? calcHeight2(int itemSer, ViewExtState vState) {
    try {
      final curImage = vState.imageMap?[itemSer];
      return curImage!.imageHeight! * (context.width / curImage.imageWidth!);
    } on Exception catch (_) {
      final curImage = vState.imageMap?[itemSer];
      return curImage!.thumbHeight! * (context.width / curImage.thumbWidth!);
    } catch (e) {
      return null;
    }
  }

  Widget Function(BuildContext context, int index) itemBuilder2() {
    return (BuildContext context, int index) {
      final int itemSer = index + 1;

      return AutoScrollTag(
        key: ValueKey(index),
        controller: controller.autoScrollController,
        index: index,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: context.width,
          ),
          child: GetBuilder<ViewExtController>(
              id: '$idImageListView$itemSer',
              builder: (logic) {
                final vState = logic.vState;
                double? height = calcHeight2(itemSer, vState);

                if (height != null) {
                  height += vState.showPageInterval ? 8 : 0;
                }

                return Container(
                  padding:
                      EdgeInsets.only(bottom: vState.showPageInterval ? 8 : 0),
                  height: height,
                  child: ViewImage(
                    imageSer: itemSer,
                    enableDoubleTap: false,
                    mode: ExtendedImageMode.none,
                  ),
                );
              }),
        ),
      );
    };
  }
}
