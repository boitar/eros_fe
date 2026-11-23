import 'package:eros_fe/common/controller/history_controller.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/index.dart';
import 'package:eros_fe/pages/tab/controller/default_tabview_controller.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/utils/logger.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

class HistoryViewController extends DefaultTabViewController {
  final HistoryController historyController = Get.find();

  static final Expando<Set<GlobalKey<SliverAnimatedListState>>>
      _animatedListKeysByController =
      Expando<Set<GlobalKey<SliverAnimatedListState>>>(
        'HistoryViewController.animatedListKeys',
      );

  static void registerAnimatedListKey(
    HistoryViewController controller,
    GlobalKey<SliverAnimatedListState> key,
  ) {
    final keys = _animatedListKeysByController[controller] ??=
        <GlobalKey<SliverAnimatedListState>>{};
    keys.add(key);
  }

  static void unregisterAnimatedListKey(
    HistoryViewController controller,
    GlobalKey<SliverAnimatedListState> key,
  ) {
    _animatedListKeysByController[controller]?.remove(key);
  }

  static Iterable<SliverAnimatedListState> _attachedAnimatedListStates(
    HistoryViewController controller,
  ) sync* {
    final seen = <SliverAnimatedListState>{};
    final keys = _animatedListKeysByController[controller];
    if (keys != null) {
      for (final key in keys) {
        final state = key.currentState;
        if (state != null && seen.add(state)) {
          yield state;
        }
      }
    }
    final fallback = controller.sliverAnimatedListKey.currentState;
    if (fallback != null && seen.add(fallback)) {
      yield fallback;
    }
  }

  static void insertAnimatedListItem(
    HistoryViewController controller,
    int index,
  ) {
    for (final state in _attachedAnimatedListStates(controller)) {
      state.insertItem(index);
    }
  }

  static void removeAnimatedListItem(
    HistoryViewController controller,
    int index,
    AnimatedRemovedItemBuilder builder,
  ) {
    for (final state in _attachedAnimatedListStates(controller)) {
      state.removeItem(index, builder);
    }
  }

  @override
  void onInit() {
    super.onInit();
    heroTag = EHRoutes.history;

    loadData().then(
      (List<GalleryProvider> value) {
        change(value, status: RxStatus.success());
      },
      onError: (err) {
        change(null, status: RxStatus.error(err.toString()));
      },
    );
  }

  Future<List<GalleryProvider>> loadData() async {
    logger.t('_loadData ');
    await historyController.initHistories();
    return List<GalleryProvider>.of(historyController.histories);
  }

  @override
  Future<void> reloadData() async {
    await historyController.reloadHistories();
    final List<GalleryProvider> gallerItemBeans = List<GalleryProvider>.of(
      historyController.histories,
    );
    change(gallerItemBeans);
    update();
  }

  // 清除历史记录 Dialog
  Future<void> clearHistory() async {
    return showCupertinoDialog<void>(
      context: Get.context!,
      builder: (BuildContext context) {
        return EhAlertDialog(
          title: Text(L10n.of(context).t_Clear_all_history),
          content: Text(L10n.of(context).desktop_clear_history_detail),
          actions: <Widget>[
            CupertinoDialogAction(
              child: Text(L10n.of(context).cancel),
              onPressed: () {
                Get.back();
              },
            ),
            CupertinoDialogAction(
              child: Text(L10n.of(context).ok),
              onPressed: () async {
                await historyController.cleanHistory();
                Get.back();
                await reloadData();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> syncHistory() async {
    await historyController.syncHistory();
  }
}
