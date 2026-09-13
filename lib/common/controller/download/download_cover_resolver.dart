/// Returns the first non-empty downloaded cover name whose file is available.
///
/// The image task is the source of truth for newly written downloads. The
/// persisted gallery cover is kept as a fallback for older task records.
Future<String?> resolveDownloadCoverImageFileName({
  required Iterable<String?> candidates,
  required Future<bool> Function(String fileName) isAvailable,
}) async {
  final checked = <String>{};
  for (final fileName in candidates) {
    if (fileName == null || fileName.isEmpty || !checked.add(fileName)) {
      continue;
    }
    if (await isAvailable(fileName)) {
      return fileName;
    }
  }
  return null;
}
