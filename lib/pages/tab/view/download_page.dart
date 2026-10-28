import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/adaptive/native_top_header.dart';
import 'package:eros_fe/common/controller/download_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/download_archiver_task_info.dart';
import 'package:eros_fe/pages/item/download_archiver_item.dart';
import 'package:eros_fe/pages/item/download_gallery_item.dart';
import 'package:eros_fe/pages/tab/controller/download_view_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/pages/tab/view/constants.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/store/db/entity/gallery_task.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/utils/logger.dart';
import 'package:eros_fe/utils/share_service.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:eros_fe/widget/segmented_rail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

const Color _kDefaultNavBarBorderColor = Color(0x4D000000);

const Border _kDefaultNavBarBorder = Border(
  bottom: BorderSide(
    color: _kDefaultNavBarBorderColor,
    width: 0.2, // One physical pixel.
    style: BorderStyle.solid,
  ),
);

class DownloadTab extends StatefulWidget {
  const DownloadTab({super.key});

  @override
  State<DownloadTab> createState() => _DownloadTabState();
}

class _DownloadTabState extends State<DownloadTab> {
  final DownloadViewController controller = Get.find();
  late PageController pageController;

  int get currIndex => controller.pageList.indexOf(controller.viewType);

  @override
  void initState() {
    super.initState();
    pageController = PageController(initialPage: currIndex);
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String _title = L10n.of(context).tab_download;

    final viewList = [
      const DownloadGalleryView(),
      const DownloadArchiverView(),
    ];

    final middle = GetPlatform.isMobile
        ? CupertinoSlidingSegmentedControl<DownloadType>(
            children: <DownloadType, Widget>{
              DownloadType.gallery: Text(
                L10n.of(context).tab_gallery,
                style: const TextStyle(fontSize: 14),
              ).marginSymmetric(horizontal: 6),
              DownloadType.archiver: Text(
                L10n.of(context).p_Archiver,
                style: const TextStyle(fontSize: 14),
              ).marginSymmetric(horizontal: 6),
            },
            groupValue: controller.viewType,
            onValueChanged: (DownloadType? value) {
              final toIndex =
                  controller.pageList.indexOf(value ?? DownloadType.gallery);
              pageController.animateToPage(toIndex,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.ease);
            },
          )
        : Text(L10n.of(context).download);

    final pages = PageView(
      key: const PageStorageKey<String>('download-pages'),
      controller: pageController,
      children: viewList,
      onPageChanged: (index) {
        setState(() {
          controller.viewType = controller.pageList[index];
        });
      },
    );

    final native = NativeNavigationScope.isEnabled(context);
    return Obx(() {
      final settings = Get.find<EhSettingService>();
      void select(int index) => pageController.animateToPage(
            index,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
      if (native) {
        return NativeNavigationPage(
          tabId: EHRoutes.download,
          chrome: NativePageChrome(
            title: _title,
            actions: [
              ...Get.find<TabHomeController>().nativeHiddenTabActions,
              if (!kReleaseMode)
                NativeNavigationAction(
                  id: 'export',
                  title: 'Import & Export',
                  symbol: 'arrow.up.arrow.down',
                  onPressed: _showExportDialog,
                ),
            ],
          ),
          child: DownloadNativeScaffold(
            rail: SegmentedRail(
              compact: true,
              selectedIndex: currIndex,
              pageController: pageController,
              followSystemTransparency:
                  settings.liquidGlassFollowSystemTransparency,
              items: [
                LiquidGlassRailCategory(
                  id: 'gallery',
                  title: L10n.of(context).tab_gallery,
                  onTap: () => select(0),
                ),
                LiquidGlassRailCategory(
                  id: 'archiver',
                  title: L10n.of(context).p_Archiver,
                  onTap: () => select(1),
                ),
              ],
            ),
            child: pages,
          ),
        );
      }
      if (settings.liquidGlass && LiquidGlassPlatform.isSupported) {
        final layout = settings.liquidGlassTopBarLayout;
        final safeTop = MediaQuery.paddingOf(context).top;
        return DownloadGlassScaffold(
          header: DownloadGlassHeader(
            title: _title,
            galleryLabel: L10n.of(context).tab_gallery,
            archiverLabel: L10n.of(context).p_Archiver,
            safeTop: safeTop,
            layout: layout,
            selectedIndex: currIndex,
            pageController: pageController,
            followSystemTransparency:
                settings.liquidGlassFollowSystemTransparency,
            onSelected: select,
            onExport: !kReleaseMode ? _showExportDialog : null,
          ),
          child: pages,
        );
      }
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          padding: const EdgeInsetsDirectional.only(end: 16),
          middle: middle,
          trailing: !kReleaseMode
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CupertinoButton(
                      minimumSize: const Size(40, 40),
                      padding: const EdgeInsets.all(0),
                      onPressed: _showExportDialog,
                      child: const Icon(
                        CupertinoIcons.arrow_up_arrow_down_square_fill,
                        size: 28,
                      ),
                    ),
                  ],
                )
              : null,
        ),
        child: pages,
      );
    });
  }

  Future<void> _showExportDialog() async {
    final pageContext = Get.context!;
    return showCupertinoDialog<void>(
      context: pageContext,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return EhAlertDialog(
          title: const Text('Import & Export'),
          content: const Text('Import and Export download task'),
          actions: [
            CupertinoDialogAction(
              onPressed: () async {
                final origin = ShareService.positionOrigin(context);
                Get.back();
                await ShareService.waitForModalDismissal();
                if (pageContext.mounted) {
                  await controller.shareTaskInfoFile(
                      sharePositionOrigin: origin);
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FaIcon(FontAwesomeIcons.squareShareNodes)
                      .paddingOnly(right: 8),
                  const Text('Share '),
                ],
              ),
            ),
            CupertinoDialogAction(
              onPressed: () async {
                Get.back();
                controller.exportTaskInfoFile();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FaIcon(FontAwesomeIcons.fileArrowUp)
                      .paddingOnly(right: 8),
                  const Text('Export'),
                ],
              ),
            ),
            CupertinoDialogAction(
              onPressed: () async {
                Get.back();
                await controller.importTaskInfoFile();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FaIcon(FontAwesomeIcons.fileArrowDown)
                      .paddingOnly(right: 8),
                  const Text('Import'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Download under the native shell: the system navigation bar, then the same
/// segmented rail and soft edge as the other root tabs.
class DownloadNativeScaffold extends StatelessWidget {
  const DownloadNativeScaffold({
    super.key,
    required this.rail,
    required this.child,
  });

  final Widget rail;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final railHeight = topTabbarHeightFor(context);
    return CupertinoPageScaffold(
      child: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: MediaQuery.paddingOf(context).copyWith(
                    top: topInset + railHeight + 8,
                  ),
                ),
                child: child,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topInset + railHeight,
              child: NativeTopTabHeader(
                topInset: topInset,
                railHeight: railHeight,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: MediaQuery.paddingOf(context).left,
                    right: MediaQuery.paddingOf(context).right,
                  ),
                  child: rail,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DownloadGlassScaffold extends StatelessWidget {
  const DownloadGlassScaffold({
    super.key,
    required this.header,
    required this.child,
  });

  final DownloadGlassHeader header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final headerHeight = header.safeTop +
        header.layout.expandedHeight(MediaQuery.textScalerOf(context));
    return CupertinoPageScaffold(
      // Positioned children do not size a Stack. Keep the list viewport full
      // height without stretching the intrinsic-height header or scrim.
      child: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: MediaQuery.paddingOf(context).copyWith(
                    top: headerHeight + 12,
                  ),
                ),
                child: child,
              ),
            ),
            LiquidGlassTopScrim(safeTop: header.safeTop, layout: header.layout),
            header,
          ],
        ),
      ),
    );
  }
}

class DownloadGlassHeader extends StatelessWidget {
  const DownloadGlassHeader({
    super.key,
    required this.title,
    required this.galleryLabel,
    required this.archiverLabel,
    required this.safeTop,
    required this.layout,
    required this.selectedIndex,
    required this.onSelected,
    this.pageController,
    this.followSystemTransparency = true,
    this.onExport,
  });

  final String title;
  final String galleryLabel;
  final String archiverLabel;
  final double safeTop;
  final LiquidGlassTopBarLayout layout;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final PageController? pageController;
  final bool followSystemTransparency;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          LiquidGlassRail(
            title: title,
            safeTop: safeTop,
            layout: layout,
            selectedIndex: selectedIndex,
            compactCategories: true,
            pageController: pageController,
            followSystemTransparency: followSystemTransparency,
            fadeProgress: 0,
            categories: [
              LiquidGlassRailCategory(
                id: 'gallery',
                title: galleryLabel,
                onTap: () => onSelected(0),
              ),
              LiquidGlassRailCategory(
                id: 'archiver',
                title: archiverLabel,
                onTap: () => onSelected(1),
              ),
            ],
            trailing: [
              if (onExport != null)
                LiquidGlassRailAction(
                  icon: CupertinoIcons.arrow_up_arrow_down,
                  label: 'Import & Export',
                  onPressed: onExport!,
                ),
            ],
          ),
          if (layout == LiquidGlassTopBarLayout.twoRow)
            Positioned(
              top: safeTop,
              left: onExport == null ? 16 : 60,
              right: onExport == null ? 16 : 60,
              height: 44,
              child: Center(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: CupertinoDynamicColor.resolve(
                        CupertinoColors.label,
                        context,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
}

class DownloadArchiverView extends StatefulWidget {
  const DownloadArchiverView({super.key});

  @override
  State<DownloadArchiverView> createState() => _DownloadArchiverViewState();
}

class _DownloadArchiverViewState extends State<DownloadArchiverView>
    with AutomaticKeepAliveClientMixin {
  final DownloadViewController controller = Get.find();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SafeArea(
      key: const PageStorageKey<String>('download-archiver-list'),
      top: false,
      bottom: false,
      child: AnimatedList(
        key: controller.animatedArchiverListKey,
        padding: EdgeInsets.only(
          top: context.mediaQueryPadding.top,
          bottom: context.mediaQueryPadding.bottom,
        ),
        initialItemCount: controller.archiverTasks.length,
        itemBuilder: downloadArchiverItemBuilder,
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class DownloadGalleryView extends StatefulWidget {
  const DownloadGalleryView({super.key});

  @override
  State<DownloadGalleryView> createState() => _DownloadGalleryViewState();
}

class _DownloadGalleryViewState extends State<DownloadGalleryView>
    with AutomaticKeepAliveClientMixin {
  final DownloadController downloadController = Get.find();
  final DownloadViewController controller = Get.find();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<void>(
      future: downloadController.downloadInitialization,
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CupertinoActivityIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Failed to load download tasks'));
        }

        return Obx(() {
          // 读取 revision 建立响应式依赖。数据库快照读取完成后，
          // refreshGalleryList 会替换 key，AnimatedList 才会读取任务数量；
          // 后台完整性修复通过对应卡片的 GetBuilder 单独刷新。
          controller.galleryListRevision.value;
          return SafeArea(
            key: const PageStorageKey<String>('download-gallery-list'),
            top: false,
            bottom: false,
            child: AnimatedList(
              key: controller.animatedGalleryListKey,
              padding: EdgeInsets.only(
                top: context.mediaQueryPadding.top,
                bottom: context.mediaQueryPadding.bottom,
              ),
              initialItemCount: controller.galleryTasks.length,
              itemBuilder: downloadItemBuilder,
            ),
          );
        });
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

Widget downloadItemBuilder(
    BuildContext context, int taskIndex, Animation<double> animation) {
  return _buildAnimatedListItem(
    animation,
    child: _downloadItemBuilder(context, taskIndex),
  );
}

Widget downloadDelItemBuilder(
    BuildContext context, int taskIndex, Animation<double> animation) {
  return _buildDelAnimatedListItem(
    animation,
    child: _downloadItemBuilder(context, taskIndex),
  );
}

Widget downloadArchiverItemBuilder(
    BuildContext context, int taskIndex, Animation<double> animation) {
  return _buildAnimatedListItem(
    animation,
    child: _downloadArchiverItemBuilder(context, taskIndex),
  );
}

Widget downloadArchiverDelItemBuilder(
    BuildContext context, int taskIndex, Animation<double> animation) {
  return _buildDelAnimatedListItem(
    animation,
    child: _downloadArchiverItemBuilder(context, taskIndex),
  );
}

Widget _downloadItemBuilder(BuildContext context, int taskIndex) {
  final DownloadViewController controller = Get.find();
  if (controller.galleryTasks.length - 1 < taskIndex) {
    return const SizedBox.shrink();
  }

  final gid = controller.galleryTasks[taskIndex].gid;
  return GetBuilder<DownloadViewController>(
    id: '${idDownloadGalleryItem}_$gid',
    builder: (logic) {
      logger.t('rebuild DownloadGalleryItem_$gid');

      final GalleryTask taskInfo = logic.galleryTasks[taskIndex];
      final String? speed = logic.downloadSpeedMap[taskInfo.gid];
      final String? errInfo = logic.errInfoMap[taskInfo.gid];

      return DownloadGalleryItem(
        galleryTask: taskInfo,
        taskIndex: taskIndex,
        speed: speed,
        errInfo: errInfo,
      );
    },
  );
}

Widget _downloadArchiverItemBuilder(BuildContext context, int taskIndex) {
  final DownloadViewController controller = Get.find();
  if (controller.archiverTasks.length - 1 < taskIndex) {
    return const SizedBox.shrink();
  }

  final tag = controller.archiverTasks[taskIndex].tag;
  return GetBuilder<DownloadViewController>(
    id: '${idDownloadArchiverItem}_$tag',
    builder: (logic) {
      final DownloadArchiverTaskInfo archiveTaskInfo =
          logic.archiverTasks[taskIndex];
      return GestureDetector(
        onLongPress: () =>
            logic.onLongPress(taskIndex, type: DownloadType.archiver),
        behavior: HitTestBehavior.opaque,
        child: DownloadArchiverItem(
          archiverTaskInfo: archiveTaskInfo,
          index: taskIndex,
        ),
      );
    },
  );
}

Widget _buildDelAnimatedListItem(
  Animation<double> animation, {
  required Widget child,
}) {
  return FadeTransition(
    opacity: animation.drive(
        CurveTween(curve: const Interval(0.0, 1.0, curve: Curves.easeOut))),
    child: SizeTransition(
      sizeFactor: animation.drive(
          CurveTween(curve: const Interval(0.0, 1.0, curve: Curves.easeOut))),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: animation,
                curve: const Interval(0.4, 1.0, curve: Curves.easeOut))),
        child: child,
      ),
    ),
  );
}

Widget _buildAnimatedListItem(
  Animation<double> _animation, {
  required Widget child,
}) {
  return FadeTransition(
    opacity: _animation.drive(CurveTween(curve: Curves.easeIn)),
    child: SizeTransition(
      sizeFactor: _animation.drive(CurveTween(curve: Curves.easeIn)),
      child: child,
    ),
  );
}
