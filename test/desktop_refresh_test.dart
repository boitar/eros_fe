import 'dart:async';

import 'package:dio/dio.dart';
import 'package:eros_fe/common/controller/tag_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/models/gallery_list.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/pages/tab/comm.dart';
import 'package:eros_fe/pages/tab/controller/enum.dart';
import 'package:eros_fe/pages/tab/controller/tabview_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Settings extends EhSettingService {
  @override
  // Tests use isolated defaults instead of loading a persisted profile.
  // ignore: must_call_super
  void onInit() {}
}

class _Tags extends TagController {
  @override
  void onReady() {}
}

class _List extends TabViewController {
  String filter = 'a';
  final requests = <Completer<GalleryList?>>[];
  final pages = <Completer<GalleryList?>>[];
  final errors = <String>[];
  @override
  Object get requestIdentity => filter;
  @override
  Future<GalleryList?> fetchData({bool refresh = false}) {
    cancelToken = CancelToken();
    final result = Completer<GalleryList?>();
    requests.add(result);
    return result.future;
  }

  @override
  Future<GalleryList?> fetchMoreData() {
    cancelToken = CancelToken();
    final result = Completer<GalleryList?>();
    pages.add(result);
    return result.future;
  }

  @override
  void reportRefreshError(String message) => errors.add(message);
}

GalleryList result(String id, {String next = 'next'}) => GalleryList(
  gallerys: [GalleryProvider(gid: id)],
  nextGid: next,
);

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put<LocaleService>(LocaleService());
    Get.put<EhSettingService>(_Settings());
    Get.put<TagController>(_Tags());
  });
  tearDown(Get.reset);
  _List list() => _List()
    ..change([GalleryProvider(gid: 'old')], status: RxStatus.success())
    ..nextGid = 'old-next'
    ..prevGid = 'old-prev'
    ..canLoadMore = true;

  testWidgets('refresh deduplicates and only a success scrolls to start', (
    tester,
  ) async {
    final c = list();
    var scrolls = 0;
    c.tabScrollController = EhTabController()
      ..scrollToTopCall = () => scrolls++;
    final first = c.refreshFromToolbar();
    final shared = c.reloadData();
    expect(c.requests, hasLength(1));
    expect(c.isReloading, isTrue);
    expect(c.state!.single.gid, 'old');
    c.requests.single.complete(result('new'));
    await Future.wait([first, shared]);
    expect(c.isReloading, isFalse);
    expect(c.state!.single.gid, 'new');
    expect(scrolls, 1);
    c.onClose();
  });

  testWidgets(
    'failed refresh retains data cursors and allows retrying cancelled pagination',
    (tester) async {
      final c = list();
      var scrolls = 0;
      c.tabScrollController = EhTabController()
        ..scrollToTopCall = () => scrolls++;
      final oldList = c.state;
      final page = c.loadDataMore();
      await tester.pump(const Duration(milliseconds: 100));
      final oldToken = c.cancelToken!;
      final reload = c.refreshFromToolbar();
      expect(oldToken.isCancelled, isTrue);
      c.requests.single.completeError(StateError('offline'));
      await reload;
      c.pages.first.complete(result('stale', next: 'stale-next'));
      await page;
      expect(identical(c.state, oldList), isTrue);
      expect(c.nextGid, 'old-next');
      expect(c.prevGid, 'old-prev');
      expect(c.pageState, PageState.None);
      expect(scrolls, 0);
      final retry = c.loadDataMore();
      await tester.pump(const Duration(milliseconds: 100));
      expect(c.pages, hasLength(2));
      c.pages.last.complete(result('appended'));
      await retry;
      expect(c.state!.map((e) => e.gid), ['old', 'appended']);
      c.onClose();
    },
  );

  testWidgets('filter replacement and disposal discard late results', (
    tester,
  ) async {
    final c = list();
    final old = c.reloadData();
    c.filter = 'b';
    final replacement = c.reloadData();
    c.requests.last.complete(result('b'));
    await replacement;
    c.requests.first.complete(result('a'));
    await old;
    expect(c.state!.single.gid, 'b');
    final last = c.reloadData();
    c.onClose();
    c.requests.last.complete(result('closed'));
    await last;
    expect(c.state!.single.gid, 'b');
  });

  testWidgets('inactive group refresh never scrolls the selected group', (
    tester,
  ) async {
    final c = list();
    var selected = true;
    var scrolls = 0;
    c.tabScrollController = EhTabController()
      ..scrollToTopCall = () => scrolls++;
    final reload = c.refreshFromToolbar(isCurrent: () => selected);
    selected = false;
    c.requests.single.complete(result('new'));
    await reload;
    expect(c.state!.single.gid, 'new');
    expect(scrolls, 0);
    c.onClose();
  });

  testWidgets('first load cannot overwrite a newer refresh', (tester) async {
    final c = list();
    final initial = c.firstLoad();
    await tester.pump(const Duration(milliseconds: 200));
    final refresh = c.reloadData();
    c.requests.last.complete(result('new'));
    await refresh;
    c.requests.first.complete(result('cache'));
    await initial;
    expect(c.state!.single.gid, 'new');
    c.onClose();
  });
}
