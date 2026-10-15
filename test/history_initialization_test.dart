import 'dart:async';

import 'package:eros_fe/common/controller/history_controller.dart';
import 'package:eros_fe/common/controller/mysql_controller.dart';
import 'package:eros_fe/common/controller/tag_controller.dart';
import 'package:eros_fe/common/controller/webdav_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/tab/controller/history_view_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/store/db/isar_helper.dart';
import 'package:eros_fe/store/hive/hive.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Storage implements IsarHelper {
  final readGate = Completer<List<GalleryProvider>>();
  final writeGate = Completer<void>();
  final records = <GalleryProvider>[];
  int reads = 0;
  bool delayWrites = false;

  @override
  Future<List<GalleryProvider>> getAllHistory() {
    reads++;
    return readGate.future;
  }

  @override
  Future<void> addHistoryAsync(GalleryProvider item) async {
    if (delayWrites) {
      await writeGate.future;
    }
    records.removeWhere((value) => value.gid == item.gid);
    records.add(item);
  }

  @override
  Future<void> addHistoriesAsync(List<GalleryProvider> items) async {
    records.addAll(items);
  }

  @override
  Future<void> cleanHistory() async => records.clear();

  @override
  Future<void> removeHistory(String gid) async =>
      records.removeWhere((item) => item.gid == gid);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected history storage call');
}

class _Legacy implements HiveHelper {
  bool migrated = true;

  @override
  bool getViewHistoryMigration() => migrated;
  @override
  List<GalleryProvider> getAllHistory() =>
      [const GalleryProvider(gid: '9', lastViewTime: 9)];
  @override
  List<HistoryIndexGid> getAllHistoryDel() => [];
  @override
  Future<void> setViewHistoryMigration(bool value) async => migrated = value;
  @override
  Future<void> removeHistoryDel(String gid) async {}
  @override
  Future<void> addHistoryDel(HistoryIndexGid value) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected legacy storage call');
}

class _Settings extends GetxService implements EhSettingService {
  @override
  final listMode = ListModeEnum.waterfall.obs;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected history setting');
}

class _Tag extends GetxController implements TagController {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected tag operation');
}

class _Tabs extends GetxController implements TabHomeController {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected tab operation');
}

class _Webdav extends GetxController implements WebdavController {
  @override
  bool get syncHistory => false;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected WebDAV operation');
}

class _Mysql extends GetxController implements MysqlController {
  final uploaded = <String?>[];
  @override
  bool get syncHistory => true;
  @override
  Future<List<HistoryIndexGid>> getHistoryList() async => [];
  @override
  Future<void> uploadHistory(GalleryProvider item) async =>
      uploaded.add(item.gid);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected MySQL operation');
}

class _View extends GetxController implements HistoryViewController {
  @override
  final sliverAnimatedListKey = GlobalKey<SliverAnimatedListState>();
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected history view operation');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Storage storage;
  late _Legacy legacy;
  late _Mysql mysql;
  late HistoryController controller;
  const old = GalleryProvider(gid: '1', lastViewTime: 10);
  const current = GalleryProvider(gid: '2', lastViewTime: 20);

  setUp(() {
    Get.testMode = true;
    Get.put<EhSettingService>(_Settings());
    Get.put<WebdavController>(_Webdav());
    mysql = Get.put<MysqlController>(_Mysql()) as _Mysql;
    Get.put<HistoryViewController>(_View());
    storage = _Storage();
    legacy = _Legacy();
    controller =
        HistoryController(historyStorage: storage, legacyStorage: legacy);
  });
  tearDown(Get.reset);

  test('concurrent initialization shares one pending database read', () async {
    final first = controller.initHistories();
    final second = controller.initHistories();
    expect(identical(first, second), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(storage.reads, 1);
    expect(controller.historiesInitialized, isFalse);
    storage.readGate.complete([old]);
    await Future.wait([first, second]);
    expect(controller.histories.single.gid, '1');
    expect(controller.historiesInitialized, isTrue);
    await controller.initHistories();
    expect(storage.reads, 1);
  });

  test('a cold history page waits for the database before publishing its list',
      () async {
    Get.put<TagController>(_Tag());
    Get.put<TabHomeController>(_Tabs());
    Get.put<HistoryController>(controller);
    final view = HistoryViewController();
    List<GalleryProvider>? result;
    final loading = view.loadData().then((value) => result = value);
    await Future<void>.delayed(Duration.zero);
    expect(result, isNull);
    storage.readGate.complete([old, current]);
    await loading;
    expect(result!.map((item) => item.gid), ['2', '1']);
    expect(storage.reads, 1);
  });

  test('migration finishes before the first database read', () async {
    legacy.migrated = false;
    final loading = controller.initHistories();
    await Future<void>.delayed(Duration.zero);
    expect(legacy.migrated, isTrue);
    expect(storage.records.single.gid, '9');
    storage.readGate.complete(List.of(storage.records));
    await loading;
    expect(controller.histories.single.gid, '9');
  });

  test('clear waits for delayed initialization and cannot resurrect old rows',
      () async {
    final loading = controller.initHistories();
    var cleared = false;
    final clearing = controller.cleanHistory().then((_) => cleared = true);
    await Future<void>.delayed(Duration.zero);
    expect(cleared, isFalse);
    storage.readGate.complete([old]);
    await Future.wait([loading, clearing]);
    expect(controller.histories, isEmpty);
    expect(storage.records, isEmpty);
  });

  test('sync waits for local initialization before uploading its snapshot',
      () async {
    final loading = controller.initHistories();
    var synced = false;
    final syncing = controller.syncHistory().then((_) => synced = true);
    await Future<void>.delayed(Duration.zero);
    expect(synced, isFalse);
    storage.readGate.complete([old]);
    await Future.wait([loading, syncing]);
    expect(mysql.uploaded, ['1']);
  });

  test('a visit received during initialization survives the delayed snapshot',
      () async {
    final loading = controller.initHistories();
    controller.addHistory(current, updateTime: false, sync: false);
    storage.readGate.complete([old]);
    await loading;
    await Future<void>.delayed(Duration.zero);
    expect(controller.histories.map((item) => item.gid), ['2', '1']);
  });

  test('clear waits for earlier persistence writes before deleting rows',
      () async {
    storage.readGate.complete([old]);
    await controller.initHistories();
    storage.delayWrites = true;
    controller.addHistory(current, updateTime: false, sync: false);
    final clearing = controller.cleanHistory();
    storage.writeGate.complete();
    await clearing;
    await Future<void>.delayed(Duration.zero);
    expect(storage.records, isEmpty);
    expect(controller.histories, isEmpty);
  });

  test('removing an absent gallery is safe after initialization', () async {
    storage.readGate.complete([old]);
    await controller.removeHistory('missing', sync: false);
    expect(controller.histories.single.gid, '1');
  });
}
