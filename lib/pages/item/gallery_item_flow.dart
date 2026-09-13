import 'package:eros_fe/pages/item/favorite_icon.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/pages/item/controller/galleryitem_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:rotated_corner_decoration/rotated_corner_decoration.dart';

import 'cover_ratio.dart';
import 'gallery_item.dart';

const double kRadius = 6.0;
const double kCategoryWidth = 28.0;
const double kCategoryHeight = 22.0;

class GalleryItemFlow extends StatelessWidget {
  const GalleryItemFlow(
      {Key? key, required this.tabTag, required this.galleryProvider})
      : super(key: key);

  final dynamic tabTag;
  final GalleryProvider galleryProvider;

  GalleryItemController get galleryProviderController =>
      Get.find(tag: galleryProvider.gid);

  Widget _buildFavcatIcon() {
    return Obx(() {
      // logger.d('${_galleryProviderController.isFav}');
      return Container(
        child: galleryProviderController.hasFavoriteColor
            ? Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                    color: const Color(0xDDFFFFFF),
                    borderRadius: BorderRadius.circular(4)),
                child: FavoriteIcon(
                    category: galleryProviderController.favCat, size: 12),
              )
            : Container(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget item = LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      final GalleryProvider galleryProvider =
          galleryProviderController.galleryProvider;

      final Color _colorCategory = CupertinoDynamicColor.resolve(
          ThemeColors.catColor[galleryProvider.category ?? 'default'] ??
              CupertinoColors.systemBackground,
          context);

      // 获取图片高度：统一走比例守卫，尺寸缺失/非法回退默认比例，
      // 不再裸用 imgHeight 像素值当逻辑高度（小图/缺尺寸时高度失真）
      double? _getHeight() {
        if (!constraints.maxWidth.isFinite) {
          return null;
        }
        return constraints.maxWidth /
            coverAspectRatio(
              imgWidth: galleryProvider.imgWidth ?? 0,
              imgHeight: galleryProvider.imgHeight ?? 0,
            );
      }

      final Widget container = Container(
        child: Stack(
          children: <Widget>[
            Hero(
              tag: '${galleryProvider.gid}_cover_${tabTag}',
              child: Container(
                decoration: BoxDecoration(
                    // borderRadius: BorderRadius.circular(kRadius), //圆角
                    // ignore: prefer_const_literals_to_create_immutables
                    boxShadow: [
                      //阴影
                      BoxShadow(
                        color: CupertinoDynamicColor.resolve(
                            CupertinoColors.systemGrey6, context),
                        blurRadius: 5,
                      )
                    ]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(kRadius),
                  child: Container(
                    foregroundDecoration: RotatedCornerDecoration.withColor(
                      color: _colorCategory.withOpacity(0.8),
                      // labelInsets:
                      //     const LabelInsets(baselineShift: 0.2, start: 2),
                      // geometry: const BadgeGeometry(
                      //     width: kCategoryWidth, height: kCategoryHeight),
                      spanBaselineShift: 0.2,
                      spanHorizontalOffset: 2,
                      badgeSize: const Size(kCategoryWidth, kCategoryHeight),
                      textSpan: TextSpan(
                        text: galleryProvider.translated ?? '',
                        style: const TextStyle(
                            fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                    alignment: Alignment.center,
                    height: _getHeight(),
                    child: CoverImg(imgUrl: galleryProvider.imgUrl!),
                  ),
                ),
              ),
            ),
            Positioned(left: 4, bottom: 4, child: _buildFavcatIcon()),
          ],
        ),
      );

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        child: container,
        onTap: () => galleryProviderController.onTap(tabTag),
        onLongPress: galleryProviderController.onLongPress,
      ).autoCompressKeyboard(context);
    });

    return item;
  }
}
