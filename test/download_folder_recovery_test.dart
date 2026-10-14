import 'dart:io';

import 'package:eros_fe/common/controller/download/download_task_manager.dart';
import 'package:eros_fe/common/controller/download/storage_adapter.dart';
import 'package:eros_fe/store/db/entity/gallery_image_task.dart';
import 'package:eros_fe/store/db/entity/gallery_task.dart';
import 'package:eros_fe/store/db/isar_helper.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/download_recovery_scenarios.dart';

class _MemoryStore extends IsarHelper {
  final galleries = <int, GalleryTask>{};
  final images = <(int, int), GalleryImageTask>{};
  @override
  Future<List<GalleryTask>> findAllGalleryTasksIsolate() async =>
      galleries.values.toList();
  @override
  Future<GalleryTask?> findGalleryTaskByGidIsolate(int gid) async =>
      galleries[gid];
  @override
  Future<void> putGalleryTaskIsolate(GalleryTask task,
      {bool replaceOnConflict = true}) async {
    galleries[task.gid] = task;
  }

  @override
  Future<List<GalleryImageTask>> findImageTaskAllByGidIsolate(int gid) async =>
      images.values.where((image) => image.gid == gid).toList();
  @override
  Future<void> putImageTaskIsolate(GalleryImageTask image) async {
    images[(image.gid, image.ser)] = image;
  }
}

class _UnreadableStorage extends StorageAdapter {
  _UnreadableStorage(IsarHelper store) : super(taskStore: store);
  @override
  Future<bool> downloadDirectoryAvailable(GalleryTask task) async =>
      throw const FileSystemException('permission denied');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  test(
      'moved-folder recovery scenarios preserve bytes and queue only missing files',
      () async {
    final root = await Directory.systemTemp.createTemp('eros-folder-recovery-');
    try {
      final passed = await runDownloadRecoveryScenarios(root, _MemoryStore());
      expect(passed.length, 15);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test(
      'unreadable directory preserves records and suppresses startup and continue',
      () async {
    final root =
        await Directory.systemTemp.createTemp('eros-unreadable-recovery-');
    try {
      final store = _MemoryStore();
      final f = RecoveryFixture(root, store, 9);
      await f.seed(status: 1);
      await f.boot(storage: _UnreadableStorage(store));
      await f.resume();
      expect(f.queued, isEmpty);
      expect(f.state.galleryTaskMap[9]!.completCount, 3);
      expect(store.images.values.every((image) => image.status == 3), isTrue);
      expect(
          f.state.errInfoMap[9], DownloadTaskManager.unavailableFilesMessage);
    } finally {
      await root.delete(recursive: true);
    }
  });
}
