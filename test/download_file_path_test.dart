import 'package:eros_fe/common/controller/download/download_cover_resolver.dart';
import 'package:eros_fe/common/controller/download/download_file_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds a regular downloaded file path', () {
    expect(
      buildDownloadFilePath(
        directoryPath: '/Documents/Download/123 - gallery',
        fileName: '0001.jpg',
      ),
      '/Documents/Download/123 - gallery/0001.jpg',
    );
  });

  test('builds a SAF file URI without duplicating the separator', () {
    expect(
      buildDownloadFilePath(
        directoryPath: 'content://downloads/tree/primary%3ADownload',
        fileName: '0001.jpg',
      ),
      'content://downloads/tree/primary%3ADownload%2F0001.jpg',
    );
    expect(
      buildDownloadFilePath(
        directoryPath: 'content://downloads/tree/primary%3ADownload%2F',
        fileName: '0001.jpg',
      ),
      'content://downloads/tree/primary%3ADownload%2F0001.jpg',
    );
  });

  test('returns null when either path component is missing', () {
    expect(
      buildDownloadFilePath(directoryPath: null, fileName: '0001.jpg'),
      isNull,
    );
    expect(
      buildDownloadFilePath(directoryPath: '/Documents/Download', fileName: ''),
      isNull,
    );
  });

  test('prefers an available image task cover over stale gallery metadata',
      () async {
    final available = {'0001.jpg'};

    final result = await resolveDownloadCoverImageFileName(
      candidates: ['0001.jpg', 'old-cover.jpg'],
      isAvailable: (fileName) async => available.contains(fileName),
    );

    expect(result, '0001.jpg');
  });

  test('falls back to the persisted cover when the image task is unavailable',
      () async {
    final result = await resolveDownloadCoverImageFileName(
      candidates: [null, '', 'missing.jpg', '0002.jpg', '0002.jpg'],
      isAvailable: (fileName) async => fileName == '0002.jpg',
    );

    expect(result, '0002.jpg');
  });
}
