import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:eros_fe/common/controller/download/download_monitor.dart' as dm;
import 'package:eros_fe/common/controller/download/download_path_manager.dart';
import 'package:eros_fe/common/controller/download/download_task_manager.dart'
    as dtm;
import 'package:eros_fe/common/controller/download/gallery_slot_manager.dart';
import 'package:eros_fe/common/controller/download/gallery_update_service.dart';
import 'package:eros_fe/common/controller/download/image_download_processor.dart';
import 'package:eros_fe/common/controller/download/storage_adapter.dart';
import 'package:eros_fe/common/controller/gallerycache_controller.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/component/exception/error.dart';
import 'package:eros_fe/component/quene_task/quene_task.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/network/app_dio/pdio.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_controller.dart';
import 'package:eros_fe/pages/tab/controller/download_view_controller.dart';
import 'package:eros_fe/store/db/entity/gallery_image_task.dart';
import 'package:eros_fe/store/db/entity/gallery_task.dart';
import 'package:executor/executor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_storage/shared_storage.dart' as ss;
import 'package:synchronized/synchronized.dart';

import 'cache_controller.dart';
import 'download_state.dart'
    hide kPeriodSeconds, kMaxCount, kCheckMaxCount, kRetryThresholdTime;

Future<String> get defDownloadPath async => GetPlatform.isAndroid
    ? await getAndroidDefaultDownloadPath()
    : (GetPlatform.isWindows
        ? path.join((await getDownloadsDirectory())!.path, 'fehviewer')
        : path.join(Global.appDocPath, 'Download'));

Future<String> getAndroidDefaultDownloadPath() async {
  final downloadPath = path.join(Global.extStorePath, 'Download');

  final dir = Directory(downloadPath);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  return downloadPath;
}

// 使用dtm中定义的TaskStatus
typedef TaskStatus = dtm.TaskStatus;

class DownloadController extends GetxController {
  final DownloadState dState = DownloadState();

  // 首屏初始化只等待数据库快照；文件完整性修复在后台执行。
  Future<void>? _downloadInitialization;
  Future<void> get downloadInitialization =>
      _downloadInitialization ?? Future<void>.value();

  final EhSettingService ehSettingService = Get.find();
  final CacheController cacheController = Get.find();

  // 新增的委托类实例
  late final DownloadPathManager pathManager;
  late final dtm.DownloadTaskManager taskManager;
  late final dm.DownloadMonitor downloadMonitor;
  late final ImageDownloadProcessor imageProcessor;
  late final StorageAdapter storageAdapter;
  late final GallerySlotManager gallerySlotManager;
  final Map<int, Lock> _completionLocks = <int, Lock>{};
  final Map<int, Lock> _taskLocks = <int, Lock>{};
  final Lock _concurrencyResetLock = Lock();
  final Lock _transferGateLock = Lock();
  final Set<int> _reservedGids = <int>{};
  final Set<String> _reservedIoDirs = <String>{};
  final Set<String> _unretiredOldDirs = <String>{};

  Future<String> _resolveRealDirKey(String dirPath) async {
    if (dirPath.isEmpty || dirPath.isContentUri) {
      return dirPath;
    }
    try {
      return path.canonicalize(await Directory(dirPath).resolveSymbolicLinks());
    } catch (_) {
      return path.canonicalize(dirPath);
    }
  }

  Lock _completionLockFor(int gid) =>
      _completionLocks.putIfAbsent(gid, () => Lock());

  Set<String> _collectOwnedIoDirs() {
    final owned = <String>{..._reservedIoDirs};
    for (final task in dState.galleryTaskMap.values) {
      final real = task.realDirPath;
      if (real != null && real.isNotEmpty) {
        owned.add(real.isContentUri ? real : path.canonicalize(real));
      }
    }
    return owned;
  }

  Future<T> _withOrderedCompletionLocks<T>(
    List<int> gids,
    Future<T> Function() action,
  ) async {
    final sorted = gids.toSet().toList()..sort();
    Future<T> run(int index) {
      if (index >= sorted.length) {
        return action();
      }
      return _completionLockFor(sorted[index])
          .synchronized(() => run(index + 1));
    }

    return run(0);
  }

  Future<void> _evictCoverCache(String? dirPath, String? fileName) async {
    if (dirPath == null ||
        dirPath.isEmpty ||
        dirPath.isContentUri ||
        fileName == null ||
        fileName.isEmpty) {
      return;
    }
    try {
      await FileImage(File(path.join(dirPath, fileName))).evict();
    } catch (_) {}
  }

  @override
  void onInit() {
    super.onInit();
    // logger.d(
    //     'DownloadController onInit multiDownload:${ehSettingService.multiDownload}');
    dState.executor = Executor(concurrency: ehSettingService.multiDownload);

    // 初始化委托类
    storageAdapter = StorageAdapter();
    pathManager = DownloadPathManager(ehSettingService);
    taskManager = dtm.DownloadTaskManager(
      dState,
      storageAdapter: storageAdapter,
      taskLocks: _taskLocks,
    );
    downloadMonitor = dm.DownloadMonitor(dState);
    imageProcessor = ImageDownloadProcessor(dState, cacheController);

    // 初始化画廊槽位管理器
    gallerySlotManager = GallerySlotManager(
      maxConcurrentGalleries: ehSettingService.concurrentGalleries,
      onStartGallery: _startGalleryDownload,
      onUpdateStatus: galleryTaskUpdateStatus,
    );

    _downloadInitialization = asyncInit();
  }

  @override
  void onClose() {
    _cancelDownloadStateChkTimer();
    super.onClose();
  }

  Future<Set<String>> _reconcilePendingIncrementalUpdates() async {
    try {
      final basePersisted = await pathManager.getGalleryDownloadPath();
      if (basePersisted.isEmpty || basePersisted.isContentUri) {
        return const <String>{};
      }
      final baseIoDir = pathManager.resolveLocalIoDirPath(basePersisted);
      final unretired = await reconcilePendingIncrementalUpdates(
        baseDownloadIoDir: baseIoDir,
        findTaskByGid: (int gid) => isarHelper.findGalleryTaskByGidIsolate(gid),
        findAllTasks: () => isarHelper.findAllGalleryTasksIsolate(),
        withEntryLock:
            (int newGid, int? oldGid, Future<void> Function() action) =>
                _withOrderedCompletionLocks<void>(
                  <int>[newGid, if (oldGid != null) oldGid],
                  () => taskManager.runWithTaskLock<void>(
                    newGid,
                    () => _transferGateLock.synchronized(action),
                  ),
                ),
        isReserved: (int newGid, int? oldGid) async =>
            _reservedGids.contains(newGid) ||
            (oldGid != null && _reservedGids.contains(oldGid)),
        getOwnedIoDirs: () async => _collectOwnedIoDirs(),
      );
      await _transferGateLock.synchronized(() async {
        _unretiredOldDirs.removeWhere((dir) => !Directory(dir).existsSync());
        _unretiredOldDirs.addAll(unretired);
      });
      return await _transferGateLock.synchronized(
        () => Set<String>.from(_unretiredOldDirs),
      );
    } catch (e, stack) {
      logger.w(
        'Failed to reconcile pending incremental updates',
        error: e,
        stackTrace: stack,
      );
      return await _transferGateLock.synchronized(
        () => Set<String>.from(_unretiredOldDirs),
      );
    }
  }

  Future<void> asyncInit() async {
    await pathManager.updateCustomDownloadPath();
    await pathManager.allowMediaScan(ehSettingService.allowMediaScan);
    await _reconcilePendingIncrementalUpdates();
    await taskManager.initGalleryTasks(
      addGalleryTaskCallback: _addGalleryTask,
      downloadTaskMigrationCallback: downloadTaskMigration,
      waitForReconciliation: false,
      onTaskReconciledCallback: _onTaskReconciled,
    );
    _refreshDownloadGalleryList();
  }

  Future<void> updateCustomDownloadPath() async {
    await pathManager.updateCustomDownloadPath();
    restoreGalleryTasks();
  }

  /// 切换允许媒体扫描
  Future<void> allowMediaScan(bool allow) async {
    await pathManager.allowMediaScan(allow);
  }

  /// 下载画廊
  Future<void> downloadGallery({
    required String url,
    required int fileCount,
    required String title,
    int? gid,
    String? token,
    String? coverUrl,
    double? rating,
    String? category,
    String? uploader,
    bool downloadOri = false,
    String? showKey,
  }) async {
    int gid0 = 0;
    String token0 = '';
    if (gid == null || token == null) {
      final RegExpMatch match =
          RegExp(r'/g/(\d+)/([0-9a-f]{10})/?').firstMatch(url)!;
      gid0 = int.parse(match.group(1)!);
      token0 = match.group(2)!;
    }
    final resolvedGid = gid ?? gid0;
    final resolvedToken = token ?? token0;

    final reserved = await _transferGateLock.synchronized(() {
      if (_reservedGids.contains(resolvedGid)) {
        return false;
      }
      _reservedGids.add(resolvedGid);
      return true;
    });
    if (!reserved) {
      showToast('Download task existed');
      return;
    }

    String? reservedDirKey;
    try {
      // 先查询任务是否已存在
      final GalleryTask? oriTask =
          dState.galleryTaskMap[resolvedGid] ??
          await isarHelper.findGalleryTaskByGidIsolate(resolvedGid);
      if (oriTask != null) {
        showToast('Download task existed');
        logger.i('$resolvedGid 任务已存在');
        logger.d('${oriTask.toString()} ');
        return;
      }

      final String galleryDirName = path.join(
        '$resolvedGid - ${path.split(title).join('_').replaceAll(RegExp(r'[/:*"<>|,?]'), '_')}',
      );
      String dirPath;
      try {
        final ownedDirs = await _transferGateLock.synchronized(
          _collectOwnedIoDirs,
        );
        final (persistedPath, ioPath) =
            await pathManager.allocateExclusiveGalleryDownloadPath(
              baseDirName: galleryDirName,
              ownedIoDirs: ownedDirs,
            );
        dirPath = persistedPath;
        reservedDirKey = ioPath.isContentUri ? ioPath : path.canonicalize(ioPath);
        await _transferGateLock.synchronized(() {
          _reservedIoDirs.add(reservedDirKey!);
        });
      } catch (err, stack) {
        logger.e('创建目录失败', error: err, stackTrace: stack);
        showToast('create Directory error, $err');
        return;
      }

      logger.d('downloadPath:$dirPath');

      // 登记主任务表
      final GalleryTask galleryTask = GalleryTask(
        gid: resolvedGid,
        token: resolvedToken,
        url: url,
        title: title,
        fileCount: fileCount,
        dirPath: dirPath,
        status: TaskStatus.enqueued.value,
        addTime: DateTime.now().millisecondsSinceEpoch,
        coverUrl: coverUrl,
        rating: rating,
        category: category,
        uploader: uploader,
        downloadOrigImage: downloadOri,
        showKey: showKey,
      );

      logger.d('add NewTask ${galleryTask.toString()}');
      await isarHelper.putGalleryTaskIsolate(galleryTask,
          replaceOnConflict: false);
      dState.galleryTaskMap[galleryTask.gid] = galleryTask;
      downloadViewAnimateListAdd();
      showToast('${galleryTask.gid} Download task start');

      // 使用_addGalleryTask添加到槽位管理器
      _addGalleryTask(
        galleryTask,
        groupCount: Get.find<GalleryPageController>(tag: pageCtrlTag)
            .gState
            .firstPageImage
            .length,
      );
    } finally {
      await _transferGateLock.synchronized(() {
        _reservedGids.remove(resolvedGid);
        if (reservedDirKey != null) {
          _reservedIoDirs.remove(reservedDirKey);
        }
      });
    }
  }

  /// Executes an incremental update from an already downloaded gallery to a
  /// newer version by reusing verified local images and fetching only delta pages.
  ///
  /// Both `inPlace` and `newTask` build the new gallery in a brand-new exclusive
  /// directory and commit via a single Isar transaction so any I/O or DB failure
  /// leaves the original downloaded gallery completely intact.
  Future<GalleryIncrementalExecutionResult?> executeIncrementalUpdate(
    GalleryIncrementalPlan plan, {
    required GalleryIncrementalUpdateMode mode,
  }) async {
    final oldTask = plan.oldTask;
    final oldGid = oldTask.gid;
    final newGid = plan.newGid;
    if (newGid <= 0 || newGid == oldGid || plan.totalNewPages <= 0) {
      return null;
    }

    final gidsToReserve = mode == GalleryIncrementalUpdateMode.inPlace
        ? <int>{oldGid, newGid}
        : <int>{newGid};
    final reserved = await _transferGateLock.synchronized(() {
      if (gidsToReserve.any(_reservedGids.contains)) {
        return false;
      }
      _reservedGids.addAll(gidsToReserve);
      return true;
    });
    if (!reserved) {
      showToast('Download task existed');
      return null;
    }

    String? reservedDirKey;
    String? createdTargetIoDir;
    String? createdTargetSafUri;
    var committedToDb = false;

    try {
      return await _withOrderedCompletionLocks<
          GalleryIncrementalExecutionResult?>(
        <int>[oldGid, newGid],
        () async {
          final existingTarget =
              dState.galleryTaskMap[newGid] ??
              await isarHelper.findGalleryTaskByGidIsolate(newGid);
          if (existingTarget != null) {
            showToast('Download task existed');
            return null;
          }

          // Re-verify the source task inside the lock before doing any I/O.
          final currentOldTask =
              dState.galleryTaskMap[oldGid] ??
              await isarHelper.findGalleryTaskByGidIsolate(oldGid);
          if (currentOldTask == null ||
              currentOldTask.status != TaskStatus.complete.value ||
              currentOldTask.token != oldTask.token ||
              currentOldTask.dirPath != oldTask.dirPath) {
            throw StateError(
              'Source gallery #$oldGid changed or is no longer complete',
            );
          }

          final sourceIoDirPath = currentOldTask.realDirPath;
          if (sourceIoDirPath == null || sourceIoDirPath.isEmpty) {
            throw StateError('Source download directory is unavailable');
          }

          final targetBaseIsSaf = ehSettingService.downloadLocatino.isContentUri;
          final sourceIsSaf = sourceIoDirPath.isContentUri;
          final useSafFallback = sourceIsSaf || targetBaseIsSaf;

          if (useSafFallback && mode == GalleryIncrementalUpdateMode.inPlace) {
            throw UnsupportedError('saf_inplace_unsupported');
          }

          final targetProvider = plan.targetProvider;
          final newTitle =
              (ehSettingService.jpnTitleInGalleryPage &&
                      (targetProvider.japaneseTitle?.trim().isNotEmpty ??
                          false))
                  ? targetProvider.japaneseTitle!.trim()
                  : (targetProvider.englishTitle?.trim().isNotEmpty ?? false)
                      ? targetProvider.englishTitle!.trim()
                      : plan.targetVersion.title;
          final canonicalUrl = normalizeGalleryUrl(
            plan.canonicalTargetUrl.isNotEmpty
                ? plan.canonicalTargetUrl
                : plan.targetVersion.url,
            baseUri: extractSiteBaseUri(currentOldTask.url),
          );
          final newUrl = canonicalUrl.isNotEmpty
              ? canonicalUrl
              : '/g/$newGid/${plan.newToken}/';
          final newFileCount = plan.totalNewPages;
          final oldImageTasks = await isarHelper.findImageTaskAllByGidIsolate(
            oldGid,
          );

          if (mode == GalleryIncrementalUpdateMode.inPlace) {
            await taskManager.cancelGalleryWork(
              oldGid,
              cancelTimerCallback: _cancelDownloadStateChkTimer,
            );
          }

          final baseDirName = path.join(
            '$newGid - ${path.split(newTitle).join('_').replaceAll(RegExp(r'[/:*"<>|,?]'), '_')}',
          );
          final ownedDirs = await _transferGateLock.synchronized(
            _collectOwnedIoDirs,
          );
          final (persistedDirPath, targetIoDirPath) =
              await pathManager.allocateExclusiveGalleryDownloadPath(
                baseDirName: baseDirName,
                ownedIoDirs: ownedDirs,
              );
          reservedDirKey = targetIoDirPath.isContentUri
              ? targetIoDirPath
              : path.canonicalize(targetIoDirPath);
          await _transferGateLock.synchronized(() {
            _reservedIoDirs.add(reservedDirKey!);
          });
          if (targetIoDirPath.isContentUri) {
            createdTargetSafUri = targetIoDirPath;
          } else {
            createdTargetIoDir = targetIoDirPath;
            // Write recovery journal immediately upon directory allocation so
            // even a kill mid-copy can be cleaned up cleanly on next start.
            await writePendingIncrementalJournal(
              targetIoDirPath: targetIoDirPath,
              newGid: newGid,
              oldGid: oldGid,
              oldToken: currentOldTask.token,
              oldIoDirPath: sourceIoDirPath,
              mode: mode,
            );
          }

          late final List<GalleryImageTask> reusedTasks;
          String? coverImage;

          if (useSafFallback) {
            reusedTasks = const <GalleryImageTask>[];
            coverImage = null;
          } else {
            final prepared = await prepareIncrementalLocalFiles(
              plan: plan,
              mode: mode,
              sourceDirPath: sourceIoDirPath,
              targetDirPath: targetIoDirPath,
              oldImageTasks: oldImageTasks,
            );
            reusedTasks = prepared.reusedImageTasks;
            coverImage = prepared.coverImage;
          }

          final reusedCount = reusedTasks.length;
          final remainingCount = max(0, newFileCount - reusedCount);
          final completedLocally = newFileCount > 0 && remainingCount == 0;
          final newTask = GalleryTask(
            gid: newGid,
            token: plan.newToken,
            url: newUrl,
            title: newTitle,
            dirPath: persistedDirPath,
            fileCount: newFileCount,
            completCount: reusedCount,
            status: completedLocally
                ? TaskStatus.complete.value
                : TaskStatus.enqueued.value,
            coverImage: coverImage,
            addTime: mode == GalleryIncrementalUpdateMode.inPlace
                ? (currentOldTask.addTime ??
                    DateTime.now().millisecondsSinceEpoch)
                : DateTime.now().millisecondsSinceEpoch,
            coverUrl: targetProvider.imgUrl ?? currentOldTask.coverUrl,
            rating: targetProvider.rating ?? currentOldTask.rating,
            category: targetProvider.category ?? currentOldTask.category,
            uploader: targetProvider.uploader ?? currentOldTask.uploader,
            downloadOrigImage: currentOldTask.downloadOrigImage,
            showKey: targetProvider.showKey,
          );

          // Stage metadata under `.info.staging` BEFORE committing Isar so
          // Restore Download Tasks never imports an uncommitted `.info` file.
          if (!targetIoDirPath.isContentUri) {
            await storageAdapter.writeTaskInfoFileWithImages(
              newTask,
              reusedTasks,
              fileName: kIncrementalStagingInfoFileName,
            );
          }

          // Single atomic Isar transaction: insert newTask + reused image tasks,
          // and (for inPlace) delete oldTask + old image tasks together.
          await isarHelper.commitIncrementalUpdateIsolate(
            newTask: newTask,
            newImageTasks: reusedTasks,
            removeOldGid:
                mode == GalleryIncrementalUpdateMode.inPlace ? oldGid : null,
            expectedOldToken: mode == GalleryIncrementalUpdateMode.inPlace
                ? currentOldTask.token
                : null,
            expectedOldDirPath: mode == GalleryIncrementalUpdateMode.inPlace
                ? currentOldTask.dirPath
                : null,
          );
          committedToDb = true;

          // Publish committed state to in-memory maps FIRST so post-commit
          // file finalization errors can never leave UI/state diverged from DB.
          dState.galleryTaskMap[newGid] = newTask;
          dState.claimedImageFiles[newGid] = <int, String>{
            for (final t in reusedTasks)
              if (t.filePath != null && t.filePath!.isNotEmpty)
                t.ser: t.filePath!,
          };

          if (mode == GalleryIncrementalUpdateMode.inPlace) {
            dState.galleryTaskMap.remove(oldGid);
            dState.claimedImageFiles.remove(oldGid);
            dState.unavailableGalleryFiles.remove(oldGid);
            dState.errInfoMap.remove(oldGid);
            dState.incrementalProgressMap.remove(oldGid);
          }

          if (completedLocally) {
            dState.incrementalProgressMap.remove(newGid);
          } else if (reusedCount > 0) {
            dState.incrementalProgressMap[newGid] = GalleryIncrementalProgress(
              gid: newGid,
              reusedCount: reusedCount,
              totalCount: newFileCount,
              mode: mode,
            );
          } else {
            dState.incrementalProgressMap.remove(newGid);
          }
          _refreshDownloadGalleryList();

          if (!completedLocally) {
            _addGalleryTask(
              newTask,
              groupCount: plan.firstPageCount,
              images: plan.targetImages,
            );
          }

          // Best-effort post-commit finalization (retains `.inc_pending.json`
          // for startup/restore retry if any file operation fails).
          if (targetIoDirPath.isContentUri) {
            try {
              await taskManager.runWithTaskLock<void>(
                newGid,
                () => storageAdapter.writeTaskInfoFileWithImages(
                  newTask,
                  reusedTasks,
                ),
              );
            } catch (e, stack) {
              logger.w(
                'Failed to write SAF .info after commit for #$newGid',
                error: e,
                stackTrace: stack,
              );
            }
          } else {
            var finalized = false;
            try {
              finalized = await taskManager.runWithTaskLock<bool>(
                newGid,
                () => finalizeCommittedIncrementalDirectory(
                  targetIoDirPath: targetIoDirPath,
                  retireOldIoDirPath:
                      mode == GalleryIncrementalUpdateMode.inPlace
                          ? sourceIoDirPath
                          : null,
                  newGid: newGid,
                  oldGid: oldGid,
                  oldToken: currentOldTask.token,
                ),
              );
              if (!finalized) {
                logger.w(
                  'Incremental file finalization incomplete for #$newGid; '
                  'pending journal retained for retry',
                );
              }
            } catch (e, stack) {
              logger.w(
                'Incremental file finalization threw for #$newGid; '
                'pending journal retained for retry',
                error: e,
                stackTrace: stack,
              );
            }
            if (!finalized &&
                mode == GalleryIncrementalUpdateMode.inPlace &&
                !sourceIoDirPath.isContentUri) {
              // Record failed source retirement BEFORE releasing `_reservedGids`
              // so a concurrent/subsequent restore cannot re-import old `.info`.
              final resolvedOld = await _resolveRealDirKey(sourceIoDirPath);
              await _transferGateLock.synchronized(() {
                _unretiredOldDirs.add(resolvedOld);
                _unretiredOldDirs.add(path.canonicalize(sourceIoDirPath));
              });
            }
          }

          if (mode == GalleryIncrementalUpdateMode.inPlace) {
            await _evictCoverCache(sourceIoDirPath, currentOldTask.coverImage);
            await _evictCoverCache(targetIoDirPath, coverImage);

            // Best-effort conditional reading progress migration isolated from
            // task finalization and checked synchronously before writing.
            if (Get.isRegistered<GalleryCacheController>()) {
              try {
                final cacheCtrl = Get.find<GalleryCacheController>();
                final freshOldCache = await cacheCtrl
                    .listenGalleryCache('$oldGid', sync: false)
                    .first;
                final freshOldIndex = freshOldCache?.lastIndex;
                if (freshOldIndex != null && freshOldIndex > 0) {
                  final mappedIndex = mapReadingIndexForIncrementalUpdate(
                    oldLastIndex: freshOldIndex,
                    reusedPages: plan.reusedPages,
                    totalNewPages: newFileCount,
                  );
                  if (mappedIndex != null) {
                    await cacheCtrl.setIndex(
                      '$newGid',
                      mappedIndex,
                      saveToStore: true,
                      onlyIfUnset: true,
                    );
                  }
                }
              } catch (e, stack) {
                logger.w(
                  'Failed to migrate reading progress from #$oldGid to #$newGid',
                  error: e,
                  stackTrace: stack,
                );
              }
            }
          } else {
            await _evictCoverCache(targetIoDirPath, coverImage);
          }

          return GalleryIncrementalExecutionResult(
            task: newTask,
            reusedCount: reusedCount,
            downloadCount: remainingCount,
            completedLocally: completedLocally,
          );
        },
      );
    } catch (_) {
      if (!committedToDb) {
        if (createdTargetIoDir != null) {
          try {
            final dir = Directory(createdTargetIoDir!);
            if (await dir.exists()) {
              await dir.delete(recursive: true);
            }
          } catch (_) {}
        }
        if (createdTargetSafUri != null) {
          try {
            final deleted =
                await ss.delete(Uri.parse(createdTargetSafUri!)) ?? false;
            if (!deleted) {
              logger.w(
                'SAF rollback delete returned false for $createdTargetSafUri',
              );
            }
          } catch (e, stack) {
            logger.w(
              'SAF rollback delete failed for $createdTargetSafUri',
              error: e,
              stackTrace: stack,
            );
          }
        }
      }
      rethrow;
    } finally {
      await _transferGateLock.synchronized(() {
        _reservedGids.removeAll(gidsToReserve);
        if (reservedDirKey != null) {
          _reservedIoDirs.remove(reservedDirKey);
        }
      });
    }
  }

  void downloadViewAnimateListAdd() {
    if (Get.isRegistered<DownloadViewController>()) {
      Get.find<DownloadViewController>().animateGalleryListAddTask();
    }
  }

  /// 更新任务为已完成
  Future<GalleryTask?> galleryTaskComplete(int gid) async {
    return _completionLockFor(gid)
        .synchronized(() => _completeGalleryTask(gid));
  }

  Future<GalleryTask?> _completeGalleryTask(int gid) async {
    final wasComplete =
        dState.galleryTaskMap[gid]?.status == TaskStatus.complete.value;
    logger.d('画廊任务完成: gid=$gid');
    final task = await taskManager.galleryTaskComplete(
      gid,
      cancelTimerCallback: _cancelDownloadStateChkTimer,
    );
    _updateDownloadView(['DownloadGalleryItem_$gid']);
    if (!wasComplete && task?.status == TaskStatus.complete.value) {
      await vibrateUtil.success();
    }

    if (task?.status == TaskStatus.complete.value) {
      dState.incrementalProgressMap.remove(gid);
      // 清理该画廊的所有重试计数
      imageProcessor.clearGalleryReDownloadCounts(gid);

      // 通知槽位管理器状态变化
      logger.d('通知槽位管理器画廊任务完成: gid=$gid');
      await gallerySlotManager.onGalleryStatusChanged(gid, TaskStatus.complete);
      logger.d('槽位管理器处理完成: gid=$gid');
    }

    return task;
  }

  /// 暂停任务
  Future<GalleryTask?> galleryTaskPaused(int gid, {bool silent = false}) async {
    logger.d('画廊任务暂停: gid=$gid, silent=$silent');
    final task = await taskManager.galleryTaskPaused(
      gid,
      silent: silent,
      cancelTimerCallback: _cancelDownloadStateChkTimer,
    );
    if (!silent) {
      _updateDownloadView(['DownloadGalleryItem_$gid']);
    }

    if (silent || task?.status == TaskStatus.paused.value) {
      // 通知槽位管理器状态变化
      logger.d('通知槽位管理器画廊任务暂停: gid=$gid');
      await gallerySlotManager.onGalleryStatusChanged(gid, TaskStatus.paused);
      logger.d('槽位管理器处理完成: gid=$gid');
    }

    return task;
  }

  /// 恢复任务
  Future<void> galleryTaskResume(int gid) async {
    await _completionLockFor(gid).synchronized(() async {
      logger.d('画廊任务恢复: gid=$gid');

      // Reconcile restored files before changing pause state or enqueueing.
      await taskManager.galleryTaskResume(
        gid,
        addGalleryTaskCallback: _addGalleryTask,
      );
      final task = dState.galleryTaskMap[gid];
      if (task?.status == TaskStatus.complete.value) {
        await gallerySlotManager.onGalleryStatusChanged(
            gid, TaskStatus.complete);
      }
      _updateDownloadView(['DownloadGalleryItem_$gid']);

      // 注意：现在不再直接通知槽位管理器状态为running
      // 由槽位管理器自己管理状态变更，在合适的时候启动任务
      logger.d('恢复任务完成: gid=$gid');
    });
  }

  /// 重下任务
  Future<void> galleryTaskRestart(int gid) async {
    await _completionLockFor(gid).synchronized(() async {
      loggerSimple.d('重启任务开始: gid=$gid');

      // 先尝试暂停正在进行的任务（如果有）
      // 这将取消现有下载和计时器
      if (dState.galleryTaskMap.containsKey(gid) &&
          dState.galleryTaskMap[gid]?.status == TaskStatus.running.value) {
        loggerSimple.d('先暂停当前运行中的任务: gid=$gid');
        await galleryTaskPaused(gid, silent: true);
      }

      // 取消特定任务的所有网络请求
      if (dState.cancelTokenMap.containsKey(gid) &&
          !(dState.cancelTokenMap[gid]?.isCancelled ?? true)) {
        loggerSimple.d('取消现有下载请求: gid=$gid');
        dState.cancelTokenMap[gid]?.cancel();
      }

      // 取消该任务的计时器
      _cancelDownloadStateChkTimer(gid);

      // 调用taskManager执行任务重启
      loggerSimple.d('执行任务重启: gid=$gid');
      await taskManager.galleryTaskRestart(
        gid,
        addGalleryTaskCallback: _addGalleryTask,
      );

      loggerSimple.d('重启任务完成: gid=$gid');
    });
  }

  /// 更新任务进度
  Future<GalleryTask?> galleryTaskUpdate(
    int gid, {
    int? countComplete,
    String? coverImg,
    bool completeWhenReached = false,
  }) {
    return taskManager.galleryTaskUpdate(
      gid,
      countComplete: countComplete,
      coverImg: coverImg,
      completeWhenReached: completeWhenReached,
    );
  }

  /// 更新任务状态
  Future<GalleryTask?> galleryTaskUpdateStatus(
    int gid,
    TaskStatus status,
  ) async {
    logger.d('更新任务状态: gid=$gid, 新状态=$status (${status.value})');

    // 获取当前任务状态和信息用于记录
    GalleryTask? oldTask = dState.galleryTaskMap[gid];
    int? oldStatus = oldTask?.status;
    logger.d('当前任务: gid=$gid, 旧状态=$oldStatus, 任务=${oldTask?.title}');

    // 通过taskManager更新状态
    final task = await taskManager.galleryTaskUpdateStatus(gid, status);

    if (oldStatus != TaskStatus.failed.value &&
        task?.status == TaskStatus.failed.value) {
      await vibrateUtil.error();
    }
    logger.d('状态更新完成: gid=$gid, 任务=${task?.title}, 新状态=${task?.status}');
    return task;
  }

  /// 根据gid获取任务
  Future<List<GalleryImageTask>> getImageTasks(int gid) async {
    final List<GalleryImageTask> tasks =
        await isarHelper.findImageTaskAllByGidIsolate(gid);
    return tasks;
  }

  /// 移除任务
  Future<void> removeDownloadGalleryTask({
    required int gid,
    bool shouldDeleteContent = true,
  }) async {
    await _completionLockFor(gid).synchronized(() async {
      dState.incrementalProgressMap.remove(gid);
      // 清理该画廊的所有重试计数
      imageProcessor.clearGalleryReDownloadCounts(gid);

      await taskManager.removeDownloadGalleryTask(
        gid: gid,
        shouldDeleteContent: shouldDeleteContent,
      );
    });
  }

  Future<void> resetConcurrency() {
    return _concurrencyResetLock.synchronized(() async {
      loggerSimple.d('重置并发设置开始');

      // 记录当前正在运行的任务GID列表，用于后续恢复
      final List<int> runningTaskGids = dState.galleryTasks
          .where((task) => task.status == TaskStatus.running.value)
          .map((task) => task.gid)
          .toList();
      loggerSimple.d('当前运行中的任务: $runningTaskGids');

      // 重置UI状态，将所有运行中的任务临时标记为入队状态
      for (final gid in runningTaskGids) {
        if (dState.galleryTaskMap.containsKey(gid)) {
          GalleryTask? oldTask = dState.galleryTaskMap[gid];
          dState.galleryTaskMap[gid] =
              oldTask!.copyWith(status: TaskStatus.enqueued.value);
          _updateDownloadView(['DownloadGalleryItem_$gid']);
        }
      }

      // 取消所有网络请求
      for (final ct in dState.cancelTokenMap.values) {
        if (!ct.isCancelled) {
          ct.cancel();
        }
      }
      dState.cancelTokenMap.clear();

      // 取消所有计时器
      _cancelDownloadStateChkTimer();

      // 等待旧 executor 中的任务结束，再创建新的 executor，避免两套
      // 下载队列同时运行。
      loggerSimple.d('关闭旧的executor');
      final oldExecutor = dState.executor;
      try {
        await oldExecutor.close();
        loggerSimple.d('旧的executor已关闭');
      } catch (e) {
        loggerSimple.e('关闭executor出错: $e');
      }

      // 创建新的executor
      loggerSimple.d('创建新的executor，并发数: ${ehSettingService.multiDownload}');
      dState.executor = Executor(concurrency: ehSettingService.multiDownload);

      // 设置槽位管理器的并发数
      loggerSimple.d('设置槽位管理器的并发数: ${ehSettingService.concurrentGalleries}');
      await gallerySlotManager
          .setMaxConcurrentGalleries(ehSettingService.concurrentGalleries);

      // 清空当前槽位状态和队列
      gallerySlotManager.resetState();

      // 清除下载缓存信息，确保重新开始不受旧状态影响
      dState.curComplete.clear();
      dState.lastCounts.clear();
      dState.noSpeed.clear();
      dState.downloadSpeeds.clear();
      dState.preComplete.clear();
      dState.reDownloadCounts.clear(); // 清理所有重试计数

      // 保存数据库中的状态更改，并等待写入完成后再恢复任务。
      for (final gid in runningTaskGids) {
        if (dState.galleryTaskMap.containsKey(gid)) {
          await isarHelper.putGalleryTaskIsolate(dState.galleryTaskMap[gid]!);
        }
      }

      // 重新初始化所有任务
      loggerSimple.d('重新初始化所有任务');
      await initGalleryTasks();

      loggerSimple.d('重置并发设置完成');
    });
  }

  void _addAllImages(int gid, List<GalleryImage> galleryImages) {
    for (final GalleryImage image in galleryImages) {
      final int? index = dState.downloadMap[gid]
          ?.indexWhere((GalleryImage e) => e.ser == image.ser);
      if (index != null && index != -1) {
        dState.downloadMap[gid]?[index] = image;
      } else {
        dState.downloadMap[gid]?.add(image);
      }
    }
  }

  // 添加任务队列
  void _addGalleryTask(
    GalleryTask galleryTask, {
    int? groupCount,
    List<GalleryImage>? images,
  }) {
    if (dState.unavailableGalleryFiles.contains(galleryTask.gid)) {
      return;
    }
    logger.d('添加画廊任务: gid=${galleryTask.gid}, 标题=${galleryTask.title}');
    dState.taskCancelTokens[galleryTask.gid] = TaskCancelToken();
    final showKey = galleryTask.showKey;
    if (showKey != null) {
      _updateShowKey(galleryTask.gid, showKey);
    }

    // 使用槽位管理器添加任务，保存 groupCount 和 images 信息
    dState.galleryTaskExtraInfo[galleryTask.gid] = {
      'groupCount': groupCount,
      'images': images,
    };
    loggerSimple.d('将任务交给槽位管理器: gid=${galleryTask.gid}');
    gallerySlotManager.addGalleryTask(galleryTask);
    loggerSimple.d('槽位管理器处理完成: gid=${galleryTask.gid}');
  }

  // 启动画廊下载
  void _startGalleryDownload(GalleryTask galleryTask) {
    loggerSimple.d('槽位管理器请求启动画廊下载: gid=${galleryTask.gid}');
    final extraInfo = dState.galleryTaskExtraInfo[galleryTask.gid];
    final int? groupCount = extraInfo?['groupCount'] as int?;
    final List<GalleryImage>? images =
        extraInfo?['images'] as List<GalleryImage>?;

    loggerSimple.d(
        '准备添加任务到队列: gid=${galleryTask.gid}, fileCount=${galleryTask.fileCount}, groupCount=$groupCount}');
    dState.queueTask.add(
      ({name}) async {
        logger.d('队列执行任务: $name, gid=${galleryTask.gid}');
        try {
          await _startImageTask(
            galleryTask: galleryTask,
            groupCount: groupCount,
            images: images,
          );
        } on Object catch (error, stack) {
          await _markImageTaskError(galleryTask.gid, error, stack);
        }
        logger.d('_startImageTask执行完成: gid=${galleryTask.gid}');
      },
      taskCancelToken: dState.taskCancelTokens[galleryTask.gid],
      taskName: '${galleryTask.gid}',
    );
    logger.d('任务已添加到队列: gid=${galleryTask.gid}');
  }

  // 取消下载任务定时器
  void _cancelDownloadStateChkTimer([int? gid]) {
    downloadMonitor.cancelDownloadStateChkTimer(gid: gid);
  }

  Future<void> checkSafPath(
      {String? uri, bool saveDownloadPath = false}) async {
    await pathManager.checkSafPath(
        uri: uri, saveDownloadPath: saveDownloadPath);
  }

  /// 获取下载路径
  Future<String> _getGalleryDownloadPath({String dirName = ''}) async {
    return pathManager.getGalleryDownloadPath(dirName: dirName);
  }

  GalleryImage? _getImageObj(int gid, int ser) {
    logger.d('获取图片对象: gid=$gid, ser=$ser');
    logger.t(
        'downloadMap: ${dState.downloadMap[gid]?.map((e) => e.ser).join(',')}');
    return dState.downloadMap[gid]
        ?.firstWhereOrNull((element) => element.ser == ser);
  }

  int _initDownloadMapByGid(int gid, {List<GalleryImage>? images}) {
    dState.downloadMap[gid] = images ?? [];
    return dState.downloadMap[gid]?.length ?? 0;
  }

  // 根据gid初始化下载任务计时器
  void _initDownloadStateChkTimer(int gid) {
    logger.d('初始化下载计时器: gid=$gid');

    // 直接提供回调函数，取代download_monitor内部默认实现
    // 这样可以避免重复调用checkDownloadStall和updateDownloadSpeed
    downloadMonitor.initDownloadStateChkTimer(
      gid,
      onTimerCallback: (int gid, Timer timer) {
        final task = dState.galleryTaskMap[gid];
        if (task != null && task.fileCount == task.completCount) {
          unawaited(galleryTaskComplete(gid));
          return;
        }

        if (dState.galleryTaskMap[gid]?.status == TaskStatus.running.value) {
          // 更新下载速度显示
          downloadMonitor.updateDownloadSpeed(
            gid,
            maxCount: dm.kMaxCount,
            periodSeconds: dm.kPeriodSeconds,
          );

          // 检查下载停滞状态
          downloadMonitor.checkDownloadStall(
            gid,
            checkMaxCount: dm.kCheckMaxCount,
            periodSeconds: dm.kPeriodSeconds,
            onRetryNeededCallback: (int gid) {
              logger.d('检测到下载停滞，正在重试 gid:$gid, 时间:${DateTime.now()}');

              // 执行重试
              Future<void>(() => galleryTaskPaused(gid, silent: true))
                  .then(
                      (_) => Future.delayed(const Duration(microseconds: 1000)))
                  .then((_) => galleryTaskResume(gid));
            },
          );

          // 更新UI
          _updateDownloadView(['DownloadGalleryItem_$gid']);
        }
      },
    );
  }

  // 初始化任务列表
  Future<void> initGalleryTasks() async {
    loggerSimple.d('开始初始化任务列表');

    await taskManager.initGalleryTasks(
      addGalleryTaskCallback: _addGalleryTask,
      downloadTaskMigrationCallback: downloadTaskMigration,
      onTaskReconciledCallback: _onTaskReconciled,
    );

    // 额外处理：找出所有应该继续的任务（已入队或运行中）
    final List<GalleryTask> tasksToResume = dState.galleryTasks
        .where((task) =>
            !dState.unavailableGalleryFiles.contains(task.gid) &&
            (task.status == TaskStatus.enqueued.value ||
                task.status == TaskStatus.running.value))
        .toList();

    loggerSimple.d('找到需要继续的任务: ${tasksToResume.length}个');

    // 确保槽位管理器有这些任务的记录
    for (final task in tasksToResume) {
      loggerSimple.d('检查任务: gid=${task.gid}, 状态=${task.status}');
      if (!gallerySlotManager.isGalleryActive(task.gid) &&
          !gallerySlotManager.isGalleryWaiting(task.gid)) {
        loggerSimple.d('重新添加任务到槽位管理器: gid=${task.gid}');
        _addGalleryTask(task);
      } else {
        loggerSimple.d('任务已在槽位管理器中: gid=${task.gid}');
      }
    }

    loggerSimple.d('任务初始化完成');
  }

  Future<void> downloadTaskMigration() async {
    final isMigrationed = hiveHelper.getDownloadTaskMigration();
    logger.t('downloadTaskMigration $isMigrationed');
    if (!isMigrationed) {
      logger.d('start download task Migration');
      await restoreGalleryTasks();
      await hiveHelper.setDownloadTaskMigration(true);
    }
  }

  Future<void> restoreGalleryTasks({bool init = false}) async {
    await _reconcilePendingIncrementalUpdates();
    await taskManager.restoreGalleryTasks(
      init: init,
      getDownloadPathCallback: _getGalleryDownloadPath,
      restoreTasksWithPathCallback: restoreGalleryTasksWithPath,
      restoreTasksWithSAFCallback: restoreGalleryTasksWithSAF,
      onInitCallback: asyncInit,
      resetDownloadViewAnimationKeyCallback: resetDownloadViewAnimationKey,
    );
    _refreshDownloadGalleryList();
  }

  Future<void> restoreGalleryTasksWithSAF(String currentDownloadPath) async {
    await storageAdapter.restoreGalleryTasksWithSAF(
      currentDownloadPath,
      _loadInfoFile,
    );
  }

  // 从当前下载目录恢复下载列表数据
  Future<void> restoreGalleryTasksWithPath(String currentDownloadPath) async {
    final skipDirs = await _transferGateLock.synchronized(
      () => Set<String>.from(_unretiredOldDirs),
    );
    await storageAdapter.restoreGalleryTasksWithPath(
      currentDownloadPath,
      _loadInfoFile,
      skipDirs: skipDirs,
    );
  }

  Future<void> _loadInfoFile(File infoFile, String dirPath) async {
    // Hold `_transferGateLock` across reservation + unretired-dir checks and
    // DB import so restore cannot race with active or failed-retirement tasks.
    final resolvedDir = await _resolveRealDirKey(dirPath);
    final canonicalDir = dirPath.isContentUri ? dirPath : path.canonicalize(dirPath);
    await _transferGateLock.synchronized(() async {
      if (_unretiredOldDirs.contains(resolvedDir) ||
          _unretiredOldDirs.contains(canonicalDir)) {
        return;
      }
      if (!dirPath.isContentUri &&
          File(path.join(dirPath, kIncrementalRetiringTombstoneFileName))
              .existsSync()) {
        return;
      }
      try {
        final firstLine = infoFile
            .readAsLinesSync()
            .firstWhere((line) => line.trim().isNotEmpty, orElse: () => '');
        if (firstLine.isNotEmpty) {
          final decoded = jsonDecode(firstLine) as Map<String, dynamic>;
          final gid = decoded['gid'] as int?;
          if (gid != null && _reservedGids.contains(gid)) {
            return;
          }
        }
      } catch (_) {}
      await storageAdapter.loadInfoFile(infoFile, dirPath);
    });
  }

  Future<void> rebuildGalleryTasks() async {
    final tasks = await isarHelper.findAllGalleryTasksIsolate();

    for (final originalTask in tasks) {
      await taskManager.reconcileGalleryTask(
        originalTask,
        writeInfoFile: true,
      );
    }
    _refreshDownloadGalleryList();
  }

  void _refreshDownloadGalleryList() {
    if (Get.isRegistered<DownloadViewController>()) {
      Get.find<DownloadViewController>().refreshGalleryList();
    }
  }

  void _onTaskReconciled(GalleryTask task) {
    _updateDownloadView(['DownloadGalleryItem_${task.gid}']);
  }

  void _updateShowKey(
    int gid,
    String showKey, {
    bool updateDB = false,
  }) {
    logger.t('update showKey $gid $showKey');
    dState.showKeyMap[gid] = showKey;
    if (!(dState.showKeyCompleteMap[gid]?.isCompleted ?? false)) {
      dState.showKeyCompleteMap[gid]?.complete(true);
    }
    if (updateDB) {
      // 如果直接操作数据库更新，不更新 map 数据，会导致后续状态更新时，直接将 map 中的 task 写入数据库，导致 showKey 丢失
      // 所以这里需要更新 map 数据 ， 数据库的更新由后续状态更新时，自动更新
      // TODO(3003n): 优化状态更新时，任务表的更新逻辑
      final task = dState.galleryTaskMap[gid];
      if (task != null) {
        dState.galleryTaskMap[gid] = task.copyWith(showKey: showKey);
      }
    }
  }

  /// 开始下载
  Future<void> _startImageTask({
    required GalleryTask galleryTask,
    int? groupCount,
    List<GalleryImage>? images,
  }) async {
    galleryTask = await taskManager.reconcileGalleryTask(galleryTask);
    _onTaskReconciled(galleryTask);
    if (dState.unavailableGalleryFiles.contains(galleryTask.gid) ||
        _shouldStopImageTask(galleryTask.gid)) {
      await gallerySlotManager.onGalleryStatusChanged(
        galleryTask.gid,
        galleryTask.status == TaskStatus.complete.value
            ? TaskStatus.complete
            : TaskStatus.paused,
      );
      return;
    }
    logger.d(
        '开始下载任务: gid=${galleryTask.gid}, 标题=${galleryTask.title}, 状态=${galleryTask.status}');

    // 初始化下载计时控制
    // logger.d('初始化下载计时器: gid=${galleryTask.gid}');
    _initDownloadStateChkTimer(galleryTask.gid);

    final List<GalleryImageTask> imageTasksOri =
        await isarHelper.findImageTaskAllByGidIsolate(galleryTask.gid);
    logger.d('获取已有图片任务: gid=${galleryTask.gid}, 任务数=${imageTasksOri.length}');

    final completeCount = imageTasksOri
        .where((element) => element.status == TaskStatus.complete.value)
        .length;
    logger.d(
        '已完成图片数: gid=${galleryTask.gid}, 完成数=$completeCount/${imageTasksOri.length}');

    final progressTask = await galleryTaskUpdate(
      galleryTask.gid,
      countComplete: completeCount,
    );
    if (progressTask == null) {
      return;
    }

    if (completeCount >= galleryTask.fileCount &&
        imageTasksOri.length >= galleryTask.fileCount &&
        galleryTask.fileCount > 0) {
      logger.d(
          '任务已完成: gid=${galleryTask.gid}, 完成数=$completeCount/${galleryTask.fileCount}');
      await galleryTaskComplete(galleryTask.gid);
      _updateDownloadView(['DownloadGalleryItem_${galleryTask.gid}']);
      return;
    }

    // 初始化下载Map
    final initCount = _initDownloadMapByGid(galleryTask.gid, images: images);
    logger.d('初始化下载Map: gid=${galleryTask.gid}, 初始数量=$initCount');

    final putCount = await _updateImageTasksByGid(galleryTask.gid);
    logger.d('更新图片任务到数据库: gid=${galleryTask.gid}, 更新数量=$putCount');

    if (_shouldStopImageTask(galleryTask.gid)) {
      logger.d('下载任务在启动前已取消或进入终态: gid=${galleryTask.gid}');
      return;
    }

    logger.d('更新任务状态为running: gid=${galleryTask.gid}');
    await galleryTaskUpdateStatus(galleryTask.gid, TaskStatus.running);

    final CancelToken cancelToken = CancelToken();
    if (_shouldStopImageTask(galleryTask.gid, cancelToken)) {
      logger.d('下载任务在切换running时已取消: gid=${galleryTask.gid}');
      cancelToken.cancel();
      return;
    }
    dState.cancelTokenMap[galleryTask.gid] = cancelToken;
    _updateDownloadView(['DownloadGalleryItem_${galleryTask.gid}']);

    _clearErrInfo(galleryTask.gid, updateView: false);

    final realDirPath = galleryTask.realDirPath;
    if (realDirPath == null) {
      logger.e('下载路径为空: gid=${galleryTask.gid}');
      await _markImageTaskError(
        galleryTask.gid,
        StateError('Download path is empty'),
        StackTrace.current,
      );
      return;
    }

    final String downloadParentPath = realDirPath;
    logger.d('下载父目录: gid=${galleryTask.gid}, path=$downloadParentPath');

    final List<int> completeSerList = imageTasksOri
        .where((element) => element.status == TaskStatus.complete.value)
        .map((e) => e.ser)
        .toList();

    final int maxCompleteSer =
        completeSerList.isNotEmpty ? completeSerList.reduce(max) : 0;
    logger.d('最大已完成序号: gid=${galleryTask.gid}, maxCompleteSer=$maxCompleteSer');

    // 循环进行下载图片
    logger.d('开始循环下载: gid=${galleryTask.gid}, 文件总数=${galleryTask.fileCount}');
    for (int index = 0; index < galleryTask.fileCount; index++) {
      if (_shouldStopImageTask(galleryTask.gid, cancelToken)) {
        logger.d('下载任务已取消或进入终态，停止继续入队: gid=${galleryTask.gid}');
        break;
      }

      final itemSer = index + 1;

      final oriImageTask =
          imageTasksOri.firstWhereOrNull((element) => element.ser == itemSer);
      if (oriImageTask?.status == TaskStatus.complete.value) {
        logger.t('图片已完成，跳过: gid=${galleryTask.gid}, ser=$itemSer');
        continue;
      }

      logger.t(
          '准备下载图片: gid=${galleryTask.gid}, ser=$itemSer/${galleryTask.fileCount}');

      if (groupCount == null || groupCount < 1) {
        logger.d('获取首页图片数量: gid=${galleryTask.gid}, url=${galleryTask.url}');
        groupCount = await imageProcessor.fetchFirstPageCount(
          galleryTask.url!,
          cancelToken: cancelToken,
        );
        logger.d('获取首页图片数量结果: gid=${galleryTask.gid}, fileCount=$groupCount');
      }

      final showKey = dState.showKeyMap[galleryTask.gid];

      if (index > 0 && showKey == null) {
        // 没有 showKey 时，fetchImageInfoByApi 会自动回退到 HTML 解析。
        // 这里不能等待前一张图片成功后才继续，否则前一张图片失败时
        // Completer 永远不会完成，并会卡住整个串行画廊队列。
        logger
            .d('showKey暂不可用，直接使用HTML解析: gid=${galleryTask.gid}, index=$index');
      }

      final imageFuture = dState.executor.scheduleTask<void>(() async {
        logger.d('开始处理图片任务: gid=${galleryTask.gid}, ser=$itemSer');
        final GalleryImage? preImage =
            await imageProcessor.checkAndGetImageList(
          galleryTask.gid,
          itemSer,
          galleryTask.fileCount,
          groupCount!,
          galleryTask.url,
          cancelToken: cancelToken,
          addAllImagesCallback: _addAllImages,
          getImageObjCallback: _getImageObj,
        );

        if (preImage != null) {
          logger.t(
              '获取到图片信息: gid=${galleryTask.gid}, ser=$itemSer, imageUrl=${preImage.imageUrl}');
          final int maxSer = galleryTask.fileCount + 1;

          logger.t('开始下载图片: gid=${galleryTask.gid}, ser=$itemSer');
          await imageProcessor.downloadImageFlow(
            preImage,
            oriImageTask,
            galleryTask.gid,
            downloadParentPath,
            maxSer,
            showKey: dState.showKeyMap[galleryTask.gid],
            downloadOrigImage: galleryTask.downloadOrigImage ?? false,
            cancelToken: cancelToken,
            reDownload: itemSer > 1 && itemSer < maxCompleteSer + 2,
            onDownloadCompleteWithFileName: (String fileName) =>
                _onDownloadComplete(
              fileName,
              galleryTask.gid,
              itemSer,
            ),
            putImageTaskCallback: _putImageTask,
          );
          logger.t('下载图片完成: gid=${galleryTask.gid}, ser=$itemSer');
        } else {
          throw StateError(
              'Unable to obtain image information for $galleryTask.gid.$itemSer');
        }
      });
      unawaited(imageFuture.catchError((Object error, StackTrace stack) async {
        await _handleImageTaskError(
          galleryTask.gid,
          itemSer,
          error,
          stack,
          taskCancelToken: cancelToken,
        );
      }));
    }
    logger.d('所有图片任务已加入队列: gid=${galleryTask.gid}');
  }

  bool _shouldStopImageTask(int gid, [CancelToken? cancelToken]) {
    if ((cancelToken?.isCancelled ?? false) ||
        dState.taskCancelTokens[gid]?.isCancelled == true) {
      return true;
    }

    final status = dState.galleryTaskMap[gid]?.status;
    return status == TaskStatus.paused.value ||
        status == TaskStatus.failed.value ||
        status == TaskStatus.canceled.value ||
        status == TaskStatus.complete.value;
  }

  Future<void> _markImageTaskError(
    int gid,
    Object error,
    StackTrace stack,
  ) async {
    await _handleImageTaskError(gid, 0, error, stack);
  }

  Future<void> _handleImageTaskError(
    int gid,
    int itemSer,
    Object error,
    StackTrace stack, {
    CancelToken? taskCancelToken,
  }) async {
    await _completionLockFor(gid).synchronized(() async {
      await _handleImageTaskErrorLocked(
        gid,
        itemSer,
        error,
        stack,
        taskCancelToken: taskCancelToken,
      );
    });
  }

  Future<void> _handleImageTaskErrorLocked(
    int gid,
    int itemSer,
    Object error,
    StackTrace stack, {
    CancelToken? taskCancelToken,
  }) async {
    // Ignore a worker that belongs to a cancelled or replaced attempt.
    final currentToken = dState.cancelTokenMap[gid];
    if (taskCancelToken != null &&
        (!identical(currentToken, taskCancelToken) ||
            taskCancelToken.isCancelled)) {
      return;
    }
    if (error is DioException && CancelToken.isCancel(error)) {
      return;
    }

    final currentTask = dState.galleryTaskMap[gid];
    if (currentTask?.status == TaskStatus.complete.value ||
        currentTask?.status == TaskStatus.paused.value ||
        currentTask?.status == TaskStatus.failed.value) {
      return;
    }

    logger.e(
      '下载图片失败: gid=$gid, ser=$itemSer, error=$error',
      error: error,
      stackTrace: stack,
    );

    final dioStatusCode =
        error is DioException ? error.response?.statusCode : null;
    final is509 = error is EhError && error.type == EhErrorType.image509;
    if (is509 || dioStatusCode == 509) {
      show509Toast();
      await _galleryTaskPausedAll();
      _updateErrInfo(gid, '509');
      return;
    }

    final is429 = error is HttpException && error.code == 429;
    if (is429 || dioStatusCode == 429) {
      show429Toast();
      await _galleryTaskPausedAll();
      _updateErrInfo(gid, '429');
      return;
    }

    await taskManager.cancelGalleryWork(
      gid,
      cancelTimerCallback: _cancelDownloadStateChkTimer,
    );
    final task = await galleryTaskUpdateStatus(gid, TaskStatus.failed);
    if (task?.status == TaskStatus.failed.value) {
      _updateErrInfo(gid, _formatDownloadError(error));
      await gallerySlotManager.onGalleryStatusChanged(gid, TaskStatus.failed);
    }
  }

  String _formatDownloadError(Object error) {
    if (error is HttpException) {
      return error.code > 0 ? '${error.code}: ${error.message}' : error.message;
    }
    if (error is DioException) {
      return error.message ?? error.type.toString();
    }
    return error.toString();
  }

  void _updateErrInfo(int gid, String error) {
    dState.errInfoMap[gid] = error;
    _updateDownloadView(['DownloadGalleryItem_$gid']);
  }

  void _clearErrInfo(int gid, {bool updateView = true}) {
    dState.errInfoMap.remove(gid);
    if (updateView) {
      _updateDownloadView(['DownloadGalleryItem_$gid']);
    }
  }

  // 下载完成回调
  Future<void> _onDownloadComplete(
      String fileName, int gid, int itemSer) async {
    await _completionLockFor(gid).synchronized(() async {
      loggerSimple.d('画廊项目下载完成: gid=$gid, 序号=$itemSer, 文件=$fileName');

      // 下载完成 更新数据库明细
      final List<GalleryImageTask> listComplete = kDebugMode
          ? await isarHelper.onDownloadComplete(
              gid,
              itemSer,
              TaskStatus.complete.value,
            )
          : await isarHelper.onDownloadCompleteIsolate(
              gid,
              itemSer,
              TaskStatus.complete.value,
            );

      loggerSimple.d('已完成图片: gid=$gid, 数量=${listComplete.length}');
      loggerSimple.d(
          '序号列表=${listComplete.map((e) => e.ser).sorted((a, b) => a.compareTo(b)).join(',')}');

      final coverImg = listComplete
          .firstWhereOrNull((element) => element.ser == 1)
          ?.filePath;
      loggerSimple.t('封面图片: gid=$gid, 路径=$coverImg');

      final GalleryTask? task = await galleryTaskUpdate(
        gid,
        countComplete: listComplete.length,
        coverImg: coverImg,
        completeWhenReached: true,
      );

      if (task != null) {
        loggerSimple.t(
            '检查画廊是否完成: gid=$gid, 已完成=${listComplete.length}/${task.fileCount}');

        if (task.status == TaskStatus.complete.value) {
          loggerSimple.d(
              '画廊任务全部完成: gid=$gid, ${listComplete.length}/${task.fileCount}');
          await _completeGalleryTask(gid);
        } else {
          loggerSimple.d(
              '画廊任务部分完成: gid=$gid, ${listComplete.length}/${task.fileCount}');
        }
      } else {
        logger.e('无法更新画廊任务: gid=$gid, 任务不存在');
      }

      _updateDownloadView(['DownloadGalleryItem_$gid']);
    });
  }

  void _updateDownloadView([List<Object>? ids]) {
    if (Get.isRegistered<DownloadViewController>()) {
      Get.find<DownloadViewController>().update(ids);
    }
  }

  void resetDownloadViewAnimationKey() {
    if (Get.isRegistered<DownloadViewController>()) {
      Get.find<DownloadViewController>().animatedGalleryListKey =
          GlobalKey<AnimatedListState>();
    }
  }

  Future<void> _putImageTask(
    int gid,
    GalleryImage image,
    String? fileName,
    int? status,
  ) async {
    // final GalleryImageTask? oriImageTask =
    //     await isarHelper.findImageTaskAllByGidSerIsolate(gid, image.ser);
    final GalleryImageTask? oriImageTask =
        await isarHelper.findImageTaskAllByGidSer(gid, image.ser);

    final GalleryImageTask newImageTask = GalleryImageTask(
      gid: gid,
      token: image.token ?? '',
      href: image.href,
      ser: image.ser,
      imageUrl: image.imageUrl,
      sourceId: image.sourceId,
      filePath: fileName,
      status: status,
    );

    final GalleryImageTask imageTask = oriImageTask?.copyWith(
          token: image.token ?? '',
          href: image.href,
          imageUrl: image.imageUrl,
          sourceId: image.sourceId,
          filePath: fileName ?? oriImageTask.filePath,
          status: status,
        ) ??
        newImageTask;

    logger.t(
        'putImageTask => statue:${imageTask.status} name:${imageTask.filePath}');

    if (kDebugMode) {
      await isarHelper.putImageTask(imageTask);
    } else {
      await isarHelper.putImageTaskIsolate(imageTask);
    }
  }

  Future<int> _updateImageTasksByGid(int gid,
      {List<GalleryImage>? images}) async {
    // 插入所有任务明细
    final sourceImages = images ?? dState.downloadMap[gid];
    final existingTasks = await isarHelper.findImageTaskAllByGidIsolate(gid);
    final existingBySer = <int, GalleryImageTask>{
      for (final task in existingTasks) task.ser: task,
    };
    final List<GalleryImageTask>? galleryImageTasks =
        sourceImages?.map((GalleryImage e) {
      final existing = existingBySer[e.ser];
      return GalleryImageTask(
        gid: gid,
        token: existing?.token ?? e.token ?? '',
        href: e.href ?? existing?.href,
        ser: e.ser,
        imageUrl: e.imageUrl ?? existing?.imageUrl,
        sourceId: e.sourceId ?? existing?.sourceId,
        filePath: existing?.filePath,
        status: existing?.status,
      );
    }).toList();

    if (galleryImageTasks != null) {
      logger.d('插入所有任务明细 $gid ${galleryImageTasks.length}');
      await isarHelper.putAllImageTaskIsolate(galleryImageTasks);
    }

    return galleryImageTasks?.length ?? 0;
  }

  // 暂停所有任务
  Future<void> _galleryTaskPausedAll() async {
    final futures = <Future<void>>[];
    for (final task in dState.galleryTasks) {
      if (task.status != TaskStatus.complete.value) {
        futures.add(galleryTaskPaused(task.gid).then<void>((_) {}));
        _updateDownloadView(['DownloadGalleryItem_${task.gid}']);
      }
    }
    await Future.wait(futures);
  }

  /// 设置同时下载的画廊数
  void setConcurrentGalleries(int count) {
    logger
        .d('请求设置同时下载画廊数: $count, 当前值: ${ehSettingService.concurrentGalleries}');

    if (count > 0 && count <= 5) {
      final int oldValue = ehSettingService.concurrentGalleries;
      ehSettingService.concurrentGalleries = count;
      logger.d('设置同时下载画廊数成功: $oldValue -> $count');

      logger.d('更新槽位管理器最大并发数: $count');
      gallerySlotManager.setMaxConcurrentGalleries(count);
      logger.d(
          '槽位管理器更新完成, 当前活动画廊: ${gallerySlotManager.activeGalleriesCount}, 等待数: ${gallerySlotManager.waitingCount}');
    } else {
      logger.e('设置同时下载画廊数失败: 值超出范围(1-5): $count');
    }
  }

  /// 设置最大下载图片线程数
  Future<void> setMultiDownload(int count) async {
    loggerSimple
        .d('请求设置最大下载图片线程数: $count, 当前值: ${ehSettingService.multiDownload}');

    if (count > 0 && count <= 32) {
      final int oldValue = ehSettingService.multiDownload;
      ehSettingService.multiDownload = count;
      loggerSimple.d('设置最大下载图片线程数成功: $oldValue -> $count');

      // 重置并发设置，应用新的线程数
      await resetConcurrency();
    } else {
      logger.e('设置最大下载图片线程数失败: 值超出范围(1-32): $count');
    }
  }
}
