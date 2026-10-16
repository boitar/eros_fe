import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/tab/controller/group/custom_sublist_controller.dart';
import 'package:eros_fe/pages/tab/controller/group/custom_tabbar_controller.dart';
import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

import '../../comm.dart';
import '../gallery_base.dart';
import '../list/tab_base.dart';

class SubListView<T extends CustomSubListController> extends StatefulWidget {
  const SubListView({
    super.key,
    required this.profileUuid,
    this.scrollToInitialAnchor,
    this.firstCardKey,
  });

  final String profileUuid;
  final Future<void> Function()? scrollToInitialAnchor;
  final GlobalKey? firstCardKey;

  @override
  State<SubListView> createState() => _SubListViewState<T>();
}

class _SubListViewState<T extends CustomSubListController>
    extends State<SubListView> with AutomaticKeepAliveClientMixin {
  late final CustomSubListController subController;
  final CustomTabbarController controller = Get.find();
  final EhTabController ehTabController = EhTabController();

  @override
  void initState() {
    super.initState();
    logger.t('Get.find ${T.runtimeType} tag:${widget.profileUuid}');
    subController = Get.find<T>(tag: widget.profileUuid)
      ..heroTag = widget.profileUuid;
    controller.subControllerMap[widget.profileUuid] = subController;
    subController.listMode =
        subController.profile?.listMode ?? ListModeEnum.global;
    addListen();
  }

  void addListen() {
    subController.initEhTabController(
      context: context,
      ehTabController: ehTabController,
      tabTag: EHRoutes.gallery,
      scrollToInitialAnchor: widget.scrollToInitialAnchor,
    );
  }

  @override
  void dispose() {
    ehTabController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return CustomScrollView(
      cacheExtent: kTabViewCacheExtent,
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        // 刷新控件必须在 SliverOverlapInjector 之前：injector 会把吸顶头栏
        // 高度转成实际布局空间，吞掉顶部下拉越界时 viewport 给出的负 overlap，
        // 而 CupertinoSliverRefreshControl 只有在 overlap < 0 时才会激活。
        SliverSafeArea(
          top: false,
          bottom: false,
          sliver: EhCupertinoSliverRefreshControl(
            onRefresh: subController.onRefresh,
          ),
        ),
        SliverOverlapInjector(
          handle: ExtendedNestedScrollView.sliverOverlapAbsorberHandleFor(
            context,
          ),
        ),
        SliverSafeArea(
          top: false,
          bottom: false,
          sliver: _buildListView(),
        ),
        Obx(() {
          return SliverSafeArea(
            sliver: EndIndicator(
              pageState: subController.pageState,
              loadDataMore: subController.loadDataMore,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildListView() {
    return GetBuilder<CustomSubListController>(
      global: false,
      init: subController,
      id: subController.listViewId,
      builder: (logic) {
        final status = logic.status;

        if (status.isLoading) {
          return SliverFillRemaining(
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.only(bottom: 50),
              child: const CupertinoActivityIndicator(
                radius: 14.0,
              ),
            ),
          );
        }

        if (status.isError) {
          return SliverFillRemaining(
            child: Container(
              padding: const EdgeInsets.only(bottom: 50),
              child: GalleryErrorPage(
                onTap: subController.reLoadDataFirst,
                error: status.errorMessage,
              ),
            ),
          );
        }

        if (status.isSuccess) {
          return getGallerySliverList(
            logic.state,
            subController.heroTag,
            next: logic.next,
            lastComplete: subController.lastComplete,
            firstCardKey: widget.firstCardKey,
            // key: subController.sliverAnimatedListKey,
            listMode: subController.listModeObs,
            // centerKey: subController.galleryGroupKey,
            keepPosition: subController.keepPosition,
          );
        }

        return SliverFillRemaining(
          child: Container(
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(
                  FontAwesomeIcons.hippo,
                  size: 100,
                  color: CupertinoDynamicColor.resolve(
                      CupertinoColors.systemGrey, context),
                ),
                Text(''),
              ],
            ),
          ).autoCompressKeyboard(Get.context!),
        );
      },
    );
  }
}
