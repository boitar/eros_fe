import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:eros_fe/common/controller/download/download_file_path.dart';
import 'package:eros_fe/common/controller/download/gallery_update_service.dart';
import 'package:eros_fe/common/controller/download_controller.dart';
import 'package:eros_fe/common/controller/gallerycache_controller.dart';
import 'package:eros_fe/common/controller/webdav_controller.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/network/api.dart';
import 'package:eros_fe/pages/tab/controller/download_view_controller.dart';
import 'package:eros_fe/store/db/entity/gallery_image_task.dart';
import 'package:eros_fe/store/db/entity/gallery_task.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/image/extended_saf_image_privider.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:eros_fe/widget/rating_bar.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

const kCardRadius = 10.0;

/// 同步阅读进度的提示dialog，会自动关闭，也可跳过同步直接阅读
Future<int?> syncReadProgress(
  BuildContext context,
  int gid, {
  Duration duration = const Duration(milliseconds: 500),
}) async {
  bool _cancelSync = false;
  bool _needShowDialog = true;

  Future<int> _sync() async {
    final _cache = await Get.find<GalleryCacheController>()
        .listenGalleryCache('$gid')
        .last;
    _needShowDialog = false;
    return _cache?.lastIndex ?? 0;
  }

  Future<int?> _showSyncDialog() async {
    return await showCupertinoDialog<int?>(
      context: context,
      // barrierDismissible: true,
      builder: (BuildContext context) {
        return EhAlertDialog(
          title: Text('${L10n.of(context).sync_read_progress}...'),
          content: GetBuilder<DownloadViewController>(
            initState: (state) async {
              final _index = await _sync();
              if (!_cancelSync) {
                Get.back(result: _index);
              }
            },
            builder: (logic) {
              return const CupertinoActivityIndicator(radius: 16);
            },
          ).paddingOnly(top: 10.0),
          actions: [
            CupertinoDialogAction(
              child: Text(
                L10n.of(context).skip,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.destructiveRed),
              ),
              onPressed: () {
                _cancelSync = true;
                Get.back();
              },
            ),
          ],
        );
      },
    );
  }

  return await _showSyncDialog();
}

/// 画廊下载项
class DownloadGalleryItem extends GetView<DownloadViewController> {
  const DownloadGalleryItem({
    super.key,
    required this.galleryTask,
    required this.taskIndex,
    this.speed,
    this.errInfo,
    this.updateInfo,
    this.incrementalProgress,
    this.onTapUpdate,
  });

  final GalleryTask galleryTask;
  final int taskIndex;
  final String? speed;
  final String? errInfo;
  final GalleryUpdateInfo? updateInfo;
  final GalleryIncrementalProgress? incrementalProgress;
  final VoidCallback? onTapUpdate;

  @override
  Widget build(BuildContext context) {
    final DateTime date =
        DateTime.fromMillisecondsSinceEpoch(galleryTask.addTime ?? 0);
    final addTime = galleryTask.addTime != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(date)
        : null;

    final status = TaskStatus(galleryTask.status ?? 0);
    final complete = status == TaskStatus.complete;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final List<GalleryImageTask> imageTasks =
            await controller.getImageTasks(galleryTask.gid);
        final GalleryTask? gTask = controller.galleryTaskMap[galleryTask.gid];
        if (gTask == null ||
            gTask.status != TaskStatus.complete.value ||
            controller.filesUnavailable(galleryTask.gid)) {
          return;
        }

        late final List<String> pics;
        final dirPath = gTask.realDirPath;

        if (dirPath?.isContentUri ?? false) {
          if (dirPath != null) {
            logger.t('^^^^ before read, dirPath: $dirPath');

            late final String parentPath;
            if (dirPath.contains('/document/')) {
              parentPath =
                  dirPath.substring(0, dirPath.lastIndexOf('/document/'));
            } else {
              parentPath = dirPath.substring(0, dirPath.lastIndexOf('%2F'));
            }

            logger.t('^^^^ before read, parentPath: $parentPath');

            if (parentPath.isNotEmpty) {
              await showSAFPermissionRequiredDialog(uri: Uri.parse(parentPath));
            }
          }

          pics = imageTasks
              .where((element) =>
                  element.filePath != null && element.filePath!.isNotEmpty)
              .map((e) => buildDownloadFilePath(
                    directoryPath: dirPath,
                    fileName: e.filePath,
                  ))
              .whereType<String>()
              .toList();
        } else {
          pics = imageTasks
              .where((element) =>
                  element.filePath != null && element.filePath!.isNotEmpty)
              .map((e) => buildDownloadFilePath(
                    directoryPath: dirPath,
                    fileName: e.filePath,
                  ))
              .whereType<String>()
              .toList();
        }

        logger.t('pics: ${pics.map((e) => e).join('\n')}');

        // 读取进度
        int? lastIndex = 0;
        if (Get.find<WebdavController>().syncReadProgress) {
          lastIndex = await syncReadProgress(context, galleryTask.gid);
        }
        final cache = await Get.find<GalleryCacheController>()
            .listenGalleryCache('${galleryTask.gid}', sync: false)
            .first;
        if (cache?.lastIndex != null) {
          lastIndex = cache?.lastIndex;
        }

        // 进入阅读
        NavigatorUtil.goGalleryViewPageFile(
          lastIndex ?? 0,
          pics,
          '${galleryTask.gid}',
        );
      },
      onLongPress: () => controller.onLongPress(taskIndex, task: galleryTask),
      child: _buildCardItem(context, complete, addTime: addTime),
    );
  }

  Widget _buildCardItem(
    BuildContext context,
    bool complete, {
    String? addTime,
  }) {
    return Container(
      padding: const EdgeInsets.only(right: 10),
      margin: const EdgeInsets.fromLTRB(10, 5, 10, 10),
      decoration: BoxDecoration(
        boxShadow: ehTheme.isDarkMode ? null : EhPalette.lightCardShadows,
        color: ehTheme.itemBackgroundColor,
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      height:
          120 * math.max(1, MediaQuery.textScalerOf(context).scale(13) / 13),
      child: Row(
        children: [
          // 封面
          Column(
            children: [
              Expanded(child: _buildCover(cardType: true)),
            ],
          ),
          // 右侧
          Expanded(
            child: _buildItemInfo(context, complete, addTime: addTime)
                .paddingSymmetric(vertical: 4),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, bool _complete, {String? addTime}) {
    return Column(
      children: [
        Container(
          padding:
              const EdgeInsets.only(top: 4, bottom: 4, left: 20, right: 16),
          height: 120,
          child: Row(
            children: [
              // 封面
              _buildCover(),
              // 右侧
              Expanded(
                child: _buildItemInfo(context, _complete, addTime: addTime),
              ),
            ],
          ),
        ),
        Divider(
          indent: 20,
          height: 0.6,
          color: EhPalette.separator.resolveFrom(context),
        ),
      ],
    );
  }

  // 封面
  Widget _buildCover({bool cardType = false}) {
    return GestureDetector(
      child: Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: DownloadItemCoverImage(
          filePath: buildDownloadFilePath(
            directoryPath: galleryTask.realDirPath,
            fileName: galleryTask.coverImage,
          ),
          url: galleryTask.coverUrl,
          cardType: cardType,
        ),
      ),
      onTap: () async {
        logger.t('${galleryTask.url} ');
        String? url = galleryTask.url;
        if (url == null) {
          return;
        }
        if (!url.startsWith('http')) {
          url = '${Api.getBaseUrl()}$url';
        }
        NavigatorUtil.goGalleryPage(url: url);
      },
    );
  }

  Widget _buildItemInfo(
    BuildContext context,
    bool isComplete, {
    String? addTime,
  }) {
    final status = TaskStatus(galleryTask.status ?? 0);
    final isIncremental = !isComplete && incrementalProgress != null;
    final isIncrementalFailed =
        isIncremental &&
        (status == TaskStatus.failed ||
            (errInfo != null && errInfo!.isNotEmpty));
    final showUpdateRow =
        isComplete && updateInfo != null && onTapUpdate != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Text(
          galleryTask.title,
          softWrap: true,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            height: 1.2,
          ),
        ).paddingSymmetric(vertical: 2),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isIncremental)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              galleryTask.uploader ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    ehTheme.palette.text2.resolveFrom(context),
                              ),
                            ),
                          ),
                          // 任务添加时间
                          Flexible(
                            flex: 2,
                            child: Text(
                              addTime ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    ehTheme.palette.text2.resolveFrom(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const Spacer(),
                    if (showUpdateRow)
                      _UpdateRow(
                        updateInfo: updateInfo!,
                        onTapUpdate: onTapUpdate!,
                      )
                    else if (isIncremental)
                      _buildIncrementalProgressBlock(
                        context,
                        failed: isIncrementalFailed,
                      )
                    else ...[
                      if (!isComplete)
                        _buildProgressIndicator(context)
                      else
                        _buildRating(galleryTask.rating),
                      // 下载速度 下载进度
                      Row(
                        children: [
                          if (!isComplete || (errInfo?.isNotEmpty ?? false))
                            Expanded(child: _buildDownloadCtl(context))
                          else
                            _buildCategory(galleryTask.category),
                          const Spacer(),
                          Text(
                            isComplete
                                ? '${galleryTask.fileCount}'
                                : '${galleryTask.completCount ?? 0}/${galleryTask.fileCount}',
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  ehTheme.palette.text2.resolveFrom(context),
                            ),
                          ),
                          // 控制按钮
                          _getIcon(),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIncrementalProgressBlock(
    BuildContext context, {
    required bool failed,
  }) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final reuseGrey = palette.text3.resolveFrom(context).withValues(alpha: 0.45);
    final trackColor = palette.fillPressed.resolveFrom(context);
    final text2 = palette.text2.resolveFrom(context);
    final danger = CupertinoDynamicColor.resolve(
      CupertinoColors.systemRed,
      context,
    );

    final total = math.max(1, galleryTask.fileCount);
    final completed = (galleryTask.completCount ?? 0).clamp(0, total);
    final reused = (incrementalProgress?.reusedCount ?? 0).clamp(0, total);
    final deltaTotal = math.max(0, total - reused);
    final deltaDone = math.max(0, completed - reused).clamp(0, deltaTotal);
    final remaining = math.max(0, total - completed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 5,
            color: trackColor,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (reused > 0)
                  Expanded(
                    flex: reused,
                    child: ColoredBox(
                      color: reuseGrey,
                      child: const SizedBox.expand(),
                    ),
                  ),
                if (reused > 0 && (deltaDone > 0 || remaining > 0))
                  const SizedBox(width: 1.5),
                if (deltaDone > 0)
                  Expanded(
                    flex: deltaDone,
                    child: ColoredBox(
                      color: accent,
                      child: const SizedBox.expand(),
                    ),
                  ),
                if (deltaDone > 0 && remaining > 0) const SizedBox(width: 1.5),
                if (remaining > 0)
                  Expanded(
                    flex: remaining,
                    child: ColoredBox(
                      color: trackColor,
                      child: const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (failed)
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  (errInfo != null && errInfo!.isNotEmpty)
                      ? '${l10n.download_incremental_failed_status} · $errInfo'
                      : l10n.download_incremental_failed_status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: danger,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _CardActionTarget(
                onTap: () => controller.resumeGalleryDownload(galleryTask.gid),
                child: EhButton(
                  label: l10n.sp_retry,
                  style: EhButtonStyle.destructive,
                  size: 30,
                  onPressed: () =>
                      controller.resumeGalleryDownload(galleryTask.gid),
                ),
              ),
            ],
          )
        else ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      galleryTask.status == TaskStatus.paused.value
                          ? l10n.download_incremental_paused_status(reused)
                          : l10n.download_incremental_status(reused),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: text2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      (galleryTask.status != TaskStatus.paused.value &&
                              speed != null &&
                              speed!.isNotEmpty)
                          ? '$speed/s · ${l10n.download_incremental_download_progress(deltaDone, deltaTotal)}'
                          : l10n.download_incremental_download_progress(
                              deltaDone,
                              deltaTotal,
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.text3.resolveFrom(context),
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              ConstrainedBox(
                key: const ValueKey<String>('download-incremental-control'),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Center(
                  child: _getIcon(context: context, minTargetSize: 44),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildProgressIndicator(BuildContext context) {
    final total = math.max(1, galleryTask.fileCount);
    final completed = (galleryTask.completCount ?? 0).clamp(0, total);
    final accent = EhPalette.accent.resolveFrom(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: completed / total,
        backgroundColor: CupertinoDynamicColor.resolve(
          CupertinoColors.secondarySystemFill,
          context,
        ),
        valueColor: AlwaysStoppedAnimation<Color>(accent),
      ),
    );
  }

  Widget _buildDownloadCtl(BuildContext context) {
    if (errInfo != null && errInfo!.isNotEmpty) {
      return Text(
        controller.filesUnavailable(galleryTask.gid)
            ? L10n.of(context).download_files_unavailable
            : errInfo ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontSize: 13,
            color: CupertinoDynamicColor.resolve(
                CupertinoColors.systemRed, context)),
      );
    } else {
      return Text(
        speed != null ? '$speed/s' : '',
        style: TextStyle(
            fontSize: 13, color: ehTheme.palette.text2.resolveFrom(context)),
      );
    }
  }

  Widget _buildRating(double? rating) {
    if (rating == null) {
      return const SizedBox.shrink();
    }

    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.fromLTRB(0, 0, 4, 0),
          child: StaticRatingBar(
            size: 16.0,
            rate: rating,
            radiusRatio: 1.5,
            colorLight: ThemeColors.colorRatingMap['ir'],
            colorDark: ehTheme.palette.text3.resolveFrom(Get.context!),
          ),
        ),
        Text(
          rating.toString(),
          style: TextStyle(
            fontSize: 11,
            color: ehTheme.palette.text2.resolveFrom(Get.context!),
          ),
        ),
      ],
    );
  }

  Widget _buildCategory(String? category) {
    final Color _colorCategory = CupertinoDynamicColor.resolve(
        ThemeColors.catColor[category ?? 'default'] ??
            CupertinoColors.systemBackground,
        Get.context!);

    return Container(
      decoration: BoxDecoration(
        color: _colorCategory,
        borderRadius: BorderRadius.circular(4.5),
      ),
      padding: const EdgeInsets.fromLTRB(6, 3, 6, 3),
      child: Text(
        category ?? '',
        style: const TextStyle(
          fontSize: 14,
          height: 1,
          color: CupertinoColors.white,
        ),
      ),
    );
  }

  Widget _getIcon({BuildContext? context, double minTargetSize = 30.0}) {
    final GalleryTask? _taskInfo = controller.galleryTaskMap[galleryTask.gid];
    final minSize = minTargetSize;
    const iconSize = 18.0;
    final buttonPadding =
        minTargetSize >= 44.0 ? EdgeInsets.zero : const EdgeInsets.only(left: 8.0);
    final resolvedContext = context ?? Get.context!;
    final accentColor = EhPalette.accent.resolveFrom(resolvedContext);

    if (controller.filesUnavailable(galleryTask.gid)) {
      return Semantics(
        label: L10n.of(resolvedContext).check_download_files_and_continue,
        child: CupertinoTheme(
          data: const CupertinoThemeData(
              primaryColor: CupertinoColors.activeGreen),
          child: CupertinoButton(
            padding: buttonPadding,
            minimumSize: Size(minSize, minSize),
            child: const EhSvgFaIcon(FontAwesomeIcons.play, size: iconSize),
            onPressed: () => controller.resumeGalleryDownload(galleryTask.gid),
          ),
        ),
      );
    }

    final Map<TaskStatus, Widget> statusMap = {
      // 下载时，显示暂停按钮
      TaskStatus.running: CupertinoTheme(
        data: const CupertinoThemeData(primaryColor: CupertinoColors.systemRed),
        child: CupertinoButton(
          padding: buttonPadding,
          minimumSize: Size(minSize, minSize),
          child: const EhSvgFaIcon(
            FontAwesomeIcons.pause,
            size: iconSize,
          ),
          onPressed: () {
            controller.pauseGalleryDownload(_taskInfo?.gid ?? galleryTask.gid);
          },
        ),
      ),
      // 完成时 按下无动作
      TaskStatus.complete: CupertinoTheme(
        data: CupertinoThemeData(primaryColor: accentColor),
        child: CupertinoButton(
          padding: buttonPadding,
          minimumSize: Size(minSize, minSize),
          child: const EhSvgFaIcon(
            FontAwesomeIcons.check,
            size: iconSize,
          ),
          onPressed: () {},
        ),
      ),
      // 暂停时 显示继续按钮。按下恢复任务
      TaskStatus.paused: CupertinoTheme(
        data:
            const CupertinoThemeData(primaryColor: CupertinoColors.activeGreen),
        child: CupertinoButton(
          padding: buttonPadding,
          minimumSize: Size(minSize, minSize),
          child: const EhSvgFaIcon(
            FontAwesomeIcons.play,
            size: iconSize,
          ),
          onPressed: () {
            controller.resumeGalleryDownload(_taskInfo?.gid ?? galleryTask.gid);
          },
        ),
      ),
      // 失败时 显示重试按钮。按下重试任务
      TaskStatus.failed: CupertinoButton(
        padding: buttonPadding,
        minimumSize: Size(minSize, minSize),
        child: const EhSvgFaIcon(
          FontAwesomeIcons.play,
          size: iconSize,
        ),
        onPressed: () {
          controller.resumeGalleryDownload(galleryTask.gid);
        },
      ),
      // 取消状态 显示重试按钮。按下重试任务
      TaskStatus.canceled: CupertinoButton(
        padding: buttonPadding,
        minimumSize: Size(minSize, minSize),
        child: const EhSvgFaIcon(
          FontAwesomeIcons.redo,
          size: iconSize,
        ),
        onPressed: () {
          controller.resumeGalleryDownload(galleryTask.gid);
        },
      ).paddingSymmetric(),
      // 排队中的任务也可以暂停，避免队列阻塞时只能看到转圈而无法操作。
      TaskStatus.enqueued: CupertinoTheme(
        data: const CupertinoThemeData(primaryColor: CupertinoColors.systemRed),
        child: CupertinoButton(
          padding: buttonPadding,
          minimumSize: Size(minSize, minSize),
          child: const EhSvgFaIcon(
            FontAwesomeIcons.pause,
            size: iconSize,
          ),
          onPressed: () {
            controller.pauseGalleryDownload(_taskInfo?.gid ?? galleryTask.gid);
          },
        ),
      ),
      TaskStatus.undefined: Container(
        width: minSize,
        height: minSize,
        child: const CupertinoActivityIndicator(
          radius: 10,
        ),
      ),
    };

    final currentStatus = _taskInfo?.status ?? galleryTask.status ?? 0;
    return statusMap[TaskStatus(currentStatus)] ?? const SizedBox(width: 40);
  }
}

class _UpdateRow extends StatelessWidget {
  const _UpdateRow({
    required this.updateInfo,
    required this.onTapUpdate,
  });

  final GalleryUpdateInfo updateInfo;
  final VoidCallback onTapUpdate;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final accent = EhPalette.accent.resolveFrom(context);
    final text2 = ehTheme.palette.text2.resolveFrom(context);
    final date = updateInfo.newerVersions.isNotEmpty
        ? updateInfo.newerVersions.first.shortMonthDay
        : '';

    return Row(
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: l10n.download_has_update_badge,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
                if (date.isNotEmpty)
                  TextSpan(
                    text: ' · $date',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: text2,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        _CardActionTarget(
          key: const ValueKey<String>('download-card-update-action'),
          onTap: onTapUpdate,
          child: EhButton(
            label: l10n.download_update_action,
            style: EhButtonStyle.tonal,
            selected: true,
            size: 30,
            onPressed: onTapUpdate,
          ),
        ),
      ],
    );
  }
}

class _CardActionTarget extends StatelessWidget {
  const _CardActionTarget({
    super.key,
    required this.onTap,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Center(child: child),
      ),
    );
  }
}

class DownloadItemCoverImage extends StatefulWidget {
  const DownloadItemCoverImage({
    this.url,
    this.filePath,
    this.cardType = false,
    super.key,
  });

  final String? filePath;
  final String? url;
  final bool cardType;

  @override
  State<DownloadItemCoverImage> createState() => _DownloadItemCoverImageState();
}

class _DownloadItemCoverImageState extends State<DownloadItemCoverImage> {
  Future<bool>? _localCoverAvailable;
  bool _localCoverMissing = false;

  String? get filePath => widget.filePath;
  String? get url => widget.url;
  bool get cardType => widget.cardType;

  @override
  void initState() {
    super.initState();
    _checkLocalCover();
  }

  @override
  void didUpdateWidget(DownloadItemCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != filePath || _localCoverMissing) {
      _checkLocalCover();
    }
  }

  void _checkLocalCover() {
    final path = filePath;
    _localCoverMissing = false;
    _localCoverAvailable = path == null || path.isEmpty || path.isContentUri
        ? null
        : _localFileExists(path);
  }

  Future<bool> _localFileExists(String path) async {
    var available = false;
    try {
      available = await File(path).exists();
    } on FileSystemException catch (error) {
      logger.w('Cannot check downloaded cover: $error');
    }
    if (mounted && filePath == path) {
      _localCoverMissing = !available;
    }
    return available;
  }

  Widget _buildFallback(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return EhNetworkImage(
        imageUrl: url!,
        fit: cardType ? BoxFit.cover : BoxFit.fitWidth,
      );
    }
    return _buildCoverPlaceholder(context);
  }

  @override
  Widget build(BuildContext context) {
    logger.t('$filePath  $url');

    Widget image = () {
      if (filePath != null && filePath!.isNotEmpty) {
        Widget? loadStateChanged(ExtendedImageState state) {
          if (state.extendedImageLoadState == LoadState.loading) {
            return Container(
              alignment: Alignment.center,
              color: ehTheme.palette.fill.resolveFrom(context),
              child: const CupertinoActivityIndicator(),
            );
          }
          if (state.extendedImageLoadState == LoadState.failed) {
            logger.w('下载列表封面加载失败: $filePath');
            return _buildFallback(context);
          }
          return null;
        }

        const filterQuality = FilterQuality.medium;
        final image = ((filePath?.isContentUri ?? false)
            ? ExtendedSafImageProvider(Uri.parse(filePath!))
            : ExtendedFileImageProvider(File(filePath!))) as ImageProvider;
        final localImage = ExtendedImage(
          image: image,
          fit: cardType ? BoxFit.cover : BoxFit.fitWidth,
          loadStateChanged: loadStateChanged,
          filterQuality: filterQuality,
          clearMemoryCacheIfFailed: true,
          // Download-list covers are small thumbnails. Keep them in Flutter's
          // normal LRU cache so scrolling back does not show a spinner again.
          clearMemoryCacheWhenDispose: false,
        );
        if (_localCoverAvailable == null) return localImage;
        // Missing files are normal for paused/recovered downloads. Do not
        // create an image stream that can fail after its list item is disposed.
        return FutureBuilder<bool>(
          future: _localCoverAvailable,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return _buildCoverPlaceholder(context);
            }
            return snapshot.data == true ? localImage : _buildFallback(context);
          },
        );
      }
      return _buildFallback(context);
    }();

    image = ClipRRect(
      borderRadius: cardType
          ? const BorderRadius.only(
              topLeft: Radius.circular(kCardRadius),
              bottomLeft: Radius.circular(kCardRadius))
          : BorderRadius.circular(6),
      child: image,
    );

    return Container(
      width: 90,
      decoration: BoxDecoration(
        boxShadow: cardType
            ? null
            : [
                //阴影
                BoxShadow(
                  color: ehTheme.palette.fill.resolveFrom(context),
                  blurRadius: 3,
                )
              ],
      ),
      child: image,
    );
  }

  Widget _buildCoverPlaceholder(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: ehTheme.palette.fill.resolveFrom(context),
      child: EhSvgIcon(
        CupertinoIcons.photo,
        color: ehTheme.palette.text2.resolveFrom(context),
      ),
    );
  }
}
