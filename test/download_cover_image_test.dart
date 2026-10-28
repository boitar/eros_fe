import 'dart:convert';
import 'dart:io';

import 'package:eros_fe/pages/item/download_gallery_item.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('eros-cover-test-');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  Future<void> mount(WidgetTester tester, String path) async {
    await tester.pumpWidget(CupertinoApp(
      builder: (_, __) => Center(
        child: SizedBox(
          height: 120,
          child: DownloadItemCoverImage(filePath: path),
        ),
      ),
    ));
    final availability = find.byType(FutureBuilder<bool>);
    var checked = availability.evaluate().isEmpty;
    bool? exists;
    if (availability.evaluate().isNotEmpty) {
      final check = tester.widget<FutureBuilder<bool>>(availability).future;
      check!.then((available) {
        exists = available;
        checked = true;
      });
    }
    for (var attempt = 0; attempt < 30; attempt++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      final image = find.byType(ExtendedImage);
      if (checked &&
          (exists == false ||
              (image.evaluate().isNotEmpty &&
                  (tester.state(image) as ExtendedImageState)
                          .extendedImageLoadState !=
                      LoadState.loading))) {
        return;
      }
    }
    fail('Local cover did not finish checking/loading');
  }

  testWidgets('a missing local cover falls back without an image stream error',
      (tester) async {
    final file = File('${directory.path}/missing.png');
    await mount(tester, file.path);
    expect(tester.takeException(), isNull);
    expect(find.byIcon(CupertinoIcons.photo), findsOneWidget);
    expect(find.byType(ExtendedImage), findsNothing);
    expect(file.existsSync(), isFalse);
  });

  testWidgets('a cover arriving later at the same path is rechecked',
      (tester) async {
    final file = File('${directory.path}/later.png');
    await mount(tester, file.path);
    expect(tester.takeException(), isNull);
    file.writeAsBytesSync(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8'
      '/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
    ));
    expect(file.existsSync(), isTrue);
    await mount(tester, file.path);
    expect(tester.takeException(), isNull);
    expect(find.byType(ExtendedImage), findsOneWidget);
    final state =
        tester.state(find.byType(ExtendedImage)) as ExtendedImageState;
    expect(state.extendedImageLoadState, LoadState.completed);
  });
}
