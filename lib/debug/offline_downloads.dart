import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/debug/offline_acceptance.dart';
import 'package:eros_fe/store/db/entity/gallery_image_task.dart';
import 'package:eros_fe/store/db/entity/gallery_task.dart';
import 'package:path/path.dart' as path;

Future<void> initializeOfflineDownloads() async {
  if (!offlineAcceptanceEnabled ||
      !const bool.fromEnvironment('EROS_DOWNLOAD_ACCEPTANCE')) {
    return;
  }
  if (const bool.fromEnvironment('EROS_DUO_ACCEPTANCE')) {
    await _initializeDuoReaderFixture();
    await _initializeDuoContinuousReaderFixture();
  }
  const fixtureFolder = 'offline-native-fixture-v2';
  final root = path.join(Global.appDocPath, fixtureFolder);
  for (final index in [1, 2, 3]) {
    final gid = 9311000 + index;
    // Never replace existing records or bytes, including prior test runs.
    if (await isarHelper.findGalleryTaskByGid(gid) != null) {
      continue;
    }
    final directory = Directory(path.join(root, '$gid'));
    final present = index != 2;
    if (present) {
      await directory.create(recursive: true);
      final cover = File(path.join(directory.path, '1.png'));
      if (!await cover.exists()) {
        await cover.writeAsBytes(base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8'
          '/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
        ));
      }
    }
    final title = index == 1
        ? 'Offline v2 downloaded fixture 1'
        : index == 2
            ? 'Offline v2 missing files fixture 2'
            : 'Offline v2 paused fixture 3';
    await isarHelper.putGalleryTask(GalleryTask(
      gid: gid,
      token: 'offline-fixture',
      title: title,
      // Match the production iOS two-component relative download layout.
      // Absolute nested fixture paths become stale after simulator reinstall.
      dirPath:
          Platform.isIOS ? path.join(fixtureFolder, '$gid') : directory.path,
      fileCount: index == 3 ? 2 : 1,
      completCount: 1,
      status: index == 3 ? 6 : 3,
      coverImage: '1.png',
      uploader: 'Neutral fixture with a deliberately long uploader name',
      addTime: 1767225610000 + index,
    ));
    await isarHelper.putImageTask(GalleryImageTask(
      gid: gid,
      token: 'offline-image',
      ser: 1,
      filePath: '1.png',
      status: 3,
    ));
    if (index == 3) {
      await isarHelper.putImageTask(GalleryImageTask(
        gid: gid,
        token: 'offline-missing-image',
        ser: 2,
        status: 6,
      ));
    }
  }
}

Future<void> _initializeDuoContinuousReaderFixture() async {
  const gid = 9333002;
  const folder = 'offline-duo-continuous-reader-v1';
  if (await isarHelper.findGalleryTaskByGid(gid) != null) return;
  final directory = Directory(path.join(Global.appDocPath, folder, '$gid'));
  await directory.create(recursive: true);
  for (var page = 1; page <= 9; page++) {
    const width = 720;
    final height = page == 6 ? 7200 : 1080;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xfffaf9f6), ui.BlendMode.src);
    final size = ui.Size(width.toDouble(), height.toDouble());
    canvas.drawRect(
      (ui.Offset.zero & size).deflate(24),
      ui.Paint()
        ..color = const ui.Color(0xff32332f)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    for (var band = 0; band * 720 < height; band++) {
      final y = band * 720.0;
      final text = (ui.ParagraphBuilder(ui.ParagraphStyle(
        fontSize: 38,
        textAlign: ui.TextAlign.center,
      ))
            ..pushStyle(ui.TextStyle(color: const ui.Color(0xff242724)))
            ..addText('OFFLINE CONTINUOUS FIXTURE\n'
                'PAGE $page / 9\nBAND ${band + 1}\n'
                'Original pixels remain unchanged.'))
          .build()
        ..layout(const ui.ParagraphConstraints(width: width - 96));
      canvas.drawParagraph(text, ui.Offset(48, y + 120));
      if (band > 0) {
        canvas.drawLine(ui.Offset(32, y), ui.Offset(width - 32, y),
            ui.Paint()..color = const ui.Color(0xff326758));
      }
    }
    for (final point in [
      const ui.Offset(40, 40),
      const ui.Offset(width - 40, 40),
      ui.Offset(40, height - 40),
      ui.Offset(width - 40, height - 40),
    ]) {
      canvas.drawCircle(
          point, 10, ui.Paint()..color = const ui.Color(0xff326758));
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path.join(directory.path, '$page.png'));
    if (!await file.exists() && data != null) {
      await file.writeAsBytes(data.buffer.asUint8List());
    }
    image.dispose();
    picture.dispose();
    await isarHelper.putImageTask(GalleryImageTask(
      gid: gid,
      token: 'offline-duo-continuous-$page',
      ser: page,
      filePath: '$page.png',
      status: 3,
    ));
  }
  await isarHelper.putGalleryTask(GalleryTask(
    gid: gid,
    token: 'offline-duo-continuous',
    title: 'Offline Duo continuous fixture (9 pages)',
    dirPath: Platform.isIOS ? path.join(folder, '$gid') : directory.path,
    fileCount: 9,
    completCount: 9,
    status: 3,
    coverImage: '1.png',
    uploader: 'Neutral local long-image acceptance',
    addTime: 1767225610200,
  ));
}

/// Synthetic local files exercise the real downloaded-content reader. They
/// never replace existing tasks, user files, image loaders, or navigation.
Future<void> _initializeDuoReaderFixture() async {
  const gid = 9333001;
  const folder = 'offline-duo-reader-v1';
  if (await isarHelper.findGalleryTaskByGid(gid) != null) return;
  final directory = Directory(path.join(Global.appDocPath, folder, '$gid'));
  await directory.create(recursive: true);
  for (var page = 1; page <= 11; page++) {
    final width = page == 4 ? 1100 : 720;
    final height = page == 4 ? 720 : 1080;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final size = ui.Size(width.toDouble(), height.toDouble());
    canvas.drawColor(const ui.Color(0xfffaf9f6), ui.BlendMode.src);
    canvas.drawRect(
      (ui.Offset.zero & size).deflate(24),
      ui.Paint()
        ..color = const ui.Color(0xff32332f)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    final text = (ui.ParagraphBuilder(ui.ParagraphStyle(
      fontSize: 54,
      textAlign: ui.TextAlign.center,
    ))
          ..pushStyle(ui.TextStyle(color: const ui.Color(0xff242724)))
          ..addText('OFFLINE READER FIXTURE\n\nPAGE $page / 11\n\n'
              'All four page edges must remain visible.'))
        .build()
      ..layout(ui.ParagraphConstraints(width: size.width - 96));
    canvas.drawParagraph(text, const ui.Offset(48, 120));
    for (final point in [
      const ui.Offset(40, 40),
      ui.Offset(size.width - 40, 40),
      ui.Offset(40, size.height - 40),
      ui.Offset(size.width - 40, size.height - 40),
    ]) {
      canvas.drawCircle(
          point, 10, ui.Paint()..color = const ui.Color(0xff326758));
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path.join(directory.path, '$page.png'));
    if (!await file.exists() && data != null) {
      await file.writeAsBytes(data.buffer.asUint8List());
    }
    image.dispose();
    picture.dispose();
    await isarHelper.putImageTask(GalleryImageTask(
      gid: gid,
      token: 'offline-duo-$page',
      ser: page,
      filePath: '$page.png',
      status: 3,
    ));
  }
  await isarHelper.putGalleryTask(GalleryTask(
    gid: gid,
    token: 'offline-duo-fixture',
    title: 'Offline Duo reader fixture (11 pages)',
    dirPath: Platform.isIOS ? path.join(folder, '$gid') : directory.path,
    fileCount: 11,
    completCount: 11,
    status: 3,
    coverImage: '1.png',
    uploader: 'Neutral local reader acceptance',
    addTime: 1767225610100,
  ));
}
