import 'dart:convert';
import 'dart:io';

import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/debug/offline_acceptance.dart';
import 'package:eros_fe/store/db/entity/gallery_image_task.dart';
import 'package:eros_fe/store/db/entity/gallery_task.dart';
import 'package:path/path.dart' as path;

Future<void> initializeOfflineDownloads() async {
  if (!offlineAcceptanceEnabled ||
      !const bool.fromEnvironment('EROS_DOWNLOAD_ACCEPTANCE')) {
    return;
  }
  const fixtureFolder = 'offline-native-fixture-v2';
  final root = path.join(Global.appDocPath, fixtureFolder);
  for (final index in [1, 2, 3]) {
    final gid = 9311000 + index;
    // Never replace existing records or bytes, including prior test runs.
    if (await isarHelper.findGalleryTaskByGid(gid) != null) {
      continue;
    }
    final directory = Directory(path.join(root, '$gid'));
    final present = index != 2;
    if (present) {
      await directory.create(recursive: true);
      final cover = File(path.join(directory.path, '1.png'));
      if (!await cover.exists()) {
        await cover.writeAsBytes(base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8'
          '/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
        ));
      }
    }
    final title = index == 1
        ? 'Offline v2 downloaded fixture 1'
        : index == 2
            ? 'Offline v2 missing files fixture 2'
            : 'Offline v2 paused fixture 3';
    await isarHelper.putGalleryTask(GalleryTask(
      gid: gid,
      token: 'offline-fixture',
      title: title,
      // Match the production iOS two-component relative download layout.
      // Absolute nested fixture paths become stale after simulator reinstall.
      dirPath: Platform.isIOS ? path.join(fixtureFolder, '$gid') : directory.path,
      fileCount: index == 3 ? 2 : 1,
      completCount: 1,
      status: index == 3 ? 6 : 3,
      coverImage: '1.png',
      uploader: 'Neutral fixture with a deliberately long uploader name',
      addTime: 1767225610000 + index,
    ));
    await isarHelper.putImageTask(GalleryImageTask(
      gid: gid,
      token: 'offline-image',
      ser: 1,
      filePath: '1.png',
      status: 3,
    ));
    if (index == 3) {
      await isarHelper.putImageTask(GalleryImageTask(
        gid: gid,
        token: 'offline-missing-image',
        ser: 2,
        status: 6,
      ));
    }
  }
}
