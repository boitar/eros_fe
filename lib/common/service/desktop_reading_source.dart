import 'dart:io';

import 'package:collection/collection.dart';
import 'package:eros_fe/common/controller/archiver_download_controller.dart';
import 'package:eros_fe/common/controller/download/download_file_path.dart';
import 'package:eros_fe/common/controller/download_controller.dart';
import 'package:eros_fe/common/controller/recent_reading_store.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/route/navigator_util.dart';
import 'package:eros_fe/store/archive_async.dart';
import 'package:eros_fe/widget/desktop_gallery_actions.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;

/// Resolve locally available content on click, never while building the sidebar.
class DesktopReadingSource {
  const DesktopReadingSource();

  GalleryProvider? providerFor(RecentReadingEntry entry) =>
      entry.gid?.isNotEmpty != true
      ? null
      : GalleryProvider(
          gid: entry.gid,
          token: entry.token,
          url: entry.url,
          imgUrl: entry.cover,
          japaneseTitle: entry.title,
          filecount: entry.total?.toString(),
        );

  static bool isImage(String file) => const {
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.avif',
    '.bmp',
  }.contains(path.extension(file).toLowerCase());

  static Future<List<String>> directoryImages(String directory) async {
    if (!await Directory(directory).exists()) return [];
    final files = await Directory(directory)
        .list(followLinks: false)
        .where((file) => file is File && isImage(file.path))
        .map((file) => file.path)
        .toList();
    files.sort(compareNatural);
    return files;
  }

  Future<List<String>> _downloadFiles(String? gid) async {
    final numeric = int.tryParse(gid ?? '');
    if (numeric == null || !Get.isRegistered<DownloadController>()) return [];
    final downloads = Get.find<DownloadController>();
    final task = downloads.dState.galleryTaskMap[numeric];
    if (task == null || task.status != TaskStatus.complete.value) return [];
    final images = await downloads.getImageTasks(numeric);
    final files = images
        .map(
          (image) => buildDownloadFilePath(
            directoryPath: task.realDirPath,
            fileName: image.filePath,
          ),
        )
        .whereType<String>()
        .toList();
    if (files.isEmpty) return [];
    for (final file in files) {
      if (!await File(file).exists()) return [];
    }
    return files;
  }

  Future<bool> open(RecentReadingEntry entry) async {
    var files = <String>[];
    try {
      files = await _downloadFiles(entry.gid);
    } on Object {
      /* Try saved source. */
    }
    if (files.isEmpty &&
        entry.source == 'download' &&
        entry.sourcePath != null) {
      try {
        files = await directoryImages(entry.sourcePath!);
      } on FileSystemException {
        /* Try online. */
      }
    }
    if (files.isNotEmpty) {
      await NavigatorUtil.goGalleryViewPageFile(
        entry.index.clamp(0, files.length - 1),
        files,
        entry.gid ?? entry.id,
      );
      return true;
    }
    final archives = <String>[
      if (entry.source == 'archiver' && entry.sourcePath != null)
        entry.sourcePath!,
      if (Get.isRegistered<ArchiverDownloadController>())
        for (final task
            in Get.find<ArchiverDownloadController>().archiverTaskMap.values)
          if (task.gid == entry.gid &&
              task.savedDir != null &&
              task.fileName != null)
            path.join(task.savedDir!, task.fileName!),
    ];
    for (final archivePath in archives.toSet()) {
      if (!await File(archivePath).exists()) continue;
      final archive = await readAsyncArchive(archivePath);
      try {
        archive.asyncArchive.files.removeWhere((file) => !isImage(file.name));
        archive.asyncArchive.files.sort(
          (a, b) => compareNatural(a.name, b.name),
        );
        if (archive.asyncArchive.files.isEmpty) continue;
        await NavigatorUtil.goGalleryViewPageArchiver(
          entry.index.clamp(0, archive.asyncArchive.files.length - 1),
          archive.asyncArchive,
          entry.gid ?? entry.id,
          sourcePath: archivePath,
        );
        return true;
      } finally {
        archive.asyncInputStream.close();
      }
    }
    final provider = providerFor(entry);
    if (provider == null || (entry.url == null && entry.token == null))
      return false;
    return DesktopGalleryActions.read(provider, index: entry.index);
  }
}
