import 'dart:convert';
import 'dart:io';

import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/debug/offline_acceptance.dart';
import 'package:eros_fe/store/db/entity/gallery_image_task.dart';
import 'package:eros_fe/store/db/entity/gallery_task.dart';
import 'package:path/path.dart' as path;

Future<void> initializeOfflineSharing() async {
  if (!offlineAcceptanceEnabled ||
      !const bool.fromEnvironment('EROS_SHARE_ACCEPTANCE')) {
    return;
  }
  if (Global.profile.user.memberId?.isNotEmpty ?? false) {
    throw StateError('Sharing acceptance requires an isolated empty account');
  }
  Global.profile = Global.profile.copyWith(
    locale: 'zh_CN',
    searchText: ['offline neutral search'],
    ehConfig: Global.profile.ehConfig.copyWith(listMode: 'list'),
  );
  const gid = 9322001;
  if (await isarHelper.findGalleryTaskByGid(gid) != null) {
    return;
  }
  const folder = 'offline-sharing-fixture';
  final directory = Directory(path.join(Global.appDocPath, folder, '$gid'));
  await directory.create(recursive: true);
  final image = File(path.join(directory.path, '1.png'));
  if (!await image.exists()) {
    await image.writeAsBytes(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8'
      '/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
    ));
  }
  await isarHelper.putGalleryTask(GalleryTask(
    gid: gid,
    token: 'offline-fixture',
    title: 'Offline sharing image fixture',
    dirPath: Platform.isIOS ? path.join(folder, '$gid') : directory.path,
    fileCount: 1,
    completCount: 1,
    status: 3,
    coverImage: '1.png',
    addTime: 1767225610000,
  ));
  await isarHelper.putImageTask(GalleryImageTask(
    gid: gid,
    token: 'offline-image',
    ser: 1,
    filePath: '1.png',
    status: 3,
  ));
}
