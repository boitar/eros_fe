import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../common/service/theme_service.dart';
import 'gallery_grid_tags.dart';
import 'item_base.dart';

const int kTitleMaxLines = 2;
const double kRadius = 6.0;
const double kCategoryWidth = 32.0;
const double kCategoryHeight = 20.0;
const double kCoverRatio = 1.4;

class GalleryItemGridPlaceHolder extends StatelessWidget {
  const GalleryItemGridPlaceHolder({
    Key? key,
    this.showTags = false,
    this.showLoadingIndicator = true,
  }) : super(key: key);

  final bool showTags;
  final bool showLoadingIndicator;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      // 封面高度
      final coverHeight =
          (showTags ? GalleryGridTagsMetrics.coverHeightRatio : kCoverRatio) *
              constraints.maxWidth;

      return Container(
        decoration: BoxDecoration(
          color: ehTheme.itemBackgroundColor,
          borderRadius: BorderRadius.circular(kRadius), //圆角
          boxShadow: ehTheme.isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: CupertinoDynamicColor.resolve(
                        CupertinoColors.systemGrey3, Get.context!),
                    blurRadius: 10,
                  )
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            /// 画廊封面
            Container(
              width: constraints.maxWidth,
              height: coverHeight,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(kRadius),
                  topRight: Radius.circular(kRadius),
                ),
                child: Container(
                  color: CupertinoDynamicColor.resolve(
                      CupertinoColors.systemGrey6, context),
                  child: showLoadingIndicator
                      ? const CupertinoActivityIndicator()
                      : null,
                ),
              ),
            ),

            /// 画廊信息等
            if (showTags)
              const _GridTagsPlaceholderInfo()
            else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Expanded(child: PlaceHolderLine()),
                        ],
                      ),
                    ],
                  ).paddingAll(6.0),
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _GridTagsPlaceholderInfo extends StatelessWidget {
  const _GridTagsPlaceholderInfo();

  @override
  Widget build(BuildContext context) {
    final metrics = GalleryGridTagsMetrics.of(context);
    final color =
        CupertinoDynamicColor.resolve(CupertinoColors.systemGrey5, context);
    Widget bar(double height) => Container(
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        );

    return Padding(
      padding: const EdgeInsets.all(GalleryGridTagsMetrics.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: metrics.titleHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [bar(6), bar(6)],
            ),
          ),
          const SizedBox(height: GalleryGridTagsMetrics.titleGap),
          SizedBox(
            height: metrics.tagsHeight,
            child: Column(children: [
              bar(metrics.tagRowExtent),
              const SizedBox(height: GalleryGridTagsMetrics.tagGap),
              bar(metrics.tagRowExtent),
            ]),
          ),
          const SizedBox(height: GalleryGridTagsMetrics.timeGap),
          SizedBox(
            height: metrics.timeLineHeight,
            child: Center(child: bar(6)),
          ),
        ],
      ),
    );
  }
}
