import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:eros_fe/common/epub/epub_builder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('archive isolate returns after every file and the central directory',
      () async {
    final root = await Directory.systemTemp.createTemp('eros-export-archive-');
    try {
      final input = await Directory('${root.path}/input').create();
      final first = List<int>.generate(128 * 1024, (i) => i % 251);
      final second = List<int>.generate(128 * 1024, (i) => i % 239);
      await File('${input.path}/first.bin').writeAsBytes(first);
      await File('${input.path}/second.bin').writeAsBytes(second);
      final output = File('${root.path}/fixture.epub');
      await compute(isolateCompactDirToZip, [output.path, input.path]);
      final archive = ZipDecoder().decodeBytes(await output.readAsBytes());
      expect(archive.files.map((file) => file.name).toSet(),
          {'first.bin', 'second.bin'});
      expect(archive.findFile('first.bin')!.content, first);
      expect(archive.findFile('second.bin')!.content, second);
    } finally {
      await root.delete(recursive: true);
    }
  });
}
