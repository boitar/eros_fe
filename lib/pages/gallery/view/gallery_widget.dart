import 'package:collection/collection.dart';
import 'package:eros_fe/common/controller/block_controller.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_controller.dart';
import 'package:eros_fe/pages/gallery/view/comment_item.dart';
import 'package:eros_fe/pages/gallery/view/taginfo_dialog.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:eros_fe/widget/rating_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

/// 封面小图 纯StatelessWidget
class CoveTinyImage extends StatelessWidget {
  const CoveTinyImage(
      {Key? key, required this.imgUrl, required this.statusBarHeight})
      : super(key: key);

  final String imgUrl;
  final double statusBarHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      child: ClipRRect(
        // 圆角
        borderRadius: BorderRadius.circular(4),
        child: EhNetworkImage(
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          imageUrl: imgUrl,
        ),
        // child: NetworkExtendedImage(
        //   url: imgUrl,
        //   height: 44,
        //   width: 44,
        //   fit: BoxFit.cover,
        // ),
      ),
    );
  }
}

// 画廊封面
class CoverImage extends StatelessWidget {
  const CoverImage({
    Key? key,
    required this.imageUrl,
    required this.heroTag,
    this.imgHeight,
    this.imgWidth,
  }) : super(key: key);

  static const double kWidth = 145.0;
  final String? imageUrl;

  // ${_item.gid}_${_item.token}_cover_$_tabIndex
  final Object heroTag;

  final double? imgHeight;
  final double? imgWidth;

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (_) {
      if (imageUrl != null && imageUrl!.isNotEmpty) {
        Widget image = Container(
          decoration: BoxDecoration(
            boxShadow: [
              //阴影
              BoxShadow(
                color: CupertinoDynamicColor.resolve(
                    CupertinoColors.systemGrey4, context),
                blurRadius: 10,
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: imgHeight,
              width: imgWidth,
              child: EhNetworkImage(
                placeholder: (_, __) {
                  return Container(
                    alignment: Alignment.center,
                    color: CupertinoDynamicColor.resolve(
                        CupertinoColors.systemGrey5, context),
                    child: const CupertinoActivityIndicator(),
                  );
                },
                imageUrl: (imageUrl ?? '').handleUrl,
                fit: BoxFit.cover,
              ),
            ),
          ),
        );

        return Container(
          width: kWidth,
          margin: const EdgeInsets.only(right: 10),
          child: Center(
            child: Hero(
              tag: heroTag,
              child: image,
            ),
          ),
        );
      } else {
        return Container(
          width: kWidth,
          margin: const EdgeInsets.only(right: 10),
          child: Container(
            decoration: BoxDecoration(
                color: CupertinoColors.systemBackground,
                borderRadius: BorderRadius.circular(6.0), //圆角
                // ignore: prefer_const_literals_to_create_immutables
                boxShadow: [
                  //阴影
                  const BoxShadow(
                    color: CupertinoColors.systemGrey2,
                    blurRadius: 2.0,
                  )
                ]),
            // child: ClipRRect(
            //   borderRadius: BorderRadius.circular(6),
            //   child: Container(
            //     color: CupertinoColors.systemBackground,
            //   ),
            // ),
          ),
        );
      }
    });
  }
}

class GalleryTitle extends StatelessWidget {
  const GalleryTitle({
    Key? key,
    required this.title,
    this.alternateTitle,
  }) : super(key: key);

  // final GalleryPageController _pageController = Get.find(tag: pageCtrlTag);
  // GalleryPageState get _pageState => _pageController.gState;

  final String title;

  /// The title in the other language, offered in the full-title sheet.
  final String? alternateTitle;

  @override
  Widget build(BuildContext context) {
    /// 构建标题
    ///
    /// 问题 文字如果使用 SelectableText 并且页面拉到比较下方的时候
    /// 在返回列表时会异常 疑似和封面图片的Hero动画有关
    /// 如果修改封面图片的 Hero tag ,即不使用 Hero 动画
    /// 异常则不会出现
    ///
    /// 暂时放弃使用 SelectableText
    ///
    /// 20210107 改用SelectableText测试

    return SelectionArea(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showGalleryFullTitle(context,
            title: title, alternateTitle: alternateTitle),
        child: Text(
          title,
          maxLines: 6,
          // minLines: 1,
          textAlign: TextAlign.left,
          // 对齐方式
          overflow: TextOverflow.ellipsis, // 超出部分省略号
          style: const TextStyle(
            textBaseline: TextBaseline.alphabetic,
            // height: 1.2,
            fontSize: 16,
            // fontWeight: FontWeight.w500,
          ),
          strutStyle: const StrutStyle(
            height: 1.2,
            forceStrutHeight: true,
          ),
        ),
      ),
    );
  }
}

/// The navigation bar no longer repeats the title, so the header is where
/// people read and copy it in full, in both languages when there are two.
void showGalleryFullTitle(
  BuildContext context, {
  required String title,
  String? alternateTitle,
}) {
  final titles = <String>{
    title,
    if (alternateTitle?.trim().isNotEmpty ?? false) alternateTitle!,
  }.toList();
  void copy(BuildContext sheetContext, String text) {
    Navigator.of(sheetContext).pop();
    Clipboard.setData(ClipboardData(text: text));
    showToast(L10n.of(context).copied_to_clipboard);
  }

  showCupertinoModalPopup<void>(
    context: context,
    builder: (sheetContext) => EhActionSheet(
      title: Text(L10n.of(context).full_title),
      message: Text(titles.join('\n\n')),
      actions: [
        for (final text in titles)
          CupertinoActionSheetAction(
            onPressed: () => copy(sheetContext, text),
            child: Text(
              titles.length == 1
                  ? L10n.of(context).copy
                  : '${L10n.of(context).copy} · ${text.characters.take(18)}…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(sheetContext).pop(),
        child: Text(L10n.of(context).cancel),
      ),
    ),
  );
}

/// 上传用户
class GalleryUploader extends StatelessWidget {
  const GalleryUploader({
    Key? key,
    required this.uploader,
  }) : super(key: key);

  final String uploader;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.only(top: 8, right: 8, bottom: 4),
        child: Text(
          uploader,
          maxLines: 1,
          textAlign: TextAlign.left, // 对齐方式
          overflow: TextOverflow.ellipsis, // 超出部分省略号
          style: TextStyle(
            fontSize: 13,
            color: CupertinoDynamicColor.resolve(
                CupertinoColors.secondaryLabel, context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      onTap: () {
        logger.t('search uploader:$uploader');
        NavigatorUtil.goSearchPageWithParam(simpleSearch: 'uploader:$uploader');
      },
    );
  }
}

class ReadButton extends StatelessWidget {
  ReadButton({
    super.key,
    required this.gid,
  });
  final String gid;

  @override
  Widget build(BuildContext context) {
    final _pageController =
        Get.find<GalleryPageController>(tag: pageCtrlTagOf(context));
    final _pageState = _pageController.gState;
    return Obx(
      () => MouseRegionClick(
        child: CupertinoButton.filled(
            minSize: 24,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            borderRadius: BorderRadius.circular(20),
            // color: CupertinoColors.activeBlue,
            onPressed: _pageState.enableRead
                ? () => _toViewPage(
                    context,
                    _pageState.galleryProvider?.gid ?? '0',
                    _pageState.lastIndex)
                : null,
            child: Text(
                (_pageState.lastIndex > 0)
                    ? '${L10n.of(context).read.toUpperCase()} ${_pageState.lastIndex + 1}'
                    : L10n.of(context).read.toUpperCase(),
                style: const TextStyle(fontSize: 15, height: 1.2))),
      ),
    );
  }

  Future<void> _toViewPage(
      BuildContext context, String? gid, int _index) async {
    // logger.d('_toViewPage lastIndex $_index');
    NavigatorUtil.goGalleryViewPage(_index, gid ?? '',
        galleryTag: pageCtrlTagOf(context));
  }
}

/// 类别
class GalleryCategory extends StatelessWidget {
  const GalleryCategory({
    Key? key,
    required this.category,
  }) : super(key: key);

  final String? category;

  @override
  Widget build(BuildContext context) {
    final Color _colorCategory = CupertinoDynamicColor.resolve(
        ThemeColors.catColor[category ?? 'default'] ??
            CupertinoColors.systemGrey4,
        context);
    // final Color _colorCategory = CupertinoDynamicColor.resolve(
    //     ThemeColors.catColor[category ?? 'default']!, context);
    return GestureDetector(
      child: Container(
        decoration: BoxDecoration(
          color: _colorCategory,
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          category ?? '',
          style: const TextStyle(
            fontSize: 14.5,
            // height: 1.1,
            color: CupertinoColors.white,
          ),
        ),
      ),
      onTap: () {
        final int iCat = EHConst.cats[category]!;
        final int cats = EHConst.sumCats - iCat;
        // NavigatorUtil.goGalleryList(cats: iCat);
      },
    );
  }
}

class GalleryRating extends StatelessWidget {
  const GalleryRating({
    Key? key,
    this.rating,
    this.ratingFB,
    this.color,
  }) : super(key: key);

  final double? rating;
  final double? ratingFB;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // logger.d('rating $rating');
    return Row(
      children: <Widget>[
        Container(
            padding: const EdgeInsets.only(right: 8),
            child: Text('${rating ?? 0}')),
        // 星星
        StaticRatingBar(
          size: 18.0,
          rate: ratingFB ?? 0,
          radiusRatio: 1.5,
          colorLight: color,
          colorDark: CupertinoDynamicColor.resolve(
              CupertinoColors.systemGrey3, context),
        ),
      ],
    );
  }
}

class TopCommentEx extends StatelessWidget {
  const TopCommentEx({
    Key? key,
    this.comments,
    this.max = 2,
    required this.uploader,
    this.grouped = false,
  }) : super(key: key);
  final List<GalleryComment>? comments;
  final int max;
  final String? uploader;

  /// Rows inside one grouped surface, the uploader's comment first and
  /// labelled, instead of separate cards.
  final bool grouped;

  EhSettingService get _ehSettingService => Get.find();
  BlockController get _blockController => Get.find();

  @override
  Widget build(BuildContext context) {
    // 显示最前面两条
    List<Widget> topComment(List<GalleryComment>? comments, {int max = 2}) {
      Iterable<GalleryComment> commentsToShow = comments ?? [];

      // 如果启用了仅显示上传者评论 则只显示上传者的评论，并且忽略评分筛选
      if (_ehSettingService.showOnlyUploaderComment) {
        final uploaderId = commentsToShow
            .firstWhereOrNull((element) => element.score.isEmpty)
            ?.memberId;
        logger.d('_uploaderId $uploaderId');
        if (uploaderId != null) {
          commentsToShow =
              commentsToShow.where((element) => element.memberId == uploaderId);
        } else {
          commentsToShow = commentsToShow
              .where((element) => element.name == uploader?.trim());
        }

        logger.d('commentsToShow.length ${commentsToShow.length}');
      } else if (_ehSettingService.filterCommentsByScore) {
        commentsToShow = commentsToShow.where((comment) =>
            comment.score.isEmpty ||
            (int.tryParse(comment.score) ?? 0) >
                _ehSettingService.scoreFilteringThreshold);
      }

      // 根据屏蔽规则过滤评论
      commentsToShow = commentsToShow.where((element) {
        return !_blockController.matchRule(
              text: element.text,
              blockType: BlockType.comment,
            ) &&
            !_blockController.matchRule(
              text: element.name,
              blockType: BlockType.commentator,
            );
      });

      if (grouped) {
        // The uploader's comment is the only one without a score.
        final all = commentsToShow.toList();
        final pinned = all.where((comment) => comment.score.isEmpty);
        commentsToShow = [...pinned, ...all.where((c) => c.score.isNotEmpty)];
      }
      commentsToShow = commentsToShow.take(max);

      if (grouped) {
        final separator = CupertinoDynamicColor.resolve(
            ehTheme.palette.hairline, context);
        final rows = <Widget>[];
        for (final comment in commentsToShow) {
          if (rows.isNotEmpty) {
            rows.add(Container(
              height: 0.5,
              margin: const EdgeInsets.only(left: 16),
              color: separator,
            ));
          }
          rows.add(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (comment.score.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    L10n.of(context).uploader,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: CupertinoDynamicColor.resolve(
                          EhPalette.accent, context),
                    ),
                  ),
                ),
              CommentItem(galleryComment: comment, simple: true, grouped: true),
            ],
          ));
        }
        return rows;
      }

      return commentsToShow
          .map((GalleryComment comment) => CommentItem(
                galleryComment: comment,
                simple: true,
              ))
          .toList();
    }

    if (grouped) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: topComment(comments, max: max),
      );
    }

    return Column(
      children: [
        ...topComment(comments, max: max),
        if ((comments?.length ?? 0) > max)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: FaIcon(FontAwesomeIcons.ellipsis),
          ),
      ],
    );
  }
}

/// 包含多个 TagGroup
class TagBox extends StatelessWidget {
  const TagBox({Key? key, required this.listTagGroup}) : super(key: key);

  final List<TagGroup> listTagGroup;

  @override
  Widget build(BuildContext context) {
    return Column(
        children: listTagGroup
            .map((tagGroupData) => TagGroupItem(tagGroupData: tagGroupData))
            .toList());
  }
}

class MorePreviewButton extends StatelessWidget {
  const MorePreviewButton({
    Key? key,
    required this.hasMorePreview,
    this.padding,
  }) : super(key: key);

  final bool hasMorePreview;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minSize: 0,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Text(
        hasMorePreview
            ? L10n.of(Get.context!).more_thumbnails
            : L10n.of(Get.context!).no_more_thumbnails,
        style: const TextStyle(fontSize: 16),
      ),
      onPressed: () {
        Get.toNamed(
          EHRoutes.galleryAllThumbnails,
          id: detailNavigatorId,
        );
      },
    );
  }
}

/// The namespace label shown before a tag group.
String tagNamespaceLabel(String? tagType, {required bool translate}) {
  final type = tagType?.trim() ?? '';
  return translate ? EHConst.translateTagType[type] ?? type : type;
}

/// Width that fits every namespace label of a gallery, so the tag column
/// starts at one edge for all groups.
double tagNamespaceColumnWidth(
  BuildContext context,
  Iterable<TagGroup> groups, {
  required bool translate,
}) {
  var widest = 34.0;
  for (final group in groups) {
    final painter = TextPainter(
      text: TextSpan(
        text: tagNamespaceLabel(group.tagType, translate: translate),
        style: TagGroupItem.namespaceStyle,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    widest = widest < painter.width ? painter.width : widest;
    painter.dispose();
  }
  return widest.ceilToDouble().clamp(34.0, 120.0);
}

/// 一个标签组 第一个是类型
///
/// The namespace is a quiet text column rather than a coloured block; tags
/// are neutral capsules, so a watched tag is the only one that stands out.
class TagGroupItem extends StatelessWidget {
  const TagGroupItem({
    super.key,
    required this.tagGroupData,
    this.labelWidth = 44,
  });

  final TagGroup tagGroupData;
  final double labelWidth;

  static const TextStyle namespaceStyle =
      TextStyle(fontSize: 13, height: 1.25, fontWeight: FontWeight.w500);

  @override
  Widget build(BuildContext context) {
    final EhSettingService ehSettingService = Get.find();
    final text2 = CupertinoDynamicColor.resolve(ehTheme.palette.text2, context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Obx(() {
        final translate = ehSettingService.isTagTranslate;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: labelWidth,
              child: Padding(
                // Optically centre the label on the first row of capsules.
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  tagNamespaceLabel(tagGroupData.tagType, translate: translate),
                  maxLines: 1,
                  style: namespaceStyle.copyWith(color: text2),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in tagGroupData.galleryTags)
                    _detailTag(context, e.setColor(), translate),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _detailTag(BuildContext context, GalleryTag tag, bool translate) {
    return DetailTagChip(
      text: translate ? tag.tagTranslat : tag.title,
      userColor: ColorsUtil.getTagColor(tag.backgrondColor),
      userTextColor: ColorsUtil.getTagColor(tag.color),
      vote: tag.vote ?? 0,
      onPressed: () {
        logger.t('search type[${tag.type}] tag[${tag.title}]');
        NavigatorUtil.goSearchPageWithParam(
            simpleSearch: '${tag.type}:${tag.title.trim()}');
      },
      onLongPress: () {
        showTagInfoDialog(
          context,
          tag.title,
          translate: tag.tagTranslat,
          type: tag.type,
          vote: tag.vote ?? 0,
        );
      },
    );
  }
}

/// Detail-page tag capsule. A watched tag wears the colours the user gave it
/// in My Tags, as on the site; a voted tag ends with ↑ or ↓.
class DetailTagChip extends StatelessWidget {
  const DetailTagChip({
    super.key,
    required this.text,
    this.userColor,
    this.userTextColor,
    this.vote = 0,
    this.onPressed,
    this.onLongPress,
  });

  final String text;

  /// The tag's colour from My Tags, filling the capsule.
  final Color? userColor;

  /// The text colour the site gives that tag.
  final Color? userTextColor;
  final int vote;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final watched = userColor != null;
    final (background, foreground) = watched
        ? ColorsUtil.watchedTag(userColor!, userTextColor)
        : (
            CupertinoDynamicColor.resolve(ThemeColors.tagBackground, context),
            CupertinoDynamicColor.resolve(ThemeColors.tagText, context),
          );
    final arrow = switch (vote) {
      > 0 => (' ↑', ThemeColors.tagUpColor),
      < 0 => (' ↓', ThemeColors.tagDownColor),
      _ => null,
    };

    return GestureDetector(
      onTap: onPressed,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: ShapeDecoration(
          color: background,
          shape: const StadiumBorder(),
        ),
        child: Text.rich(
          TextSpan(
            text: text,
            children: [
              if (arrow != null)
                TextSpan(
                  text: arrow.$1,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: CupertinoDynamicColor.resolve(arrow.$2, context),
                  ),
                ),
            ],
          ),
          style: TextStyle(
            fontSize: 13,
            height: 1.25,
            fontWeight: watched ? FontWeight.w600 : FontWeight.w400,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

/// Dashed "+ Tags" capsule closing the tag list.
class AddTagChip extends StatelessWidget {
  const AddTagChip({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text2 = CupertinoDynamicColor.resolve(ehTheme.palette.text2, context);
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: CustomPaint(
          painter: _DashedStadiumPainter(
            color: CupertinoDynamicColor.resolve(ehTheme.palette.text3, context),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              '+ ${L10n.of(context).add_tags}',
              style: TextStyle(fontSize: 13, height: 1.25, color: text2),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedStadiumPainter extends CustomPainter {
  const _DashedStadiumPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 1.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 7) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedStadiumPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 标签按钮
/// onPressed 回调
class TagButton extends StatelessWidget {
  const TagButton({
    Key? key,
    required this.text,
    this.textColor,
    this.color,
    this.onPressed,
    this.padding,
    this.onLongPress,
  }) : super(key: key);

  final String text;
  final Color? textColor;
  final Color? color;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: color ??
              CupertinoDynamicColor.resolve(ThemeColors.tagBackground, context),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: padding ?? const EdgeInsets.fromLTRB(6, 3, 6, 4),
        child: Column(
          children: [
            Text(
              text,
              style: TextStyle(
                color: textColor ??
                    CupertinoDynamicColor.resolve(ThemeColors.tagText, context),
                fontSize: 13,
                // fontWeight: textColor != null ? FontWeight.w600 : null,
                height: 1.3,
              ),
              strutStyle: const StrutStyle(height: 1),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchHisTagButton extends StatelessWidget {
  const SearchHisTagButton({
    Key? key,
    required this.text,
    this.desc,
    this.textColor,
    this.color,
    this.onPressed,
    this.onLongPress,
    this.padding,
  }) : super(key: key);

  final String text;
  final String? desc;
  final Color? textColor;
  final Color? color;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      onLongPress: onLongPress,
      child: Container(
        padding: padding ?? const EdgeInsets.fromLTRB(6, 3, 6, 4),
        decoration: BoxDecoration(
          color: color ??
              CupertinoDynamicColor.resolve(ThemeColors.tagBackground, context),
          borderRadius: BorderRadius.circular(8),
        ),
        child: IntrinsicWidth(
          child: Column(
            children: [
              Text(
                text,
                style: TextStyle(
                  color: textColor ??
                      CupertinoDynamicColor.resolve(
                          ThemeColors.tagText, context),
                  fontSize: 13,
                  fontWeight: textColor != null ? FontWeight.w500 : null,
                  height: 1.3,
                ),
                strutStyle: const StrutStyle(height: 1),
              ),
              if (desc != null && desc!.isNotEmpty)
                Container(
                  height: 0.1,
                  color: ThemeColors.tagText,
                ),
              if (desc != null && desc!.isNotEmpty)
                Text(
                  desc!,
                  style: TextStyle(
                    color: textColor ??
                        CupertinoDynamicColor.resolve(
                            ThemeColors.tagText, context),
                    fontSize: 12,
                    height: 1.3,
                    // fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class TextBtn extends StatelessWidget {
  const TextBtn(this.iconData,
      {Key? key,
      this.iconSize,
      this.title,
      this.onTap,
      this.onLongPress,
      this.color,
      this.iconPadding})
      : super(key: key);
  final FaIconData iconData;
  final double? iconSize;
  final String? title;
  final Color? color;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? iconPadding;

  @override
  Widget build(BuildContext context) {
    return CupertinoTheme(
      data:
          CupertinoThemeData(primaryColor: color ?? CupertinoColors.systemGrey),
      child: GestureDetector(
        // behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
        // behavior: HitTestBehavior.opaque,
        child: Column(
          children: <Widget>[
            Container(
              padding: iconPadding,
              child: MouseRegionClick(
                disable: onTap == null && onLongPress == null,
                child: CupertinoButton(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  onPressed: onTap,
                  child: FaIcon(
                    iconData,
                    size: iconSize ?? 28,
                    // color: CupertinoColors.systemGrey3,
                  ),
                ),
              ),
            ),
            Text(
              title ?? '',
              style: const TextStyle(fontSize: 12, height: 1),
            ),
          ],
        ),
      ),
    );
  }
}

// 导航栏封面小图
class NavigationBarImage extends StatelessWidget {
  const NavigationBarImage({
    Key? key,
    this.imageUrl,
    this.scrollController,
  }) : super(key: key);

  final String? imageUrl;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final double _statusBarHeight = MediaQuery.of(Get.context!).padding.top;

    Widget cover = imageUrl == null || (imageUrl?.isEmpty ?? true)
        ? const SizedBox.expand()
        : Container(
            child: CoveTinyImage(
              imgUrl: imageUrl!,
              statusBarHeight: _statusBarHeight,
            ),
          );

    return GestureDetector(
      onTap: () {
        scrollController?.animateTo(0,
            duration: const Duration(milliseconds: 500), curve: Curves.ease);
      },
      child: cover,
    );
  }
}
