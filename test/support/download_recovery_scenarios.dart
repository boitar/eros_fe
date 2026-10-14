import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:eros_fe/common/controller/cache_controller.dart';
import 'package:eros_fe/common/controller/download/download_task_manager.dart';
import 'package:eros_fe/common/controller/download/image_download_processor.dart';
import 'package:eros_fe/common/controller/download/resumable_file_downloader.dart';
import 'package:eros_fe/common/controller/download/storage_adapter.dart';
import 'package:eros_fe/common/controller/download_state.dart';
import 'package:eros_fe/models/gallery_image.dart';
import 'package:eros_fe/store/db/entity/gallery_image_task.dart';
import 'package:eros_fe/store/db/entity/gallery_task.dart';
import 'package:eros_fe/store/db/isar_helper.dart';
import 'package:path/path.dart' as path;

void requireRecovery(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}

bool sameBytes(List<int> left, List<int> right) =>
    left.length == right.length &&
    List.generate(left.length, (index) => left[index] == right[index])
        .every((matches) => matches);

class RecoveryFixture {
  RecoveryFixture(this.root, this.store, this.gid);
  final Directory root;
  final IsarHelper store;
  final int gid;
  late GalleryTask gallery;
  late DownloadState state;
  late DownloadTaskManager manager;
  final queued = <GalleryTask>[];
  List<int> bytes(int ser) => List.generate(513 + ser, (i) => (i + ser) % 251);
  Directory get folder => Directory(path.join(root.path, 'downloads', '$gid'));
  File image(int ser) => File(path.join(folder.path, '$ser.jpg'));

  Future<void> seed(
      {int status = 3,
      int imageStatus = 3,
      bool info = true,
      bool filenames = true}) async {
    await folder.create(recursive: true);
    gallery = GalleryTask(
        gid: gid,
        token: 'gallery-token',
        title: 'Recovery fixture',
        dirPath: folder.path,
        fileCount: 3,
        completCount: 3,
        status: status,
        coverImage: '1.jpg');
    await store.putGalleryTaskIsolate(gallery);
    for (var ser = 1; ser <= 3; ser++) {
      await image(ser).writeAsBytes(bytes(ser));
      await store.putImageTaskIsolate(GalleryImageTask(
          gid: gid,
          token: 'image-$ser',
          ser: ser,
          filePath: '$ser.jpg',
          status: 3));
    }
    if (info) {
      await StorageAdapter(taskStore: store).writeTaskInfoFile(gallery);
    }
    for (var ser = 1; ser <= 3; ser++) {
      await store.putImageTaskIsolate(GalleryImageTask(
          gid: gid,
          token: 'image-$ser',
          ser: ser,
          filePath: filenames ? '$ser.jpg' : null,
          status: imageStatus));
    }
  }

  Future<void> boot({StorageAdapter? storage}) async {
    queued.clear();
    state = DownloadState();
    manager =
        DownloadTaskManager(state, taskStore: store, storageAdapter: storage);
    await manager.initGalleryTasks(addGalleryTaskCallback: (GalleryTask task) {
      queued.add(task);
    });
  }

  Future<void> resume() => manager.galleryTaskResume(gid,
      addGalleryTaskCallback: (GalleryTask task) => queued.add(task));

  Future<void> assertComplete() async {
    final task = state.galleryTaskMap[gid]!;
    requireRecovery(task.status == 3 && task.completCount == 3,
        'gallery $gid must be complete');
    requireRecovery(
        queued.every((task) => task.gid != gid), 'complete gallery queued');
    for (var ser = 1; ser <= 3; ser++) {
      requireRecovery(sameBytes(await image(ser).readAsBytes(), bytes(ser)),
          'restored image $gid/$ser bytes changed');
      requireRecovery(!await File('${image(ser).path}.part').exists(),
          'restored image renamed to part');
    }
  }
}

class _UnusedCacheController implements CacheController {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Claimed image reached cache/network processing');
}

class _ImageReadDeniedStorage extends StorageAdapter {
  _ImageReadDeniedStorage(IsarHelper store) : super(taskStore: store);
  @override
  Future<bool> downloadFileExists(
      String? directoryPath, String? fileName) async {
    if (fileName == '2.jpg') {
      throw const FileSystemException('image access denied');
    }
    return super.downloadFileExists(directoryPath, fileName);
  }
}

/// Shared by host regression tests and the iOS Simulator executable.
Future<List<String>> runDownloadRecoveryScenarios(
    Directory root, IsarHelper store) async {
  final passed = <String>[];
  var gid = 910000;
  Future<void> scenario(
      String name, Future<void> Function(RecoveryFixture) run) async {
    final fixture = RecoveryFixture(root, store, ++gid);
    await run(fixture);
    passed.add(name);
  }

  await scenario(
      'six-step move away, startup, pause, clean partials, restore, continue',
      (f) async {
    await f.seed();
    final moved =
        await f.folder.rename(path.join(root.path, 'backup-${f.gid}'));
    await f.boot();
    requireRecovery(f.state.unavailableGalleryFiles.contains(f.gid),
        'missing directory not flagged');
    requireRecovery(
        f.state.galleryTaskMap[f.gid]!.status == 3 &&
            f.state.galleryTaskMap[f.gid]!.completCount == 3,
        'missing directory changed progress');
    requireRecovery(f.queued.every((task) => task.gid != f.gid),
        'missing gallery auto queued');
    final records = await store.findImageTaskAllByGidIsolate(f.gid);
    requireRecovery(
        records.every((image) => image.status == 3 && image.filePath != null),
        'startup erased completed image identity');
    // Simulate the paused/demoted records left by an older application version.
    await store
        .putGalleryTaskIsolate(f.gallery.copyWith(status: 6, completCount: 0));
    f.state.galleryTaskMap[f.gid] =
        f.gallery.copyWith(status: 6, completCount: 0);
    for (final image in records) {
      await store
          .putImageTaskIsolate(image.copyWith(status: 1, filePath: null));
    }
    await f.folder.create(recursive: true);
    final partial = File(path.join(f.folder.path, '1.jpg.part'));
    await partial.writeAsBytes([1, 2, 3]);
    await partial.delete();
    await f.folder.delete();
    await moved.rename(f.folder.path);
    await f.resume();
    await f.assertComplete();
  });

  for (final status in [1, 6, 3]) {
    await scenario(
        'restored final files claimed from DB with image status $status',
        (f) async {
      await f.seed(status: 6, imageStatus: status, info: false);
      await f.boot();
      await f.assertComplete();
    });
  }

  await scenario('partial restoration queues only missing images', (f) async {
    await f.seed(imageStatus: 1, filenames: false);
    await f.image(2).delete();
    await f.boot();
    final images = await store.findImageTaskAllByGidIsolate(f.gid);
    requireRecovery(f.state.galleryTaskMap[f.gid]!.completCount == 2,
        'wrong partial count');
    requireRecovery(images.where((image) => image.status == 1).single.ser == 2,
        'existing images queued');
    requireRecovery(
        images.singleWhere((image) => image.ser == 2).filePath == '2.jpg',
        'missing image identity discarded');
    requireRecovery(sameBytes(await f.image(1).readAsBytes(), f.bytes(1)),
        'partial restore changed bytes');
  });

  await scenario(
      'partial restoration retains user pause until explicit continue',
      (f) async {
    await f.seed(status: 6, imageStatus: 6);
    await f.image(3).delete();
    await f.boot();
    requireRecovery(
        f.state.galleryTaskMap[f.gid]!.status == 6, 'user pause lost');
    requireRecovery(
        f.queued.every((task) => task.gid != f.gid), 'paused gallery queued');
    await f.resume();
    requireRecovery(f.queued.where((task) => task.gid == f.gid).length == 1,
        'continue did not queue missing work');
    requireRecovery(f.state.claimedImageFiles[f.gid]!.length == 2,
        'existing files not claimed');
  });

  await scenario('directory stays absent across startup and repeated continue',
      (f) async {
    await f.seed(status: 1);
    final moved =
        await f.folder.rename(path.join(root.path, 'absent-${f.gid}'));
    await f.boot();
    await f.resume();
    await f.resume();
    requireRecovery(!await f.folder.exists(), 'missing directory recreated');
    requireRecovery(f.state.galleryTaskMap[f.gid]!.completCount == 3,
        'missing directory lost count');
    requireRecovery(f.queued.every((task) => task.gid != f.gid),
        'missing directory queued');
    requireRecovery(await moved.exists(), 'backup lost');
  });

  await scenario(
      'missing info uses DB and ignores unrelated files and partials',
      (f) async {
    await f.seed(info: false);
    await f.image(2).delete();
    await File(path.join(f.folder.path, 'unrelated.jpg')).writeAsBytes([1]);
    await File('${f.image(2).path}.part').writeAsBytes([1, 2]);
    await f.boot();
    requireRecovery(f.state.galleryTaskMap[f.gid]!.completCount == 2,
        'file count used as identity');
    requireRecovery(f.state.claimedImageFiles[f.gid]![2] == null,
        'part claimed as complete');
  });

  await scenario('foreign info cannot claim files for another gallery',
      (f) async {
    await f.seed(imageStatus: 1, filenames: false);
    final info = File(path.join(f.folder.path, '.info'));
    final lines = (await info.readAsString()).split('\n');
    final json = jsonDecode(lines[0]) as Map<String, dynamic>;
    json['gid'] = f.gid + 99;
    await info.writeAsString('${jsonEncode(json)}\n${lines[1]}');
    await f.boot();
    requireRecovery(f.state.galleryTaskMap[f.gid]!.completCount == 0,
        'foreign metadata imported');
  });

  await scenario('corrupt info falls back to DB filenames', (f) async {
    await f.seed();
    await File(path.join(f.folder.path, '.info'))
        .writeAsString('corrupt\nmetadata');
    await f.boot();
    await f.assertComplete();
  });

  await scenario(
      'claimed destination survives downloader and stale partial metadata',
      (f) async {
    await f.seed();
    await f.boot();
    final finalFile = f.image(1);
    final part = File('${finalFile.path}.part');
    await part.writeAsBytes([9, 8, 7]);
    await File('${finalFile.path}.part.json')
        .writeAsString(jsonEncode({'url': 'old'}));
    final result = await ResumableFileDownloader(Dio()).download(
      url: 'http://127.0.0.1:1/must-not-request',
      destinationPath: finalFile.path,
      isDestinationClaimed: () async =>
          f.state.claimedImageFiles[f.gid]![1] == '1.jpg',
    );
    requireRecovery(
        result.bytes == f.bytes(1).length, 'guard returned wrong result');
    requireRecovery(sameBytes(await finalFile.readAsBytes(), f.bytes(1)),
        'guard changed final bytes');
    requireRecovery(sameBytes(await part.readAsBytes(), [9, 8, 7]),
        'guard modified stale partial');
  });

  await scenario('claimed image bypasses URL fetching and cache writes',
      (f) async {
    await f.seed();
    await f.boot();
    final processor = ImageDownloadProcessor(f.state, _UnusedCacheController(),
        downloader: ResumableFileDownloader(Dio()));
    final completed = <String>[];
    await processor.downloadImageFlow(
      const GalleryImage(ser: 1, href: 'http://127.0.0.1:1/must-not-request'),
      null,
      f.gid,
      f.folder.path,
      4,
      onDownloadCompleteWithFileName: (name) async => completed.add(name),
    );
    await processor.downloadToPath(
      'http://127.0.0.1:1/must-not-request',
      f.folder.path,
      '1',
      gid: f.gid,
      onDownloadCompleteWithFileName: (name) async => completed.add(name),
    );
    requireRecovery(
        completed.join(',') == '1.jpg,1.jpg', 'claim not used by processor');
    await f.assertComplete();
  });

  await scenario('failed file access preserves all records before any write',
      (f) async {
    await f.seed(status: 6, imageStatus: 6);
    await f.boot(storage: _ImageReadDeniedStorage(store));
    requireRecovery(f.state.unavailableGalleryFiles.contains(f.gid),
        'access error not flagged');
    requireRecovery(f.state.galleryTaskMap[f.gid]!.completCount == 3,
        'access error changed progress');
    final images = await store.findImageTaskAllByGidIsolate(f.gid);
    requireRecovery(
        images.every((image) => image.status == 6 && image.filePath != null),
        'file access failure partially rewrote records');
  });

  await scenario('one final file cannot satisfy two image serials', (f) async {
    await f.seed(info: false);
    final images = await store.findImageTaskAllByGidIsolate(f.gid);
    await store.putImageTaskIsolate(images
        .singleWhere((image) => image.ser == 2)
        .copyWith(filePath: '1.jpg'));
    await f.boot();
    requireRecovery(f.state.galleryTaskMap[f.gid]!.completCount == 2,
        'duplicate filename counted twice');
  });

  await scenario(
      'genuine part resumes with Range and preserves restored siblings',
      (f) async {
    await f.seed(status: 6);
    await f.image(3).delete();
    final part = File('${f.image(3).path}.part');
    final payload = f.bytes(3);
    const prefixLength = 77;
    await part.writeAsBytes(payload.sublist(0, prefixLength));
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final url = 'http://127.0.0.1:${server.port}/image';
    await File('${part.path}.json')
        .writeAsString(jsonEncode({'url': url, 'etag': '"v1"'}));
    var requests = 0;
    final subscription = server.listen((request) async {
      requests++;
      requireRecovery(request.headers.value('range') == 'bytes=$prefixLength-',
          'missing Range');
      requireRecovery(
          request.headers.value('if-range') == '"v1"', 'missing If-Range');
      request.response.statusCode = 206;
      request.response.headers.set('content-range',
          'bytes $prefixLength-${payload.length - 1}/${payload.length}');
      request.response.headers.contentLength = payload.length - prefixLength;
      request.response.add(payload.sublist(prefixLength));
      await request.response.close();
    });
    try {
      await f.boot();
      requireRecovery(f.state.claimedImageFiles[f.gid]!.length == 2,
          'partial treated as complete');
      final result = await ResumableFileDownloader(Dio()).download(
          url: url,
          destinationPath: f.image(3).path,
          isDestinationClaimed: () async => false);
      requireRecovery(
          result.resumed && requests == 1, 'genuine partial not resumed');
      requireRecovery(sameBytes(await f.image(3).readAsBytes(), payload),
          'resumed bytes incorrect');
      requireRecovery(sameBytes(await f.image(1).readAsBytes(), f.bytes(1)),
          'sibling file modified');
      await f.resume();
      await f.assertComplete();
    } finally {
      await subscription.cancel();
      await server.close(force: true);
    }
  });
  return passed;
}
