import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:eros_fe/common/controller/favorite_state_store.dart';
import 'package:eros_fe/common/controller/localfav_controller.dart';
import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/fav_rule_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/extension.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/models/fav_rule.dart';
import 'package:eros_fe/network/request.dart';
import 'package:eros_fe/pages/gallery/view/favorite_form_widgets.dart';
import 'package:eros_fe/pages/gallery/view/gallery_favcat.dart';
import 'package:eros_fe/pages/item/controller/galleryitem_controller.dart';
import 'package:eros_fe/pages/setting/fav_rule/fav_rule_edit_page.dart';
import 'package:eros_fe/pages/tab/controller/favorite/favorite_tabbar_controller.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/utils/logger.dart';
import 'package:eros_fe/utils/toast.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:eros_fe/widget/fav_rule_safe_area.dart';
import 'package:eros_fe/widget/fav_rule_widgets.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

import 'favorite_note_draft.dart';
import 'favorite_sel_controller.dart';

/// Optional context passed to the favorite picker when opened as a fallback
/// after rule-based favoriting found no matching rule (prototype ⑦).
class FavRuleMissContext {
  const FavRuleMissContext({
    this.galleryTitle = '',
    this.keyTags = const <NormalizedTag>[],
  });

  final String galleryTitle;
  final List<NormalizedTag> keyTags;
}

class FavController extends GetxController {
  EhSettingService get _ehSettingService => Get.find();
  LocalFavController get _localFavController => Get.find();
  FavRuleService? get _favRuleService =>
      Get.isRegistered<FavRuleService>() ? Get.find<FavRuleService>() : null;

  // 收藏输入框控制器
  final TextEditingController _favnoteController = TextEditingController();
  FavoriteNoteDraft? _noteDraft;

  Future<String?> loadFavoriteNote(String gid, String token) async =>
      (await galleryGetFavorite(gid, token)).favNote;

  FixedExtentScrollController _fixedExtentScrollController =
      FixedExtentScrollController();

  FavoriteSelectorController get _favoriteSelectorController => Get.find();

  FavPickerStyle get _currentPickerStyle {
    final ruleService = _favRuleService;
    if (ruleService != null) {
      return ruleService.config.pickerStyle;
    }
    return _ehSettingService.isFavPicker.value
        ? FavPickerStyle.wheel
        : FavPickerStyle.list;
  }

  Future<void> _cyclePickerStyle(BuildContext context) async {
    final l10n = L10n.of(context);
    final next = switch (_currentPickerStyle) {
      FavPickerStyle.grid => FavPickerStyle.list,
      FavPickerStyle.list => FavPickerStyle.wheel,
      FavPickerStyle.wheel => FavPickerStyle.grid,
    };
    final ruleService = _favRuleService;
    if (ruleService != null) {
      await ruleService.setPickerStyle(next);
    } else {
      _ehSettingService.isFavPicker.value = next == FavPickerStyle.wheel;
    }
    final label = switch (next) {
      FavPickerStyle.grid => l10n.fav_rule_picker_grid,
      FavPickerStyle.list => l10n.fav_rule_picker_list,
      FavPickerStyle.wheel => l10n.fav_rule_picker_wheel,
    };
    showToast('${l10n.fav_rule_picker_switched}: $label');
  }

  void _openCreateRuleFromMiss(
    BuildContext dialogContext, {
    NormalizedTag? tag,
  }) {
    final conditions = tag == null
        ? const <FavRuleCondition>[]
        : <FavRuleCondition>[FavRuleCondition.fromNormalizedTag(tag)];
    final editArgs = FavRuleEditArgs(initialConditions: conditions);
    unawaited(vibrateUtil.selection());
    Navigator.of(dialogContext).pop();
    Get.toNamed<dynamic>(
      EHRoutes.favRuleEdit,
      arguments: editArgs,
      id: detailNavigatorId,
      preventDuplicates: false,
    );
  }

  Future<Favcat?> showFavListDialog(
    BuildContext context,
    List<Favcat> favList, {
    String? galleryTitle,
    FavRuleMissContext? ruleMissContext,
  }) async {
    return switch (_currentPickerStyle) {
      FavPickerStyle.grid => await _showAddFavGrid(
          context,
          favList,
          galleryTitle: galleryTitle ?? ruleMissContext?.galleryTitle,
          ruleMissContext: ruleMissContext,
        ),
      FavPickerStyle.wheel => await _showAddFavPicker(
          context,
          favList,
          ruleMissContext: ruleMissContext,
        ),
      FavPickerStyle.list => await _showAddFavList(
          context,
          favList,
          ruleMissContext: ruleMissContext,
        ),
    };
  }

  /// 单层平铺双列收藏夹面板（面板 ②：收藏夹在前，备注居中，未命中中性胶囊在底部）
  Future<Favcat?> _showAddFavGrid(
    BuildContext context,
    List<Favcat> favList, {
    String? galleryTitle,
    FavRuleMissContext? ruleMissContext,
  }) async {
    final choices = favList.where((value) => value.favId != 'a').toList();
    final lastFavcat = _ehSettingService.lastFavcat;

    return showCupertinoModalPopup<Favcat>(
      context: context,
      barrierColor: const Color(0x70000000),
      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      builder: (sheetContext) {
        final l10n = L10n.of(sheetContext);
        final palette = ehTheme.palette;
        final fill = palette.fill.resolveFrom(sheetContext);
        final text1 = palette.text1.resolveFrom(sheetContext);
        final text2 = palette.text2.resolveFrom(sheetContext);
        final text3 = palette.text3.resolveFrom(sheetContext);
        final hairline = palette.hairline.resolveFrom(sheetContext);
        final displayTitle = (galleryTitle ?? '').trim();

        return buildSafeFloatingSheet(
          context: sheetContext,
          maxWidth: 480,
          heightFactor: 0.84,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: text3.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                child: Row(
                  children: <Widget>[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(sheetContext).pop(),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: fill,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: EhSvgIcon(
                              CupertinoIcons.xmark,
                              size: 15,
                              color: text1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onLongPress: () => _cyclePickerStyle(sheetContext),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              l10n.fav_rule_target_folder,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w600,
                                color: text1,
                              ),
                            ),
                            if (displayTitle.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 2),
                              Text(
                                displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: text2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      FavFolderTwoColumnGrid(
                        choices: choices,
                        lastUsedFavcat: lastFavcat,
                        onSelect: (fav) => Navigator.of(sheetContext).pop(
                          fav.copyWith(note: _favnoteController.text.oN),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        constraints: const BoxConstraints(minHeight: 46),
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.centerLeft,
                        child: CupertinoTextField(
                          controller: _favnoteController,
                          onChanged: (value) => _noteDraft?.edit(value),
                          minLines: 1,
                          maxLines: 3,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                          style: EhPopupTextStyles.body(sheetContext).copyWith(
                            fontSize: 14.5,
                          ),
                          placeholder: l10n.favorite_note_hint,
                          placeholderStyle: TextStyle(
                            fontSize: 14.5,
                            color: text3,
                          ),
                          decoration: null,
                          prefix: Padding(
                            padding: const EdgeInsets.only(left: 13),
                            child: EhSvgIcon(
                              CupertinoIcons.pencil,
                              size: 16,
                              color: text3,
                            ),
                          ),
                        ),
                      ),
                      if (ruleMissContext != null) ...<Widget>[
                        Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 12),
                          child: Container(height: 0.5, color: hairline),
                        ),
                        _buildRuleMissStrip(
                          sheetContext,
                          ruleMissContext,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Unboxed bottom inline strip for quick rule creation when no rule matched
  /// (Panel ② redesign: neutral chips, category swatch, clean namespace label).
  Widget _buildRuleMissStrip(
    BuildContext dialogContext,
    FavRuleMissContext miss,
  ) {
    final l10n = L10n.of(dialogContext);
    final zh = Localizations.localeOf(dialogContext).languageCode == 'zh';
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(dialogContext);
    final fill = palette.fill.resolveFrom(dialogContext);
    final text1 = palette.text1.resolveFrom(dialogContext);
    final text2 = palette.text2.resolveFrom(dialogContext);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.fav_rule_miss_title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: text2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openCreateRuleFromMiss(dialogContext),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 36),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      l10n.fav_rule_new_title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 2),
                    EhSvgIcon(
                      CupertinoIcons.chevron_forward,
                      size: 13,
                      color: accent,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (miss.keyTags.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              for (final tag in miss.keyTags.take(4))
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openCreateRuleFromMiss(
                    dialogContext,
                    tag: tag,
                  ),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: tag.isCategory
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              FavCategorySwatchSquare(
                                category: tag.rawTitle,
                                size: 14,
                                borderRadius: 4.5,
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  tag.rawTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w500,
                                    color: text1,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (tag.namespace.isNotEmpty) ...<Widget>[
                                Text(
                                  favRuleNamespaceShortLabel(
                                    tag.namespace,
                                    zh: zh,
                                  ),
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w400,
                                    color: text2,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Text(
                                  (zh && tag.rawTranslation.isNotEmpty)
                                      ? tag.rawTranslation
                                      : tag.rawTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w500,
                                    color: text1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// 添加收藏 Picker 形式
  Future<Favcat?> _showAddFavPicker(
    BuildContext context,
    List<Favcat> favList, {
    FavRuleMissContext? ruleMissContext,
  }) async {
    final choices = favList.where((value) => value.favId != 'a').toList();
    int _favIndex = _fixedExtentScrollController.initialItem;

    final List<Widget> _favPickerList =
        List<Widget>.from(choices.map((Favcat e) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    right: liquidGlassPopupsEnabled ? 12 : 4,
                    bottom: liquidGlassPopupsEnabled ? 0 : 4,
                  ),
                  child: EhSvgFaIcon(
                    FontAwesomeIcons.solidHeart,
                    color: ThemeColors.favColor[e.favId],
                    size: 18,
                  ),
                ),
                if (liquidGlassPopupsEnabled)
                  Flexible(
                    child: Text(
                      e.favTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: EhPopupTextStyles.action(context),
                    ),
                  ),
                if (!liquidGlassPopupsEnabled) Text(e.favTitle),
              ],
            ))).toList();

    return showCupertinoDialog<Favcat>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return EhAlertDialog(
          insetForm: liquidGlassPopupsEnabled,
          title: GestureDetector(
            onLongPress: () => _cyclePickerStyle(dialogContext),
            child: Text(L10n.of(dialogContext).add_to_favorites),
          ),
          content: Column(
            children: <Widget>[
              FavoriteFormGroup(
                enabled: liquidGlassPopupsEnabled,
                child: SizedBox(
                  height: liquidGlassPopupsEnabled ? 216 : 250,
                  child: CupertinoPicker(
                    scrollController: _fixedExtentScrollController,
                    itemExtent: liquidGlassPopupsEnabled
                        ? math.max(
                            44,
                            MediaQuery.textScalerOf(dialogContext).scale(17) *
                                    2.6 +
                                12)
                        : 30,
                    onSelectedItemChanged: (int index) {
                      _favIndex = index;
                    },
                    children: _favPickerList,
                  ),
                ),
              ),
              SizedBox(height: liquidGlassPopupsEnabled ? 16 : 0),
              _favoriteNoteField(dialogContext),
              if (ruleMissContext != null) ...<Widget>[
                const SizedBox(height: 14),
                _buildRuleMissStrip(dialogContext, ruleMissContext),
              ],
            ],
          ),
          actions: <Widget>[
            CupertinoDialogAction(
              child: Text(L10n.of(dialogContext).cancel),
              onPressed: () {
                Get.back();
              },
            ),
            CupertinoDialogAction(
              isDefaultAction: liquidGlassPopupsEnabled,
              child: Text(L10n.of(dialogContext).ok),
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
    List<Favcat> favList, {
    FavRuleMissContext? ruleMissContext,
  }) async {
    final List<Widget> _favcatList = List<Widget>.from(favList
        .where((value) => value.favId != 'a')
        .map((Favcat fav) => FavCatAddListItem(
              text: fav.favTitle,
              favcat: fav.favId,
              totNum: fav.totNum,
              grouped: liquidGlassPopupsEnabled,
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
      builder: (BuildContext dialogContext) {
        return EhAlertDialog(
          insetForm: liquidGlassPopupsEnabled,
          title: GestureDetector(
            onLongPress: () => _cyclePickerStyle(dialogContext),
            child: Text(L10n.of(dialogContext).add_to_favorites),
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (liquidGlassPopupsEnabled)
                FavoriteCategoryList(
                  children: _favcatList,
                )
              else
                ..._favcatList,
              SizedBox(height: liquidGlassPopupsEnabled ? 12 : 8),
              _favoriteNoteField(dialogContext),
              if (ruleMissContext != null) ...<Widget>[
                const SizedBox(height: 14),
                _buildRuleMissStrip(dialogContext, ruleMissContext),
              ],
            ],
          ),
          actions: <Widget>[
            CupertinoDialogAction(
              child: Text(L10n.of(dialogContext).cancel),
              onPressed: () {
                Get.back();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _favoriteNoteField(BuildContext context) {
    final glass = liquidGlassPopupsEnabled;
    if (glass) {
      return FavoriteNoteField(
        controller: _favnoteController,
        onChanged: (value) => _noteDraft?.edit(value),
      );
    }
    return CupertinoTextField(
      controller: _favnoteController,
      onChanged: (value) => _noteDraft?.edit(value),
      minLines: glass ? 1 : null,
      maxLines: glass ? 3 : null,
      padding: glass ? const EdgeInsets.all(12) : const EdgeInsets.all(6),
      style: glass ? EhPopupTextStyles.body(context) : null,
      placeholder: L10n.of(context).favorite_note_hint,
      placeholderStyle: glass ? EhPopupTextStyles.secondary(context) : null,
      decoration: BoxDecoration(
        color: glass
            ? CupertinoDynamicColor.resolve(
                CupertinoColors.tertiarySystemFill, context)
            : ehTheme.favnoteTextFieldBackgroundColor,
        borderRadius: BorderRadius.all(Radius.circular(glass ? 12 : 8)),
        border: glass
            ? Border.all(
                color: CupertinoDynamicColor.resolve(
                    CupertinoColors.separator, context),
                width: .5,
              )
            : null,
      ),
    );
  }

  /// 点击收藏按钮处理（列表项等入口调用）
  Future<Favcat?> addFav(
    String gid,
    String token, {
    String oriFavcat = '',
    String oriFavnote = '',
    String? galleryTitle,
    GalleryProvider? galleryProvider,
    FavRuleMissContext? ruleMissContext,
  }) async {
    logger.d('bbb add fav $gid $token');
    _favnoteController.text = oriFavnote;

    // 列表菜单点「添加到收藏夹」/「更改收藏夹」时始终打开收藏夹选择器，
    // 规则收藏有独立的顶部菜单项。
    return await selectToSave(
      gid,
      token,
      oriFavcat: oriFavcat,
      galleryTitle: galleryTitle,
      galleryProvider: galleryProvider,
      ruleMissContext: ruleMissContext,
    );
  }

  // 选择并收藏
  bool _selecting = false;

  Future<Favcat?> selectToSave(
    String gid,
    String token, {
    String oriFavcat = '',
    VoidCallback? startLoading,
    String? galleryTitle,
    FavRuleMissContext? ruleMissContext,
    GalleryProvider? galleryProvider,
  }) async {
    if (_selecting) {
      return null;
    }
    _selecting = true;
    try {
      return await _selectToSave(
        gid,
        token,
        oriFavcat: oriFavcat,
        startLoading: startLoading,
        galleryTitle: galleryTitle,
        ruleMissContext: ruleMissContext,
        galleryProvider: galleryProvider,
      );
    } finally {
      _selecting = false;
    }
  }

  @protected
  Future<void> mutateNetworkFavorite(
    String gid,
    String token, {
    String favcat = 'favdel',
    String favnote = '',
  }) =>
      galleryAddFavorite(gid, token, favcat: favcat, favnote: favnote);

  String _effectiveCurrentCategory(String gid, String oriFavcat) {
    final netCat = favoriteStates[gid]?.category;
    if (netCat != null && netCat.isNotEmpty) {
      return netCat;
    }
    final inLocal = oriFavcat == 'l' ||
        _localFavController.loacalFavs.any((item) => item.gid == gid);
    if (inLocal) {
      return 'l';
    }
    return netCat ?? oriFavcat;
  }

  Future<Favcat?> _selectToSave(
    String gid,
    String token, {
    String oriFavcat = '',
    VoidCallback? startLoading,
    String? galleryTitle,
    FavRuleMissContext? ruleMissContext,
    GalleryProvider? galleryProvider,
  }) async {
    _favnoteController.clear();
    final BuildContext context = Get.context!;

    final List<Favcat> favList = _favoriteSelectorController.favcatList;

    if (favoriteStates.isBusy(gid)) {
      throw StateError('该画廊的收藏操作正在处理中');
    }
    final epoch = favoriteStates.epoch;
    final selectedCategory = _effectiveCurrentCategory(gid, oriFavcat);
    final noteDraft = FavoriteNoteDraft();
    _noteDraft = noteDraft;
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

    Favcat? result;
    try {
      result = await showFavListDialog(
        context,
        favList,
        galleryTitle: galleryTitle,
        ruleMissContext: ruleMissContext,
      );
    } catch (e, stack) {
      logger.e('$e\n$stack');
    } finally {
      noteDraft.active = false;
      if (identical(_noteDraft, noteDraft)) {
        _noteDraft = null;
      }
    }

    logger.t('$result  ${result.runtimeType}');

    if (result != null) {
      startLoading?.call();
      logger.t('add fav $result');

      final String _favcat = result.favId;
      final String _favnote = _favcat == 'l' ? '' : await noteDraft.forSave();
      if (epoch != favoriteStates.epoch) {
        throw StateError('账号已切换');
      }
      final saved = await saveToFavcat(
        gid,
        token,
        _favcat,
        oriFavcat: selectedCategory,
        favnote: _favnote,
        galleryProvider: galleryProvider,
      );
      return result.copyWith(
        favTitle:
            saved.favTitle.isNotEmpty ? saved.favTitle : result.favTitle,
        note: _favnote.oN,
      );
    } else {
      return null;
    }
  }

  /// Directly saves a gallery into [targetFavcat] (`'0'..'9'` or `'l'`),
  /// optionally preserving [favnote] for network favorites.
  Future<Favcat> saveToFavcat(
    String gid,
    String token,
    String targetFavcat, {
    String oriFavcat = '',
    String favnote = '',
    GalleryProvider? galleryProvider,
  }) async {
    final previousCategory = _effectiveCurrentCategory(gid, oriFavcat);
    final title = _favoriteSelectorController.favcatList
            .where((value) => value.favId == targetFavcat)
            .map((value) => value.favTitle)
            .firstOrNull ??
        (targetFavcat == 'l' ? L10n.current.local_favorite : '');

    if (targetFavcat == 'l') {
      final existingLocal = _localFavController.loacalFavs
          .where((item) => item.gid == gid)
          .firstOrNull;
      final targetProvider = galleryProvider ??
          (Get.isRegistered<GalleryItemController>(tag: gid)
              ? Get.find<GalleryItemController>(tag: gid).galleryProvider
              : existingLocal);
      if (targetProvider == null) {
        throw StateError('无法添加到本地收藏');
      }
      final normalizedLocal = targetProvider.copyWith(
        localFav: true.oN,
        favcat: ''.oN,
        favTitle: ''.oN,
        favNote: ''.oN,
      );
      final isLoggedIn = Get.isRegistered<UserController>() &&
          Get.find<UserController>().isLogin;
      // If moving from network favorite to local favorite, remove network fav.
      if (isLoggedIn && isNetworkFavoriteCategory(previousCategory)) {
        await mutateNetworkFavorite(gid, token);
      }
      _localFavController.addLocalFav(normalizedLocal);
      if (Get.isRegistered<GalleryItemController>(tag: gid)) {
        Get.find<GalleryItemController>(tag: gid)
            .setFavTitleAndFavcat(favTitle: title, favcat: 'l');
      }
      _updateCounts(previousCategory, 'l');
      return Favcat(favTitle: title, favId: 'l');
    }

    await mutateNetworkFavorite(
      gid,
      token,
      favcat: targetFavcat,
      favnote: favnote,
    );
    final wasInLocal = previousCategory == 'l' ||
        _localFavController.loacalFavs.any((item) => item.gid == gid);
    if (wasInLocal) {
      _localFavController.removeFavByGid(gid);
    }
    if (Get.isRegistered<GalleryItemController>(tag: gid)) {
      Get.find<GalleryItemController>(tag: gid)
          .setFavTitleAndFavcat(favTitle: title, favcat: targetFavcat);
    }
    _updateCounts(wasInLocal ? 'l' : previousCategory, targetFavcat);
    return Favcat(favTitle: title, favId: targetFavcat, note: favnote);
  }

  Future<Favcat> addToLastFavcat(
    String gid,
    String token,
    String _lastFavcat, {
    String oriFavcat = '',
    String oriFavnote = '',
    GalleryProvider? galleryProvider,
  }) {
    return saveToFavcat(
      gid,
      token,
      _lastFavcat,
      oriFavcat: oriFavcat,
      favnote: oriFavnote,
      galleryProvider: galleryProvider,
    );
  }

  final Set<String> _dirtyCategories = {};
  bool _refreshingFavorites = false;

  void _updateCounts(String previous, String next) {
    if (previous != next) {
      if (previous.isNotEmpty) {
        _favoriteSelectorController.decrease(previous);
      }
      if (next.isNotEmpty) {
        _favoriteSelectorController.increase(next);
      }
    }
    _dirtyCategories.addAll(['a', previous, next]);
    unawaited(_refreshAffectedFavorites());
  }

  Future<void> _refreshAffectedFavorites() async {
    if (_refreshingFavorites) {
      return;
    }
    _refreshingFavorites = true;
    try {
      while (_dirtyCategories.isNotEmpty) {
        final categories = Set<String>.of(_dirtyCategories);
        _dirtyCategories.clear();
        if (!Get.isRegistered<FavoriteTabBarController>()) {
          continue;
        }
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
      await mutateNetworkFavorite(gid, token);
    } else {
      logger.t('取消本地收藏');
      _localFavController.removeFavByGid(gid);
    }
    _updateCounts(favcat, '');
  }

  /// Batch move selected favorites into [targetFavcat] (`'0'`..`'9'`).
  Future<FavoriteBatchResult> batchMove(
    List<GalleryProvider> items,
    String targetFavcat, {
    String? currentFavcat,
  }) async {
    final gids = items
        .map((e) => e.gid ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (gids.isEmpty) {
      return const FavoriteBatchResult(
        succeededGids: <String>[],
        failedGids: <String>[],
      );
    }
    final previousCategories = <String, String>{
      for (final item in items)
        if ((item.gid ?? '').isNotEmpty)
          item.gid!:
              favoriteStates[item.gid]?.category ?? item.favcat ?? '',
    };
    final targetTitle = _favoriteSelectorController.favcatList
            .where((f) => f.favId == targetFavcat)
            .map((f) => f.favTitle)
            .firstOrNull ??
        '';
    final result = await favoritesBatch(
      gids: gids,
      ddact: 'fav$targetFavcat',
      favcat: currentFavcat,
      targetFavTitle: targetTitle,
    );
    if (result.updatedFavList.isNotEmpty) {
      _favoriteSelectorController.addAllFavList(result.updatedFavList);
    } else if (result.succeededGids.isNotEmpty) {
      for (final gid in result.succeededGids) {
        final prev = previousCategories[gid] ?? '';
        if (prev != targetFavcat) {
          if (prev.isNotEmpty) {
            _favoriteSelectorController.decrease(prev);
          }
          _favoriteSelectorController.increase(targetFavcat);
        }
      }
    }
    if (result.succeededGids.isNotEmpty) {
      _dirtyCategories.addAll(<String>[
        'a',
        targetFavcat,
        if (currentFavcat != null && currentFavcat.isNotEmpty) currentFavcat,
        for (final prev in previousCategories.values)
          if (prev.isNotEmpty) prev,
      ]);
      unawaited(_refreshAffectedFavorites());
    }
    return result;
  }

  /// Batch remove selected favorites (`ddact=delete` for network, local store
  /// removal for `'l'`).
  Future<FavoriteBatchResult> batchRemove(
    List<GalleryProvider> items, {
    String? currentFavcat,
  }) async {
    final gids = items
        .map((e) => e.gid ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (gids.isEmpty) {
      return const FavoriteBatchResult(
        succeededGids: <String>[],
        failedGids: <String>[],
      );
    }
    if (currentFavcat == 'l') {
      for (final gid in gids) {
        _localFavController.removeFavByGid(gid);
        _favoriteSelectorController.decrease('l');
      }
      _dirtyCategories.add('l');
      unawaited(_refreshAffectedFavorites());
      return FavoriteBatchResult(
        succeededGids: gids,
        failedGids: const <String>[],
      );
    }
    final result = await favoritesBatch(
      gids: gids,
      ddact: 'delete',
      favcat: currentFavcat,
    );
    if (result.updatedFavList.isNotEmpty) {
      _favoriteSelectorController.addAllFavList(result.updatedFavList);
    } else if (result.succeededGids.isNotEmpty) {
      final succeededSet = result.succeededGids.toSet();
      for (final item in items) {
        if (!succeededSet.contains(item.gid)) {
          continue;
        }
        final prev = item.favcat ?? '';
        if (prev.isNotEmpty) {
          _favoriteSelectorController.decrease(prev);
        }
      }
    }
    if (result.succeededGids.isNotEmpty) {
      _dirtyCategories.addAll(<String>[
        'a',
        if (currentFavcat != null && currentFavcat.isNotEmpty) currentFavcat,
        for (final item in items)
          if ((item.favcat ?? '').isNotEmpty) item.favcat!,
      ]);
      unawaited(_refreshAffectedFavorites());
    }
    return result;
  }

  /// Updates the note on an already-favorited network gallery without changing
  /// its folder.
  Future<void> updateFavoriteNote(
    String gid,
    String token, {
    required String favcat,
    required String favnote,
  }) async {
    await galleryAddFavorite(
      gid,
      token,
      favcat: favcat,
      favnote: favnote,
    );
    _dirtyCategories.addAll(<String>['a', favcat]);
    unawaited(_refreshAffectedFavorites());
  }
}
