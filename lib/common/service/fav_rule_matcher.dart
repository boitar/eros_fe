import 'package:eros_fe/models/fav_rule.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/models/gallery_tag.dart';
import 'package:eros_fe/models/simple_tag.dart';
import 'package:eros_fe/models/tag_group.dart';

/// Pure rule normalization and evaluation utilities for tag & category rule favorites.
abstract final class FavRuleMatcher {
  static final RegExp _multiSpace = RegExp(r'\s+');
  static final RegExp _markdownImage = RegExp(r'!\[[^\]]*\]\([^)]*\)');

  /// Normalizes a tag value or namespace for case-insensitive matching:
  /// lowercases, trims, converts underscores to spaces, and collapses whitespace.
  static String normalize(String raw) {
    return raw.trim().toLowerCase().replaceAll('_', ' ').replaceAll(_multiSpace, ' ');
  }

  /// Strips optional markdown image prefixes found in EhTagTranslation names.
  static String cleanTranslation(String raw) {
    return raw.replaceAll(_markdownImage, '').trim();
  }

  /// Builds a synthetic [NormalizedTag] for a gallery's `category` string,
  /// or `null` when [rawCategory] is empty.
  static NormalizedTag? categoryTagFromString(String? rawCategory) {
    if (rawCategory == null) {
      return null;
    }
    final trimmed = rawCategory.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final canonical = canonicalizeFavRuleCategory(trimmed) ?? trimmed;
    final meta = favRuleCategoryMetaFor(canonical);
    final zhLabel = meta?.zhLabel ?? '';
    return NormalizedTag(
      namespace: kFavRuleCategoryNamespace,
      title: normalize(canonical),
      rawTitle: canonical,
      translation: normalize(zhLabel),
      rawTranslation: zhLabel,
    );
  }

  /// Prepends [providerCategory] as a synthetic `category` [NormalizedTag] if
  /// non-empty and not already present in [tags].
  static List<NormalizedTag> ensureCategoryTag(
    List<NormalizedTag> tags,
    String? providerCategory,
  ) {
    final catTag = categoryTagFromString(providerCategory);
    if (catTag == null) {
      return tags;
    }
    if (tags.any((t) => t.namespace == kFavRuleCategoryNamespace)) {
      return tags;
    }
    if (tags.isEmpty) {
      return <NormalizedTag>[catTag];
    }
    return <NormalizedTag>[catTag, ...tags];
  }

  /// Parses an API tag string such as `"artist:mitsuki"` or `"misc_tag"`.
  static NormalizedTag parseApiTag(
    String raw, {
    String? translation,
  }) {
    final trimmed = raw.trim();
    final colonIndex = trimmed.indexOf(':');
    final String namespace;
    final String rawTitle;
    if (colonIndex > 0) {
      namespace = normalize(trimmed.substring(0, colonIndex));
      rawTitle = trimmed.substring(colonIndex + 1).trim();
    } else {
      namespace = '';
      rawTitle = trimmed;
    }
    if (namespace == kFavRuleCategoryNamespace) {
      final catTag = categoryTagFromString(rawTitle);
      if (catTag != null) {
        return catTag;
      }
    }
    final cleanedTrans = cleanTranslation(translation ?? '');
    return NormalizedTag(
      namespace: namespace,
      title: normalize(rawTitle),
      rawTitle: rawTitle,
      translation: normalize(cleanedTrans),
      rawTranslation: cleanedTrans,
    );
  }

  /// Parses a user-entered tag test string separated by commas, newlines, or semicolons.
  static List<NormalizedTag> parseFreeformTags(String input) {
    final parts = input
        .split(RegExp(r'[,，;\n]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    return <NormalizedTag>[
      for (final part in parts) parseApiTag(part),
    ];
  }

  /// Extracts normalized tags from [TagGroup] list (full detail-page tags).
  static List<NormalizedTag> fromTagGroups(List<TagGroup>? groups) {
    if (groups == null || groups.isEmpty) {
      return const <NormalizedTag>[];
    }
    final result = <NormalizedTag>[];
    for (final group in groups) {
      final groupNs = normalize(group.tagType ?? '');
      for (final GalleryTag tag in group.galleryTags) {
        final ns = tag.type.trim().isNotEmpty ? normalize(tag.type) : groupNs;
        final rawTitle = tag.title.trim();
        final rawTrans = cleanTranslation(tag.tagTranslat);
        if (rawTitle.isEmpty) {
          continue;
        }
        result.add(
          NormalizedTag(
            namespace: ns,
            title: normalize(rawTitle),
            rawTitle: rawTitle,
            translation: normalize(rawTrans),
            rawTranslation: rawTrans,
          ),
        );
      }
    }
    return result;
  }

  /// Extracts normalized tags from `gdata` API `tagsFromApi`.
  static List<NormalizedTag> fromApiTags(
    List<dynamic>? apiTags, {
    Map<String, String>? translationByKey,
  }) {
    if (apiTags == null || apiTags.isEmpty) {
      return const <NormalizedTag>[];
    }
    final result = <NormalizedTag>[];
    for (final item in apiTags) {
      final raw = item?.toString().trim() ?? '';
      if (raw.isEmpty) {
        continue;
      }
      final parsed = parseApiTag(raw);
      final trans = translationByKey?[parsed.key] ??
          translationByKey?[parsed.title] ??
          '';
      if (trans.isNotEmpty) {
        final cleaned = cleanTranslation(trans);
        result.add(
          NormalizedTag(
            namespace: parsed.namespace,
            title: parsed.title,
            rawTitle: parsed.rawTitle,
            translation: normalize(cleaned),
            rawTranslation: cleaned,
          ),
        );
      } else {
        result.add(parsed);
      }
    }
    return result;
  }

  /// Extracts normalized tags from list-card [SimpleTag] entries.
  /// Note: `SimpleTag` has no namespace and may be truncated by list settings.
  static List<NormalizedTag> fromSimpleTags(List<SimpleTag>? simpleTags) {
    if (simpleTags == null || simpleTags.isEmpty) {
      return const <NormalizedTag>[];
    }
    final result = <NormalizedTag>[];
    for (final tag in simpleTags) {
      final rawText = tag.text?.trim() ?? '';
      if (rawText.isEmpty) {
        continue;
      }
      final rawTrans = cleanTranslation(tag.translat ?? '');
      // Some simple tags may carry "ns:tag", handle gracefully.
      if (rawText.contains(':')) {
        result.add(parseApiTag(rawText, translation: rawTrans));
      } else {
        result.add(
          NormalizedTag(
            namespace: '',
            title: normalize(rawText),
            rawTitle: rawText,
            translation: normalize(rawTrans),
            rawTranslation: rawTrans,
          ),
        );
      }
    }
    return result;
  }

  /// Whether [provider] already holds a complete tag set with namespaces.
  static bool hasCompleteTags(GalleryProvider provider) {
    final hasGroups =
        provider.tagGroup != null && provider.tagGroup!.any((g) => g.galleryTags.isNotEmpty);
    if (hasGroups) {
      return true;
    }
    final hasApi = provider.tagsFromApi != null && provider.tagsFromApi!.isNotEmpty;
    return hasApi;
  }

  /// Extracts the best available tags synchronously from [provider], always
  /// including `provider.category` as a synthetic `category` tag when present.
  static List<NormalizedTag> extractAvailableTags(GalleryProvider provider) {
    final fromGroups = fromTagGroups(provider.tagGroup);
    if (fromGroups.isNotEmpty) {
      return ensureCategoryTag(fromGroups, provider.category);
    }
    final fromApi = fromApiTags(provider.tagsFromApi);
    if (fromApi.isNotEmpty) {
      return ensureCategoryTag(fromApi, provider.category);
    }
    final fromSimple = fromSimpleTags(provider.simpleTags);
    return ensureCategoryTag(fromSimple, provider.category);
  }

  /// Determines whether list-view evaluation on [provider] requires fetching
  /// complete tags (via history/cache/`gdata`) to guarantee deterministic priority.
  ///
  /// Returns `false` when:
  /// - [provider] already has complete tags, OR
  /// - there are no enabled rules, OR
  /// - all enabled rules only inspect `category` and [provider] already has a category, OR
  /// - the highest-priority enabled rule only uses `category` (or unnamespaced tags)
  ///   and already matches the available list-card data.
  static bool needsFullTagFetch(
    GalleryProvider provider,
    List<FavRule> rules,
  ) {
    final enabledRules =
        rules.where((r) => r.enabled && r.conditions.isNotEmpty).toList();
    if (enabledRules.isEmpty) {
      return false;
    }
    if (hasCompleteTags(provider)) {
      return false;
    }
    final hasCategory = (provider.category ?? '').trim().isNotEmpty;
    final allCategoryOnly = enabledRules.every(
      (r) => r.conditions.every((c) => c.isCategory),
    );
    if (allCategoryOnly && hasCategory) {
      return false;
    }

    final available = extractAvailableTags(provider);
    if (available.isEmpty) {
      return true;
    }

    final firstRule = enabledRules.first;
    final firstNeedsTagNamespace = firstRule.conditions.any(
      (c) => !c.isCategory && c.namespace != null && c.namespace!.isNotEmpty,
    );
    if (firstNeedsTagNamespace) {
      return true;
    }
    final firstUsesTagCondition =
        firstRule.conditions.any((c) => !c.isCategory);
    if (firstUsesTagCondition &&
        fromSimpleTags(provider.simpleTags).isEmpty &&
        firstRule.match == FavRuleMatch.all) {
      return true;
    }
    final hit = matchRule(firstRule, available);
    return hit == null;
  }

  static String _normalizeKeyPattern(String raw) {
    final idx = raw.indexOf(':');
    if (idx <= 0) {
      return normalize(raw);
    }
    final ns = normalize(raw.substring(0, idx));
    final title = normalize(raw.substring(idx + 1));
    return ns.isEmpty ? title : '$ns:$title';
  }

  static final RegExp _previewTokenSplit = RegExp(r'[\s_:]+');

  /// Splits a tag query string into non-empty separator-free tokens (splitting
  /// on whitespace, underscores, and colons) so database pre-filters match
  /// space, underscore, and inline-colon forms alike.
  static List<String> previewTokens(String rawOrNormalized) {
    if (rawOrNormalized.isEmpty) {
      return const <String>[];
    }
    return rawOrNormalized
        .split(_previewTokenSplit)
        .where((t) => t.isNotEmpty)
        .toList(growable: false);
  }

  /// Returns space and underscore storage variants for [normalized] (for
  /// example `['black hair', 'black_hair']`).
  static List<String> previewStorageVariants(String normalized) {
    if (normalized.isEmpty) {
      return const <String>[];
    }
    if (!normalized.contains(' ')) {
      return <String>[normalized];
    }
    return <String>[normalized, normalized.replaceAll(' ', '_')];
  }

  /// Builds a [NormalizedTag] from a tag translation dictionary entry
  /// (`TagTranslat`) using the same normalization and markdown-image stripping
  /// as runtime gallery tag extraction.
  static NormalizedTag normalizedTagFromTranslationEntry({
    required String namespace,
    required String key,
    String? name,
  }) {
    final ns = normalize(namespace);
    final rawTitle = key.trim();
    final cleanedTrans = cleanTranslation(name ?? '');
    return NormalizedTag(
      namespace: ns,
      title: normalize(rawTitle),
      rawTitle: rawTitle,
      translation: normalize(cleanedTrans),
      rawTranslation: cleanedTrans,
    );
  }

  /// Filters preview tag candidates using the exact same matching semantics as
  /// [matchCondition] (including underscore/space equivalence, inline
  /// `namespace:tag` syntax, and cleaned translations).
  ///
  /// Returns `(limitedMatches, totalMatchedCount)`.
  static (List<T>, int) filterPreviewCandidates<T>({
    required Iterable<T> candidates,
    required FavRuleCondition condition,
    required String Function(T) namespaceOf,
    required String Function(T) keyOf,
    required String? Function(T) translationOf,
    int limit = 40,
  }) {
    if (condition.isCategory) {
      return (const <Never>[], 0);
    }
    final rawValue = condition.value.trim();
    if (rawValue.isEmpty) {
      return (const <Never>[], 0);
    }
    final targetNs =
        condition.namespace != null && condition.namespace!.trim().isNotEmpty
            ? normalize(condition.namespace!)
            : null;
    final normalizedValue = rawValue.contains(':')
        ? _normalizeKeyPattern(rawValue)
        : normalize(rawValue);

    RegExp? compiledRegex;
    if (condition.op == FavRuleOp.regex) {
      try {
        compiledRegex = RegExp(rawValue, caseSensitive: false);
      } catch (_) {
        return (const <Never>[], 0);
      }
    }

    final matched = <T>[];
    var total = 0;
    for (final item in candidates) {
      final tag = normalizedTagFromTranslationEntry(
        namespace: namespaceOf(item),
        key: keyOf(item),
        name: translationOf(item),
      );
      if (tag.title.isEmpty || tag.namespace == kFavRuleCategoryNamespace) {
        continue;
      }
      if (targetNs != null && tag.namespace != targetNs) {
        continue;
      }
      final isHit = switch (condition.op) {
        FavRuleOp.equals => _matchesEquals(
            tag,
            normalizedValue,
            matchTranslation: condition.matchTranslation,
          ),
        FavRuleOp.contains => _matchesContains(
            tag,
            normalizedValue,
            matchTranslation: condition.matchTranslation,
          ),
        FavRuleOp.regex => _matchesRegex(
            tag,
            compiledRegex!,
            rawPattern: rawValue,
            matchTranslation: condition.matchTranslation,
          ),
      };
      if (isHit) {
        total++;
        if (matched.length < limit) {
          matched.add(item);
        }
      }
    }
    return (matched, total);
  }

  /// Parses a condition input (`value` + optional `namespace` chip) into
  /// structured components for Isar `TagTranslat` preview queries, matching
  /// [matchCondition]'s support for explicit `namespace:tag` inputs.
  static FavRuleConditionPreviewQuery parseConditionPreviewQuery({
    required String value,
    String? namespace,
  }) {
    final trimmed = value.trim();
    final explicitNs = namespace != null && namespace.trim().isNotEmpty
        ? normalize(namespace)
        : null;
    if (trimmed.isEmpty) {
      return FavRuleConditionPreviewQuery(
        rawValue: '',
        normalizedFull: '',
        explicitNamespace: explicitNs,
      );
    }
    final normalizedFull = trimmed.contains(':')
        ? _normalizeKeyPattern(trimmed)
        : normalize(trimmed);

    String? inlineNs;
    String? inlineKeyNormalized;
    String? inlineKeyRaw;
    final colonIdx = trimmed.indexOf(':');
    if (colonIdx > 0) {
      final candidateNs = normalize(trimmed.substring(0, colonIdx));
      if (candidateNs.isNotEmpty) {
        inlineNs = candidateNs;
        inlineKeyRaw = trimmed.substring(colonIdx + 1).trim();
        inlineKeyNormalized = normalize(inlineKeyRaw);
      }
    }

    String? regexNamespaceHint;
    if (explicitNs == null && trimmed.startsWith('^') && !trimmed.contains('|')) {
      final rxMatch =
          RegExp(r'^\^([a-zA-Z0-9_ ]+):').firstMatch(trimmed);
      if (rxMatch != null) {
        final hinted = normalize(rxMatch.group(1)!);
        if (hinted.isNotEmpty) {
          regexNamespaceHint = hinted;
        }
      }
    }

    return FavRuleConditionPreviewQuery(
      rawValue: trimmed,
      normalizedFull: normalizedFull,
      explicitNamespace: explicitNs,
      inlineNamespace: inlineNs,
      inlineKeyNormalized: inlineKeyNormalized,
      inlineKeyRaw: inlineKeyRaw,
      regexNamespaceHint: regexNamespaceHint,
    );
  }

  /// Evaluates a single [condition] against [tags], returning the first matching
  /// [NormalizedTag] or `null`.
  static NormalizedTag? matchCondition(
    FavRuleCondition condition,
    List<NormalizedTag> tags,
  ) {
    if (condition.isCategory) {
      final allowed = condition.categoryValues;
      if (allowed.isEmpty) {
        return null;
      }
      NormalizedTag? galleryCatTag;
      for (final tag in tags) {
        if (tag.namespace == kFavRuleCategoryNamespace) {
          galleryCatTag = tag;
          break;
        }
      }
      if (galleryCatTag == null) {
        return null;
      }
      final galleryCanonical =
          canonicalizeFavRuleCategory(galleryCatTag.rawTitle) ??
              canonicalizeFavRuleCategory(galleryCatTag.title) ??
              canonicalizeFavRuleCategory(galleryCatTag.rawTranslation);
      final inSet = allowed.any((candidate) {
        final candidateCanonical = canonicalizeFavRuleCategory(candidate);
        if (galleryCanonical != null && candidateCanonical != null) {
          return galleryCanonical == candidateCanonical;
        }
        final norm = normalize(candidate);
        return galleryCatTag!.title == norm ||
            (galleryCatTag.translation.isNotEmpty &&
                galleryCatTag.translation == norm);
      });
      if (condition.negated) {
        return inSet ? null : galleryCatTag;
      }
      return inSet ? galleryCatTag : null;
    }

    final rawValue = condition.value.trim();
    if (rawValue.isEmpty) {
      return null;
    }
    final targetNs = condition.namespace != null && condition.namespace!.isNotEmpty
        ? normalize(condition.namespace!)
        : null;
    final normalizedValue = rawValue.contains(':')
        ? _normalizeKeyPattern(rawValue)
        : normalize(rawValue);

    RegExp? compiledRegex;
    if (condition.op == FavRuleOp.regex) {
      try {
        compiledRegex = RegExp(rawValue, caseSensitive: false);
      } catch (_) {
        return null;
      }
    }

    for (final tag in tags) {
      // Strict isolation: unnamespaced ("Any tag") or regular tag conditions
      // must never accidentally match the synthetic gallery category tag.
      if (tag.namespace == kFavRuleCategoryNamespace) {
        continue;
      }
      if (targetNs != null && tag.namespace != targetNs) {
        continue;
      }
      final matched = switch (condition.op) {
        FavRuleOp.equals => _matchesEquals(
            tag,
            normalizedValue,
            matchTranslation: condition.matchTranslation,
          ),
        FavRuleOp.contains => _matchesContains(
            tag,
            normalizedValue,
            matchTranslation: condition.matchTranslation,
          ),
        FavRuleOp.regex => _matchesRegex(
            tag,
            compiledRegex!,
            rawPattern: rawValue,
            matchTranslation: condition.matchTranslation,
          ),
      };
      if (matched) {
        return tag;
      }
    }
    return null;
  }

  static bool _matchesEquals(
    NormalizedTag tag,
    String normalizedValue, {
    required bool matchTranslation,
  }) {
    if (tag.title == normalizedValue) {
      return true;
    }
    // Also accept full "namespace:title" input if user typed it with no namespace selected.
    if (normalizedValue.contains(':') && tag.key == normalizedValue) {
      return true;
    }
    if (matchTranslation && tag.translation.isNotEmpty) {
      if (tag.translation == normalizedValue) {
        return true;
      }
      if (normalizedValue.contains(':') &&
          tag.namespace.isNotEmpty &&
          '${tag.namespace}:${tag.translation}' == normalizedValue) {
        return true;
      }
    }
    return false;
  }

  static bool _matchesContains(
    NormalizedTag tag,
    String normalizedValue, {
    required bool matchTranslation,
  }) {
    if (tag.title.contains(normalizedValue)) {
      return true;
    }
    if (normalizedValue.contains(':') && tag.key.contains(normalizedValue)) {
      return true;
    }
    if (matchTranslation && tag.translation.isNotEmpty) {
      if (tag.translation.contains(normalizedValue)) {
        return true;
      }
      if (normalizedValue.contains(':') &&
          tag.namespace.isNotEmpty &&
          '${tag.namespace}:${tag.translation}'.contains(normalizedValue)) {
        return true;
      }
    }
    return false;
  }

  static bool _matchesRegex(
    NormalizedTag tag,
    RegExp regex, {
    required String rawPattern,
    required bool matchTranslation,
  }) {
    if (regex.hasMatch(tag.title) || regex.hasMatch(tag.rawTitle)) {
      return true;
    }
    if (rawPattern.contains(':') && regex.hasMatch(tag.key)) {
      return true;
    }
    if (matchTranslation &&
        tag.translation.isNotEmpty &&
        (regex.hasMatch(tag.translation) || regex.hasMatch(tag.rawTranslation))) {
      return true;
    }
    return false;
  }

  /// Evaluates a single [rule] against [tags].
  static FavRuleHit? matchRule(FavRule rule, List<NormalizedTag> tags) {
    if (rule.conditions.isEmpty || tags.isEmpty) {
      return null;
    }
    final hits = <FavRuleConditionHit>[];
    switch (rule.match) {
      case FavRuleMatch.any:
        for (final condition in rule.conditions) {
          final matched = matchCondition(condition, tags);
          if (matched != null) {
            hits.add(FavRuleConditionHit(condition: condition, tag: matched));
          }
        }
        return hits.isEmpty ? null : FavRuleHit(rule: rule, conditionHits: hits);
      case FavRuleMatch.all:
        for (final condition in rule.conditions) {
          final matched = matchCondition(condition, tags);
          if (matched == null) {
            return null;
          }
          hits.add(FavRuleConditionHit(condition: condition, tag: matched));
        }
        return FavRuleHit(rule: rule, conditionHits: hits);
    }
  }

  /// Evaluates [rules] in order against [tags]. Returns the first matching rule
  /// as [FavRuleEvalResult.primary] and any additional matches in `others`.
  static FavRuleEvalResult evaluate(
    List<FavRule> rules,
    List<NormalizedTag> tags,
  ) {
    if (rules.isEmpty || tags.isEmpty) {
      return FavRuleEvalResult.miss;
    }
    FavRuleHit? primary;
    final others = <FavRuleHit>[];
    for (final rule in rules) {
      if (!rule.enabled || rule.conditions.isEmpty) {
        continue;
      }
      final hit = matchRule(rule, tags);
      if (hit != null) {
        if (primary == null) {
          primary = hit;
        } else {
          others.add(hit);
        }
      }
    }
    if (primary == null) {
      return FavRuleEvalResult.miss;
    }
    return FavRuleEvalResult(primary: primary, others: others);
  }
}

/// Parsed query shape used by `IsarHelper.findTagTranslatesForRuleCondition`
/// so inline `namespace:title` inputs match `TagTranslat(namespace, key)`.
class FavRuleConditionPreviewQuery {
  const FavRuleConditionPreviewQuery({
    required this.rawValue,
    required this.normalizedFull,
    this.explicitNamespace,
    this.inlineNamespace,
    this.inlineKeyNormalized,
    this.inlineKeyRaw,
    this.regexNamespaceHint,
  });

  final String rawValue;
  final String normalizedFull;
  final String? explicitNamespace;
  final String? inlineNamespace;
  final String? inlineKeyNormalized;
  final String? inlineKeyRaw;
  final String? regexNamespaceHint;

  List<String> get normalizedFullTokens =>
      FavRuleMatcher.previewTokens(normalizedFull);

  List<String> get inlineKeyTokens =>
      FavRuleMatcher.previewTokens(inlineKeyNormalized ?? '');

  List<String> get normalizedFullKeyVariants =>
      FavRuleMatcher.previewStorageVariants(normalizedFull);

  List<String> get inlineKeyVariants =>
      FavRuleMatcher.previewStorageVariants(inlineKeyNormalized ?? '');

  bool get isEmpty => rawValue.isEmpty;
}
