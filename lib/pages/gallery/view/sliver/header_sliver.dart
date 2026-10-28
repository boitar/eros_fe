import 'dart:math';

import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_controller.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_state.dart';
import 'package:eros_fe/pages/gallery/view/gallery_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:sliver_tools/sliver_tools.dart';

import '../const.dart';
import '../gallery_favcat.dart';

class GalleryHeaderSliver extends StatelessWidget {
  const GalleryHeaderSliver({
    Key? key,
    required this.initGalleryProvider,
    this.tabTag,
  }) : super(key: key);

  final GalleryProvider initGalleryProvider;
  final Object? tabTag;

  @override
  Widget build(BuildContext context) {
    final _controller =
        Get.find<GalleryPageController>(tag: pageCtrlTagOf(context));
    final _pageState = _controller.gState;
    return SliverPadding(
      padding: const EdgeInsets.all(kPadding),
      sliver: MultiSliver(
        children: [
          SizedBox(
            height: galleryHeaderHeightFor(context),
            child: Row(
              children: [
                HeroMode(
                  enabled: _pageState.hideNavigationBtn || isLayoutLarge,
                  child: CoverImage(
                    imageUrl: initGalleryProvider.imgUrl,
                    heroTag: '${initGalleryProvider.gid}_cover_$tabTag',
                  ),
                ),
                Expanded(
                  child: GetBuilder<GalleryPageController>(
                      assignId: true,
                      id: GetIds.PAGE_VIEW_HEADER,
                      tag: pageCtrlTagOf(context),
                      builder: (logic) {
                        final _pageState = logic.gState;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 标题
                            GalleryTitle(
                              title: _pageState.mainTitle,
                              alternateTitle: _pageState.subTitle,
                            ),
                            // 上传用户
                            GalleryUploader(
                                uploader:
                                    _pageState.galleryProvider?.uploader ?? ''),
                            const SizedBox(
                              height: 8,
                            ),

                            const Spacer(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                const Spacer(),
                                // 收藏按钮
                                const GalleryFavButton(),
                                // 阅读按钮
                                ReadButton(gid: initGalleryProvider.gid ?? '')
                                    .paddingOnly(right: 6),
                              ],
                            ).marginOnly(top: 10),
                          ],
                        );
                      }),
                ),
              ],
            ),
          ),
          GalleryInfoBarSliver(pageController: _controller),
        ],
      ),
    );
  }
}

class GalleryInfoBarSliver extends StatelessWidget {
  const GalleryInfoBarSliver({Key? key, required this.pageController})
      : super(key: key);
  final GalleryPageController pageController;

  GalleryPageState get _pageState => pageController.gState;
  static const paddingRight = 5.0;

  @override
  Widget build(BuildContext context) {
    final TextStyle _hearTextStyle = TextStyle(
      fontSize: 13,
      color: CupertinoDynamicColor.resolve(CupertinoColors.label, context),
    );

    Widget languageWidget() => _InfoWidget(
          text: _pageState.galleryProvider?.language,
          icon: FontAwesomeIcons.language,
        );

    Widget imageCountWidget() => _InfoWidget(
          text: _pageState.galleryProvider?.filecount,
          icon: FontAwesomeIcons.solidImages,
        );
    Widget fileSizeWidget() => _InfoWidget(
          text: _pageState.galleryProvider?.filesizeText,
          icon: FontAwesomeIcons.fileArrowDown,
        );
    Widget favCountWidget() => _InfoWidget(
          text: _pageState.galleryProvider?.favoritedCount,
          icon: FontAwesomeIcons.solidHeart,
        );
    Widget rateCountWidget() => _InfoWidget(
          text: _pageState.galleryProvider?.ratingCount,
          icon: FontAwesomeIcons.solidStar,
        );
    Widget potTimeWidget() => _InfoWidget(
          text: _pageState.galleryProvider?.postTime,
          icon: FontAwesomeIcons.solidClock,
        );

    final postTimeTextSize = getTextSize('0000-00-00 00:00', _hearTextStyle);
    final _maxCrossAxisExtent = max(160.0, postTimeTextSize.width + 60.0);
    final infoRowHeight = max(
      20.0,
      MediaQuery.textScalerOf(context).scale(13) * 1.2 + 2,
    );
    logger.t('_maxCrossAxisExtent $_maxCrossAxisExtent  $postTimeTextSize');

    Widget infoWidget() => Container(
          margin: const EdgeInsets.only(top: 8),
          child: Container(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!context.isTablet)
                  Container(
                    decoration: BoxDecoration(
                      color: CupertinoDynamicColor.resolve(
                          CupertinoColors.secondaryLabel, context),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    margin: const EdgeInsets.only(right: 6),
                    width: 4,
                    height: max(48, infoRowHeight * 2),
                  ),
                Expanded(
                  child: GridView(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(0),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      mainAxisExtent: infoRowHeight,
                      maxCrossAxisExtent: _maxCrossAxisExtent,
                    ),
                    shrinkWrap: true,
                    children: [
                      languageWidget(),
                      imageCountWidget(),
                      fileSizeWidget(),
                      favCountWidget(),
                      rateCountWidget(),
                      potTimeWidget(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Get.toNamed(
          EHRoutes.galleryInfo,
          id: detailNavigatorId,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: GetBuilder<GalleryPageController>(
          assignId: true,
          tag: pageCtrlTagOf(context),
          id: GetIds.PAGE_VIEW_HEADER,
          builder: (logic) {
            final GalleryPageState _pageState = logic.gState;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.only(top: 8.0, right: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    // ignore: prefer_const_literals_to_create_immutables
                    children: <Widget>[
                      // 评分
                      GalleryRating(
                        rating: _pageState.galleryProvider?.rating ?? 0,
                        ratingFB:
                            _pageState.galleryProvider?.ratingFallBack ?? 0,
                        color: ThemeColors.colorRatingMap[
                            _pageState.galleryProvider?.colorRating?.trim() ??
                                'ir'],
                      ),
                      // 评分人次
                      // Padding(
                      //   padding: const EdgeInsets.symmetric(horizontal: 4),
                      //   child: Text(
                      //       _pageState.galleryProvider?.ratingCount ?? '',
                      //       style: TextStyle(
                      //         fontSize: 10,
                      //         color: CupertinoDynamicColor.resolve(
                      //             CupertinoColors.secondaryLabel, context),
                      //       )),
                      // ),
                      const Spacer(),
                      // 类型
                      GalleryCategory(
                          category: _pageState.galleryProvider?.category ?? ''),
                    ],
                  ),
                ),
                infoWidget(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InfoWidget extends StatelessWidget {
  const _InfoWidget({
    Key? key,
    this.icon,
    this.text,
  }) : super(key: key);

  final FaIconData? icon;
  final String? text;

  static const paddingRight = 5.0;

  @override
  Widget build(BuildContext context) {
    final TextStyle _hearTextStyle = TextStyle(
      fontSize: 13,
      color: CupertinoDynamicColor.resolve(CupertinoColors.label, context),
    );

    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        FaIcon(
          icon,
          color: CupertinoDynamicColor.resolve(
              CupertinoColors.secondaryLabel, context),
          size: 12,
        ).paddingOnly(right: paddingRight),
        Expanded(
          child: Text(
            text ?? '...',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _hearTextStyle,
          ),
        ),
      ],
    );
  }
}

class GalleryInfoView extends StatelessWidget {
  const GalleryInfoView({Key? key, required this.pageController})
      : super(key: key);
  final GalleryPageController pageController;

  GalleryPageState get _pageState => pageController.gState;
  static const paddingRight = 6.0;

  @override
  Widget build(BuildContext context) {
    final TextStyle _hearTextStyle = TextStyle(
      fontSize: 12,
      color: CupertinoDynamicColor.resolve(
          CupertinoColors.secondaryLabel, context),
    );

    Widget languageWidget() => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              FontAwesomeIcons.language,
              color: CupertinoDynamicColor.resolve(
                  CupertinoColors.secondaryLabel, context),
              size: 12,
            ).paddingOnly(right: paddingRight),
            Text(
              _pageState.galleryProvider?.language ?? '...',
              style: _hearTextStyle,
            ),
          ],
        );

    Widget imageCountWidget() => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              FontAwesomeIcons.solidImages,
              size: 12,
              color: CupertinoDynamicColor.resolve(
                  CupertinoColors.secondaryLabel, context),
            ).paddingOnly(right: paddingRight),
            Text(
              _pageState.galleryProvider?.filecount ?? '...',
              style: _hearTextStyle,
            ),
          ],
        );
    Widget fileSizeWidget() => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              FontAwesomeIcons.fileArrowDown,
              size: 12,
              color: CupertinoDynamicColor.resolve(
                  CupertinoColors.secondaryLabel, context),
            ).paddingOnly(right: paddingRight),
            Text(
              _pageState.galleryProvider?.filesizeText ?? '...',
              style: _hearTextStyle,
            ),
          ],
        );
    Widget favCountWidget() => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              FontAwesomeIcons.solidHeart,
              // color: CupertinoColors.systemRed,
              color: CupertinoDynamicColor.resolve(
                  CupertinoColors.secondaryLabel, context),
              size: 12,
            ).paddingOnly(right: paddingRight),
            Text(_pageState.galleryProvider?.favoritedCount ?? '...',
                style: _hearTextStyle),
          ],
        );
    Widget rateCountWidget() => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              FontAwesomeIcons.solidStar,
              color: CupertinoDynamicColor.resolve(
                  CupertinoColors.secondaryLabel, context),
              size: 12,
            ).paddingOnly(right: paddingRight),
            Text(_pageState.galleryProvider?.ratingCount ?? '...',
                style: _hearTextStyle),
          ],
        );
    Widget potTimeWidget() => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              FontAwesomeIcons.solidClock,
              size: 12,
              color: CupertinoDynamicColor.resolve(
                  CupertinoColors.secondaryLabel, context),
            ).paddingOnly(right: paddingRight),
            Text(
              _pageState.galleryProvider?.postTime ?? '...',
              style: _hearTextStyle,
              maxLines: 2,
            ),
          ],
        );

    Widget infoWidget() => Row(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
              ),
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                width: 2,
                color: CupertinoDynamicColor.resolve(
                    CupertinoColors.secondaryLabel, context),
              ),
            ),
            Expanded(
              child: ListView(
                // mainAxisSize: MainAxisSize.min,
                // crossAxisAlignment: CrossAxisAlignment.start,
                padding: const EdgeInsets.all(0),
                shrinkWrap: true,
                children: [
                  languageWidget(),
                  favCountWidget(),
                  // rateCountWidget(),
                  imageCountWidget(),
                  fileSizeWidget(),
                  potTimeWidget(),
                ],
              ),
            ),
          ],
        );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Get.toNamed(
          EHRoutes.galleryInfo,
          id: detailNavigatorId,
        );
      },
      child: infoWidget(),
    );
  }
}
