import 'dart:async';

import 'package:eros_fe/common/controller/cache_controller.dart';
import 'package:eros_fe/common/controller/favorite_state_store.dart';
import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/fav_rule_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/extension.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/fav_rule.dart';
import 'package:eros_fe/network/api.dart';
import 'package:eros_fe/network/favorite_mutation.dart';
import 'package:eros_fe/pages/controller/fav_controller.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_controller.dart';
import 'package:eros_fe/pages/item/controller/galleryitem_controller.dart';
import 'package:eros_fe/pages/setting/fav_rule/fav_rule_edit_page.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/utils/logger.dart';
import 'package:eros_fe/utils/toast.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:eros_fe/widget/fav_rule_toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import 'gallery_page_state.dart';

class GalleryFavController extends GetxController {
  GalleryFavController({String? galleryTag})
      : galleryTag = galleryTag ?? pageCtrlTag;

  final String galleryTag;

  final RxBool _isLoading = false.obs;

  bool get isLoading => _isLoading.value;

  set isLoading(bool value) => _isLoading.value = value;
  String favnote = '';

  final EhSettingService _ehSettingService = Get.find();
  FavRuleService? get _favRuleService =>
      Get.isRegistered<FavRuleService>() ? Get.find<FavRuleService>() : null;

  /// Temporarily highlighted tag outlines on the detail page while the
  /// rule-favorite feedback banner is visible (key = normalized `ns:title`).
  final RxMap<String, Color> highlightedTagColors = <String, Color>{}.obs;

  late GalleryPageController _pageController;
  GalleryPageState get _pageState => _pageController.gState;

  final CacheController cacheController = Get.find();

  GalleryItemController get _itemController =>
      Get.find(tag: _pageController.gState.gid);

  bool get isRegItemController =>
      Get.isRegistered<GalleryItemController>(tag: _pageController.gState.gid);

  final FavController favController = Get.find();

  @override
  void onInit() {
    super.onInit();
    _pageController = Get.find(tag: galleryTag);

    _localFav.value = _pageState.localFav;

    // _favTitle 初始化
    if (_pageState.galleryProvider != null &&
        _pageState.galleryProvider?.favTitle != null &&
        _pageState.galleryProvider!.favTitle!.isNotEmpty) {
      _favTitle.value = _pageState.galleryProvider?.favTitle ?? '';
    } else {
      final ctx = Get.context;
      _favTitle.value =
          (localFav && ctx != null) ? L10n.of(ctx).local_favorite : '';
    }

    // _favcat初始化
    if (_pageState.galleryProvider != null &&
        _pageState.galleryProvider?.favcat != null &&
        _pageState.galleryProvider!.favcat!.isNotEmpty) {
      _favcat.value = _pageState.galleryProvider?.favcat ?? '';
    } else {
      _favcat.value = localFav ? 'l' : '';
    }

    final provider = _pageState.galleryProvider;
    if (provider != null) {
      _favRuleService?.cacheTagsForGallery(provider);
    }
  }

  @override
  void onClose() {
    highlightedTagColors.clear();
    super.onClose();
  }

  final RxBool _localFav = false.obs;

  bool get localFav => _pageState.localFav;

  final RxString _favTitle =
      (Get.context != null ? L10n.of(Get.context!).notFav : '').obs;
  String get favTitle {
    if (localFav && favcat == 'l') {
      final ctx = Get.context;
      if (ctx != null) {
        return L10n.of(ctx).local_favorite;
      }
    }
    return favoriteStates[_pageState.gid]?.title ??
        _pageState.galleryProvider?.favTitle ??
        _favTitle.value;
  }

  final RxString _favcat = ''.obs;
  int _favMutationSeq = 0;

  String get favcat {
    final category = favoriteStates[_pageState.gid]?.category ??
        _pageState.galleryProvider?.favcat ??
        _favcat.value;
    return category.isEmpty && localFav ? 'l' : category;
  }

  FavoriteUndoSnapshot _captureUndoSnapshot() => favoriteStates.snapshotForUndo(
        _pageState.gid,
        expectedFavcat: favcat,
        controllerMutationSeq: _favMutationSeq,
      );

  void setFav(String favcat, String favtitle) {
    _favMutationSeq++;
    favoriteStates.recordMutation(_pageState.gid);
    _favTitle.value = favtitle;
    _favcat.value = favcat;
    _pageState.localFav = favcat == 'l';
    if (favcat.isNotEmpty) {
      _ehSettingService.lastFavcat = favcat;
    }

    try {
      if (isRegItemController) {
        _itemController.setFavTitleAndFavcat(
            favTitle: favTitle, favcat: favcat);
      }
      _pageState.galleryProvider = _pageState.galleryProvider
          ?.copyWith(favcat: favcat.oN, favTitle: favtitle.oN);
    } catch (_) {
      // Optional list-item sync when detail page is opened standalone.
    }
  }

  bool get isFav => favcat.isNotEmpty || localFav;

  String get _galleryDisplayTitle {
    final p = _pageState.galleryProvider;
    if (p == null) {
      return '';
    }
    if (p.japaneseTitle?.isNotEmpty ?? false) {
      return p.japaneseTitle!;
    }
    return p.englishTitle ?? '';
  }

  /// 点击收藏按钮处理
  Future<void> tapFav() async {
    if (isLoading || favoriteStates.isBusy(_pageState.gid)) {
      return;
    }

    await vibrateUtil.light();

    if (favcat.isNotEmpty || _pageState.localFav) {
      logger.d(' del fav');
      await delFav();
      return;
    }

    final ruleService = _favRuleService;
    final ruleEnabled = ruleService?.enabled ?? false;
    final hasEnabledRules =
        ruleEnabled && ruleService!.config.enabledRuleCount > 0;
    final triggerIsTap =
        ruleEnabled && ruleService!.config.trigger == FavRuleTrigger.tap;

    // Default v2 behavior: when rules exist (or when tap-mode fallback is
    // last/fixed, e.g. migrated One-Step Favorite), tapping ♡ evaluates rules
    // directly -> auto-saves on hit, or opens picker on miss!
    if (triggerIsTap &&
        (hasEnabledRules ||
            ruleService.config.fallback != FavRuleFallback.picker)) {
      await _ruleFav();
      return;
    }

    // Only honor retired `isFavLongTap` if FavRuleService has not replaced it.
    final legacyOneStepActive =
        (ruleService == null || !ruleService.config.migratedFromOneStep) &&
            _ehSettingService.isFavLongTap.value &&
            _ehSettingService.lastFavcat.isNotEmpty;
    if (!ruleEnabled && legacyOneStepActive) {
      await _saveDirectly(_ehSettingService.lastFavcat);
      return;
    }

    final provider = _pageState.galleryProvider;
    final hasMatchedRule = ruleService != null &&
        provider != null &&
        ruleEnabled &&
        hasEnabledRules &&
        ruleService.evaluateGallerySync(provider).isHit;
    final missContext =
        (ruleService != null && provider != null && !hasMatchedRule)
            ? FavRuleMissContext(
                galleryTitle: _galleryDisplayTitle,
                keyTags: ruleService.extractSuggestionTags(provider),
              )
            : null;

    await _selectToSave(
      ruleMissContext: missContext,
      triggerRememberOnPick: missContext != null,
    );
  }

  // 长按事件
  Future<void> longTapFav() async {
    if (isLoading || favoriteStates.isBusy(_pageState.gid)) {
      return;
    }
    vibrateUtil.heavy();

    final ruleService = _favRuleService;
    final ruleEnabled = ruleService?.enabled ?? false;
    final hasEnabledRules =
        ruleEnabled && ruleService!.config.enabledRuleCount > 0;
    final ruleOnLongPress = ruleEnabled &&
        ruleService!.config.trigger == FavRuleTrigger.longPress &&
        (hasEnabledRules ||
            ruleService.config.fallback != FavRuleFallback.picker);

    if (ruleOnLongPress) {
      await _ruleFav();
      return;
    }

    // 在默认 trigger == FavRuleTrigger.tap（或未启用规则）时，长按 ♡ 打开手选收藏夹弹窗；
    // 仅在“尚未收藏且没有规则命中”时附带底部未命中建议与选后顺手记住提示。
    final provider = _pageState.galleryProvider;
    if (!isFav && ruleService != null && provider != null) {
      final alreadyMatched =
          hasEnabledRules && ruleService.evaluateGallerySync(provider).isHit;
      if (!alreadyMatched) {
        await _selectToSave(
          ruleMissContext: FavRuleMissContext(
            galleryTitle: _galleryDisplayTitle,
            keyTags: ruleService.extractSuggestionTags(provider),
          ),
          triggerRememberOnPick: true,
        );
        return;
      }
    }
    await _selectToSave();
  }

  /// Executes tag-rule evaluation, handles existing favorites, fallbacks,
  /// tag highlighting, and glass undo banner.
  Future<void> _ruleFav() async {
    final ruleService = _favRuleService;
    final provider = _pageState.galleryProvider;
    if (ruleService == null || provider == null) {
      await _selectToSave();
      return;
    }

    final cfg = ruleService.config;
    final hasEnabledRules = cfg.enabledRuleCount > 0;
    late final FavRuleEvalResult eval;
    if (hasEnabledRules && ruleService.needsAsyncTagFetch(provider)) {
      // Edge case: user tapped ♡ while detail HTML was still loading `tagGroup`
      // (or `tagsFromApi` lacks local Isar translations for a translation rule).
      isLoading = true;
      try {
        eval = await ruleService.evaluateGalleryWithFetch(provider);
      } catch (_) {
        eval = ruleService.evaluateGallerySync(provider);
      } finally {
        isLoading = false;
      }
    } else {
      eval = hasEnabledRules
          ? ruleService.evaluateGallerySync(provider)
          : FavRuleEvalResult.miss;
    }

    final context = Get.context;
    if (context == null || !context.mounted) {
      return;
    }
    final l10n = L10n.of(context);
    final zh = Localizations.localeOf(context).languageCode == 'zh';

    if (eval.isHit) {
      final primary = eval.primary!;
      var targetFavcat = primary.rule.favcat;
      final isLoggedIn =
          Get.isRegistered<UserController>() && Get.find<UserController>().isLogin;
      if (!isLoggedIn) {
        targetFavcat = 'l';
      }

      final previousFavcat = favcat;
      final previousFavTitle = favTitle;
      final wasFav = isFav;

      // Highlight matched tags on the detail page while banner is visible.
      _applyTagHighlights(eval, context);

      if (wasFav && previousFavcat == targetFavcat) {
        final folderName = ruleService.favTitleFor(targetFavcat);
        await vibrateUtil.selection();
        showFavRuleFeedbackBanner(
          context: Get.overlayContext ?? Get.context,
          favcat: targetFavcat,
          title: l10n.fav_rule_already_in_folder(folderName),
          subtitle: _formatRuleReason(l10n, primary, zh: zh),
          subtitleWidget: buildFavRuleHitSubtitleWidget(l10n, primary, zh: zh),
          actions: <FavRuleBannerAction>[
            FavRuleBannerAction(
              label: l10n.fav_rule_change_folder,
              onPressed: () {
                highlightedTagColors.clear();
                unawaited(_selectToSave());
              },
            ),
          ],
          onDismiss: () => highlightedTagColors.clear(),
        );
        return;
      }

      if (wasFav && cfg.existing == FavRuleExisting.keep) {
        final currentName = previousFavTitle.isNotEmpty
            ? previousFavTitle
            : ruleService.favTitleFor(previousFavcat);
        await vibrateUtil.selection();
        showFavRuleFeedbackBanner(
          context: Get.overlayContext ?? Get.context,
          favcat: previousFavcat,
          title: l10n.fav_rule_kept_in_folder(currentName),
          subtitle: _formatRuleReason(l10n, primary, zh: zh),
          subtitleWidget: buildFavRuleHitSubtitleWidget(l10n, primary, zh: zh),
          actions: <FavRuleBannerAction>[
            FavRuleBannerAction(
              label: l10n.fav_rule_change_folder,
              onPressed: () {
                highlightedTagColors.clear();
                unawaited(_selectToSave());
              },
            ),
          ],
          onDismiss: () => highlightedTagColors.clear(),
        );
        return;
      }

      // Preserve existing note when moving an already-favorited network gallery.
      // Abort if the note cannot be read so an existing server note is never erased.
      var preservedNote = '';
      if (wasFav && isNetworkFavoriteCategory(previousFavcat)) {
        try {
          preservedNote = (await favController.loadFavoriteNote(
                _pageState.gid,
                provider.token ?? '',
              )) ??
              '';
        } catch (_) {
          highlightedTagColors.clear();
          showToast(
            favoriteMutationMessage(StateError('原收藏备注未能读取，未提交更改，请重试')),
          );
          await vibrateUtil.error();
          return;
        }
      }

      final saved = await _saveDirectly(targetFavcat, favnote: preservedNote);
      if (!saved) {
        highlightedTagColors.clear();
        return;
      }

      final undoSnapshot = _captureUndoSnapshot();
      var undoConsumed = false;
      unawaited(ruleService.recordHit(primary.rule.id));
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
        subtitle: _formatRuleReason(l10n, primary, zh: zh),
        subtitleWidget: buildFavRuleHitSubtitleWidget(l10n, primary, zh: zh),
        secondaryNote: secondaryNote,
        actions: <FavRuleBannerAction>[
          if (wasFav)
            FavRuleBannerAction(
              label: l10n.fav_rule_change_folder,
              isPrimary: false,
              onPressed: () {
                highlightedTagColors.clear();
                unawaited(_selectToSave());
              },
            ),
          FavRuleBannerAction(
            label: l10n.fav_rule_undo,
            onPressed: () {
              if (undoConsumed) {
                return;
              }
              undoConsumed = true;
              highlightedTagColors.clear();
              unawaited(
                _undoFavorite(
                  undoSnapshot: undoSnapshot,
                  wasFav: wasFav,
                  previousFavcat: previousFavcat,
                  previousNote: preservedNote,
                ),
              );
            },
          ),
        ],
        onDismiss: () => highlightedTagColors.clear(),
      );
      return;
    }

    // No rule matched -> execute configured fallback (reusing cached tags).
    final keyTags = ruleService.extractSuggestionTags(provider);
    final missContext = FavRuleMissContext(
      galleryTitle: _galleryDisplayTitle,
      keyTags: keyTags,
    );

    switch (cfg.fallback) {
      case FavRuleFallback.picker:
        await _selectToSave(
          ruleMissContext: missContext,
          triggerRememberOnPick: !isFav,
        );
      case FavRuleFallback.last:
        final lastCat = _ehSettingService.lastFavcat;
        if (lastCat.isEmpty) {
          await _selectToSave(
            ruleMissContext: missContext,
            triggerRememberOnPick: !isFav,
          );
          return;
        }
        await _saveViaFallback(
          targetFavcat: lastCat,
          reasonText: l10n.fav_rule_miss_saved_last,
          keyTags: keyTags,
        );
      case FavRuleFallback.fixed:
        final fixedCat =
            cfg.fallbackFavcat.isNotEmpty ? cfg.fallbackFavcat : '0';
        await _saveViaFallback(
          targetFavcat: fixedCat,
          reasonText: l10n.fav_rule_miss_saved_fixed,
          keyTags: keyTags,
        );
    }
  }

  Future<void> _saveViaFallback({
    required String targetFavcat,
    required String reasonText,
    required List<NormalizedTag> keyTags,
  }) async {
    final context = Get.context;
    final ruleService = _favRuleService;
    if (context == null || ruleService == null) {
      return;
    }
    final l10n = L10n.of(context);
    final isLoggedIn =
        Get.isRegistered<UserController>() && Get.find<UserController>().isLogin;
    final effectiveFavcat = isLoggedIn ? targetFavcat : 'l';
    final wasFav = isFav;
    final previousFavcat = favcat;
    final previousFavTitle = favTitle;

    if (wasFav && previousFavcat == effectiveFavcat) {
      await _selectToSave(
        ruleMissContext: FavRuleMissContext(
          galleryTitle: _galleryDisplayTitle,
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
              _selectToSave(
                ruleMissContext: FavRuleMissContext(
                  galleryTitle: _galleryDisplayTitle,
                  keyTags: keyTags,
                ),
              ),
            ),
          ),
        ],
      );
      return;
    }

    var preservedNote = '';
    if (wasFav && isNetworkFavoriteCategory(previousFavcat)) {
      try {
        preservedNote = (await favController.loadFavoriteNote(
              _pageState.gid,
              _pageState.galleryProvider?.token ?? '',
            )) ??
            '';
      } catch (_) {
        showToast(
          favoriteMutationMessage(StateError('原收藏备注未能读取，未提交更改，请重试')),
        );
        await vibrateUtil.error();
        return;
      }
    }

    final saved = await _saveDirectly(effectiveFavcat, favnote: preservedNote);
    if (!saved) {
      return;
    }
    final undoSnapshot = _captureUndoSnapshot();
    var undoConsumed = false;
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
              _undoFavorite(
                undoSnapshot: undoSnapshot,
                wasFav: wasFav,
                previousFavcat: previousFavcat,
                previousNote: preservedNote,
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _undoFavorite({
    required FavoriteUndoSnapshot undoSnapshot,
    required bool wasFav,
    required String previousFavcat,
    required String previousNote,
  }) async {
    if (isLoading ||
        !undoSnapshot.canUndo(
          currentFavcat: favcat,
          currentControllerSeq: _favMutationSeq,
        )) {
      return;
    }
    if (!wasFav || previousFavcat.isEmpty) {
      await delFav();
      return;
    }
    await _saveDirectly(previousFavcat, favnote: previousNote);
  }

  String _formatRuleReason(
    L10n l10n,
    FavRuleHit hit, {
    required bool zh,
  }) {
    final ruleName = hit.rule.displayName(zh: zh);
    final tagLabel = hit.primaryTag?.displayLabel() ?? '';
    return tagLabel.isEmpty
        ? l10n.fav_rule_reason_only(ruleName)
        : l10n.fav_rule_reason_with_tag(ruleName, tagLabel);
  }

  void _applyTagHighlights(FavRuleEvalResult eval, BuildContext context) {
    final map = <String, Color>{};
    // Secondary hits first so primary hit color takes precedence on overlap.
    for (final other in eval.others) {
      final color = CupertinoDynamicColor.resolve(
        ThemeColors.favColorFor(other.rule.favcat),
        context,
      );
      for (final tag in other.matchedTags) {
        map[tag.key] = color;
      }
    }
    final primary = eval.primary;
    if (primary != null) {
      final color = CupertinoDynamicColor.resolve(
        ThemeColors.favColorFor(primary.rule.favcat),
        context,
      );
      for (final tag in primary.matchedTags) {
        map[tag.key] = color;
      }
    }
    highlightedTagColors.assignAll(map);
  }

  Future<bool> _saveDirectly(
    String targetFavcat, {
    String favnote = '',
  }) async {
    isLoading = true;
    try {
      final result = await favController.saveToFavcat(
        _pageState.gid,
        _pageState.galleryProvider?.token ?? '',
        targetFavcat,
        oriFavcat: favcat,
        favnote: favnote,
        galleryProvider: _pageState.galleryProvider,
      );
      setFav(result.favId, result.favTitle);
      await _removeGalleryCache();
      await vibrateUtil.success();
      return true;
    } catch (e) {
      showToast(favoriteMutationMessage(e));
      await vibrateUtil.error();
      return false;
    } finally {
      isLoading = false;
    }
  }

  // 选择并收藏
  Future<void> _selectToSave({
    FavRuleMissContext? ruleMissContext,
    bool triggerRememberOnPick = false,
  }) async {
    final provider = _pageState.galleryProvider;
    try {
      final result = await favController.selectToSave(
        provider?.gid ?? '0',
        provider?.token ?? '',
        oriFavcat: favcat,
        startLoading: () => isLoading = true,
        galleryTitle: _galleryDisplayTitle,
        ruleMissContext: ruleMissContext,
        galleryProvider: provider,
      );
      if (result != null) {
        highlightedTagColors.clear();
        dismissFavRuleFeedbackBanner();
        final _favcatFromRult = result.favId;
        final _favTitleFromRult = result.favTitle;
        _favTitle.value = _favTitleFromRult;
        _favcat.value = _favcatFromRult;

        _pageState.galleryProvider = _pageState.galleryProvider?.copyWith(
            favcat: _favcatFromRult.oN, favTitle: _favTitleFromRult.oN);
        setFav(_favcatFromRult, _favTitleFromRult);
        await _removeGalleryCache();
        await vibrateUtil.success();
        final ruleService = _favRuleService;
        if (triggerRememberOnPick && ruleService != null) {
          maybeShowRememberCategoryBanner(
            context: Get.overlayContext ?? Get.context,
            ruleService: ruleService,
            rawCategory: provider?.category,
            chosenFavcat: _favcatFromRult,
            chosenFavTitle: _favTitleFromRult,
          );
        }
      }
    } catch (e) {
      showToast(favoriteMutationMessage(e));
      await vibrateUtil.error();
    } finally {
      isLoading = false;
    }
  }

  /// 删除收藏
  Future<void> delFav() async {
    if (isLoading || favoriteStates.isBusy(_pageState.gid)) {
      return;
    }
    highlightedTagColors.clear();
    dismissFavRuleFeedbackBanner();
    isLoading = true;
    final deletingLocal = favcat == 'l';
    try {
      await favController.delFav(
        favcat,
        _pageState.galleryProvider?.gid ?? '0',
        _pageState.galleryProvider?.token ?? '',
      );
      if (deletingLocal) {
        _pageState.localFav = false;
      }
      _favTitle.value = '';
      _favcat.value = '';
      _pageState.galleryProvider =
          _pageState.galleryProvider?.copyWith(favcat: ''.oN, favTitle: ''.oN);
      setFav('', '');
      await _removeGalleryCache();
      await vibrateUtil.success();
    } catch (e) {
      showToast(favoriteMutationMessage(e));
      await vibrateUtil.error();
    } finally {
      isLoading = false;
    }
  }

  Future<void> _removeGalleryCache() async {
    final detailUrl = _pageState.galleryProvider?.url ??
        (isRegItemController ? _itemController.galleryProvider.url : null);
    final paths = <String>{
      if (detailUrl != null && detailUrl.isNotEmpty)
        Uri.parse(Api.getBaseUrl()).resolve(detailUrl).toString(),
      '${Api.getBaseUrl()}/favorites.php',
    };

    logger.d('delete favorite caches: ${paths.join(', ')}');
    try {
      await Future.wait(
          paths.map((path) => cacheController.clearDioCache(path: path)));
    } catch (_) {
      logger.w('Favorite saved; HTTP cache cleanup failed');
    }
  }
}
