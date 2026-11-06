import 'dart:io';

import 'package:eros_fe/common/controller/download/storage_adapter.dart';
import 'package:eros_fe/common/global.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('first-run directory creation completes before returning', () async {
    final root = await Directory.systemTemp.createTemp('eros-first-run-');
    final originalDocPath = Global.appDocPath;
    addTearDown(() async {
      Global.appDocPath = originalDocPath;
      await root.delete(recursive: true);
    });
    Global.appDocPath = path.join(root.path, 'documents');

    await Global.createDirs();
    expect(
      await Directory(path.join(Global.appDocPath, 'Download')).exists(),
      isTrue,
    );
    await Global.createDirs();
  });

  test('restore skips missing directories and keeps existing paths', () async {
    final root = await Directory.systemTemp.createTemp('eros-restore-root-');
    addTearDown(() => root.delete(recursive: true));
    final storage = StorageAdapter();
    final callbacks = <String>[];
    void found(File info, String directory) => callbacks.add(directory);
    final missing = path.join(root.path, 'missing', 'Download');

    await storage.restoreGalleryTasksWithPath(missing, found);
    expect(callbacks, isEmpty);
    expect(await Directory(missing).exists(), isFalse);

    final gallery = await Directory(path.join(root.path, 'existing', '123'))
        .create(recursive: true);
    await File(path.join(gallery.path, '.info')).writeAsString('{}');
    await storage.restoreGalleryTasksWithPath(
      path.join(root.path, 'existing'),
      found,
    );
    expect(callbacks, <String>[gallery.path]);
  });

  test('restore propagates errors raised by its callback', () async {
    final root = await Directory.systemTemp.createTemp('eros-restore-error-');
    addTearDown(() => root.delete(recursive: true));
    final gallery = await Directory(path.join(root.path, '123')).create();
    await File(path.join(gallery.path, '.info')).writeAsString('{}');

    await expectLater(
      StorageAdapter().restoreGalleryTasksWithPath(
        root.path,
        (File info, String directory) =>
            throw PathNotFoundException(info.path, const OSError('test', 2)),
      ),
      throwsA(isA<PathNotFoundException>()),
    );
  });

  for (final missing in [true, false]) {
    test(
      missing
          ? 'restore ignores a directory disappearing during listing'
          : 'restore propagates other directory listing errors',
      () async {
        final error = missing
            ? PathNotFoundException('/download', const OSError('missing', 2))
            : FileSystemException(
                'permission denied',
                '/download',
                const OSError('permission denied', 13),
              );
        final directory = _ListingErrorDirectory(error);
        var callbackCount = 0;

        final restore = IOOverrides.runZoned(
          () => StorageAdapter().restoreGalleryTasksWithPath(
            '/download',
            (File info, String directory) => callbackCount++,
          ),
          createDirectory: (_) => directory,
        );

        if (missing) {
          await expectLater(restore, completes);
        } else {
          await expectLater(restore, throwsA(same(error)));
        }
        expect(directory.operations, ['exists', 'list']);
        expect(callbackCount, 0);
      },
    );
  }
}

/// Simulates a directory removed, or made unreadable, after its existence check.
class _ListingErrorDirectory implements Directory {
  _ListingErrorDirectory(this.error);

  final FileSystemException error;
  final operations = <String>[];

  @override
  Future<bool> exists() async {
    operations.add('exists');
    return true;
  }

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) {
    operations.add('list');
    return Stream<FileSystemEntity>.error(error);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
