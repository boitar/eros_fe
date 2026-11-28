import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/controller/archiver_download_controller.dart';
import 'package:eros_fe/common/controller/download/gallery_update_service.dart';
import 'package:eros_fe/common/controller/download_controller.dart';
import 'package:eros_fe/common/controller/gallerycache_controller.dart';
import 'package:eros_fe/common/epub/epub_builder.dart';
import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/extension.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/index.dart';
import 'package:eros_fe/pages/tab/view/download_page.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/store/db/entity/gallery_image_task.dart';
import 'package:eros_fe/store/db/entity/gallery_task.dart';
import 'package:eros_fe/utils/export_progress.dart';
import 'package:eros_fe/utils/logger.dart';
import 'package:eros_fe/utils/share_service.dart';
import 'package:eros_fe/utils/toast.dart';
import 'package:eros_fe/utils/utility.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:shared_storage/shared_storage.dart' as ss;

enum DownloadType {
  gallery,
  archiver,
}

typedef FunctionExport = Future<String?> Function();

const String idDownloadGalleryView = 'DownloadGalleryView';
const String idDownloadArchiverView = 'DownloadArchiverView';
const String idDownloadGalleryItem = 'DownloadGalleryItem';
const String idDownloadArchiverItem = 'DownloadArchiverItem';

const String viewTypeStoreKey = 'DownloadView.viewType';

class DownloadViewController extends GetxController {
  DownloadViewController({GalleryUpdateService? updateService})
    : updateService = updateService ?? GalleryUpdateService();

  ArchiverDownloadController get _archiverDownloadController => Get.find();

  final DownloadController _downloadController = Get.find();

  late GlobalKey<AnimatedListState> animatedGalleryListKey =
      GlobalKey<AnimatedListState>();

  final GlobalKey<AnimatedListState> animatedArchiverListKey =
      GlobalKey<AnimatedListState>();

  // Rebuild AnimatedList only when the persisted task snapshot is restored.
  final RxInt galleryListRevision = 0.obs;

  /// Update-check state for downloaded galleries.
  final GalleryUpdateService updateService;
  final RxMap<int, GalleryUpdateInfo> updateInfoMap =
      <int, GalleryUpdateInfo>{}.obs;
  final RxBool isCheckingUpdates = false.obs;
  final RxInt updateCheckCompleted = 0.obs;
  final RxInt updateCheckTotal = 0.obs;
  final RxBool showOnlyUpdatable = false.obs;
  final RxBool updateSummaryDismissed = false.obs;
  final RxInt lastUpdateCheckCheckedCount = 0.obs;
  final RxInt lastUpdateCheckFailedCount = 0.obs;
  final RxBool hasCompletedUpdateCheck = false.obs;
  DateTime? lastUpdateCheckAt;
  CancelToken? _updateCheckCancelToken;

  GalleryUpdateInfo? updateInfoFor(int gid) => updateInfoMap[gid];

  GalleryIncrementalProgress? incrementalProgressFor(int gid) =>
      _downloadController.dState.incrementalProgressMap[gid];

  int get availableUpdatesCount => updateInfoMap.length;

  /// Cancels an in-flight batch update check.
  void cancelUpdateCheck() {
    _updateCheckCancelToken?.cancel('user_cancelled');
  }

  /// Toggles filtering the gallery download list to updatable / updating /
  /// failed incremental tasks.
  void toggleShowOnlyUpdatable() {
    showOnlyUpdatable.value = !showOnlyUpdatable.value;
  }

  /// Dismisses the inline update summary strip and restores the full list.
  void dismissUpdateSummary() {
    updateSummaryDismissed.value = true;
    showOnlyUpdatable.value = false;
  }

  /// Whether [task] should stay visible when [showOnlyUpdatable] is enabled:
  /// tasks with a discovered newer version, active/failed incremental updates,
  /// or any active download created by an update action (including zero-reuse
  /// or SAF full-download fallbacks).
  bool isUpdatableFilterMatch(GalleryTask task) {
    final gid = task.gid;
    if (updateInfoMap.containsKey(gid)) {
      return true;
    }
    if (incrementalProgressFor(gid) != null) {
      return true;
    }
    if (_downloadController.dState.updateCreatedTaskGids.contains(gid) &&
        task.status != TaskStatus.complete.value) {
      return true;
    }
    return false;
  }

  List<GalleryTask> get filteredGalleryTasks =>
      galleryTasks.where(isUpdatableFilterMatch).toList();

  /// Automatically turns off the "updatable only" filter when no tasks remain
  /// matching it (for example after the last updatable task finishes updating),
  /// returning to the full list with the up-to-date status strip.
  void syncUpdatableFilterIfEmpty() {
    if (!showOnlyUpdatable.value) {
      return;
    }
    if (filteredGalleryTasks.isEmpty) {
      showOnlyUpdatable.value = false;
      if (!isCheckingUpdates.value) {
        hasCompletedUpdateCheck.value = true;
      }
    }
  }

  /// Records newer versions discovered while browsing a gallery detail page.
  void registerDiscoveredUpdate(
    int gid,
    List<GalleryNewerVersion> newerVersions,
  ) {
    final liveTask = galleryTaskMap[gid];
    if (liveTask == null ||
        liveTask.status != TaskStatus.complete.value ||
        filesUnavailable(gid)) {
      if (updateInfoMap.remove(gid) != null) {
        update(['${idDownloadGalleryItem}_$gid']);
      }
      return;
    }
    final availableVersions = newerVersions
        .where((v) => !galleryTaskMap.containsKey(v.gidInt))
        .toList();
    if (availableVersions.isEmpty) {
      if (updateInfoMap.remove(gid) != null) {
        update(['${idDownloadGalleryItem}_$gid']);
      }
      return;
    }
    updateInfoMap[gid] = GalleryUpdateInfo(
      sourceGid: gid,
      newerVersions: availableVersions,
      checkedAt: DateTime.now(),
    );
    update(['${idDownloadGalleryItem}_$gid']);
  }

  void _pruneStaleUpdateEntries() {
    final activeTasks = galleryTaskMap;
    final toRemove = <int>[];
    for (final entry in updateInfoMap.entries) {
      final task = activeTasks[entry.key];
      if (task == null ||
          task.status != TaskStatus.complete.value ||
          filesUnavailable(entry.key)) {
        toRemove.add(entry.key);
        continue;
      }
      final availableNewer = entry.value.newerVersions
          .where((v) => !activeTasks.containsKey(v.gidInt))
          .toList();
      if (availableNewer.isEmpty) {
        toRemove.add(entry.key);
      } else if (availableNewer.length != entry.value.newerVersions.length) {
        updateInfoMap[entry.key] = GalleryUpdateInfo(
          sourceGid: entry.key,
          newerVersions: availableNewer,
          checkedAt: entry.value.checkedAt,
        );
      }
    }
    for (final gid in toRemove) {
      updateInfoMap.remove(gid);
      update(['${idDownloadGalleryItem}_$gid']);
    }
    final staleUpdateCreated = _downloadController.dState.updateCreatedTaskGids
        .where((gid) {
          final task = activeTasks[gid];
          return task == null || task.status == TaskStatus.complete.value;
        })
        .toList();
    if (staleUpdateCreated.isNotEmpty) {
      _downloadController.dState.updateCreatedTaskGids.removeAll(
        staleUpdateCreated,
      );
    }
    syncUpdatableFilterIfEmpty();
  }

  /// Checks all completed downloaded galleries for `#gnd` newer versions.
  Future<GalleryUpdateBatchResult?> checkAllGalleryUpdates({
    BuildContext? context,
  }) async {
    if (isCheckingUpdates.value) {
      return null;
    }
    _pruneStaleUpdateEntries();
    final targets = galleryTasks
        .where(
          (task) =>
              task.status == TaskStatus.complete.value &&
              !filesUnavailable(task.gid),
        )
        .toList();
    if (targets.isEmpty) {
      if (context != null && context.mounted) {
        showToast(L10n.of(context).download_updates_no_targets);
      }
      return const GalleryUpdateBatchResult(
        checkedCount: 0,
        failedCount: 0,
        updates: <int, GalleryUpdateInfo>{},
      );
    }

    isCheckingUpdates.value = true;
    updateSummaryDismissed.value = false;
    lastUpdateCheckFailedCount.value = 0;
    updateCheckCompleted.value = 0;
    updateCheckTotal.value = targets.length;
    final cancelToken = CancelToken();
    _updateCheckCancelToken = cancelToken;

    void publishTaskResult(int gid, GalleryUpdateInfo? discovered) {
      final liveTask = galleryTaskMap[gid];
      if (liveTask == null ||
          liveTask.status != TaskStatus.complete.value ||
          filesUnavailable(gid)) {
        updateInfoMap.remove(gid);
        update(['${idDownloadGalleryItem}_$gid']);
        return;
      }
      if (discovered != null) {
        final availableVersions = discovered.newerVersions
            .where((v) => !galleryTaskMap.containsKey(v.gidInt))
            .toList();
        if (availableVersions.isNotEmpty) {
          updateInfoMap[gid] = GalleryUpdateInfo(
            sourceGid: gid,
            newerVersions: availableVersions,
            checkedAt: discovered.checkedAt,
          );
        } else {
          updateInfoMap.remove(gid);
        }
      } else {
        updateInfoMap.remove(gid);
      }
      update(['${idDownloadGalleryItem}_$gid']);
    }

    try {
      final result = await updateService.checkTasksForUpdates(
        targets,
        cancelToken: cancelToken,
        onProgress: (completed, total) {
          updateCheckCompleted.value = completed;
          updateCheckTotal.value = total;
        },
        onTaskChecked: publishTaskResult,
      );

      // Reconcile confirmed results for tasks that still exist and remain
      // complete, clearing stale badges for confirmed-up-to-date tasks even
      // when unrelated tasks in the batch failed.
      for (final gid in result.checkedGids) {
        publishTaskResult(gid, result.updates[gid]);
      }
      _pruneStaleUpdateEntries();
      lastUpdateCheckCheckedCount.value = result.checkedCount;
      lastUpdateCheckFailedCount.value = result.failedCount;
      lastUpdateCheckAt = DateTime.now();

      if (!result.cancelled) {
        hasCompletedUpdateCheck.value = true;
      } else if (updateInfoMap.isEmpty) {
        hasCompletedUpdateCheck.value = false;
      }
      syncUpdatableFilterIfEmpty();
      return result;
    } finally {
      if (identical(_updateCheckCancelToken, cancelToken)) {
        _updateCheckCancelToken = null;
      }
      isCheckingUpdates.value = false;
    }
  }

  /// Analyzes a single downloaded task against a target newer version.
  Future<GalleryIncrementalPlan> analyzeIncrementalUpdate({
    required GalleryTask oldTask,
    required GalleryNewerVersion targetVersion,
    CancelToken? cancelToken,
  }) async {
    final oldImageTasks = await getImageTasks(oldTask.gid);
    int? oldReadingIndex;
    if (Get.isRegistered<GalleryCacheController>()) {
      final cache = await Get.find<GalleryCacheController>()
          .listenGalleryCache('${oldTask.gid}', sync: false)
          .first;
      oldReadingIndex = cache?.lastIndex;
    }
    final targetBaseIsSaf = Get.isRegistered<EhSettingService>() &&
        Get.find<EhSettingService>().downloadLocatino.isContentUri;
    return updateService.analyzeIncrementalUpdate(
      oldTask: oldTask,
      oldImageTasks: oldImageTasks,
      targetVersion: targetVersion,
      oldReadingIndex: oldReadingIndex,
      targetBaseIsSaf: targetBaseIsSaf,
      cancelToken: cancelToken,
    );
  }

  /// Executes an analyzed incremental update plan and updates pending badges.
  Future<GalleryIncrementalExecutionResult?> executeIncrementalUpdate(
    GalleryIncrementalPlan plan, {
    required GalleryIncrementalUpdateMode mode,
  }) async {
    final result = await _downloadController.executeIncrementalUpdate(
      plan,
      mode: mode,
    );
    if (result != null) {
      if (mode == GalleryIncrementalUpdateMode.inPlace) {
        updateInfoMap.remove(plan.oldTask.gid);
        _downloadController.dState.updateCreatedTaskGids.remove(
          plan.oldTask.gid,
        );
      }
      if (result.completedLocally) {
        _downloadController.dState.updateCreatedTaskGids.remove(
          result.task.gid,
        );
      } else {
        _downloadController.dState.updateCreatedTaskGids.add(result.task.gid);
      }
      _pruneStaleUpdateEntries();
      update(['${idDownloadGalleryItem}_${plan.oldTask.gid}']);
    }
    return result;
  }

  @override
  void onClose() {
    _updateCheckCancelToken?.cancel();
    super.onClose();
  }

  late String tabTag;

  final _viewType = DownloadType.gallery.obs;
  DownloadType get viewType => _viewType.value;
  set viewType(DownloadType val) => _viewType.value = val;

  @override
  void onInit() {
    super.onInit();
    tabTag = EHRoutes.download;

    viewType = EnumToString.fromString(DownloadType.values,
            hiveHelper.getString(viewTypeStoreKey) ?? '') ??
        viewType;
    ever<DownloadType>(
        _viewType, (val) => hiveHelper.setString(viewTypeStoreKey, val.name));
  }

  List<DownloadType> pageList = <DownloadType>[
    DownloadType.gallery,
    DownloadType.archiver,
  ];

  // Desktop exposes the tab without the mobile-only downloader. On mobile,
  // the backend remains a required dependency: Get.find must report a missing
  // registration rather than silently presenting an empty queue.
  List<DownloadArchiverTaskInfo> get archiverTasks {
    final host = PlatformCapabilities.hostPlatform;
    final desktop =
        host == TargetPlatform.macOS ||
        host == TargetPlatform.windows ||
        host == TargetPlatform.linux;
    if (desktop && !Get.isRegistered<ArchiverDownloadController>()) {
      return const [];
    }
    return _archiverDownloadController.archiverTaskMap.values
        .toList()
        .reversed
        .toList();
  }

  Map<int, GalleryTask> get galleryTaskMap =>
      _downloadController.dState.galleryTaskMap;

  List<GalleryTask> get galleryTasks {
    final tasks = _downloadController.dState.galleryTasks;
    tasks.sort((GalleryTask a, GalleryTask b) {
      return (b.addTime ?? 0) - (a.addTime ?? 0);
    });
    return tasks;
  }

  Map<int, String> get downloadSpeedMap =>
      _downloadController.dState.downloadSpeeds;

  Map<int, String> get errInfoMap => _downloadController.dState.errInfoMap;

  bool filesUnavailable(int gid) =>
      _downloadController.dState.unavailableGalleryFiles.contains(gid);

  Future<List<GalleryImageTask>> getImageTasks(int gid) async {
    return await _downloadController.getImageTasks(gid);
  }

  // Archiver暂停任务
  Future<void> pauseArchiverDownload({required String? taskId}) async {
    if (taskId != null) {
      FlutterDownloader.pause(taskId: taskId);
    }
  }

  // Archiver取消任务
  Future<void> cancelArchiverDownload({required String? taskId}) async {
    if (taskId != null) {
      FlutterDownloader.cancel(taskId: taskId);
    }
  }

  // Archiver恢复任务
  Future<void> resumeArchiverDownload(int index) async {
    final String? oriTaskId = archiverTasks[index].taskId;
    final int? oriStatus = archiverTasks[index].status;

    String? newTaskId;
    if (oriStatus == downloadStatusToInt(DownloadTaskStatus.paused)) {
      newTaskId = await FlutterDownloader.resume(taskId: oriTaskId ?? '');
    } else if (oriStatus == downloadStatusToInt(DownloadTaskStatus.failed)) {
      newTaskId = await FlutterDownloader.retry(taskId: oriTaskId ?? '');
    }

    if (newTaskId == null) {
      return;
    }

    logger.d('oriTaskId $oriTaskId,  newTaskId $newTaskId');
    if (newTaskId.isNotEmpty && archiverTasks[index].tag != null) {
      _archiverDownloadController.archiverTaskMap[archiverTasks[index].tag!] =
          _archiverDownloadController
              .archiverTaskMap[archiverTasks[index].tag!]!
              .copyWith(taskId: newTaskId.oN);
    }
  }

  // Archiver 重试任务
  Future<void> retryArchiverDownload(int index) async {
    logger.d('Archiver重试任务');
    final oriTask = archiverTasks[index];
    final String? oriTaskId = oriTask.taskId;
    final int? oriStatus = archiverTasks[index].status;

    String? newTaskId;
    if (oriStatus == downloadStatusToInt(DownloadTaskStatus.paused)) {
      newTaskId = await FlutterDownloader.retry(taskId: oriTaskId ?? '');
    } else if (oriStatus == downloadStatusToInt(DownloadTaskStatus.failed)) {
      newTaskId = await FlutterDownloader.retry(taskId: oriTaskId ?? '');
    }

    if (newTaskId == null || newTaskId.isEmpty) {
      // await retryArchiverDownload(index);
      logger.d('url ${oriTask.gid} ${oriTask.url}');
      return;
    }

    logger.d('oriTaskId $oriTaskId, newTaskId $newTaskId');
    if (newTaskId.isNotEmpty && archiverTasks[index].tag != null) {
      _archiverDownloadController.archiverTaskMap[archiverTasks[index].tag!] =
          _archiverDownloadController
              .archiverTaskMap[archiverTasks[index].tag!]!
              .copyWith(taskId: newTaskId.oN);
    }
  }

  // Archiver移除任务
  void removeArchiverTask(
    int index, {
    bool shouldDeleteContent = true,
  }) {
    final String? oriTaskId = archiverTasks[index].taskId;
    final String? tag = archiverTasks[index].tag;

    animatedArchiverListKey.currentState?.removeItem(
        index,
        (context, animation) =>
            downloadArchiverDelItemBuilder(context, index, animation));

    _archiverDownloadController.removeTask(tag);
    FlutterDownloader.remove(
      taskId: oriTaskId ?? '',
      shouldDeleteContent: shouldDeleteContent,
    );
    update([idDownloadArchiverView]);
  }

  // 打开Archiver文件
  Future<void> openArchiverTaskFile(int index) async {
    final String? oriTaskId = archiverTasks[index].taskId;

    // final _result = await OpenFile.open('');
    FlutterDownloader.open(
      taskId: oriTaskId ?? '',
    );
  }

  // 导出Archiver文件
  Future<void> exportArchiverTaskFile(int index) async {
    final String? oriTaskId = archiverTasks[index].taskId;

    FlutterDownloader.open(
      taskId: oriTaskId ?? '',
    );
  }

  // Gallery 移除任务
  void removeGalleryTask(
    int index, {
    bool shouldDeleteContent = true,
    int? gid,
  }) {
    final tasks = galleryTasks;
    final resolvedIndex = gid != null
        ? tasks.indexWhere((t) => t.gid == gid)
        : (index >= 0 && index < tasks.length ? index : -1);
    if (resolvedIndex < 0) {
      return;
    }
    final GalleryTask task = tasks[resolvedIndex];
    final wasFiltered = showOnlyUpdatable.value;
    updateInfoMap.remove(task.gid);
    _downloadController.dState.incrementalProgressMap.remove(task.gid);
    _downloadController.dState.updateCreatedTaskGids.remove(task.gid);
    _downloadController.removeDownloadGalleryTask(
      gid: task.gid,
      shouldDeleteContent: shouldDeleteContent,
    );
    if (wasFiltered) {
      refreshGalleryList();
    } else {
      animatedGalleryListKey.currentState?.removeItem(
        resolvedIndex,
        (context, animation) =>
            downloadDelItemBuilder(context, resolvedIndex, animation),
      );
    }
    syncUpdatableFilterIfEmpty();
    update([idDownloadGalleryView]);
  }

  void animateGalleryListAddTask() {
    if (galleryTasks.isNotEmpty) {
      animatedGalleryListKey.currentState?.insertItem(galleryTasks.length - 1);
    }
  }

  void refreshGalleryList() {
    animatedGalleryListKey = GlobalKey<AnimatedListState>();
    galleryListRevision.value++;
  }

  void animateArchiverListAddTask({int? index}) {
    animatedArchiverListKey.currentState
        ?.insertItem(index ?? archiverTasks.length - 1);
  }

  void onLongPress(
    int index, {
    DownloadType type = DownloadType.gallery,
    GalleryTask? task,
  }) {
    vibrateUtil.medium();
    _showLongPressSheet(index, type, task: task);
  }

  /// 长按菜单
  Future<void> _showLongPressSheet(
    int taskIndex,
    DownloadType type, {
    GalleryTask? task,
  }) async {
    final BuildContext pageContext = Get.context!;

    await showCupertinoModalPopup<void>(
        context: pageContext,
        builder: (BuildContext context) {
          return EhActionSheet(
            cancelButton: CupertinoActionSheetAction(
                onPressed: () {
                  Get.back();
                },
                child: Text(L10n.of(context).cancel)),
            actions: <Widget>[
              if (type == DownloadType.archiver)
                CupertinoActionSheetAction(
                  onPressed: () {
                    Get.back();
                    openArchiverTaskFile(taskIndex);
                  },
                  child: Text(
                    L10n.of(context).open_with_other_apps,
                  ),
                ),
              // gallery重新下载
              if (type == DownloadType.gallery)
                CupertinoActionSheetAction(
                  onPressed: () {
                    Get.back();
                    restartGalleryDownload(task?.gid);
                  },
                  child: Text(
                    L10n.of(context).redownload,
                  ),
                ),
              // gallery导出
              if (type == DownloadType.gallery &&
                  task?.status == TaskStatus.complete.value)
                CupertinoActionSheetAction(
                  onPressed: () async {
                    Get.back();
                    await ShareService.waitForModalDismissal();
                    if (pageContext.mounted) {
                      await _showExportSheet(
                          pageContext: pageContext, task: task);
                    }
                  },
                  child: Text(
                    L10n.of(context).export,
                  ),
                ),
              // 删除
              CupertinoActionSheetAction(
                onPressed: () {
                  Get.back();
                  _showDeleteSheet(taskIndex, type, task: task);
                },
                child: Text(
                  L10n.of(context).delete,
                  style: const TextStyle(color: CupertinoColors.destructiveRed),
                ),
              ),
            ],
          );
        });
  }

  Future<void> _showDeleteSheet(
    int taskIndex,
    DownloadType type, {
    GalleryTask? task,
  }) async {
    await showCupertinoModalPopup<void>(
        context: Get.overlayContext!,
        builder: (BuildContext context) {
          return EhActionSheet(
            cancelButton: CupertinoActionSheetAction(
                onPressed: () {
                  Get.back();
                },
                child: Text(L10n.of(context).cancel)),
            actions: <Widget>[
              // 删除
              CupertinoActionSheetAction(
                onPressed: () {
                  Get.back();
                  type == DownloadType.archiver
                      ? removeArchiverTask(taskIndex,
                          shouldDeleteContent: false)
                      : removeGalleryTask(
                          taskIndex,
                          shouldDeleteContent: false,
                          gid: task?.gid,
                        );
                },
                child: Text(
                  L10n.of(context).delete_task_only,
                  style: const TextStyle(color: CupertinoColors.destructiveRed),
                ),
              ),
              CupertinoActionSheetAction(
                onPressed: () {
                  Get.back();
                  type == DownloadType.archiver
                      ? removeArchiverTask(taskIndex)
                      : removeGalleryTask(taskIndex, gid: task?.gid);
                },
                child: Text(
                  L10n.of(context).delete_task_and_content,
                  style: const TextStyle(color: CupertinoColors.destructiveRed),
                ),
              ),
            ],
          );
        });
  }

  Future<void> _showDeleteDialog(
    int taskIndex,
    DownloadType type, {
    GalleryTask? task,
  }) async {
    return showCupertinoDialog<void>(
      context: Get.overlayContext!,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return EhAlertDialog(
          title: Text(L10n.of(context).delete_task),
          actions: [
            CupertinoDialogAction(
              onPressed: () async {
                Get.back();
                type == DownloadType.archiver
                    ? removeArchiverTask(taskIndex, shouldDeleteContent: false)
                    : removeGalleryTask(
                        taskIndex,
                        shouldDeleteContent: false,
                        gid: task?.gid,
                      );
              },
              child: Text(
                L10n.of(context).delete_task_only,
                style: const TextStyle(color: CupertinoColors.destructiveRed),
              ),
            ),
            CupertinoDialogAction(
              onPressed: () async {
                Get.back();
                type == DownloadType.archiver
                    ? removeArchiverTask(taskIndex)
                    : removeGalleryTask(taskIndex, gid: task?.gid);
              },
              child: Text(
                L10n.of(context).delete_task_and_content,
                style: const TextStyle(color: CupertinoColors.destructiveRed),
              ),
            ),
            CupertinoDialogAction(
              onPressed: () async {
                Get.back();
              },
              child: Text(L10n.of(context).cancel),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showExportSheet({
    GalleryTask? task,
    BuildContext? pageContext,
  }) async {
    if (task == null) {
      return;
    }
    final BuildContext sharePageContext = pageContext ?? Get.context!;
    await showCupertinoModalPopup<void>(
        context: sharePageContext,
        builder: (BuildContext sheetContext) {
          return EhActionSheet(
            cancelButton: CupertinoActionSheetAction(
                onPressed: () {
                  Get.back();
                },
                child: Text(L10n.of(sheetContext).cancel)),
            actions: <Widget>[
              // ZIP
              CupertinoActionSheetAction(
                onPressed: () async {
                  logger.d('导出zip');
                  final shareOrigin = ShareService.positionOrigin(sheetContext);
                  Get.back();
                  await ShareService.waitForModalDismissal();
                  if (!sharePageContext.mounted) {
                    return;
                  }
                  await _exportZip(
                    sharePageContext,
                    task,
                    sharePositionOrigin: shareOrigin,
                  );
                },
                child: const Text(
                  'ZIP',
                ),
              ),
              // ZIP
              CupertinoActionSheetAction(
                onPressed: () async {
                  logger.d('导出epub');
                  final shareOrigin = ShareService.positionOrigin(sheetContext);
                  Get.back();
                  await ShareService.waitForModalDismissal();
                  if (!sharePageContext.mounted) {
                    return;
                  }
                  await _exportEpub(
                    sharePageContext,
                    task,
                    sharePositionOrigin: shareOrigin,
                  );
                },
                child: const Text(
                  'EPUB',
                ),
              ),
            ],
          );
        });
  }

  Future<String?> _exportZip(
    BuildContext context,
    GalleryTask task, {
    Rect? sharePositionOrigin,
  }) async {
    logger.d('export zip , dir path ${task.dirPath}');
    if (task.dirPath == null) {
      return null;
    }
    final origin = sharePositionOrigin ?? ShareService.positionOrigin(context);

    final zipPath = await _exportGallery(context, () => _compZip(task));

    if (zipPath != null) {
      await ShareService.waitForModalDismissal();
      await ShareService.shareFiles(
        [XFile(zipPath)],
        sharePositionOrigin: origin,
      );
    }
    return null;
  }

  String get _exportTempRoot => Global.extStoreTempPath.isNotEmpty
      ? Global.extStoreTempPath
      : Global.tempPath;

  Future<String?> _compZip(GalleryTask task) async {
    final tempPath = path.join(_exportTempRoot, 'export_temp');
    Directory tempDir = Directory(tempPath);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
    tempDir.createSync(recursive: true);

    // 打包zip
    final encoder = ZipFileEncoder();
    final title = task.title.replaceAll(RegExp(r'[/:*"<>|]'), '_');
    final zipPath = path.join(_exportTempRoot, 'zip', '${task.gid}_$title.zip');
    await Directory(path.dirname(zipPath)).create(recursive: true);
    encoder.create(zipPath);

    if (task.realDirPath?.isContentUri ?? false) {
      // SAF list files
      const columns = <ss.DocumentFileColumn>[
        ss.DocumentFileColumn.displayName,
        ss.DocumentFileColumn.size,
        ss.DocumentFileColumn.lastModified,
        ss.DocumentFileColumn.id,
        ss.DocumentFileColumn.mimeType,
      ];
      final onFileLoaded =
          ss.listFiles(Uri.parse(task.realDirPath!), columns: columns);

      await for (final domFile in onFileLoaded) {
        final bytes = await domFile.getContent();
        if (bytes == null) {
          continue;
        }
        final filePath = path.join(tempPath, domFile.name);
        File(filePath).writeAsBytesSync(bytes);
        await encoder.addFile(File(filePath));
      }
    } else {
      // 添加文件
      final galleryDir = Directory(task.realDirPath!);
      for (final imgFile in galleryDir.listSync()) {
        if ((await FileSystemEntity.type(imgFile.path)) ==
            FileSystemEntityType.file) {
          final srcFile = File(imgFile.path);
          await encoder.addFile(srcFile);
        }
      }
    }

    if (kDebugMode) {
      // _zipPath len
      final file = File(zipPath);
      logger.d('zip file len ${file.lengthSync()}');
    }

    await encoder.close();
    return zipPath;
  }

  Future<String?> _exportEpub(
    BuildContext context,
    GalleryTask task, {
    Rect? sharePositionOrigin,
  }) async {
    logger.d('export epub , dir path ${task.dirPath}');
    if (task.dirPath == null) {
      return null;
    }
    final origin = sharePositionOrigin ?? ShareService.positionOrigin(context);

    final exportFilePath =
        await _exportGallery(context, () => _buildEpub(task));

    if (exportFilePath != null) {
      await ShareService.waitForModalDismissal();
      await ShareService.shareFiles(
        [XFile(exportFilePath)],
        sharePositionOrigin: origin,
      );
    }
    return null;
  }

  Future<String?> _buildEpub(GalleryTask task) async {
    loggerTime.t('start buildEpub');
    final tempEpubPath = await buildEpub(task,
        tempPath: path.join(_exportTempRoot, 'export_epub_temp'));
    loggerTime.t('end buildEpub');

    final title = task.title.replaceAll(RegExp(r'[/:*"<>|]'), '_');

    // 打包epub文件
    final epubPath =
        path.join(_exportTempRoot, 'epub', '${task.gid}_$title.epub');
    await Directory(path.dirname(epubPath)).create(recursive: true);
    await compute(isolateCompactDirToZip, [epubPath, tempEpubPath]);

    if (kDebugMode) {
      // _epubPath len
      final file = File(epubPath);
      logger.d('epub file len ${file.lengthSync()}');
    }

    return epubPath;
  }

  // gallery 暂停任务
  void pauseGalleryDownload(int? gid) {
    if (gid != null) {
      _downloadController.galleryTaskPaused(gid);
    }
    update(['${idDownloadGalleryItem}_$gid']);
  }

  // gallery 恢复任务
  void resumeGalleryDownload(int? gid) {
    if (gid != null) {
      _downloadController.galleryTaskResume(gid);
    }
    update(['${idDownloadGalleryItem}_$gid']);
  }

  // gallery 重新下载
  void restartGalleryDownload(int? gid) {
    if (gid != null) {
      _downloadController.galleryTaskRestart(gid);
    }
    update(['${idDownloadGalleryItem}_$gid']);
  }

  Future<String?> _writeTaskInfoFile() async {
    throw UnimplementedError();
    /*
    // 创建zip文件
    final encoder = ZipFileEncoder();
    final _zipPath = _getLocalFilePath();
    encoder.create(_zipPath);

    // 临时db
    final tempDBPath = path.join(Global.tempPath, 'export', EHConst.DB_NAME);
    final tempDBFile = File(tempDBPath);
    if (tempDBFile.existsSync()) {
      tempDBFile.deleteSync(recursive: true);
    }

    final ehDb = await Global.getDatabase();
    final allImageTasks = await ehDb.imageTaskDao.findAllTasks();
    final allTasks = await ehDb.galleryTaskDao.findAllGalleryTasks();

    // 导出任务数据表到临时db中
    final tempDB = await Global.getDatabase(path: tempDBPath);
    await tempDB.imageTaskDao.insertOrReplaceImageTasks(allImageTasks);
    // await tempDB.galleryTaskDao.insertOrReplaceTasks(allTasks);
    tempDB.close();

    // 添加文件
    encoder.addFile(tempDBFile);

    encoder.close();
    return _zipPath;
    */
  }

  Future<void> _readTaskInfoFile(File importFile) async {
    throw UnimplementedError();
    /*
    final decoder = ZipDecoder();
    final archive = decoder.decodeBytes(importFile.readAsBytesSync());
    final archivePath = path.join(Global.tempPath, 'archive');

    for (final file in archive) {
      final filename = file.name;
      if (file.isFile && filename == EHConst.DB_NAME) {
        final data = file.content as List<int>;
        File(path.join(archivePath, filename))
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
      } else {
        Directory(path.join(archivePath, filename)).create(recursive: true);
      }
    }

    final _pathImportDB = path.join(archivePath, EHConst.DB_NAME);
    final _importDBFile = File(_pathImportDB);
    if (!_importDBFile.existsSync()) {
      return;
    }

    final importDb = await Global.getDatabase(path: _pathImportDB);
    final allImageTasks = await importDb.imageTaskDao.findAllTasks();
    final allTasks = await importDb.galleryTaskDao.findAllGalleryTasks();

    logger.d('import task ${allTasks.length}');

    // 从临时db导入任务数据
    final ehDB = await Global.getDatabase();

    final taskMap = <int, GalleryTask?>{};
    final taskCompletMap = <int, int>{};

    // 导入 imagetask
    for (final imageTask in allImageTasks) {
      late GalleryTask? _task;
      if (taskMap[imageTask.gid] != null) {
        _task = taskMap[imageTask.gid];
      } else {
        _task = allTasks
            .firstWhereOrNull((element) => element.gid == imageTask.gid);
        taskMap[imageTask.gid] = _task;
      }
      if (_task == null || _task.realDirPath == null) {
        continue;
      }

      final _filePath = path.join(_task.realDirPath!, imageTask.filePath);
      // logger.d(_filePath);

      taskCompletMap.putIfAbsent(imageTask.gid, () => 0);
      if (File(_filePath).existsSync()) {
        // logger.d(
        //     'insertOrReplaceImageTask complete ${imageTask.gid}/${imageTask.filePath}');
        await ehDB.imageTaskDao.insertOrReplaceImageTask(
            imageTask.copyWith(status: TaskStatus.complete.value));
        taskCompletMap.update(imageTask.gid, (val) => val + 1,
            ifAbsent: () => 1);
      } else {
        // logger.d(
        //     'insertOrReplaceImageTask enqueued ${imageTask.gid}/${imageTask.filePath}');
        await ehDB.imageTaskDao.insertOrReplaceImageTask(
            imageTask.copyWith(status: TaskStatus.enqueued.value));
      }
    }

    // 导入task
    final allOriTasks = await ehDB.galleryTaskDao.findAllGalleryTasks();
    for (final task in allTasks) {
      GalleryTask? _oriTask =
          allOriTasks.firstWhereOrNull((element) => element.gid == task.gid);
      // 插入新的任务
      if (_oriTask == null) {
        final _task = task.copyWith(
          coverImage: '',
          status: TaskStatus.paused.value,
          completCount: taskCompletMap[task.gid] ?? 0,
        );
        logger.d('insert ${_task.toString()}');
        // await ehDB.galleryTaskDao.insertTask(_task);
        await isarHelper.putGalleryTask(_task, replaceOnConflict: false);
        _downloadController.dState.galleryTaskMap[_task.gid] = _task;
        animateGalleryListAddTask();
      }
    }*/
  }

  String _getLocalFilePath() {
    final DateTime now = DateTime.now();
    final DateFormat formatter = DateFormat('yyyyMMdd_HHmmss');
    final String nowTime = formatter.format(now);
    return path.join(Global.appDocPath, 'FEhDownloadTask_$nowTime.zip');
  }

  Future<void> shareTaskInfoFile({
    BuildContext? context,
    Rect? sharePositionOrigin,
  }) async {
    final origin = sharePositionOrigin ?? ShareService.positionOrigin(context);
    final tempFilePath = await _writeTaskInfoFile();
    if (tempFilePath != null) {
      await ShareService.shareFiles(
        [XFile(tempFilePath)],
        sharePositionOrigin: origin,
      );
    }
  }

  Future exportTaskInfoFile() async {
    try {
      final tempFilePath = await _writeTaskInfoFile();
      await requestManageExternalStoragePermission();
      if (tempFilePath != null) {
        final saveToDirPath = await FilePicker.platform.getDirectoryPath();
        logger.d('$saveToDirPath');
        if (saveToDirPath != null) {
          final dstPath = path.join(saveToDirPath, path.basename(tempFilePath));
          File(tempFilePath).copySync(dstPath);
        }
      }
    } catch (e) {
      showToast('$e');
      rethrow;
    }
  }

  Future importTaskInfoFile() async {
    await requestManageExternalStoragePermission();

    final FilePickerResult? result = await FilePicker.platform.pickFiles();
    logger.d('import file $result');
    if (result != null) {
      final File _file = File(result.files.single.path!);
      await _readTaskInfoFile(_file);
      _downloadController.initGalleryTasks();
      update([idDownloadGalleryView]);
      // await _showRestartAppDialog();

      // 更新 animatedGalleryListKey
      animatedGalleryListKey = GlobalKey<AnimatedListState>();
    }
  }
}

Future<String?> _exportGallery(
  BuildContext context,
  FunctionExport funExport, {
  FunctionExport? funcCancel,
}) =>
    showExportProgress(
      context,
      funExport,
      onCancel: () {
        funcCancel?.call();
      },
      onError: (error, stack) {
        showToast('Export failed');
      },
    );
