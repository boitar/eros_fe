import 'package:path/path.dart' as path;

/// Builds the path used by both local-file and SAF-backed downloads.
String? buildDownloadFilePath({
  required String? directoryPath,
  required String? fileName,
}) {
  if (directoryPath == null ||
      directoryPath.isEmpty ||
      fileName == null ||
      fileName.isEmpty) {
    return null;
  }

  if (directoryPath.startsWith('content://')) {
    final separator = directoryPath.endsWith('%2F') ? '' : '%2F';
    return '$directoryPath$separator$fileName';
  }

  return path.join(directoryPath, fileName);
}
