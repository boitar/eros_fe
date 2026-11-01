import 'package:eros_fe/adaptive/tab_navigation.dart';
import 'package:eros_fe/common/controller/block_controller.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/gallery/controller/comment_controller.dart';
import 'package:eros_fe/pages/gallery/view/const.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/scroll_edge_effect.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import 'comment_item.dart';

/// Height of the composer's single-line field.
const double _kComposerHeight = 44;

/// Space between the composer and the edges around it.
const double _kComposerMargin = 12;

class CommentPage extends StatefulWidget {
  const CommentPage({super.key});

  @override
  State<CommentPage> createState() => _CommentPageState();
}

class _CommentPageState extends State<CommentPage>
    with AutomaticKeepAliveClientMixin {
  late CommentController controller;

  EhSettingService get _ehSettingService => Get.find();
  BlockController get _blockController => Get.find();

  @override
  void initState() {
    super.initState();
    final tag = pageCtrlTagOf(context);
    controller = Get.put(CommentController(galleryTag: tag), tag: tag);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RetainedDraft(
      controller: controller.commentTextController,
      // The title and back button sit on the same glass bar as every other
      // page, so opening the comments never takes the bar away.
      child: SettingScaffold(
        title: L10n.of(context).gallery_comments,
        child: Stack(
          children: [
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                top: false,
                child: commentListView(context),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: buildCommentTextField(context),
            ),
          ],
        ),
      ),
    );
  }

  // 评论列表
  Widget commentListView(BuildContext context) {
    if (!_ehSettingService.showComments) {
      return const SizedBox();
    }

    return Obx(() {
      logger.t('build commentListView');

      List<GalleryComment> comments =
          _filterComments(controller.comments) ?? [];

      return CustomScrollView(
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: CupertinoSliverRefreshControl(
              onRefresh: controller.onRefresh,
            ),
          ),
          if (comments.isEmpty)
            const SliverFillRemaining()
          else
            SliverSafeArea(
              top: false,
              minimum: EdgeInsets.only(
                  left: kPadding,
                  right: kPadding,
                  bottom: _kComposerHeight +
                      _kComposerMargin * 2 +
                      context.mediaQueryPadding.bottom),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return _itemBuilder(comments[index]);
                  },
                  childCount: comments.length,
                ),
              ),
            ),
        ],
      );
    });
  }

  List<GalleryComment>? _filterComments(List<GalleryComment>? comments) {
    List<GalleryComment>? commentsFilter;

    if (_ehSettingService.showOnlyUploaderComment) {
      final uploaderId =
          comments?.firstWhere((element) => element.score.isEmpty).memberId;

      if (uploaderId != null) {
        commentsFilter = comments
            ?.where((element) => element.memberId == uploaderId)
            .toList();
      } else {
        commentsFilter = comments
            ?.where((element) => element.name == controller.uploader)
            .toList();
      }
    } else {
      commentsFilter = comments;
    }

    // 根据屏蔽规则过滤评论
    commentsFilter = commentsFilter?.where((element) {
      return !_blockController.matchRule(
            text: element.text,
            blockType: BlockType.comment,
          ) &&
          !_blockController.matchRule(
            text: element.name,
            blockType: BlockType.commentator,
          );
    }).toList();

    return commentsFilter;
  }

  Widget _itemBuilder(GalleryComment comment) {
    if (controller.comments == null || controller.comments!.isEmpty) {
      return const SizedBox();
    }

    final hideComment = _ehSettingService.filterCommentsByScore &&
        (comment.score.isNotEmpty &&
            (int.tryParse(comment.score) ?? 0) <=
                _ehSettingService.scoreFilteringThreshold);

    if (!hideComment) {
      return CommentItem(
        galleryComment: comment,
      ).autoCompressKeyboard(context);
    } else {
      return const SizedBox();
    }
  }

  // 原始消息
  Widget _buildOriText(BuildContext context) {
    return Obx(
      () {
        if (controller.editState == EditState.newComment) {
          return const SizedBox.shrink();
        }
        final secondary = CupertinoDynamicColor.resolve(
            CupertinoColors.secondaryLabel, context);
        final caption = TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: secondary,
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 4, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      controller.isEditStat
                          ? L10n.of(context).edit_comment
                          : '${L10n.of(context).reply_to_comment} '
                              '${controller.reptyUser}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: caption,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      controller.isEditStat
                          ? controller.oriComment
                          : controller.reptyCommentText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: secondary),
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 32,
                onPressed: controller.pressCancel,
                child: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  size: 22,
                  semanticLabel: L10n.of(context).cancel,
                  color: CupertinoDynamicColor.resolve(
                      CupertinoColors.tertiaryLabel, context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Like Messages, the field floats on glass at the foot of the page; the
  /// comments scroll on under it and fade out behind it.
  Widget buildCommentTextField(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final bottom = padding.bottom > 0 ? padding.bottom : _kComposerMargin;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: <Widget>[
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: SoftScrollEdgeEffect(
              edge: SoftEdge.bottom,
              inset: bottom,
              bars: _kComposerHeight + _kComposerMargin,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            padding.left + _kComposerMargin,
            _kComposerMargin,
            padding.right + _kComposerMargin,
            bottom,
          ),
          child: LiquidGlassSurface(
            enabled: true,
            useNativeGlass: false,
            emphasizeFallbackEdge: true,
            followSystemTransparency:
                _ehSettingService.liquidGlassFollowSystemTransparency,
            borderRadius: BorderRadius.circular(_kComposerHeight / 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // 编辑原消息 或者回复消息 时的显示
                _buildOriText(context),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: CupertinoTextField(
                        padding: const EdgeInsets.fromLTRB(16, 11, 4, 11),
                        minLines: 1,
                        maxLines: 6,
                        keyboardType: TextInputType.multiline,
                        decoration: null,
                        controller: controller.commentTextController,
                        focusNode: controller.focusNode,
                        placeholder: L10n.of(context).new_comment,
                        strutStyle: const StrutStyle(height: 1.25),
                        style: const TextStyle(fontSize: 16, height: 1.25),
                      ),
                    ),
                    _sendButton(context),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Fills with the accent colour once there is something to send.
  Widget _sendButton(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller.commentTextController,
      builder: (context, value, _) => Obx(() {
        final confirming = controller.isEditStat || controller.isReptyStat;
        final enabled = value.text.trim().isNotEmpty;
        final accent = CupertinoTheme.of(context).primaryColor;
        return CupertinoButton(
          padding: const EdgeInsets.all(6),
          minSize: _kComposerHeight,
          onPressed: enabled ? controller.pressSend : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled
                  ? accent
                  : CupertinoDynamicColor.resolve(
                      CupertinoColors.tertiarySystemFill, context),
            ),
            child: Icon(
              confirming ? CupertinoIcons.checkmark : CupertinoIcons.arrow_up,
              size: 18,
              semanticLabel: confirming
                  ? L10n.of(context).done
                  : L10n.of(context).new_comment,
              color: enabled
                  ? CupertinoColors.white
                  : CupertinoDynamicColor.resolve(
                      CupertinoColors.tertiaryLabel, context),
            ),
          ),
        );
      }),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
