import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:eros_fe/common/controller/cache_controller.dart';
import 'package:eros_fe/common/controller/download/download_cover_resolver.dart';
import 'package:eros_fe/common/controller/download/download_file_path.dart';
import 'package:eros_fe/common/controller/download/storage_adapter.dart';
import 'package:eros_fe/common/controller/download_state.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/network/api.dart';
import 'package:eros_fe/store/db/entity/gallery_image_task.dart';
import 'package:eros_fe/store/db/entity/gallery_task.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;
import 'package:shared_storage/shared_storage.dart' as ss;
import 'package:synchronized/synchronized.dart';

@immutable
class TaskStatus {
  const TaskStatus(this.value);

  final int value;

  static TaskStatus from(int value) => TaskStatus(value);

  static const undefined = TaskStatus(0);
  static const enqueued = TaskStatus(1);
  static const running = TaskStatus(2);
  static const complete = TaskStatus(3);
  static const failed = TaskStatus(4);
  static const canceled = TaskStatus(5);
  static const paused = TaskStatus(6);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is TaskStatus && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return 'TaskStatus{value: $value}';
  }
}

class DownloadTaskManager {
  static const int _reconcileConcurrency = 4;

  DownloadTaskManager(this.dState, {StorageAdapter? storageAdapter})
      : storageAdapter = storageAdapter ?? StorageAdapter();
  final DownloadState dState;
  final CacheController cacheController = Get.find();
  final StorageAdapter storageAdapter;
  final Map<int, Lock> _taskLocks = <int, Lock>{};

  Lock _lockFor(int gid) => _taskLocks.putIfAbsent(gid, () => Lock());

  Future<void> _invoke(Function callback,
      [List<Object?> args = const []]) async {
    final result = Function.apply(callback, args);
    if (result is Future) {
      await result;
    }
  }

  void _cancelTask(int gid) {
    dState.taskCancelTokens[gid]?.cancel();
    final cancelToken = dState.cancelTokenMap[gid];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel();
    }
  }

  void _resetDownloadStatistics(int gid) {
    dState.downloadCounts
        .removeWhere((key, value) => key.startsWith('${gid}_'));
    dState.lastCounts.remove(gid);
    dState.downloadSpeeds.remove(gid);
    dState.noSpeed.remove(gid);
  }

  /// 取消当前画廊的活动请求，但保留图片任务和临时文件。
  Future<void> cancelGalleryWork(
    int gid, {
    Function? cancelTimerCallback,
  }) async {
    await _lockFor(gid).synchronized(() async {
      if (cancelTimerCallback != null) {
        await _invoke(cancelTimerCallback, [gid]);
      }
      _cancelTask(gid);
      _resetDownloadStatistics(gid);
    });
  }

  /// 更新任务为已完成
  Future<GalleryTask?> galleryTaskComplete(
    int gid, {
    Function? cancelTimerCallback,
  }) async {
    return _lockFor(gid).synchronized(() async {
      final current = dState.galleryTaskMap[gid] ??
          await isarHelper.findGalleryTaskByGidIsolate(gid);
      if (current == null) {
        logger.e('找不到任务: $gid');
        return null;
      }

      if (current.status == TaskStatus.failed.value ||
          current.status == TaskStatus.paused.value ||
          current.status == TaskStatus.canceled.value) {
        return current;
      }

      logger.t('更新任务为已完成');
      if (cancelTimerCallback != null) {
        await _invoke(cancelTimerCallback, [gid]);
      }
      _cancelTask(gid);
      _resetDownloadStatistics(gid);

      final galleryTask = current.status == TaskStatus.complete.value
          ? current
          : current.copyWith(status: TaskStatus.complete.value);
      dState.galleryTaskMap[gid] = galleryTask;
      await isarHelper.putGalleryTaskIsolate(galleryTask);
      await storageAdapter.writeTaskInfoFile(galleryTask);
      return galleryTask;
    });
  }

  /// 暂停任务
  Future<GalleryTask?> galleryTaskPaused(int gid,
      {bool silent = false, Function? cancelTimerCallback}) async {
    return _lockFor(gid).synchronized(() async {
      if (cancelTimerCallback != null) {
        await _invoke(cancelTimerCallback, [gid]);
      }
      logger.t('${dState.cancelTokenMap[gid]?.isCancelled}');
      _cancelTask(gid);
      _resetDownloadStatistics(gid);
      if (silent) {
        return null;
      }
      return _updateStatusLocked(gid, TaskStatus.paused);
    });
  }

  /// 恢复任务
  Future<void> galleryTaskResume(int gid,
      {Function? addGalleryTaskCallback}) async {
    await _lockFor(gid).synchronized(() async {
      final GalleryTask? galleryTask = dState.galleryTaskMap[gid] ??
          await isarHelper.findGalleryTaskByGidIsolate(gid);
      if (galleryTask == null ||
          galleryTask.status == TaskStatus.complete.value) {
        return;
      }

      logger.d('恢复任务 $gid showKey:${galleryTask.showKey}');
      _resetDownloadStatistics(gid);
      final resumeTask = galleryTask.copyWith(
        status: TaskStatus.enqueued.value,
      );
      dState.galleryTaskMap[gid] = resumeTask;
      await isarHelper.putGalleryTaskIsolate(resumeTask);
      logger.d('任务状态已重置为enqueued: gid=$gid');

      if (addGalleryTaskCallback != null) {
        logger.d('调用恢复任务回调: gid=$gid');
        await _invoke(addGalleryTaskCallback, [resumeTask]);
      }
    });
  }

  /// 重下任务
  Future<void> galleryTaskRestart(
    int gid, {
    Function? addGalleryTaskCallback,
  }) async {
    await _lockFor(gid).synchronized(() async {
      logger.d('开始重启任务: gid=$gid');
      _cancelTask(gid);
      _resetDownloadStatistics(gid);

      final GalleryTask? galleryTask = dState.galleryTaskMap[gid] ??
          await isarHelper.findGalleryTaskByGidIsolate(gid);
      if (galleryTask == null) {
        logger.e('重下任务失败: 找不到任务 gid=$gid');
        return;
      }

      logger.d(
          '重下任务: gid=$gid, 原状态=${galleryTask.status}, url=${galleryTask.url}');
      await _clearTaskFiles(galleryTask);
      await isarHelper.removeImageTask(gid);
      await cacheController.clearDioCache(
          path: '${Api.getBaseUrl()}${galleryTask.url}');

      final reTask = galleryTask.copyWith(
        completCount: 0,
        status: TaskStatus.enqueued.value,
        coverImage: null,
      );
      dState.galleryTaskMap[gid] = reTask;
      await isarHelper.putGalleryTaskIsolate(reTask);
      logger.d('重置后的任务已保存到数据库: gid=$gid');

      if (addGalleryTaskCallback != null) {
        logger.d('调用添加任务回调: gid=$gid');
        await _invoke(addGalleryTaskCallback, [reTask]);
      }
    });
  }

  /// 手动重下必须从头开始，清理最终文件和临时文件，但保留任务目录。
  /// 自动重试不会调用此方法，因此不会影响已完成图片。
  Future<void> _clearTaskFiles(GalleryTask task) async {
    await _clearSafTempFiles(task.gid);

    final dirPath = task.realDirPath;
    if (dirPath == null || dirPath.isEmpty) {
      return;
    }

    if (dirPath.isContentUri) {
      final files = await ss.listFiles(
        Uri.parse(dirPath),
        columns: const [
          ss.DocumentFileColumn.displayName,
          ss.DocumentFileColumn.id,
        ],
      ).toList();
      await Future.wait(files.map((file) => ss.delete(file.uri)));
      return;
    }

    final directory = Directory(dirPath);
    if (!await directory.exists()) {
      return;
    }
    await for (final entity in directory.list()) {
      await entity.delete(recursive: entity is Directory);
    }
  }

  Future<void> _clearSafTempFiles(int gid) async {
    final tempRoot = Global.extStoreTempPath;
    if (tempRoot.isEmpty) {
      return;
    }

    final tempDirectory = Directory(
      path.join(tempRoot, 'temp_download', '$gid'),
    );
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  }

  /// 更新任务进度
  Future<GalleryTask?> galleryTaskUpdate(
    int gid, {
    int? countComplete,
    String? coverImg,
    bool completeWhenReached = false,
  }) async {
    return _lockFor(gid).synchronized(() async {
      logger.t('galleryTaskCountUpdate gid:$gid count:$countComplete');
      final current = dState.galleryTaskMap[gid] ??
          await isarHelper.findGalleryTaskByGidIsolate(gid);
      if (current == null) {
        return null;
      }

      final currentCount = current.completCount ?? 0;
      final nextCount = math.max(currentCount, countComplete ?? currentCount);
      final canComplete = current.status != TaskStatus.failed.value &&
          current.status != TaskStatus.paused.value &&
          current.status != TaskStatus.canceled.value;
      final shouldComplete = completeWhenReached &&
          canComplete &&
          current.fileCount > 0 &&
          nextCount >= current.fileCount;
      final nextTask = current.copyWith(
        completCount: nextCount,
        coverImage: coverImg ?? current.coverImage,
        status: shouldComplete ? TaskStatus.complete.value : current.status,
      );
      dState.curComplete[gid] = nextCount;
      dState.galleryTaskMap[gid] = nextTask;
      await isarHelper.putGalleryTaskIsolate(nextTask);

      if (shouldComplete) {
        _cancelTask(gid);
        _resetDownloadStatistics(gid);
        await storageAdapter.writeTaskInfoFile(nextTask);
      }
      return nextTask;
    });
  }

  /// 更新任务状态
  Future<GalleryTask?> galleryTaskUpdateStatus(
    int gid,
    TaskStatus status,
  ) async {
    return _lockFor(gid).synchronized(() => _updateStatusLocked(gid, status));
  }

  Future<GalleryTask?> _updateStatusLocked(
    int gid,
    TaskStatus status,
  ) async {
    loggerSimple.d(
        '===== DownloadTaskManager更新状态: gid=$gid, 状态=$status (${status.value})');
    final current = dState.galleryTaskMap[gid] ??
        await isarHelper.findGalleryTaskByGidIsolate(gid);
    if (current == null) {
      logger.e('找不到任务: gid=$gid');
      return null;
    }

    // A stale worker is never allowed to downgrade a completed task.
    if (current.status == TaskStatus.complete.value &&
        status != TaskStatus.complete) {
      return current;
    }

    final task = current.copyWith(status: status.value);
    dState.galleryTaskMap[gid] = task;
    loggerSimple.d('保存到数据库: gid=$gid');
    await isarHelper.putGalleryTaskIsolate(task);
    loggerSimple.d('数据库保存完成: gid=$gid');
    if (status == TaskStatus.paused || status == TaskStatus.complete) {
      _resetDownloadStatistics(gid);
    }
    return task;
  }

  // Repair records written by older versions before enqueueing work.
  Future<GalleryTask> _reconcileTask(GalleryTask task) async {
    return _lockFor(task.gid).synchronized(() async {
      final imageTasks =
          await isarHelper.findImageTaskAllByGidIsolate(task.gid);
      var completeCount = 0;
      var imageTasksChanged = false;

      for (final imageTask in imageTasks) {
        var currentImageTask = imageTask;
        if (imageTask.status == TaskStatus.complete.value) {
          if (await _imageFileExists(task, imageTask)) {
            completeCount++;
          } else {
            currentImageTask = imageTask.copyWith(
              status: TaskStatus.enqueued.value,
              filePath: null,
            );
            await isarHelper.putImageTaskIsolate(currentImageTask);
            imageTasksChanged = true;
          }
        }
      }

      final coverImage = await _resolveCoverImage(task, imageTasks);

      final allFilesExist = task.fileCount > 0 &&
          imageTasks.length >= task.fileCount &&
          completeCount >= task.fileCount;
      final nextStatus = allFilesExist
          ? TaskStatus.complete.value
          : (task.status == TaskStatus.complete.value ||
                  task.status == TaskStatus.running.value
              ? TaskStatus.enqueued.value
              : task.status);
      final changed = imageTasksChanged ||
          task.completCount != completeCount ||
          task.status != nextStatus ||
          task.coverImage != coverImage;
      if (!changed) {
        return task;
      }

      final nextTask = task.copyWith(
        completCount: completeCount,
        status: nextStatus,
        coverImage: coverImage,
      );
      dState.galleryTaskMap[task.gid] = nextTask;
      await isarHelper.putGalleryTaskIsolate(nextTask);
      if (nextStatus == TaskStatus.complete.value ||
          task.coverImage != coverImage) {
        await storageAdapter.writeTaskInfoFile(nextTask);
      }
      return nextTask;
    });
  }

  Future<GalleryTask> reconcileGalleryTask(GalleryTask task) {
    return _reconcileTask(task);
  }

  Future<String?> _resolveCoverImage(
    GalleryTask task,
    List<GalleryImageTask> imageTasks,
  ) async {
    GalleryImageTask? firstImageTask;
    for (final imageTask in imageTasks) {
      if (imageTask.ser == 1) {
        firstImageTask = imageTask;
        break;
      }
    }
    return resolveDownloadCoverImageFileName(
      candidates: [firstImageTask?.filePath, task.coverImage],
      isAvailable: (fileName) => _downloadFileExists(task, fileName),
    );
  }

  Future<bool> _imageFileExists(
    GalleryTask task,
    GalleryImageTask imageTask,
  ) async {
    final fileName = imageTask.filePath;
    return _downloadFileExists(task, fileName);
  }

  Future<bool> _downloadFileExists(GalleryTask task, String? fileName) async {
    final dirPath = task.realDirPath;
    final filePath = buildDownloadFilePath(
      directoryPath: dirPath,
      fileName: fileName,
    );
    if (filePath == null) {
      return false;
    }
    if (dirPath?.startsWith('content://') ?? false) {
      return await ss.exists(Uri.parse(filePath)) ?? false;
    }
    final file = File(filePath);
    if (!await file.exists()) {
      return false;
    }
    return await file.length() > 0;
  }

  Future<GalleryTask> _reconcileTaskSafely(GalleryTask task) async {
    try {
      return await _reconcileTask(task);
    } on Object catch (error, stack) {
      // 一个任务损坏不能阻塞其他任务的恢复，保留数据库中的原始记录。
      logger.e(
        '恢复下载任务失败，保留原任务: gid=${task.gid}',
        error: error,
        stackTrace: stack,
      );
      return dState.galleryTaskMap[task.gid] ?? task;
    }
  }

  Future<void> _reconcileAndResumeTasks({
    required List<GalleryTask> tasks,
    Function? addGalleryTaskCallback,
    Function? onTaskReconciledCallback,
  }) async {
    for (var start = 0; start < tasks.length; start += _reconcileConcurrency) {
      final end = math.min(start + _reconcileConcurrency, tasks.length);
      final batch = tasks.sublist(start, end);
      final reconciledTasks = await Future.wait<GalleryTask>(
        batch.map(_reconcileTaskSafely),
      );

      for (var index = 0; index < reconciledTasks.length; index++) {
        final originalTask = batch[index];
        final task = reconciledTasks[index];
        if (!identical(originalTask, task) &&
            onTaskReconciledCallback != null) {
          await _invoke(onTaskReconciledCallback, [task]);
        }
      }

      // Start resumable tasks after their own reconciliation instead of
      // waiting for every gallery in the database to finish.
      for (final task in reconciledTasks) {
        if (task.status == TaskStatus.enqueued.value ||
            task.status == TaskStatus.running.value) {
          logger.d('继续未完成的任务');
          if (addGalleryTaskCallback != null) {
            await _invoke(addGalleryTaskCallback, [task]);
          }
        }
      }
    }
  }

  /// 移除任务
  Future<void> removeDownloadGalleryTask({
    required int gid,
    bool shouldDeleteContent = true,
  }) async {
    final GalleryTask? task = dState.galleryTaskMap[gid] ??
        await isarHelper.findGalleryTaskByGidIsolate(gid);
    if (task == null) {
      return;
    }

    // 取消任务
    _cancelTask(task.gid);
    _resetDownloadStatistics(task.gid);

    dState.galleryTaskMap.remove(gid);

    // 删除文件
    String? dirPath = task.realDirPath;
    logger.t('dirPath: $dirPath');
    if (dirPath != null && shouldDeleteContent) {
      if (dirPath.isContentUri) {
        // SAF
        await ss.delete(Uri.parse(dirPath));
      } else {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
    }

    // 删除数据库记录
    await isarHelper.removeImageTask(task.gid);
    await isarHelper.removeGalleryTask(task.gid);
  }

  // 初始化任务列表
  Future<void> initGalleryTasks(
      {Function? addGalleryTaskCallback,
      Function? downloadTaskMigrationCallback,
      bool waitForReconciliation = true,
      Function? onTaskReconciledCallback}) async {
    if (downloadTaskMigrationCallback != null) {
      await _invoke(downloadTaskMigrationCallback);
    }

    final tasks = await isarHelper.findAllGalleryTasksIsolate();

    // 先把数据库中的任务放入内存。修复文件状态和封面可能需要较长时间，
    // 不能因为这段后台修复让下载列表在启动期间保持空白。
    for (final task in tasks) {
      dState.galleryTaskMap[task.gid] = task;
    }

    final reconciliation = _reconcileAndResumeTasks(
      tasks: tasks,
      addGalleryTaskCallback: addGalleryTaskCallback,
      onTaskReconciledCallback: onTaskReconciledCallback,
    );
    if (waitForReconciliation) {
      await reconciliation;
    } else {
      // The download page can render the database snapshot immediately while
      // file checks and recovery continue in the background.
      unawaited(reconciliation.catchError((Object error, StackTrace stack) {
        logger.e(
          '后台恢复下载任务失败',
          error: error,
          stackTrace: stack,
        );
      }));
    }
  }

  Future<void> restoreGalleryTasks({
    bool init = false,
    Function? getDownloadPathCallback,
    Function? restoreTasksWithPathCallback,
    Function? restoreTasksWithSAFCallback,
    Function? onInitCallback,
    Function? resetDownloadViewAnimationKeyCallback,
  }) async {
    if (getDownloadPathCallback == null) {
      return;
    }

    final String currentDownloadPath =
        await Function.apply(getDownloadPathCallback, []);
    logger.d('_currentDownloadPath: $currentDownloadPath');

    if (currentDownloadPath.isContentUri) {
      if (restoreTasksWithSAFCallback != null) {
        await Function.apply(
            restoreTasksWithSAFCallback, [currentDownloadPath]);
      }
    } else {
      if (restoreTasksWithPathCallback != null) {
        await Function.apply(
            restoreTasksWithPathCallback, [currentDownloadPath]);
      }
    }

    if (init) {
      if (onInitCallback != null) {
        await _invoke(onInitCallback);
      }
      if (resetDownloadViewAnimationKeyCallback != null) {
        await _invoke(resetDownloadViewAnimationKeyCallback);
      }
    }
  }
}
