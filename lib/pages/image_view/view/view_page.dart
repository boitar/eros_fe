import 'package:archive_async/archive_async.dart';
import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/debug/offline_acceptance.dart';
import 'package:eros_fe/extension.dart';
import 'package:eros_fe/pages/image_view/view/view_widget.dart';
import 'package:eros_fe/utils/logger.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../common.dart';
import '../controller/view_controller.dart';
import '../controller/view_state.dart';
import 'image_list_view.dart';
import 'image_page_view.dart';
import 'image_page_view_ex.dart';
import 'reader_chrome.dart';
import 'reader_layout.dart';
import 'view_image.dart';

typedef DoubleClickAnimationListener = void Function();

class ViewRepository {
  ViewRepository({
    this.index = 0,
    this.loadType = LoadFrom.gallery,
    this.files,
    this.asyncArchives,
    this.galleryControllerTag,
    required this.gid,
  });

  final int index;
  final List<String>? files;
  final String gid;
  final String? galleryControllerTag;
  final LoadFrom loadType;
  final List<AsyncArchiveFile>? asyncArchives;
}

class ViewPage extends StatefulWidget {
  const ViewPage({super.key});

  @override
  State<ViewPage> createState() => _ViewPageState();
}

class _ViewPageState extends State<ViewPage> with TickerProviderStateMixin {
  final ViewExtController controller = Get.find();

  ViewExtState get vState => controller.vState;

  @override
  void initState() {
    super.initState();
    logger.t('ViewPage initState');
  }

  @override
  void dispose() {
    if (Get.isRegistered<ViewExtController>() &&
        identical(Get.find<ViewExtController>(), controller)) {
      Get.delete<ViewExtController>(force: true);
    }
    super.dispose();
    logger.t('ViewPage dispose');
  }

  @override
  Widget build(BuildContext context) {
    Widget body = const ViewKeyboardListener(
      child: CupertinoTheme(
        data: CupertinoThemeData(
          brightness: Brightness.dark,
        ),
        child: ImagePlugins(
          child: ImageGestureDetector(
            child: ImageView(),
          ),
        ),
      ),
    );
    if (offlineAcceptanceEnabled &&
        const bool.fromEnvironment('EROS_DUO_ACCEPTANCE')) {
      body = Stack(
        fit: StackFit.expand,
        children: [
          body,
          Positioned(
            left: 0,
            top: 0,
            child: IgnorePointer(
              child: GetBuilder<ViewExtController>(
                id: idViewTopBar,
                builder: (logic) {
                  final environment = AdaptiveEnvironment.maybeOf(context);
                  return Semantics(
                    container: true,
                    identifier: 'offline-duo-reader-probe',
                    label: 'index=${vState.currentItemIndex};'
                        'count=${vState.fileCount};page=${vState.pageIndex};'
                        'column=${vState.columnMode.name};'
                        'preference=${vState.ehSettingService.readerColumnPreference.name};'
                        'direction=${vState.viewMode.name};'
                        'interval=${vState.showPageInterval};'
                        'backend=${logic.pageViewType.name};'
                        'ignoreScrollingPointer=${logic.extendedPageController.shouldIgnorePointerWhenScrolling};'
                        'surface=${vState.surfacePreference.name};'
                        'layout=${environment?.layoutKind.name};'
                        'size=${environment?.size.width}x${environment?.size.height};'
                        'divisions=${environment?.activeDivisionRegions.map((region) => region.frame).join("|")};'
                        'layoutVersion=${environment?.layoutVersion};'
                        'generation=${logic.paginationGeneration}',
                    child: const SizedBox(width: 1, height: 1),
                  );
                },
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 2,
            child: IgnorePointer(
              child: ValueListenableBuilder<Iterable<ItemPosition>>(
                valueListenable: controller.itemPositionsListener.itemPositions,
                builder: (_, positions, __) {
                  final visible = positions
                      .where((item) =>
                          item.itemLeadingEdge < 1 && item.itemTrailingEdge > 0)
                      .toList()
                    ..sort((a, b) => a.index.compareTo(b.index));
                  return Semantics(
                    container: true,
                    identifier: 'offline-duo-scroll-probe',
                    label:
                        'items=${visible.map((item) => '${item.index}:${item.itemLeadingEdge}:${item.itemTrailingEdge}').join("|")};'
                        'viewport=${vState.viewportSize?.width}x${vState.viewportSize?.height}',
                    child: const SizedBox(width: 1, height: 1),
                  );
                },
              ),
            ),
          ),
        ],
      );
    }

    body = ReaderNativeChrome(child: body);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: body,
    );
  }
}

class ViewKeyboardListener extends StatefulWidget {
  const ViewKeyboardListener({required this.child, super.key});

  final Widget child;

  @override
  State<ViewKeyboardListener> createState() => _ViewKeyboardListenerState();
}

class _ViewKeyboardListenerState extends State<ViewKeyboardListener> {
  final ViewExtController controller = Get.find();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: (KeyEvent event) async {
        if (event is! KeyDownEvent) {
          return;
        }

        // 按键对应的事件
        Map<LogicalKeyboardKey, Function> actionMap = {
          LogicalKeyboardKey.arrowLeft: controller.tapLeft,
          LogicalKeyboardKey.arrowUp: controller.toPrev,
          LogicalKeyboardKey.arrowRight: controller.tapRight,
          LogicalKeyboardKey.arrowDown: controller.toNext,
          LogicalKeyboardKey.pageUp: controller.toPrev,
          LogicalKeyboardKey.pageDown: controller.toNext,
          LogicalKeyboardKey.space: controller.handOnTapCent,
          LogicalKeyboardKey.enter: controller.handOnTapCent,
          LogicalKeyboardKey.escape: Get.back,
          LogicalKeyboardKey.backspace: Get.back,
          LogicalKeyboardKey.equal: controller.scaleUp,
          LogicalKeyboardKey.minus: controller.scaleDown,
          LogicalKeyboardKey.digit0: controller.scaleReset,
          LogicalKeyboardKey.keyP: controller.switchColumnMode,
          LogicalKeyboardKey.keyT: controller.switchShowThumbList,
          LogicalKeyboardKey.keyA: () =>
              controller.tapAutoRead(context, setInv: false),
        };

        logger.t('logicalKey: ${event.logicalKey}');
        actionMap[event.logicalKey]?.call();
      },
      child: widget.child,
    );
  }
}

class ImageView extends StatefulWidget {
  const ImageView({super.key});

  @override
  State<ImageView> createState() => _ImageViewState();
}

class _ImageViewState extends State<ImageView> {
  int _viewportGeneration = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final adaptive = AdaptiveEnvironment.maybeOf(context);
        final canUseDoublePage = adaptive?.canUseReaderDoublePage;
        final generation = ++_viewportGeneration;
        if (size.isFinite) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                generation == _viewportGeneration &&
                Get.isRegistered<ViewExtController>()) {
              Get.find<ViewExtController>().updateViewport(
                size,
                canUseDoublePage: canUseDoublePage,
                bookFolded: adaptive?.isBookFolded ?? false,
              );
            }
          });
        }
        return GetBuilder<ViewExtController>(
          id: idImagePageView,
          builder: (logic) {
            logger.t('build ImageView');
            switch (logic.vState.viewMode) {
              case ViewMode.topToBottom:
                return const ImageListView();
              case ViewMode.leftToRight:
                return const ImagePageView();
              case ViewMode.rightToLeft:
                return const ImagePageView(reverse: true);
              default:
                return const ImagePhotoView();
            }
          },
        );
      },
    );
  }
}

PhotoViewScaleState listViewScaleStateCycle(PhotoViewScaleState actual) {
  logger.d('actual $actual');
  switch (actual) {
    case PhotoViewScaleState.initial:
      return PhotoViewScaleState.covering;
    case PhotoViewScaleState.covering:
      return PhotoViewScaleState.originalSize;
    case PhotoViewScaleState.originalSize:
      return PhotoViewScaleState.initial;
    case PhotoViewScaleState.zoomedIn:
    case PhotoViewScaleState.zoomedOut:
      return PhotoViewScaleState.initial;
    default:
      return PhotoViewScaleState.initial;
  }
}

class DoublePageView extends StatefulWidget {
  const DoublePageView({
    super.key,
    required this.pageIndex,
  });

  final int pageIndex;

  @override
  State<DoublePageView> createState() => _DoublePageViewState();
}

class _DoublePageViewState extends State<DoublePageView> {
  ViewExtController get controller => Get.find();
  ViewExtState get vState => controller.vState;

  double _aspectRatio(int ser) {
    final known = vState.imageSizeMap[ser];
    if (known != null && known.height > 0) return known.width / known.height;
    final image = vState.imageMap?[ser];
    if ((image?.imageHeight ?? 0) > 0 && (image?.imageWidth ?? 0) > 0) {
      return image!.imageWidth! / image.imageHeight!;
    }
    if ((image?.thumbHeight ?? 0) > 0 && (image?.thumbWidth ?? 0) > 0) {
      return image!.thumbWidth! / image.thumbHeight!;
    }
    return 3 / 4;
  }

  void _imageSizeChanged(int ser, Size size) {
    if (size.isEmpty || !size.isFinite || vState.imageSizeMap[ser] == size) {
      return;
    }
    vState.imageSizeMap[ser] = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
    vState.galleryPageController?.uptImageBySer(
      ser: ser,
      imageCallback: (image) => image.copyWith(
        imageWidth: size.width.oN,
        imageHeight: size.height.oN,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final environment = AdaptiveEnvironment.maybeOf(context) ??
        AdaptiveEnvironmentSnapshot.fromMediaQuery(context);
    final book = environment.isBookFolded;
    final images = vState.pagination.imagesForPage(widget.pageIndex);
    return ReaderSpreadLayout(
      environment: environment,
      reverse: vState.viewMode == ViewMode.rightToLeft,
      pages: [
        for (final index in images)
          ReaderSpreadPage(
            slot: (index +
                    (vState.columnMode == ViewColumnMode.evenLeft ? 1 : 0)) %
                2,
            aspectRatio: _aspectRatio(index + 1),
            child: Semantics(
              label: '${index + 1}/${vState.fileCount}',
              image: true,
              child: ViewImage(
                key: ValueKey('spread-image-${index + 1}'),
                imageSer: index + 1,
                enableDoubleTap: book,
                mode: book ? ExtendedImageMode.gesture : ExtendedImageMode.none,
                enableSlideOutPage: false,
                imageSizeChanged: (size) => _imageSizeChanged(index + 1, size),
              ),
            ),
          ),
      ],
    );
  }
}

///  显示顶栏 底栏 slider等
class ImagePlugins extends GetView<ViewExtController> {
  const ImagePlugins({
    super.key,
    required this.child,
  });

  final Widget child;

  ViewExtState get vState => controller.vState;

  @override
  Widget build(BuildContext context) {
    final nativeChrome = NativeNavigationScope.isEnabled(context);
    return GetBuilder<ViewExtController>(
      id: idViewBar,
      builder: (logic) {
        final environment = AdaptiveEnvironment.maybeOf(context) ??
            AdaptiveEnvironmentSnapshot.fromMediaQuery(context);
        final showInline = environment.isWide;
        final bottomHeight = nativeChrome
            ? ReaderDock.heightFor(thumbnails: vState.showThumbList)
            : (showInline ? 0 : kBottomBarHeight) +
                kSliderBarHeight +
                (vState.showThumbList ? kThumbListViewHeight : 0);
        vState.bottomBarHeight = bottomHeight;
        return Obx(() {
          final fillScreen =
              vState.ehSettingService.readerFillsScreen(environment.size);
          return _ReaderSystemUiSync(
            fillScreen: fillScreen,
            onChanged: controller.syncFullscreen,
            child: ReaderSurfaceLayout(
              environment: environment,
              preference: vState.surfacePreference,
              singlePage: vState.ehSettingService.readerColumnPreference ==
                  ReaderColumnPreference.single,
              showBars: vState.showBar,
              fillScreen: fillScreen,
              nativeChrome: nativeChrome,
              topBarHeight: nativeChrome ? 0 : kTopBarHeight,
              bottomBarHeight: bottomHeight,
              topBar: nativeChrome
                  ? const SizedBox.shrink()
                  : const ViewTopBar(),
              bottomBar:
                  nativeChrome ? const ReaderDock() : const ViewBottomBar(),
              content: child,
            ),
          );
        });
      },
    );
  }
}

/// Re-applies the system bars when rotation or the setting flips the fill.
class _ReaderSystemUiSync extends StatefulWidget {
  const _ReaderSystemUiSync({
    required this.fillScreen,
    required this.onChanged,
    required this.child,
  });

  final bool fillScreen;
  final VoidCallback onChanged;
  final Widget child;

  @override
  State<_ReaderSystemUiSync> createState() => _ReaderSystemUiSyncState();
}

class _ReaderSystemUiSyncState extends State<_ReaderSystemUiSync> {
  @override
  void didUpdateWidget(_ReaderSystemUiSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fillScreen != widget.fillScreen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onChanged();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 控制触摸手势事件
class ImageGestureDetector extends GetView<ViewExtController> {
  const ImageGestureDetector({
    super.key,
    required this.child,
  });
  final Widget child;

  static const lrRatio = 1 / 3;
  static const tbRatio = 1 / 5;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTapUp: (details) {
        // logger.d('${details.globalPosition} ${details.localPosition}');

        final globalPosition = details.localPosition;
        if (globalPosition.dx < context.width * (1 - lrRatio) &&
            globalPosition.dx > context.width * lrRatio) {
          if (globalPosition.dy < context.height * tbRatio) {
            controller.toPrev();
          } else if (globalPosition.dy > context.height * (1 - tbRatio)) {
            controller.toNext();
          } else {
            controller.handOnTapCent();
          }
        }

        if (globalPosition.dx < context.width * lrRatio) {
          controller.tapLeft();
        }

        if (globalPosition.dx > context.width * (1 - lrRatio)) {
          controller.tapRight();
        }
      },
      onDoubleTap: () {
        logger.d('onDoubleTap');
      },
      child: child,
    );
  }
}
