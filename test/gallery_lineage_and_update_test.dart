import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
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
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/network/app_dio/exception.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_controller.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_state.dart';
import 'package:eros_fe/pages/gallery/view/gallery_incremental_update_sheet.dart';
import 'package:eros_fe/pages/gallery/view/gallery_info_page.dart';
import 'package:eros_fe/pages/gallery/view/sliver/gallery_hero.dart';
import 'package:eros_fe/pages/item/download_gallery_item.dart';
import 'package:eros_fe/pages/tab/controller/download_view_controller.dart';
import 'package:eros_fe/store/db/entity/gallery_image_task.dart';
import 'package:eros_fe/store/db/entity/gallery_task.dart';
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

  @override
  bool filesUnavailable(int gid) => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrapCupertinoApp({
  required Widget child,
  Locale locale = const Locale('zh', 'CN'),
  Brightness brightness = Brightness.dark,
}) {
  return oktoast.OKToast(
    child: GetCupertinoApp(
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
                  isDownloadedComplete: false,
                  onTap: () => tapped = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('有 2 个更新版本'), findsOneWidget);
      expect(find.text('含父画廊'), findsOneWidget);
      final whisperHeight = tester.getSize(find.byType(GalleryLineageWhisper)).height;
      expect(whisperHeight, lessThanOrEqualTo(44));

      await tester.tap(find.byType(GalleryLineageWhisper));
      expect(tapped, isTrue);
    });

    testWidgets('GalleryInfoPage renders clickable Parent, Newer Versions and incremental entry', (tester) async {
      final dlCtrl = Get.put<DownloadController>(_FakeDownloadController());
      dlCtrl.dState.galleryTaskMap[3104821] = GalleryTask(
        gid: 3104821,
        token: '9a4f2c1b8e',
        title: 'Yoimachi',
        dirPath: '/tmp/yoimachi',
        fileCount: 48,
        completCount: 48,
        status: TaskStatus.complete.value,
      );

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
      expect(find.text('#2841029'), findsOneWidget);
      expect(find.text('Yoimachi [Expanded]'), findsOneWidget);
      expect(find.text('最新'), findsOneWidget);
      expect(find.text('增量更新已下载画廊'), findsOneWidget);

      await tester.tap(find.text('#2841029'));
      await tester.tap(find.text('Yoimachi [Expanded]'));
      await tester.tap(find.text('增量更新已下载画廊'));

      expect(openedUrls, <String>[
        'https://e-hentai.org/g/2841029/fedcba9876/',
        'https://e-hentai.org/g/3298510/1234567890/',
      ]);
      expect(incrementalOpened, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('GalleryIncrementalUpdateSheet displays diff and executes selected mode', (tester) async {
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
      final fakePlan = GalleryIncrementalPlan(
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

      GalleryIncrementalUpdateMode? executedMode;

      await tester.pumpWidget(
        _wrapCupertinoApp(
          child: CupertinoPageScaffold(
            child: GalleryIncrementalUpdateSheet(
              oldTask: oldTask,
              newerVersions: const <GalleryNewerVersion>[targetVersion],
              analyzePlan: ({required oldTask, required targetVersion, cancelToken}) async =>
                  fakePlan,
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
      await tester.pumpAndSettle();

      expect(find.text('46'), findsOneWidget);
      expect(find.text('+8'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // Switch to newTask mode and tap confirm.
      await tester.tap(find.text('作为新任务下载（保留旧版）'));
      await tester.pumpAndSettle();
      expect(find.text('新建任务并复用 · 拉取 10 页'), findsOneWidget);

      await tester.tap(find.text('新建任务并复用 · 拉取 10 页'));
      await tester.pumpAndSettle();
      oktoast.dismissAllToast();
      await tester.pump(const Duration(seconds: 4));
      expect(executedMode, GalleryIncrementalUpdateMode.newTask);
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

    testWidgets('GalleryIncrementalUpdateSheet forces newTask for SAF paths and cycles versions', (tester) async {
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
          title: 'SAF Gallery V3',
          addedDate: '2026-04-01 00:00',
        ),
        GalleryNewerVersion(
          gid: '9002',
          token: '2222222222',
          url: 'https://e-hentai.org/g/9002/2222222222/',
          title: 'SAF Gallery V2',
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

      // Default analyzes newest version (9003), SAF shows honest full-download cost.
      expect(analyzedGids, <String>['9003']);
      expect(find.text('新建任务完整下载 · 拉取 24 页'), findsOneWidget);
      expect(find.text('0/24'), findsOneWidget);

      // Cycle version to 9002.
      await tester.tap(find.text('#9003 (1/2) ▾'));
      await tester.pumpAndSettle();
      expect(analyzedGids, <String>['9003', '9002']);

      // Tapping in-place radio should remain on newTask for SAF.
      await tester.tap(find.text('原位升级并保留阅读进度'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('新建任务完整下载 · 拉取 24 页'));
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
          title: 'V3',
          addedDate: '2026-04-01 00:00',
        ),
        GalleryNewerVersion(
          gid: '7002',
          token: '2222222222',
          url: 'https://e-hentai.org/g/7002/2222222222/',
          title: 'V2',
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

      // Switch immediately while first request is still pending.
      await tester.tap(find.text('#7003 (1/2) ▾'));
      await tester.pumpAndSettle();
      expect(find.text('原位增量更新 · 拉取 12 页'), findsOneWidget);

      // Now first request fails late with CancelException -> must NOT clobber V2 plan!
      firstCompleter.completeError(CancelException('stale cancel'));
      await tester.pumpAndSettle();

      expect(find.text('原位增量更新 · 拉取 12 页'), findsOneWidget);
      expect(find.text('差异分析失败'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('GalleryInfoPage Russian header wraps cleanly on 320px at 1.6x text scale', (tester) async {
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
    });

    testWidgets('DownloadGalleryItem displays update badge and incremental dual-bar cleanly', (tester) async {
      final view = Get.put<DownloadViewController>(_FakeDownloadViewController());
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
      view.galleryTaskMap[100] = completeTask;
      view.galleryTaskMap[200] = updatingTask;

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
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('有新版'), findsOneWidget);
      expect(find.text('有新版 ›'), findsOneWidget);
      expect(find.text('增量中'), findsOneWidget);
      expect(find.text('复用 46 页'), findsOneWidget);

      await tester.tap(find.text('有新版 ›'));
      expect(tappedUpdate, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
