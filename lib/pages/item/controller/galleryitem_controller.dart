import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:eros_fe/common/controller/favorite_state_store.dart';
import 'package:eros_fe/common/controller/history_controller.dart';
import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/fav_rule_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/component/setting_base.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/models/fav_rule.dart';
import 'package:eros_fe/network/favorite_mutation.dart';
import 'package:eros_fe/pages/controller/fav_controller.dart';
import 'package:eros_fe/pages/item/item_base.dart';
import 'package:eros_fe/pages/setting/fav_rule/fav_rule_edit_page.dart';
import 'package:eros_fe/pages/tab/controller/favorite/favorite_selection_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/widget/desktop_gallery_actions.dart';
import 'package:eros_fe/widget/fav_rule_toast.dart';
import 'package:eros_fe/widget/gallery_card_context_menu.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

class GalleryItemController extends GetxController {
  GalleryItemController({required GalleryProvider galleryProvider})
      : _galleryProvider = galleryProvider,
        _accountEpoch = favoriteStates.epoch {
    _favCat.value = galleryProvider.favcat ?? '';
  }

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
  int _favMutationSeq = 0;

  String get favCat {
    final category = favoriteStates[_galleryProvider.gid]?.category ??
        (_accountEpoch == favoriteStates.epoch ? _favCat.value : '');
    return category.isEmpty && (_galleryProvider.localFav ?? false)
        ? 'l'
        : category;
  }

  set favCat(String val) => _favCat.value = val;

  FavoriteUndoSnapshot _captureUndoSnapshot(String gid) =>
      favoriteStates.snapshotForUndo(
        gid,
        expectedFavcat: favCat,
        controllerMutationSeq: _favMutationSeq,
      );

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
    _favMutationSeq++;
    favoriteStates.recordMutation(_galleryProvider.gid);
    final cat = favcat ?? '';
    final isLocal = cat == 'l';
    _galleryProvider = _galleryProvider.copyWith(
      favTitle: (isLocal ? '' : favTitle).oN,
      favcat: (isLocal ? '' : cat).oN,
      localFav: isLocal.oN,
    );
    _isFav.value = cat.isNotEmpty;
    _favCat.value = isLocal ? '' : cat;
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
    _favMutationSeq++;
    favoriteStates.recordMutation(_galleryProvider.gid);
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

  String get _displayTitle {
    final jp = galleryProvider.japaneseTitle;
    if (jp != null && jp.isNotEmpty) {
      return jp;
    }
    return galleryProvider.englishTitle ?? '';
  }

  /// Adds the gallery to a favorites folder the user picks (or the last one,
  /// when that setting is on).
  Future<void> addFavorite() async {
    if (galleryProvider.gid == null || galleryProvider.token == null) {
      return;
    }
    final wasFav = isFav;
    final ruleService =
        Get.isRegistered<FavRuleService>() ? Get.find<FavRuleService>() : null;
    final alreadyMatched = ruleService != null &&
        ruleService.enabled &&
        ruleService.config.enabledRuleCount > 0 &&
        ruleService.evaluateGallerySync(galleryProvider).isHit;
    final missContext = (!wasFav && ruleService != null && !alreadyMatched)
        ? FavRuleMissContext(
            galleryTitle: _displayTitle,
            keyTags: ruleService.extractSuggestionTags(galleryProvider),
          )
        : null;
    try {
      final value = await _favDialogController.addFav(
        galleryProvider.gid!,
        galleryProvider.token!,
        galleryTitle: _displayTitle,
        galleryProvider: galleryProvider,
        ruleMissContext: missContext,
      );
      if (value == null) {
        return;
      }
      dismissFavRuleFeedbackBanner();
      setFavTitleAndFavcat(favTitle: value.favTitle, favcat: value.favId);
      await vibrateUtil.success();
      final bannerShown = !wasFav &&
          !alreadyMatched &&
          ruleService != null &&
          maybeShowRememberCategoryBanner(
            context: Get.overlayContext ?? Get.context,
            ruleService: ruleService,
            rawCategory: galleryProvider.category,
            chosenFavcat: value.favId,
            chosenFavTitle: value.favTitle,
          );
      if (!bannerShown) {
        showToast('successfully add');
      }
    } catch (e) {
      showToast(favoriteMutationMessage(e));
      await vibrateUtil.error();
    }
  }

  /// Removes the gallery from its favorites folder; false when it failed.
  Future<bool> removeFavorite() async {
    if (galleryProvider.gid == null || galleryProvider.token == null) {
      return false;
    }
    dismissFavRuleFeedbackBanner();
    try {
      await _favDialogController.delFav(galleryProvider.favcat!,
          galleryProvider.gid!, galleryProvider.token!);
    } catch (e) {
      showToast(favoriteMutationMessage(e));
      await vibrateUtil.error();
      return false;
    }
    setFavTitleAndFavcat(favTitle: '', favcat: '');
    await vibrateUtil.success();
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
        galleryProvider.gid!,
        galleryProvider.token!,
        oriFavcat: galleryProvider.favcat!,
        galleryTitle: _displayTitle,
        galleryProvider: galleryProvider,
      );
      if (value != null) {
        dismissFavRuleFeedbackBanner();
        setFavTitleAndFavcat(favTitle: '', favcat: '');
        setFavTitleAndFavcat(favTitle: value.favTitle, favcat: value.favId);
        await vibrateUtil.success();
        showToast('successfully changed');
      }
    } catch (e) {
      showToast(favoriteMutationMessage(e));
      await vibrateUtil.error();
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

  /// Applies a matched [FavRuleEvalResult] from a list or desktop menu,
  /// preserving existing favorite note when moving and offering undo.
  Future<void> applyRuleFavorite(FavRuleEvalResult eval) async {
    final primary = eval.primary;
    final gid = galleryProvider.gid;
    final token = galleryProvider.token;
    if (primary == null || gid == null || token == null) {
      return;
    }
    if (!Get.isRegistered<FavRuleService>()) {
      return;
    }
    final ruleService = Get.find<FavRuleService>();
    final context = Get.overlayContext ?? Get.context;
    if (context == null) {
      return;
    }
    final l10n = L10n.of(context);
    final zh = Localizations.localeOf(context).languageCode == 'zh';

    final isLoggedIn =
        Get.isRegistered<UserController>() && Get.find<UserController>().isLogin;
    final targetFavcat = isLoggedIn ? primary.rule.favcat : 'l';
    final wasFav = isFav;
    final previousFavcat = favCat;
    final previousFavTitle = galleryProvider.favTitle ?? '';

    if (wasFav && previousFavcat == targetFavcat) {
      showFavRuleFeedbackBanner(
        context: context,
        favcat: targetFavcat,
        title: l10n.fav_rule_already_in_folder(
          ruleService.favTitleFor(targetFavcat),
        ),
        subtitle: _ruleReasonText(l10n, primary, zh: zh),
        subtitleWidget: buildFavRuleHitSubtitleWidget(l10n, primary, zh: zh),
        actions: <FavRuleBannerAction>[
          FavRuleBannerAction(
            label: l10n.fav_rule_change_folder,
            onPressed: () => unawaited(
              _hasNetworkFavorite ? changeFavorite() : addFavorite(),
            ),
          ),
        ],
      );
      return;
    }

    if (wasFav && ruleService.config.existing == FavRuleExisting.keep) {
      final currentName = previousFavTitle.isNotEmpty
          ? previousFavTitle
          : ruleService.favTitleFor(previousFavcat);
      await vibrateUtil.selection();
      showFavRuleFeedbackBanner(
        context: Get.overlayContext ?? Get.context,
        favcat: previousFavcat,
        title: l10n.fav_rule_kept_in_folder(currentName),
        subtitle: _ruleReasonText(l10n, primary, zh: zh),
        subtitleWidget: buildFavRuleHitSubtitleWidget(l10n, primary, zh: zh),
        actions: <FavRuleBannerAction>[
          FavRuleBannerAction(
            label: l10n.fav_rule_change_folder,
            onPressed: () => unawaited(
              _hasNetworkFavorite ? changeFavorite() : addFavorite(),
            ),
          ),
        ],
      );
      return;
    }

    try {
      var preservedNote = '';
      if (wasFav && isNetworkFavoriteCategory(previousFavcat)) {
        try {
          preservedNote =
              (await _favDialogController.loadFavoriteNote(gid, token)) ?? '';
        } catch (_) {
          throw StateError('原收藏备注未能读取，未提交更改，请重试');
        }
      }

      final result = await _favDialogController.saveToFavcat(
        gid,
        token,
        targetFavcat,
        oriFavcat: previousFavcat,
        favnote: preservedNote,
        galleryProvider: galleryProvider,
      );
      setFavTitleAndFavcat(favTitle: result.favTitle, favcat: result.favId);
      final undoSnapshot = _captureUndoSnapshot(gid);
      var undoConsumed = false;
      unawaited(ruleService.recordHit(primary.rule.id));
      await vibrateUtil.success();

      final targetName = ruleService.favTitleFor(targetFavcat);
      final headline = wasFav
          ? l10n.fav_rule_moved_folder(
              previousFavTitle.isNotEmpty
                  ? previousFavTitle
                  : ruleService.favTitleFor(previousFavcat),
              targetName,
            )
          : l10n.fav_rule_saved_to_folder(targetName);
      final secondaryNote = eval.others.isNotEmpty
          ? l10n.fav_rule_other_hits_note(
              eval.others.map((h) => h.rule.displayName(zh: zh)).join('、'),
            )
          : null;

      showFavRuleFeedbackBanner(
        context: Get.overlayContext ?? Get.context,
        favcat: targetFavcat,
        title: headline,
        subtitle: _ruleReasonText(l10n, primary, zh: zh),
        subtitleWidget: buildFavRuleHitSubtitleWidget(l10n, primary, zh: zh),
        secondaryNote: secondaryNote,
        actions: <FavRuleBannerAction>[
          FavRuleBannerAction(
            label: l10n.fav_rule_undo,
            onPressed: () {
              if (undoConsumed) {
                return;
              }
              undoConsumed = true;
              unawaited(
                _undoRuleFavorite(
                  undoSnapshot: undoSnapshot,
                  gid: gid,
                  token: token,
                  wasFav: wasFav,
                  previousFavcat: previousFavcat,
                  previousNote: preservedNote,
                ),
              );
            },
          ),
        ],
      );
    } catch (e) {
      showToast(favoriteMutationMessage(e));
      await vibrateUtil.error();
    }
  }

  /// Applies [eval] when a rule matched, or executes the configured
  /// [FavRuleFallback] (`picker` / `last` / `fixed`) when no rule matched.
  Future<void> applyRuleOrFallback(FavRuleEvalResult eval) async {
    if (eval.isHit) {
      await applyRuleFavorite(eval);
      return;
    }
    final gid = galleryProvider.gid;
    final token = galleryProvider.token;
    if (gid == null || token == null) {
      return;
    }
    if (!Get.isRegistered<FavRuleService>()) {
      await (_hasNetworkFavorite ? changeFavorite() : addFavorite());
      return;
    }
    final ruleService = Get.find<FavRuleService>();
    final cfg = ruleService.config;
    final keyTags = ruleService.extractSuggestionTags(galleryProvider);
    final missContext = FavRuleMissContext(
      galleryTitle: _displayTitle,
      keyTags: keyTags,
    );

    switch (cfg.fallback) {
      case FavRuleFallback.picker:
        await _openFavoritePickerWithMissContext(missContext);
      case FavRuleFallback.last:
        final lastCat = _ehSettingService.lastFavcat;
        if (lastCat.isEmpty) {
          await _openFavoritePickerWithMissContext(missContext);
          return;
        }
        final ctx = Get.overlayContext ?? Get.context;
        if (ctx == null) {
          return;
        }
        await _saveItemViaFallback(
          targetFavcat: lastCat,
          reasonText: L10n.of(ctx).fav_rule_miss_saved_last,
          keyTags: keyTags,
        );
      case FavRuleFallback.fixed:
        final fixedCat =
            cfg.fallbackFavcat.isNotEmpty ? cfg.fallbackFavcat : '0';
        final ctx = Get.overlayContext ?? Get.context;
        if (ctx == null) {
          return;
        }
        await _saveItemViaFallback(
          targetFavcat: fixedCat,
          reasonText: L10n.of(ctx).fav_rule_miss_saved_fixed,
          keyTags: keyTags,
        );
    }
  }

  Future<void> _openFavoritePickerWithMissContext(
    FavRuleMissContext missContext,
  ) async {
    final gid = galleryProvider.gid;
    final token = galleryProvider.token;
    if (gid == null || token == null) {
      return;
    }
    final wasFav = isFav;
    final hadNetworkFav = _hasNetworkFavorite;
    final ruleService =
        Get.isRegistered<FavRuleService>() ? Get.find<FavRuleService>() : null;
    try {
      final value = await _favDialogController.addFav(
        gid,
        token,
        oriFavcat: hadNetworkFav ? (galleryProvider.favcat ?? '') : '',
        galleryTitle: _displayTitle,
        galleryProvider: galleryProvider,
        ruleMissContext: missContext,
      );
      if (value == null) {
        return;
      }
      dismissFavRuleFeedbackBanner();
      if (hadNetworkFav) {
        setFavTitleAndFavcat(favTitle: '', favcat: '');
      }
      setFavTitleAndFavcat(favTitle: value.favTitle, favcat: value.favId);
      await vibrateUtil.success();
      final bannerShown = !wasFav &&
          ruleService != null &&
          maybeShowRememberCategoryBanner(
            context: Get.overlayContext ?? Get.context,
            ruleService: ruleService,
            rawCategory: galleryProvider.category,
            chosenFavcat: value.favId,
            chosenFavTitle: value.favTitle,
          );
      if (!bannerShown) {
        showToast(hadNetworkFav ? 'successfully changed' : 'successfully add');
      }
    } catch (e) {
      showToast(favoriteMutationMessage(e));
      await vibrateUtil.error();
    }
  }

  Future<void> _saveItemViaFallback({
    required String targetFavcat,
    required String reasonText,
    required List<NormalizedTag> keyTags,
  }) async {
    final gid = galleryProvider.gid;
    final token = galleryProvider.token;
    if (gid == null || token == null || !Get.isRegistered<FavRuleService>()) {
      return;
    }
    final ruleService = Get.find<FavRuleService>();
    final context = Get.overlayContext ?? Get.context;
    if (context == null) {
      return;
    }
    final l10n = L10n.of(context);
    final isLoggedIn =
        Get.isRegistered<UserController>() && Get.find<UserController>().isLogin;
    final effectiveFavcat = isLoggedIn ? targetFavcat : 'l';
    final wasFav = isFav;
    final previousFavcat = favCat;
    final previousFavTitle = galleryProvider.favTitle ?? '';

    if (wasFav && previousFavcat == effectiveFavcat) {
      await _openFavoritePickerWithMissContext(
        FavRuleMissContext(
          galleryTitle: _displayTitle,
          keyTags: keyTags,
        ),
      );
      return;
    }

    if (wasFav && ruleService.config.existing == FavRuleExisting.keep) {
      final currentName = previousFavTitle.isNotEmpty
          ? previousFavTitle
          : ruleService.favTitleFor(previousFavcat);
      await vibrateUtil.selection();
      showFavRuleFeedbackBanner(
        context: Get.overlayContext ?? Get.context,
        favcat: previousFavcat,
        title: l10n.fav_rule_kept_in_folder(currentName),
        subtitle: reasonText,
        actions: <FavRuleBannerAction>[
          FavRuleBannerAction(
            label: l10n.fav_rule_change_folder,
            onPressed: () => unawaited(
              _openFavoritePickerWithMissContext(
                FavRuleMissContext(
                  galleryTitle: _displayTitle,
                  keyTags: keyTags,
                ),
              ),
            ),
          ),
        ],
      );
      return;
    }

    try {
      var preservedNote = '';
      if (wasFav && isNetworkFavoriteCategory(previousFavcat)) {
        try {
          preservedNote =
              (await _favDialogController.loadFavoriteNote(gid, token)) ?? '';
        } catch (_) {
          throw StateError('原收藏备注未能读取，未提交更改，请重试');
        }
      }

      final result = await _favDialogController.saveToFavcat(
        gid,
        token,
        effectiveFavcat,
        oriFavcat: previousFavcat,
        favnote: preservedNote,
        galleryProvider: galleryProvider,
      );
      setFavTitleAndFavcat(favTitle: result.favTitle, favcat: result.favId);
      final undoSnapshot = _captureUndoSnapshot(gid);
      var undoConsumed = false;
      await vibrateUtil.success();

      final folderName = ruleService.favTitleFor(effectiveFavcat);
      showFavRuleFeedbackBanner(
        context: Get.overlayContext ?? Get.context,
        favcat: effectiveFavcat,
        title: l10n.fav_rule_saved_to_folder(folderName),
        subtitle: reasonText,
        actions: <FavRuleBannerAction>[
          FavRuleBannerAction(
            label: l10n.fav_rule_create_from_tag_short,
            isPrimary: false,
            onPressed: () {
              final firstTag = keyTags.isNotEmpty ? keyTags.first : null;
              Get.toNamed<dynamic>(
                EHRoutes.favRuleEdit,
                arguments: FavRuleEditArgs(
                  initialConditions: firstTag == null
                      ? const <FavRuleCondition>[]
                      : <FavRuleCondition>[
                          FavRuleCondition.fromNormalizedTag(firstTag),
                        ],
                  initialFavcat: effectiveFavcat,
                ),
                id: detailNavigatorId,
                preventDuplicates: false,
              );
            },
          ),
          FavRuleBannerAction(
            label: l10n.fav_rule_undo,
            onPressed: () {
              if (undoConsumed) {
                return;
              }
              undoConsumed = true;
              unawaited(
                _undoRuleFavorite(
                  undoSnapshot: undoSnapshot,
                  gid: gid,
                  token: token,
                  wasFav: wasFav,
                  previousFavcat: previousFavcat,
                  previousNote: preservedNote,
                ),
              );
            },
          ),
        ],
      );
    } catch (e) {
      showToast(favoriteMutationMessage(e));
      await vibrateUtil.error();
    }
  }

  Future<void> _undoRuleFavorite({
    required FavoriteUndoSnapshot undoSnapshot,
    required String gid,
    required String token,
    required bool wasFav,
    required String previousFavcat,
    required String previousNote,
  }) async {
    if (!undoSnapshot.canUndo(
      currentFavcat: favCat,
      currentControllerSeq: _favMutationSeq,
    )) {
      return;
    }
    try {
      if (!wasFav || previousFavcat.isEmpty) {
        await _favDialogController.delFav(favCat, gid, token);
        setFavTitleAndFavcat(favTitle: '', favcat: '');
      } else {
        final restored = await _favDialogController.saveToFavcat(
          gid,
          token,
          previousFavcat,
          oriFavcat: favCat,
          favnote: previousNote,
          galleryProvider: galleryProvider,
        );
        setFavTitleAndFavcat(
          favTitle: restored.favTitle,
          favcat: restored.favId,
        );
      }
      await vibrateUtil.success();
    } catch (e) {
      showToast(favoriteMutationMessage(e));
      await vibrateUtil.error();
    }
  }

  String _ruleReasonText(L10n l10n, FavRuleHit hit, {required bool zh}) {
    final ruleName = hit.rule.displayName(zh: zh);
    final tagLabel = hit.primaryTag?.displayLabel() ?? '';
    return tagLabel.isEmpty
        ? l10n.fav_rule_reason_only(ruleName)
        : l10n.fav_rule_reason_with_tag(ruleName, tagLabel);
  }

  String _resolveGalleryUrl() {
    final rawUrl = galleryProvider.url;
    if (rawUrl != null && rawUrl.startsWith('http')) {
      return rawUrl;
    }
    var isEx = false;
    try {
      isEx = _ehSettingService.isSiteEx.value;
    } catch (_) {
      isEx = false;
    }
    final host = isEx ? 'https://exhentai.org' : 'https://e-hentai.org';
    if (rawUrl != null && rawUrl.isNotEmpty) {
      return rawUrl.startsWith('/') ? '$host$rawUrl' : '$host/$rawUrl';
    }
    return '$host/g/${galleryProvider.gid ?? ''}/${galleryProvider.token ?? ''}/';
  }

  Future<void> copyGalleryLink(BuildContext context) =>
      DesktopGalleryActions.copyLink(
        context,
        galleryProvider.copyWith(url: _resolveGalleryUrl().oN),
      );

  Future<void> _handleContextQuickFavorite(RuleMenuEvalSnapshot snap) async {
    if (galleryProvider.gid == null || galleryProvider.token == null) {
      return;
    }
    if (_hasNetworkFavorite) {
      await changeFavorite();
      return;
    }
    final ruleService =
        Get.isRegistered<FavRuleService>() ? Get.find<FavRuleService>() : null;
    final rulesActive = ruleService != null &&
        ruleService.enabled &&
        (ruleService.config.enabledRuleCount > 0 ||
            ruleService.config.fallback != FavRuleFallback.picker);
    if (!rulesActive) {
      await addFavorite();
      return;
    }

    if (snap.state == RuleMenuEvalState.hit && snap.evalResult != null) {
      await applyRuleFavorite(snap.evalResult!);
      return;
    }
    if (snap.state == RuleMenuEvalState.loading) {
      FavRuleEvalResult eval;
      try {
        eval = await ruleService.evaluateGalleryWithFetch(galleryProvider);
      } catch (_) {
        eval = ruleService.evaluateGallerySync(galleryProvider);
      }
      await applyRuleOrFallback(eval);
      return;
    }
    final syncEval = ruleService.config.enabledRuleCount > 0
        ? ruleService.evaluateGallerySync(galleryProvider)
        : FavRuleEvalResult.miss;
    await applyRuleOrFallback(syncEval);
  }

  void _openCreateRuleFromGallery() {
    final canonical = canonicalizeFavRuleCategory(galleryProvider.category);
    final args = FavRuleEditArgs(
      initialConditions: canonical != null
          ? <FavRuleCondition>[FavRuleCondition.category(<String>[canonical])]
          : const <FavRuleCondition>[],
    );
    unawaited(vibrateUtil.selection());
    Get.toNamed<dynamic>(
      EHRoutes.favRuleEdit,
      arguments: args,
      id: detailNavigatorId,
      preventDuplicates: false,
    );
  }

  /// 长按菜单（根据配置在「卡片浮层菜单」与「底部操作表」间切换）
  Future<void> _showLongPressMenu(
    BuildContext? cardContext, {
    FavoriteSelectionController? selectionController,
  }) async {
    final BuildContext? context =
        Get.overlayContext ?? cardContext ?? Get.context;
    if (context == null) {
      return;
    }
    final isHistoryItem = this.isHistoryItem;
    logger.d('isHistoryItem $isHistoryItem');

    final evalNotifier = createRuleEvalNotifier(galleryProvider);
    final useContextMenu = cardContext != null &&
        Get.isRegistered<FavRuleService>() &&
        Get.find<FavRuleService>().config.listMenuStyle ==
            FavListMenuStyle.contextMenu;

    try {
      if (useContextMenu) {
        final l10n = L10n.of(context);
        final uploader = galleryProvider.uploader?.trim() ?? '';
        final favAccent = hasFavoriteColor
            ? CupertinoDynamicColor.resolve(
                ThemeColors.favColorFor(favCat),
                context,
              )
            : null;

        final quickActions = <GalleryContextQuickAction>[
          GalleryContextQuickAction(
            label:
                _hasNetworkFavorite ? l10n.fav_rule_change_folder : l10n.favcat,
            icon: _hasNetworkFavorite
                ? CupertinoIcons.heart_fill
                : CupertinoIcons.heart,
            accentColor: favAccent,
            onPressed: () {
              final snap = evalNotifier.value;
              unawaited(_handleContextQuickFavorite(snap));
            },
          ),
          GalleryContextQuickAction(
            label: l10n.read,
            icon: CupertinoIcons.book,
            onPressed: () =>
                unawaited(DesktopGalleryActions.read(galleryProvider)),
          ),
          GalleryContextQuickAction(
            label: l10n.copy_link,
            icon: CupertinoIcons.link,
            onPressed: () => unawaited(copyGalleryLink(context)),
          ),
        ];

        final entries = <GalleryContextMenuEntry>[
          if (selectionController != null)
            GalleryContextMenuEntry(
              label: l10n.fav_select,
              icon: CupertinoIcons.checkmark_circle,
              onPressed: () =>
                  selectionController.enter(initialItem: galleryProvider),
            ),
          if (!_hasNetworkFavorite)
            GalleryContextMenuEntry(
              label: l10n.choose_favcat,
              icon: CupertinoIcons.folder,
              showChevron: true,
              onPressed: () {
                if (galleryProvider.gid == null ||
                    galleryProvider.token == null) {
                  return;
                }
                unawaited(addFavorite());
              },
            ),
          if (_hasNetworkFavorite) ...<GalleryContextMenuEntry>[
            GalleryContextMenuEntry(
              label: l10n.change_to_favorites,
              icon: CupertinoIcons.folder,
              showChevron: true,
              onPressed: () {
                if (galleryProvider.gid == null ||
                    galleryProvider.token == null) {
                  return;
                }
                unawaited(changeFavorite());
              },
            ),
            GalleryContextMenuEntry(
              label: l10n.remove_from_favorites,
              icon: CupertinoIcons.heart_slash,
              onPressed: () => unawaited(removeFavorite()),
            ),
          ],
          if (uploader.isNotEmpty)
            GalleryContextMenuEntry(
              label: l10n.filter_by_uploader,
              trailing: uploader,
              icon: CupertinoIcons.person,
              onPressed: () => unawaited(
                DesktopGalleryActions.searchUploader(galleryProvider),
              ),
            ),
          if (isHistoryItem)
            GalleryContextMenuEntry(
              label: l10n.delete,
              icon: CupertinoIcons.trash,
              destructive: true,
              sectionBreakBefore: true,
              onPressed: removeFromHistory,
            ),
        ];

        await showGalleryCardContextMenu(
          cardContext: cardContext,
          provider: galleryProvider,
          isAlreadyFav: isFav,
          currentFavcat: favCat,
          evalNotifier: evalNotifier,
          onApplyRule: (eval) => unawaited(applyRuleFavorite(eval)),
          onCreateRuleFromGallery: _openCreateRuleFromGallery,
          quickActions: quickActions,
          entries: entries,
        );
        return;
      }

      final uploader = galleryProvider.uploader?.trim() ?? '';
      unawaited(vibrateUtil.contextMenuPop());
      await showCupertinoModalPopup<void>(
          context: context,
          builder: (BuildContext sheetContext) {
            return ValueListenableBuilder<RuleMenuEvalSnapshot>(
              valueListenable: evalNotifier,
              builder: (ctx, snap, _) {
                final hasRuleRow = snap.state == RuleMenuEvalState.hit ||
                    snap.state == RuleMenuEvalState.loading ||
                    snap.state == RuleMenuEvalState.error;
                return EhActionSheet(
                  title: Text(title),
                  cancelButton: CupertinoActionSheetAction(
                      onPressed: () {
                        Get.back();
                      },
                      child: Text(L10n.of(ctx).cancel)),
                  actions: <Widget>[
                    if (hasRuleRow)
                      buildRuleFavMenuBanner(
                        context: ctx,
                        snapshot: snap,
                        isAlreadyFav: isFav,
                        currentFavcat: favCat,
                        insetPadding: false,
                        onApplyRule: (eval) {
                          Get.back();
                          unawaited(applyRuleFavorite(eval));
                        },
                      ),
                    if (selectionController != null)
                      EhActionSheetAction(
                        icon: CupertinoIcons.checkmark_circle,
                        systemIcon: 'checkmark.circle',
                        onPressed: () {
                          Get.back();
                          selectionController.enter(
                            initialItem: galleryProvider,
                          );
                        },
                        child: Text(L10n.of(ctx).fav_select),
                      ),
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
                        child: Text(L10n.of(ctx).add_to_favorites),
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
                        child: Text(L10n.of(ctx).remove_from_favorites),
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
                        child: Text(L10n.of(ctx).change_to_favorites),
                      ),
                    EhActionSheetAction(
                      icon: CupertinoIcons.book,
                      systemIcon: 'book',
                      onPressed: () {
                        Get.back();
                        unawaited(DesktopGalleryActions.read(galleryProvider));
                      },
                      child: Text(L10n.of(ctx).read),
                    ),
                    EhActionSheetAction(
                      icon: CupertinoIcons.link,
                      systemIcon: 'link',
                      onPressed: () {
                        Get.back();
                        unawaited(copyGalleryLink(context));
                      },
                      child: Text(L10n.of(ctx).copy_link),
                    ),
                    if (uploader.isNotEmpty)
                      EhActionSheetAction(
                        icon: CupertinoIcons.person,
                        systemIcon: 'person',
                        onPressed: () {
                          Get.back();
                          unawaited(
                            DesktopGalleryActions.searchUploader(
                              galleryProvider,
                            ),
                          );
                        },
                        child: Text(L10n.of(ctx).filter_by_uploader),
                      ),
                    if (snap.state != RuleMenuEvalState.hit &&
                        snap.state != RuleMenuEvalState.loading)
                      EhActionSheetAction(
                        icon: CupertinoIcons.plus_circle,
                        systemIcon: 'plus.circle',
                        onPressed: () {
                          Get.back();
                          _openCreateRuleFromGallery();
                        },
                        child: Text(
                          formatCreateRuleFromGalleryLabel(
                            ctx,
                            galleryProvider,
                          ),
                        ),
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
                        child: Text(L10n.of(ctx).delete),
                      ),
                  ],
                );
              },
            );
          });
    } finally {
      evalNotifier.dispose();
    }
  }

  void onLongPress([BuildContext? cardContext]) {
    _updateNormalColor();
    final selectionController = cardContext != null
        ? FavoriteListScope.maybeOf(cardContext)?.selection
        : null;
    if (selectionController != null && selectionController.selecting.value) {
      selectionController.toggle(galleryProvider);
      return;
    }
    unawaited(
      _showLongPressMenu(
        cardContext,
        selectionController: selectionController,
      ),
    );
  }
}
