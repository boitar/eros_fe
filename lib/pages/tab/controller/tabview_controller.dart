import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:eros_fe/adaptive/gallery_anchor.dart';
import 'package:eros_fe/common/controller/tag_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/network/app_dio/pdio.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/pages/tab/fetch_list.dart';
import 'package:eros_fe/widget/jump_sheets.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../comm.dart';
import 'enum.dart';

abstract class TabViewController extends GetxController {
  final galleryAnchor = GalleryAnchorController();

  // 当前页码
  // final _curPage = (-1).obs;
  // int get curPage => _curPage.value;
  // set curPage(int val) => _curPage.value = val;

  final TagController tagController = Get.find();

  String get listViewId => 'listViewId';

  // 最大页码
  int? maxPage = 1;

  final RxInt _nextPage = (-1).obs;
  int get nextPage => _nextPage.value;
  set nextPage(int? val) => _nextPage.value = val ?? -1;

  final RxInt _prevPage = (-1).obs;
  int get prevPage => _prevPage.value;
  set prevPage(int? val) => _prevPage.value = val ?? -1;

  // 下一页
  final RxString _nextGid = ''.obs;
  String get nextGid => _nextGid.value;
  set nextGid(String? value) => _nextGid.value = value ?? '';

  // 上一页
  final RxString _prevGid = ''.obs;
  String get prevGid => _prevGid.value;
  set prevGid(String? value) => _prevGid.value = value ?? '';

  String get next => '${nextPage > 0 ? nextPage : nextGid}';

  String get prev => '${prevPage > -1 ? prevPage : prevGid}';

  final _afterJump = false.obs;
  bool get afterJump => _afterJump.value;
  set afterJump(bool value) => _afterJump.value = value;

  final TextEditingController pageTextEditController = TextEditingController();

  final TextEditingController gidTextEditController = TextEditingController();

  final TextEditingController jumpOrSeekTextEditController =
      TextEditingController();
  final gidNode = FocusNode();

  String? heroTag;
  EhTabController? tabScrollController;

  CancelToken? cancelToken = CancelToken();

  bool canLoadMore = false;

  bool get keepPosition => prevGid.isNotEmpty || prevPage > -1;

  final RxBool _isBackgroundRefresh = false.obs;
  bool get isBackgroundRefresh => _isBackgroundRefresh.value;
  set isBackgroundRefresh(bool val) => _isBackgroundRefresh.value = val;

  final GlobalKey<SliverAnimatedListState> sliverAnimatedListKey =
      GlobalKey<SliverAnimatedListState>();

  Key galleryGroupKey = UniqueKey();

  List<GalleryProvider>? state = [];
  RxStatus status = RxStatus.loading();

  void change(List<GalleryProvider>? newState, {RxStatus? status}) {
    state = newState;
    if (status != null) {
      this.status = status;
    }
    update([listViewId]);
  }

  final Rx<PageState> _pageState = PageState.None.obs;
  PageState get pageState => _pageState.value;
  set pageState(PageState val) => _pageState.value = val;

  bool get canLoadData =>
      pageState != PageState.Loading &&
      pageState != PageState.LoadingMore &&
      pageState != PageState.LoadingPrev;

  final EhSettingService ehSettingService = Get.find();

  @override
  void onReady() {
    super.onReady();
    logger.t('onReady');
    firstLoad();
  }

  // 请求一批画廊数据
  Future<GalleryList?> fetchData({bool refresh = false}) async {
    // logger.d('super fetchData ....');
    cancelToken = CancelToken();
    return null;
  }

  Future<GalleryList?> fetchMoreData() async {
    cancelToken = CancelToken();
    return null;
  }

  Future<GalleryList?> fetchPrevData() async {
    cancelToken = CancelToken();
    return null;
  }

  Future<GalleryList?> fetchDataFrom({
    String? gid,
    PageType? pageType,
    String? jump,
    String? seek,
    int? page,
  }) async {
    cancelToken = CancelToken();
    return null;
  }

  void setResultPage(GalleryList result) {
    nextGid = result.nextGid;
    prevGid = result.prevGid;
    nextPage = result.nextPage;
    prevPage = result.prevPage;
    maxPage = result.maxPage;
  }

  void resetResultPage() {
    nextGid = null;
    prevGid = null;
    nextPage = null;
    prevPage = null;
    maxPage = null;
  }

  // 首次请求
  Future<void> firstLoad() async {
    canLoadMore = false;
    await Future.delayed(200.milliseconds);
    try {
      cancelToken = CancelToken();
      final GalleryList? result = await fetchData();
      if (result == null) {
        change(null, status: RxStatus.loading());
        return;
      }

      final _listItem = result.gallerys;

      logger.t('_listItem ${_listItem?.length}');

      setResultPage(result);
      change(_listItem, status: RxStatus.success());
    } catch (err, stack) {
      logger.e('$err\n$stack');
      final errMsg = err is HttpException ? err.message : '$err';
      change(null, status: RxStatus.error(errMsg));
    } finally {
      canLoadMore = true;
    }
  }

  // 重新加载
  Future<void> reloadData() async {
    resetResultPage();

    try {
      final GalleryList? result = await fetchData(
        refresh: true,
      );

      logger.t('reloadData length ${result?.gallerys?.length}');

      if (result == null) {
        return;
      }

      final List<GalleryProvider>? resultList = result.gallerys;

      setResultPage(result);

      logger.t('reloadData next $next, prev $prev');

      change(resultList, status: RxStatus.success());
      afterJump = false;
    } catch (err) {
      // change(state, status: RxStatus.error(err.toString()));
      final errmsg = err is HttpException ? err.message : '$err';
      showToast(errmsg);
    }
  }

  Future<void> jumpToTop() async {
    await reloadData();
  }

  String? lastNext;
  String? lastPrev;

  // 加载更多
  Future<void> loadDataMore() async {
    await Future.delayed(100.milliseconds);
    if (!canLoadData) {
      logger.e('not canLoadData');
      return;
    }

    if (!canLoadMore) {
      logger.e('not canLoadMore');
      return;
    }

    if (lastNext == next) {
      logger.t('lastNext == next  $next');
      return;
    }

    logger.t('loadDataMore .....');
    pageState = PageState.LoadingMore;

    logger.d('load page next: $next');

    lastNext = next;

    try {
      final GalleryList? result = await fetchMoreData();

      if (result == null) {
        return;
      }

      final List<GalleryProvider> resultList = result.gallerys ?? [];

      final n = state?.indexWhere(
              (GalleryProvider e) => e.gid == resultList.firstOrNull?.gid) ==
          -1;

      if (resultList.isNotEmpty && n) {
        setResultPage(result);

        logger.d('loadDataMore next $next, prev $prev');
      }

      final insertIndex = state?.length ?? 0;

      logger.t('insertIndex $insertIndex');

      if (state == null) {
        change(resultList, status: RxStatus.success());
      } else {
        state!.addAll(resultList);
        change(state, status: RxStatus.success());
      }
    } catch (e, stack) {
      pageState = PageState.LoadingException;
      rethrow;
    }
    // 成功才更新

    pageState = PageState.None;
  }

  // 加载上一页
  Future<void> loadPrevious() async {
    await Future.delayed(100.milliseconds);
    logger.d('loadPrevious .....');
    if (!canLoadData) {
      logger.e('not loadPrevious');
      return;
    }

    if (!canLoadMore) {
      logger.e('not loadPrevious');
      return;
    }

    if (lastPrev == prev) {
      logger.t('lastPrev == prev  $prev');
      return;
    }

    logger.t('loadPrevious .....');
    pageState = PageState.LoadingPrev;

    logger.t('load page prev: $prevGid');

    lastPrev = prevGid;

    try {
      final GalleryList? result = await fetchPrevData();

      if (result == null) {
        return;
      }

      final List<GalleryProvider> resultList = result.gallerys ?? [];

      if (resultList.isNotEmpty &&
          state?.indexWhere(
                  (GalleryProvider e) => e.gid == resultList.first.gid) ==
              -1) {
        setResultPage(result);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (state == null) {
          change(resultList, status: RxStatus.success());
        } else {
          state!.insertAll(0, resultList);
          change(state, status: RxStatus.success());
        }
      });
    } catch (e, stack) {
      pageState = PageState.LoadingException;
      rethrow;
    }
    // 成功才更新

    pageState = PageState.None;
  }

  Future<void> loadFrom({
    String? gid,
    PageType? pageType,
    String? jump,
    String? seek,
    int? page,
  }) async {
    cancelToken = CancelToken();

    canLoadMore = false;
    pageState = PageState.Loading;
    change(state, status: RxStatus.loading());
    try {
      final GalleryList? result = await fetchDataFrom(
        gid: gid,
        pageType: pageType,
        jump: jump,
        seek: seek,
        page: page,
      );
      if (result == null) {
        change(null, status: RxStatus.loading());
        return;
      }

      final _listItem = result.gallerys;

      logger.t('loadFrom _listItem ${_listItem?.length}');

      setResultPage(result);
      change(_listItem, status: RxStatus.success());
      pageState = PageState.None;
      logger.d('loadFrom next $next, prev $prev');
      afterJump = true;
    } catch (err, stack) {
      logger.e('$err\n$stack');
      final errMsg = err is HttpException ? err.message : '$err';
      pageState = PageState.LoadingError;
      change(null, status: RxStatus.error(errMsg));
    } finally {
      canLoadMore = true;
    }
  }

  Future<void> onRefresh() async {
    if (!(cancelToken?.isCancelled ?? false)) {
      cancelToken?.cancel();
    }
    change(state, status: RxStatus.success());
    logger.d('prevGid: $prevGid, prevPage $prevPage,  afterJump: $afterJump');
    if ((prevGid.isNotEmpty || prevPage >= 0) && afterJump) {
      logger.d('>>>>> loadPrevious');
      await loadPrevious();
    } else {
      logger.d('>>>>> reloadData');
      await reloadData();
    }
  }

  Future<void> reLoadDataFirst() async {
    if (!(cancelToken?.isCancelled ?? false)) {
      cancelToken?.cancel();
    }
    change(null, status: RxStatus.loading());
    onReady();
  }

  Future<void> lastComplete() async {}

  void initEhTabController({
    required BuildContext context,
    required EhTabController ehTabController,
    String? tabTag,
    Future<void> Function()? scrollToInitialAnchor,
  }) {
    tabScrollController = ehTabController;
    ehTabController.hasScrollClientsCall = () =>
        context.mounted &&
        (PrimaryScrollController.maybeOf(context)?.hasClients ?? false);
    ehTabController.scrollToTopCall = () => scrollToInitialAnchor == null
        ? scrollToTop(context)
        : scrollToInitialAnchor();
    ehTabController.scrollToTopRefreshCall = () => scrollToTopRefresh(context);
    ehTabController.scrollToTopAndRefreshCall = () async {
      if (scrollToInitialAnchor != null) {
        await scrollToInitialAnchor();
      } else {
        final primary = PrimaryScrollController.maybeOf(context);
        if (!(primary?.hasClients ?? false)) {
          return;
        }
        await primary!.animateTo(
          0.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.ease,
        );
      }
      if (ehTabController.hasScrollClients) {
        await onRefresh();
      }
    };

    tabPages.scrollControllerMap[tabTag ?? heroTag ?? ''] = ehTabController;
  }

  void scrollToTop(BuildContext context) {
    if (!context.mounted) {
      return;
    }
    final primary = PrimaryScrollController.maybeOf(context);
    if (!(primary?.hasClients ?? false)) {
      return;
    }
    primary!.animateTo(0.0,
        duration: const Duration(milliseconds: 500), curve: Curves.ease);
  }

  void scrollToTopRefresh(BuildContext context) {
    if (!context.mounted) {
      return;
    }
    final primary = PrimaryScrollController.maybeOf(context);
    if (!(primary?.hasClients ?? false)) {
      return;
    }
    primary!.animateTo(-kDefaultRefreshTriggerPullDistance,
        duration: const Duration(milliseconds: 500), curve: Curves.ease);
  }

  final _showDatePicker = true.obs;
  bool get showDatePicker => _showDatePicker.value;
  set showDatePicker(bool value) => _showDatePicker.value = value;

  String? lastSeek;
  String? lastJump;

  Future<void> showJumpDialog(BuildContext context) async {
    logger.d('showJumpDialog');
    if (nextPage > -1) {
      final l10n = L10n.of(context);
      final max = maxPage ?? 1;
      final page = await showPageJumpSheet(
        context,
        title: l10n.jump_to_page,
        subtitle: l10n.sp_page_total(max),
        current: int.tryParse(pageTextEditController.text.trim()) ??
            nextPage.clamp(1, max < 1 ? 1 : max),
        max: max,
      );
      if (page != null) {
        pageTextEditController.text = '$page';
        loadFrom(page: page - 1);
      }
      return;
    }

    if (jumpOrSeekTextEditController.text.isEmpty) {
      jumpOrSeekTextEditController.text =
          lastJump ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
    final request = await showSeekSheet(
      context,
      text: jumpOrSeekTextEditController.text,
      gid: gidTextEditController.text,
      pickerVisible: showDatePicker,
      pickerDate: lastSeek != null
          ? DateTime.tryParse(lastSeek!) ?? DateTime.now()
          : DateTime.now(),
      prevGid: prevGid,
      nextGid: nextGid,
      onPickerVisibleChanged: (value) => showDatePicker = value,
    );
    if (request == null) {
      return;
    }
    jumpOrSeekTextEditController.text = request.text;
    gidTextEditController.text = request.gid;
    try {
      await _jumpToPageWithGidOrTime(
        pageType: request.direction == SeekDirection.prev
            ? PageType.prev
            : PageType.next,
        closeDialog: false,
      );
    } catch (e, stack) {
      logger.e('jump or seek error', error: e, stackTrace: stack);
      showToast('$e');
    }
  }

  Future<void> _jumpToPageWithGidOrTime({
    PageType? pageType,
    bool closeDialog = true,
  }) async {
    final String jumpOrSeek = jumpOrSeekTextEditController.text.trim();
    final String _gid = gidTextEditController.text.trim();

    logger.t('jumpOrSeek is $jumpOrSeek _gid is $_gid');

    if (jumpOrSeek.isEmpty && _gid.isEmpty) {
      showToast(L10n.of(Get.context!).input_empty);
      return;
    }

    final jumpExp = RegExp(r'^\d+[wmy]?$');
    // YYYY, YYYY-MM or YYYY-MM-DD
    final dateExpFull = RegExp(r'^\d{4}(-\d{2}){0,2}$');
    // YY-MM or YY-MM-DD
    final dateExpShort = RegExp(r'^\d{2}(-\d{2}){1,2}$');

    String jump = '';
    String seek = '';
    if (jumpExp.hasMatch(jumpOrSeek)) {
      jump = jumpOrSeek;
    } else if (dateExpFull.hasMatch(jumpOrSeek) ||
        dateExpShort.hasMatch(jumpOrSeek)) {
      seek = jumpOrSeek;
    } else {
      showToast(L10n.of(Get.context!).input_error);
    }

    logger.t('jump is $jump, seek is $seek, gid is $_gid');

    FocusScope.of(Get.context!).requestFocus(FocusNode());

    // if _gid is not empty, toGid is _gid ,
    // else if pageType is prev, toGid is prev,
    // else if pageType is next, toGid is next
    final toGid = _gid.isEmpty
        ? pageType == PageType.prev
            ? prevGid
            : nextGid
        : _gid;

    loadFrom(
      jump: jump,
      seek: seek,
      gid: toGid,
      pageType: pageType,
    );
    if (closeDialog) {
      Get.back();
    }
    lastSeek = seek;
    lastJump = jump;
    jumpOrSeekTextEditController.clear();
    gidTextEditController.clear();
  }
}
