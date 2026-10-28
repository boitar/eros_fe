import 'package:archive_async/archive_async.dart';
import 'package:collection/collection.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/network/api.dart';
import 'package:eros_fe/network/request.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_controller.dart';
import 'package:eros_fe/pages/gallery/gallery_repository.dart';
import 'package:eros_fe/pages/image_view/common.dart';
import 'package:eros_fe/pages/image_view/view/view_page.dart';
import 'package:eros_fe/pages/tab/controller/search_page_controller.dart';
import 'package:eros_fe/pages/tab/view/list/tab_base.dart';
import 'package:eros_fe/route/first_observer.dart';
import 'package:eros_fe/route/second_observer.dart';
import 'package:get/get.dart';

import '../pages/image_view/controller/view_controller.dart';

class NavigatorUtil {
  // 带搜索条件打开搜索
  static Future<void> goSearchPageWithParam({
    required String simpleSearch,
    bool replace = false,
    AdvanceSearch? advanceSearch,
  }) async {
    String _search = simpleSearch;
    if (simpleSearch.contains(':') &&
        EHConst.translateTagType.keys
            .contains(simpleSearch.split(':')[0].trim())) {
      final List<String> searArr = simpleSearch.split(':');
      String _end = '';
      if (searArr[0] != 'uploader') {
        _end = '\$';
      }
      _search = '${searArr[0]}:"${searArr[1]}$_end"';
    }

    final tags = Get.find<ControllerTagService>();
    final tag = tags.pushSearchPageCtrl(searchText: _search);
    final repository =
        SearchRepository(searchText: _search, advanceSearch: advanceSearch);

    // Get.put(
    //   SearchPageController(),
    //   tag: searchPageCtrlTag,
    //   // permanent: true,
    // );

    Get.lazyPut(
      () => SearchPageController(repository: repository, controllerTag: tag),
      tag: tag,
    );

    final ownership = ControllerTagSnapshot(
        galleryTag: tags.snapshot.galleryTag, searchTag: tag);
    if (replace) {
      await Get.offNamed(
        EHRoutes.search,
        id: primaryNavigatorId,
        preventDuplicates: false,
        arguments: ownership,
      );
    } else {
      await Get.toNamed(
        EHRoutes.search,
        id: primaryNavigatorId,
        preventDuplicates: false,
        arguments: ownership,
      );
    }

    tags.popSearchPageCtrl(tag: tag);
  }

  /// 打开搜索页面 指定搜索类型
  static Future<void> goSearchPage({
    SearchType searchType = SearchType.normal,
    bool fromTabItem = true,
  }) async {
    logger.d('fromTabItem $fromTabItem');
    final tags = Get.find<ControllerTagService>();
    final tag = tags.pushSearchPageCtrl();
    final repository = SearchRepository(searchType: searchType);

    // Get.put(
    //   SearchPageController(),
    //   tag: searchPageCtrlTag,
    //   // permanent: true,
    // );

    Get.lazyPut(
      () => SearchPageController(repository: repository, controllerTag: tag),
      tag: tag,
    );

    await Get.toNamed(
      EHRoutes.search,
      id: primaryNavigatorId,
      preventDuplicates: false,
      arguments: ControllerTagSnapshot(
          galleryTag: tags.snapshot.galleryTag, searchTag: tag),
    );

    tags.popSearchPageCtrl(tag: tag);
  }

  /// 转到画廊页面
  static Future<void> goGalleryPage({
    String? url,
    dynamic tabTag,
    GalleryProvider? galleryProvider,
    bool replace = false,
    bool forceReplace = false,
  }) async {
    final tags = Get.find<ControllerTagService>();
    final owner = tags.currentOwner;
    final navigatorId = detailNavigatorId;
    final topMainRoute =
        MainNavigatorObserver().history.lastOrNull?.settings.name;
    String? gid;
    GalleryRepository? repository;

    if (url != null && url.isNotEmpty) {
      final galleryLink =
          RegExp(r'https?://e[-x]hentai.org/g/([0-9]+)/[0-9a-z]+/?');
      final imageLink =
          RegExp(r'https?://e[-x]hentai.org/s/[0-9a-z]+/\d+-\d+/?');
      if (galleryLink.hasMatch(url)) {
        gid = galleryLink.firstMatch(url)?.group(1);
        repository = GalleryRepository(url: url.linkRedirect);
      } else if (imageLink.hasMatch(url)) {
        final image = await fetchImageInfoByApi(url.linkRedirect);
        if (image == null) return;
        gid = image.gid;
        repository = GalleryRepository(
          url: '${Api.getBaseUrl()}/g/${image.gid}/${image.token}',
          jumpSer: image.ser,
        );
      }
    } else {
      gid = galleryProvider?.gid;
      repository = GalleryRepository(item: galleryProvider, tabTag: tabTag);
    }
    if (gid == null || repository == null) return;

    final replaceRoot =
        forceReplace || (replace && topMainRoute == EHRoutes.root);
    final observer = replaceRoot || navigatorId == null
        ? MainNavigatorObserver()
        : SecondNavigatorObserver.forId(navigatorId);
    final topRoute = observer.history.lastOrNull?.settings.name;
    final currentTag = replaceRoot || navigatorId == null
        ? tags.snapshot.galleryTag
        : tags.snapshotFor(owner).galleryTag;
    if (topRoute == EHRoutes.galleryPage &&
        Get.isRegistered<GalleryPageController>(tag: currentTag) &&
        Get.find<GalleryPageController>(tag: currentTag).gState.gid == gid) {
      return;
    }

    final tag = tags.pushPageCtrl(gid: gid, owner: owner, unique: true);
    final ownership = ControllerTagSnapshot(
        galleryTag: tag, searchTag: tags.snapshot.searchTag);
    Get.lazyPut(() => repository!, tag: tag, fenix: true);
    try {
      if (replaceRoot) {
        await Get.offNamed(EHRoutes.galleryPage,
            preventDuplicates: false, arguments: ownership);
      } else if (isLayoutLarge &&
          url == null &&
          topRoute != null &&
          topRoute != EHRoutes.empty) {
        await Get.offNamed(
          EHRoutes.galleryPage,
          id: navigatorId,
          preventDuplicates: false,
          arguments: ownership,
        );
      } else {
        await Get.toNamed(
          EHRoutes.galleryPage,
          id: navigatorId,
          preventDuplicates: false,
          arguments: ownership,
        );
      }
    } finally {
      tags.popPageCtrl(tag: tag);
    }
  }

  // 转到大图浏览
  static Future<void> goGalleryViewPage(int index, String gid,
      {String? galleryTag}) async {
    // 命名路由方式
    await Get.toNamed(EHRoutes.galleryViewExt,
        arguments: ViewRepository(
      index: index,
      loadType: LoadFrom.gallery,
      gid: gid,
      galleryControllerTag: galleryTag ?? _liveGalleryTag(gid),
        ));
  }

  /// The global tag can point at a gallery that was already closed; its fenix
  /// factory would then hand the reader a fresh, empty controller (1/0).
  static String _liveGalleryTag(String gid) {
    bool live(String tag) =>
        Get.isRegistered<GalleryPageController>(tag: tag) &&
        !Get.isPrepared<GalleryPageController>(tag: tag) &&
        Get.find<GalleryPageController>(tag: tag).gState.gid == gid;
    final current = pageCtrlTag;
    if (gid.isEmpty || live(current)) {
      return current;
    }
    return Get.find<ControllerTagService>()
            .galleryTagsFor(gid)
            .lastWhereOrNull(live) ??
        current;
  }

  // 打开已下载任务阅读
  static Future<void> goGalleryViewPageFile(
      int index, List<String> pics, String gid) async {
    // 命名路由方式
    await Get.toNamed(EHRoutes.galleryViewExt,
        arguments: ViewRepository(
      index: index,
      files: pics,
      loadType: LoadFrom.download,
      gid: gid,
        ));
  }

  // 打开归档压缩包阅读
  static Future<void> goGalleryViewPageArchiver(
      int index, AsyncArchive asyncArchive, String gid) async {
    // 命名路由方式
    await Get.toNamed(EHRoutes.galleryViewExt,
        arguments: ViewRepository(
      index: index,
      asyncArchives: asyncArchive.files,
      loadType: LoadFrom.archiver,
      gid: gid,
        ));
  }

  static Future<void> goItemWidthSettingPage() async {
    final topFirstRoute =
        FirstNavigatorObserver().history.lastOrNull?.settings.name;

    if (topFirstRoute == EHRoutes.itemWidthSetting) {
      return;
    }

    Get.toNamed(
      EHRoutes.itemWidthSetting,
      id: primaryNavigatorId,
    );
  }
}
