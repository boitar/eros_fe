import 'dart:async';
import 'dart:io';

import 'package:archive_async/archive_async.dart';
import 'package:collection/collection.dart';
import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/common/controller/archiver_download_controller.dart';
import 'package:eros_fe/common/controller/download_controller.dart';
import 'package:eros_fe/common/controller/gallerycache_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/network/request.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_controller.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_state.dart';
import 'package:eros_fe/pages/image_view/common.dart';
import 'package:eros_fe/pages/image_view/view/view_widget.dart';
import 'package:eros_fe/store/archive_async.dart';
import 'package:eros_fe/utils/orientation_helper.dart';
import 'package:eros_fe/utils/saf_helper.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_android_volume_keydown/flutter_android_volume_keydown.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;
import 'package:photo_view/photo_view.dart';
import 'package:preload_page_view/preload_page_view.dart';
import 'package:saf/saf.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:synchronized/synchronized.dart';
import 'package:throttling/throttling.dart';
// import 'package:wakelock/wakelock.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../view/view_page.dart';
import 'view_state.dart';

// 底栏控制栏按钮高度
const double kBottomBarButtonHeight = 54.0;

// 底栏控制栏高度
const double kBottomBarHeight = 64.0;

// 底栏滑动栏高度
const double kSliderBarHeight = 64.0;

// 顶栏高度
const double kTopBarHeight = 56.0;

// 顶栏按钮高度
const double kTopBarButtonHeight = 44.0;

// 缩略图栏高度
const double kThumbListViewHeight = 140.0;
const double kThumbImageWidth = kThumbListViewHeight / 2 - 10;

const String idViewTopBar = 'ViewTopBar';
const String idViewBottomBar = 'ViewBottomBar';
const String idViewBar = 'ViewBar';
const String idViewPageSlider = 'ViewPageSlider';
const String idSlidePage = 'ViewImageSlidePage';
const String idImagePageView = 'ImagePageView';
const String idImageListView = 'ImageListView';
const String idViewColumnModeIcon = 'ViewColumnModeIcon';
const String idThumbnailListView = 'ThumbnailListView';
const String idShowThumbListIcon = 'ShowThumbListIcon';
const String idAutoReadIcon = 'AutoReadIcon';
const String idIconBar = 'IconBar';
const String idProcess = 'Process';

const int _speedMaxCount = 50;
const int _speedInv = 10;

/// 支持在线以及本地（已下载）阅读的组件
class ViewExtController extends GetxController {
  ViewExtController({ViewExtState? state, ViewRepository? repository})
      : vState = state ?? ViewExtState(repository: repository);

  /// 状态
  final ViewExtState vState;

  final _absorbing = false.obs;
  bool get absorbing => _absorbing.value;
  set absorbing(bool val) => _absorbing.value = val;

  late PageController pageController;
  late ExtendedPageController extendedPageController;

  late PreloadPageController preloadPageController;
  ViewColumnMode? _renderedColumnMode;
  int _paginationGeneration = 0;
  int get paginationGeneration => _paginationGeneration;
  bool _renderedBookSpread = false;
  Timer? _continuousPositionTimer;
  VoidCallback? _itemPositionsChanged;
  VoidCallback? _thumbPositionsChanged;

  /// Captured by the page-view build, so a disposed layout cannot update the
  /// original image anchor during a rapid resize.
  ValueChanged<int> get pageChangedCallback {
    final generation = _paginationGeneration;
    return (page) {
      if (!isClosed && generation == _paginationGeneration) {
        handOnPageChanged(page);
      }
    };
  }

  GalleryPageController? get _galleryPageController =>
      vState.galleryPageController;

  GalleryPageState? get _galleryPageStat => vState.pageState;

  EhSettingService get _ehSettingService => vState.ehSettingService;

  late final ArchiverDownloadController archiverDownloadController;

  // 使用 PhotoView
  // PageViewType get pageViewType => _ehSettingService.readViewCompatibleMode
  //     ? PageViewType.extendedImageGesturePageView
  //     : PageViewType.preloadPageView;
  PageViewType get pageViewType => _ehSettingService.pageViewType;
  set pageViewType(PageViewType val) => _ehSettingService.pageViewType = val;

  // enableSlideOutPage
  bool get enableSlideOutPage => _ehSettingService.enableSlideOutPage;
  set enableSlideOutPage(bool val) =>
      _ehSettingService.enableSlideOutPage = val;

  Map<String, DownloadArchiverTaskInfo> get archiverTaskMap =>
      archiverDownloadController.archiverTaskMap;

  Map<int, Future<GalleryImage?>> imageFutureMap = {};

  Map<int, Stream<GalleryImage?>> imageStreamMap = {};

  Map<int, Future<File?>> imageArchiveFutureMap = {};

  final imageArchiveLock = Lock();

  final imageLock = Lock();

  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();

  final ItemScrollController thumbScrollController = ItemScrollController();
  final ItemPositionsListener thumbPositionsListener =
      ItemPositionsListener.create();

  final AutoScrollController autoScrollController = AutoScrollController();
  final photoViewScaleStateController = PhotoViewScaleStateController();

  final FlutterListViewController flutterListViewController =
      FlutterListViewController();

  final PhotoViewController photoViewController = PhotoViewController();

  final GlobalKey<ExtendedImageSlidePageState> slidePagekey =
      GlobalKey<ExtendedImageSlidePageState>();

  Timer? autoNextTimer;

  StreamSubscription? _volumeKeyDownSubscription;

  String? safCacheDirectory;

  @override
  void onInit() {
    super.onInit();
    _liveReaders++;
    _renderedColumnMode = vState.columnMode;

    if (Get.isRegistered<ArchiverDownloadController>()) {
      archiverDownloadController = Get.find();
    }

    // 横屏模式 pageView 控制器初始化
    pageController = PageController(
      initialPage: vState.pageIndex,
      keepPage: false,
      viewportFraction: vState.showPageInterval ? 1.1 : 1.0,
      // viewportFraction: 0.999999,
    );

    preloadPageController = PreloadPageController(
      initialPage: vState.pageIndex,
      keepPage: false,
      // viewportFraction: vState.showPageInterval
      //     ? (Get.context!.width + 10) / Get.context!.width
      //     : 1.0,
      // viewportFraction: vState.showPageInterval ? 1.1 : 1.0,
    );

    extendedPageController = ExtendedPageController(
      initialPage: vState.pageIndex,
      keepPage: false,
      shouldIgnorePointerWhenScrolling: true,
    );

    // 竖屏模式初始页码
    if (vState.viewMode == ViewMode.topToBottom) {
      // logger.t('竖屏模式初始页码: ${vState.itemIndex}');
      Future.delayed(const Duration(milliseconds: 50)).then((_) {
        if (!isClosed &&
            vState.viewMode == ViewMode.topToBottom &&
            itemScrollController.isAttached) {
          itemScrollController.jumpTo(index: vState.currentItemIndex);
        }
      });

      vState.speedTimer = Timer.periodic(
        const Duration(milliseconds: _speedInv),
        (timer) {
          // loggerSimple.d('${vState.tempPos}');
          final offset = vState.tempPos;
          vState.speedList.add(offset);
          if (vState.speedList.length > _speedMaxCount) {
            vState.speedList.removeAt(0);
          }
        },
      );
    }

    // list视图滚动监听
    _itemPositionsChanged = () {
      if (isClosed) return;
      final positions = itemPositionsListener.itemPositions.value;
      if (positions.isEmpty) return;
      vState.tempPos = positions.first.itemLeadingEdge;
      handItemPositionsChange(positions);
    };
    itemPositionsListener.itemPositions.addListener(_itemPositionsChanged!);

    Future.delayed(const Duration(milliseconds: 200)).then((value) {
      if (thumbScrollController.isAttached) {
        thumbScrollController.jumpTo(index: vState.currentItemIndex);
      }
    });

    // 缩略图滚动组件监听
    _thumbPositionsChanged = () {
      if (isClosed) return;
      final positions = thumbPositionsListener.itemPositions.value;
      handThumbPositionsChange(positions);
    };
    thumbPositionsListener.itemPositions.addListener(_thumbPositionsChanged!);

    photoViewScaleStateController.outputScaleStateStream.listen((state) {
      final prevScaleState = photoViewScaleStateController.prevScaleState;
      logger.d('prevScaleState $prevScaleState , cur state $state');
    });

    addVolumeKeydownListen();
  }

  @override
  void onReady() {
    super.onReady();

    logger.t('Read onReady');

    /// 初始预载
    /// 后续的预载触发放在翻页事件中
    if (vState.loadFrom == LoadFrom.gallery) {
      // 预载
      logger.t('初始预载');

      GalleryPara.instance
          .ehPrecacheImages(
        imageMap: vState.imageMap,
        itemSer: vState.currentItemIndex,
        max: _ehSettingService.preloadImage.value,
        showKey: vState.pageState?.galleryProvider?.showKey,
      )
          .listen((GalleryImage? event) {
        if (event != null) {
          _galleryPageController?.uptImageBySer(
              ser: event.ser, imageCallback: (image) => event);
        }
      });
    }

    logger.t('旋转设置');
    final ReadOrientation? orientation = _ehSettingService.orientation.value;
    // logger.d(' $_orientation');
    if (orientation != ReadOrientation.system &&
        orientation != ReadOrientation.auto) {
      OrientationHelper.setPreferredOrientations(
          [orientationMap[orientation] ?? DeviceOrientation.portraitUp]);
    }

    // vState.sliderValue = vState.currentItemIndex / 1.0;
    _setPageSliderValue(updateSlider: true);

    // setFullscreen();
    400.milliseconds.delay(syncFullscreen);
  }

  @override
  void onClose() {
    _continuousPositionTimer?.cancel();
    if (_itemPositionsChanged != null) {
      itemPositionsListener.itemPositions
          .removeListener(_itemPositionsChanged!);
    }
    if (_thumbPositionsChanged != null) {
      thumbPositionsListener.itemPositions
          .removeListener(_thumbPositionsChanged!);
    }
    cancelAutoRead();
    autoNextTimer?.cancel();
    autoNextTimer = null;

    vState.speedTimer?.cancel();
    Get.find<GalleryCacheController>().saveAll();
    vState.saveLastIndex(saveToStore: true);
    vState.dispose();
    flutterListViewController.dispose();
    autoScrollController.dispose();
    photoViewController.dispose();
    photoViewScaleStateController.dispose();
    pageController.dispose();
    preloadPageController.dispose();
    extendedPageController.dispose();
    vState.getMoreCancelToken.cancel();

    cancelVolumeKeydownListen();

    // unsetFullscreen();
    _liveReaders--;
    // A reader opened right after this one owns the system bars by now.
    400.milliseconds.delay(() {
      if (_liveReaders == 0) {
        unsetFullscreen();
      }
    });

    // 恢复系统旋转设置
    logger.t('恢复系统旋转设置');
    OrientationHelper.setPreferredOrientations(DeviceOrientation.values);

    vState.asyncInputStreamMap.values.map((e) => e.close());

    if (safCacheDirectory != null) {
      Saf.clearCacheFor(safCacheDirectory);
      safCacheDirectory = null;
    }

    super.onClose();
  }

  void addVolumeKeydownListen() {
    if (_ehSettingService.volumnTurnPage) {
      _volumeKeyDownSubscription =
          FlutterAndroidVolumeKeydown.stream.listen((event) {
        if (event == HardwareButton.volume_down) {
          // logger.d('Volume down received');
          toNext();
        } else if (event == HardwareButton.volume_up) {
          // logger.d('Volume up received');
          toPrev();
        }
      });
    }
  }

  void cancelVolumeKeydownListen() {
    _volumeKeyDownSubscription?.cancel();
  }

  Future<void> initArchiveFuture(int ser, {AsyncArchiveFile? asyncFile}) async {
    final file = asyncFile ?? vState.asyncArchiveFiles[ser - 1];
    logger.t('load ${file.name}');
    imageArchiveFutureMap[ser] = getArchiveFile(vState.gid, file);
  }

  Future<void> initFuture(int ser) async {
    imageFutureMap[ser] = fetchImage(ser);
  }

  Future<File> getArchiveFile(String? gid, AsyncArchiveFile file) async {
    // 同步锁 保证同时只有一个读取操作
    return await imageArchiveLock.synchronized(() => _getFile(gid, file));
  }

  Future<File> _getFile(String? gid, AsyncArchiveFile file) async {
    final outFile = File(path.join(Global.tempPath, 'archive_$gid', file.name));
    if (outFile.existsSync()) {
      return outFile;
    }
    final fileData = await file.getContent();
    await outFile.create(recursive: true);
    await outFile.writeAsBytes(fileData as Uint8List);
    return outFile;
  }

  void resetPageController() {
    final oldPage = pageController;
    final oldPreload = preloadPageController;
    final oldExtended = extendedPageController;
    _paginationGeneration++;
    photoViewController.reset();
    photoViewScaleStateController.scaleState = PhotoViewScaleState.initial;
    pageController = PageController(
      initialPage: vState.pageIndex,
      keepPage: false,
      viewportFraction: vState.showPageInterval ? 1.1 : 1.0,
    );
    preloadPageController =
        PreloadPageController(initialPage: vState.pageIndex, keepPage: false);
    extendedPageController = ExtendedPageController(
      initialPage: vState.pageIndex,
      keepPage: false,
      shouldIgnorePointerWhenScrolling: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldPage.dispose();
      oldPreload.dispose();
      oldExtended.dispose();
    });
  }

  /// Re-evaluate only automatic reader layout after a live window resize.
  /// Explicit single/paired choices are untouched.
  void updateViewport(Size size,
      {bool? canUseDoublePage, bool bookFolded = false}) {
    if (isClosed || size.isEmpty || !size.isFinite) {
      return;
    }
    vState.viewportSize = size;
    vState.viewportAllowsDoublePage = canUseDoublePage;
    vState.bookFolded = bookFolded;
    refreshPagination();
  }

  void refreshPagination() {
    if (isClosed) return;
    final next = vState.columnMode;
    final bookSpread = vState.bookFolded && next != ViewColumnMode.single;
    if (_renderedColumnMode == next && _renderedBookSpread == bookSpread) {
      return;
    }
    _renderedColumnMode = next;
    _renderedBookSpread = bookSpread;
    resetPageController();
    update([
      idImagePageView,
      idSlidePage,
      idViewColumnModeIcon,
      idViewBottomBar,
      idViewTopBar,
    ]);
    _setPageSliderValue(updateSlider: true);
  }

  void setColumnPreference(ReaderColumnPreference preference) {
    _ehSettingService.setReaderColumnPreference(preference);
    refreshPagination();
    update([idViewBar, idViewColumnModeIcon, idViewTopBar]);
  }

  void cycleSurfacePreference() {
    final values = ReaderSurfacePreference.values;
    vState.surfacePreference =
        values[(vState.surfacePreference.index + 1) % values.length];
    update([idViewBar]);
  }

  // 横向页码切换时的回调
  void handOnPageChanged(int pageIndex) {
    vState.currentItemIndex = vState.pagination.imageAfterPageChange(
      pageIndex,
      currentImage: vState.currentItemIndex,
    );

    if (vState.loadFrom == LoadFrom.gallery) {
      // 预载图片
      // logger.t('页码切换时的回调 预载图片');
      GalleryPara.instance
          .ehPrecacheImages(
        imageMap: _galleryPageStat?.imageMap,
        itemSer: vState.currentItemIndex,
        max: _ehSettingService.preloadImage.value,
        showKey: vState.pageState?.galleryProvider?.showKey,
      )
          .listen((GalleryImage? event) {
        if (event != null) {
          _galleryPageController?.uptImageBySer(
              ser: event.ser, imageCallback: (val) => event);
        }
      });
    }

    // if (vState.currentItemIndex >= vState.fileCount - 1) {
    //   vState.sliderValue = (vState.fileCount - 1).toDouble();
    // } else if (vState.currentItemIndex < 0) {
    //   vState.sliderValue = 1.0;
    // } else {
    //   vState.sliderValue = vState.currentItemIndex.toDouble();
    // }
    _setPageSliderValue();

    update([idViewTopBar, idViewPageSlider]);
    if (vState.syncThumbList) {
      thumbScrollTo();
    }
  }

  void _setPageSliderValue({bool updateSlider = false}) {
    logger.t(
        '>>> _setPageSliderValue currentItemIndex ${vState.currentItemIndex}');
    if (vState.currentItemIndex >= vState.fileCount - 1) {
      vState.sliderValue = (vState.fileCount - 1).toDouble();
    } else if (vState.currentItemIndex < 0) {
      vState.sliderValue = 1.0;
    } else {
      vState.sliderValue = vState.currentItemIndex.toDouble();
    }
    logger.t('>>> _setPageSliderValue ${vState.sliderValue}');
    if (updateSlider) {
      update([idViewTopBar, idViewPageSlider]);
    }
  }

  /// 切换单页双页模式
  Future<void> switchColumnMode() async {
    vibrateUtil.light();
    final next = switch (vState.columnMode) {
      ViewColumnMode.single => ReaderColumnPreference.oddLeft,
      ViewColumnMode.oddLeft => ReaderColumnPreference.evenLeft,
      ViewColumnMode.evenLeft => ReaderColumnPreference.single,
    };
    setColumnPreference(next);
  }

  Future<void> switchShowThumbList() async {
    if (vState.showThumbList) {
      vState.showThumbList = false;
    } else {
      vState.showThumbList = true;
    }

    // The bar layout reserves the filmstrip's height, so it must rebuild too.
    update([
      idViewBar,
      idShowThumbListIcon,
      idViewBottomBar,
      idThumbnailListView,
    ]);
  }

  final Map<int, Future<void>?> _mapFetchGalleryPriviewPage = {};

  /// 拉取图片信息
  Future<GalleryImage?> fetchThumb(
    int itemSer, {
    bool refresh = false,
    bool changeSource = false,
  }) async {
    final GalleryImage? tImage = _galleryPageStat?.imageMap[itemSer];
    if (tImage == null) {
      logger.d('fetchThumb ser:$itemSer 所在页尚未获取， 开始获取');
      _mapFetchGalleryPriviewPage.putIfAbsent(
          itemSer, () => _galleryPageController?.loadImagesForSer(itemSer));

      // 直接获取需要的ser所在页
      await _mapFetchGalleryPriviewPage[itemSer];
    }

    final GalleryImage? image = _galleryPageStat?.imageMap[itemSer];

    return image;
  }

  Future<GalleryImage?> _getImageFromImageTasks(
    int itemSer,
    String? dir, {
    bool reloadDB = false,
  }) async {
    if (dir == null) {
      return null;
    }

    if (reloadDB) {
      vState.imageTasks = await isarHelper.findImageTaskAllByGidIsolate(
          int.tryParse(_galleryPageStat?.gid ?? '') ?? 0);
    }

    final imageTask = vState.imageTasks
        .firstWhereOrNull((imageTask) => imageTask.ser == itemSer);

    if (imageTask != null &&
        imageTask.filePath != null &&
        imageTask.filePath!.isNotEmpty &&
        imageTask.status == TaskStatus.complete.value) {
      final filePath = dir.isContentUri
          ? '$dir%2F${imageTask.filePath}'
          : path.join(dir, imageTask.filePath!);

      return GalleryImage(
        ser: itemSer,
        completeDownload: true,
        filePath: filePath,
      );
    }
    return null;
  }

  Future<String?> _getTaskDirPath(int gid) async {
    logger.t('vState.realDirPath ${vState.realDirPath} gid:${vState.gid} $gid');
    if (vState.gid == gid.toString() &&
        vState.realDirPath != null &&
        vState.realDirPath!.isNotEmpty) {
      return vState.realDirPath;
    }

    final gTask = await isarHelper.findGalleryTaskByGid(gid);

    final realDirPath = gTask?.realDirPath;
    if (realDirPath != null && realDirPath.isNotEmpty) {
      vState.realDirPath = realDirPath;
    }

    return gTask?.realDirPath;
  }

  /// 拉取图片信息
  Future<GalleryImage?> fetchImage(
    int itemSer, {
    bool changeSource = false,
  }) async {
    logger.t('fetchImage ser:$itemSer');

    // 首先检查下载记录中是否有记录
    vState.dirPath ??=
        await _getTaskDirPath(int.tryParse(_galleryPageStat?.gid ?? '') ?? 0);

    late GalleryImage? image;

    // 检查是否已下载
    image = await _getImageFromImageTasks(itemSer, vState.dirPath);
    image ??=
        await _getImageFromImageTasks(itemSer, vState.dirPath, reloadDB: true);
    if (image != null) {
      logger.d('fetchImage ser:$itemSer 从下载记录中获取');
      return image;
    }

    // 检查是否已下载archive
    if (GetPlatform.isMobile) {
      image ??= await getFromArchiverTask(itemSer);
    }

    // 请求页面 解析为 [GalleryImage]
    if (image == null) {
      final tImage = _galleryPageStat?.imageMap[itemSer];
      if (tImage == null) {
        logger.d('ser:$itemSer 所在页尚未获取， 开始获取');

        // 直接获取所在页数据
        await _galleryPageController?.loadImagesForSer(itemSer);
      }

      var needShowKey =
          vState.pageState?.galleryProvider?.showKey?.isEmpty ?? true;

      if (needShowKey) {
        // fetchAndParserImageInfo() then ehPrecacheImages()
        // make sure showKey is parsed before ehPrecacheImages()
        image = await _galleryPageController?.fetchAndParserImageInfo(
          itemSer,
          cancelToken: vState.getMoreCancelToken,
          changeSource: changeSource,
        );
      }

      GalleryPara.instance
          .ehPrecacheImages(
        imageMap: _galleryPageStat?.imageMap,
        itemSer: itemSer,
        max: _ehSettingService.preloadImage.value,
        showKey: vState.pageState?.galleryProvider?.showKey,
      )
          .listen((GalleryImage? event) {
        if (event != null) {
          _galleryPageController?.uptImageBySer(
              ser: event.ser, imageCallback: (val) => val = event);
        }
      });

      if (!needShowKey) {
        // ehPrecacheImages() then fetchAndParserImageInfo()
        // the original logic
        image = await _galleryPageController?.fetchAndParserImageInfo(
          itemSer,
          cancelToken: vState.getMoreCancelToken,
          changeSource: changeSource,
        );
      }
    }

    return image;
  }

  Future<GalleryImage?> getFromArchiverTask(int itemSer) async {
    final gid = vState.gid;
    // 读取缓存
    AsyncArchive? asyncArchive = vState.asyncArchiveMap[gid];

    if (asyncArchive == null && gid != null) {
      // archiver任务
      final task = archiverTaskMap.values
          .sorted((t1, t2) => (t1.type ?? '').compareTo(t2.type ?? ''))
          .where((element) =>
              element.gid == _galleryPageStat?.gid &&
              element.status ==
                  downloadStatusToInt(DownloadTaskStatus.complete))
          .toList()
          .firstOrNull;

      if (task == null) {
        return null;
      }

      late final String? filePath;
      if (task.savedDir?.isContentUri ?? false) {
        final uri = task.safUri ??
            '${task.savedDir}%2F${Uri.encodeComponent(task.fileName ?? '')}';
        final result = await safCacheSingle(Uri.parse(uri));
        filePath = result.cachePath;
        safCacheDirectory = result.parentPath;
      } else {
        filePath = path.join(task.savedDir ?? '', task.fileName);
      }
      logger.d('filePath $filePath');
      if (filePath == null) {
        throw Exception('filePath is null');
      }

      // 异步读取zip
      final result = await readAsyncArchive(filePath.realArchiverPath);
      final asyncArchive = result.asyncArchive;
      final asyncInputStream = result.asyncInputStream;
      vState.asyncArchiveMap[gid] = asyncArchive;
      vState.asyncInputStreamMap[gid] = asyncInputStream;
    }

    if (asyncArchive == null) {
      return null;
    }

    final file =
        await getArchiveFile(vState.gid, asyncArchive.files[itemSer - 1]);

    return GalleryImage(
        ser: itemSer, gid: _galleryPageStat?.gid, tempPath: file.path);
  }

  /// 重载图片数据，重构部件
  Future<void> reloadImage(int itemSer, {bool changeSource = true}) async {
    final GalleryImage? _currentImage = _galleryPageStat?.imageMap[itemSer];
    // 清除CachedNetworkImage的缓存
    try {
      // CachedNetworkImage 清除指定缓存
      // await CachedNetworkImage.evictFromCache(_currentImage?.imageUrl ?? '');
      // extended_image 清除指定缓存
      await clearDiskCachedImage(_currentImage?.imageUrl ?? '');
      clearMemoryImageCache();
    } catch (_) {}

    if (_currentImage == null) {
      return;
    }
    _galleryPageController?.uptImageBySer(
      ser: itemSer,
      imageCallback: (image) => image.copyWith(
        imageUrl: ''.oN,
        changeSource: changeSource.oN,
        completeCache: false.oN,
      ),
    );

    // 换源重载
    imageFutureMap[itemSer] = fetchImage(
      itemSer,
      changeSource: changeSource,
    );

    // update();
    update(['$idImageListView$itemSer', idImagePageView]);
  }

  void setScale100(ImageInfo imageInfo, Size size) {
    final sizeImage = Size(
        imageInfo.image.width.toDouble(), imageInfo.image.height.toDouble());

    final double _scalesS100 = scale100(size: size, imageSize: sizeImage);

    if (vState.doubleTapScales.length < 3) {
      vState.doubleTapScales.add(_scalesS100);
    } else {
      vState.doubleTapScales[2] = _scalesS100;
    }
  }

  double readerZoomRatioFor(int imageSer) {
    final ratio = vState.readerZoomRatios[imageSer] ?? 1.0;
    if (!ratio.isFinite) return 1.0;
    return ratio.clamp(1.0, 10.0);
  }

  void recordReaderZoom({
    required int imageSer,
    required double totalScale,
    required double fittedScale,
  }) {
    if (isClosed ||
        !totalScale.isFinite ||
        !fittedScale.isFinite ||
        fittedScale <= 0) {
      return;
    }
    final ratio = (totalScale / fittedScale).clamp(1.0, 10.0);
    if (ratio <= 1.0005) {
      vState.readerZoomRatios.remove(imageSer);
    } else {
      vState.readerZoomRatios[imageSer] = ratio;
    }
  }

  // 点击中间
  Future<void> handOnTapCent() async {
    if (vState.viewMode == ViewMode.topToBottom && vState.isScrolling) {
      return;
    }
    // 工具栏显隐是最频繁的阅读器交互，用 selection 轻点而非 impact。
    await vibrateUtil.selection();

    // android会有抖动
    if (GetPlatform.isIOS) {
      if (!vState.showBar) {
        unsetFullscreen();
        vState.showBar = !vState.showBar;
      } else {
        // hide
        vState.showBar = !vState.showBar;
        // Native bars animate out with the status bar; the Flutter bars
        // finish their own transition first.
        if (NativeNavigationBridge.enabled.value) {
          syncFullscreen();
        } else {
          400.milliseconds.delay(syncFullscreen);
        }
      }
    } else {
      vState.showBar = !vState.showBar;
    }

    update([idViewBar]);
  }

  static int _liveReaders = 0;

  bool get _wantsFullscreen {
    final size =
        WidgetsBinding.instance.platformDispatcher.implicitView?.physicalSize ??
            Size.zero;
    return _ehSettingService.viewFullscreen ||
        _ehSettingService.readerFillsScreen(size);
  }

  void setFullscreen() {
    if (isClosed) {
      return;
    }
    if (_wantsFullscreen) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
      );
    } else {
      unsetFullscreen();
    }
  }

  /// iOS shows the system bars together with the reader bars.
  void syncFullscreen() {
    if (GetPlatform.isIOS && vState.showBar) {
      return;
    }
    setFullscreen();
  }

  Future<void> unsetFullscreen() async {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
  }

  void changePage(
    int page, {
    Duration duration = const Duration(milliseconds: 200),
    bool? animate,
  }) {
    if (isClosed || vState.pageCount == 0) {
      return;
    }
    final target = page.clamp(0, vState.pageCount - 1).toInt();
    final animated = animate ?? _ehSettingService.turnPageAnimations;
    if (vState.viewMode == ViewMode.topToBottom) {
      if (!itemScrollController.isAttached) {
        return;
      }
      if (animated) {
        itemScrollController.scrollTo(
            index: target, duration: duration, curve: Curves.ease);
      } else {
        itemScrollController.jumpTo(index: target);
      }
      return;
    }

    final paired = vState.columnMode != ViewColumnMode.single;
    final usesPreload = paired && vState.bookFolded ||
        (paired
            ? pageViewType == PageViewType.preloadPageView ||
                pageViewType == PageViewType.extendedImageGesturePageView
            : pageViewType == PageViewType.preloadPageView ||
                pageViewType == PageViewType.preloadPhotoView);
    if (usesPreload) {
      if (!preloadPageController.hasClients) return;
      if (animated) {
        preloadPageController.animateToPage(target,
            duration: duration, curve: Curves.ease);
      } else {
        preloadPageController.jumpToPage(target);
      }
    } else if (!paired &&
        pageViewType == PageViewType.extendedImageGesturePageView) {
      if (!extendedPageController.hasClients) return;
      if (animated) {
        extendedPageController.animateToPage(target,
            duration: duration, curve: Curves.ease);
      } else {
        extendedPageController.jumpToPage(target);
      }
    } else {
      if (!pageController.hasClients) return;
      if (animated) {
        pageController.animateToPage(target,
            duration: duration, curve: Curves.ease);
      } else {
        pageController.jumpToPage(target);
      }
    }
  }

  Future<void> tapLeft() async {
    logger.t('${vState.viewMode} tap left');
    final enableAnimate = _ehSettingService.turnPageAnimations;
    vState.fade = false;

    // if (vState.viewMode == ViewMode.LeftToRight && vState.pageIndex > 0) {
    //   final toPage = vState.pageIndex - 1;
    //   changePage(toPage);
    // } else if (vState.viewMode == ViewMode.rightToLeft &&
    //     vState.pageIndex < vState.filecount) {
    //   final toPage = vState.pageIndex + 1;
    //   changePage(toPage);
    // } else if (vState.viewMode == ViewMode.topToBottom &&
    //     itemScrollController.isAttached &&
    //     !vState.isScrolling &&
    //     vState.pageIndex > 0) {
    //   logger.t('${vState.minImageIndex}');
    //   itemScrollController.scrollTo(
    //     index: vState.minImageIndex - 1,
    //     duration: const Duration(milliseconds: 200),
    //     curve: Curves.ease,
    //   );
    // }

    if (vState.viewMode == ViewMode.leftToRight) {
      toPrev();
    } else if (vState.viewMode == ViewMode.rightToLeft) {
      toNext();
    } else if (vState.viewMode == ViewMode.topToBottom) {
      if (itemScrollController.isAttached && !vState.isScrolling) {
        toPrev();
      }
    }
  }

  Future<void> tapRight() async {
    logger.t('${vState.viewMode} tap right');
    vState.fade = false;
    // if (vState.viewMode == ViewMode.LeftToRight &&
    //     vState.pageIndex < vState.filecount) {
    //   final toPage = vState.pageIndex + 1;
    //   changePage(toPage);
    // } else if (vState.viewMode == ViewMode.rightToLeft &&
    //     vState.pageIndex > 0) {
    //   final toPage = vState.pageIndex - 1;
    //   changePage(toPage);
    // } else if (vState.viewMode == ViewMode.topToBottom &&
    //     itemScrollController.isAttached &&
    //     !vState.isScrolling &&
    //     vState.pageIndex < vState.filecount) {
    //   itemScrollController.scrollTo(
    //     index: vState.minImageIndex + 1,
    //     duration: const Duration(milliseconds: 200),
    //     curve: Curves.ease,
    //   );
    // }

    if (vState.viewMode == ViewMode.leftToRight) {
      toNext();
    } else if (vState.viewMode == ViewMode.rightToLeft) {
      toPrev();
    } else if (vState.viewMode == ViewMode.topToBottom &&
        itemScrollController.isAttached &&
        !vState.isScrolling) {
      toNext();
    }
  }

  void toNext() {
    if (vState.viewMode == ViewMode.topToBottom &&
        itemScrollController.isAttached &&
        !vState.isScrolling &&
        vState.pageIndex < vState.fileCount - 1) {
      itemScrollController.scrollTo(
        index: vState.minImageIndex + 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease,
      );
    } else if (vState.pageIndex < vState.pageCount - 1) {
      final toPage = vState.pageIndex + 1;
      changePage(toPage);
    }
  }

  void toPrev() {
    if (vState.viewMode == ViewMode.topToBottom &&
        itemScrollController.isAttached &&
        !vState.isScrolling &&
        vState.pageIndex > 0) {
      itemScrollController.scrollTo(
        index: vState.minImageIndex - 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease,
      );
    } else if (vState.pageIndex > 0) {
      final toPage = vState.pageIndex - 1;
      changePage(toPage);
    }
  }

  void handOnSliderChangedEnd(double value) {
    final curIndex = vState.currentItemIndex;
    jumpToPage(value.round());
    if ((value.round() - curIndex).abs() > 20) {
      Future.delayed(const Duration(milliseconds: 200))
          .then((value) => thumbScrollTo());
    }
  }

  void jumpToPage(int index) {
    vState.currentItemIndex = vState.pagination.clampImage(index);
    if (vState.viewMode != ViewMode.topToBottom) {
      // pageControllerCallBack(() => pageController.jumpToPage(vState.pageIndex),
      //     () => extendedPageController.jumpToPage(vState.pageIndex));
      changePage(vState.pageIndex, animate: false);
    } else {
      itemScrollController.jumpTo(index: vState.currentItemIndex);
      update([idViewTopBar]);
    }
    // Picking the other image in the same spread does not emit onPageChanged.
    _setPageSliderValue(updateSlider: true);
  }

  void handOnSliderChanged(double value) {
    vState.sliderValue = value;
    update([idViewPageSlider]);

    if (vState.syncThumbList) {
      thumbScrollTo(index: value.round());
    }
  }

  void tapShare(BuildContext context) {
    final ser = vState.currentItemIndex + 1;
    if (vState.loadFrom == LoadFrom.gallery) {
      logger.d('share networkFile $ser');
      final GalleryImage? p = vState.imageMap?[ser];
      logger.d('p:\n${p?.toJson()}');
      showShareActionSheet(
        context,
        imageUrl: p?.imageUrl,
        origImageUrl: p?.originImageUrl,
        filePath: p?.filePath,
        gid: vState.gid,
        ser: ser,
        filename: p?.filename,
      );
    } else {
      logger.d('share localFile');
      showShareActionSheet(
        context,
        isLocal: true,
        filePath: vState.imagePathList[vState.currentItemIndex],
        gid: vState.gid,
        ser: ser,
      );
    }
  }

  void tapSave(BuildContext context) {
    final ser = vState.currentItemIndex + 1;
    if (vState.loadFrom == LoadFrom.gallery) {
      logger.d('save networkFile ser');
      final GalleryImage? p = vState.imageMap?[ser];
      logger.d('p:\n${p?.toJson()}');
      showSaveActionSheet(
        context,
        imageUrl: p?.imageUrl,
        origImageUrl: p?.originImageUrl,
        filePath: p?.filePath,
        tempPath: p?.tempPath,
        cacheKey: p?.cacheKey,
        originalCacheKey: p?.getCacheKey(p.originImageUrl ?? ''),
        gid: vState.gid,
        ser: ser,
        filename: p?.filename,
      );
    } else {
      logger.d('save localFile');
      showSaveActionSheet(
        context,
        isLocal: true,
        filePath: vState.imagePathList[vState.currentItemIndex],
        gid: vState.gid,
        ser: ser,
      );
    }
  }

  Future tapAutoRead(BuildContext context, {bool setInv = true}) async {
    // logger.d('tap autoRead');

    if (!vState.autoRead) {
      await _setAutoReadInv(context, setInv: setInv);
      update([idAutoReadIcon]);
      _startAutoRead();
    } else {
      cancelAutoRead();
    }
  }

  Future<void> longTapAutoRead(BuildContext context) async {
    await _setAutoReadInv(context);
    _startAutoRead();
  }

  Future<void> _setAutoReadInv(
    BuildContext context, {
    bool setInv = true,
  }) async {
    final initIndex = EHConst.invList
        .indexWhere((int element) => element == _ehSettingService.turnPageInv);
    final int? inv = setInv
        ? await _showAutoReadInvPicker(
            context,
            EHConst.invList,
            initIndex: initIndex,
          )
        : _ehSettingService.turnPageInv;

    if (inv != null) {
      _ehSettingService.turnPageInv = inv;
      vState.autoRead = !vState.autoRead;
    }
  }

  /// Starts auto reading every [interval] milliseconds, restarting a running
  /// timer so the new interval applies at once.
  void startAutoReadWithInterval(int interval) {
    _ehSettingService.turnPageInv = interval;
    autoNextTimer?.cancel();
    vState.autoRead = true;
    update([idAutoReadIcon]);
    _startAutoRead();
  }

  Future<void> pickAutoReadInterval(BuildContext context) async {
    final initIndex = EHConst.invList
        .indexWhere((int element) => element == _ehSettingService.turnPageInv);
    final inv = await _showAutoReadInvPicker(context, EHConst.invList,
        initIndex: initIndex < 0 ? null : initIndex);
    if (inv != null) {
      startAutoReadWithInterval(inv);
    }
  }

  Future<int?> _showAutoReadInvPicker(BuildContext context, List<int> invList,
      {int? initIndex}) async {
    int selIndex = initIndex ?? 0;

    final scrollController = FixedExtentScrollController(initialItem: selIndex);

    final List<Widget> favPickerList =
        List<Widget>.from(invList.map((int e) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('${e / 1000}'),
              ],
            ))).toList();

    return showCupertinoDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return EhAlertDialog(
          title: const Text('Auto page interval'),
          content: Container(
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 150,
                  child: CupertinoPicker(
                    scrollController: scrollController,
                    itemExtent: 30,
                    onSelectedItemChanged: (int index) {
                      selIndex = index;
                    },
                    children: favPickerList,
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            CupertinoDialogAction(
              child: Text(L10n.of(context).cancel),
              onPressed: () {
                Get.back();
              },
            ),
            CupertinoDialogAction(
              child: Text(L10n.of(context).ok),
              onPressed: () {
                // 返回数据
                Get.back(result: invList[selIndex]);
              },
            ),
          ],
        );
      },
    );
  }

  void cancelAutoRead() {
    WakelockPlus.disable();
    vState.autoRead = false;
    vState.lastAutoNextSer = null;
    autoNextTimer?.cancel();
    update([idAutoReadIcon]);
  }

  final debNextPage = Debouncing(duration: const Duration(seconds: 1));

  void _startAutoRead() {
    WakelockPlus.enable();
    final duration = Duration(milliseconds: _ehSettingService.turnPageInv);
    autoNextTimer = Timer.periodic(duration, (timer) {
      _autoTunToPage();
    });
  }

  Future<void> onLoadCompleted(int ser) async {
    vState.loadCompleMap[ser] = true;
    await Future.delayed(const Duration(milliseconds: 100));

    if (vState.autoRead && !(autoNextTimer?.isActive ?? false)) {
      _startAutoRead();
    }
  }

  /// 竖屏阅读下页码变化的监听
  void handItemPositionsChange(Iterable<ItemPosition> positions) {
    _continuousPositionTimer?.cancel();
    if (isClosed || vState.viewMode != ViewMode.topToBottom) return;
    final visible = positions
        .where((item) => item.itemLeadingEdge < 1 && item.itemTrailingEdge > 0)
        .toList();
    int min;
    int max;
    if (visible.isNotEmpty) {
      // Determine the first visible item by finding the item with the
      // smallest trailing edge that is greater than 0.  i.e. the first
      // item whose trailing edge in visible in the viewport.
      min = visible
          .where((ItemPosition position) => position.itemTrailingEdge > 0)
          .reduce((ItemPosition min, ItemPosition position) =>
              position.itemTrailingEdge < min.itemTrailingEdge ? position : min)
          .index;
      // Determine the last visible item by finding the item with the
      // greatest leading edge that is less than 1.  i.e. the last
      // item whose leading edge in visible in the viewport.
      max = visible
          .where((ItemPosition position) => position.itemLeadingEdge < 1)
          .reduce((ItemPosition max, ItemPosition position) =>
              position.itemLeadingEdge > max.itemLeadingEdge ? position : max)
          .index;

      vState.tempIndex = (min + max) ~/ 2;
      // logger.d('max $max  min $min tempIndex ${vState.tempIndex}');

      vState.minImageIndex = min;
      vState.maxImageIndex = max;

      // logger.d('${positions.elementAt(index).itemLeadingEdge} ');
      if (vState.tempIndex != vState.currentItemIndex &&
          vState.conditionItemIndex) {
        // logger.d('${vState.tempIndex} ${vState.currentItemIndex}');
        _continuousPositionTimer = Timer(const Duration(milliseconds: 200), () {
          if (isClosed ||
              vState.viewMode != ViewMode.topToBottom ||
              !vState.conditionItemIndex) {
            return;
          }
          vState.currentItemIndex = vState.tempIndex;
          vState.sliderValue = vState.currentItemIndex / 1.0;
          update([idViewTopBar, idViewPageSlider]);
          if (vState.syncThumbList) {
            thumbScrollTo();
          }
        });
      }
    }
    // logger.i('First Item: ${min ?? ''}\nLast Item: ${max ?? ''}');
  }

  void handThumbPositionsChange(Iterable<ItemPosition> positions) {
    if (isClosed) return;
    final visible = positions
        .where((item) => item.itemLeadingEdge < 1 && item.itemTrailingEdge > 0)
        .toList();
    int? min;
    int? max;
    if (visible.isNotEmpty) {
      min = visible
          .where((ItemPosition position) => position.itemTrailingEdge > 0)
          .reduce((ItemPosition min, ItemPosition position) =>
              position.itemTrailingEdge < min.itemTrailingEdge ? position : min)
          .index;
      max = visible
          .where((ItemPosition position) => position.itemLeadingEdge < 1)
          .reduce((ItemPosition max, ItemPosition position) =>
              position.itemLeadingEdge > max.itemLeadingEdge ? position : max)
          .index;

      final centIndex = (min + max) ~/ 2;
      if (vState.centThumbIndex != centIndex) {
        vState.minThumbIndex = min;
        vState.maxThumbIndex = max;
        vState.centThumbIndex = centIndex;
      }
    }
  }

  final thrThumbScrollTo =
      Throttling(duration: const Duration(milliseconds: 200));

  void thumbScrollTo({int? index}) {
    if (isClosed || !thumbScrollController.isAttached) return;
    final indexRange = vState.maxThumbIndex - vState.minThumbIndex;
    final toIndex = index ?? vState.currentItemIndex;
    if (toIndex < vState.fileCount - indexRange - 1) {
      thrThumbScrollTo.throttle(() {
        if (isClosed || !thumbScrollController.isAttached) return;
        thumbScrollController.scrollTo(
          index: toIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.ease,
        );
      });
    }
  }

  Future<void> _autoTunToPage() async {
    if (vState.pageIndex >= vState.pageCount - 1) {
      return;
    }

    if (vState.autoRead) {
      if (vState.viewMode == ViewMode.topToBottom &&
          itemScrollController.isAttached) {
        logger.d('t2d minImageIndex:${vState.minImageIndex + 1}');
        final minIndex = vState.minImageIndex;
        final minImageSer = minIndex + 1;
        if (!(vState.loadCompleMap[minImageSer] ?? false)) {
          autoNextTimer?.cancel();
        }

        vState.lastAutoNextSer = minImageSer + 1;
        if (!(vState.loadCompleMap[vState.lastAutoNextSer] ?? false)) {
          autoNextTimer?.cancel();
        }

        if (vState.loadCompleMap[minImageSer] ?? false) {
          changePage(minIndex + 1);
        }
      } else {
        changePage(vState.pageIndex + 1);
      }
    }
  }

  Future<void> _autoTunToPage_Old() async {
    if (vState.pageIndex >= vState.pageCount - 1) {
      return;
    }

    if (vState.autoRead) {
      if (vState.viewMode == ViewMode.topToBottom &&
          itemScrollController.isAttached) {
        logger.d('trd minImageIndex:${vState.minImageIndex + 1}');
        final _minIndex = vState.minImageIndex;
        final _minImageSer = _minIndex + 1;
        if (!(vState.loadCompleMap[_minImageSer] ?? false)) {
          autoNextTimer?.cancel();
        }

        vState.lastAutoNextSer = _minImageSer + 1;
        if (!(vState.loadCompleMap[vState.lastAutoNextSer] ?? false)) {
          autoNextTimer?.cancel();
        }

        if (vState.loadCompleMap[_minImageSer] ?? false) {
          // itemScrollController.scrollTo(
          //   index: _minIndex + 1,
          //   duration: const Duration(milliseconds: 200),
          //   curve: Curves.ease,
          // );
          changePage(_minIndex + 1);
        }
      } else {
        logger.d('horizontal next page ${vState.pageIndex + 1}');

        if (vState.columnMode == ViewColumnMode.single) {
          // 下一张图片的加载完成标志 如果没有完成 取消翻页定时器
          vState.lastAutoNextSer = vState.currentItemIndex + 2;

          logger.d('cur ${vState.loadCompleMap[vState.currentItemIndex]}  '
              'nex ${vState.loadCompleMap[vState.currentItemIndex + 1]}');

          if (!(vState.loadCompleMap[vState.lastAutoNextSer] ?? false)) {
            autoNextTimer?.cancel();
          }
          // 翻页
          pageControllerCallBack(
            () {
              if (pageController.positions.isNotEmpty) {
                pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut);
              }
            },
            () {
              if (extendedPageController.positions.isNotEmpty) {
                extendedPageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut);
              }
            },
            onPreviewPageController: () {
              if (preloadPageController.positions.isNotEmpty) {
                preloadPageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut);
              }
            },
          );
        } else {
          // 双页阅读
          logger.d('双页阅读 自动翻页');
          final int serLeftNext = vState.serFirst + 2;
          if (vState.fileCount > serLeftNext) {
            if (serLeftNext > 0 &&
                !(vState.loadCompleMap[serLeftNext] ?? false)) {
              autoNextTimer?.cancel();
            }
            final rigthNextComple =
                vState.loadCompleMap[serLeftNext + 1] ?? false;
            if (!rigthNextComple) {
              autoNextTimer?.cancel();
            }
          }

          final int serLeftCur = vState.serFirst;
          if ((vState.loadCompleMap[serLeftCur] ?? false) &&
              (vState.loadCompleMap[serLeftCur + 1] ?? false)) {
            // 翻页
            pageControllerCallBack(
              () {
                if (pageController.positions.isNotEmpty) {
                  pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut);
                }
              },
              () {
                if (extendedPageController.positions.isNotEmpty) {
                  extendedPageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut);
                }
              },
              onPreviewPageController: () {
                if (preloadPageController.positions.isNotEmpty) {
                  preloadPageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut);
                }
              },
            );
          }
        }
      }

      // if (vState.columnMode != ViewColumnMode.single) {
      //   vState.lastAutoNextSer = vState.serStart;
      // }
    }
  }

  static Timer? debounceTimer;

  // 防抖函数
  void vvDebounce(
    Function? doSomething, {
    required String id,
    Duration durationTime = const Duration(milliseconds: 200),
  }) {
    if (debounceTimer?.isActive ?? false) {
      logger.t('timer.cancel');
      debounceTimer?.cancel();
    }

    debounceTimer = Timer(durationTime, () {
      loggerTime.v('func.call');
      doSomething?.call();
      debounceTimer = null;
    });
  }

  Future<void> handOnViewModeChanged(ViewMode val) async {
    _continuousPositionTimer?.cancel();
    final itemIndex = vState.currentItemIndex;
    _renderedColumnMode = vState.columnMode;
    resetPageController();
    final generation = _paginationGeneration;
    // The const page widget can survive its parent's rebuild. Rebind its
    // controller and refresh the thumbnail direction even on a re-selection.
    update([
      idImagePageView,
      idSlidePage,
      idThumbnailListView,
      idViewBottomBar,
      idIconBar,
      idViewTopBar,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isClosed || generation != _paginationGeneration) return;
      vState.currentItemIndex = itemIndex;
      changePage(vState.pageIndex, animate: false);
    });
  }

  void switchSyncThumb() {
    vState.syncThumbList = !vState.syncThumbList;
    if (vState.syncThumbList) {
      thumbScrollTo();
    }
    update([idThumbnailListView]);
  }

  final Map<String, bool> _loadExtendedImageRectComplets = {};

  void handOnLoadCompletExtendedImageRect({required String url}) {
    Future.delayed(const Duration(milliseconds: 50)).then(
      (_) {
        if (!(_loadExtendedImageRectComplets[url] ?? false)) {
          logger.d('onLoadComplet $url');

          _loadExtendedImageRectComplets[url] = true;
          update([idThumbnailListView]);
        }
      },
    );
  }

  void pageControllerCallBack(
    Function onPageController,
    Function onExtendedPageController, {
    Function? onPreviewPageController,
  }) {
    switch (pageViewType) {
      case PageViewType.photoView:
        onPageController.call();
        break;
      case PageViewType.preloadPageView:
        onPreviewPageController?.call();
        break;
      default:
        onExtendedPageController.call();
    }
  }

  void scaleUp() {}

  void scaleDown() {}

  void scaleReset() {}

  Future<void> downloadImage({
    required int ser,
    required String url,
    bool reset = false,
    onError(e)?,
  }) async {
    logger.d('downloadImage $url');
    final savePath = path.join(Global.tempPath, 'ViewTemp', vState.gid, '$ser');

    try {
      await ehDownload(
        savePath: savePath,
        url: url,
        progressCallback: (int count, int total) {
          final process = count / total;
          // loggerSimple.d('ViewTemp download file, $ser $process');
          // _galleryPageController.uptImageProcess(ser, process);
          _galleryPageController?.uptImageBySer(
              ser: ser,
              imageCallback: (image) {
                return image.copyWith(downloadProcess: process.oN);
              });
          update(['${idProcess}_$ser']);
        },
        onDownloadComplete: () {
          _galleryPageController?.uptImageBySer(
              ser: ser,
              imageCallback: (image) => image.copyWith(
                    tempPath: savePath.oN,
                    completeCache: true.oN,
                    changeSource: false.oN,
                  ));
        },
      );
    } catch (e) {
      onError?.call(e);
      // logger.e('$e');
      // logger.e('${e.runtimeType}');
      // _galleryPageController.uptImageBySer(
      //     ser: ser, imageCallback: (image) => image.copyWith(errorInfo: '$e'));
      // update(['${idProcess}_$ser']);
    }
  }
}
