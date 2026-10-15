import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/debug/offline_acceptance.dart';
import 'package:flutter_socks_proxy/socks_proxy.dart';
import 'package:path/path.dart' as p;

/// Account ownership is captured by the caller before any asynchronous work.
class AvatarStore {
  AvatarStore._();

  static const maxBytes = 9000000;

  /// iOS can relocate the data container when installing an updated app.
  /// Recover only this store's owned copies under the current support directory.
  static String resolveLocalPath(String value) {
    const marker = '/Library/Application Support/avatars/';
    final markerIndex = value.indexOf(marker);
    if (markerIndex < 0 || Global.appSupportPath.isEmpty) {
      return value;
    }
    final relative = value.substring(markerIndex + marker.length);
    if (!RegExp(r'^avatar_[A-Za-z0-9_-]+/avatar\.(jpg|png|gif|webp)$')
        .hasMatch(relative)) {
      return value;
    }
    final candidate = p.join(Global.appSupportPath, 'avatars', relative);
    return File(candidate).existsSync() ? candidate : value;
  }

  static Uri imageUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !<String>{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Enter an http(s) image URL');
    }
    return uri;
  }

  static Future<Directory> avatarDir() async {
    return Directory(p.join(Global.appSupportPath, 'avatars'))
        .create(recursive: true);
  }

  static Future<String> validateImage(String path) async {
    final file = File(path);
    final length = await file.length();
    if (length == 0 || length > maxBytes) {
      throw const FormatException('Avatar must be between 1 byte and 9 MB');
    }
    final bytes = await file.readAsBytes();
    String? ext;
    if (bytes.length >= 8 &&
        bytes.take(8).join(',') == '137,80,78,71,13,10,26,10') {
      ext = '.png';
    } else if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      ext = '.jpg';
    } else if (bytes.length >= 6 &&
        String.fromCharCodes(bytes.take(6)).startsWith('GIF8')) {
      ext = '.gif';
    } else if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
        String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
      ext = '.webp';
    }
    if (ext == null) {
      throw const FormatException('Choose a JPEG, PNG, GIF or WebP image');
    }
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 512);
    try {
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } finally {
      codec.dispose();
    }
    return ext;
  }

  static Future<String> saveFromFile(String sourcePath,
      {required String memberId}) async {
    final ext = await validateImage(sourcePath);
    final dir = await avatarDir();
    final owner = memberId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final target = await dir.createTemp('avatar_${owner}_');
    try {
      final result =
          await File(sourcePath).copy(p.join(target.path, 'avatar$ext'));
      return result.path;
    } catch (_) {
      await target.delete(recursive: true);
      rethrow;
    }
  }

  static Future<String> saveFromUrl(String url,
      {required String memberId}) async {
    final temporary = await downloadToTemp(url, memberId: memberId);
    try {
      return await saveFromFile(temporary, memberId: memberId);
    } finally {
      await File(temporary).parent.delete(recursive: true);
    }
  }

  static Future<String> downloadToTemp(String url,
      {required String memberId}) async {
    final dir = await Directory.systemTemp.createTemp('eros-avatar-');
    final target = p.join(dir.path, 'image');
    try {
      await downloadToFile(url, target);
      final ext = await validateImage(target);
      return (await File(target).rename(p.join(dir.path, 'image$ext'))).path;
    } catch (_) {
      await dir.delete(recursive: true);
      rethrow;
    }
  }

  static Future<void> downloadToFile(String url, String savePath,
      {Dio? client}) async {
    final uri = imageUri(url);
    // User-supplied image URLs must never receive forum credentials or cookies.
    final http = client ??
        Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ));
    if (client == null) {
      http.httpClientAdapter = offlineAcceptanceEnabled
          ? OfflineAcceptanceAdapter()
          : IOHttpClientAdapter(createHttpClient: () {
              final transport = createProxyHttpClient();
              transport.findProxy = (_) => globalDioConfig.proxy ?? 'DIRECT';
              return transport;
            });
    }
    final cancelToken = CancelToken();
    try {
      final response = await http.download(uri.toString(), savePath,
          cancelToken: cancelToken, onReceiveProgress: (count, total) {
        if (count > maxBytes || total > maxBytes) {
          cancelToken.cancel('Avatar exceeds 9 MB');
        }
      });
      if (response.statusCode != 200) {
        throw const FormatException('Image download failed');
      }
      await validateImage(savePath);
    } catch (_) {
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    } finally {
      if (client == null) {
        http.close(force: true);
      }
    }
  }
}
