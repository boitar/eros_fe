import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/common/controller/download/download_path_manager.dart';
import 'package:eros_fe/common/controller/download/gallery_update_service.dart';
import 'package:eros_fe/common/controller/download/storage_adapter.dart';
import 'package:eros_fe/common/controller/download_controller.dart';
import 'package:eros_fe/common/controller/download_state.dart';
import 'package:eros_fe/common/controller/tag_trans_controller.dart';
import 'package:eros_fe/common/parser/gallery_detail_parser.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/network/app_dio/exception.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_controller.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_state.dart';
import 'package:eros_fe/pages/gallery/view/gallery_incremental_update_sheet.dart';
import 'package:eros_fe/pages/gallery/view/gallery_info_page.dart';
import 'package:eros_fe/pages/gallery/view/gallery_lineage_chain.dart';
import 'package:eros_fe/pages/gallery/view/gallery_lineage_sheet.dart';
import 'package:eros_fe/pages/gallery/view/sliver/gallery_hero.dart';
import 'package:eros_fe/pages/item/download_gallery_item.dart';
import 'package:eros_fe/pages/tab/controller/download_view_controller.dart';
import 'package:eros_fe/pages/tab/view/download_page.dart';
import 'package:eros_fe/store/db/entity/gallery_image_task.dart';
import 'package:eros_fe/store/db/entity/gallery_task.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/eh_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:oktoast/oktoast.dart' as oktoast;
import 'package:path/path.dart' as path;

class _FakeSettings extends EhSettingService {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _FakeTheme extends ThemeService {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _FakeTagTrans extends TagTransController {
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<String?> getTagTranslateText(
    String text, {
    String? namespace,
    bool ignoreNamespace = false,
  }) async => text;
}

class _FakeGalleryPageController extends GetxController
    implements GalleryPageController {
  _FakeGalleryPageController(this.gState);

  @override
  final GalleryPageState gState;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDownloadController extends GetxController
    implements DownloadController {
  @override
  final DownloadState dState = DownloadState();

  @override
  Future<void> get downloadInitialization => Future<void>.value();

  final List<int> resumedGids = <int>[];
  final List<({int gid, bool shouldDeleteContent})> removedCalls =
      <({int gid, bool shouldDeleteContent})>[];
  Future<GalleryIncrementalExecutionResult?> Function(
    GalleryIncrementalPlan plan,
    GalleryIncrementalUpdateMode mode,
  )?
  onExecuteIncrementalUpdate;

  @override
  Future<void> galleryTaskResume(int gid, {bool userInitiated = false}) async {
    resumedGids.add(gid);
  }

  @override
  Future<void> removeDownloadGalleryTask({
    required int gid,
    bool shouldDeleteContent = true,
  }) async {
    removedCalls.add((gid: gid, shouldDeleteContent: shouldDeleteContent));
    dState.galleryTaskMap.remove(gid);
    dState.incrementalProgressMap.remove(gid);
    dState.updateCreatedTaskGids.remove(gid);
  }

  @override
  Future<GalleryIncrementalExecutionResult?> executeIncrementalUpdate(
    GalleryIncrementalPlan plan, {
    required GalleryIncrementalUpdateMode mode,
  }) async {
    if (onExecuteIncrementalUpdate != null) {
      return onExecuteIncrementalUpdate!(plan, mode);
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThrowingStorageAdapter extends StorageAdapter {
  int probeCalls = 0;

  @override
  Future<bool> downloadFileExists(
    String? directoryPath,
    String? fileName,
  ) async {
    probeCalls++;
    throw const FileSystemException('SAF source should not be probed');
  }
}

class _FakeDownloadViewController extends GetxController
    implements DownloadViewController {
  @override
  final galleryTaskMap = <int, GalleryTask>{};

  final List<int> resumedGids = <int>[];
  final List<int> pausedGids = <int>[];

  @override
  bool filesUnavailable(int gid) => false;

  @override
  void resumeGalleryDownload(int? gid) {
    if (gid != null) {
      resumedGids.add(gid);
    }
  }

  @override
  void pauseGalleryDownload(int? gid) {
    if (gid != null) {
      pausedGids.add(gid);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestableDownloadViewController extends DownloadViewController {
  _TestableDownloadViewController({super.updateService});

  @override
  // ignore: must_call_super
  void onInit() {
    tabTag = 'download';
  }
}

Widget _wrapCupertinoApp({
  Key? appKey,
  required Widget child,
  Locale locale = const Locale('zh', 'CN'),
  Brightness brightness = Brightness.dark,
}) {
  return oktoast.OKToast(
    child: GetCupertinoApp(
      key: appKey,
      locale: locale,
      supportedLocales: L10n.delegate.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        L10n.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
      ],
      theme: CupertinoThemeData(brightness: brightness),
      home: child,
    ),
  );
}

void main() {
  group('Newer Versions (#gnd) & Parent parsing', () {
    test('parses #gnd newer versions, deduplicates, and sorts newest-first', () {
      const html = '''
      <div id="gnd">
        <a href="https://e-hentai.org/g/3180442/abcdef1234/">Yoimachi [Proofread]</a>, added 2026-01-09 10:15<br />
        <a href="https://e-hentai.org/g/3298510/0123456789/">Yoimachi [Expanded]</a>, added 2026-03-14 21:30<br />
        <a href="https://e-hentai.org/g/3298510/0123456789/">Duplicate Ignored</a>, added 2026-03-14 21:30<br />
        <a href="https://e-hentai.org/invalid">Not a gallery</a>
      </div>
      ''';
      final document = html_parser.parse(html);
      final versions = parseGalleryNewerVersions(document);

      expect(versions, hasLength(2));
      expect(versions[0].gid, '3180442');
      expect(versions[0].token, 'abcdef1234');
      expect(versions[0].title, 'Yoimachi [Proofread]');
      expect(versions[0].addedDate, '2026-01-09 10:15');
      expect(versions[0].shortDate, '2026-01-09');

      expect(versions[1].gid, '3298510');
      expect(versions[1].token, '0123456789');
      expect(versions[1].title, 'Yoimachi [Expanded]');
      expect(versions[1].addedDate, '2026-03-14 21:30');

      final provider = GalleryProvider(
        gid: '3104821',
        token: '9a4f2c1b8e',
        newerVersions: versions,
      );
      expect(provider.hasNewerVersions, isTrue);
      expect(provider.newerVersionsNewestFirst.first.gid, '3298510');
      expect(provider.latestNewerVersion?.gid, '3298510');

      // JSON round-trip & copyWithAll preserve both parentHref and newerVersions.
      final roundTrip = GalleryProvider.fromJson(provider.toJson());
      expect(roundTrip.newerVersions, equals(versions));

      final merged = const GalleryProvider(gid: '3104821').copyWithAll(
        provider.copyWith(
          parent: '2841029'.oN,
          parentHref: 'https://e-hentai.org/g/2841029/fedcba9876/'.oN,
        ),
      );
      expect(merged.hasParentLink, isTrue);
      expect(merged.parentGid, '2841029');
      expect(merged.parentHref, 'https://e-hentai.org/g/2841029/fedcba9876/');
      expect(merged.newerVersions, equals(versions));

      // Strict URL validation: relative g/..., protocol-relative, and reject foreign hosts.
      final exBase = Uri.parse('https://exhentai.org/g/100/0123456789/');
      expect(
        resolveEhGalleryUri('g/200/aabbccddee/', baseUri: exBase).toString(),
        'https://exhentai.org/g/200/aabbccddee/',
      );
      expect(
        resolveEhGalleryUri('//exhentai.org/g/200/aabbccddee/').toString(),
        'https://exhentai.org/g/200/aabbccddee/',
      );
      expect(
        resolveEhGalleryUri('https://evil.example/g/200/aabbccddee/'),
        isNull,
      );
      expect(parseGalleryGidToken('/foo/g/200/aabbccddee/'), isNull);

      // Strict total-order sorting with mixed dated and undated versions.
      const mixedProvider = GalleryProvider(
        gid: '100',
        newerVersions: <GalleryNewerVersion>[
          GalleryNewerVersion(
            gid: '500',
            token: '5555555555',
            url: 'https://e-hentai.org/g/500/5555555555/',
            title: 'Undated High GID',
          ),
          GalleryNewerVersion(
            gid: '300',
            token: '3333333333',
            url: 'https://e-hentai.org/g/300/3333333333/',
            title: 'Dated Older',
            addedDate: '2026-01-01 00:00',
          ),
          GalleryNewerVersion(
            gid: '400',
            token: '4444444444',
            url: 'https://e-hentai.org/g/400/4444444444/',
            title: 'Dated Newer',
            addedDate: '2026-03-01 00:00',
          ),
        ],
      );
      expect(
        mixedProvider.newerVersionsNewestFirst.map((e) => e.gid).toList(),
        <String>['400', '300', '500'],
      );
    });

    test('parseGalleryDetail extracts parent, parentHref and #gnd', () async {
      Get.testMode = true;
      Get.put<LocaleService>(LocaleService());
      Get.put<EhSettingService>(_FakeSettings());
      Get.put<TagTransController>(_FakeTagTrans());
      addTearDown(Get.reset);

      const detailHtml = '''
      <html><body>
        <div id="gd1"><div style="width:250px; height:350px; background:transparent url(https://ehgt.org/t/cover.jpg) 0 0 no-repeat"></div></div>
        <h1 id="gn">Yoimachi Dusk Vol.2</h1>
        <h1 id="gj">宵待街の黄昏風景集</h1>
        <div id="gdc"><div class="cs ct6">Non-H</div></div>
        <div id="gdn"><a href="#">hoshino_scan</a></div>
        <div id="gdd"><table><tbody>
          <tr><td class="gdt1">Posted:</td><td class="gdt2">2025-11-18 20:14</td></tr>
          <tr><td class="gdt1">Parent:</td><td class="gdt2"><a href="https://exhentai.org/g/2841029/aabbccddee/">2841029</a></td></tr>
          <tr><td class="gdt1">Visible:</td><td class="gdt2">Yes</td></tr>
          <tr><td class="gdt1">Language:</td><td class="gdt2">Chinese</td></tr>
          <tr><td class="gdt1">File Size:</td><td class="gdt2">68.4 MB</td></tr>
          <tr><td class="gdt1">Favorited:</td><td class="gdt2">123 times</td></tr>
        </tbody></table></div>
        <div id="gd5"><p></p><p></p><p><img><a href="#">Torrent Download (1)</a></p></div>
        <div id="rating_label">Average: 4.86</div>
        <div id="rating_count">88</div>
        <div id="rating_image" class="ir" style="background-position:0px -1px"></div>
        <div id="gnd">
          <a href="https://exhentai.org/g/3298510/1122334455/">Yoimachi [Expanded]</a>, added 2026-03-14 08:20<br />
        </div>
        <div id="gdt">
          <a href="https://exhentai.org/s/aa11bb22cc/3104821-1"><div title="Page 1: 01.jpg" style="width:200px;height:280px;background:url(https://ehgt.org/t/1.jpg) -0px 0"></div></a>
        </div>
      </body></html>
      ''';

      final provider = await parseGalleryDetail(detailHtml);
      expect(provider.parent, '2841029');
      expect(provider.parentHref, 'https://exhentai.org/g/2841029/aabbccddee/');
      expect(provider.hasParentLink, isTrue);
      expect(provider.newerVersions, hasLength(1));
      expect(provider.latestNewerVersion?.gid, '3298510');
      expect(provider.latestNewerVersion?.addedDate, '2026-03-14 08:20');
    });
  });

  group('Incremental update planner & atomic file staging', () {
    test('matches image keys across shifted serials and maps reading index', () {
      final oldTask = GalleryTask(
        gid: 100,
        token: 'oldtoken00',
        title: 'Old Version',
        dirPath: '/tmp/old',
        fileCount: 4,
        completCount: 4,
        status: TaskStatus.complete.value,
      );
      final oldImages = <GalleryImageTask>[
        GalleryImageTask(
          gid: 100,
          token: 'aaaaaaaaaa',
          href: 'https://e-hentai.org/s/aaaaaaaaaa/100-1',
          ser: 1,
          filePath: '0001.jpg',
          status: TaskStatus.complete.value,
        ),
        GalleryImageTask(
          gid: 100,
          token: 'bbbbbbbbbb',
          href: 'https://e-hentai.org/s/bbbbbbbbbb/100-2',
          ser: 2,
          filePath: '0002.png',
          status: TaskStatus.complete.value,
        ),
        GalleryImageTask(
          gid: 100,
          token: 'cccccccccc',
          href: 'https://e-hentai.org/s/cccccccccc/100-3',
          ser: 3,
          filePath: '0003.jpg',
          status: TaskStatus.complete.value,
        ),
        GalleryImageTask(
          gid: 100,
          token: 'dddddddddd',
          href: 'https://e-hentai.org/s/dddddddddd/100-4',
          ser: 4,
          filePath: '0004.jpg',
          status: TaskStatus.complete.value,
        ),
      ];

      // New version inserts 1 cover page at ser 1, shifts old 1 & 2 to ser 2 & 3,
      // replaces old 3 with new key, keeps old 4 at ser 5, and adds ser 6.
      final newImages = <GalleryImage>[
        const GalleryImage(
          ser: 1,
          href: 'https://e-hentai.org/s/newcover01/200-1',
        ),
        const GalleryImage(
          ser: 2,
          href: 'https://e-hentai.org/s/aaaaaaaaaa/200-2',
        ),
        const GalleryImage(
          ser: 3,
          href: 'https://e-hentai.org/s/bbbbbbbbbb/200-3',
        ),
        const GalleryImage(
          ser: 4,
          href: 'https://e-hentai.org/s/fixedpage4/200-4',
        ),
        const GalleryImage(
          ser: 5,
          href: 'https://e-hentai.org/s/dddddddddd/200-5',
        ),
        const GalleryImage(
          ser: 6,
          href: 'https://e-hentai.org/s/bonuspage6/200-6',
        ),
      ];

      final plan = buildGalleryIncrementalPlan(
        oldTask: oldTask,
        oldImageTasks: oldImages,
        availableOldFileNames: {'0001.jpg', '0002.png', '0003.jpg', '0004.jpg'},
        targetVersion: const GalleryNewerVersion(
          gid: '200',
          token: 'newtoken00',
          url: 'https://e-hentai.org/g/200/newtoken00/',
          title: 'New Version',
          addedDate: '2026-03-14 08:00',
        ),
        targetProvider: const GalleryProvider(
          gid: '200',
          token: 'newtoken00',
          filecount: '6',
        ),
        targetImages: newImages,
        firstPageCount: 6,
        // User was reading old page 2 (0-based index 1), which shifted to new ser 3 (index 2).
        oldReadingIndex: 1,
      );

      expect(plan.totalNewPages, 6);
      expect(plan.reusedCount, 3);
      expect(plan.downloadCount, 3);
      expect(plan.addedCount, 2);
      expect(plan.replacedCount, 1);
      expect(plan.mappedReadingIndex, 2);
    });

    test('in-place copies shifted serials into exclusive dir leaving source untouched', () async {
      final tempRoot = await Directory.systemTemp.createTemp('eros_inc_test_');
      addTearDown(() => tempRoot.delete(recursive: true));

      final srcDir = path.join(tempRoot.path, '100 - Old');
      final dstDir = path.join(tempRoot.path, '200 - New');
      await Directory(srcDir).create();
      await File(path.join(srcDir, '0001.jpg')).writeAsString('PAGE_ONE');
      await File(path.join(srcDir, '0002.jpg')).writeAsString('PAGE_TWO');
      await File(path.join(srcDir, '0003.jpg')).writeAsString('OBSOLETE_THREE');
      await File(path.join(srcDir, '.info')).writeAsString('OLD_INFO');

      final oldImages = <GalleryImageTask>[
        GalleryImageTask(
          gid: 100,
          token: 'aaaaaaaaaa',
          href: 'https://e-hentai.org/s/aaaaaaaaaa/100-1',
          ser: 1,
          filePath: '0001.jpg',
          status: TaskStatus.complete.value,
        ),
        GalleryImageTask(
          gid: 100,
          token: 'bbbbbbbbbb',
          href: 'https://e-hentai.org/s/bbbbbbbbbb/100-2',
          ser: 2,
          filePath: '0002.jpg',
          status: TaskStatus.complete.value,
        ),
        GalleryImageTask(
          gid: 100,
          token: 'cccccccccc',
          href: 'https://e-hentai.org/s/cccccccccc/100-3',
          ser: 3,
          filePath: '0003.jpg',
          status: TaskStatus.complete.value,
        ),
      ];

      final oldTask = GalleryTask(
        gid: 100,
        token: 'a0b1c2d3e4',
        title: 'Old',
        dirPath: srcDir,
        fileCount: 3,
        completCount: 3,
        status: TaskStatus.complete.value,
      );

      // Shift old 1 -> new 2, old 2 -> new 3; ser 1 is brand new.
      final plan = buildGalleryIncrementalPlan(
        oldTask: oldTask,
        oldImageTasks: oldImages,
        availableOldFileNames: {'0001.jpg', '0002.jpg', '0003.jpg'},
        targetVersion: const GalleryNewerVersion(
          gid: '200',
          token: 'f0e1d2c3b4',
          url: 'https://e-hentai.org/g/200/f0e1d2c3b4/',
          title: 'New',
        ),
        targetProvider: const GalleryProvider(
          gid: '200',
          token: 'f0e1d2c3b4',
          filecount: '3',
        ),
        targetImages: const <GalleryImage>[
          GalleryImage(ser: 1, href: 'https://e-hentai.org/s/abcdef0101/200-1'),
          GalleryImage(ser: 2, href: 'https://e-hentai.org/s/aaaaaaaaaa/200-2'),
          GalleryImage(ser: 3, href: 'https://e-hentai.org/s/bbbbbbbbbb/200-3'),
        ],
        firstPageCount: 3,
      );

      // Rejects mutating sourceDirPath directly.
      await expectLater(
        prepareIncrementalLocalFiles(
          plan: plan,
          mode: GalleryIncrementalUpdateMode.inPlace,
          sourceDirPath: srcDir,
          targetDirPath: srcDir,
          oldImageTasks: oldImages,
        ),
        throwsStateError,
      );

      final prepared = await prepareIncrementalLocalFiles(
        plan: plan,
        mode: GalleryIncrementalUpdateMode.inPlace,
        sourceDirPath: srcDir,
        targetDirPath: dstDir,
        oldImageTasks: oldImages,
      );

      expect(prepared.reusedImageTasks, hasLength(2));
      expect(await File(path.join(dstDir, '0001.jpg')).exists(), isFalse);
      expect(await File(path.join(dstDir, '0002.jpg')).readAsString(), 'PAGE_ONE');
      expect(await File(path.join(dstDir, '0003.jpg')).readAsString(), 'PAGE_TWO');
      // Source directory remains 100% intact until atomic DB commit succeeds.
      expect(await File(path.join(srcDir, '0001.jpg')).readAsString(), 'PAGE_ONE');
      expect(await File(path.join(srcDir, '.info')).readAsString(), 'OLD_INFO');

      // Non-empty target directory is rejected without overwriting preserved files.
      await expectLater(
        prepareIncrementalLocalFiles(
          plan: plan,
          mode: GalleryIncrementalUpdateMode.newTask,
          sourceDirPath: srcDir,
          targetDirPath: dstDir,
          oldImageTasks: oldImages,
        ),
        throwsStateError,
      );
      expect(await File(path.join(dstDir, '0002.jpg')).readAsString(), 'PAGE_ONE');
    });

    test('DownloadPathManager allocates exclusive dir skipping preserved & owned folders', () async {
      Get.testMode = true;
      Get.put<LocaleService>(LocaleService());
      final settings = Get.put<EhSettingService>(_FakeSettings());
      addTearDown(Get.reset);

      final tempRoot = await Directory.systemTemp.createTemp('eros_alloc_test_');
      addTearDown(() => tempRoot.delete(recursive: true));
      settings.downloadLocatino = tempRoot.path;

      // Simulate preserved download on disk at base name.
      final preserved = Directory(path.join(tempRoot.path, '200 - Title'));
      await preserved.create();
      await File(path.join(preserved.path, '0001.jpg')).writeAsString('KEEP');

      // Simulate (2) owned by another active task even if currently empty.
      final ownedSecond = path.join(tempRoot.path, '200 - Title (2)');

      final manager = DownloadPathManager(settings);
      final (persisted, ioDir) = await manager.allocateExclusiveGalleryDownloadPath(
        baseDirName: '200 - Title',
        ownedIoDirs: <String>{ownedSecond},
      );

      expect(path.basename(persisted), '200 - Title (3)');
      expect(path.canonicalize(ioDir), path.canonicalize(persisted));
      expect(await Directory(ioDir).exists(), isTrue);
      expect(await File(path.join(preserved.path, '0001.jpg')).readAsString(), 'KEEP');
    });

    test('newTask mode copies reused files without mutating old folder', () async {
      final tempRoot = await Directory.systemTemp.createTemp('eros_inc_new_');
      addTearDown(() => tempRoot.delete(recursive: true));

      final oldDir = path.join(tempRoot.path, 'old');
      final newDir = path.join(tempRoot.path, 'new');
      await Directory(oldDir).create();
      await File(path.join(oldDir, '0001.png')).writeAsString('ORIG_ONE');

      final oldImages = <GalleryImageTask>[
        GalleryImageTask(
          gid: 100,
          token: 'aaaaaaaaaa',
          href: 'https://e-hentai.org/s/aaaaaaaaaa/100-1',
          ser: 1,
          filePath: '0001.png',
          status: TaskStatus.complete.value,
        ),
      ];
      final oldTask = GalleryTask(
        gid: 100,
        token: 'oldtoken00',
        title: 'Old',
        dirPath: oldDir,
        fileCount: 1,
        completCount: 1,
        status: TaskStatus.complete.value,
      );

      final plan = buildGalleryIncrementalPlan(
        oldTask: oldTask,
        oldImageTasks: oldImages,
        availableOldFileNames: {'0001.png'},
        targetVersion: const GalleryNewerVersion(
          gid: '200',
          token: 'newtoken00',
          url: 'https://e-hentai.org/g/200/newtoken00/',
          title: 'New',
        ),
        targetProvider: const GalleryProvider(
          gid: '200',
          token: 'newtoken00',
          filecount: '2',
        ),
        targetImages: const <GalleryImage>[
          GalleryImage(ser: 1, href: 'https://e-hentai.org/s/aaaaaaaaaa/200-1'),
          GalleryImage(ser: 2, href: 'https://e-hentai.org/s/newsecond2/200-2'),
        ],
        firstPageCount: 2,
      );

      final prepared = await prepareIncrementalLocalFiles(
        plan: plan,
        mode: GalleryIncrementalUpdateMode.newTask,
        sourceDirPath: oldDir,
        targetDirPath: newDir,
        oldImageTasks: oldImages,
      );

      expect(prepared.coverImage, '0001.png');
      expect(await File(path.join(oldDir, '0001.png')).readAsString(), 'ORIG_ONE');
      expect(await File(path.join(newDir, '0001.png')).readAsString(), 'ORIG_ONE');
    });

    test('GalleryUpdateService paginates real HTML detail, validates completeness, and handles CancelException', () async {
      Get.testMode = true;
      Get.put<LocaleService>(LocaleService());
      Get.put<EhSettingService>(_FakeSettings());
      Get.put<TagTransController>(_FakeTagTrans());
      addTearDown(Get.reset);

      final tempDir = await Directory.systemTemp.createTemp('eros_svc_test_');
      addTearDown(() => tempDir.delete(recursive: true));
      await File(path.join(tempDir.path, '0001.jpg')).writeAsString('IMG1');
      await File(path.join(tempDir.path, '0002.jpg')).writeAsString('IMG2');

      const page0Html = '''
      <html><body>
        <script>var gid = 201; var token = "aabbccddee";</script>
        <div id="gd1"><div style="width:250px; height:350px; background:transparent url(https://ehgt.org/t/cover.jpg) 0 0 no-repeat"></div></div>
        <h1 id="gn">V2 ExHentai Multi-Page</h1>
        <div id="gdc"><div class="cs ct6">Non-H</div></div>
        <div id="gdn"><a href="#">uploader</a></div>
        <div id="gdd"><table><tbody>
          <tr><td class="gdt1">Length:</td><td class="gdt2">3 pages</td></tr>
        </tbody></table></div>
        <div id="gd5"><p></p><p></p><p><img><a href="#">Torrent Download (0)</a></p></div>
        <div id="rating_label">Average: 4.50</div>
        <div id="rating_count">10</div>
        <div id="rating_image" class="ir" style="background-position:0px -1px"></div>
        <div id="gdt">
          <a href="https://exhentai.org/s/aaaa111111/201-1"><div title="Page 1: 01.jpg" style="width:200px;height:280px;background:transparent url(https://ehgt.org/t/1.jpg) 0 0 no-repeat"></div></a>
          <a href="https://exhentai.org/s/bbbb222222/201-2"><div title="Page 2: 02.jpg" style="width:200px;height:280px;background:transparent url(https://ehgt.org/t/2.jpg) 0 0 no-repeat"></div></a>
        </div>
      </body></html>
      ''';

      final requestedPageUrls = <String>[];
      final service = GalleryUpdateService(
        fetchDetail: ({required String url, bool refresh = false, CancelToken? cancelToken}) async {
          if (url.contains('/g/101/')) {
            return const GalleryProvider(
              gid: '101',
              token: '1111111111',
              newerVersions: <GalleryNewerVersion>[
                GalleryNewerVersion(
                  gid: '201',
                  token: 'aabbccddee',
                  url: 'https://exhentai.org/g/201/aabbccddee/',
                  title: 'V2',
                  addedDate: '2026-03-14 08:00',
                ),
              ],
            );
          }
          if (url.contains('/g/102/')) {
            throw Exception('network glitch');
          }
          if (url.contains('/g/103/')) {
            throw CancelException('cancelled');
          }
          if (url.contains('/g/201/')) {
            // Exercise the real HTML parser including Length -> filecount!
            return parseGalleryDetail(
              page0Html,
              baseUri: Uri.parse(url),
            );
          }
          return const GalleryProvider(gid: '104', token: '4444444444');
        },
        fetchImageList: (String inUrl, {int? page, bool refresh = false, CancelToken? cancelToken}) async {
          requestedPageUrls.add('$inUrl?p=$page');
          if (page == 1) {
            return const <GalleryImage>[
              GalleryImage(ser: 3, href: 'https://exhentai.org/s/cccc333333/201-3'),
            ];
          }
          return const <GalleryImage>[];
        },
      );

      final task1 = GalleryTask(
        gid: 101,
        token: '1111111111',
        url: 'https://exhentai.org/g/101/1111111111/',
        title: 'G1',
        dirPath: tempDir.path,
        fileCount: 2,
        completCount: 2,
        status: TaskStatus.complete.value,
      );
      final task2 = GalleryTask(
        gid: 102,
        token: '2222222222',
        url: 'https://exhentai.org/g/102/2222222222/',
        title: 'G2',
        dirPath: tempDir.path,
        fileCount: 2,
        completCount: 2,
        status: TaskStatus.complete.value,
      );
      final task3 = GalleryTask(
        gid: 103,
        token: '3333333333',
        url: 'https://exhentai.org/g/103/3333333333/',
        title: 'G3',
        dirPath: tempDir.path,
        fileCount: 2,
        completCount: 2,
        status: TaskStatus.complete.value,
      );

      final batch = await service.checkTasksForUpdates(
        <GalleryTask>[task1, task2, task3],
        delayBetweenRequests: Duration.zero,
      );
      expect(batch.checkedCount, 1);
      expect(batch.checkedGids, <int>{101});
      expect(batch.failedCount, 1);
      expect(batch.failedGids, <int>{102});
      expect(batch.cancelled, isTrue);
      expect(batch.cancelledGids, <int>{103});
      expect(batch.foundCount, 1);
      expect(batch.updates[101]?.latest.gid, '201');

      final plan = await service.analyzeIncrementalUpdate(
        oldTask: task1,
        oldImageTasks: <GalleryImageTask>[
          GalleryImageTask(
            gid: 101,
            token: 'aaaa111111',
            href: 'https://exhentai.org/s/aaaa111111/101-1',
            ser: 1,
            filePath: '0001.jpg',
            status: TaskStatus.complete.value,
          ),
          GalleryImageTask(
            gid: 101,
            token: 'bbbb222222',
            href: 'https://exhentai.org/s/bbbb222222/101-2',
            ser: 2,
            filePath: '0002.jpg',
            status: TaskStatus.complete.value,
          ),
        ],
        targetVersion: batch.updates[101]!.latest,
        oldReadingIndex: 0,
      );

      expect(requestedPageUrls, <String>['https://exhentai.org/g/201/aabbccddee/?p=1']);
      expect(plan.canonicalTargetUrl, 'https://exhentai.org/g/201/aabbccddee/');
      expect(plan.totalNewPages, 3);
      expect(plan.reusedCount, 2);
      expect(plan.addedCount, 1);
      expect(plan.replacedCount, 0);
      expect(plan.pagesToDownload.single.ser, 3);

      // Truncated pagination (page 1 empty) MUST throw instead of returning truncated plan.
      final truncatedService = GalleryUpdateService(
        fetchDetail: ({required String url, bool refresh = false, CancelToken? cancelToken}) =>
            parseGalleryDetail(page0Html, baseUri: Uri.parse(url)),
        fetchImageList: (String inUrl, {int? page, bool refresh = false, CancelToken? cancelToken}) async =>
            const <GalleryImage>[],
      );
      await expectLater(
        truncatedService.analyzeIncrementalUpdate(
          oldTask: task1,
          oldImageTasks: const <GalleryImageTask>[],
          targetVersion: batch.updates[101]!.latest,
        ),
        throwsStateError,
      );

      // Missing authoritative filecount MUST throw.
      final noCountService = GalleryUpdateService(
        fetchDetail: ({required String url, bool refresh = false, CancelToken? cancelToken}) async =>
            const GalleryProvider(
              gid: '201',
              token: 'aabbccddee',
              galleryImages: <GalleryImage>[
                GalleryImage(ser: 1, href: 'https://exhentai.org/s/aaaa111111/201-1'),
              ],
            ),
        fetchImageList: (String inUrl, {int? page, bool refresh = false, CancelToken? cancelToken}) async =>
            const <GalleryImage>[],
      );
      await expectLater(
        noCountService.analyzeIncrementalUpdate(
          oldTask: task1,
          oldImageTasks: const <GalleryImageTask>[],
          targetVersion: batch.updates[101]!.latest,
        ),
        throwsStateError,
      );
    });

    test('resolveEhImagePageUri normalizes relative hrefs and rejects blank links; SAF fallback skips source probes', () async {
      final exOrigin = Uri.parse('https://exhentai.org');
      expect(
        resolveEhImagePageUri(
          '/s/aaaa111111/201-1',
          baseUri: exOrigin,
          expectedGid: 201,
          expectedSer: 1,
        ),
        'https://exhentai.org/s/aaaa111111/201-1',
      );
      expect(
        resolveEhImagePageUri(
          '',
          baseUri: exOrigin,
          expectedGid: 201,
          expectedSer: 1,
        ),
        isNull,
      );

      final throwingStorage = _ThrowingStorageAdapter();
      final safTask = GalleryTask(
        gid: 101,
        token: '1111111111',
        url: 'https://exhentai.org/g/101/1111111111/',
        title: 'SAF Old',
        dirPath: 'content://com.android.externalstorage.documents/tree/primary%3Aeh%2F101',
        fileCount: 2,
        completCount: 2,
        status: TaskStatus.complete.value,
      );
      const target = GalleryNewerVersion(
        gid: '201',
        token: 'aabbccddee',
        url: 'https://exhentai.org/g/201/aabbccddee/',
        title: 'V2',
      );

      // Relative /s/... image links resolve to https://exhentai.org/s/... and
      // SAF fallback NEVER probes old files via StorageAdapter.
      final service = GalleryUpdateService(
        storageAdapter: throwingStorage,
        fetchDetail: ({required String url, bool refresh = false, CancelToken? cancelToken}) async =>
            const GalleryProvider(
              gid: '201',
              token: 'aabbccddee',
              filecount: '2',
              galleryImages: <GalleryImage>[
                GalleryImage(ser: 1, href: '/s/aaaa111111/201-1'),
                GalleryImage(ser: 2, href: '/s/bbbb222222/201-2'),
              ],
            ),
        fetchImageList: (String inUrl, {int? page, bool refresh = false, CancelToken? cancelToken}) async =>
            const <GalleryImage>[],
      );

      final safPlan = await service.analyzeIncrementalUpdate(
        oldTask: safTask,
        oldImageTasks: <GalleryImageTask>[
          GalleryImageTask(
            gid: 101,
            token: 'aaaa111111',
            href: 'https://exhentai.org/s/aaaa111111/101-1',
            ser: 1,
            filePath: '0001.jpg',
            status: TaskStatus.complete.value,
          ),
        ],
        targetVersion: target,
      );
      expect(throwingStorage.probeCalls, 0);
      expect(safPlan.canReuseLocalFiles, isFalse);
      expect(safPlan.targetImages[0].href, 'https://exhentai.org/s/aaaa111111/201-1');
      expect(safPlan.targetImages[1].href, 'https://exhentai.org/s/bbbb222222/201-2');

      // Blank image href MUST be rejected instead of producing an undownloadable plan.
      final blankHrefService = GalleryUpdateService(
        storageAdapter: throwingStorage,
        fetchDetail: ({required String url, bool refresh = false, CancelToken? cancelToken}) async =>
            const GalleryProvider(
              gid: '201',
              token: 'aabbccddee',
              filecount: '2',
              galleryImages: <GalleryImage>[
                GalleryImage(ser: 1, href: '/s/aaaa111111/201-1'),
                GalleryImage(ser: 2, href: ''),
              ],
            ),
        fetchImageList: (String inUrl, {int? page, bool refresh = false, CancelToken? cancelToken}) async =>
            const <GalleryImage>[],
      );
      await expectLater(
        blankHrefService.analyzeIncrementalUpdate(
          oldTask: safTask,
          oldImageTasks: const <GalleryImageTask>[],
          targetVersion: target,
        ),
        throwsStateError,
      );
    });

    test('reconcilePendingIncrementalUpdates handles pre-commit rollback, verified post-commit promotion, tampered journal rejection, and restore skip', () async {
      final baseRoot = await Directory.systemTemp.createTemp('eros_reconcile_');
      final outsideRoot = await Directory.systemTemp.createTemp('eros_outside_');
      addTearDown(() => baseRoot.delete(recursive: true));
      addTearDown(() => outsideRoot.delete(recursive: true));

      // Case 1: Pre-commit crash (newGid=201 not in DB) -> staged dir deleted, old dir intact.
      final oldDir1 = Directory(path.join(baseRoot.path, '101 - Old1'))..createSync();
      File(path.join(oldDir1.path, '.info')).writeAsStringSync('{"gid":101,"token":"1111111111"}\n[]');
      final stagedDir1 = Directory(path.join(baseRoot.path, '201 - New1'))..createSync();
      File(path.join(stagedDir1.path, kIncrementalStagingInfoFileName))
          .writeAsStringSync('{"gid":201,"token":"aaaaaaaaaa"}\n[]');
      await writePendingIncrementalJournal(
        targetIoDirPath: stagedDir1.path,
        newGid: 201,
        oldGid: 101,
        oldToken: '1111111111',
        oldIoDirPath: oldDir1.path,
        mode: GalleryIncrementalUpdateMode.inPlace,
      );

      // Case 2: Post-commit crash (newGid=202 in DB owning stagedDir2, oldGid=102 deleted)
      // -> promote .info & retire verified old dir.
      final oldDir2 = Directory(path.join(baseRoot.path, '102 - Old2'))..createSync();
      File(path.join(oldDir2.path, '.info')).writeAsStringSync('{"gid":102,"token":"2222222222"}\n[]');
      final stagedDir2 = Directory(path.join(baseRoot.path, '202 - New2'))..createSync();
      File(path.join(stagedDir2.path, kIncrementalStagingInfoFileName))
          .writeAsStringSync('{"gid":202,"token":"bbbbbbbbbb"}\n[]');
      await writePendingIncrementalJournal(
        targetIoDirPath: stagedDir2.path,
        newGid: 202,
        oldGid: 102,
        oldToken: '2222222222',
        oldIoDirPath: oldDir2.path,
        mode: GalleryIncrementalUpdateMode.inPlace,
      );

      // Case 3: Directory WITH a `.info` AND `.inc_pending.json` (in-progress) ->
      // Restore MUST skip it because of `.inc_pending.json`, not missing `.info`.
      final inFlightDir = Directory(path.join(baseRoot.path, '203 - InFlight'))..createSync();
      File(path.join(inFlightDir.path, '.info')).writeAsStringSync('{"gid":203,"token":"cccccccccc"}\n[]');
      await writePendingIncrementalJournal(
        targetIoDirPath: inFlightDir.path,
        newGid: 203,
        oldGid: 103,
        oldToken: '3333333333',
        oldIoDirPath: outsideRoot.path,
        mode: GalleryIncrementalUpdateMode.inPlace,
      );

      // Case 4: Tampered journal pointing oldIoDirPath outside baseDownloadIoDir ->
      // MUST NOT delete outsideRoot!
      final stagedDir4 = Directory(path.join(baseRoot.path, '204 - Tampered'))..createSync();
      File(path.join(stagedDir4.path, kIncrementalStagingInfoFileName))
          .writeAsStringSync('{"gid":204,"token":"dddddddddd"}\n[]');
      await writePendingIncrementalJournal(
        targetIoDirPath: stagedDir4.path,
        newGid: 204,
        oldGid: 104,
        oldToken: '4444444444',
        oldIoDirPath: outsideRoot.path,
        mode: GalleryIncrementalUpdateMode.inPlace,
      );

      // Restore scan BEFORE reconciliation must skip ALL journaled dirs (even inFlightDir which has `.info`).
      final restoredDirs = <String>[];
      await StorageAdapter().restoreGalleryTasksWithPath(
        baseRoot.path,
        (File infoFile, String dirPath) async => restoredDirs.add(dirPath),
      );
      expect(restoredDirs, contains(oldDir1.path));
      expect(restoredDirs, isNot(contains(stagedDir1.path)));
      expect(restoredDirs, isNot(contains(stagedDir2.path)));
      expect(restoredDirs, isNot(contains(inFlightDir.path)));

      // Run startup/restore reconciliation (203 is reserved in-flight!).
      final dbTasks = <int, GalleryTask>{
        101: GalleryTask(
          gid: 101,
          token: '1111111111',
          title: 'Old1',
          dirPath: oldDir1.path,
          fileCount: 2,
        ),
        202: GalleryTask(
          gid: 202,
          token: 'bbbbbbbbbb',
          title: 'New2',
          dirPath: stagedDir2.path,
          fileCount: 3,
        ),
        204: GalleryTask(
          gid: 204,
          token: 'dddddddddd',
          title: 'New4',
          dirPath: stagedDir4.path,
          fileCount: 3,
        ),
      };
      await reconcilePendingIncrementalUpdates(
        baseDownloadIoDir: baseRoot.path,
        findTaskByGid: (gid) async => dbTasks[gid],
        isReserved: (newGid, oldGid) async => newGid == 203,
      );

      // Case 1 rolled back cleanly.
      expect(await stagedDir1.exists(), isFalse);
      expect(await File(path.join(oldDir1.path, '.info')).exists(), isTrue);

      // Case 2 promoted `.info.staging` -> `.info`, retired oldDir2, and removed journal.
      expect(await oldDir2.exists(), isFalse);
      expect(
        await File(path.join(stagedDir2.path, '.info')).readAsString(),
        '{"gid":202,"token":"bbbbbbbbbb"}\n[]',
      );
      expect(
        await File(path.join(stagedDir2.path, kIncrementalStagingInfoFileName)).exists(),
        isFalse,
      );
      expect(
        await File(path.join(stagedDir2.path, kIncrementalPendingJournalFileName)).exists(),
        isFalse,
      );

      // Case 3 reserved in-flight dir was untouched.
      expect(await inFlightDir.exists(), isTrue);
      expect(
        await File(path.join(inFlightDir.path, kIncrementalPendingJournalFileName)).exists(),
        isTrue,
      );

      // Case 4 promoted its own `.info` but NEVER deleted outsideRoot!
      expect(await outsideRoot.exists(), isTrue);
      expect(await File(path.join(stagedDir4.path, '.info')).exists(), isTrue);
    });

    test('recovery blocks symlink escape, missing/tokenless .info, preserves newer .info, and skips retiring dirs on restore', () async {
      final baseRoot = await Directory.systemTemp.createTemp('eros_sec_base_');
      final outsideRoot = await Directory.systemTemp.createTemp('eros_sec_out_');
      addTearDown(() => baseRoot.delete(recursive: true));
      addTearDown(() => outsideRoot.delete(recursive: true));

      // 1) Symlink inside baseRoot pointing to outsideRoot -> MUST NOT delete outsideRoot.
      File(path.join(outsideRoot.path, '.info'))
          .writeAsStringSync('{"gid":301,"token":"3010000000"}\n[]');
      final symlinkPath = path.join(baseRoot.path, '301 - SymlinkOld');
      Link(symlinkPath).createSync(outsideRoot.path);
      final target1 = Directory(path.join(baseRoot.path, '401 - Target1'))..createSync();
      // Newer `.info` already exists alongside stale `.info.staging` -> MUST keep newer `.info`!
      File(path.join(target1.path, '.info'))
          .writeAsStringSync('{"gid":401,"token":"4010000000","completCount":50}\n[]');
      File(path.join(target1.path, kIncrementalStagingInfoFileName))
          .writeAsStringSync('{"gid":401,"token":"4010000000","completCount":46}\n[]');
      await writePendingIncrementalJournal(
        targetIoDirPath: target1.path,
        newGid: 401,
        oldGid: 301,
        oldToken: '3010000000',
        oldIoDirPath: symlinkPath,
        mode: GalleryIncrementalUpdateMode.inPlace,
      );

      // 2) Old dir with missing `.info` (no tombstone) -> MUST NOT be deleted.
      final noInfoDir = Directory(path.join(baseRoot.path, '302 - NoInfo'))..createSync();
      File(path.join(noInfoDir.path, 'keep.txt')).writeAsStringSync('KEEP');
      final target2 = Directory(path.join(baseRoot.path, '402 - Target2'))..createSync();
      await writePendingIncrementalJournal(
        targetIoDirPath: target2.path,
        newGid: 402,
        oldGid: 302,
        oldToken: '3020000000',
        oldIoDirPath: noInfoDir.path,
        mode: GalleryIncrementalUpdateMode.inPlace,
      );

      // 3) Old dir whose `.info` is missing `token` while journal has `oldToken` -> MUST NOT be deleted.
      final tokenlessDir = Directory(path.join(baseRoot.path, '303 - Tokenless'))..createSync();
      File(path.join(tokenlessDir.path, '.info')).writeAsStringSync('{"gid":303}\n[]');
      final target3 = Directory(path.join(baseRoot.path, '403 - Target3'))..createSync();
      await writePendingIncrementalJournal(
        targetIoDirPath: target3.path,
        newGid: 403,
        oldGid: 303,
        oldToken: '3030000000',
        oldIoDirPath: tokenlessDir.path,
        mode: GalleryIncrementalUpdateMode.inPlace,
      );

      // 4) Retiring tombstone dir -> Restore MUST skip it even while `.info` still exists.
      final retiringDir = Directory(path.join(baseRoot.path, '304 - Retiring'))..createSync();
      File(path.join(retiringDir.path, '.info'))
          .writeAsStringSync('{"gid":304,"token":"3040000000"}\n[]');
      File(path.join(retiringDir.path, kIncrementalRetiringTombstoneFileName))
          .writeAsStringSync('{"oldGid":304,"oldToken":"3040000000","replacedByGid":404}');

      final restoredBefore = <String>[];
      await StorageAdapter().restoreGalleryTasksWithPath(
        baseRoot.path,
        (File infoFile, String dirPath) async => restoredBefore.add(dirPath),
      );
      expect(restoredBefore, isNot(contains(retiringDir.path)));

      final dbTasks = <int, GalleryTask>{
        401: GalleryTask(gid: 401, token: '4010000000', title: 'T1', dirPath: target1.path, fileCount: 50),
        402: GalleryTask(gid: 402, token: '4020000000', title: 'T2', dirPath: target2.path, fileCount: 50),
        403: GalleryTask(gid: 403, token: '4030000000', title: 'T3', dirPath: target3.path, fileCount: 50),
      };

      await reconcilePendingIncrementalUpdates(
        baseDownloadIoDir: baseRoot.path,
        findTaskByGid: (gid) async => dbTasks[gid],
        findAllTasks: () async => dbTasks.values.toList(),
      );

      // Symlink target outside baseRoot was NEVER deleted; newer `.info` was preserved and stale staging deleted.
      expect(await outsideRoot.exists(), isTrue);
      expect(
        await File(path.join(target1.path, '.info')).readAsString(),
        contains('"completCount":50'),
      );
      expect(
        await File(path.join(target1.path, kIncrementalStagingInfoFileName)).exists(),
        isFalse,
      );
      // Missing `.info` & missing-token `.info` directories were NOT deleted.
      expect(await File(path.join(noInfoDir.path, 'keep.txt')).exists(), isTrue);
      expect(await File(path.join(tokenlessDir.path, '.info')).exists(), isTrue);

      // 5) Conflicting `.info` alongside leftover tombstone -> `.info` wins and dir is NOT deleted!
      final conflictDir = Directory(path.join(baseRoot.path, '305 - Conflict'))..createSync();
      File(path.join(conflictDir.path, '.info'))
          .writeAsStringSync('{"gid":9999,"token":"9999000000"}\n[]');
      File(path.join(conflictDir.path, kIncrementalRetiringTombstoneFileName))
          .writeAsStringSync('{"oldGid":305,"oldToken":"3050000000","replacedByGid":405}');
      final target5 = Directory(path.join(baseRoot.path, '405 - Target5'))..createSync();
      await writePendingIncrementalJournal(
        targetIoDirPath: target5.path,
        newGid: 405,
        oldGid: 305,
        oldToken: '3050000000',
        oldIoDirPath: conflictDir.path,
        mode: GalleryIncrementalUpdateMode.inPlace,
      );
      dbTasks[405] = GalleryTask(
        gid: 405,
        token: '4050000000',
        title: 'T5',
        dirPath: target5.path,
        fileCount: 10,
      );

      await reconcilePendingIncrementalUpdates(
        baseDownloadIoDir: baseRoot.path,
        findTaskByGid: (gid) async => dbTasks[gid],
        findAllTasks: () async => dbTasks.values.toList(),
      );
      expect(await File(path.join(conflictDir.path, '.info')).exists(), isTrue);

      // 6) `skipDirs` prevents restore from importing a plain unretired directory
      // (no tombstone / no pending journal) that WOULD otherwise be restored.
      final plainDir = Directory(path.join(baseRoot.path, '306 - PlainOld'))
        ..createSync();
      File(path.join(plainDir.path, '.info'))
          .writeAsStringSync('{"gid":306,"token":"3060000000"}\n[]');

      final restoredWithoutSkip = <String>[];
      await StorageAdapter().restoreGalleryTasksWithPath(
        baseRoot.path,
        (File infoFile, String dirPath) async =>
            restoredWithoutSkip.add(dirPath),
      );
      expect(restoredWithoutSkip, contains(plainDir.path));

      final restoredWithSkip = <String>[];
      await StorageAdapter().restoreGalleryTasksWithPath(
        baseRoot.path,
        (File infoFile, String dirPath) async => restoredWithSkip.add(dirPath),
        skipDirs: <String>{
          path.canonicalize(plainDir.resolveSymbolicLinksSync()),
        },
      );
      expect(restoredWithSkip, isNot(contains(plainDir.path)));
    });
  });

  group('UI widgets: GalleryLineageWhisper, GalleryInfoPage, EhSheet, DownloadCard', () {
    setUp(() {
      Get.testMode = true;
      Get.put<LocaleService>(LocaleService());
      Get.put<EhSettingService>(_FakeSettings());
      Get.put<ThemeService>(_FakeTheme());
      Get.put<ControllerTagService>(ControllerTagService());
      Get.find<ThemeService>().themeModel = ThemesModeEnum.darkMode;
    });

    tearDown(Get.reset);

    testWidgets('GalleryLineageWhisper hides when empty and stays compact when present', (tester) async {
      // Case 1: neither newer versions nor parent -> hidden (SizedBox.shrink).
      await tester.pumpWidget(
        _wrapCupertinoApp(
          child: CupertinoPageScaffold(
            child: GalleryLineageWhisper(
              provider: const GalleryProvider(gid: '100'),
              isDownloadedComplete: false,
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.byType(GestureDetector), findsNothing);
      expect(tester.getSize(find.byType(GalleryLineageWhisper)).height, 0);

      // Case 2: newer versions -> >= 44pt height, accentSoft radial glow,
      // crisp text1/text2 with zero text shadows, single-line message.
      var tapped = false;
      await tester.pumpWidget(
        _wrapCupertinoApp(
          child: CupertinoPageScaffold(
            child: Center(
              child: SizedBox(
                width: 340,
                child: GalleryLineageWhisper(
                  provider: const GalleryProvider(
                    gid: '100',
                    parent: '90',
                    parentHref: 'https://e-hentai.org/g/90/aabbccddee/',
                    newerVersions: <GalleryNewerVersion>[
                      GalleryNewerVersion(
                        gid: '200',
                        token: '1122334455',
                        url: 'https://e-hentai.org/g/200/1122334455/',
                        title: 'V2',
                        addedDate: '2026-03-14 08:00',
                      ),
                      GalleryNewerVersion(
                        gid: '201',
                        token: '6677889900',
                        url: 'https://e-hentai.org/g/201/6677889900/',
                        title: 'V3',
                        addedDate: '2026-04-01 09:00',
                      ),
                    ],
                  ),
                  isDownloadedComplete: true,
                  onTap: () => tapped = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('有新版本'), findsOneWidget);
      expect(find.text('04-01 修订 · 可增量更新'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('gallery-lineage-whisper-glow')),
        findsOneWidget,
      );
      final whisperCtx = tester.element(find.text('有新版本'));
      final primaryTextWidget = tester.widget<Text>(find.text('有新版本'));
      final secondaryTextWidget = tester.widget<Text>(
        find.text('04-01 修订 · 可增量更新'),
      );
      expect(primaryTextWidget.style?.shadows, isNull);
      expect(secondaryTextWidget.style?.shadows, isNull);
      expect(
        primaryTextWidget.style?.color,
        ehTheme.palette.text1.resolveFrom(whisperCtx),
      );
      expect(
        secondaryTextWidget.style?.color,
        ehTheme.palette.text2.resolveFrom(whisperCtx),
      );
      final glowBox = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey<String>('gallery-lineage-whisper-glow')),
      );
      final glowGradient =
          (glowBox.decoration as BoxDecoration).gradient! as RadialGradient;
      expect(
        glowGradient.colors.first,
        EhPalette.accentSoft.resolveFrom(whisperCtx),
      );
      final newerHitHeight =
          tester.getSize(find.byType(GestureDetector)).height;
      expect(newerHitHeight, greaterThanOrEqualTo(44));

      await tester.tap(find.byType(GalleryLineageWhisper));
      expect(tapped, isTrue);

      // Case 3: parent only -> >= 44pt height, NO glow, quiet text2 + icon.
      await tester.pumpWidget(
        _wrapCupertinoApp(
          brightness: Brightness.light,
          child: CupertinoPageScaffold(
            child: Center(
              child: SizedBox(
                width: 340,
                child: GalleryLineageWhisper(
                  provider: const GalleryProvider(
                    gid: '201',
                    parent: '100',
                    parentHref: 'https://e-hentai.org/g/100/aabbccddee/',
                  ),
                  isDownloadedComplete: false,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('源自父画廊 · 共 2 个版本'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('gallery-lineage-whisper-glow')),
        findsNothing,
      );
      final parentCtx = tester.element(find.text('源自父画廊 · 共 2 个版本'));
      final parentTextWidget = tester.widget<Text>(find.text('源自父画廊 · 共 2 个版本'));
      expect(parentTextWidget.style?.shadows, isNull);
      expect(
        parentTextWidget.style?.color,
        ehTheme.palette.text2.resolveFrom(parentCtx),
      );
      expect(
        tester.getSize(find.byType(GestureDetector)).height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets(
      'GalleryLineageChain orders Latest -> Intermediate -> Current (non-tappable) -> Parent',
      (tester) async {
        const provider = GalleryProvider(
          gid: '3104821',
          token: '9a4f2c1b8e',
          url: 'https://e-hentai.org/g/3104821/9a4f2c1b8e/',
          englishTitle: 'Current Gallery Title',
          postTime: '2026-11-03 14:22',
          parent: '2841029',
          parentHref: 'https://e-hentai.org/g/2841029/fedcba9876/',
          newerVersions: <GalleryNewerVersion>[
            GalleryNewerVersion(
              gid: '3298500',
              token: '1111111111',
              url: 'https://e-hentai.org/g/3298500/1111111111/',
              title: 'Intermediate Revision',
              addedDate: '2026-11-08 09:41',
            ),
            GalleryNewerVersion(
              gid: '3298510',
              token: '1234567890',
              url: 'https://e-hentai.org/g/3298510/1234567890/',
              title: 'Latest Revision',
              addedDate: '2026-11-22 14:03',
            ),
          ],
        );

        final openedUrls = <String>[];
        final copiedValues = <String>[];

        await tester.pumpWidget(
          _wrapCupertinoApp(
            child: CupertinoPageScaffold(
              child: GalleryLineageChain(
                provider: provider,
                currentTitle: 'Current Gallery Title',
                isDownloaded: true,
                onOpen: openedUrls.add,
                onCopy: copiedValues.add,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final latestY = tester.getTopLeft(find.text('Latest Revision')).dy;
        final midY = tester.getTopLeft(find.text('Intermediate Revision')).dy;
        final currentY =
            tester.getTopLeft(find.text('Current Gallery Title')).dy;
        final parentY = tester.getTopLeft(find.text('父画廊')).dy;

        expect(latestY, lessThan(midY));
        expect(midY, lessThan(currentY));
        expect(currentY, lessThan(parentY));
        expect(find.text('最新'), findsOneWidget);
        expect(find.text('当前'), findsOneWidget);
        expect(find.text('11-03 · 已下载'), findsOneWidget);

        // Current row is NOT tappable.
        await tester.tap(find.text('Current Gallery Title'));
        expect(openedUrls, isEmpty);

        // Latest, intermediate, and parent rows ARE tappable.
        await tester.tap(find.text('Latest Revision'));
        await tester.tap(find.text('Intermediate Revision'));
        await tester.tap(find.text('父画廊'));
        expect(openedUrls, <String>[
          'https://e-hentai.org/g/3298510/1234567890/',
          'https://e-hentai.org/g/3298500/1111111111/',
          'https://e-hentai.org/g/2841029/fedcba9876/',
        ]);

        // Long press copies normalized URL.
        await tester.longPress(find.text('Latest Revision'));
        expect(copiedValues, <String>[
          'https://e-hentai.org/g/3298510/1234567890/',
        ]);
      },
    );

    testWidgets(
      'GalleryLineageSheet adapts primary CTA for downloaded / not-downloaded / parent-only',
      (tester) async {
        const withNewer = GalleryProvider(
          gid: '3104821',
          token: '9a4f2c1b8e',
          englishTitle: 'Base Gallery',
          parent: '2841029',
          parentHref: 'https://e-hentai.org/g/2841029/fedcba9876/',
          newerVersions: <GalleryNewerVersion>[
            GalleryNewerVersion(
              gid: '3298510',
              token: '1234567890',
              url: 'https://e-hentai.org/g/3298510/1234567890/',
              title: 'Latest Gallery',
              addedDate: '2026-11-22 14:03',
            ),
          ],
        );
        final downloadedTask = GalleryTask(
          gid: 3104821,
          token: '9a4f2c1b8e',
          title: 'Base Gallery',
          dirPath: '/tmp/base',
          fileCount: 20,
          completCount: 20,
          status: TaskStatus.complete.value,
        );

        // Downloaded + newer -> primary button is "增量更新到最新版".
        await tester.pumpWidget(
          _wrapCupertinoApp(
            child: CupertinoPageScaffold(
              child: GalleryLineageSheet(
                provider: withNewer,
                downloadedTask: downloadedTask,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('版本血缘'), findsOneWidget);
        expect(find.text('共 3 个版本'), findsOneWidget);
        expect(find.text('增量更新到最新版'), findsOneWidget);

        // Not downloaded + newer -> primary button is "打开最新版本".
        await tester.pumpWidget(
          _wrapCupertinoApp(
            child: const CupertinoPageScaffold(
              child: GalleryLineageSheet(provider: withNewer),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('打开最新版本'), findsOneWidget);

        // Parent only -> NO primary prominent button.
        const parentOnly = GalleryProvider(
          gid: '3298510',
          token: '1234567890',
          englishTitle: 'Latest Gallery',
          parent: '3104821',
          parentHref: 'https://e-hentai.org/g/3104821/9a4f2c1b8e/',
        );
        await tester.pumpWidget(
          _wrapCupertinoApp(
            child: const CupertinoPageScaffold(
              child: GalleryLineageSheet(provider: parentOnly),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('共 2 个版本'), findsOneWidget);
        expect(find.text('增量更新到最新版'), findsNothing);
        expect(find.text('打开最新版本'), findsNothing);

        // When the newer version is already in galleryTaskMap, hide incremental CTA.
        final dlCtrl = Get.put<DownloadController>(_FakeDownloadController());
        dlCtrl.dState.galleryTaskMap[3298510] = GalleryTask(
          gid: 3298510,
          token: '1234567890',
          title: 'Latest Gallery',
          dirPath: '/tmp/latest',
          fileCount: 24,
          completCount: 24,
          status: TaskStatus.complete.value,
        );
        await tester.pumpWidget(
          _wrapCupertinoApp(
            child: CupertinoPageScaffold(
              child: GalleryLineageSheet(
                provider: withNewer,
                downloadedTask: downloadedTask,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('增量更新到最新版'), findsNothing);
        expect(find.text('打开最新版本'), findsOneWidget);
      },
    );

    testWidgets(
      'formatLineageDistinguishingTitle preserves distinguishing version suffix in chain and menu',
      (tester) async {
        const currentTitle = 'dekamofuchan/@chiiko_tanunu Updated 10/14/2026';
        const latestTitle = 'dekamofuchan/@chiiko_tanunu Updated 10/28/2026';
        const midTitle = 'dekamofuchan/@chiiko_tanunu Updated 10/20/2026';

        expect(
          formatLineageDistinguishingTitle(
            title: latestTitle,
            currentTitle: currentTitle,
          ),
          contains('Updated 10/28/2026'),
        );
        expect(
          formatLineageDistinguishingTitle(
            title: currentTitle,
            currentTitle: currentTitle,
          ),
          currentTitle,
        );
        expect(
          formatLineageDistinguishingTitle(
            title: 'Short V2',
            currentTitle: 'Short V1',
          ),
          'Short V2',
        );

        const versions = <GalleryNewerVersion>[
          GalleryNewerVersion(
            gid: '4288330',
            token: '254131c601',
            url: 'https://e-hentai.org/g/4288330/254131c601/',
            title: latestTitle,
            addedDate: '2026-10-28 12:00',
          ),
          GalleryNewerVersion(
            gid: '4269523',
            token: '23e7918173',
            url: 'https://e-hentai.org/g/4269523/23e7918173/',
            title: midTitle,
            addedDate: '2026-10-20 12:00',
          ),
        ];

        // 1. GalleryLineageChain displays distinguishing suffix with maxLines == 2.
        await tester.pumpWidget(
          _wrapCupertinoApp(
            child: const CupertinoPageScaffold(
              child: SizedBox(
                width: 320,
                child: GalleryLineageChain(
                  provider: GalleryProvider(
                    gid: '4255250',
                    token: '65441d5197',
                    englishTitle: currentTitle,
                    postTime: '2026-10-14 22:21',
                    newerVersions: versions,
                  ),
                  currentTitle: currentTitle,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final latestTextFinder = find.textContaining('Updated 10/28/2026');
        expect(latestTextFinder, findsOneWidget);
        expect(tester.widget<Text>(latestTextFinder).maxLines, 2);
        expect(find.textContaining('Updated 10/20/2026'), findsOneWidget);

        // 2. GalleryIncrementalUpdateSheet target menu also shows distinguishing suffix.
        final task = GalleryTask(
          gid: 4255250,
          token: '65441d5197',
          title: currentTitle,
          dirPath: '/tmp/deka',
          fileCount: 40,
          completCount: 40,
          status: TaskStatus.complete.value,
        );
        await tester.pumpWidget(
          _wrapCupertinoApp(
            child: CupertinoPageScaffold(
              child: GalleryIncrementalUpdateSheet(
                oldTask: task,
                newerVersions: versions,
                analyzePlan: ({required oldTask, required targetVersion, cancelToken}) async =>
                    GalleryIncrementalPlan(
                      oldTask: oldTask,
                      targetVersion: targetVersion,
                      targetProvider: GalleryProvider(
                        gid: targetVersion.gid,
                        token: targetVersion.token,
                        filecount: '48',
                      ),
                      targetImages: const <GalleryImage>[],
                      reusedPages: const <GalleryPageReuse>[],
                      pagesToDownload: const <GalleryImage>[],
                      addedCount: 8,
                      replacedCount: 0,
                      totalNewPages: 48,
                      firstPageCount: 40,
                    ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('目标版本'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Updated 10/28/2026'), findsOneWidget);
        expect(find.textContaining('Updated 10/20/2026'), findsOneWidget);
        expect(find.text('10-28 · #4288330'), findsOneWidget);
        expect(find.text('10-20 · #4269523'), findsOneWidget);
      },
    );

    testWidgets('GalleryInfoPage renders shared chain, tonal CTA, and stable height placeholder', (tester) async {
      final dlCtrl = Get.put<DownloadController>(_FakeDownloadController());
      final state = GalleryPageState()
        ..galleryProvider = const GalleryProvider(
          gid: '3104821',
          token: '9a4f2c1b8e',
          url: 'https://e-hentai.org/g/3104821/9a4f2c1b8e/',
          englishTitle: 'Yoimachi Dusk Vol.2',
          parent: '2841029',
          parentHref: 'https://e-hentai.org/g/2841029/fedcba9876/',
          newerVersions: <GalleryNewerVersion>[
            GalleryNewerVersion(
              gid: '3298510',
              token: '1234567890',
              url: 'https://e-hentai.org/g/3298510/1234567890/',
              title: 'Yoimachi [Expanded]',
              addedDate: '2026-03-14 08:20',
            ),
          ],
        );

      final ctrlTag = Get.find<ControllerTagService>().pushPageCtrl(
        gid: '3104821',
      );
      Get.put<GalleryPageController>(
        _FakeGalleryPageController(state),
        tag: ctrlTag,
      );

      final openedUrls = <String>[];
      var incrementalOpened = false;

      // 1. Never downloaded: no reserved empty placeholder at bottom of card.
      await tester.pumpWidget(
        _wrapCupertinoApp(
          child: GalleryInfoPage(
            onOpenGalleryUrl: openedUrls.add,
            onIncrementalUpdate: (_, _, _) => incrementalOpened = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('版本血缘'), findsOneWidget);
      expect(find.text('点按跳转 · 长按复制'), findsNothing);
      expect(find.text('增量更新到最新版'), findsNothing);
      final detailsYUndownloaded = tester.getTopLeft(find.text('画廊属性')).dy;

      // 2. Active in-progress download: 44pt slot is reserved to prevent jump on completion.
      dlCtrl.dState.galleryTaskMap[3104821] = GalleryTask(
        gid: 3104821,
        token: '9a4f2c1b8e',
        title: 'Yoimachi',
        dirPath: '/tmp/yoimachi',
        fileCount: 48,
        completCount: 20,
        status: TaskStatus.running.value,
      );
      await tester.pumpAndSettle();

      expect(find.text('增量更新到最新版'), findsNothing);
      final detailsYBefore = tester.getTopLeft(find.text('画廊属性')).dy;
      expect(detailsYBefore, greaterThan(detailsYUndownloaded + 40));

      // 3. After download completes: tonal CTA appears without shifting section Y.
      dlCtrl.dState.galleryTaskMap[3104821] = dlCtrl
          .dState
          .galleryTaskMap[3104821]!
          .copyWith(completCount: 48, status: TaskStatus.complete.value);
      await tester.pumpAndSettle();

      final detailsYAfter = tester.getTopLeft(find.text('画廊属性')).dy;
      expect(detailsYAfter, closeTo(detailsYBefore, 1.0));
      expect(find.text('#2841029'), findsOneWidget);
      expect(find.text('Yoimachi [Expanded]'), findsOneWidget);
      expect(find.text('最新'), findsOneWidget);
      expect(find.text('增量更新到最新版'), findsOneWidget);

      await tester.tap(find.text('#2841029'));
      await tester.tap(find.text('Yoimachi [Expanded]'));
      await tester.tap(find.text('增量更新到最新版'));

      expect(openedUrls, <String>[
        'https://e-hentai.org/g/2841029/fedcba9876/',
        'https://e-hentai.org/g/3298510/1234567890/',
      ]);
      expect(incrementalOpened, isTrue);

      // 4. Once the newer version itself is downloaded, incremental CTA hides.
      dlCtrl.dState.galleryTaskMap[3298510] = GalleryTask(
        gid: 3298510,
        token: '1234567890',
        title: 'Yoimachi [Expanded]',
        dirPath: '/tmp/yoimachi2',
        fileCount: 52,
        completCount: 52,
        status: TaskStatus.complete.value,
      );
      await tester.pumpAndSettle();
      expect(find.text('增量更新到最新版'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('GalleryIncrementalUpdateSheet covers loading, error, 0-page, and normal states', (tester) async {
      final oldTask = GalleryTask(
        gid: 3104821,
        token: '9a4f2c1b8e',
        title: 'Yoimachi',
        dirPath: '/tmp/yoimachi',
        fileCount: 48,
        completCount: 48,
        status: TaskStatus.complete.value,
      );
      const targetVersion = GalleryNewerVersion(
        gid: '3298510',
        token: '1234567890',
        url: 'https://e-hentai.org/g/3298510/1234567890/',
        title: 'Yoimachi [Expanded]',
        addedDate: '2026-03-14 08:20',
      );
      final normalPlan = GalleryIncrementalPlan(
        oldTask: oldTask,
        targetVersion: targetVersion,
        targetProvider: const GalleryProvider(
          gid: '3298510',
          token: '1234567890',
          filecount: '56',
        ),
        targetImages: const <GalleryImage>[],
        reusedPages: List<GalleryPageReuse>.generate(
          46,
          (i) => GalleryPageReuse(
            newSer: i + 1,
            oldSer: i + 1,
            oldFileName: '0001.jpg',
            imgKey: 'key$i',
            newImage: GalleryImage(ser: i + 1),
          ),
        ),
        pagesToDownload: List<GalleryImage>.generate(
          10,
          (i) => GalleryImage(ser: 47 + i),
        ),
        addedCount: 8,
        replacedCount: 2,
        totalNewPages: 56,
        firstPageCount: 40,
        mappedReadingIndex: 17,
      );

      // 1. Loading -> Error -> Retry -> Normal.
      var attempt = 0;
      final firstCompleter = Completer<GalleryIncrementalPlan>();
      GalleryIncrementalUpdateMode? executedMode;

      await tester.pumpWidget(
        _wrapCupertinoApp(
          child: CupertinoPageScaffold(
            child: GalleryIncrementalUpdateSheet(
              oldTask: oldTask,
              newerVersions: const <GalleryNewerVersion>[targetVersion],
              analyzePlan: ({required oldTask, required targetVersion, cancelToken}) {
                attempt++;
                if (attempt == 1) {
                  return firstCompleter.future;
                }
                return Future<GalleryIncrementalPlan>.value(normalPlan);
              },
              executePlan: (plan, {required mode}) async {
                executedMode = mode;
                return GalleryIncrementalExecutionResult(
                  task: oldTask.copyWith(gid: 3298510),
                  reusedCount: 46,
                  downloadCount: 10,
                  completedLocally: false,
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Loading state: spinner + text, no x/N progress, primary CTA disabled.
      expect(find.text('正在比对新版页面…'), findsOneWidget);
      expect(find.text('开始更新'), findsOneWidget);
      final loadingPrimary = tester.widget<EhButton>(
        find.widgetWithText(EhButton, '开始更新'),
      );
      expect(loadingPrimary.onPressed, isNull);
      final loadingGroupHeight =
          tester.getSize(find.byType(EhSheetGroup).at(1)).height;

      // Fail first attempt -> error state keeps card height stable.
      firstCompleter.completeError(Exception('network timeout'));
      await tester.pumpAndSettle();
      expect(find.text('比对新版页面失败'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      final errorGroupHeight =
          tester.getSize(find.byType(EhSheetGroup).at(1)).height;
      expect(errorGroupHeight, greaterThanOrEqualTo(112));
      expect((errorGroupHeight - loadingGroupHeight).abs(), lessThan(24));

      // Retry -> loads normal plan with approx replaced label & two-mode segment.
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('新版共 56 页'), findsOneWidget);
      expect(find.text('复用 46 页'), findsOneWidget);
      expect(find.text('新增 8 · 修订约 2'), findsOneWidget);
      expect(find.text('开始更新'), findsOneWidget);
      // Verify the 8pt two-color diff bar segments actually paint at full 8pt height.
      final diffColoredBoxes = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .where((box) => box.child is SizedBox)
          .toList();
      expect(diffColoredBoxes.length, greaterThanOrEqualTo(2));
      for (final finder in <Finder>[
        find.byWidget(diffColoredBoxes.first),
        find.byWidget(diffColoredBoxes.last),
      ]) {
        expect(tester.getSize(finder).height, 8);
      }

      // Switch segment to newTask and verify footnote changes.
      await tester.tap(find.text('保留，另存新任务'));
      await tester.pumpAndSettle();
      expect(find.text('新建任务并复用未改动页面，旧版保持不变。'), findsOneWidget);

      await tester.tap(find.text('开始更新'));
      await tester.pumpAndSettle();
      oktoast.dismissAllToast();
      await tester.pump(const Duration(seconds: 4));
      expect(executedMode, GalleryIncrementalUpdateMode.newTask);
      expect(tester.takeException(), isNull);
    });

    testWidgets('GalleryIncrementalUpdateSheet shows reuse-only CTA for 0-page updates', (tester) async {
      final oldTask = GalleryTask(
        gid: 3104821,
        token: '9a4f2c1b8e',
        title: 'Yoimachi',
        dirPath: '/tmp/yoimachi',
        fileCount: 48,
        completCount: 48,
        status: TaskStatus.complete.value,
      );
      const targetVersion = GalleryNewerVersion(
        gid: '3298510',
        token: '1234567890',
        url: 'https://e-hentai.org/g/3298510/1234567890/',
        title: 'Yoimachi [Expanded]',
        addedDate: '2026-03-14 08:20',
      );
      final zeroFetchPlan = GalleryIncrementalPlan(
        oldTask: oldTask,
        targetVersion: targetVersion,
        targetProvider: const GalleryProvider(
          gid: '3298510',
          token: '1234567890',
          filecount: '48',
        ),
        targetImages: const <GalleryImage>[],
        reusedPages: List<GalleryPageReuse>.generate(
          48,
          (i) => GalleryPageReuse(
            newSer: i + 1,
            oldSer: i + 1,
            oldFileName: '0001.jpg',
            imgKey: 'key$i',
            newImage: GalleryImage(ser: i + 1),
          ),
        ),
        pagesToDownload: const <GalleryImage>[],
        addedCount: 0,
        replacedCount: 0,
        totalNewPages: 48,
        firstPageCount: 40,
      );
      await tester.pumpWidget(
        _wrapCupertinoApp(
          child: CupertinoPageScaffold(
            child: GalleryIncrementalUpdateSheet(
              key: const ValueKey<String>('zero-fetch-sheet'),
              oldTask: oldTask,
              newerVersions: const <GalleryNewerVersion>[targetVersion],
              analyzePlan: ({required oldTask, required targetVersion, cancelToken}) async =>
                  zeroFetchPlan,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('立即完成更新'), findsOneWidget);
      expect(find.text('全部页面可直接复用'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('GalleryInfoPage hides lineage when absent and degrades static parent', (tester) async {
      Get.put<DownloadController>(_FakeDownloadController());

      // Case 1: neither parent nor newer versions -> lineage section hidden.
      final emptyState = GalleryPageState()
        ..galleryProvider = const GalleryProvider(
          gid: '5001',
          token: 'aaaaaaaaaa',
          url: 'https://e-hentai.org/g/5001/aaaaaaaaaa/',
          englishTitle: 'Standalone Gallery',
          parent: 'None',
        );
      final tag1 = Get.find<ControllerTagService>().pushPageCtrl(gid: '5001');
      Get.put<GalleryPageController>(_FakeGalleryPageController(emptyState), tag: tag1);

      await tester.pumpWidget(_wrapCupertinoApp(child: const GalleryInfoPage()));
      await tester.pumpAndSettle();

      expect(find.text('版本血缘'), findsNothing);
      expect(find.text('Standalone Gallery'), findsOneWidget);

      // Case 2: parent text present without parentHref -> lineage shown, not navigable.
      final staticParentState = GalleryPageState()
        ..galleryProvider = const GalleryProvider(
          gid: '5002',
          token: 'bbbbbbbbbb',
          url: 'https://e-hentai.org/g/5002/bbbbbbbbbb/',
          englishTitle: 'Static Parent Gallery',
          parent: '4999',
        );
      final tag2 = Get.find<ControllerTagService>().pushPageCtrl(gid: '5002');
      Get.put<GalleryPageController>(
        _FakeGalleryPageController(staticParentState),
        tag: tag2,
      );

      final opened = <String>[];
      await tester.pumpWidget(
        _wrapCupertinoApp(
          brightness: Brightness.light,
          child: GalleryInfoPage(
            key: const ValueKey<String>('static-parent'),
            onOpenGalleryUrl: opened.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('版本血缘'), findsOneWidget);
      expect(find.text('4999'), findsOneWidget);
      await tester.tap(find.text('4999'));
      await tester.pumpAndSettle();
      oktoast.dismissAllToast();
      await tester.pump(const Duration(seconds: 4));
      expect(opened, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('GalleryIncrementalUpdateSheet forces newTask for SAF paths and selects versions via menu', (tester) async {
      final safTask = GalleryTask(
        gid: 9001,
        token: '9999999999',
        title: 'SAF Gallery',
        dirPath: 'content://com.android.externalstorage.documents/tree/primary%3Aeh',
        fileCount: 20,
        completCount: 20,
        status: TaskStatus.complete.value,
      );
      const versions = <GalleryNewerVersion>[
        GalleryNewerVersion(
          gid: '9003',
          token: '3333333333',
          url: 'https://e-hentai.org/g/9003/3333333333/',
          title: 'SAF Gallery [V3]',
          addedDate: '2026-04-01 00:00',
        ),
        GalleryNewerVersion(
          gid: '9002',
          token: '2222222222',
          url: 'https://e-hentai.org/g/9002/2222222222/',
          title: 'SAF Gallery [V2]',
          addedDate: '2026-03-01 00:00',
        ),
      ];

      final analyzedGids = <String>[];
      GalleryIncrementalUpdateMode? executedMode;

      await tester.pumpWidget(
        _wrapCupertinoApp(
          brightness: Brightness.light,
          child: CupertinoPageScaffold(
            child: GalleryIncrementalUpdateSheet(
              oldTask: safTask,
              newerVersions: versions,
              analyzePlan: ({required oldTask, required targetVersion, cancelToken}) async {
                analyzedGids.add(targetVersion.gid);
                return GalleryIncrementalPlan(
                  oldTask: oldTask,
                  targetVersion: targetVersion,
                  targetProvider: GalleryProvider(
                    gid: targetVersion.gid,
                    token: targetVersion.token,
                    filecount: '24',
                  ),
                  targetImages: const <GalleryImage>[],
                  reusedPages: List<GalleryPageReuse>.generate(
                    20,
                    (i) => GalleryPageReuse(
                      newSer: i + 1,
                      oldSer: i + 1,
                      oldFileName: '0001.jpg',
                      imgKey: 'k$i',
                      newImage: GalleryImage(ser: i + 1),
                    ),
                  ),
                  pagesToDownload: List<GalleryImage>.generate(
                    4,
                    (i) => GalleryImage(ser: 21 + i),
                  ),
                  addedCount: 4,
                  replacedCount: 0,
                  totalNewPages: 24,
                  firstPageCount: 24,
                  canReuseLocalFiles: false,
                );
              },
              executePlan: (plan, {required mode}) async {
                executedMode = mode;
                return GalleryIncrementalExecutionResult(
                  task: safTask.copyWith(gid: int.parse(plan.targetVersion.gid)),
                  reusedCount: 0,
                  downloadCount: 24,
                  completedLocally: false,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default analyzes newest version (9003), SAF shows honest full-download CTA.
      expect(analyzedGids, <String>['9003']);
      expect(find.text('完整下载新版'), findsOneWidget);
      expect(find.text('无法复用'), findsOneWidget);
      expect(find.text('当前存储位置（SAF）不能复用本地文件'), findsOneWidget);

      // Open target version menu and pick V2 (analyzes once).
      await tester.tap(find.text('目标版本'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('V2'));
      await tester.pumpAndSettle();
      expect(analyzedGids, <String>['9003', '9002']);

      // Tapping in-place segment should remain on newTask for SAF.
      await tester.tap(find.text('替换'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('完整下载新版'));
      await tester.pumpAndSettle();
      oktoast.dismissAllToast();
      await tester.pump(const Duration(seconds: 4));

      expect(executedMode, GalleryIncrementalUpdateMode.newTask);
      expect(tester.takeException(), isNull);
    });

    testWidgets('GalleryIncrementalUpdateSheet ignores stale CancelException on rapid version switch', (tester) async {
      final oldTask = GalleryTask(
        gid: 7001,
        token: '7777777777',
        title: 'Race Test',
        dirPath: '/tmp/race',
        fileCount: 10,
        completCount: 10,
        status: TaskStatus.complete.value,
      );
      const versions = <GalleryNewerVersion>[
        GalleryNewerVersion(
          gid: '7003',
          token: '3333333333',
          url: 'https://e-hentai.org/g/7003/3333333333/',
          title: 'Race [V3]',
          addedDate: '2026-04-01 00:00',
        ),
        GalleryNewerVersion(
          gid: '7002',
          token: '2222222222',
          url: 'https://e-hentai.org/g/7002/2222222222/',
          title: 'Race [V2]',
          addedDate: '2026-03-01 00:00',
        ),
      ];

      final firstCompleter = Completer<GalleryIncrementalPlan>();
      var callCount = 0;

      await tester.pumpWidget(
        _wrapCupertinoApp(
          child: CupertinoPageScaffold(
            child: GalleryIncrementalUpdateSheet(
              oldTask: oldTask,
              newerVersions: versions,
              analyzePlan: ({required oldTask, required targetVersion, cancelToken}) {
                callCount++;
                if (callCount == 1) {
                  return firstCompleter.future;
                }
                return Future<GalleryIncrementalPlan>.value(
                  GalleryIncrementalPlan(
                    oldTask: oldTask,
                    targetVersion: targetVersion,
                    targetProvider: GalleryProvider(
                      gid: targetVersion.gid,
                      token: targetVersion.token,
                      filecount: '12',
                    ),
                    targetImages: const <GalleryImage>[],
                    reusedPages: const <GalleryPageReuse>[],
                    pagesToDownload: List<GalleryImage>.generate(
                      12,
                      (i) => GalleryImage(ser: i + 1),
                    ),
                    addedCount: 2,
                    replacedCount: 10,
                    totalNewPages: 12,
                    firstPageCount: 12,
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Switch immediately via menu while first request is still pending.
      // Loading spinner animates continuously, so use bounded pumps instead of pumpAndSettle.
      await tester.tap(find.text('目标版本'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('V2'));
      await tester.pumpAndSettle();
      expect(find.text('新版共 12 页'), findsOneWidget);

      // Now first request fails late with CancelException -> must NOT clobber V2 plan!
      firstCompleter.completeError(CancelException('stale cancel'));
      await tester.pumpAndSettle();

      expect(find.text('新版共 12 页'), findsOneWidget);
      expect(find.text('比对新版页面失败'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Russian narrow 320px at 1.6x text scale does not overflow or clip primary CTA', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Get.put<DownloadController>(_FakeDownloadController());
      final state = GalleryPageState()
        ..galleryProvider = const GalleryProvider(
          gid: '8001',
          token: '8888888888',
          url: 'https://e-hentai.org/g/8001/8888888888/',
          englishTitle: 'Russian Narrow Test',
          parent: '7999',
          parentHref: 'https://e-hentai.org/g/7999/9999999999/',
        );
      final tag = Get.find<ControllerTagService>().pushPageCtrl(gid: '8001');
      Get.put<GalleryPageController>(_FakeGalleryPageController(state), tag: tag);

      await tester.pumpWidget(
        _wrapCupertinoApp(
          locale: const Locale('ru'),
          child: const MediaQuery(
            data: MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.6),
            ),
            child: GalleryInfoPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Also verify GalleryIncrementalUpdateSheet in Russian at 320px / 1.6x.
      final ruTask = GalleryTask(
        gid: 8001,
        token: '8888888888',
        title: 'Russian Narrow Test',
        dirPath: '/tmp/ru',
        fileCount: 20,
        completCount: 20,
        status: TaskStatus.complete.value,
      );
      const ruVer = GalleryNewerVersion(
        gid: '8002',
        token: '9999999999',
        url: 'https://e-hentai.org/g/8002/9999999999/',
        title: 'Russian Narrow Test [v2]',
        addedDate: '2026-11-22 10:00',
      );
      await tester.pumpWidget(
        _wrapCupertinoApp(
          locale: const Locale('ru'),
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.6),
            ),
            child: CupertinoPageScaffold(
              child: GalleryIncrementalUpdateSheet(
                oldTask: ruTask,
                newerVersions: const <GalleryNewerVersion>[ruVer],
                analyzePlan: ({required oldTask, required targetVersion, cancelToken}) async =>
                    GalleryIncrementalPlan(
                      oldTask: oldTask,
                      targetVersion: targetVersion,
                      targetProvider: const GalleryProvider(
                        gid: '8002',
                        token: '9999999999',
                        filecount: '24',
                      ),
                      targetImages: const <GalleryImage>[],
                      reusedPages: List<GalleryPageReuse>.generate(
                        20,
                        (i) => GalleryPageReuse(
                          newSer: i + 1,
                          oldSer: i + 1,
                          oldFileName: '0001.jpg',
                          imgKey: 'k$i',
                          newImage: GalleryImage(ser: i + 1),
                        ),
                      ),
                      pagesToDownload: List<GalleryImage>.generate(
                        4,
                        (i) => GalleryImage(ser: 21 + i),
                      ),
                      addedCount: 4,
                      replacedCount: 0,
                      totalNewPages: 24,
                      firstPageCount: 24,
                    ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ctaFinder = find.text('Обновить');
      expect(ctaFinder, findsOneWidget);
      final ctaText = tester.widget<Text>(ctaFinder);
      final tp = TextPainter(
        text: TextSpan(text: ctaText.data, style: ctaText.style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
        textScaler: const TextScaler.linear(1.6),
      )..layout(maxWidth: tester.getSize(ctaFinder).width + 1);
      expect(tp.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('DownloadGalleryItem displays _UpdateRow, incremental progress, and failed retry cleanly', (tester) async {
      final view = _FakeDownloadViewController();
      Get.put<DownloadViewController>(view);
      final completeTask = GalleryTask(
        gid: 100,
        token: 'tok100',
        title: 'Completed With Update',
        dirPath: null,
        fileCount: 48,
        completCount: 48,
        status: TaskStatus.complete.value,
        rating: 4.8,
        category: 'Non-H',
        uploader: 'uploader',
        addTime: 0,
      );
      final updatingTask = GalleryTask(
        gid: 200,
        token: 'tok200',
        title: 'Incremental Running Gallery',
        dirPath: null,
        fileCount: 56,
        completCount: 50,
        status: TaskStatus.running.value,
        uploader: 'uploader',
        addTime: 0,
      );
      final pausedTask = GalleryTask(
        gid: 250,
        token: 'tok250',
        title: 'Incremental Paused Gallery',
        dirPath: null,
        fileCount: 56,
        completCount: 50,
        status: TaskStatus.paused.value,
        uploader: 'uploader',
        addTime: 0,
      );
      final failedTask = GalleryTask(
        gid: 300,
        token: 'tok300',
        title: 'Incremental Failed Gallery',
        dirPath: null,
        fileCount: 64,
        completCount: 61,
        status: TaskStatus.failed.value,
        uploader: 'uploader',
        addTime: 0,
      );
      final plainCompleteTask = GalleryTask(
        gid: 400,
        token: 'tok400',
        title: 'Plain Complete Gallery',
        dirPath: null,
        fileCount: 20,
        completCount: 20,
        status: TaskStatus.complete.value,
        rating: 4.5,
        category: 'Non-H',
        uploader: 'uploader',
        addTime: 0,
      );
      view.galleryTaskMap[100] = completeTask;
      view.galleryTaskMap[200] = updatingTask;
      view.galleryTaskMap[250] = pausedTask;
      view.galleryTaskMap[300] = failedTask;
      view.galleryTaskMap[400] = plainCompleteTask;

      var tappedUpdate = false;
      await tester.pumpWidget(
        _wrapCupertinoApp(
          child: CupertinoPageScaffold(
            child: ListView(
              children: <Widget>[
                DownloadGalleryItem(
                  galleryTask: completeTask,
                  taskIndex: 0,
                  updateInfo: GalleryUpdateInfo(
                    sourceGid: 100,
                    newerVersions: const <GalleryNewerVersion>[
                      GalleryNewerVersion(
                        gid: '200',
                        token: 'tok200',
                        url: 'https://e-hentai.org/g/200/tok200/',
                        title: 'Newer',
                        addedDate: '2026-03-14 08:00',
                      ),
                    ],
                    checkedAt: DateTime(2026, 3, 14),
                  ),
                  onTapUpdate: () => tappedUpdate = true,
                ),
                DownloadGalleryItem(
                  galleryTask: updatingTask,
                  taskIndex: 1,
                  speed: '2.4 MB',
                  incrementalProgress: const GalleryIncrementalProgress(
                    gid: 200,
                    reusedCount: 46,
                    totalCount: 56,
                    mode: GalleryIncrementalUpdateMode.inPlace,
                  ),
                ),
                DownloadGalleryItem(
                  galleryTask: pausedTask,
                  taskIndex: 2,
                  incrementalProgress: const GalleryIncrementalProgress(
                    gid: 250,
                    reusedCount: 46,
                    totalCount: 56,
                    mode: GalleryIncrementalUpdateMode.inPlace,
                  ),
                ),
                DownloadGalleryItem(
                  galleryTask: failedTask,
                  taskIndex: 3,
                  errInfo: '3 页下载出错',
                  incrementalProgress: const GalleryIncrementalProgress(
                    gid: 300,
                    reusedCount: 60,
                    totalCount: 64,
                    mode: GalleryIncrementalUpdateMode.inPlace,
                  ),
                ),
                DownloadGalleryItem(
                  galleryTask: plainCompleteTask,
                  taskIndex: 4,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Old cover badge & rating-row pill are gone.
      expect(find.text('有新版 ›'), findsNothing);
      expect(find.text('增量中'), findsNothing);
      // New _UpdateRow with 44pt target + tonal "更新" button.
      final updateTarget = find.byKey(
        const ValueKey<String>('download-card-update-action'),
      );
      expect(updateTarget, findsOneWidget);
      expect(tester.getSize(updateTarget).height, greaterThanOrEqualTo(44));
      expect(find.text('更新'), findsOneWidget);

      await tester.tap(updateTarget);
      expect(tappedUpdate, isTrue);

      // Incremental running status, speed, delta progress, and >=44pt pause control.
      expect(find.text('更新中 · 复用 46 页'), findsOneWidget);
      expect(find.text('2.4 MB/s · 下载 4 / 10'), findsOneWidget);
      final controlTargets = find.byKey(
        const ValueKey<String>('download-incremental-control'),
      );
      expect(controlTargets, findsNWidgets(2));
      expect(tester.getSize(controlTargets.at(0)).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(controlTargets.at(0)).height, greaterThanOrEqualTo(44));
      await tester.tap(controlTargets.at(0));
      expect(view.pausedGids, <int>[200]);

      // Incremental paused status & >=44pt resume control.
      expect(find.text('已暂停 · 复用 46 页'), findsOneWidget);
      expect(find.text('下载 4 / 10'), findsOneWidget);
      expect(tester.getSize(controlTargets.at(1)).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(controlTargets.at(1)).height, greaterThanOrEqualTo(44));
      await tester.tap(controlTargets.at(1));
      expect(view.resumedGids, <int>[250]);

      // Failed incremental status & retry button.
      expect(find.text('更新失败 · 3 页下载出错'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      await tester.tap(find.text('重试'));
      expect(view.resumedGids, <int>[250, 300]);

      // Complete task checkmark uses EhPalette.accent instead of activeBlue.
      final completeItem = find.byWidgetPredicate(
        (w) => w is DownloadGalleryItem && w.galleryTask.gid == 400,
      );
      final completeTheme = tester.widget<CupertinoTheme>(
        find.descendant(
          of: completeItem,
          matching: find.byType(CupertinoTheme),
        ).first,
      );
      final completeCtx = tester.element(completeItem);
      expect(
        completeTheme.data.primaryColor,
        EhPalette.accent.resolveFrom(completeCtx),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('DownloadGalleryView supports stop, filter (with updating/failed), dismiss, and no-targets', (tester) async {
      final dlCtrl = _FakeDownloadController();
      Get.put<DownloadController>(dlCtrl);

      final blockCheck = Completer<GalleryProvider?>();
      final service = GalleryUpdateService(
        fetchDetail: ({
          required String url,
          bool refresh = false,
          CancelToken? cancelToken,
        }) async {
          cancelToken?.whenCancel.then((_) {
            if (!blockCheck.isCompleted) {
              blockCheck.completeError(
                DioException.requestCancelled(
                  requestOptions: RequestOptions(path: url),
                  reason: 'cancelled',
                ),
              );
            }
          });
          return blockCheck.future;
        },
      );
      final viewCtrl = _TestableDownloadViewController(updateService: service);
      Get.put<DownloadViewController>(viewCtrl);

      await tester.pumpWidget(
        _wrapCupertinoApp(
          child: const CupertinoPageScaffold(child: DownloadGalleryView()),
        ),
      );
      await tester.pumpAndSettle();

      // 1. No completed targets -> shows download_updates_no_targets, not "all up to date".
      final buildCtx = tester.element(find.byType(DownloadGalleryView));
      final emptyResult = await viewCtrl.checkAllGalleryUpdates(context: buildCtx);
      await tester.pump();
      expect(emptyResult?.checkedCount, 0);
      expect(viewCtrl.hasCompletedUpdateCheck.value, isFalse);
      oktoast.dismissAllToast();
      await tester.pump(const Duration(seconds: 4));

      // 2. Add tasks and start check -> strip shows progress & Stop button (>= 44pt).
      final t1 = GalleryTask(
        gid: 101,
        token: 'aaaaaaaaaa',
        url: 'https://e-hentai.org/g/101/aaaaaaaaaa/',
        title: 'Task Updatable',
        dirPath: null,
        fileCount: 20,
        completCount: 20,
        status: TaskStatus.complete.value,
        addTime: 300,
      );
      final t2 = GalleryTask(
        gid: 102,
        token: 'bbbbbbbbbb',
        url: 'https://e-hentai.org/g/102/bbbbbbbbbb/',
        title: 'Task Plain Complete',
        dirPath: null,
        fileCount: 15,
        completCount: 15,
        status: TaskStatus.complete.value,
        addTime: 200,
      );
      final t3 = GalleryTask(
        gid: 103,
        token: 'cccccccccc',
        url: 'https://e-hentai.org/g/103/cccccccccc/',
        title: 'Task Incremental Failed',
        dirPath: null,
        fileCount: 30,
        completCount: 25,
        status: TaskStatus.failed.value,
        addTime: 100,
      );
      dlCtrl.dState.galleryTaskMap[101] = t1;
      dlCtrl.dState.galleryTaskMap[102] = t2;
      dlCtrl.dState.galleryTaskMap[103] = t3;
      dlCtrl.dState.incrementalProgressMap[103] = const GalleryIncrementalProgress(
        gid: 103,
        reusedCount: 20,
        totalCount: 30,
        mode: GalleryIncrementalUpdateMode.inPlace,
      );
      viewCtrl.galleryListRevision.value++;
      // Remount DownloadGalleryView so AnimatedList initializes with all 3 tasks.
      await tester.pumpWidget(
        _wrapCupertinoApp(
          appKey: const ValueKey<String>('populated-dl-app'),
          child: const CupertinoPageScaffold(
            key: ValueKey<String>('populated-dl-view'),
            child: DownloadGalleryView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final populatedCtx = tester.element(find.byType(DownloadGalleryView));
      final checkFuture = viewCtrl.checkAllGalleryUpdates(context: populatedCtx);
      await tester.pump();

      final stopFinder = find.byKey(const ValueKey<String>('download-update-stop'));
      expect(stopFinder, findsOneWidget);
      expect(tester.getSize(stopFinder).height, greaterThanOrEqualTo(44));
      expect(find.text('正在检查更新 0 / 2'), findsOneWidget);

      await tester.tap(stopFinder);
      final stopResult = await checkFuture;
      await tester.pumpAndSettle();
      expect(stopResult?.cancelled, isTrue);

      // 3. Publish update on t1 -> filter keeps t1 (updatable) + t3 (failed incremental), hides t2.
      viewCtrl.updateInfoMap[101] = GalleryUpdateInfo(
        sourceGid: 101,
        newerVersions: const <GalleryNewerVersion>[
          GalleryNewerVersion(
            gid: '201',
            token: 'dddddddddd',
            url: 'https://e-hentai.org/g/201/dddddddddd/',
            title: 'Task Updatable V2',
            addedDate: '2026-11-22 10:00',
          ),
        ],
        checkedAt: DateTime(2026, 11, 22),
      );
      viewCtrl.hasCompletedUpdateCheck.value = true;
      viewCtrl.updateSummaryDismissed.value = false;
      await tester.pumpAndSettle();

      expect(find.text('Task Plain Complete'), findsOneWidget);
      final filterFinder = find.byKey(const ValueKey<String>('download-update-filter'));
      expect(filterFinder, findsOneWidget);
      expect(tester.getSize(filterFinder).height, greaterThanOrEqualTo(44));

      await tester.tap(filterFinder);
      await tester.pumpAndSettle();
      expect(viewCtrl.showOnlyUpdatable.value, isTrue);
      expect(find.text('Task Updatable'), findsOneWidget);
      expect(find.text('Task Incremental Failed'), findsOneWidget);
      expect(find.text('Task Plain Complete'), findsNothing);

      // 4. When filtered list becomes empty (all updates finished), auto-disable
      // filter and return to the up-to-date status strip + full list.
      viewCtrl.lastUpdateCheckCheckedCount.value = 2;
      viewCtrl.updateInfoMap.remove(101);
      dlCtrl.dState.incrementalProgressMap.remove(103);
      await tester.pumpAndSettle();
      expect(viewCtrl.showOnlyUpdatable.value, isFalse);
      expect(find.text('Task Plain Complete'), findsOneWidget);
      expect(find.text('都是最新版本 · 已检查 2 部'), findsOneWidget);
      expect(find.text('0 部有新版'), findsNothing);

      // 4b. When updatesFound == 0 but failedCount > 0, never show false all-clear.
      viewCtrl.lastUpdateCheckFailedCount.value = 1;
      await tester.pumpAndSettle();
      expect(find.text('都是最新版本 · 已检查 2 部'), findsNothing);
      expect(find.text('已检查 2 部 · 0 部有新版（1 部失败）'), findsOneWidget);
      viewCtrl.lastUpdateCheckFailedCount.value = 0;
      await tester.pumpAndSettle();

      // 5. Dismiss strip -> hides strip and restores full list.
      final dismissFinder = find.byKey(const ValueKey<String>('download-update-dismiss'));
      expect(tester.getSize(dismissFinder).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(dismissFinder).height, greaterThanOrEqualTo(44));
      await tester.tap(dismissFinder);
      await tester.pumpAndSettle();
      expect(viewCtrl.updateSummaryDismissed.value, isTrue);
      expect(viewCtrl.showOnlyUpdatable.value, isFalse);
      expect(find.text('Task Plain Complete'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('EhSheetFrame.resolvePlacement keeps sheets off unfolded iPhone Duo hinge without affecting iPad/landscape iPhone', () {
      const duoEnv = AdaptiveEnvironmentSnapshot(
        size: Size(951, 669),
        safeArea: EdgeInsets.only(right: 84),
        reservedRegions: <AdaptiveRegion>[
          AdaptiveRegion(
            frame: Rect.fromLTWH(462, 0, 27, 669),
            kind: AdaptiveRegionKind.division,
            active: true,
          ),
        ],
        systemBarEdge: 'right',
        duoVerticalBar: true,
        nativeSupported: true,
      );

      // 1. Triggered on right half (detail pane) -> left >= 497, right <= 859.
      final rightPlacement = EhSheetFrame.resolvePlacement(
        viewportSize: const Size(951, 669),
        safeArea: const EdgeInsets.only(right: 84),
        isDesktop: false,
        environment: duoEnv,
        triggerGlobalX: 680,
      );
      expect(rightPlacement.avoidsFold, isTrue);
      expect(rightPlacement.padding.left, greaterThanOrEqualTo(497));
      expect(951 - rightPlacement.padding.right, lessThanOrEqualTo(859));
      expect(rightPlacement.padding.left + rightPlacement.maxWidth, lessThanOrEqualTo(859));

      // 2. Triggered on left half -> left >= 8, right <= 454.
      final leftPlacement = EhSheetFrame.resolvePlacement(
        viewportSize: const Size(951, 669),
        safeArea: const EdgeInsets.only(right: 84),
        isDesktop: false,
        environment: duoEnv,
        triggerGlobalX: 200,
      );
      expect(leftPlacement.avoidsFold, isTrue);
      expect(leftPlacement.padding.left, greaterThanOrEqualTo(8));
      expect(951 - leftPlacement.padding.right, lessThanOrEqualTo(454));

      // 3. Zero-width division region (flat 180°) uses 27pt avoidance band (±13.5pt).
      const zeroWidthFoldEnv = AdaptiveEnvironmentSnapshot(
        size: Size(951, 669),
        safeArea: EdgeInsets.only(right: 84),
        reservedRegions: <AdaptiveRegion>[
          AdaptiveRegion(
            frame: Rect.fromLTWH(475.5, 0, 0, 669),
            kind: AdaptiveRegionKind.division,
            active: true,
          ),
        ],
        systemBarEdge: 'right',
        duoVerticalBar: true,
        nativeSupported: true,
      );
      final flatFoldRight = EhSheetFrame.resolvePlacement(
        viewportSize: const Size(951, 669),
        safeArea: const EdgeInsets.only(right: 84),
        isDesktop: false,
        environment: zeroWidthFoldEnv,
        triggerGlobalX: 680,
      );
      expect(flatFoldRight.avoidsFold, isTrue);
      expect(flatFoldRight.padding.left, greaterThanOrEqualTo(497));
      expect(951 - flatFoldRight.padding.right, lessThanOrEqualTo(859));

      // 4. Unfolded Duo inner display with duoVerticalBar=true and NO division regions.
      const duoNoRegionEnv = AdaptiveEnvironmentSnapshot(
        size: Size(951, 669),
        safeArea: EdgeInsets.only(right: 84),
        systemBarEdge: 'right',
        duoVerticalBar: true,
        nativeSupported: true,
      );
      final duoNoRegionRight = EhSheetFrame.resolvePlacement(
        viewportSize: const Size(951, 669),
        safeArea: const EdgeInsets.only(right: 84),
        isDesktop: false,
        environment: duoNoRegionEnv,
        triggerGlobalX: 680,
      );
      expect(duoNoRegionRight.avoidsFold, isTrue);
      expect(duoNoRegionRight.padding.left, greaterThanOrEqualTo(497));
      expect(951 - duoNoRegionRight.padding.right, lessThanOrEqualTo(859));
      expect(
        duoNoRegionRight.padding.left + duoNoRegionRight.maxWidth,
        lessThanOrEqualTo(859),
      );

      final duoNoRegionLeft = EhSheetFrame.resolvePlacement(
        viewportSize: const Size(951, 669),
        safeArea: const EdgeInsets.only(right: 84),
        isDesktop: false,
        environment: duoNoRegionEnv,
        triggerGlobalX: 200,
      );
      expect(duoNoRegionLeft.avoidsFold, isTrue);
      expect(duoNoRegionLeft.padding.left, greaterThanOrEqualTo(8));
      expect(951 - duoNoRegionLeft.padding.right, lessThanOrEqualTo(454));

      // 5. Non-Duo wide devices (iPad 1180x820, landscape iPhone 932x430) stay centered @ 440pt.
      final ipadPlacement = EhSheetFrame.resolvePlacement(
        viewportSize: const Size(1180, 820),
        safeArea: const EdgeInsets.only(top: 24, bottom: 20),
        isDesktop: false,
        environment: const AdaptiveEnvironmentSnapshot(
          size: Size(1180, 820),
          nativeSupported: true,
          duoVerticalBar: false,
        ),
        triggerGlobalX: 800,
      );
      expect(ipadPlacement.avoidsFold, isFalse);
      expect(ipadPlacement.alignment, Alignment.center);
      expect(ipadPlacement.maxWidth, 440);

      final landscapePhonePlacement = EhSheetFrame.resolvePlacement(
        viewportSize: const Size(932, 430),
        safeArea: const EdgeInsets.symmetric(horizontal: 59),
        isDesktop: false,
        environment: const AdaptiveEnvironmentSnapshot(
          size: Size(932, 430),
          nativeSupported: true,
          duoVerticalBar: false,
        ),
        triggerGlobalX: 700,
      );
      expect(landscapePhonePlacement.avoidsFold, isFalse);
      expect(landscapePhonePlacement.alignment, Alignment.center);
      expect(landscapePhonePlacement.maxWidth, 440);

      // 6. Stale folded triggerX is ignored after unfolding -> defaults to right detail pane.
      final postureChanged = EhSheetFrame.resolvePlacement(
        viewportSize: const Size(951, 669),
        safeArea: const EdgeInsets.only(right: 84),
        isDesktop: false,
        environment: duoNoRegionEnv,
        triggerGlobalX: 190,
        triggerViewportWidth: 466,
      );
      expect(postureChanged.avoidsFold, isTrue);
      expect(postureChanged.padding.left, greaterThanOrEqualTo(497));
      expect(
        postureChanged.padding.left + postureChanged.maxWidth,
        lessThanOrEqualTo(859),
      );
    });

    testWidgets(
      'filtered list long-press deletion removes the selected task by identity',
      (tester) async {
        Get.testMode = true;
        final settings = _FakeSettings();
        final theme = _FakeTheme();
        final dlCtrl = _FakeDownloadController();
        Get.put<EhSettingService>(settings);
        Get.put<ThemeService>(theme);
        Get.put<DownloadController>(dlCtrl);
        final viewCtrl = _TestableDownloadViewController();
        Get.put<DownloadViewController>(viewCtrl);

        // Full list order (descending addTime): [101 (plain), 102 (updatable), 103 (updatable)].
        // Under "updates only" filter, filtered index 0 is gid 102 (NOT gid 101!).
        dlCtrl.dState.galleryTaskMap[101] = GalleryTask(
          gid: 101,
          token: '1111111111',
          url: 'https://e-hentai.org/g/101/1111111111/',
          title: 'Innocent First Task',
          dirPath: null,
          fileCount: 10,
          completCount: 10,
          status: TaskStatus.complete.value,
          addTime: 300,
        );
        dlCtrl.dState.galleryTaskMap[102] = GalleryTask(
          gid: 102,
          token: '2222222222',
          url: 'https://e-hentai.org/g/102/2222222222/',
          title: 'Filtered Target One',
          dirPath: null,
          fileCount: 12,
          completCount: 12,
          status: TaskStatus.complete.value,
          addTime: 200,
        );
        dlCtrl.dState.galleryTaskMap[103] = GalleryTask(
          gid: 103,
          token: '3333333333',
          url: 'https://e-hentai.org/g/103/3333333333/',
          title: 'Filtered Target Two',
          dirPath: null,
          fileCount: 14,
          completCount: 14,
          status: TaskStatus.complete.value,
          addTime: 100,
        );
        viewCtrl.updateInfoMap[102] = GalleryUpdateInfo(
          sourceGid: 102,
          newerVersions: const <GalleryNewerVersion>[
            GalleryNewerVersion(
              gid: '202',
              token: 'aaaaaaaaaa',
              url: 'https://e-hentai.org/g/202/aaaaaaaaaa/',
              title: 'Filtered Target One V2',
            ),
          ],
          checkedAt: DateTime(2026, 11, 28),
        );
        viewCtrl.updateInfoMap[103] = GalleryUpdateInfo(
          sourceGid: 103,
          newerVersions: const <GalleryNewerVersion>[
            GalleryNewerVersion(
              gid: '203',
              token: 'bbbbbbbbbb',
              url: 'https://e-hentai.org/g/203/bbbbbbbbbb/',
              title: 'Filtered Target Two V2',
            ),
          ],
          checkedAt: DateTime(2026, 11, 28),
        );
        viewCtrl.hasCompletedUpdateCheck.value = true;
        viewCtrl.showOnlyUpdatable.value = true;

        await tester.pumpWidget(
          _wrapCupertinoApp(
            child: const CupertinoPageScaffold(child: DownloadGalleryView()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Innocent First Task'), findsNothing);
        expect(find.text('Filtered Target One'), findsOneWidget);
        expect(find.text('Filtered Target Two'), findsOneWidget);

        // 1. Long-press first filtered item (gid 102) -> Delete -> Delete task only.
        await tester.longPress(find.text('Filtered Target One'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('删除'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('仅删除任务'));
        await tester.pumpAndSettle();

        expect(dlCtrl.removedCalls, hasLength(1));
        expect(dlCtrl.removedCalls.single.gid, 102);
        expect(dlCtrl.removedCalls.single.shouldDeleteContent, isFalse);
        expect(dlCtrl.dState.galleryTaskMap.containsKey(101), isTrue);
        expect(dlCtrl.dState.galleryTaskMap.containsKey(102), isFalse);
        expect(dlCtrl.dState.galleryTaskMap.containsKey(103), isTrue);
        expect(find.text('Filtered Target One'), findsNothing);
        expect(find.text('Filtered Target Two'), findsOneWidget);

        // 2. Long-press remaining filtered item (gid 103) -> Delete -> Delete task and content.
        await tester.longPress(find.text('Filtered Target Two'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('删除'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('删除任务和下载内容'));
        await tester.pumpAndSettle();

        expect(dlCtrl.removedCalls, hasLength(2));
        expect(dlCtrl.removedCalls.last.gid, 103);
        expect(dlCtrl.removedCalls.last.shouldDeleteContent, isTrue);
        // Innocent first task (gid 101) is untouched and restored once filter auto-exits.
        expect(dlCtrl.dState.galleryTaskMap.containsKey(101), isTrue);
        expect(dlCtrl.dState.galleryTaskMap.containsKey(103), isFalse);
        expect(viewCtrl.showOnlyUpdatable.value, isFalse);
        expect(find.text('Innocent First Task'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'zero-reuse new-task update stays visible in updatable filter while another update remains',
      (tester) async {
        Get.testMode = true;
        final settings = _FakeSettings();
        final theme = _FakeTheme();
        final dlCtrl = _FakeDownloadController();
        Get.put<EhSettingService>(settings);
        Get.put<ThemeService>(theme);
        Get.put<DownloadController>(dlCtrl);
        final viewCtrl = _TestableDownloadViewController();
        Get.put<DownloadViewController>(viewCtrl);

        final plainTask = GalleryTask(
          gid: 100,
          token: '0000000000',
          url: 'https://e-hentai.org/g/100/0000000000/',
          title: 'Plain Completed Gallery',
          dirPath: null,
          fileCount: 10,
          completCount: 10,
          status: TaskStatus.complete.value,
          addTime: 300,
        );
        final sourceTask = GalleryTask(
          gid: 101,
          token: '1111111111',
          url: 'https://e-hentai.org/g/101/1111111111/',
          title: 'Source Gallery One',
          dirPath: null,
          fileCount: 18,
          completCount: 18,
          status: TaskStatus.complete.value,
          addTime: 200,
        );
        final otherUpdatableTask = GalleryTask(
          gid: 102,
          token: '2222222222',
          url: 'https://e-hentai.org/g/102/2222222222/',
          title: 'Other Updatable Gallery',
          dirPath: null,
          fileCount: 20,
          completCount: 20,
          status: TaskStatus.complete.value,
          addTime: 100,
        );
        dlCtrl.dState.galleryTaskMap[100] = plainTask;
        dlCtrl.dState.galleryTaskMap[101] = sourceTask;
        dlCtrl.dState.galleryTaskMap[102] = otherUpdatableTask;

        const targetVersion = GalleryNewerVersion(
          gid: '201',
          token: 'aaaaaaaaaa',
          url: 'https://e-hentai.org/g/201/aaaaaaaaaa/',
          title: 'Zero Reuse Target V2',
        );
        viewCtrl.updateInfoMap[101] = GalleryUpdateInfo(
          sourceGid: 101,
          newerVersions: const <GalleryNewerVersion>[targetVersion],
          checkedAt: DateTime(2026, 11, 28),
        );
        viewCtrl.updateInfoMap[102] = GalleryUpdateInfo(
          sourceGid: 102,
          newerVersions: const <GalleryNewerVersion>[
            GalleryNewerVersion(
              gid: '202',
              token: 'bbbbbbbbbb',
              url: 'https://e-hentai.org/g/202/bbbbbbbbbb/',
              title: 'Other Updatable V2',
            ),
          ],
          checkedAt: DateTime(2026, 11, 28),
        );
        viewCtrl.hasCompletedUpdateCheck.value = true;
        viewCtrl.showOnlyUpdatable.value = true;

        // Simulate zero-reuse / SAF fallback: new task is created WITHOUT an
        // incrementalProgressMap entry, while source gid 101 gets pruned.
        dlCtrl.onExecuteIncrementalUpdate = (plan, mode) async {
          final created = GalleryTask(
            gid: 201,
            token: 'aaaaaaaaaa',
            url: 'https://e-hentai.org/g/201/aaaaaaaaaa/',
            title: 'Zero Reuse Target V2',
            dirPath: null,
            fileCount: 18,
            completCount: 0,
            status: TaskStatus.running.value,
            addTime: 400,
          );
          dlCtrl.dState.galleryTaskMap[201] = created;
          dlCtrl.dState.incrementalProgressMap.remove(201);
          dlCtrl.dState.updateCreatedTaskGids.add(201);
          return GalleryIncrementalExecutionResult(
            task: created,
            reusedCount: 0,
            downloadCount: 18,
            completedLocally: false,
          );
        };

        await tester.pumpWidget(
          _wrapCupertinoApp(
            child: const CupertinoPageScaffold(child: DownloadGalleryView()),
          ),
        );
        await tester.pumpAndSettle();

        final plan = GalleryIncrementalPlan(
          oldTask: sourceTask,
          targetVersion: targetVersion,
          targetProvider: const GalleryProvider(
            gid: '201',
            token: 'aaaaaaaaaa',
            englishTitle: 'Zero Reuse Target V2',
            filecount: '18',
          ),
          targetImages: const <GalleryImage>[],
          reusedPages: const <GalleryPageReuse>[],
          pagesToDownload: const <GalleryImage>[],
          addedCount: 0,
          replacedCount: 18,
          totalNewPages: 18,
          firstPageCount: 18,
          canReuseLocalFiles: false,
        );
        await viewCtrl.executeIncrementalUpdate(
          plan,
          mode: GalleryIncrementalUpdateMode.newTask,
        );
        await tester.pumpAndSettle();

        // Source badge was pruned, another updatable task keeps filter active,
        // and the zero-reuse active target task remains visible in the list.
        expect(viewCtrl.updateInfoMap.containsKey(101), isFalse);
        expect(viewCtrl.showOnlyUpdatable.value, isTrue);
        expect(dlCtrl.dState.incrementalProgressMap.containsKey(201), isFalse);
        expect(find.text('Zero Reuse Target V2'), findsOneWidget);
        expect(find.text('Other Updatable Gallery'), findsOneWidget);
        expect(find.text('Plain Completed Gallery'), findsNothing);

        // Once the zero-reuse task completes, it exits the filtered view.
        dlCtrl.dState.galleryTaskMap[201] = dlCtrl.dState.galleryTaskMap[201]!
            .copyWith(completCount: 18, status: TaskStatus.complete.value);
        dlCtrl.dState.updateCreatedTaskGids.remove(201);
        await tester.pumpAndSettle();

        expect(find.text('Zero Reuse Target V2'), findsNothing);
        expect(find.text('Other Updatable Gallery'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'EhSheetFrame avoids horizontal folds (tabletop/portrait) and constrains sheet height',
      (tester) async {
        Get.testMode = true;
        Get.put<EhSettingService>(_FakeSettings());
        Get.put<ThemeService>(_FakeTheme());

        const tabletopEnv = AdaptiveEnvironmentSnapshot(
          size: Size(700, 960),
          safeArea: EdgeInsets.only(top: 24, bottom: 20),
          reservedRegions: <AdaptiveRegion>[
            AdaptiveRegion(
              frame: Rect.fromLTWH(0, 470, 700, 20),
              kind: AdaptiveRegionKind.division,
              active: true,
            ),
          ],
          nativeSupported: true,
        );

        // 1. Default horizontal fold places sheet in lower pane and bounds maxHeight.
        // Fold center = 480, min avoid = 27 -> avoidTop = 466.5, avoidBottom = 493.5.
        final lowerPlacement = EhSheetFrame.resolvePlacement(
          viewportSize: const Size(700, 960),
          safeArea: const EdgeInsets.only(top: 24, bottom: 20),
          isDesktop: false,
          environment: tabletopEnv,
        );
        expect(lowerPlacement.avoidsFold, isTrue);
        expect(lowerPlacement.padding.top, closeTo(493.5 + 8, 0.01));
        expect(lowerPlacement.padding.bottom, closeTo(20 + 8, 0.01));
        expect(lowerPlacement.maxHeight, isNotNull);
        expect(lowerPlacement.maxHeight!, closeTo(940 - 493.5 - 16, 0.01));

        // 2. Thin active horizontal fold (1pt) still expands to the 27pt avoidance band.
        const thinHorizontalEnv = AdaptiveEnvironmentSnapshot(
          size: Size(700, 960),
          safeArea: EdgeInsets.only(top: 24, bottom: 20),
          reservedRegions: <AdaptiveRegion>[
            AdaptiveRegion(
              frame: Rect.fromLTWH(0, 479.5, 700, 1),
              kind: AdaptiveRegionKind.division,
              active: true,
            ),
          ],
          nativeSupported: true,
        );
        final thinLower = EhSheetFrame.resolvePlacement(
          viewportSize: const Size(700, 960),
          safeArea: const EdgeInsets.only(top: 24, bottom: 20),
          isDesktop: false,
          environment: thinHorizontalEnv,
        );
        expect(thinLower.avoidsFold, isTrue);
        expect(thinLower.padding.top, closeTo(493.5 + 8, 0.01));

        // 3. Explicit upper-pane trigger places sheet strictly above the fold.
        final upperPlacement = EhSheetFrame.resolvePlacement(
          viewportSize: const Size(700, 960),
          safeArea: const EdgeInsets.only(top: 24, bottom: 20),
          isDesktop: false,
          environment: tabletopEnv,
          triggerGlobalY: 200,
        );
        expect(upperPlacement.avoidsFold, isTrue);
        expect(960 - upperPlacement.padding.bottom, lessThanOrEqualTo(466.5 - 8));
        expect(upperPlacement.maxHeight!, closeTo(466.5 - 24 - 16, 0.01));

        // 4. Widget layout check: tall sheet content stays strictly below the fold.
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(700, 960);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _wrapCupertinoApp(
            child: const MediaQuery(
              data: MediaQueryData(
                size: Size(700, 960),
                padding: EdgeInsets.only(top: 24, bottom: 20),
              ),
              child: AdaptiveEnvironmentScope(
                snapshot: tabletopEnv,
                child: EhSheetFrame(
                  child: SingleChildScrollView(
                    child: SizedBox(height: 800, width: 400),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final sheetRect = tester.getRect(find.byType(EhSheetSurface));
        expect(sheetRect.top, greaterThanOrEqualTo(493.5));
        expect(sheetRect.bottom, lessThanOrEqualTo(960 - 20));
        expect(sheetRect.height, lessThanOrEqualTo(940 - 493.5 - 16 + 0.5));
        expect(tester.takeException(), isNull);
      },
    );
  });
}
