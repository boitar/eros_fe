import 'dart:async';
import 'dart:convert';

import 'package:eros_fe/common/controller/mysql_controller.dart';
import 'package:eros_fe/common/controller/webdav_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/tab/controller/history_view_controller.dart';
import 'package:eros_fe/pages/tab/view/list/tab_base.dart';
import 'package:eros_fe/store/db/isar_helper.dart';
import 'package:eros_fe/store/hive/hive.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:throttling/throttling.dart';

class HistoryController extends GetxController {
  HistoryController({IsarHelper? historyStorage, HiveHelper? legacyStorage})
      : _historyStorage = historyStorage ?? isarHelper,
        _legacyStorage = legacyStorage ?? hiveHelper;

  final IsarHelper _historyStorage;
  final HiveHelper _legacyStorage;
  final List<GalleryProvider> _histories = <GalleryProvider>[];
  Future<void>? _initHistoriesFuture;
  bool _historiesInitialized = false;
  Future<void> _pendingWrites = Future<void>.value();

  Future<void> _enqueueHistoryMutation(Future<void> Function() action) {
    final future = _pendingWrites.then((_) async {
      await initHistories();
      await action();
    });
    // Keep later operations usable after a failed write; callers still receive
    // the original failure through the returned future.
    _pendingWrites =
        future.then<void>((_) {}, onError: (Object error, StackTrace stack) {});
    return future;
  }

  List<GalleryProvider> get histories {
    _histories
        .sort((a, b) => (b.lastViewTime ?? 0).compareTo(a.lastViewTime ?? 0));
    return _histories;
  }

  bool get historiesInitialized => _historiesInitialized;

  // 登记删除gid和删除时间，用于同步远程时筛选
  final List<HistoryIndexGid> _delHistories = <HistoryIndexGid>[];

  final EhSettingService _ehSettingService = Get.find();
  final WebdavController webdavController = Get.find();
  final MysqlController mysqlController = Get.find();

  final thrSync = Throttling(duration: const Duration(seconds: 60));
  final debSync = Debouncing(duration: const Duration(seconds: 80));

  bool get isListView =>
      _ehSettingService.listMode.value == ListModeEnum.list ||
      _ehSettingService.listMode.value == ListModeEnum.simpleList;

  Future<void> addHistory(
    GalleryProvider galleryProvider, {
    bool updateTime = true,
    bool sync = true,
  }) =>
      _enqueueHistoryMutation(() async {
        final hisViewController = Get.find<HistoryViewController>();

        final int nowTime = DateTime.now().millisecondsSinceEpoch;
        final item = galleryProvider.copyWith(
          lastViewTime: updateTime ? nowTime.oN : null,
          galleryImages: <GalleryImage>[].oN,
          galleryComment: <GalleryComment>[].oN,
        );

        final eDelFlg = _delHistories
            .firstWhereOrNull((eDel) => eDel.g == galleryProvider.gid);
        if (nowTime > (eDelFlg?.t ?? 0)) {
          await _removeHistoryDelFlg(galleryProvider.gid ?? '');
        }

        final int curIndex = histories.indexWhere((element) {
          return element.gid == item.gid;
        });

        if (curIndex >= 0) {
          histories.removeAt(curIndex);
          if (curIndex > 0 && isListView) {
            // removeItem 动画
            hisViewController.sliverAnimatedListKey.currentState?.removeItem(
                curIndex,
                (context, Animation<double> animation) =>
                    buildDelGallerySliverListItem(item, curIndex, animation));
          }

          _histories.add(item);
          if (curIndex > 0 && isListView) {
            // insertItem 动画
            hisViewController.sliverAnimatedListKey.currentState?.insertItem(0);
          }

          await _historyStorage.addHistoryAsync(item);
        } else {
          _histories.add(item);
          final insertIndex = histories.indexOf(item);
          if (isListView) {
            hisViewController.sliverAnimatedListKey.currentState
                ?.insertItem(insertIndex);
          }

          await _historyStorage.addHistoryAsync(item);
        }

        logger.t('add ${galleryProvider.gid} update1');
        update();

        if (sync) {
          // 节流函数 最多每分钟一次同步
          thrSync.throttle(() {
            logger.t('throttle syncHistory');
            return syncHistory();
          });

          debSync.debounce(syncHistory);
        }
      });

  Future<void> removeHistory(String gid, {bool sync = true}) =>
      _enqueueHistoryMutation(() async {
        final hisViewController = Get.find<HistoryViewController>();

        final index = histories.indexWhere((element) => element.gid == gid);
        if (index < 0) {
          return;
        }
        final item = histories[index];
        histories.removeAt(index);
        if (isListView) {
          hisViewController.sliverAnimatedListKey.currentState?.removeItem(
              index,
              (context, Animation<double> animation) =>
                  buildDelGallerySliverListItem(item, index, animation));
          update();
        } else {
          update();
        }

        await _historyStorage.removeHistory(gid);
        await _addHistoryDelFlg(gid);

        if (sync) {
          // 节流函数 最多每分钟一次同步
          thrSync.throttle(() {
            logger.t('throttle syncHistory');
            return syncHistory();
          });

          debSync.debounce(syncHistory);
        }
      });

  Future<void> _addHistoryDelFlg(String gid) async {
    final int nowTime = DateTime.now().millisecondsSinceEpoch;
    final del = HistoryIndexGid(t: nowTime, g: gid);
    _delHistories.add(del);
    await _legacyStorage.addHistoryDel(del);
  }

  Future<void> _removeHistoryDelFlg(String gid) async {
    _delHistories.removeWhere((element) => element.g == gid);
    await _legacyStorage.removeHistoryDel(gid);
  }

  Future<void> cleanHistory() => _enqueueHistoryMutation(() async {
        histories.clear();
        update();
        await _historyStorage.cleanHistory();
      });

  @override
  void onInit() {
    super.onInit();

    // _histories.addAll(_legacyStorage.getAllHistory());
    // _delHistories.addAll(_legacyStorage.getAllHistoryDel());
    unawaited(initHistories());
  }

  Future<void> initHistories() {
    return _initHistoriesFuture ??= _loadHistories();
  }

  Future<void> _loadHistories() async {
    // 历史迁移
    await historyMigration();
    final loadedHistories = await _historyStorage.getAllHistory();
    _histories
      ..clear()
      ..addAll(loadedHistories);
    _delHistories
      ..clear()
      ..addAll(_legacyStorage.getAllHistoryDel());
    _historiesInitialized = true;
    update();
  }

  Future<void> reloadHistories() => _enqueueHistoryMutation(() async {
        final future = _loadHistories();
        _initHistoriesFuture = future;
        await future;
      });

  Future<void> historyMigration() async {
    final isMigration = _legacyStorage.getViewHistoryMigration();
    logger.t('historyMigration $isMigration');
    if (!isMigration) {
      logger.d('start history Migration');
      await _historyStorage.addHistoriesAsync(_legacyStorage.getAllHistory());
      await _legacyStorage.setViewHistoryMigration(true);
    }
  }

  // Future<void> removeRemoteHistory(String gid) async {
  //   // 发送云端标记该画廊为删除 不直接删除云端信息
  //   webdavController.updateRemoveFlg(gid);
  // }

  /// 同步历史记录
  Future<void> syncHistory() async {
    await initHistories();
    await _pendingWrites;
    final List<HistoryIndexGid?> listLocal = histories
        .map((e) => HistoryIndexGid(t: e.lastViewTime, g: e.gid))
        .toList();
    logger.t('listLocal ${listLocal.length} \n${listLocal.map((e) => e?.g)}');
    logger.t('${jsonEncode(listLocal)} ');

    await Future.wait<void>([
      syncHistoryMySQL(listLocal),
      syncHistoryWebDAV(listLocal),
    ]);
  }

  /// 通过mysql同步历史记录
  Future<void> syncHistoryMySQL(List<HistoryIndexGid?> listLocal) async {
    await _syncHistoryCallback(
      enable: mysqlController.syncHistory,
      listLocal: listLocal,
      getRemoteList: mysqlController.getHistoryList,
      uploadLocalHistories: _uploadHistoriesMySQL,
      downloadRemoteHistories: _downloadHistoriesMySQL,
    );
  }

  /// 通过webdav同步历史记录
  Future<void> syncHistoryWebDAV(List<HistoryIndexGid?> listLocal) async {
    await _syncHistoryCallback(
      enable: webdavController.syncHistory,
      listLocal: listLocal,
      getRemoteList: webdavController.getRemoteHistoryList,
      uploadLocalHistories: _uploadHistoriesWebDAV,
      downloadRemoteHistories: _downloadHistoriesWebDAV,
    );
  }

  Future<void> _downloadHistoriesMySQL(List<HistoryIndexGid> hisList) async {
    final list = await mysqlController
        .downloadHistoryList(hisList.map((e) => e.g).toList());
    for (final image in list) {
      if (image != null) {
        final ori =
            histories.firstWhereOrNull((element) => element.gid == image.gid);
        if (ori != null &&
            (image.lastViewTime ?? 0) <= (ori.lastViewTime ?? 0)) {
          continue;
        }
        await addHistory(image, updateTime: false, sync: false);
      }
    }
  }

  Future<void> _uploadHistoriesMySQL(
    List<HistoryIndexGid?> localHisList, {
    List<HistoryIndexGid?>? listRemote,
  }) async {
    for (final his in localHisList) {
      logger.d('his ${his?.g}');
      final GalleryProvider? hisProvider =
          histories.firstWhereOrNull((element) => element.gid == his?.g);

      if (hisProvider != null) {
        await mysqlController.uploadHistory(hisProvider);
      }
    }
  }

  Future<void> _downloadHistoriesWebDAV(List<HistoryIndexGid> hisList) async {
    webdavController.initExecutor();
    for (final gid in hisList) {
      webdavController.webDAVExecutor.scheduleTask(() async {
        if (gid.g != null) {
          final image =
              await webdavController.downloadHistory('${gid.g!}_${gid.t}');
          if (image != null) {
            final ori = histories
                .firstWhereOrNull((element) => element.gid == image.gid);
            if (ori != null && (gid.t ?? 0) <= (ori.lastViewTime ?? 0)) {
              return;
            }
            await addHistory(image, updateTime: false, sync: false);
          }
        }
      });
    }

    await webdavController.webDAVExecutor.join(withWaiting: true);
  }

  Future<void> _uploadHistoriesWebDAV(
    List<HistoryIndexGid?> localHisList, {
    List<HistoryIndexGid?>? listRemote,
  }) async {
    webdavController.initExecutor();
    for (final his in localHisList) {
      webdavController.webDAVExecutor.scheduleTask(() async {
        final GalleryProvider? _his =
            histories.firstWhereOrNull((element) => element.gid == his?.g);

        final oriRemote =
            listRemote?.firstWhereOrNull((element) => element?.g == his?.g);

        if (_his != null) {
          final upload = webdavController.uploadHistory(_his);
          final delete = webdavController.deleteHistory(oriRemote);
          await Future.wait([upload, delete]);
        }
      });
    }
    await webdavController.webDAVExecutor.join(withWaiting: true);
  }

  Future<void> _syncHistoryCallback({
    bool enable = false,
    required List<HistoryIndexGid?> listLocal,
    required Future<List<HistoryIndexGid>> Function() getRemoteList,
    required Future<void> Function(
      List<HistoryIndexGid?>, {
      List<HistoryIndexGid?>? listRemote,
    }) uploadLocalHistories,
    required Future<void> Function(List<HistoryIndexGid>)
        downloadRemoteHistories,
  }) async {
    logger.t('syncHistoryCallback');
    if (!enable) {
      return;
    }

    // 下载远程列表
    final listRemote = await getRemoteList();
    if (listRemote.isEmpty) {
      await uploadLocalHistories(listLocal);
      return;
    }

    logger.t('listRemote ${listRemote.length}');

    // 比较远程和本地的差异
    // final combinedList = <HistoryIndexGid?>{...listRemote, ...listLocal};
    // final diff = combinedList
    //     .where((element) =>
    //         !listRemote.contains(element) || !listLocal.contains(element))
    //     .toList()
    //     .toSet();

    // 本地时间更大的画廊
    final localNewer = listLocal.where(
      (eLocal) {
        if (eLocal == null) {
          return false;
        }
        final eRemote =
            listRemote.firstWhereOrNull((eRemote) => eRemote.g == eLocal.g);
        if (eRemote == null) {
          return true;
        }

        return (eLocal.t ?? 0) > (eRemote.t ?? 0);
      },
    );

    // 远程时间更大的画廊
    final remoteNewer = listRemote.where(
      (eRemote) {
        final eLocal = listLocal
            .firstWhereOrNull((eLocal) => (eLocal?.g ?? '') == eRemote.g);

        final eDelFlg = _delHistories
            .firstWhereOrNull((eDel) => (eDel.g ?? '') == eRemote.g);

        if (eDelFlg != null) {
          return (eRemote.t ?? 0) > (eDelFlg.t ?? 0);
        }

        if (eLocal == null) {
          return true;
        }

        return (eRemote.t ?? 0) > (eLocal.t ?? 0);
      },
    );

    logger.t('localNewer ${localNewer.length} ${localNewer.map((e) => e?.g)}');

    await downloadRemoteHistories(remoteNewer.toSet().toList());

    await uploadLocalHistories(localNewer.toList(), listRemote: listRemote);
  }
}
