import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:eros_fe/common/controller/history_controller.dart';
import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/fav_rule_matcher.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/fav_rule.dart';
import 'package:eros_fe/models/favcat.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/network/request.dart';
import 'package:eros_fe/pages/controller/favorite_sel_controller.dart';
import 'package:eros_fe/utils/logger.dart';
import 'package:eros_fe/widget/desktop_gallery_actions.dart';
import 'package:get/get.dart';

typedef FavRuleReadJson = String? Function();
typedef FavRuleWriteJson = Future<void> Function(String json);
typedef FavRuleFetchApiTags = Future<List<String>> Function(
  String gid,
  String token,
);
typedef FavRuleLookupTranslation = Future<String?> Function(
  String rawTitle, {
  String? namespace,
});

/// Manages tag- and category-based favorite rules, persistence, one-step
/// favorite migration, rule evaluation, and full-tag resolution with caching.
class FavRuleService extends GetxService {
  FavRuleService({
    FavRuleReadJson? readJson,
    FavRuleWriteJson? writeJson,
    FavRuleFetchApiTags? fetchApiTags,
    FavRuleLookupTranslation? lookupTranslation,
    bool Function()? readLegacyOneStep,
    void Function(bool value)? syncLegacyOneStep,
    bool Function()? readLegacyFavPicker,
    void Function(bool value)? syncLegacyFavPicker,
  })  : _readJson = readJson ?? hiveHelper.getFavRuleConfigJson,
        _writeJson = writeJson ?? hiveHelper.setFavRuleConfigJson,
        _fetchApiTags = fetchApiTags ?? _defaultFetchApiTags,
        _lookupTranslation = lookupTranslation ?? _defaultLookupTranslation,
        _readLegacyOneStepFn = readLegacyOneStep,
        _syncLegacyOneStepFn = syncLegacyOneStep,
        _readLegacyFavPickerFn = readLegacyFavPicker,
        _syncLegacyFavPickerFn = syncLegacyFavPicker;

  static final math.Random _random = math.Random();
  static int _idCounter = 0;
  static const int _maxTagCacheEntries = 200;

  final FavRuleReadJson _readJson;
  final FavRuleWriteJson _writeJson;
  final FavRuleFetchApiTags _fetchApiTags;
  final FavRuleLookupTranslation _lookupTranslation;
  final bool Function()? _readLegacyOneStepFn;
  final void Function(bool value)? _syncLegacyOneStepFn;
  final bool Function()? _readLegacyFavPickerFn;
  final void Function(bool value)? _syncLegacyFavPickerFn;

  final Rx<FavRuleConfig> _config = const FavRuleConfig().obs;
  FavRuleConfig get config => _config.value;
  Rx<FavRuleConfig> get configRx => _config;

  bool get enabled => config.enabled;
  List<FavRule> get rules => config.rules;

  /// In-memory cache of complete normalized tags keyed by `gid`.
  final Map<String, List<NormalizedTag>> _tagCache =
      <String, List<NormalizedTag>>{};
  final Set<String> _translationEnrichedGids = <String>{};
  final Map<String, Future<List<NormalizedTag>>> _inflightFetches =
      <String, Future<List<NormalizedTag>>>{};

  @override
  void onInit() {
    super.onInit();
    loadAndMigrate();
  }

  /// Loads stored config from Hive and migrates legacy `favLongTap` /
  /// `isFavPicker` settings and schema versions once if needed.
  void loadAndMigrate() {
    FavRuleConfig loaded = const FavRuleConfig();
    var needsPersist = false;
    try {
      final raw = _readJson();
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          loaded = FavRuleConfig.fromJson(Map<String, dynamic>.from(decoded));
        }
      }
    } catch (e, s) {
      logger.w('Failed to decode fav rule config, resetting to defaults: $e\n$s');
    }

    final originalVersion = loaded.version;

    if (!loaded.migratedFromOneStep) {
      final legacyOneStep = _readLegacyOneStepFn?.call() ??
          (Get.isRegistered<EhSettingService>() &&
              Get.find<EhSettingService>().isFavLongTap.value);
      final legacyPicker = _readLegacyFavPickerFn?.call() ??
          (Get.isRegistered<EhSettingService>() &&
              Get.find<EhSettingService>().isFavPicker.value);

      // Intentionally upgrade `DEFAULT_EH_CONFIG.favPicker == false` (which was
      // hardcoded `false` for every user who never toggled the hidden wheel
      // easter egg) to the redesigned v2/v3 2x5 flat sheet (`FavPickerStyle.grid`
      // via `loaded.pickerStyle`), while preserving explicit wheel opt-in
      // (`isFavPicker == true` -> `FavPickerStyle.wheel`) and any explicit
      // `pickerStyle` (e.g. `'list'`) already present in `loaded`.
      final initialPickerStyle =
          legacyPicker ? FavPickerStyle.wheel : loaded.pickerStyle;

      if (legacyOneStep) {
        loaded = loaded.copyWith(
          version: FavRuleConfig.currentVersion,
          enabled: true,
          trigger: FavRuleTrigger.tap,
          fallback: FavRuleFallback.last,
          pickerStyle: initialPickerStyle,
          migratedFromOneStep: true,
          showMigrationBanner: true,
        );
        // Consume legacy one-step flag so disabling Rule Favorites later will
        // not unexpectedly auto-save via the retired `isFavLongTap` flag.
        final syncOneStep = _syncLegacyOneStepFn;
        if (syncOneStep != null) {
          syncOneStep(false);
        } else if (Get.isRegistered<EhSettingService>()) {
          Get.find<EhSettingService>().isFavLongTap.value = false;
        }
      } else {
        loaded = loaded.copyWith(
          version: FavRuleConfig.currentVersion,
          pickerStyle: initialPickerStyle,
          migratedFromOneStep: true,
        );
      }
      needsPersist = true;
    }

    // One-time v2 schema upgrade (build 216/218 -> v2): promote heart-tap to
    // rule evaluation and reserve long-press for manual folder selection.
    if (originalVersion < FavRuleConfig.currentVersion) {
      loaded = loaded.copyWith(
        version: FavRuleConfig.currentVersion,
        trigger: FavRuleTrigger.tap,
      );
      needsPersist = true;
    }

    _config.value = loaded;
    if (needsPersist) {
      unawaited(_persist(loaded));
    }
  }

  Future<void> _update(FavRuleConfig next) async {
    _config.value = next;
    await _persist(next);
  }

  Future<void> _persist(FavRuleConfig value) async {
    try {
      await _writeJson(jsonEncode(value.toJson()));
    } catch (e, s) {
      logger.e('Failed to persist fav rule config: $e\n$s');
    }
  }

  String generateRuleId() {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final seq = (++_idCounter).toRadixString(36);
    final rnd = _random.nextInt(0x7fffffff).toRadixString(36);
    return 'fr_${ts}_${seq}_$rnd';
  }

  Future<void> setEnabled(bool value) =>
      _update(config.copyWith(enabled: value));

  Future<void> setTrigger(FavRuleTrigger value) =>
      _update(config.copyWith(trigger: value));

  Future<void> setFallback(FavRuleFallback value) =>
      _update(config.copyWith(fallback: value));

  Future<void> setFallbackFavcat(String favcat) =>
      _update(config.copyWith(fallbackFavcat: favcat));

  Future<void> setExisting(FavRuleExisting value) =>
      _update(config.copyWith(existing: value));

  Future<void> setListMenuStyle(FavListMenuStyle value) =>
      _update(config.copyWith(listMenuStyle: value));

  Future<void> setPickerStyle(FavPickerStyle value) async {
    await _update(config.copyWith(pickerStyle: value));
    final isWheel = value == FavPickerStyle.wheel;
    final syncPicker = _syncLegacyFavPickerFn;
    if (syncPicker != null) {
      syncPicker(isWheel);
    } else if (Get.isRegistered<EhSettingService>()) {
      Get.find<EhSettingService>().isFavPicker.value = isWheel;
    }
  }

  Future<void> dismissMigrationBanner() =>
      _update(config.copyWith(showMigrationBanner: false));

  static String rememberComboKey(String rawCategory, String favcat) {
    final canonical =
        canonicalizeFavRuleCategory(rawCategory) ?? rawCategory.trim();
    return '$canonical->$favcat';
  }

  bool isRememberComboDismissed(String? rawCategory, String favcat) {
    if (rawCategory == null || rawCategory.trim().isEmpty || favcat.isEmpty) {
      return false;
    }
    return config.dismissedRememberKeys
        .contains(rememberComboKey(rawCategory, favcat));
  }

  Future<void> dismissRememberCombo(String rawCategory, String favcat) async {
    final key = rememberComboKey(rawCategory, favcat);
    if (config.dismissedRememberKeys.contains(key)) {
      return;
    }
    final next = <String>[...config.dismissedRememberKeys, key];
    await _update(
      config.copyWith(
        dismissedRememberKeys: List<String>.unmodifiable(next),
      ),
    );
  }

  /// Counts rules (enabled or disabled) that reference [rawCategory].
  int countRulesUsingCategory(String? rawCategory) {
    final canonical = canonicalizeFavRuleCategory(rawCategory);
    if (canonical == null) {
      return 0;
    }
    var count = 0;
    for (final rule in config.rules) {
      final uses = rule.conditions.any(
        (c) =>
            c.isCategory &&
            c.categoryValues.any(
              (v) => canonicalizeFavRuleCategory(v) == canonical,
            ),
      );
      if (uses) {
        count++;
      }
    }
    return count;
  }

  /// Whether an enabled positive pure-category rule already covers [rawCategory].
  bool hasEnabledPureCategoryRuleFor(String? rawCategory) {
    final canonical = canonicalizeFavRuleCategory(rawCategory);
    if (canonical == null) {
      return false;
    }
    return config.rules.any(
      (r) =>
          r.enabled &&
          r.conditions.isNotEmpty &&
          r.conditions.every((c) => c.isCategory && !c.negated) &&
          r.conditions.any(
            (c) => c.categoryValues.any(
              (v) => canonicalizeFavRuleCategory(v) == canonical,
            ),
          ),
    );
  }

  /// Extracts up to [maxCount] high-signal chips for Panel ②'s bottom miss strip:
  /// puts the gallery's `category` first (when canonical), followed by key tags.
  List<NormalizedTag> extractSuggestionTags(
    GalleryProvider provider, {
    int maxCount = 4,
  }) {
    final all = resolveCachedFullTags(provider) ??
        FavRuleMatcher.extractAvailableTags(provider);
    if (all.isEmpty) {
      return const <NormalizedTag>[];
    }
    const preferredNs = <String>[
      kFavRuleCategoryNamespace,
      'parody',
      'language',
      'artist',
      'group',
      'character',
      'female',
      'male',
      'cosplayer',
    ];
    final result = <NormalizedTag>[];
    final seen = <String>{};
    for (final ns in preferredNs) {
      for (final tag in all) {
        if (tag.namespace == ns && seen.add(tag.key)) {
          result.add(tag);
          if (result.length >= maxCount) {
            return result;
          }
        }
      }
    }
    for (final tag in all) {
      if (seen.add(tag.key)) {
        result.add(tag);
        if (result.length >= maxCount) {
          break;
        }
      }
    }
    return result;
  }

  bool get _anyRuleUsesTranslation => config.rules.any(
        (r) => r.enabled && r.conditions.any((c) => c.matchTranslation),
      );

  bool _tagsHaveMissingTranslations(List<NormalizedTag> tags) => tags.any(
        (t) => !t.isCategory && t.translation.isEmpty,
      );

  bool _needsTranslationLookup(String? gid, List<NormalizedTag> tags) =>
      _anyRuleUsesTranslation &&
      _tagsHaveMissingTranslations(tags) &&
      (gid == null || gid.isEmpty || !_translationEnrichedGids.contains(gid));

  Future<FavRule> addRule(FavRule rule) async {
    final normalized = rule.id.isEmpty ? rule.copyWith(id: generateRuleId()) : rule;
    final nextRules = <FavRule>[...config.rules, normalized];
    // Auto-enable when user adds their first rule so it works immediately.
    final nextEnabled = config.enabled || config.rules.isEmpty;
    if (normalized.conditions.any((c) => c.matchTranslation)) {
      _evictUntranslatedCacheEntries();
    }
    await _update(config.copyWith(rules: nextRules, enabled: nextEnabled));
    return normalized;
  }

  Future<void> updateRule(FavRule updated) async {
    final nextRules = config.rules
        .map((r) => r.id == updated.id ? updated : r)
        .toList();
    if (updated.conditions.any((c) => c.matchTranslation)) {
      _evictUntranslatedCacheEntries();
    }
    await _update(config.copyWith(rules: nextRules));
  }

  void _evictUntranslatedCacheEntries() {
    _translationEnrichedGids.clear();
  }

  Future<void> deleteRule(String ruleId) async {
    final nextRules = config.rules.where((r) => r.id != ruleId).toList();
    await _update(config.copyWith(rules: nextRules));
  }

  /// Removes a newly added rule during "Undo" and, when [restoreDisabled] is
  /// true and no rules remain, restores `enabled: false` so auto-enabling the
  /// first rule does not leave fallback modes active after undo.
  Future<void> undoAddedRule(
    String ruleId, {
    bool restoreDisabled = false,
  }) async {
    if (!config.rules.any((r) => r.id == ruleId)) {
      return;
    }
    final nextRules = config.rules.where((r) => r.id != ruleId).toList();
    final nextEnabled =
        !(restoreDisabled && nextRules.isEmpty) && config.enabled;
    await _update(config.copyWith(rules: nextRules, enabled: nextEnabled));
  }

  Future<void> toggleRule(String ruleId, bool enabled) async {
    final nextRules = config.rules
        .map((r) => r.id == ruleId ? r.copyWith(enabled: enabled) : r)
        .toList();
    if (enabled) {
      _evictUntranslatedCacheEntries();
    }
    await _update(config.copyWith(rules: nextRules));
  }

  Future<void> reorderRules(
    int oldIndex,
    int newIndex, {
    bool adjustNewIndex = true,
  }) async {
    final list = List<FavRule>.of(config.rules);
    if (oldIndex < 0 || oldIndex >= list.length) {
      return;
    }
    var targetIndex = newIndex;
    if (adjustNewIndex && targetIndex > oldIndex) {
      targetIndex -= 1;
    }
    targetIndex = targetIndex.clamp(0, list.length - 1);
    if (oldIndex == targetIndex) {
      return;
    }
    final moved = list.removeAt(oldIndex);
    list.insert(targetIndex, moved);
    await _update(config.copyWith(rules: list));
  }

  Future<void> recordHit(String ruleId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    var changed = false;
    final nextRules = config.rules.map((r) {
      if (r.id == ruleId) {
        changed = true;
        return r.copyWith(hitCount: r.hitCount + 1, lastHitAt: now);
      }
      return r;
    }).toList();
    if (changed) {
      await _update(config.copyWith(rules: nextRules));
    }
  }

  /// Stores complete normalized tags for [gid] in memory so list-view menus
  /// can reuse them without calling `gdata`.
  void cacheTagsForGallery(GalleryProvider provider) {
    final gid = provider.gid;
    if (gid == null || gid.isEmpty || !FavRuleMatcher.hasCompleteTags(provider)) {
      return;
    }
    final tags = FavRuleMatcher.extractAvailableTags(provider);
    if (tags.isNotEmpty) {
      _putCache(gid, tags);
    }
  }

  void _putCache(
    String gid,
    List<NormalizedTag> tags, {
    bool markTranslationEnriched = false,
  }) {
    _tagCache.remove(gid);
    _tagCache[gid] = tags;
    if (markTranslationEnriched) {
      _translationEnrichedGids.add(gid);
    } else {
      _translationEnrichedGids.remove(gid);
    }
    while (_tagCache.length > _maxTagCacheEntries) {
      final evicted = _tagCache.keys.first;
      _tagCache.remove(evicted);
      _translationEnrichedGids.remove(evicted);
    }
  }

  static int _completeTagCount(GalleryProvider provider) {
    final groups = provider.tagGroup;
    if (groups != null && groups.isNotEmpty) {
      var total = 0;
      for (final group in groups) {
        total += group.galleryTags.length;
      }
      if (total > 0) {
        return total;
      }
    }
    final api = provider.tagsFromApi;
    if (api != null && api.isNotEmpty) {
      return api.length;
    }
    return 0;
  }

  static int _countTranslatedGroupTags(GalleryProvider provider) {
    final groups = provider.tagGroup;
    if (groups == null || groups.isEmpty) {
      return 0;
    }
    var count = 0;
    for (final group in groups) {
      for (final tag in group.galleryTags) {
        if (tag.tagTranslat.trim().isNotEmpty) {
          count++;
        }
      }
    }
    return count;
  }

  static int _countTranslatedNormalizedTags(List<NormalizedTag> tags) {
    var count = 0;
    for (final tag in tags) {
      if (!tag.isCategory && tag.translation.isNotEmpty) {
        count++;
      }
    }
    return count;
  }

  static int _countNonCategoryTags(List<NormalizedTag> tags) {
    var count = 0;
    for (final tag in tags) {
      if (!tag.isCategory) {
        count++;
      }
    }
    return count;
  }

  /// Attempts to obtain complete tags synchronously from [provider], the
  /// in-memory cache, any live detail page, or local browsing history.
  List<NormalizedTag>? resolveCachedFullTags(GalleryProvider provider) {
    final gid = provider.gid;
    final cached = (gid != null && gid.isNotEmpty) ? _tagCache[gid] : null;
    if (FavRuleMatcher.hasCompleteTags(provider)) {
      if (cached != null &&
          _countNonCategoryTags(cached) == _completeTagCount(provider) &&
          (!_tagsHaveMissingTranslations(cached) ||
              _countTranslatedGroupTags(provider) <=
                  _countTranslatedNormalizedTags(cached))) {
        return FavRuleMatcher.ensureCategoryTag(cached, provider.category);
      }
      final tags = FavRuleMatcher.extractAvailableTags(provider);
      if (gid != null && gid.isNotEmpty && tags.isNotEmpty) {
        _putCache(gid, tags);
      }
      return tags;
    }
    if (gid == null || gid.isEmpty) {
      return null;
    }
    if (cached != null) {
      return FavRuleMatcher.ensureCategoryTag(cached, provider.category);
    }
    final liveProvider = DesktopGalleryActions.livePageFor(gid)?.gState.galleryProvider;
    if (liveProvider != null && FavRuleMatcher.hasCompleteTags(liveProvider)) {
      final tags = FavRuleMatcher.ensureCategoryTag(
        FavRuleMatcher.extractAvailableTags(liveProvider),
        provider.category ?? liveProvider.category,
      );
      if (tags.isNotEmpty) {
        _putCache(gid, tags);
        return tags;
      }
    }
    if (Get.isRegistered<HistoryController>()) {
      final history = Get.find<HistoryController>()
          .histories
          .firstWhereOrNull((h) => h.gid == gid);
      if (history != null && FavRuleMatcher.hasCompleteTags(history)) {
        final tags = FavRuleMatcher.ensureCategoryTag(
          FavRuleMatcher.extractAvailableTags(history),
          provider.category ?? history.category,
        );
        if (tags.isNotEmpty) {
          _putCache(gid, tags);
          return tags;
        }
      }
    }
    return null;
  }

  /// Synchronously evaluates rules against [provider] using the best tags
  /// already available locally (no network).
  FavRuleEvalResult evaluateGallerySync(GalleryProvider provider) {
    final full = resolveCachedFullTags(provider);
    final tags = full ?? FavRuleMatcher.extractAvailableTags(provider);
    return FavRuleMatcher.evaluate(config.rules, tags);
  }

  /// Whether evaluating [provider] in a list menu needs an async lookup
  /// (either `gdata` network fetch or Isar translation enrichment).
  bool needsAsyncTagFetch(GalleryProvider provider) {
    if (!config.enabled || config.enabledRuleCount == 0) {
      return false;
    }
    final cached = resolveCachedFullTags(provider);
    if (cached != null) {
      return _needsTranslationLookup(provider.gid, cached);
    }
    return FavRuleMatcher.needsFullTagFetch(provider, config.rules);
  }

  /// Evaluates rules against [provider], fetching full tags via `gdata` when
  /// list-card tags are incomplete and enriching translations when needed.
  Future<FavRuleEvalResult> evaluateGalleryWithFetch(
    GalleryProvider provider,
  ) async {
    if (!config.enabled || config.enabledRuleCount == 0) {
      return FavRuleEvalResult.miss;
    }
    final cachedFull = resolveCachedFullTags(provider);
    if (cachedFull != null) {
      final enriched = await _enrichTranslationsIfNeeded(
        provider.gid ?? '',
        cachedFull,
      );
      return FavRuleMatcher.evaluate(config.rules, enriched);
    }
    if (!FavRuleMatcher.needsFullTagFetch(provider, config.rules)) {
      return FavRuleMatcher.evaluate(
        config.rules,
        FavRuleMatcher.extractAvailableTags(provider),
      );
    }

    final gid = provider.gid ?? '';
    final token = provider.token ?? '';
    if (gid.isEmpty || token.isEmpty) {
      return FavRuleMatcher.evaluate(
        config.rules,
        FavRuleMatcher.extractAvailableTags(provider),
      );
    }

    final fetched = await _fetchAndCacheFullTags(
      gid,
      token,
      providerCategory: provider.category,
    );
    return FavRuleMatcher.evaluate(
      config.rules,
      FavRuleMatcher.ensureCategoryTag(fetched, provider.category),
    );
  }

  Future<List<NormalizedTag>> _enrichTranslationsIfNeeded(
    String gid,
    List<NormalizedTag> tags,
  ) async {
    if (!_needsTranslationLookup(gid, tags)) {
      return tags;
    }
    final enriched = <NormalizedTag>[];
    var anyFound = false;
    var lookupFailed = false;
    for (final tag in tags) {
      if (tag.isCategory || tag.translation.isNotEmpty) {
        enriched.add(tag);
        continue;
      }
      String? trans;
      try {
        trans = await _lookupTranslation(
          tag.rawTitle,
          namespace: tag.namespace.isEmpty ? null : tag.namespace,
        );
      } catch (_) {
        // Isar may be uninitialized in unit tests; ignore gracefully.
        lookupFailed = true;
      }
      if (trans != null && trans.isNotEmpty) {
        anyFound = true;
        final cleaned = FavRuleMatcher.cleanTranslation(trans);
        enriched.add(
          NormalizedTag(
            namespace: tag.namespace,
            title: tag.title,
            rawTitle: tag.rawTitle,
            translation: FavRuleMatcher.normalize(cleaned),
            rawTranslation: cleaned,
          ),
        );
      } else {
        enriched.add(tag);
      }
    }
    if (gid.isNotEmpty) {
      if (anyFound) {
        _putCache(gid, enriched, markTranslationEnriched: !lookupFailed);
      } else if (!lookupFailed) {
        _translationEnrichedGids.add(gid);
      }
    }
    return enriched;
  }

  Future<List<NormalizedTag>> _fetchAndCacheFullTags(
    String gid,
    String token, {
    String? providerCategory,
  }) {
    final existing = _inflightFetches[gid];
    if (existing != null) {
      return existing;
    }
    late final Future<List<NormalizedTag>> future;
    future = () async {
      try {
        final apiTags = await _fetchApiTags(gid, token);
        final needsTrans = config.rules.any(
          (r) => r.enabled && r.conditions.any((c) => c.matchTranslation),
        );
        final transMap = <String, String>{};
        var lookupFailed = false;
        if (needsTrans && apiTags.isNotEmpty) {
          for (final raw in apiTags) {
            final parsed = FavRuleMatcher.parseApiTag(raw);
            if (parsed.isCategory) {
              continue;
            }
            try {
              final name = await _lookupTranslation(
                parsed.rawTitle,
                namespace: parsed.namespace.isEmpty ? null : parsed.namespace,
              );
              if (name != null && name.isNotEmpty) {
                transMap[parsed.key] = name;
              }
            } catch (_) {
              // Isar may be uninitialized in unit tests; ignore gracefully.
              lookupFailed = true;
            }
          }
        }
        final normalized = FavRuleMatcher.ensureCategoryTag(
          FavRuleMatcher.fromApiTags(
            apiTags,
            translationByKey: transMap.isEmpty ? null : transMap,
          ),
          providerCategory,
        );
        if (normalized.isNotEmpty) {
          _putCache(
            gid,
            normalized,
            markTranslationEnriched: needsTrans && !lookupFailed,
          );
        }
        return normalized;
      } finally {
        if (identical(_inflightFetches[gid], future)) {
          _inflightFetches.remove(gid);
        }
      }
    }();
    _inflightFetches[gid] = future;
    return future;
  }

  static Future<String?> _defaultLookupTranslation(
    String rawTitle, {
    String? namespace,
  }) async {
    final found = await isarHelper.findTagTranslate(
      rawTitle,
      namespace: namespace,
    );
    return found?.name;
  }

  static Future<List<String>> _defaultFetchApiTags(
    String gid,
    String token,
  ) async {
    final reqJson = jsonEncode(<String, dynamic>{
      'method': 'gdata',
      'gidlist': <List<Object>>[
        <Object>[int.tryParse(gid) ?? gid, token],
      ],
      'namespace': 1,
    });
    final response = await postEhApi(reqJson);
    final decoded = jsonDecode(response.toString());
    if (decoded is! Map) {
      return const <String>[];
    }
    final list = decoded['gmetadata'];
    if (list is! List || list.isEmpty || list.first is! Map) {
      return const <String>[];
    }
    final rawTags = (list.first as Map)['tags'];
    if (rawTags is! List) {
      return const <String>[];
    }
    return rawTags.map((e) => e.toString()).toList();
  }

  /// Evaluates a single candidate [rule] against all locally stored history
  /// galleries (for the edit-page hit preview).
  List<GalleryProvider> matchHistoryGalleries(FavRule rule) {
    if (!Get.isRegistered<HistoryController>() || rule.conditions.isEmpty) {
      return const <GalleryProvider>[];
    }
    final history = Get.find<HistoryController>().histories;
    final matched = <GalleryProvider>[];
    for (final gallery in history) {
      final tags = resolveCachedFullTags(gallery) ??
          FavRuleMatcher.extractAvailableTags(gallery);
      if (tags.isEmpty) {
        continue;
      }
      if (FavRuleMatcher.matchRule(rule, tags) != null) {
        matched.add(gallery);
      }
    }
    return matched;
  }

  /// Resolves the synced display title for a favorite category (`'0'..'9'` or `'l'`).
  String favTitleFor(String favcat) {
    if (Get.isRegistered<FavoriteSelectorController>()) {
      final favs = Get.find<FavoriteSelectorController>().favcatList;
      final found = favs.firstWhereOrNull((f) => f.favId == favcat);
      if (found != null && found.favTitle.isNotEmpty) {
        return found.favTitle;
      }
    }
    if (favcat == 'l') {
      try {
        return L10n.current.local_favorite;
      } catch (_) {
        return 'Local Favorites';
      }
    }
    return 'Favorites $favcat';
  }

  /// Returns the synced gallery count for [favcat], if available.
  int? favCountFor(String favcat) {
    if (!Get.isRegistered<FavoriteSelectorController>()) {
      return null;
    }
    final favs = Get.find<FavoriteSelectorController>().favcatList;
    return favs.firstWhereOrNull((f) => f.favId == favcat)?.totNum;
  }

  /// Returns all selectable favorite categories (`'0'..'9'`, plus `'l'` if available).
  List<Favcat> availableFavcats({bool includeLocal = false}) {
    if (Get.isRegistered<FavoriteSelectorController>()) {
      final favs = Get.find<FavoriteSelectorController>()
          .favcatList
          .where((f) => f.favId != 'a' && (includeLocal || f.favId != 'l'))
          .toList();
      if (favs.isNotEmpty) {
        return favs;
      }
    }
    return <Favcat>[
      for (var i = 0; i <= 9; i++)
        Favcat(favId: '$i', favTitle: 'Favorites $i', totNum: 0),
      if (includeLocal)
        Favcat(
          favId: 'l',
          favTitle: favTitleFor('l'),
          totNum: 0,
        ),
    ];
  }

  void clearTagCache() {
    _tagCache.clear();
    _translationEnrichedGids.clear();
  }
}
