import 'dart:async';
import 'package:eros_fe/pages/tab/controller/favorite/favorite_tabbar_controller.dart';
import 'package:eros_fe/common/controller/favorite_state_store.dart';
import 'package:eros_fe/common/controller/localfav_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/extension.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/favcat.dart';
import 'package:eros_fe/network/request.dart';
import 'package:eros_fe/pages/gallery/view/gallery_favcat.dart';
import 'package:eros_fe/pages/item/controller/galleryitem_controller.dart';
import 'package:eros_fe/utils/logger.dart';
import 'package:eros_fe/utils/toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

import 'favorite_sel_controller.dart';
import 'favorite_note_draft.dart';

class FavController extends GetxController {
  EhSettingService get _ehSettingService => Get.find();
  LocalFavController get _localFavController => Get.find();

  // 收藏输入框控制器
  final TextEditingController _favnoteController = TextEditingController();
  FavoriteNoteDraft? _noteDraft;

  Future<String?> loadFavoriteNote(String gid, String token) async =>
      (await galleryGetFavorite(gid, token)).favNote;

  FixedExtentScrollController _fixedExtentScrollController =
      FixedExtentScrollController();

  FavoriteSelectorController get _favoriteSelectorController => Get.find();

  Future<Favcat?> showFavListDialog(
    BuildContext context,
    List<Favcat> favList,
  ) async {
    return _ehSettingService.isFavPicker.value
        ? await _showAddFavPicker(context, favList)
        : await _showAddFavList(context, favList);
  }

  /// 添加收藏 Picker 形式
  Future<Favcat?> _showAddFavPicker(
      BuildContext context, List<Favcat> favList) async {
    final choices = favList.where((value) => value.favId != 'a').toList();
    int _favIndex = _fixedExtentScrollController.initialItem;

    final List<Widget> _favPickerList =
        List<Widget>.from(choices.map((Favcat e) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 4, bottom: 4),
                  child: FaIcon(
                    FontAwesomeIcons.solidHeart,
                    color: ThemeColors.favColor[e.favId],
                    size: 18,
                  ),
                ),
                Text(e.favTitle),
              ],
            ))).toList();

    return showCupertinoDialog<Favcat>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: GestureDetector(
            onLongPress: () {
              _ehSettingService.isFavPicker.value = false;
              showToast('切换样式');
            },
            child: Text(L10n.of(context).add_to_favorites),
          ),
          content: Container(
            child: Column(
              children: <Widget>[
                Container(
                  height: 250,
                  child: CupertinoPicker(
                    scrollController: _fixedExtentScrollController,
                    itemExtent: 30,
                    onSelectedItemChanged: (int index) {
                      _favIndex = index;
                    },
                    children: _favPickerList,
                  ),
                ),
                CupertinoTextField(
                  controller: _favnoteController,
                  onChanged: (value) => _noteDraft?.edit(value),
                  maxLines: null,
                  decoration: BoxDecoration(
                    color: ehTheme.favnoteTextFieldBackgroundColor,
                    borderRadius: const BorderRadius.all(Radius.circular(8.0)),
                  ),
                )
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
                Get.back(
                    result: choices[_favIndex]
                        .copyWith(note: _favnoteController.text.oN));
              },
            ),
          ],
        );
      },
    );
  }

  /// 添加收藏 List形式
  Future<Favcat?> _showAddFavList(
    BuildContext context,
    List<Favcat> favList,
  ) async {
    final List<Widget> _favcatList = List<Widget>.from(favList
        .where((value) => value.favId != 'a')
        .map((Favcat fav) => FavCatAddListItem(
              text: fav.favTitle,
              favcat: fav.favId,
              totNum: fav.totNum,
              onTap: () {
                // 返回数据
                Get.back(
                    result: fav.copyWith(note: _favnoteController.text.oN));
              },
            ))).toList();

    logger.t(_favcatList.length);

    return showCupertinoDialog<Favcat?>(
      barrierDismissible: true,
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: GestureDetector(
            onLongPress: () {
              _ehSettingService.isFavPicker.value = true;
              showToast('切换样式');
            },
            child: Text(L10n.of(context).add_to_favorites),
          ),
          content: Container(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ..._favcatList,
                CupertinoTextField(
                  controller: _favnoteController,
                  onChanged: (value) => _noteDraft?.edit(value),
                  maxLines: null,
                  decoration: BoxDecoration(
                    color: ehTheme.favnoteTextFieldBackgroundColor,
                    borderRadius: const BorderRadius.all(Radius.circular(8.0)),
                  ),
                  placeholder: 'Favorites note',
                ).paddingOnly(top: 8.0),
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
          ],
        );
      },
    );
  }

  /// 点击收藏按钮处理
  Future<Favcat?> addFav(
    String gid,
    String token, {
    String oriFavcat = '',
    String oriFavnote = '',
  }) async {
    logger.d('bbb add fav $gid $token');
    final String? _lastFavcat = _ehSettingService.lastFavcat;

    _favnoteController.text = oriFavnote;

    // 添加到上次收藏夹
    if ((_ehSettingService.isFavLongTap.value) &&
        _lastFavcat != null &&
        _lastFavcat.isNotEmpty) {
      logger.t('添加到上次收藏夹');
      return addToLastFavcat(gid, token, _lastFavcat, oriFavcat: oriFavcat);
    } else {
      // 手选收藏夹
      logger.t('手选收藏夹');
      return await selectToSave(gid, token, oriFavcat: oriFavcat);
    }
  }

  // 选择并收藏
  bool _selecting = false;

  Future<Favcat?> selectToSave(
    String gid,
    String token, {
    String oriFavcat = '',
    VoidCallback? startLoading,
  }) async {
    if (_selecting) return null;
    _selecting = true;
    try {
      return await _selectToSave(gid, token,
          oriFavcat: oriFavcat, startLoading: startLoading);
    } finally {
      _selecting = false;
    }
  }

  Future<Favcat?> _selectToSave(
    String gid,
    String token, {
    String oriFavcat = '',
    VoidCallback? startLoading,
  }) async {
    _favnoteController.clear();
    final BuildContext context = Get.context!;

    final List<Favcat> favList = _favoriteSelectorController.favcatList;

    if (favoriteStates.isBusy(gid)) throw StateError('该画廊的收藏操作正在处理中');
    final epoch = favoriteStates.epoch;
    final selectedCategory = favoriteStates[gid]?.category ?? oriFavcat;
    final noteDraft = FavoriteNoteDraft();
    _noteDraft = noteDraft;
    // Existing favorites may have a note not included in gallery HTML.
    // Load only that note in the background; never change the selected folder.
    if (isNetworkFavoriteCategory(selectedCategory)) {
      noteDraft.load(() => loadFavoriteNote(gid, token), (note) {
        if (identical(_noteDraft, noteDraft) && epoch == favoriteStates.epoch) {
          _favnoteController.text = note;
        }
      });
    }
    final choices = favList.where((value) => value.favId != 'a').toList();
    final selectedIndex =
        choices.indexWhere((value) => value.favId == selectedCategory);
    _fixedExtentScrollController.dispose();
    _fixedExtentScrollController = FixedExtentScrollController(
        initialItem: selectedIndex < 0 ? 0 : selectedIndex);

    // diaolog 获取选择结果
    Favcat? result;
    try {
      result = await showFavListDialog(context, favList);
    } catch (e, stack) {
      logger.e('$e\n$stack');
    } finally {
      noteDraft.active = false;
      if (identical(_noteDraft, noteDraft)) _noteDraft = null;
    }

    logger.t('$result  ${result.runtimeType}');

    if (result != null) {
      startLoading?.call();
      logger.t('add fav $result');

      final String _favcat = result.favId;
      final String _favnote = _favcat == 'l' ? '' : await noteDraft.forSave();
      if (epoch != favoriteStates.epoch) throw StateError('账号已切换');
      result = result.copyWith(note: _favnote.oN);
      final previousCategory =
          favoriteStates[gid]?.category ?? selectedCategory;
      try {
        if (_favcat != 'l') {
          await galleryAddFavorite(
            gid,
            token,
            favcat: _favcat,
            favnote: _favnote,
          );
        } else {
          // _localFavController.addLocalFav(_pageController.galleryProvider);
          // todo
          _localFavController.addLocalFav(
              Get.find<GalleryItemController>(tag: gid).galleryProvider);
          logger.d('addLocalFav');
        }
      } catch (e) {
        rethrow;
      }
      _updateCounts(previousCategory, _favcat);

      return result;
    } else {
      return null;
    }
  }

  Future<Favcat> addToLastFavcat(
    String gid,
    String token,
    String _lastFavcat, {
    String oriFavcat = '',
    String oriFavnote = '',
  }) async {
    final previousCategory = favoriteStates[gid]?.category ?? oriFavcat;
    final title = _favoriteSelectorController.favcatList
            .where((value) => value.favId == _lastFavcat)
            .map((value) => value.favTitle)
            .firstOrNull ??
        '';
    try {
      await galleryAddFavorite(gid, token, favcat: _lastFavcat, favnote: '');
    } catch (e) {
      rethrow;
    }
    _updateCounts(previousCategory, _lastFavcat);
    return Favcat(favTitle: title, favId: _lastFavcat);
  }

  final Set<String> _dirtyCategories = {};
  bool _refreshingFavorites = false;

  void _updateCounts(String previous, String next) {
    if (previous != next) {
      if (previous.isNotEmpty) _favoriteSelectorController.decrease(previous);
      if (next.isNotEmpty) _favoriteSelectorController.increase(next);
    }
    _dirtyCategories.addAll(['a', previous, next]);
    unawaited(_refreshAffectedFavorites());
  }

  Future<void> _refreshAffectedFavorites() async {
    if (_refreshingFavorites) return;
    _refreshingFavorites = true;
    try {
      while (_dirtyCategories.isNotEmpty) {
        final categories = Set<String>.of(_dirtyCategories);
        _dirtyCategories.clear();
        if (!Get.isRegistered<FavoriteTabBarController>()) continue;
        final controllers = Get.find<FavoriteTabBarController>()
            .subControllerMap
            .values
            .toSet()
            .where((controller) =>
                !controller.isClosed && categories.contains(controller.favcat));
        await Future.wait(controllers.map((controller) async {
          try {
            await controller.reloadData();
          } catch (_) {
            logger.w('Favorite saved; favorite list refresh failed');
          }
        }));
      }
    } finally {
      _refreshingFavorites = false;
    }
  }

  /// 删除收藏
  Future<void> delFav(String favcat, String gid, String token) async {
    if (favcat.isNotEmpty && favcat != 'l') {
      logger.t('取消网络收藏');
      await galleryAddFavorite(gid, token);
    } else {
      logger.t('取消本地收藏');
      _localFavController.removeFavByGid(gid);
    }
    _updateCounts(favcat, '');
  }
}
