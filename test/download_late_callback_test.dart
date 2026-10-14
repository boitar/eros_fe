import 'dart:async';

import 'package:dio/dio.dart';
import 'package:eros_fe/common/controller/cache_controller.dart';
import 'package:eros_fe/common/controller/download/image_download_processor.dart';
import 'package:eros_fe/common/controller/download/resumable_file_downloader.dart';
import 'package:eros_fe/common/controller/download_state.dart';
import 'package:eros_fe/models/gallery_image.dart';
import 'package:flutter_test/flutter_test.dart';

class _UnusedCache implements CacheController {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('The controlled worker must not access cache services');
}

class _LateWorker extends ImageDownloadProcessor {
  _LateWorker(DownloadState state)
      : super(state, _UnusedCache(), downloader: ResumableFileDownloader(Dio()));

  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<ImageDownloadInfo> getImageDownloadInfo(
    GalleryImage preImage,
    dynamic imageTask,
    int gid,
    int maxSer, {
    bool downloadOrigImage = false,
    bool reDownload = false,
    CancelToken? cancelToken,
    String? showKey,
    Function? updateShowKeyCallback,
    Function? addAllImagesCallback,
    Function? putImageTaskCallback,
  }) async =>
      ImageDownloadInfo(
        imageUrl: 'https://example.invalid/image.jpg',
        updatedImage: preImage,
        fileNameWithoutExtension: '1',
      );

  @override
  Future<void> downloadToPath(
    String url,
    String parentPath,
    String fileNameWithoutExtension, {
    required int gid,
    String? fileExtension,
    CancelToken? cancelToken,
    Future<void> Function(String fileName)? onDownloadCompleteWithFileName,
    ProgressCallback? progressCallback,
  }) async {
    started.complete();
    await release.future;
    progressCallback?.call(12, 12);
    await onDownloadCompleteWithFileName?.call('1.jpg');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final action in ['cancelled', 'replaced', 'active']) {
    test('a $action worker cannot corrupt a newer attempt', () async {
      final state = DownloadState();
      final token = CancelToken();
      state.cancelTokenMap[1] = token;
      final worker = _LateWorker(state);
      final writes = <String>[];
      final future = worker.downloadImageFlow(
        const GalleryImage(ser: 1),
        null,
        1,
        '/unused-fixture-path',
        2,
        cancelToken: token,
        putImageTaskCallback: (gid, image, file, status) async =>
            writes.add('image:$file:$status'),
        onDownloadCompleteWithFileName: (file) async =>
            writes.add('gallery:$file'),
      );
      await worker.started.future;
      if (action == 'active') {
        worker.release.complete();
        await future;
        expect(writes, ['image:1.jpg:3', 'gallery:1.jpg']);
        expect(state.downloadCounts['1_1'], 12);
      } else {
        final checked = expectLater(
          future,
          throwsA(isA<DioException>().having(
              (error) => error.type, 'type', DioExceptionType.cancel)),
        );
        if (action == 'cancelled') {
          token.cancel();
        } else {
          state.cancelTokenMap[1] = CancelToken();
        }
        worker.release.complete();
        await checked;
        expect(writes, isEmpty);
        expect(state.downloadCounts, isEmpty);
      }
    });
  }
}
