import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:eros_fe/common/controller/download/download_task_manager.dart';
import 'package:eros_fe/common/controller/download/storage_adapter.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/network/api.dart';
import 'package:eros_fe/network/app_dio/exception.dart';
import 'package:eros_fe/network/request.dart';
import 'package:eros_fe/store/db/entity/gallery_image_task.dart';
import 'package:eros_fe/store/db/entity/gallery_task.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sprintf/sprintf.dart' as sp;

const int _kMinSerialDigits = 4;

/// Staged `.info` filename written before Isar commit so `restoreGalleryTasks`
/// never imports an uncommitted incremental target directory.
const String kIncrementalStagingInfoFileName = '.info.staging';

/// Crash-recovery journal placed inside a staged incremental target directory
/// until the Isar transaction, `.info` promotion, and old-directory retirement
/// have all completed.
const String kIncrementalPendingJournalFileName = '.inc_pending.json';

/// Tombstone placed inside a superseded `inPlace` source directory right before
/// deleting its `.info` / files so interrupted retirement can still be verified
/// and skipped by `restoreGalleryTasks`.
const String kIncrementalRetiringTombstoneFileName = '.inc_retiring.json';

final RegExp _kImagePagePathPattern = RegExp(
  r'^/s/([0-9a-fA-F]{6,})/(\d+)-(\d+)(?:/.*)?$',
);

/// Resolves and validates an E-Hentai/ExHentai image page link (`/s/<key>/<gid>-<ser>`)
/// against [baseUri], returning a canonical absolute HTTPS URL.
///
/// Returns `null` if [rawHref] is blank, invalid, belongs to a non-EH host, or
/// fails [expectedGid] / [expectedSer] verification.
String? resolveEhImagePageUri(
  String? rawHref, {
  Uri? baseUri,
  int? expectedGid,
  int? expectedSer,
}) {
  final trimmed = rawHref?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }
  final normalized = trimmed.startsWith('//') ? 'https:$trimmed' : trimmed;
  final parsed = Uri.tryParse(normalized);
  if (parsed == null) {
    return null;
  }

  final fallbackBase =
      (baseUri != null &&
          (baseUri.scheme == 'https' || baseUri.scheme == 'http') &&
          isAllowedEhHost(baseUri.host))
      ? Uri(scheme: 'https', host: baseUri.host.toLowerCase())
      : Uri.tryParse(Api.getBaseUrl());

  late final Uri resolved;
  if (parsed.hasScheme) {
    final scheme = parsed.scheme.toLowerCase();
    if ((scheme != 'https' && scheme != 'http') ||
        !isAllowedEhHost(parsed.host)) {
      return null;
    }
    resolved = parsed;
  } else if (parsed.host.isNotEmpty) {
    if (!isAllowedEhHost(parsed.host)) {
      return null;
    }
    resolved = parsed.replace(scheme: 'https');
  } else {
    final normalizedPath = parsed.path.startsWith('/')
        ? parsed.path
        : '/${parsed.path}';
    if (fallbackBase == null || !isAllowedEhHost(fallbackBase.host)) {
      return null;
    }
    resolved = Uri(
      scheme: 'https',
      host: fallbackBase.host.toLowerCase(),
      path: normalizedPath,
    );
  }

  final normalizedPath = resolved.path.startsWith('/')
      ? resolved.path
      : '/${resolved.path}';
  final match = _kImagePagePathPattern.firstMatch(normalizedPath);
  if (match == null) {
    return null;
  }
  final key = match.group(1)!.toLowerCase();
  final matchedGid = int.tryParse(match.group(2)!);
  final matchedSer = int.tryParse(match.group(3)!);
  if (matchedGid == null || matchedSer == null) {
    return null;
  }
  if (expectedGid != null && matchedGid != expectedGid) {
    return null;
  }
  if (expectedSer != null && matchedSer != expectedSer) {
    return null;
  }
  return Uri(
    scheme: 'https',
    host: resolved.host.toLowerCase(),
    path: '/s/$key/$matchedGid-$matchedSer',
  ).toString();
}

/// Returns `true` when [error] represents a cancelled HTTP request, including
/// the app's Dio-to-[CancelException] translation.
bool isCancelError(Object error) {
  if (error is CancelException) {
    return true;
  }
  if (error is DioException && CancelToken.isCancel(error)) {
    return true;
  }
  return false;
}

/// Extracts the E-Hentai/ExHentai image hash key from a validated page `href`
/// (`/s/<imgkey>/<gid>-<ser>`) or falls back to a hex-like `token` when `href`
/// is absent.
///
/// When [expectedGid] or [expectedSer] is provided and `href` is present, a
/// mismatch returns `null` rather than silently accepting a foreign page link.
String? extractGalleryImageKey({
  String? href,
  String? token,
  int? expectedGid,
  int? expectedSer,
}) {
  final rawHref = href?.trim() ?? '';
  if (rawHref.isNotEmpty) {
    final normalized = rawHref.startsWith('//') ? 'https:$rawHref' : rawHref;
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      return null;
    }
    if (uri.hasScheme) {
      final scheme = uri.scheme.toLowerCase();
      if ((scheme != 'https' && scheme != 'http') ||
          !isAllowedEhHost(uri.host)) {
        return null;
      }
    } else if (uri.host.isNotEmpty && !isAllowedEhHost(uri.host)) {
      return null;
    }
    final normalizedPath = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
    final match = _kImagePagePathPattern.firstMatch(normalizedPath);
    if (match == null) {
      return null;
    }
    final key = match.group(1)!.toLowerCase();
    final matchedGid = int.tryParse(match.group(2)!);
    final matchedSer = int.tryParse(match.group(3)!);
    if (expectedGid != null && matchedGid != expectedGid) {
      return null;
    }
    if (expectedSer != null && matchedSer != expectedSer) {
      return null;
    }
    return key;
  }

  final rawToken = token?.trim() ?? '';
  if (RegExp(r'^[0-9a-fA-F]{6,}$').hasMatch(rawToken)) {
    return rawToken.toLowerCase();
  }
  return null;
}

/// Normalizes a validated E-Hentai/ExHentai gallery URL to a canonical absolute
/// URL using [baseUri] (or [Api.getBaseUrl] when omitted).
///
/// Returns an empty string for malformed or non-E-Hentai URLs.
String normalizeGalleryUrl(String rawUrl, {Uri? baseUri}) {
  final fallbackBase = baseUri ?? Uri.tryParse(Api.getBaseUrl());
  final resolved = resolveEhGalleryUri(rawUrl, baseUri: fallbackBase);
  if (resolved == null) {
    return '';
  }
  return resolved.toString();
}

/// Extracts an allowed E-Hentai/ExHentai site origin [Uri] from [rawUrl], if any.
Uri? extractSiteBaseUri(String? rawUrl) {
  final resolved = resolveEhGalleryUri(rawUrl);
  if (resolved == null || !resolved.hasScheme || !isAllowedEhHost(resolved.host)) {
    return null;
  }
  return Uri(scheme: resolved.scheme, host: resolved.host);
}

/// Formats a zero-padded serial base name matching `ImageDownloadProcessor`.
String formatDownloadSerialBaseName(int ser, int maxSer) {
  final width = math.max(_kMinSerialDigits, maxSer.toString().length);
  return sp.sprintf('%0${width}d', <int>[ser]);
}

@immutable
class GalleryUpdateInfo {
  const GalleryUpdateInfo({
    required this.sourceGid,
    required this.newerVersions,
    required this.checkedAt,
  });

  final int sourceGid;

  /// Ordered newest-first.
  final List<GalleryNewerVersion> newerVersions;
  final DateTime checkedAt;

  GalleryNewerVersion get latest => newerVersions.first;
  int get count => newerVersions.length;
}

enum GalleryIncrementalUpdateMode {
  inPlace,
  newTask,
}

@immutable
class GalleryIncrementalProgress {
  const GalleryIncrementalProgress({
    required this.gid,
    required this.reusedCount,
    required this.totalCount,
    required this.mode,
  });

  final int gid;
  final int reusedCount;
  final int totalCount;
  final GalleryIncrementalUpdateMode mode;
}

@immutable
class GalleryPageReuse {
  const GalleryPageReuse({
    required this.newSer,
    required this.oldSer,
    required this.oldFileName,
    required this.imgKey,
    required this.newImage,
  });

  final int newSer;
  final int oldSer;
  final String oldFileName;
  final String imgKey;
  final GalleryImage newImage;
}

@immutable
class GalleryIncrementalPlan {
  const GalleryIncrementalPlan({
    required this.oldTask,
    required this.targetVersion,
    required this.targetProvider,
    required this.targetImages,
    required this.reusedPages,
    required this.pagesToDownload,
    required this.addedCount,
    required this.replacedCount,
    required this.totalNewPages,
    required this.firstPageCount,
    this.mappedReadingIndex,
    this.canReuseLocalFiles = true,
    this.canonicalTargetUrl = '',
  });

  final GalleryTask oldTask;
  final GalleryNewerVersion targetVersion;
  final GalleryProvider targetProvider;
  final List<GalleryImage> targetImages;
  final List<GalleryPageReuse> reusedPages;
  final List<GalleryImage> pagesToDownload;
  final int addedCount;
  final int replacedCount;
  final int totalNewPages;
  final int firstPageCount;
  final int? mappedReadingIndex;

  /// Whether local filesystem reuse & in-place replacement are available.
  /// False when either the source or destination storage uses Android SAF.
  final bool canReuseLocalFiles;

  /// Validated absolute URL preserving the target gallery's site host.
  final String canonicalTargetUrl;

  int get reusedCount => reusedPages.length;
  int get downloadCount => pagesToDownload.length;
  int get effectiveReusedCount => canReuseLocalFiles ? reusedCount : 0;
  int get effectiveDownloadCount =>
      canReuseLocalFiles ? downloadCount : totalNewPages;
  int get newGid => targetVersion.gidInt;
  String get newToken => targetVersion.token;
}

@immutable
class GalleryIncrementalExecutionResult {
  const GalleryIncrementalExecutionResult({
    required this.task,
    required this.reusedCount,
    required this.downloadCount,
    required this.completedLocally,
  });

  final GalleryTask task;
  final int reusedCount;
  final int downloadCount;
  final bool completedLocally;
}

@immutable
class GalleryUpdateBatchResult {
  const GalleryUpdateBatchResult({
    required this.checkedCount,
    required this.failedCount,
    required this.updates,
    this.checkedGids = const <int>{},
    this.failedGids = const <int>{},
    this.cancelledGids = const <int>{},
    this.cancelled = false,
  });

  final int checkedCount;
  final int failedCount;
  final Map<int, GalleryUpdateInfo> updates;
  final Set<int> checkedGids;
  final Set<int> failedGids;
  final Set<int> cancelledGids;
  final bool cancelled;

  int get foundCount => updates.length;
}

/// Maps a 0-based reading page index from the old gallery onto the new version.
int? mapReadingIndexForIncrementalUpdate({
  required int? oldLastIndex,
  required List<GalleryPageReuse> reusedPages,
  required int totalNewPages,
}) {
  if (oldLastIndex == null || totalNewPages <= 0) {
    return null;
  }
  final oldSer = oldLastIndex + 1;
  for (final reuse in reusedPages) {
    if (reuse.oldSer == oldSer) {
      return (reuse.newSer - 1).clamp(0, totalNewPages - 1);
    }
  }
  return oldLastIndex.clamp(0, totalNewPages - 1);
}

/// Builds a pure incremental-update plan by matching E-Hentai image keys
/// between completed local pages (with verified files) and the target version's
/// complete image list.
GalleryIncrementalPlan buildGalleryIncrementalPlan({
  required GalleryTask oldTask,
  required List<GalleryImageTask> oldImageTasks,
  required Set<String> availableOldFileNames,
  required GalleryNewerVersion targetVersion,
  required GalleryProvider targetProvider,
  required List<GalleryImage> targetImages,
  required int firstPageCount,
  int? oldReadingIndex,
  bool canReuseLocalFiles = true,
  String canonicalTargetUrl = '',
}) {
  final oldByKey = <String, Queue<GalleryImageTask>>{};
  final sortedOld = oldImageTasks.toList()
    ..sort((a, b) => a.ser.compareTo(b.ser));

  for (final task in sortedOld) {
    final fileName = task.filePath;
    if (task.status != TaskStatus.complete.value ||
        fileName == null ||
        fileName.isEmpty ||
        !availableOldFileNames.contains(fileName)) {
      continue;
    }
    final key = extractGalleryImageKey(
      href: task.href,
      token: task.token,
      expectedGid: oldTask.gid,
      expectedSer: task.ser,
    );
    if (key == null) {
      continue;
    }
    oldByKey.putIfAbsent(key, Queue<GalleryImageTask>.new).add(task);
  }

  final dedupedNew = <int, GalleryImage>{};
  for (final img in targetImages) {
    if (img.ser > 0) {
      dedupedNew[img.ser] = img;
    }
  }
  final sortedNew = dedupedNew.values.toList()
    ..sort((a, b) => a.ser.compareTo(b.ser));

  final reused = <GalleryPageReuse>[];
  final toDownload = <GalleryImage>[];

  for (final img in sortedNew) {
    final key = extractGalleryImageKey(
      href: img.href,
      token: img.token,
      expectedGid: targetVersion.gidInt,
      expectedSer: img.ser,
    );
    final queue = key == null ? null : oldByKey[key];
    if (key != null && queue != null && queue.isNotEmpty) {
      final matched = queue.removeFirst();
      reused.add(
        GalleryPageReuse(
          newSer: img.ser,
          oldSer: matched.ser,
          oldFileName: matched.filePath!,
          imgKey: key,
          newImage: img,
        ),
      );
    } else {
      toDownload.add(img);
    }
  }

  final parsedFileCount = int.tryParse(targetProvider.filecount ?? '') ?? 0;
  final totalNewPages = math.max(parsedFileCount, sortedNew.length);
  final fetchCount = math.max(toDownload.length, totalNewPages - reused.length);
  final rawAdded = math.max(0, totalNewPages - oldTask.fileCount);
  final addedCount = math.min(fetchCount, rawAdded);
  final replacedCount = math.max(0, fetchCount - addedCount);

  final mappedIndex = mapReadingIndexForIncrementalUpdate(
    oldLastIndex: oldReadingIndex,
    reusedPages: reused,
    totalNewPages: totalNewPages,
  );

  return GalleryIncrementalPlan(
    oldTask: oldTask,
    targetVersion: targetVersion,
    targetProvider: targetProvider,
    targetImages: sortedNew,
    reusedPages: reused,
    pagesToDownload: toDownload,
    addedCount: addedCount,
    replacedCount: replacedCount,
    totalNewPages: totalNewPages,
    firstPageCount: firstPageCount > 0 ? firstPageCount : sortedNew.length,
    mappedReadingIndex: mappedIndex,
    canReuseLocalFiles: canReuseLocalFiles,
    canonicalTargetUrl: canonicalTargetUrl.isNotEmpty
        ? canonicalTargetUrl
        : targetVersion.url,
  );
}

@immutable
class PreparedIncrementalFiles {
  const PreparedIncrementalFiles({
    required this.targetDirPath,
    required this.reusedImageTasks,
    this.coverImage,
  });

  final String targetDirPath;
  final List<GalleryImageTask> reusedImageTasks;
  final String? coverImage;
}

/// Copies verified reused local image files from [sourceDirPath] into a brand-new,
/// empty, exclusive [targetDirPath] without mutating [sourceDirPath].
///
/// Both `inPlace` and `newTask` modes build the new gallery in an isolated target
/// directory so any copy, `.info`, or Isar transaction failure leaves the original
/// gallery completely untouched.
Future<PreparedIncrementalFiles> prepareIncrementalLocalFiles({
  required GalleryIncrementalPlan plan,
  required GalleryIncrementalUpdateMode mode,
  required String sourceDirPath,
  required String targetDirPath,
  required List<GalleryImageTask> oldImageTasks,
}) async {
  if (sourceDirPath.isContentUri || targetDirPath.isContentUri) {
    throw UnsupportedError('SAF storage is handled separately');
  }

  final canonicalSource = path.canonicalize(sourceDirPath);
  final canonicalTarget = path.canonicalize(targetDirPath);
  if (canonicalSource == canonicalTarget) {
    throw StateError(
      'Target incremental directory must be distinct from source directory',
    );
  }

  final sourceDir = Directory(sourceDirPath);
  if (!await sourceDir.exists()) {
    throw FileSystemException(
      'Source download directory does not exist',
      sourceDirPath,
    );
  }

  final targetDir = Directory(targetDirPath);
  final existedBefore = await targetDir.exists();
  if (existedBefore) {
    final existingEntries = await targetDir.list(followLinks: false).toList();
    final unexpected = existingEntries.where(
      (entry) =>
          path.basename(entry.path) != kIncrementalPendingJournalFileName,
    );
    if (unexpected.isNotEmpty) {
      throw StateError(
        'Target download directory is not empty: $targetDirPath',
      );
    }
  } else {
    await targetDir.create(recursive: true);
  }

  // Re-index current old image tasks so stale plans cannot copy mismatched files.
  final currentOldBySer = <int, GalleryImageTask>{
    for (final task in oldImageTasks)
      if (task.status == TaskStatus.complete.value &&
          task.filePath != null &&
          task.filePath!.isNotEmpty)
        task.ser: task,
  };

  final maxSer = plan.totalNewPages + 1;
  final reusedTasks = <GalleryImageTask>[];
  String? coverImage;

  String destFileNameFor(GalleryPageReuse reuse) {
    final ext = path.extension(reuse.oldFileName);
    final safeExt = ext.isNotEmpty ? ext : '.jpg';
    return '${formatDownloadSerialBaseName(reuse.newSer, maxSer)}$safeExt';
  }

  try {
    for (final reuse in plan.reusedPages) {
      final currentOld = currentOldBySer[reuse.oldSer];
      if (currentOld == null || currentOld.filePath != reuse.oldFileName) {
        continue;
      }
      final currentKey = extractGalleryImageKey(
        href: currentOld.href,
        token: currentOld.token,
        expectedGid: plan.oldTask.gid,
        expectedSer: currentOld.ser,
      );
      if (currentKey != reuse.imgKey) {
        continue;
      }

      final srcFile = File(path.join(sourceDirPath, reuse.oldFileName));
      if (!await srcFile.exists() || await srcFile.length() <= 0) {
        continue;
      }
      final destName = destFileNameFor(reuse);
      final destFile = File(path.join(targetDirPath, destName));
      if (await destFile.exists()) {
        throw StateError('Unexpected filename collision in target dir: $destName');
      }
      final tempFile = File(path.join(targetDirPath, '.$destName.inc_tmp'));
      await srcFile.copy(tempFile.path);
      if (await tempFile.length() <= 0) {
        throw FileSystemException('Copied image file was empty', tempFile.path);
      }
      await tempFile.rename(destFile.path);

      if (reuse.newSer == 1) {
        coverImage = destName;
      }
      reusedTasks.add(
        GalleryImageTask(
          gid: plan.newGid,
          token: reuse.imgKey,
          href: reuse.newImage.href,
          ser: reuse.newSer,
          filePath: destName,
          status: TaskStatus.complete.value,
        ),
      );
    }
  } catch (_) {
    if (await targetDir.exists()) {
      try {
        await targetDir.delete(recursive: true);
      } catch (_) {}
    }
    rethrow;
  }

  return PreparedIncrementalFiles(
    targetDirPath: targetDirPath,
    reusedImageTasks: reusedTasks,
    coverImage: coverImage,
  );
}

/// Writes the crash-recovery journal file inside [targetIoDirPath] as soon as
/// the target directory is allocated (before copying files or committing Isar).
Future<void> writePendingIncrementalJournal({
  required String targetIoDirPath,
  required int newGid,
  required int oldGid,
  required String? oldToken,
  required String? oldIoDirPath,
  required GalleryIncrementalUpdateMode mode,
}) async {
  if (targetIoDirPath.isContentUri) {
    return;
  }
  final journalFile = File(
    path.join(targetIoDirPath, kIncrementalPendingJournalFileName),
  );
  final payload = jsonEncode(<String, Object?>{
    'newGid': newGid,
    'oldGid': oldGid,
    'oldToken': oldToken,
    'oldIoDirPath': oldIoDirPath,
    'mode': mode.name,
  });
  await journalFile.writeAsString(payload, flush: true);
}

/// Promotes `.info.staging` -> `.info` (without overwriting a newer `.info`),
/// retires superseded `inPlace` source directories, and removes
/// `.inc_pending.json` ONLY when all steps succeed.
///
/// Returns `true` when fully finalized (journal removed), or `false` if any
/// step failed so the journal remains on disk for startup/restore retry.
Future<bool> finalizeCommittedIncrementalDirectory({
  required String targetIoDirPath,
  String? retireOldIoDirPath,
  int? newGid,
  int? oldGid,
  String? oldToken,
}) async {
  var allSucceeded = true;

  if (!targetIoDirPath.isContentUri) {
    try {
      final stagingInfo = File(
        path.join(targetIoDirPath, kIncrementalStagingInfoFileName),
      );
      final finalInfo = File(path.join(targetIoDirPath, '.info'));
      // Check and promote/discard synchronously with no intervening await so
      // concurrent completion writes cannot interleave with promotion.
      if (stagingInfo.existsSync()) {
        if (finalInfo.existsSync()) {
          // A newer `.info` already exists (e.g., from task progress/completion);
          // never clobber it with an older staging snapshot.
          stagingInfo.deleteSync();
        } else {
          stagingInfo.renameSync(finalInfo.path);
        }
      }
    } catch (_) {
      allSucceeded = false;
    }
  }

  if (retireOldIoDirPath != null &&
      retireOldIoDirPath.isNotEmpty &&
      !retireOldIoDirPath.isContentUri) {
    try {
      final oldDir = Directory(retireOldIoDirPath);
      if (await oldDir.exists()) {
        // Best-effort tombstone so restore skips this dir even if `.info`
        // deletion fails or only `.info` is removed before a crash.
        if (oldGid != null && newGid != null) {
          try {
            final tombstone = File(
              path.join(retireOldIoDirPath, kIncrementalRetiringTombstoneFileName),
            );
            await tombstone.writeAsString(
              jsonEncode(<String, Object?>{
                'oldGid': oldGid,
                'oldToken': oldToken,
                'replacedByGid': newGid,
              }),
              flush: true,
            );
          } catch (_) {}
        }
        final oldInfo = File(path.join(retireOldIoDirPath, '.info'));
        if (await oldInfo.exists()) {
          await oldInfo.delete();
        }
        await oldDir.delete(recursive: true);
      }
    } catch (_) {
      allSucceeded = false;
    }
  }

  if (allSucceeded && !targetIoDirPath.isContentUri) {
    try {
      final journalFile = File(
        path.join(targetIoDirPath, kIncrementalPendingJournalFileName),
      );
      if (await journalFile.exists()) {
        await journalFile.delete();
      }
    } catch (_) {
      allSucceeded = false;
    }
  }

  return allSucceeded;
}

bool _verifyInfoMatchesGallery(
  File infoFile, {
  required int expectedGid,
  String? expectedToken,
}) {
  try {
    final firstLine = infoFile
        .readAsLinesSync()
        .firstWhere((line) => line.trim().isNotEmpty, orElse: () => '');
    if (firstLine.isEmpty) {
      return false;
    }
    final decoded = jsonDecode(firstLine) as Map<String, dynamic>;
    final gid = decoded['gid'] as int?;
    if (gid != expectedGid) {
      return false;
    }
    if (expectedToken != null && expectedToken.isNotEmpty) {
      final token = decoded['token']?.toString().trim() ?? '';
      if (token.isEmpty || token != expectedToken) {
        return false;
      }
    }
    return true;
  } catch (_) {
    return false;
  }
}

bool _verifyRetiringTombstoneMatches(
  File tombstoneFile, {
  required int expectedOldGid,
  required int expectedNewGid,
  String? expectedOldToken,
}) {
  try {
    final decoded =
        jsonDecode(tombstoneFile.readAsStringSync()) as Map<String, dynamic>;
    if (decoded['oldGid'] != expectedOldGid ||
        decoded['replacedByGid'] != expectedNewGid) {
      return false;
    }
    if (expectedOldToken != null && expectedOldToken.isNotEmpty) {
      final token = decoded['oldToken']?.toString().trim() ?? '';
      if (token.isEmpty || token != expectedOldToken) {
        return false;
      }
    }
    return true;
  } catch (_) {
    return false;
  }
}

Future<String> _resolveRealPath(String dirPath) async {
  try {
    return path.canonicalize(await Directory(dirPath).resolveSymbolicLinks());
  } catch (_) {
    return path.canonicalize(dirPath);
  }
}

/// Scans [baseDownloadIoDir] for interrupted incremental updates and either:
/// - completes `.info` promotion + verified old-directory retirement when
///   `newGid` is committed in Isar AND owns that directory, or
/// - removes the uncommitted staging directory when `newGid` is absent from Isar.
///
/// Returns the set of symlink-resolved paths of superseded `oldIoDirPath`
/// directories whose retirement did not complete, so `restoreGalleryTasks`
/// skips them and never re-imports a superseded task.
Future<Set<String>> reconcilePendingIncrementalUpdates({
  required String baseDownloadIoDir,
  required Future<GalleryTask?> Function(int gid) findTaskByGid,
  Future<List<GalleryTask>> Function()? findAllTasks,
  Future<void> Function(
    int newGid,
    int? oldGid,
    Future<void> Function() action,
  )?
  withEntryLock,
  Future<bool> Function(int newGid, int? oldGid)? isReserved,
  Future<Set<String>> Function()? getOwnedIoDirs,
}) async {
  final unretiredOldDirs = <String>{};
  if (baseDownloadIoDir.isEmpty || baseDownloadIoDir.isContentUri) {
    return unretiredOldDirs;
  }
  final baseDir = Directory(baseDownloadIoDir);
  if (!await baseDir.exists()) {
    return unretiredOldDirs;
  }
  final resolvedBase = await _resolveRealPath(baseDownloadIoDir);

  await for (final entry in baseDir.list(followLinks: false)) {
    if (entry is! Directory) {
      continue;
    }
    final journalFile = File(
      path.join(entry.path, kIncrementalPendingJournalFileName),
    );
    if (!await journalFile.exists()) {
      continue;
    }

    int? newGid;
    int? oldGid;
    String? oldToken;
    String? oldIoDirPath;
    String? modeName;
    try {
      final raw = await journalFile.readAsString();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      newGid = decoded['newGid'] as int?;
      oldGid = decoded['oldGid'] as int?;
      oldToken = decoded['oldToken'] as String?;
      oldIoDirPath = decoded['oldIoDirPath'] as String?;
      modeName = decoded['mode'] as String?;
    } catch (_) {
      continue;
    }

    if (newGid == null || newGid <= 0) {
      try {
        await journalFile.delete();
      } catch (_) {}
      continue;
    }

    final int targetGid = newGid;
    final int? sourceGid = oldGid;
    final String? sourceToken = oldToken;
    final String? sourceDir = oldIoDirPath;
    final String? journalMode = modeName;

    Future<void> processEntry() async {
      if (isReserved != null && await isReserved(targetGid, sourceGid)) {
        return;
      }
      if (!await journalFile.exists()) {
        return;
      }

      final committedTask = await findTaskByGid(targetGid);
      final resolvedEntry = await _resolveRealPath(entry.path);
      if (committedTask != null) {
        final taskRealDir = committedTask.realDirPath;
        final resolvedTaskDir =
            (taskRealDir != null &&
                taskRealDir.isNotEmpty &&
                !taskRealDir.isContentUri)
            ? await _resolveRealPath(taskRealDir)
            : '';
        final taskOwnsEntry =
            resolvedTaskDir.isNotEmpty && resolvedTaskDir == resolvedEntry;
        if (!taskOwnsEntry) {
          // Journal does not match the committed task's directory; do not
          // touch any other folder.
          try {
            await journalFile.delete();
          } catch (_) {}
          return;
        }

        String? verifiedRetireDir;
        String? resolvedVerifiedOld;
        if (journalMode == GalleryIncrementalUpdateMode.inPlace.name &&
            sourceGid != null &&
            sourceDir != null &&
            sourceDir.isNotEmpty &&
            !sourceDir.isContentUri &&
            (await findTaskByGid(sourceGid)) == null) {
          final oldDir = Directory(sourceDir);
          if (await oldDir.exists()) {
            // Resolve symlinks to prevent symlink escapes outside baseDir.
            final resolvedOld = await _resolveRealPath(sourceDir);
            final ownedDirs = <String>{};
            if (getOwnedIoDirs != null) {
              for (final dir in await getOwnedIoDirs()) {
                if (dir.isNotEmpty && !dir.isContentUri) {
                  ownedDirs.add(await _resolveRealPath(dir));
                }
              }
            }
            if (findAllTasks != null) {
              for (final t in await findAllTasks()) {
                final real = t.realDirPath;
                if (real != null && real.isNotEmpty && !real.isContentUri) {
                  ownedDirs.add(await _resolveRealPath(real));
                }
              }
            }
            final oldIsWithinBase =
                path.isWithin(resolvedBase, resolvedOld) &&
                resolvedOld != resolvedBase &&
                resolvedOld != resolvedEntry &&
                !ownedDirs.contains(resolvedOld);
            if (oldIsWithinBase) {
              final oldInfo = File(path.join(sourceDir, '.info'));
              final oldTombstone = File(
                path.join(sourceDir, kIncrementalRetiringTombstoneFileName),
              );
              // When `.info` is present, it is authoritative; a leftover
              // tombstone can ONLY authorize retirement when `.info` is absent.
              final oldInfoExists = await oldInfo.exists();
              final verifiedOld = oldInfoExists
                  ? _verifyInfoMatchesGallery(
                      oldInfo,
                      expectedGid: sourceGid,
                      expectedToken: sourceToken,
                    )
                  : (await oldTombstone.exists() &&
                      _verifyRetiringTombstoneMatches(
                        oldTombstone,
                        expectedOldGid: sourceGid,
                        expectedNewGid: targetGid,
                        expectedOldToken: sourceToken,
                      ));
              if (verifiedOld) {
                verifiedRetireDir = sourceDir;
                resolvedVerifiedOld = resolvedOld;
              }
            }
          }
        }

        final finalized = await finalizeCommittedIncrementalDirectory(
          targetIoDirPath: entry.path,
          retireOldIoDirPath: verifiedRetireDir,
          newGid: targetGid,
          oldGid: sourceGid,
          oldToken: sourceToken,
        );
        if (!finalized && resolvedVerifiedOld != null) {
          unretiredOldDirs.add(resolvedVerifiedOld);
        }
      } else {
        // Uncommitted staged directory: only delete if it has no published
        // `.info` belonging to an unrelated gallery.
        final publishedInfo = File(path.join(entry.path, '.info'));
        if (!await publishedInfo.exists() ||
            _verifyInfoMatchesGallery(publishedInfo, expectedGid: targetGid)) {
          await entry.delete(recursive: true);
        }
      }
    }

    try {
      if (withEntryLock != null) {
        await withEntryLock(targetGid, sourceGid, processEntry);
      } else {
        await processEntry();
      }
    } catch (_) {
      // Leave journal in place for next recovery pass.
    }
  }

  return unretiredOldDirs;
}

typedef GalleryDetailFetcher = Future<GalleryProvider?> Function({
  required String url,
  bool refresh,
  CancelToken? cancelToken,
});

typedef GalleryImageListFetcher = Future<List<GalleryImage>> Function(
  String inUrl, {
  int? page,
  bool refresh,
  CancelToken? cancelToken,
});

/// Fetches newer-version metadata and builds incremental update plans.
class GalleryUpdateService {
  GalleryUpdateService({
    GalleryDetailFetcher? fetchDetail,
    GalleryImageListFetcher? fetchImageList,
    StorageAdapter? storageAdapter,
  }) : _fetchDetail = fetchDetail ?? getGalleryDetail,
       _fetchImageList = fetchImageList ?? getGalleryImageList,
       _storageAdapter = storageAdapter ?? StorageAdapter();

  final GalleryDetailFetcher _fetchDetail;
  final GalleryImageListFetcher _fetchImageList;
  final StorageAdapter _storageAdapter;

  /// Checks a single downloaded [task] for newer versions via its detail page.
  Future<GalleryUpdateInfo?> checkTaskForUpdate(
    GalleryTask task, {
    CancelToken? cancelToken,
  }) async {
    final rawUrl = task.url?.trim().isNotEmpty == true
        ? task.url!
        : '/g/${task.gid}/${task.token}/';
    final url = normalizeGalleryUrl(rawUrl);
    if (url.isEmpty) {
      throw StateError('Invalid gallery URL for task ${task.gid}: $rawUrl');
    }
    final provider = await _fetchDetail(
      url: url,
      refresh: true,
      cancelToken: cancelToken,
    );
    if (provider == null) {
      throw StateError('Empty gallery detail response for task ${task.gid}');
    }
    if (!provider.hasNewerVersions) {
      return null;
    }
    return GalleryUpdateInfo(
      sourceGid: task.gid,
      newerVersions: provider.newerVersionsNewestFirst,
      checkedAt: DateTime.now(),
    );
  }

  /// Checks a batch of downloaded [tasks] sequentially with light throttling
  /// to stay polite to E-Hentai/ExHentai rate limits.
  Future<GalleryUpdateBatchResult> checkTasksForUpdates(
    List<GalleryTask> tasks, {
    Duration delayBetweenRequests = const Duration(milliseconds: 220),
    CancelToken? cancelToken,
    void Function(int completed, int total)? onProgress,
  }) async {
    final updates = <int, GalleryUpdateInfo>{};
    final checkedGids = <int>{};
    final failedGids = <int>{};
    final cancelledGids = <int>{};
    var cancelled = false;

    for (var i = 0; i < tasks.length; i++) {
      if (cancelToken?.isCancelled == true) {
        cancelled = true;
        for (var j = i; j < tasks.length; j++) {
          cancelledGids.add(tasks[j].gid);
        }
        break;
      }
      final task = tasks[i];
      try {
        final info = await checkTaskForUpdate(task, cancelToken: cancelToken);
        checkedGids.add(task.gid);
        if (info != null) {
          updates[task.gid] = info;
        }
      } on Object catch (e) {
        if (isCancelError(e) || cancelToken?.isCancelled == true) {
          cancelled = true;
          for (var j = i; j < tasks.length; j++) {
            cancelledGids.add(tasks[j].gid);
          }
          break;
        }
        failedGids.add(task.gid);
      }
      onProgress?.call(i + 1, tasks.length);
      if (i + 1 < tasks.length &&
          delayBetweenRequests > Duration.zero &&
          cancelToken?.isCancelled != true) {
        await Future<void>.delayed(delayBetweenRequests);
      }
    }

    return GalleryUpdateBatchResult(
      checkedCount: checkedGids.length,
      failedCount: failedGids.length,
      updates: updates,
      checkedGids: checkedGids,
      failedGids: failedGids,
      cancelledGids: cancelledGids,
      cancelled: cancelled,
    );
  }

  /// Fetches the target newer version's full image list and compares it against
  /// the locally downloaded [oldTask] and its [oldImageTasks].
  ///
  /// Strictly requires an authoritative `filecount`, target identity validation,
  /// and complete serial coverage `1..totalCount` so truncated pagination can
  /// never mark an incomplete upgrade as complete.
  Future<GalleryIncrementalPlan> analyzeIncrementalUpdate({
    required GalleryTask oldTask,
    required List<GalleryImageTask> oldImageTasks,
    required GalleryNewerVersion targetVersion,
    int? oldReadingIndex,
    bool targetBaseIsSaf = false,
    CancelToken? cancelToken,
  }) async {
    final sourceBaseUri = extractSiteBaseUri(oldTask.url);
    final targetUrl = normalizeGalleryUrl(
      targetVersion.url,
      baseUri: sourceBaseUri,
    );
    if (targetUrl.isEmpty) {
      throw StateError('Invalid target gallery URL: ${targetVersion.url}');
    }

    final detail = await _fetchDetail(
      url: targetUrl,
      refresh: true,
      cancelToken: cancelToken,
    );
    if (detail == null) {
      throw StateError('Failed to fetch newer version detail');
    }

    // Validate target gallery identity when the fetched response includes it.
    final detailGid = detail.gid?.trim() ?? '';
    if (detailGid.isNotEmpty && detailGid != targetVersion.gid) {
      throw StateError(
        'Target gallery GID mismatch: expected ${targetVersion.gid}, got $detailGid',
      );
    }
    final detailToken = detail.token?.trim().toLowerCase() ?? '';
    if (detailToken.isNotEmpty &&
        detailToken != targetVersion.token.toLowerCase()) {
      throw StateError(
        'Target gallery token mismatch for #${targetVersion.gid}',
      );
    }

    final canonicalUrl = normalizeGalleryUrl(
      detail.url?.trim().isNotEmpty == true ? detail.url! : targetUrl,
      baseUri: extractSiteBaseUri(targetUrl) ?? sourceBaseUri,
    );
    final effectiveTargetUrl = canonicalUrl.isNotEmpty ? canonicalUrl : targetUrl;

    final targetProvider = detail.copyWith(
      gid: targetVersion.gid.oN,
      token: targetVersion.token.toLowerCase().oN,
      url: effectiveTargetUrl.oN,
      englishTitle: (detail.englishTitle?.isNotEmpty == true
              ? detail.englishTitle
              : targetVersion.title)
          .oN,
    );

    final totalCount = int.tryParse(targetProvider.filecount?.trim() ?? '');
    if (totalCount == null || totalCount <= 0) {
      throw StateError(
        'Authoritative page count is missing for target gallery #${targetVersion.gid}',
      );
    }

    final firstImages = targetProvider.galleryImages ?? const <GalleryImage>[];
    if (firstImages.isEmpty) {
      throw StateError(
        'No gallery images returned on first page for #${targetVersion.gid}',
      );
    }

    final responseOriginUri =
        extractSiteBaseUri(effectiveTargetUrl) ?? sourceBaseUri;
    final bySer = <int, GalleryImage>{};
    void ingestImages(List<GalleryImage> list, int pageIndex) {
      for (final img in list) {
        if (img.ser <= 0 || img.ser > totalCount) {
          continue;
        }
        final resolvedHref = resolveEhImagePageUri(
          img.href,
          baseUri: responseOriginUri,
          expectedGid: targetVersion.gidInt,
          expectedSer: img.ser,
        );
        if (resolvedHref == null) {
          throw StateError(
            'Missing or invalid image link at page $pageIndex ser ${img.ser} for #${targetVersion.gid}',
          );
        }
        bySer[img.ser] = img.copyWith(href: resolvedHref.oN);
      }
    }

    ingestImages(firstImages, 0);

    final perPage = firstImages.length;
    if (totalCount > bySer.length) {
      final totalPages = (totalCount / perPage).ceil();
      for (var page = 1; page < totalPages; page++) {
        if (cancelToken?.isCancelled == true) {
          throw DioException(
            requestOptions: RequestOptions(path: effectiveTargetUrl),
            type: DioExceptionType.cancel,
          );
        }
        final pageImages = await _fetchImageList(
          effectiveTargetUrl,
          page: page,
          refresh: true,
          cancelToken: cancelToken,
        );
        if (pageImages.isEmpty) {
          throw StateError(
            'Failed to load image list page $page/$totalPages for #${targetVersion.gid}',
          );
        }
        ingestImages(pageImages, page);
      }
    }

    // Strict serial completeness check: every serial 1..totalCount must exist.
    if (bySer.length != totalCount) {
      throw StateError(
        'Incomplete image list for #${targetVersion.gid}: '
        'expected $totalCount pages, got ${bySer.length}',
      );
    }
    for (var ser = 1; ser <= totalCount; ser++) {
      if (!bySer.containsKey(ser)) {
        throw StateError(
          'Missing page serial $ser/$totalCount for #${targetVersion.gid}',
        );
      }
    }

    final dirPath = oldTask.realDirPath;
    final sourceIsSaf = dirPath != null && dirPath.isContentUri;
    final canReuseLocalFiles = !sourceIsSaf && !targetBaseIsSaf;

    // Verify which old downloaded files currently exist on storage.
    // Skip source file probes in SAF fallback mode so unreadable SAF files
    // never block the full-download option.
    final availableOldFiles = <String>{};
    if (canReuseLocalFiles && dirPath != null && dirPath.isNotEmpty) {
      for (final imgTask in oldImageTasks) {
        final name = imgTask.filePath;
        if (imgTask.status == TaskStatus.complete.value &&
            name != null &&
            name.isNotEmpty &&
            await _storageAdapter.downloadFileExists(dirPath, name)) {
          availableOldFiles.add(name);
        }
      }
    }

    return buildGalleryIncrementalPlan(
      oldTask: oldTask,
      oldImageTasks: oldImageTasks,
      availableOldFileNames: availableOldFiles,
      targetVersion: targetVersion,
      targetProvider: targetProvider,
      targetImages: bySer.values.toList(),
      firstPageCount: firstImages.length,
      oldReadingIndex: oldReadingIndex,
      canReuseLocalFiles: canReuseLocalFiles,
      canonicalTargetUrl: effectiveTargetUrl,
    );
  }
}
