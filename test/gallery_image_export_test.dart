import 'dart:async';
import 'dart:io';

import 'package:eros_fe/utils/gallery_image_export.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

File fixture(String name) => File('test/fixtures/gallery_save/$name');
Matcher failure(ImageExportFailure value) =>
    isA<ImageExportException>().having((e) => e.failure, 'failure', value);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late GalleryImageResolver resolver;
  late List<String> requests;
  late Map<String, File> cache;
  late List<String?> keys;
  const currentUrl = 'https://images.invalid/current';
  const originalUrl = 'https://images.invalid/fullimg/1';
  const source = GalleryImageSource(
      gid: '12',
      ser: 3,
      url: currentUrl,
      cacheKey: 'page_xres1280',
      originalUrl: originalUrl,
      originalCacheKey: 'page_origin');

  setUp(() async {
    root = await Directory.systemTemp.createTemp('gallery-save-test-');
    requests = [];
    keys = [];
    cache = {};
    resolver = GalleryImageResolver(
        directory: root,
        cacheLookup: (url, key) async {
          keys.add(key);
          return cache[key ?? url];
        },
        download: (url, destination) async {
          requests.add(url);
          await fixture(url == originalUrl ? 'original.jpg' : 'current.png')
              .copy(destination);
        });
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await root.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PhotoLibraryWriter.channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('image_gallery_saver_plus'), null);
  });

  test('custom viewer cache key hits with zero network requests', () async {
    cache['page_xres1280'] = fixture('current.png');
    final image = await resolver.resolve(source);
    expect(image.file.path, fixture('current.png').path);
    expect(keys, ['page_xres1280']);
    expect(requests, isEmpty);
  });

  test('actual displayed local and temporary files precede network cache',
      () async {
    for (final local in [true, false]) {
      final image = await resolver.resolve(GalleryImageSource(
          url: currentUrl,
          filePath: local ? fixture('current.png').path : '',
          tempPath: fixture('original.jpg').path));
      expect(image.extension, local ? 'png' : 'jpg');
    }
    expect(keys, isEmpty);
    expect(requests, isEmpty);
  });

  test('original request cannot reuse resampled local, temporary or disk cache',
      () async {
    cache['page_xres1280'] = fixture('current.png');
    final image = await resolver.resolve(
        GalleryImageSource(
            gid: '12',
            ser: 3,
            url: currentUrl,
            cacheKey: 'page_xres1280',
            filePath: fixture('current.png').path,
            tempPath: fixture('current.png').path,
            originalUrl: originalUrl,
            originalCacheKey: 'page_origin'),
        original: true);
    expect(image.extension, 'jpg');
    expect(await image.file.readAsBytes(),
        await fixture('original.jpg').readAsBytes());
    expect(requests, [originalUrl]);
    expect(keys, ['page_origin']);
  });

  test('original cache and a proven identical current source avoid downloading',
      () async {
    cache['page_origin'] = fixture('original.jpg');
    await resolver.resolve(source, original: true);
    final same = GalleryImageSource(
        url: originalUrl,
        originalUrl: originalUrl,
        filePath: fixture('original.jpg').path);
    expect(same.hasSeparateOriginal, isFalse);
    await resolver.resolve(same, original: true);
    expect(requests, isEmpty);
    expect(source.hasSeparateOriginal, isTrue);
    expect(
        const GalleryImageSource(url: currentUrl).hasSeparateOriginal, isFalse);
  });

  test('unrelated temp files and partial downloads are never selected',
      () async {
    await File('${root.path}/unrelated.jpg').writeAsString('not an image');
    await File('${root.path}/image.part')
        .writeAsBytes(await fixture('original.jpg').readAsBytes());
    final image = await resolver.resolve(source);
    expect(await image.file.readAsBytes(),
        await fixture('current.png').readAsBytes());
    expect(requests, [currentUrl]);
    await resolver.resolve(source);
    expect(requests, [currentUrl],
        reason: 'validated completed download is reusable');
  });

  test(
      'corrupt cache falls back to download; HTML is rejected and never committed',
      () async {
    cache['page_xres1280'] =
        await File('${root.path}/corrupt').writeAsString('<html>Error</html>');
    await resolver.resolve(source);
    expect(requests, [currentUrl]);
    final bad = GalleryImageResolver(
        directory: root,
        cacheLookup: (_, __) async => null,
        download: (_, destination) async {
          await File(destination).writeAsString('<html>Login</html>');
        });
    await expectLater(
        bad.resolve(const GalleryImageSource(url: 'https://invalid/html')),
        throwsA(failure(ImageExportFailure.invalidFile)));
    expect(
        await root
            .list(recursive: true)
            .where((f) => f.path.endsWith('.part'))
            .length,
        0);
  });

  test('interrupted downloads are removed and retry fetches again', () async {
    var attempts = 0;
    final flaky = GalleryImageResolver(
        directory: root,
        cacheLookup: (_, __) async => null,
        download: (_, destination) async {
          attempts++;
          await fixture('current.png').copy(destination);
          if (attempts == 1) {
            throw const HttpException('connection lost');
          }
        });
    await expectLater(
        flaky.resolve(source), throwsA(failure(ImageExportFailure.download)));
    await flaky.resolve(source);
    expect(attempts, 2);
    expect(
        await root
            .list(recursive: true)
            .where((f) => f.path.endsWith('.part'))
            .length,
        0);
  });

  test(
      'truncated but recognizable images fall back rather than saving partial data',
      () async {
    final bytes = await fixture('current.png').readAsBytes();
    cache['page_xres1280'] = await File('${root.path}/truncated.png')
        .writeAsBytes(bytes.sublist(0, bytes.length - 12));
    final image = await resolver.resolve(source);
    expect(requests, [currentUrl]);
    expect(await image.file.readAsBytes(), bytes);
  });

  test('local gallery with no valid file fails without downloading', () async {
    await expectLater(
        resolver.resolve(const GalleryImageSource(
            isLocal: true, filePath: '/missing', url: currentUrl)),
        throwsA(failure(ImageExportFailure.invalidFile)));
    expect(requests, isEmpty);
  });

  test('simultaneous requests for same image share one download', () async {
    final results =
        await Future.wait([resolver.resolve(source), resolver.resolve(source)]);
    expect(requests.length, 1);
    expect(results.first.file.path, results.last.file.path);
  });

  for (final name in ['current.png', 'original.jpg', 'animated.gif']) {
    test(
        'exports $name byte for byte, holds copy until callback, preserves source',
        () async {
      final bytes = await fixture(name).readAsBytes();
      final done = Completer<void>();
      final entered = Completer<void>();
      late File export;
      final saver = GalleryPhotoSaver(
          resolver: resolver,
          writer: (file, _) async {
            export = file;
            expect(await file.readAsBytes(), bytes);
            entered.complete();
            await done.future;
            expect(await file.exists(), isTrue);
          });
      final pending = saver.save(
          GalleryImageSource(filePath: fixture(name).path, isLocal: true));
      await entered.future;
      await expectLater(
          saver.save(source), throwsA(failure(ImageExportFailure.busy)));
      done.complete();
      await pending;
      expect(await export.exists(), isFalse);
      expect(await fixture(name).readAsBytes(), bytes);
    });
  }

  test(
      'failed write cleans up export, resets guard and does not report success',
      () async {
    var fail = true;
    late File export;
    final saver = GalleryPhotoSaver(
        resolver: resolver,
        writer: (file, _) async {
          export = file;
          if (fail) {
            throw const ImageExportException(ImageExportFailure.permission);
          }
        });
    final local = GalleryImageSource(
        filePath: fixture('current.png').path, isLocal: true);
    await expectLater(
        saver.save(local), throwsA(failure(ImageExportFailure.permission)));
    expect(await export.exists(), isFalse);
    fail = false;
    await saver.save(local);
  });

  test('native writer uses file import, returns only after native success',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final done = Completer<bool>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PhotoLibraryWriter.channel, (call) {
      expect(call.method, 'saveImage');
      expect(call.arguments, {'path': 'a.png', 'name': 'a.png'});
      return done.future;
    });
    var completed = false;
    final pending = PhotoLibraryWriter.write(File('a.png'), 'a.png')
        .then((_) => completed = true);
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    done.complete(true);
    await pending;
    expect(completed, isTrue);
  });

  for (final item in {
    'permission_denied': ImageExportFailure.permission,
    'invalid_file': ImageExportFailure.invalidFile,
    'unsupported_format': ImageExportFailure.unsupported,
    'write_failed': ImageExportFailure.write
  }.entries) {
    test('native ${item.key} stays distinct with its original error details',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PhotoLibraryWriter.channel, (_) async {
        throw PlatformException(
            code: item.key, details: {'domain': 'Photos', 'code': 42});
      });
      await expectLater(PhotoLibraryWriter.write(File('a.png'), 'a.png'),
          throwsA(failure(item.value)));
    });
  }

  test('Android retains saveFile and checks explicit plugin success', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var success = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('image_gallery_saver_plus'), (call) async {
      expect(call.method, 'saveFileToGallery');
      expect((call.arguments as Map)['file'], 'image.png');
      return {'isSuccess': success};
    });
    await expectLater(PhotoLibraryWriter.write(File('image.png'), 'image.png'),
        throwsA(failure(ImageExportFailure.write)));
    success = true;
    await PhotoLibraryWriter.write(File('image.png'), 'image.png');
  });
}
