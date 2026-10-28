import 'package:eros_fe/common/controller/gallerycache_controller.dart';
import 'package:eros_fe/common/controller/mysql_controller.dart';
import 'package:eros_fe/common/controller/quicksearch_controller.dart';
import 'package:eros_fe/common/controller/webdav_controller.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  late _Webdav webdav;
  late _Mysql mysql;

  setUp(() {
    Get.testMode = true;
    webdav = Get.put<WebdavController>(_Webdav()) as _Webdav;
    mysql = Get.put<MysqlController>(_Mysql()) as _Mysql;
  });
  tearDown(Get.reset);

  test('reading progress without remote providers is an empty result',
      () async {
    final cache = GalleryCacheController();
    expect(await cache.getRemote('42'), isNull);
    expect(webdav.readRequests, 0);
    expect(mysql.readRequests, 0);
  });

  test('enabled providers without the gallery are also an empty result',
      () async {
    webdav.syncReadProgress = true;
    mysql.syncReadProgress = true;
    expect(await GalleryCacheController().getRemote('42'), isNull);
    expect(webdav.readRequests, 1);
    expect(mysql.readRequests, 1);
  });

  test('reading progress still selects the newest available timestamp',
      () async {
    webdav.syncReadProgress = true;
    webdav.remote = const GalleryCache(gid: '42', lastIndex: 3, time: 10);
    mysql.syncReadProgress = true;
    mysql.remote = const GalleryCache(gid: '42', lastIndex: 5, time: 20);
    final cache = GalleryCacheController();
    expect((await cache.getRemote('42'))?.lastIndex, 5);
    webdav.remote = const GalleryCache(gid: '42', lastIndex: 7, time: 30);
    expect((await cache.getRemote('42'))?.lastIndex, 7);
  });

  test('an unavailable optional progress provider does not fail browsing',
      () async {
    mysql.syncReadProgress = true;
    mysql.fail = true;
    expect(await GalleryCacheController().getRemote('42'), isNull);
  });

  test('disabled quick-search sync does not contact WebDAV', () async {
    webdav.url = 'https://example.invalid';
    await _QuickSearch().syncQuickSearch();
    expect(webdav.quickRequests, 0);
    expect(webdav.uploads, 0);
  });

  test('an empty WebDAV address does not start quick-search sync', () async {
    webdav.syncQuickSearch = true;
    await _QuickSearch().syncQuickSearch();
    expect(webdav.quickRequests, 0);
  });

  test('enabled configured quick-search sync retains its upload behavior',
      () async {
    webdav.syncQuickSearch = true;
    webdav.url = 'https://example.invalid';
    await _QuickSearch().syncQuickSearch();
    expect(webdav.quickRequests, 1);
    expect(webdav.uploads, 1);
  });

  test('background quick-search failure completes without an uncaught future',
      () async {
    webdav.syncQuickSearch = true;
    webdav.url = 'https://example.invalid';
    webdav.fail = true;
    await _QuickSearch().syncQuickSearch();
    expect(webdav.quickRequests, 1);
    expect(webdav.uploads, 0);
  });
}

class _Webdav extends GetxController implements WebdavController {
  @override
  bool syncReadProgress = false;
  @override
  bool syncQuickSearch = false;
  String url = '';
  GalleryCache? remote;
  int readRequests = 0;
  int quickRequests = 0;
  int uploads = 0;
  bool fail = false;
  @override
  WebdavProfile get webdavProfile => WebdavProfile(url: url);
  @override
  Future<List<String>> getRemotReadList() async {
    readRequests++;
    return remote == null ? [] : ['42'];
  }

  @override
  Future<GalleryCache?> downloadRead(String gid) async => remote;
  @override
  Future<List<int>> getQuickList() async {
    quickRequests++;
    if (fail) throw StateError('Offline optional provider');
    return [];
  }

  @override
  Future<void> uploadQuickSearch(List<String> texts, int time) async {
    uploads++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Mysql extends GetxController implements MysqlController {
  @override
  bool syncReadProgress = false;
  GalleryCache? remote;
  int readRequests = 0;
  bool fail = false;
  @override
  Future<GalleryCache?> downloadRead(String gid) async {
    readRequests++;
    if (fail) throw StateError('Offline optional provider');
    return remote;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _QuickSearch extends QuickSearchController {
  @override
  void onInit() {}
}
