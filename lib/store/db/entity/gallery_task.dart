import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:eros_fe/common/global.dart';
import 'package:get/get.dart';
import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:path/path.dart' as path;

part 'gallery_task.g.dart';

@CopyWith()
@JsonSerializable()
@Collection()
class GalleryTask {
  GalleryTask({
    required this.gid,
    required this.token,
    this.url,
    required this.title,
    required this.dirPath,
    required this.fileCount,
    this.completCount,
    this.status,
    this.coverImage,
    this.addTime,
    this.coverUrl,
    this.rating,
    this.category,
    this.uploader,
    this.jsonString,
    this.tag,
    this.downloadOrigImage,
    this.showKey,
  });

  factory GalleryTask.fromJson(Map<String, dynamic> json) =>
      _$GalleryTaskFromJson(json);

  Map<String, dynamic> toJson() => _$GalleryTaskToJson(this);

  // @primaryKey
  @Index(unique: true, replace: true)
  final Id gid;
  final String token;
  final String? url;
  final String title;
  final String? dirPath;
  final int fileCount;
  final int? completCount;
  final int? status;
  final String? coverImage;
  final int? addTime;
  final String? coverUrl;
  final double? rating;
  final String? category;
  final String? uploader;
  final String? jsonString;
  final String? tag;
  final bool? downloadOrigImage;
  final String? showKey;

  String? get realDirPath {
    if (dirPath == null) {
      return dirPath;
    }
    if (!GetPlatform.isIOS || dirPath!.startsWith('content://')) {
      return dirPath;
    }

    final storedPath = path.normalize(dirPath!);
    final appDocPath = path.normalize(Global.appDocPath);

    // Restored .info files contain an absolute path. Keep it when it already
    // belongs to this installation; only rewrite paths from an old container.
    if (path.isAbsolute(storedPath) &&
        appDocPath.isNotEmpty &&
        (storedPath == appDocPath ||
            storedPath.startsWith('$appDocPath${path.separator}'))) {
      return storedPath;
    }

    final pathList = path.split(storedPath);
    if (pathList.length < 2) {
      return path.join(Global.appDocPath, storedPath);
    }

    // iOS stores the default download path relative to Documents. Rebuild it
    // from the final two components so paths remain valid after reinstall.
    return path.join(
      Global.appDocPath,
      pathList[pathList.length - 2],
      pathList.last,
    );
  }

  @override
  String toString() {
    return 'GalleryTask{gid: $gid, token: $token, url: $url, title: $title, dirPath: $dirPath, fileCount: $fileCount, completCount: $completCount, status: $status, coverImage: $coverImage, addTime: $addTime, coverUrl: $coverUrl, rating: $rating, category: $category, uploader: $uploader, jsonString: $jsonString, tag: $tag, downloadOrigImage: $downloadOrigImage, showKey: $showKey}';
  }
}
