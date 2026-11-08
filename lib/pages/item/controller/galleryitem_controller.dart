import 'dart:math';

import 'package:collection/collection.dart';
import 'package:eros_fe/common/controller/favorite_state_store.dart';
import 'package:eros_fe/common/controller/history_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/component/setting_base.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/network/favorite_mutation.dart';
import 'package:eros_fe/pages/controller/fav_controller.dart';
import 'package:eros_fe/pages/item/item_base.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

class GalleryItemController extends GetxController {
  GalleryItemController({required GalleryProvider galleryProvider})
      : _galleryProvider = galleryProvider,
        _accountEpoch = favoriteStates.epoch;

  EhSettingService get _ehSettingService => Get.find();
  FavController get _favDialogController => Get.find();
  TabHomeController get _tabHomeController => Get.find();
  HistoryController get _historyController => Get.find();

  late List<GalleryImage> firstPageImage;
  GalleryProvider _galleryProvider;
  final int _accountEpoch;
  GalleryProvider get galleryProvider {
    final provider = _accountEpoch == favoriteStates.epoch
        ? _galleryProvider
        : _galleryProvider.copyWith(favcat: ''.oN, favTitle: ''.oN);
    return favoriteStates.overlay(provider);
  }

  final RxBool _isFav = false.obs;
  bool get isFav => favCat.isNotEmpty;
  set isFav(bool val) => _isFav.value = val;

  /// Only a mapped favorite category has a corresponding colored heart.
  bool get hasFavoriteColor => ThemeColors.favColor.containsKey(favCat);

  final _favCat = ''.obs;
  String get favCat {
    final category = favoriteStates[_galleryProvider.gid]?.category ??
        (_accountEpoch == favoriteStates.epoch ? _favCat.value : '');
    return category.isEmpty && (_galleryProvider.localFav ?? false)
        ? 'l'
        : category;
  }

  set favCat(String val) => _favCat.value = val;

  final _rating = 0.0.obs;
  double get rating => _rating.value;
  set rating(double val) => _rating.value = val;

  final _ratingFallBack = 0.0.obs;
  double get ratingFallBack => _ratingFallBack.value;
  set ratingFallBack(double val) => _ratingFallBack.value = val;

  final _colorRating = ''.obs;
  String get colorRating => _colorRating.value;
  set colorRating(String val) => _colorRating.value = val;

  @override
  void onInit() {
    super.onInit();
    logger.t(
        'init GalleryProviderController ${galleryProvider.gid}  ${galleryProvider.englishTitle}');
    if (galleryProvider.favTitle != null &&
        galleryProvider.favTitle!.isNotEmpty) {
      isFav = true;
    }

    rating = galleryProvider.rating ?? 0.00;
    colorRating = galleryProvider.colorRating ?? '';

    ratingFallBack = galleryProvider.ratingFallBack ?? 0.00;
    logger.t('ratingFB=$ratingFallBack');

    favCat = galleryProvider.favcat ?? '';
    logger.t('favCat=$favCat');
  }

  int get tagLine => max(
          1,
          (getLimitSimpleTags(galleryProvider.simpleTags,
                          _ehSettingService.listViewTagLimit)
                      ?.length ??
                  0) /
              4)
      .round();

  /// 设置收藏夹
  void setFavTitleAndFavcat({String favTitle = '', String? favcat}) {
    _galleryProvider = _galleryProvider.copyWith(
        favTitle: favTitle.oN, favcat: (favcat ?? '').oN);
    _isFav.value = (favcat ?? '').isNotEmpty;
    _favCat.value = favcat ?? '';
  }

  String get title {
    // if ((_ehSettingService.isJpnTitle.value) &&
    //     (galleryProvider.japaneseTitle?.isNotEmpty ?? false)) {
    //   return galleryProvider.japaneseTitle ?? '';
    // } else {
    //   return galleryProvider.englishTitle ?? '';
    // }
    return galleryProvider.englishTitle ?? '';
  }

  late Rx<Color?> colorTap = ehTheme.itemBackgroundColor.obs;

  /// 点击item
  void onTap(dynamic tabTag) {
    logger.t('${galleryProvider.englishTitle} ');
    NavigatorUtil.goGalleryPage(
        galleryProvider: galleryProvider, tabTag: tabTag);
  }

  void onTapDown(_) => _updatePressedColor();

  void onTapUp(_) {
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      _updateNormalColor();
    });
  }

  void onTapCancel() => _updateNormalColor();

  void _updateNormalColor() {
    colorTap.value = ehTheme.itemBackgroundColor;
  }

  void _updatePressedColor() {
    // colorTap.value = CupertinoDynamicColor.resolve(
    //     CupertinoColors.systemGrey4, Get.context!);
    colorTap.value = getPressedColor(Get.context!);
  }

  set localFav(bool value) {
    _galleryProvider = galleryProvider.copyWith(localFav: value.oN);
    update();
  }

  bool get localFav => galleryProvider.localFav ?? false;

  void firstPutImage(List<GalleryImage> galleryImage) {
    if (galleryImage.isNotEmpty) {
      galleryProvider.copyWith(galleryImages: galleryImage.oN);
    }

    firstPageImage =
        galleryProvider.galleryImages?.sublist(0, galleryImage.length) ?? [];
  }

  bool get _hasNetworkFavorite =>
      galleryProvider.favcat != null &&
      (galleryProvider.favcat?.isNotEmpty ?? false);

  /// Adds the gallery to a favorites folder the user picks (or the last one,
  /// when that setting is on).
  Future<void> addFavorite() async {
    if (galleryProvider.gid == null || galleryProvider.token == null) {
      return;
    }
    try {
      final value = await _favDialogController.addFav(
          galleryProvider.gid!, galleryProvider.token!);
      if (value == null) {
        return;
      }
      setFavTitleAndFavcat(favTitle: value.favTitle, favcat: value.favId);
      showToast('successfully add');
    } catch (e) {
      showToast(favoriteMutationMessage(e));
    }
  }

  /// Removes the gallery from its favorites folder; false when it failed.
  Future<bool> removeFavorite() async {
    if (galleryProvider.gid == null || galleryProvider.token == null) {
      return false;
    }
    try {
      await _favDialogController.delFav(galleryProvider.favcat!,
          galleryProvider.gid!, galleryProvider.token!);
    } catch (e) {
      showToast(favoriteMutationMessage(e));
      return false;
    }
    setFavTitleAndFavcat(favTitle: '', favcat: '');
    showToast('successfully deleted');
    return true;
  }

  /// Moves the gallery to another favorites folder.
  Future<void> changeFavorite() async {
    if (galleryProvider.gid == null || galleryProvider.token == null) {
      return;
    }
    try {
      final value = await _favDialogController.addFav(
          galleryProvider.gid!, galleryProvider.token!,
          oriFavcat: galleryProvider.favcat!);
      if (value != null) {
        setFavTitleAndFavcat(favTitle: '', favcat: '');
        setFavTitleAndFavcat(favTitle: value.favTitle, favcat: value.favId);
        showToast('successfully changed');
      }
    } catch (e) {
      showToast(favoriteMutationMessage(e));
    }
  }

  /// Whether the item sits in the history list, which lets it be removed.
  bool get isHistoryItem {
    final curPage = Get.currentRoute;
    final curTab = Get.isRegistered<TabHomeController>()
        ? _tabHomeController.currRoute
        : null;
    final topRoute = MainNavigatorObserver().history.lastOrNull?.settings.name;
    return curPage == EHRoutes.history ||
        topRoute == EHRoutes.history ||
        curTab == EHRoutes.history;
  }

  void removeFromHistory() {
    if (galleryProvider.gid == null) {
      return;
    }
    _historyController.removeHistory(galleryProvider.gid!);
  }

  /// 长按菜单
  Future<void> _showLongPressSheet() async {
    final BuildContext context = Get.overlayContext!;
    final isHistoryItem = this.isHistoryItem;
    logger.d('isHistoryItem $isHistoryItem');

    await showCupertinoModalPopup<void>(
        context: context,
        builder: (BuildContext context) {
          return EhActionSheet(
            title: Text(title),
            cancelButton: CupertinoActionSheetAction(
                onPressed: () {
                  Get.back();
                },
                child: Text(L10n.of(context).cancel)),
            actions: <Widget>[
              if (!_hasNetworkFavorite)
                EhActionSheetAction(
                  icon: CupertinoIcons.heart,
                  systemIcon: 'heart',
                  onPressed: () async {
                    if (galleryProvider.gid == null ||
                        galleryProvider.token == null) {
                      return;
                    }
                    Get.back();
                    await addFavorite();
                  },
                  child: Text(L10n.of(context).add_to_favorites),
                ),
              if (_hasNetworkFavorite)
                EhActionSheetAction(
                  icon: CupertinoIcons.heart_slash,
                  systemIcon: 'heart.slash',
                  onPressed: () async {
                    if (await removeFavorite()) {
                      Get.back();
                    }
                  },
                  child: Text(L10n.of(context).remove_from_favorites),
                ),
              if (_hasNetworkFavorite)
                EhActionSheetAction(
                  icon: CupertinoIcons.folder,
                  systemIcon: 'folder',
                  onPressed: () async {
                    if (galleryProvider.gid == null ||
                        galleryProvider.token == null) {
                      return;
                    }
                    Get.back();
                    await changeFavorite();
                  },
                  child: Text(L10n.of(context).change_to_favorites),
                ),
              if (isHistoryItem)
                EhActionSheetAction(
                  icon: CupertinoIcons.trash,
                  systemIcon: 'trash',
                  isDestructiveAction: true,
                  onPressed: () {
                    if (galleryProvider.gid == null) {
                      return;
                    }
                    removeFromHistory();
                    Get.back();
                  },
                  child: Text(L10n.of(context).delete),
                ),
            ],
          );
        });
  }

  void onLongPress() {
    vibrateUtil.heavy();
    _showLongPressSheet();
  }
}
