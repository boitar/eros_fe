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

  /// A toolbar refresh must not start a second request for the same list.
  /// Keeping this state in the shared list controller also protects the
  /// desktop action when the user changes groups while a response is in flight.
  final RxBool _isReloading = false.obs;
  bool get isReloading => _isReloading.value;
  Future<void>? _reloadInFlight;
  int _requestGeneration = 0;
  int _successfulReloads = 0;
  Object? _reloadIdentity;
  bool _disposed = false;

  /// Only request conditions belong here; presentation preferences do not.
  Object? get requestIdentity => null;

  @protected
  int get requestRevision => _requestGeneration;

  bool _isCurrent(int generation, Object? identity) =>
      !_disposed &&
      generation == _requestGeneration &&
      identity == requestIdentity;

  int _replaceRequest() {
    cancelToken?.cancel('list request replaced');
    _reloadInFlight = null;
    _isReloading.value = false;
    return ++_requestGeneration;
  }

  @override
  void onClose() {
    _disposed = true;
    _replaceRequest();
    pageTextEditController.dispose();
    gidTextEditController.dispose();
    jumpOrSeekTextEditController.dispose();
    gidNode.dispose();
    super.onClose();
  }

  Future<void> refreshFromToolbar({bool Function()? isCurrent}) async {
    final revision = _successfulReloads;
    await reloadData();
    if (!_disposed &&
        _successfulReloads > revision &&
        (isCurrent?.call() ?? true)) {
      galleryAnchor.forget();
      tabScrollController?.scrollToTop();
    }
  }

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
    pageTextEditController.clear();
  }

  // Replacement requests retain ownership across cache and network awaits.
  Future<void> firstLoad() async {
    final generation = _replaceRequest();
    final identity = requestIdentity;
    canLoadMore = false;
    await Future.delayed(200.milliseconds);
    if (!_isCurrent(generation, identity)) return;
    try {
      final result = await fetchData();
      if (!_isCurrent(generation, identity) || result == null) return;
      setResultPage(result);
      lastNext = lastPrev = null;
      change(result.gallerys, status: RxStatus.success());
      pageState = PageState.None;
    } catch (err, stack) {
      if (!_isCurrent(generation, identity) ||
          (err is DioException && CancelToken.isCancel(err)))
        return;
      logger.e('$err\n$stack');
      final message = err is HttpException ? err.message : '$err';
      change(null, status: RxStatus.error(message));
      pageState = PageState.LoadingError;
    } finally {
      if (_isCurrent(generation, identity)) canLoadMore = true;
    }
  }

  Future<void> reloadData() {
    final identity = requestIdentity;
    final existing = _reloadInFlight;
    if (existing != null && identity == _reloadIdentity) return existing;
    if (pageState == PageState.LoadingMore) lastNext = null;
    if (pageState == PageState.LoadingPrev) lastPrev = null;
    final generation = _replaceRequest();
    _reloadIdentity = identity;
    _isReloading.value = true;
    late final Future<void> tracked;
    tracked = _reloadData(generation, identity).whenComplete(() {
      if (identical(_reloadInFlight, tracked)) _reloadInFlight = null;
    });
    _reloadInFlight = tracked;
    return tracked;
  }

  Future<void> _reloadData(int generation, Object? identity) async {
    // Cursors, content, anchor and pagination remain intact on failure.
    final previousCanLoadMore = canLoadMore;
    try {
      final result = await fetchData(refresh: true);
      if (!_isCurrent(generation, identity) || result == null) return;
      setResultPage(result);
      lastNext = lastPrev = null;
      afterJump = false;
      canLoadMore = true;
      change(result.gallerys, status: RxStatus.success());
      _successfulReloads++;
    } catch (err) {
      if (_isCurrent(generation, identity)) {
        canLoadMore = previousCanLoadMore;
        if (!(err is DioException && CancelToken.isCancel(err))) {
          reportRefreshError(err is HttpException ? err.message : '$err');
        }
      }
    } finally {
      if (generation == _requestGeneration && !_disposed) {
        _isReloading.value = false;
        pageState = PageState.None;
      }
    }
  }

  @protected
  void reportRefreshError(String message) => showToast(message);

  Future<void> jumpToTop() async {
    await reloadData();
  }

  String? lastNext;
  String? lastPrev;

  Future<void> loadDataMore() => _loadAdjacent(previous: false);

  Future<void> loadPrevious() => _loadAdjacent(previous: true);

  Future<void> _loadAdjacent({required bool previous}) async {
    final generation = _requestGeneration;
    final identity = requestIdentity;
    await Future.delayed(100.milliseconds);
    if (!_isCurrent(generation, identity) ||
        isReloading ||
        !canLoadData ||
        !canLoadMore)
      return;
    final cursor = previous ? prev : next;
    if ((previous ? lastPrev : lastNext) == cursor) return;
    pageState = previous ? PageState.LoadingPrev : PageState.LoadingMore;
    if (previous) {
      lastPrev = cursor;
    } else {
      lastNext = cursor;
    }
    var committed = false;
    try {
      final result = await (previous ? fetchPrevData() : fetchMoreData());
      if (!_isCurrent(generation, identity) || result == null) return;
      final existingIds = {
        for (final item in state ?? <GalleryProvider>[]) item.gid,
      };
      final items = (result.gallerys ?? <GalleryProvider>[])
          .where((item) => item.gid == null || existingIds.add(item.gid))
          .toList();
      setResultPage(result);
      void commit() {
        if (!_isCurrent(generation, identity)) return;
        final list = state ?? <GalleryProvider>[];
        if (previous) {
          list.insertAll(0, items);
        } else {
          list.addAll(items);
        }
        change(list, status: RxStatus.success());
      }

      if (previous) {
        WidgetsBinding.instance.addPostFrameCallback((_) => commit());
      } else {
        commit();
      }
      committed = true;
    } catch (err) {
      if (!_isCurrent(generation, identity) ||
          (err is DioException && CancelToken.isCancel(err)))
        return;
      pageState = PageState.LoadingException;
      rethrow;
    } finally {
      if (_isCurrent(generation, identity)) {
        if (!committed) {
          if (previous) {
            lastPrev = null;
          } else {
            lastNext = null;
          }
        }
        if (pageState != PageState.LoadingException) pageState = PageState.None;
      }
    }
  }

  Future<void> loadFrom({
    String? gid,
    PageType? pageType,
    String? jump,
    String? seek,
    int? page,
    bool markAfterJump = true,
  }) async {
    final generation = _replaceRequest();
    final identity = requestIdentity;
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
      if (!_isCurrent(generation, identity)) return;
      if (result == null) {
        change(null, status: RxStatus.loading());
        return;
      }

      final _listItem = result.gallerys;

      logger.t('loadFrom _listItem ${_listItem?.length}');

      setResultPage(result);
      lastNext = lastPrev = null;
      change(_listItem, status: RxStatus.success());
      pageState = PageState.None;
      logger.d('loadFrom next $next, prev $prev');
      afterJump = markAfterJump;
    } catch (err, stack) {
      if (!_isCurrent(generation, identity) ||
          (err is DioException && CancelToken.isCancel(err)))
        return;
      logger.e('$err\n$stack');
      final errMsg = err is HttpException ? err.message : '$err';
      pageState = PageState.LoadingError;
      change(null, status: RxStatus.error(errMsg));
    } finally {
      if (_isCurrent(generation, identity)) canLoadMore = true;
    }
  }

  Future<void> onRefresh() async {
    if (isReloading) {
      await reloadData();
      return;
    }
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
    primary!.animateTo(
      0.0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.ease,
    );
  }

  void scrollToTopRefresh(BuildContext context) {
    if (!context.mounted) {
      return;
    }
    final primary = PrimaryScrollController.maybeOf(context);
    if (!(primary?.hasClients ?? false)) {
      return;
    }
    primary!.animateTo(
      -kDefaultRefreshTriggerPullDistance,
      duration: const Duration(milliseconds: 500),
      curve: Curves.ease,
    );
  }

  final _showDatePicker = true.obs;
  bool get showDatePicker => _showDatePicker.value;
  set showDatePicker(bool value) => _showDatePicker.value = value;

  String? lastSeek;
  String? lastJump;

  Future<void> showJumpDialog(BuildContext context) async {
    logger.d('showJumpDialog');
    if (nextPage > -1 || prevPage > -1) {
      final l10n = L10n.of(context);
      final max = maxPage ?? 1;
      final fallbackPage = nextPage > -1
          ? nextPage.clamp(1, max < 1 ? 1 : max)
          : max;
      final current =
          int.tryParse(pageTextEditController.text.trim()) ?? fallbackPage;
      final result = await showPageJumpSheet(
        context,
        title: l10n.jump_to_page,
        subtitle: l10n.sp_page_total(max),
        current: current,
        max: max,
      );
      if (result != null) {
        if (result.nav == JumpNavAction.first) {
          pageTextEditController.clear();
          await loadFrom(page: 0, markAfterJump: false);
        } else {
          pageTextEditController.text = '${result.page}';
          await loadFrom(page: result.page - 1, markAfterJump: result.page > 1);
        }
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
    if (request.nav != null) {
      try {
        await _navigateCursor(request.nav!);
      } catch (e, stack) {
        logger.e('jump nav error', error: e, stackTrace: stack);
        showToast('$e');
      }
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

  Future<void> _navigateCursor(JumpNavAction action) async {
    switch (action) {
      case JumpNavAction.first:
        resetResultPage();
        jumpOrSeekTextEditController.clear();
        gidTextEditController.clear();
        await loadFrom(markAfterJump: false);
      case JumpNavAction.prev:
        if (prevGid.isNotEmpty) {
          await loadFrom(gid: prevGid, pageType: PageType.prev);
        }
      case JumpNavAction.next:
        if (nextGid.isNotEmpty) {
          await loadFrom(gid: nextGid, pageType: PageType.next);
        }
      case JumpNavAction.last:
        await loadFrom(gid: '1', pageType: PageType.prev);
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

    loadFrom(jump: jump, seek: seek, gid: toGid, pageType: pageType);
    if (closeDialog) {
      Get.back();
    }
    lastSeek = seek;
    lastJump = jump;
    jumpOrSeekTextEditController.clear();
    gidTextEditController.clear();
  }
}
