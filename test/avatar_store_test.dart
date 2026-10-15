import 'dart:io';

import 'package:dio/dio.dart';
import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/models/index.dart';
import 'package:eros_fe/utils/avatar_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/avatar_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late String oldSupport;
  late File source;
  setUp(() async {
    HttpOverrides.global = null;
    dir = await Directory.systemTemp.createTemp('avatar-store-test-');
    oldSupport = Global.appSupportPath;
    Global.appSupportPath = dir.path;
    source =
        await File('${dir.path}/misnamed.jpg').writeAsBytes(neutralAvatarPng);
  });
  tearDown(() async {
    Global.appSupportPath = oldSupport;
    await dir.delete(recursive: true);
  });
  test(
      'validates actual bytes and makes distinct account-scoped persistent copies',
      () async {
    final paths = await Future.wait([
      AvatarStore.saveFromFile(source.path, memberId: 'a'),
      AvatarStore.saveFromFile(source.path, memberId: 'a'),
      AvatarStore.saveFromFile(source.path, memberId: 'b'),
    ]);
    expect(paths.toSet().length, 3);
    expect(paths[0], contains('avatar_a_'));
    expect(paths[2], contains('avatar_b_'));
    for (final path in paths) {
      expect(path, endsWith('.png'));
      expect(await File(path).readAsBytes(), neutralAvatarPng);
    }
    await source.delete();
    expect(await File(paths[0]).exists(), true);
  });
  test('empty, missing, non-image and corrupt image files are rejected',
      () async {
    for (final bytes in [
      <int>[],
      [1, 2, 3],
      [...neutralAvatarPng.take(20)]
    ]) {
      await source.writeAsBytes(bytes);
      await expectLater(AvatarStore.saveFromFile(source.path, memberId: 'a'),
          throwsA(anything));
    }
    await expectLater(
        AvatarStore.saveFromFile('${dir.path}/missing.png', memberId: 'a'),
        throwsA(anything));
    expect(await Directory('${dir.path}/avatars').exists(), false);
  });
  test('oversize image is rejected before creating a persistent copy',
      () async {
    await source.writeAsBytes(List.filled(AvatarStore.maxBytes + 1, 0));
    await expectLater(AvatarStore.saveFromFile(source.path, memberId: 'a'),
        throwsFormatException);
  });
  test('rejects empty, relative, credentialed and non-http image URLs', () {
    for (final value in [
      '',
      'photo.png',
      'file:///tmp/photo.png',
      'https://',
      'https://user:password@example.test/a'
    ]) {
      expect(() => AvatarStore.imageUri(value), throwsFormatException);
    }
    expect(AvatarStore.imageUri(' https://example.test/a.png?x=1 ').host,
        'example.test');
  });
  test('owned iOS avatar paths survive a changed data-container UUID',
      () async {
    final saved = await AvatarStore.saveFromFile(source.path, memberId: 'a');
    final relative = saved.substring('${dir.path}/avatars/'.length);
    final old =
        '/old/Application/OLD/Library/Application Support/avatars/$relative';
    expect(AvatarStore.resolveLocalPath(old), saved);
    expect(AvatarStore.resolveLocalPath(saved), saved);
    const unrelated = '/old/Application/OLD/Documents/other.png';
    expect(AvatarStore.resolveLocalPath(unrelated), unrelated);
    await File(saved).delete();
    expect(AvatarStore.resolveLocalPath(old), old);
  });
  test('real local HTTP download validates bytes and removes failed output',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (request.uri.path == '/ok') {
        request.response.add(neutralAvatarPng);
      } else if (request.uri.path == '/missing') {
        request.response.statusCode = 404;
      } else {
        request.response.write('<html>not an image</html>');
      }
      await request.response.close();
    });
    final client = Dio();
    final output = '${dir.path}/download.png';
    try {
      final base = 'http://127.0.0.1:${server.port}';
      await AvatarStore.downloadToFile('$base/ok', output, client: client);
      expect(await File(output).readAsBytes(), neutralAvatarPng);
      final profile = Global.profile;
      try {
        Global.profile = profile.copyWith(
            user: const User(
                memberId: 'offline-only', passHash: 'never-send-this-fixture'));
        await AvatarStore.downloadToFile('$base/ok', output);
        expect(await File(output).readAsBytes(), neutralAvatarPng);
      } finally {
        Global.profile = profile;
      }
      await File(output).delete();
      for (final path in ['/bad', '/missing']) {
        await expectLater(
            AvatarStore.downloadToFile('$base$path', output, client: client),
            throwsA(anything));
        expect(await File(output).exists(), false);
      }
    } finally {
      client.close(force: true);
      await server.close(force: true);
    }
  });
}
