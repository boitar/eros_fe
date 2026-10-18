import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;

enum ImageExportFailure {
  permission,
  invalidFile,
  download,
  unsupported,
  write,
  busy,
}

class ImageExportException implements Exception {
  const ImageExportException(this.failure, [this.cause]);
  final ImageExportFailure failure;
  final Object? cause;

  @override
  String toString() => 'ImageExportException($failure): $cause';
}

/// A snapshot of the selected page, never a reference to the reader's index.
@immutable
class GalleryImageSource {
  const GalleryImageSource({
    this.gid,
    this.ser,
    this.url,
    this.cacheKey,
    this.filePath,
    this.tempPath,
    this.originalUrl,
    this.originalCacheKey,
    this.filename,
    this.isLocal = false,
  });

  final String? gid;
  final int? ser;
  final String? url;
  final String? cacheKey;
  final String? filePath;
  final String? tempPath;
  final String? originalUrl;
  final String? originalCacheKey;
  final String? filename;
  final bool isLocal;

  // Preferences alone are not proof: the server can still send a resample.
  bool get currentIsOriginal =>
      url != null && url!.isNotEmpty && url == originalUrl;

  bool get hasSeparateOriginal =>
      !isLocal &&
      originalUrl != null &&
      originalUrl!.isNotEmpty &&
      !currentIsOriginal;
}

class ExportImageFile {
  const ExportImageFile(this.file, this.extension);
  final File file;
  final String extension;
}

typedef ImageCacheLookup = Future<File?> Function(String url, String? cacheKey);
typedef ImageFileDownload = Future<void> Function(
    String url, String destination);

/// Resolves encoded image files. It never exports a screenshot or decoded frame.
class GalleryImageResolver {
  GalleryImageResolver({
    required this.directory,
    required this.download,
    ImageCacheLookup? cacheLookup,
  }) : cacheLookup = cacheLookup ??
            ((url, key) => getCachedImageFile(url, cacheKey: key));

  final Directory directory;
  final ImageFileDownload download;
  final ImageCacheLookup cacheLookup;
  final Map<String, Future<ExportImageFile>> _downloads = {};

  Future<ExportImageFile> resolve(GalleryImageSource source,
      {bool original = false}) async {
    final useCurrent = !original || source.currentIsOriginal;
    if (useCurrent) {
      for (final candidate in [source.filePath, source.tempPath]) {
        if (candidate == null || candidate.isEmpty) {
          continue;
        }
        final image = await _usable(File(candidate));
        if (image != null) {
          return image;
        }
      }
    }

    final url = useCurrent ? source.url : source.originalUrl;
    final key = useCurrent ? source.cacheKey : source.originalCacheKey;
    if (url == null || url.isEmpty || source.isLocal) {
      throw const ImageExportException(ImageExportFailure.invalidFile);
    }
    final cached = await cacheLookup(url, key);
    if (cached != null) {
      final image = await _usable(cached);
      if (image != null) {
        return image;
      }
    }

    // Do not scan the shared temp directory, or trust a partial/old download.
    final identity = keyToMd5(jsonEncode([
      source.gid,
      source.ser,
      url,
      if (original) 'original' else 'current',
    ]));
    final inFlight = _downloads[identity];
    if (inFlight != null) {
      return inFlight;
    }
    final future = _download(url, identity);
    _downloads[identity] = future;
    try {
      return await future;
    } finally {
      _downloads.remove(identity);
    }
  }

  Future<ExportImageFile> _download(String url, String identity) async {
    final folder = Directory(path.join(directory.path, identity));
    final completed = File(path.join(folder.path, 'image'));
    final existing = await _usable(completed);
    if (existing != null) {
      return existing;
    }
    await folder.create(recursive: true);
    // A unique staging directory also isolates a simultaneous share/export.
    final staging = await folder.createTemp('pending-');
    try {
      final partial = File(path.join(staging.path, 'image.part'));
      try {
        await download(url, partial.path);
      } catch (error) {
        throw ImageExportException(ImageExportFailure.download, error);
      }
      final image = await inspect(partial);
      await partial.rename(completed.path);
      return ExportImageFile(completed, image.extension);
    } finally {
      try {
        await staging.delete(recursive: true);
      } on FileSystemException catch (error) {
        debugPrint('Image export staging cleanup failed: $error');
      }
    }
  }

  Future<ExportImageFile?> _usable(File file) async {
    try {
      return await inspect(file);
    } on ImageExportException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  static Future<ExportImageFile> inspect(File file) async {
    if (!await file.exists() || await file.length() == 0) {
      throw const ImageExportException(ImageExportFailure.invalidFile);
    }
    final bytes = await file.readAsBytes();
    // Use only file signatures, never an untrusted URL/filename extension.
    final mime = lookupMimeType('', headerBytes: bytes.take(64).toList());
    const extensions = {
      'image/jpeg': 'jpg',
      'image/png': 'png',
      'image/gif': 'gif',
      'image/webp': 'webp',
      'image/bmp': 'bmp',
      'image/tiff': 'tiff',
      'image/heic': 'heic',
      'image/heif': 'heif',
      'image/avif': 'avif',
    };
    final extension = extensions[mime];
    if (extension == null) {
      throw ImageExportException(
        mime?.startsWith('image/') == true
            ? ImageExportFailure.unsupported
            : ImageExportFailure.invalidFile,
      );
    }
    final complete = switch (extension) {
      'jpg' => bytes.length >= 2 &&
          bytes[bytes.length - 2] == 0xff &&
          bytes.last == 0xd9,
      'png' => bytes.length >= 12 &&
          listEquals(bytes.sublist(bytes.length - 12),
              [0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130]),
      'gif' => bytes.last == 0x3b,
      _ => true,
    };
    if (!complete) {
      throw const ImageExportException(ImageExportFailure.invalidFile);
    }
    // Validate decoding without retaining a full-resolution bitmap. Keep the
    // encoded file untouched (including animation, alpha and metadata).
    // Apple-only codecs are validated by ImageIO in the native writer.
    if (!['heic', 'heif', 'tiff', 'avif'].contains(extension)) {
      ui.Codec? codec;
      try {
        codec = await ui.instantiateImageCodec(bytes,
            targetWidth: 1, targetHeight: 1);
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } catch (error) {
        throw ImageExportException(ImageExportFailure.invalidFile, error);
      } finally {
        codec?.dispose();
      }
    }
    return ExportImageFile(file, extension);
  }
}

/// Native iOS writing owns its add-only authorization; it never reads assets.
class PhotoLibraryWriter {
  static const channel = MethodChannel('cn.honjow.eros/photos');

  static Future<void> write(File file, String name) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final result = await channel.invokeMethod<bool>('saveImage', {
          'path': file.path,
          'name': name,
        });
        if (result != true) {
          throw const ImageExportException(ImageExportFailure.write);
        }
      } else {
        final result =
            await ImageGallerySaverPlus.saveFile(file.path, name: name);
        if (result is! Map || result['isSuccess'] != true) {
          throw ImageExportException(ImageExportFailure.write, result);
        }
      }
    } on PlatformException catch (error) {
      final failure = switch (error.code) {
        'permission_denied' => ImageExportFailure.permission,
        'invalid_file' => ImageExportFailure.invalidFile,
        'unsupported_format' => ImageExportFailure.unsupported,
        'busy' => ImageExportFailure.busy,
        _ => ImageExportFailure.write,
      };
      throw ImageExportException(failure, error);
    }
  }
}

class GalleryPhotoSaver {
  GalleryPhotoSaver({
    required this.resolver,
    this.writer = PhotoLibraryWriter.write,
  });

  final GalleryImageResolver resolver;
  final Future<void> Function(File file, String name) writer;
  bool _saving = false;
  bool get isSaving => _saving;

  Future<void> save(GalleryImageSource source, {bool original = false}) async {
    if (_saving) {
      throw const ImageExportException(ImageExportFailure.busy);
    }
    _saving = true;
    Directory? staging;
    try {
      final image = await resolver.resolve(source, original: original);
      await resolver.directory.create(recursive: true);
      staging = await resolver.directory.createTemp('album-');
      final rawName = '${source.gid ?? "image"}-${source.ser ?? 0}-'
          '${path.basenameWithoutExtension(source.filename ?? "image")}';
      final safeName = String.fromCharCodes(rawName.runes.take(60))
          .replaceAll(RegExp(r'[^\w\-.\u0080-\uFFFF]'), '_');
      final name = '$safeName.${image.extension}';
      // Own the export copy until Photos finishes, even if cache is evicted.
      final exported = await image.file.copy(path.join(staging.path, name));
      await writer(exported, name);
    } on FileSystemException catch (error) {
      throw ImageExportException(ImageExportFailure.invalidFile, error);
    } finally {
      try {
        if (staging != null) {
          await staging.delete(recursive: true);
        }
      } on FileSystemException catch (error) {
        // A cleanup error must not turn a successful Photos import into a
        // reported failure and encourage a duplicate save.
        debugPrint('Album export cleanup failed: $error');
      } finally {
        _saving = false;
      }
    }
  }
}
