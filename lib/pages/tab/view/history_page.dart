import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/adaptive/native_single_bar_edge.dart';
import 'package:eros_fe/adaptive/native_top_header.dart';
import 'package:eros_fe/common/controller/history_controller.dart';
import 'package:eros_fe/debug/offline_history.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/tab/controller/history_view_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/pages/tab/view/list/tab_base.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/utils/cust_lib/persistent_header_builder.dart';
import 'package:eros_fe/utils/cust_lib/sliver/sliver_persistent_header.dart';
import 'package:eros_fe/utils/logger.dart';
import 'package:eros_fe/widget/canvas_grain.dart';
import 'package:eros_fe/widget/refresh.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:keframe/keframe.dart';

import '../comm.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final controller = Get.find<HistoryViewController>();
  final EhTabController ehTabController = EhTabController();
  final GlobalKey<SliverAnimatedListState> _sliverAnimatedListKey =
      GlobalKey<SliverAnimatedListState>();
  bool _registeredAsRootTab = false;
  static const Key _firstCardKey = ValueKey<String>('history-first-card');

  @override
  void initState() {
    super.initState();

    HistoryViewController.registerAnimatedListKey(
      controller,
      _sliverAnimatedListKey,
    );
    ehTabController.hasScrollClientsCall = () =>
        mounted &&
        (PrimaryScrollController.maybeOf(context)?.hasClients ?? false);
    ehTabController.scrollToTopCall = () => controller.scrollToTop(context);
    ehTabController.scrollToTopRefreshCall =
        () => controller.scrollToTopRefresh(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isTab = ModalRoute.of(context)?.isFirst ?? true;
    final heroTag = controller.heroTag;
    if (heroTag != null && isTab && !_registeredAsRootTab) {
      tabPages.scrollControllerMap[heroTag] = ehTabController;
      _registeredAsRootTab = true;
    }
  }

  @override
  void dispose() {
    HistoryViewController.unregisterAnimatedListKey(
      controller,
      _sliverAnimatedListKey,
    );
    final heroTag = controller.heroTag;
    if (_registeredAsRootTab &&
        heroTag != null &&
        identical(tabPages.scrollControllerMap[heroTag], ehTabController)) {
      tabPages.scrollControllerMap.remove(heroTag);
    }
    ehTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    logger.t('build Historyview');
    final String _title = L10n.of(context).tab_history;

    bool isRefresh = false;
    final navigationBar = CupertinoNavigationBar(
      transitionBetweenRoutes: false,
      padding: const EdgeInsetsDirectional.only(end: 4),
      leading: controller.getLeading(context),
      middle: GestureDetector(
          onTap: () => controller.scrollToTop(context), child: Text(_title)),
      trailing: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (GetPlatform.isDesktop)
            StatefulBuilder(
              builder: (context, setState) {
                return CupertinoButton(
                  padding: const EdgeInsets.all(0),
                  minSize: 40,
                  child: isRefresh
                      ? const CupertinoActivityIndicator(radius: 10)
                      : const EhSvgIcon(CupertinoIcons.arrow_clockwise, size: 24),
                  onPressed: () async {
                    setState(() {
                      isRefresh = true;
                    });
                    try {
                      await controller.reloadData();
                    } finally {
                      setState(() {
                        isRefresh = false;
                      });
                    }
                  },
                );
              },
            ),
          // 清除按钮
          CupertinoButton(
            minSize: 40,
            padding: const EdgeInsets.all(0),
            child: const EhSvgFaIcon(
              FontAwesomeIcons.solidTrashCan,
              size: 20,
            ),
            onPressed: () {
              controller.clearHistory();
            },
          ),
        ],
      ),
    );
    // The native bar replaces the Flutter one and already pads the page.
    final bool nativeBar = NativeNavigationScope.isEnabled(context);
    final Widget customScrollView = CustomScrollView(
      slivers: <Widget>[
        if (nativeBar)
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.viewPaddingOf(context).top),
          )
        else
          SliverFloatingPinnedPersistentHeader(
            delegate: SliverFloatingPinnedPersistentHeaderBuilder(
              minExtentProtoType: SizedBox(
                height: context.mediaQueryPadding.top,
              ),
              maxExtentProtoType: navigationBar,
              builder: (_, __, ___) => navigationBar,
            ),
          ),
        // CupertinoSliverNavigationBar(
        //   largeTitle: GestureDetector(
        //       onTap: () => controller.scrollToTop(context),
        //       child: Text(_title)),
        // ),
        EhCupertinoSliverRefreshControl(
          onRefresh: controller.syncHistory,
        ),
        SliverSafeArea(
          top: false,
          sliver: GetBuilder<HistoryController>(
            builder: (logic) {
              return offlineHistorySliver(
                initialized: logic.historiesInitialized,
                count: logic.histories.length,
                sliver: getGallerySliverList(
                  logic.histories,
                  controller.heroTag,
                  key: _sliverAnimatedListKey,
                  firstCardKey: nativeBar ? _firstCardKey : null,
                  contentTopGap: nativeBar
                      ? NativeTopTabHeader.contentGapFor(context)
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );

    // A tab of its own names the tabs it hides, as the other root lists do.
    final bool isTab = ModalRoute.of(context)?.isFirst ?? true;
    return NativeNavigationPage(
      tabId: EHRoutes.history,
      chrome: NativePageChrome(
        title: _title,
        actions: [
          if (isTab) ...Get.find<TabHomeController>().nativeHiddenTabActions,
          NativeNavigationAction(
            id: 'history.clear',
            title: L10n.of(context).t_Clear_all_history,
            symbol: 'trash',
            onPressed: controller.clearHistory,
          ),
        ],
      ),
      child: CupertinoPageScaffold(
        child: CanvasGrain(
          child: SizeCacheWidget(
            child: NativeSingleBarEdge(child: customScrollView),
          ),
        ),
      ),
    );
  }
}
