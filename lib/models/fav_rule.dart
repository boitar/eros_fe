import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

/// Reserved synthetic namespace representing E-Hentai gallery categories.
const String kFavRuleCategoryNamespace = 'category';

/// Metadata for each of the 10 canonical E-Hentai gallery categories.
@immutable
class FavRuleCategoryMeta {
  const FavRuleCategoryMeta({
    required this.canonical,
    required this.zhLabel,
    required this.gridSubLabel,
    required this.zhPopoverSubtitle,
    required this.enPopoverSubtitle,
  });

  final String canonical;
  final String zhLabel;
  final String gridSubLabel;
  final String zhPopoverSubtitle;
  final String enPopoverSubtitle;
}

const List<FavRuleCategoryMeta> kFavRuleCategoryMetas = <FavRuleCategoryMeta>[
  FavRuleCategoryMeta(
    canonical: 'Doujinshi',
    zhLabel: '同人志',
    gridSubLabel: 'Doujinshi',
    zhPopoverSubtitle: '同人志 · 同人创作',
    enPopoverSubtitle: 'Fan-made comics & works',
  ),
  FavRuleCategoryMeta(
    canonical: 'Manga',
    zhLabel: '漫画',
    gridSubLabel: 'Manga',
    zhPopoverSubtitle: '漫画 · 商业连载与单行本',
    enPopoverSubtitle: 'Commercial manga',
  ),
  FavRuleCategoryMeta(
    canonical: 'Artist CG',
    zhLabel: '画师CG',
    gridSubLabel: 'Artist CG',
    zhPopoverSubtitle: '画师CG · 插画与画集',
    enPopoverSubtitle: 'Original artist illustrations & CG sets',
  ),
  FavRuleCategoryMeta(
    canonical: 'Game CG',
    zhLabel: '游戏CG',
    gridSubLabel: 'Game CG',
    zhPopoverSubtitle: '游戏CG · 游戏立绘与事件CG',
    enPopoverSubtitle: 'Game art & event CG archives',
  ),
  FavRuleCategoryMeta(
    canonical: 'Western',
    zhLabel: '西方',
    gridSubLabel: 'Western',
    zhPopoverSubtitle: '西方 · 欧美漫画与插画',
    enPopoverSubtitle: 'Western comics & art',
  ),
  FavRuleCategoryMeta(
    canonical: 'Non-H',
    zhLabel: '无H',
    gridSubLabel: 'Non-H',
    zhPopoverSubtitle: '无H · 全年龄',
    enPopoverSubtitle: 'All-ages · Safe for work',
  ),
  FavRuleCategoryMeta(
    canonical: 'Image Set',
    zhLabel: '图集',
    gridSubLabel: 'Image Set',
    zhPopoverSubtitle: '图集 · 综合图片合集',
    enPopoverSubtitle: 'Curated image collections',
  ),
  FavRuleCategoryMeta(
    canonical: 'Cosplay',
    zhLabel: 'Cosplay',
    gridSubLabel: '扮演',
    zhPopoverSubtitle: 'Cosplay · 角色扮演写真',
    enPopoverSubtitle: 'Cosplay photo sets',
  ),
  FavRuleCategoryMeta(
    canonical: 'Asian Porn',
    zhLabel: '亚洲',
    gridSubLabel: 'Asian Porn',
    zhPopoverSubtitle: '亚洲 · 真人写真与影像',
    enPopoverSubtitle: 'Asian photo sets',
  ),
  FavRuleCategoryMeta(
    canonical: 'Misc',
    zhLabel: '杂项',
    gridSubLabel: 'Misc',
    zhPopoverSubtitle: '杂项 · 其他未归类作品',
    enPopoverSubtitle: 'Miscellaneous works',
  ),
];

const List<String> kFavRuleCanonicalCategories = <String>[
  'Doujinshi',
  'Manga',
  'Artist CG',
  'Game CG',
  'Western',
  'Non-H',
  'Image Set',
  'Cosplay',
  'Asian Porn',
  'Misc',
];

/// Resolves any English or Chinese category alias (e.g. `'non-h'`, `'Non-H'`,
/// `'artist_cg'`, `'无H'`) to its canonical E-Hentai category name, or `null`
/// if unrecognized.
String? canonicalizeFavRuleCategory(String? raw) {
  if (raw == null) {
    return null;
  }
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final compact = trimmed
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_\-]+'), '');
  return switch (compact) {
    'doujinshi' || '同人志' || '同人' => 'Doujinshi',
    'manga' || '漫画' || '漫畫' => 'Manga',
    'artistcg' || '画师cg' || '畫師cg' => 'Artist CG',
    'gamecg' || '游戏cg' || '遊戲cg' => 'Game CG',
    'western' || '西方' => 'Western',
    'nonh' || '无h' || '無h' || '全年龄' || '全年齡' => 'Non-H',
    'imageset' || '图集' || '圖集' => 'Image Set',
    'cosplay' || '扮演' => 'Cosplay',
    'asianporn' || '亚洲' || '亞洲' => 'Asian Porn',
    'misc' || '杂项' || '雜項' => 'Misc',
    _ => null,
  };
}

FavRuleCategoryMeta? favRuleCategoryMetaFor(String? raw) {
  final canonical = canonicalizeFavRuleCategory(raw);
  if (canonical == null) {
    return null;
  }
  for (final meta in kFavRuleCategoryMetas) {
    if (meta.canonical == canonical) {
      return meta;
    }
  }
  return null;
}

/// How conditions inside a single [FavRule] are combined.
enum FavRuleMatch {
  any,
  all;

  static FavRuleMatch fromName(String? name) =>
      values.firstWhere((e) => e.name == name, orElse: () => FavRuleMatch.any);
}

/// How a [FavRuleCondition] matches against a tag's title or translation.
enum FavRuleOp {
  equals,
  contains,
  regex;

  static FavRuleOp fromName(String? name) =>
      values.firstWhere((e) => e.name == name, orElse: () => FavRuleOp.equals);
}

/// Which gesture on the gallery favorite button triggers rule-based favoriting.
enum FavRuleTrigger {
  tap,
  longPress;

  static FavRuleTrigger fromName(String? name) => values.firstWhere(
        (e) => e.name == name,
        orElse: () => FavRuleTrigger.tap,
      );
}

/// What happens when rule-based favoriting runs and no rule matches.
enum FavRuleFallback {
  picker,
  last,
  fixed;

  static FavRuleFallback fromName(String? name) => values.firstWhere(
        (e) => e.name == name,
        orElse: () => FavRuleFallback.picker,
      );
}

/// What happens when rule-based favoriting runs on an already-favorited gallery.
enum FavRuleExisting {
  move,
  keep;

  static FavRuleExisting fromName(String? name) => values.firstWhere(
        (e) => e.name == name,
        orElse: () => FavRuleExisting.move,
      );
}

/// Presentation style for the gallery list long-press menu.
enum FavListMenuStyle {
  contextMenu,
  actionSheet;

  static FavListMenuStyle fromName(String? name) => values.firstWhere(
        (e) => e.name == name,
        orElse: () => FavListMenuStyle.contextMenu,
      );
}

/// Presentation style for the favorite category picker dialog.
enum FavPickerStyle {
  grid,
  list,
  wheel;

  static FavPickerStyle fromName(String? name) => values.firstWhere(
        (e) => e.name == name,
        orElse: () => FavPickerStyle.grid,
      );
}

/// Ordered canonical E-Hentai tag namespaces supported by rule conditions.
const List<String> kFavRulePrimaryNamespaces = <String>[
  'artist',
  'group',
  'parody',
  'character',
  'female',
  'male',
];

const List<String> kFavRuleExtraNamespaces = <String>[
  'mixed',
  'other',
  'language',
  'cosplayer',
  'reclass',
  'misc',
];

const List<String> kFavRuleAllNamespaces = <String>[
  ...kFavRulePrimaryNamespaces,
  ...kFavRuleExtraNamespaces,
];

/// Display label for a rule namespace (`null` means any tag namespace).
String favRuleNamespaceLabel(String? namespace, {bool zh = true}) {
  if (namespace == null || namespace.isEmpty) {
    return zh ? '任意标签' : 'Any tag';
  }
  final norm = namespace.trim().toLowerCase();
  if (norm == kFavRuleCategoryNamespace) {
    return zh ? '画廊分类' : 'Category';
  }
  if (!zh) {
    return norm;
  }
  return switch (norm) {
    'artist' => '画师',
    'group' => '社团',
    'parody' => '原作',
    'character' => '角色',
    'female' => '女性',
    'male' => '男性',
    'mixed' => '混合',
    'other' => '其他',
    'language' => '语言',
    'cosplayer' => '扮演者',
    'reclass' => '归类',
    'misc' => '杂项',
    _ => norm,
  };
}

/// Compact namespace label used in narrow left columns (`分类` / `任意` / `原作`).
String favRuleNamespaceShortLabel(String? namespace, {bool zh = true}) {
  if (namespace == null || namespace.isEmpty) {
    return zh ? '任意' : 'Any';
  }
  final norm = namespace.trim().toLowerCase();
  if (norm == kFavRuleCategoryNamespace) {
    return zh ? '分类' : 'Category';
  }
  return favRuleNamespaceLabel(norm, zh: zh);
}

String favRuleOpLabel(FavRuleOp op, {bool zh = true}) {
  if (zh) {
    return switch (op) {
      FavRuleOp.equals => '是',
      FavRuleOp.contains => '包含',
      FavRuleOp.regex => '匹配正则',
    };
  }
  return switch (op) {
    FavRuleOp.equals => 'is',
    FavRuleOp.contains => 'contains',
    FavRuleOp.regex => 'matches',
  };
}

String favRuleOpShortLabel(FavRuleOp op, {bool zh = true}) {
  if (zh) {
    return switch (op) {
      FavRuleOp.equals => '是',
      FavRuleOp.contains => '包含',
      FavRuleOp.regex => '正则',
    };
  }
  return switch (op) {
    FavRuleOp.equals => 'is',
    FavRuleOp.contains => 'contains',
    FavRuleOp.regex => 'regex',
  };
}

@immutable
class FavRuleCondition {
  const FavRuleCondition({
    this.namespace,
    this.op = FavRuleOp.equals,
    this.value = '',
    this.values = const <String>[],
    this.negated = false,
    this.matchTranslation = false,
  });

  /// Builds a gallery-category condition (`category ∈ values` or `∉ values`).
  factory FavRuleCondition.category(
    Iterable<String> categories, {
    bool negated = false,
  }) {
    final normalized = _normalizeCategoryList(categories);
    return FavRuleCondition(
      namespace: kFavRuleCategoryNamespace,
      op: FavRuleOp.equals,
      value: normalized.isEmpty ? '' : normalized.first,
      values: List<String>.unmodifiable(normalized),
      negated: negated,
    );
  }

  factory FavRuleCondition.fromJson(Map<String, dynamic> json) {
    final rawNs = json['namespace']?.toString().trim();
    final ns = (rawNs == null || rawNs.isEmpty) ? null : rawNs.toLowerCase();
    final rawVal = json['value']?.toString() ?? '';
    final rawValues = json['values'];
    final parsedValues = <String>[];
    if (rawValues is List) {
      for (final item in rawValues) {
        final s = item?.toString().trim() ?? '';
        if (s.isNotEmpty) {
          parsedValues.add(s);
        }
      }
    }
    final isNegated = json['negated'] == true;
    if (ns == kFavRuleCategoryNamespace) {
      final source = parsedValues.isNotEmpty
          ? parsedValues
          : (rawVal.trim().isNotEmpty ? <String>[rawVal.trim()] : const <String>[]);
      final cats = _normalizeCategoryList(source);
      return FavRuleCondition(
        namespace: kFavRuleCategoryNamespace,
        op: FavRuleOp.equals,
        value: cats.isNotEmpty ? cats.first : rawVal.trim(),
        values: List<String>.unmodifiable(cats),
        negated: isNegated,
      );
    }
    return FavRuleCondition(
      namespace: ns,
      op: FavRuleOp.fromName(json['op']?.toString()),
      value: rawVal,
      values: parsedValues.isEmpty
          ? const <String>[]
          : List<String>.unmodifiable(parsedValues),
      negated: isNegated,
      matchTranslation: json['matchTranslation'] == true,
    );
  }

  /// Builds an initial `equals` condition from a [NormalizedTag] clicked in a
  /// rule-miss prompt or feedback banner, preserving namespace and falling back
  /// cleanly if only normalized or translated text is present.
  factory FavRuleCondition.fromNormalizedTag(NormalizedTag tag) {
    final ns = tag.namespace.trim().toLowerCase();
    if (ns == kFavRuleCategoryNamespace) {
      final cat = canonicalizeFavRuleCategory(tag.rawTitle) ??
          canonicalizeFavRuleCategory(tag.title) ??
          canonicalizeFavRuleCategory(tag.rawTranslation) ??
          tag.rawTitle.trim();
      return FavRuleCondition.category(
        cat.isEmpty ? const <String>[] : <String>[cat],
      );
    }
    final rawTitle = tag.rawTitle.trim();
    final normTitle = tag.title.trim();
    final rawTrans = tag.rawTranslation.trim();
    final String resolvedValue;
    final bool useTranslation;
    if (rawTitle.isNotEmpty) {
      resolvedValue = rawTitle;
      useTranslation = false;
    } else if (normTitle.isNotEmpty) {
      resolvedValue = normTitle;
      useTranslation = false;
    } else {
      resolvedValue = rawTrans;
      useTranslation = rawTrans.isNotEmpty;
    }
    return FavRuleCondition(
      namespace: ns.isEmpty ? null : ns,
      op: FavRuleOp.equals,
      value: resolvedValue,
      matchTranslation: useTranslation,
    );
  }

  static List<String> _normalizeCategoryList(Iterable<String> rawItems) {
    final seen = <String>{};
    final result = <String>[];
    for (final item in rawItems) {
      final trimmed = item.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final canonical = canonicalizeFavRuleCategory(trimmed) ?? trimmed;
      if (seen.add(canonical.toLowerCase())) {
        result.add(canonical);
      }
    }
    return result;
  }

  /// Nullable tag namespace (`artist`, `female`, `category`, etc.). `null` matches any tag.
  final String? namespace;
  final FavRuleOp op;
  final String value;

  /// Multi-value selection used by gallery-category conditions (`OR` semantics).
  final List<String> values;

  /// Whether a category condition excludes [categoryValues] (`∉` instead of `∈`).
  final bool negated;

  final bool matchTranslation;

  bool get isCategory =>
      namespace?.trim().toLowerCase() == kFavRuleCategoryNamespace;

  /// Canonical category list for `namespace == 'category'`, supporting both
  /// multi-value [values] and legacy single-string [value].
  List<String> get categoryValues {
    if (!isCategory) {
      return const <String>[];
    }
    if (values.isNotEmpty) {
      return _normalizeCategoryList(values);
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return const <String>[];
    }
    return _normalizeCategoryList(<String>[trimmed]);
  }

  bool get hasValidValue {
    if (isCategory) {
      return categoryValues.isNotEmpty;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (op == FavRuleOp.regex) {
      return isValidRegex;
    }
    return true;
  }

  bool get isValidRegex {
    if (isCategory || op != FavRuleOp.regex) {
      return true;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    try {
      RegExp(trimmed, caseSensitive: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  String describe({bool zh = true}) {
    if (isCategory) {
      final cats = categoryValues;
      if (cats.isEmpty) {
        return zh ? '画廊分类' : 'Category';
      }
      final joined = cats.join(' / ');
      if (negated) {
        return zh ? '分类 不是 $joined' : 'Category is not $joined';
      }
      if (cats.length == 1) {
        return zh ? '分类 是 ${cats.first}' : 'Category is ${cats.first}';
      }
      return zh ? '分类 是其中之一 $joined' : 'Category in $joined';
    }
    final ns = favRuleNamespaceLabel(namespace, zh: zh);
    final opText = favRuleOpLabel(op, zh: zh);
    return '$ns $opText ${value.trim()}';
  }

  FavRuleCondition copyWith({
    String? namespace,
    bool clearNamespace = false,
    FavRuleOp? op,
    String? value,
    List<String>? values,
    bool? negated,
    bool? matchTranslation,
  }) {
    final nextNs = clearNamespace ? null : (namespace ?? this.namespace);
    if (nextNs?.trim().toLowerCase() == kFavRuleCategoryNamespace) {
      final nextCats = values != null
          ? _normalizeCategoryList(values)
          : (value != null
              ? _normalizeCategoryList(<String>[value])
              : categoryValues);
      return FavRuleCondition(
        namespace: kFavRuleCategoryNamespace,
        op: FavRuleOp.equals,
        value: nextCats.isEmpty ? '' : nextCats.first,
        values: List<String>.unmodifiable(nextCats),
        negated: negated ?? this.negated,
      );
    }
    return FavRuleCondition(
      namespace: nextNs,
      op: op ?? this.op,
      value: value ?? this.value,
      values: values ?? this.values,
      negated: negated ?? this.negated,
      matchTranslation: matchTranslation ?? this.matchTranslation,
    );
  }

  Map<String, dynamic> toJson() {
    if (isCategory) {
      final cats = categoryValues;
      return <String, dynamic>{
        'namespace': kFavRuleCategoryNamespace,
        'op': FavRuleOp.equals.name,
        'value': cats.isNotEmpty ? cats.first : value,
        if (cats.isNotEmpty) 'values': cats,
        if (negated) 'negated': true,
        'matchTranslation': false,
      };
    }
    return <String, dynamic>{
      if (namespace != null && namespace!.isNotEmpty) 'namespace': namespace,
      'op': op.name,
      'value': value,
      if (values.isNotEmpty) 'values': values,
      if (negated) 'negated': true,
      'matchTranslation': matchTranslation,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! FavRuleCondition) {
      return false;
    }
    if (isCategory || other.isCategory) {
      return isCategory &&
          other.isCategory &&
          negated == other.negated &&
          const ListEquality<String>().equals(
            categoryValues,
            other.categoryValues,
          );
    }
    return namespace == other.namespace &&
        op == other.op &&
        value == other.value &&
        negated == other.negated &&
        matchTranslation == other.matchTranslation &&
        const ListEquality<String>().equals(values, other.values);
  }

  @override
  int get hashCode => isCategory
      ? Object.hash(
          kFavRuleCategoryNamespace,
          negated,
          Object.hashAll(categoryValues),
        )
      : Object.hash(
          namespace,
          op,
          value,
          negated,
          matchTranslation,
          Object.hashAll(values),
        );
}

@immutable
class FavRule {
  const FavRule({
    required this.id,
    this.name = '',
    this.enabled = true,
    this.match = FavRuleMatch.any,
    required this.conditions,
    required this.favcat,
    this.hitCount = 0,
    this.lastHitAt,
  });

  factory FavRule.fromJson(Map<String, dynamic> json) {
    final rawConditions = json['conditions'];
    final parsedConditions = <FavRuleCondition>[];
    if (rawConditions is List) {
      for (final item in rawConditions) {
        if (item is Map) {
          parsedConditions.add(
            FavRuleCondition.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return FavRule(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      enabled: json['enabled'] != false,
      match: FavRuleMatch.fromName(json['match']?.toString()),
      conditions: parsedConditions,
      favcat: json['favcat']?.toString() ?? '0',
      hitCount: (json['hitCount'] is num)
          ? (json['hitCount'] as num).toInt()
          : int.tryParse('${json['hitCount'] ?? 0}') ?? 0,
      lastHitAt: (json['lastHitAt'] is num)
          ? (json['lastHitAt'] as num).toInt()
          : int.tryParse('${json['lastHitAt'] ?? ''}'),
    );
  }

  final String id;
  final String name;
  final bool enabled;
  final FavRuleMatch match;
  final List<FavRuleCondition> conditions;

  /// `'0'..'9'` for E-Hentai favorite folders, or `'l'` for local favorites.
  final String favcat;

  final int hitCount;
  final int? lastHitAt;

  /// Display name: uses explicit [name] if non-empty, otherwise generates one
  /// from the first condition.
  String displayName({bool zh = true}) {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    if (conditions.isEmpty) {
      return zh ? '未命名规则' : 'Untitled rule';
    }
    final first = conditions.first;
    if (first.isCategory) {
      final cats = first.categoryValues;
      if (cats.isEmpty) {
        return zh ? '画廊分类' : 'Category';
      }
      if (first.negated) {
        if (cats.length == 1) {
          return zh ? '不是 ${cats.first}' : 'Not ${cats.first}';
        }
        return zh
            ? '不是 ${cats.first} 等 ${cats.length} 类'
            : 'Not ${cats.first} (+${cats.length - 1})';
      }
      if (cats.length == 1) {
        return cats.first;
      }
      return zh
          ? '${cats.first} 等 ${cats.length} 类'
          : '${cats.first} (+${cats.length - 1})';
    }
    final ns = favRuleNamespaceLabel(first.namespace, zh: zh);
    final val = first.value.trim();
    if (first.op == FavRuleOp.contains) {
      return zh ? '$ns包含 $val' : '$ns contains $val';
    }
    if (first.op == FavRuleOp.regex) {
      return '$ns /$val/';
    }
    return '$ns $val';
  }

  FavRule copyWith({
    String? id,
    String? name,
    bool? enabled,
    FavRuleMatch? match,
    List<FavRuleCondition>? conditions,
    String? favcat,
    int? hitCount,
    int? lastHitAt,
  }) {
    return FavRule(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      match: match ?? this.match,
      conditions: conditions ?? this.conditions,
      favcat: favcat ?? this.favcat,
      hitCount: hitCount ?? this.hitCount,
      lastHitAt: lastHitAt ?? this.lastHitAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'enabled': enabled,
        'match': match.name,
        'conditions': conditions.map((c) => c.toJson()).toList(),
        'favcat': favcat,
        'hitCount': hitCount,
        if (lastHitAt != null) 'lastHitAt': lastHitAt,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavRule &&
          id == other.id &&
          name == other.name &&
          enabled == other.enabled &&
          match == other.match &&
          const ListEquality<FavRuleCondition>()
              .equals(conditions, other.conditions) &&
          favcat == other.favcat &&
          hitCount == other.hitCount &&
          lastHitAt == other.lastHitAt;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        enabled,
        match,
        Object.hashAll(conditions),
        favcat,
        hitCount,
        lastHitAt,
      );
}

@immutable
class FavRuleConfig {
  const FavRuleConfig({
    this.version = currentVersion,
    this.enabled = false,
    this.trigger = FavRuleTrigger.tap,
    this.fallback = FavRuleFallback.picker,
    this.fallbackFavcat = '0',
    this.existing = FavRuleExisting.move,
    this.listMenuStyle = FavListMenuStyle.contextMenu,
    this.pickerStyle = FavPickerStyle.grid,
    this.migratedFromOneStep = false,
    this.showMigrationBanner = false,
    this.rules = const <FavRule>[],
    this.dismissedRememberKeys = const <String>[],
  });

  factory FavRuleConfig.fromJson(Map<String, dynamic> json) {
    final rawRules = json['rules'];
    final parsedRules = <FavRule>[];
    if (rawRules is List) {
      for (final item in rawRules) {
        if (item is Map) {
          parsedRules.add(FavRule.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    final rawDismissed = json['dismissedRememberKeys'];
    final parsedDismissed = <String>[];
    if (rawDismissed is List) {
      for (final item in rawDismissed) {
        final s = item?.toString().trim() ?? '';
        if (s.isNotEmpty) {
          parsedDismissed.add(s);
        }
      }
    }
    return FavRuleConfig(
      version: (json['version'] is num)
          ? (json['version'] as num).toInt()
          : int.tryParse('${json['version'] ?? 1}') ?? 1,
      enabled: json['enabled'] == true,
      trigger: FavRuleTrigger.fromName(json['trigger']?.toString()),
      fallback: FavRuleFallback.fromName(json['fallback']?.toString()),
      fallbackFavcat: json['fallbackFavcat']?.toString() ?? '0',
      existing: FavRuleExisting.fromName(json['existing']?.toString()),
      listMenuStyle:
          FavListMenuStyle.fromName(json['listMenuStyle']?.toString()),
      pickerStyle: FavPickerStyle.fromName(json['pickerStyle']?.toString()),
      migratedFromOneStep: json['migratedFromOneStep'] == true,
      showMigrationBanner: json['showMigrationBanner'] == true,
      rules: parsedRules,
      dismissedRememberKeys: parsedDismissed.isEmpty
          ? const <String>[]
          : List<String>.unmodifiable(parsedDismissed),
    );
  }

  /// Schema v2 promotes heart-tap to rule evaluation and long-press to manual picker.
  static const int currentVersion = 2;

  final int version;
  final bool enabled;
  final FavRuleTrigger trigger;
  final FavRuleFallback fallback;
  final String fallbackFavcat;
  final FavRuleExisting existing;
  final FavListMenuStyle listMenuStyle;
  final FavPickerStyle pickerStyle;
  final bool migratedFromOneStep;
  final bool showMigrationBanner;
  final List<FavRule> rules;

  /// Persisted `<canonicalCategory>-><favcat>` pairs explicitly dismissed via `×`
  /// on the post-pick "Remember" banner so the same pair is not offered again.
  final List<String> dismissedRememberKeys;

  int get enabledRuleCount => rules.where((r) => r.enabled).length;

  FavRuleConfig copyWith({
    int? version,
    bool? enabled,
    FavRuleTrigger? trigger,
    FavRuleFallback? fallback,
    String? fallbackFavcat,
    FavRuleExisting? existing,
    FavListMenuStyle? listMenuStyle,
    FavPickerStyle? pickerStyle,
    bool? migratedFromOneStep,
    bool? showMigrationBanner,
    List<FavRule>? rules,
    List<String>? dismissedRememberKeys,
  }) {
    return FavRuleConfig(
      version: version ?? this.version,
      enabled: enabled ?? this.enabled,
      trigger: trigger ?? this.trigger,
      fallback: fallback ?? this.fallback,
      fallbackFavcat: fallbackFavcat ?? this.fallbackFavcat,
      existing: existing ?? this.existing,
      listMenuStyle: listMenuStyle ?? this.listMenuStyle,
      pickerStyle: pickerStyle ?? this.pickerStyle,
      migratedFromOneStep: migratedFromOneStep ?? this.migratedFromOneStep,
      showMigrationBanner: showMigrationBanner ?? this.showMigrationBanner,
      rules: rules ?? this.rules,
      dismissedRememberKeys:
          dismissedRememberKeys ?? this.dismissedRememberKeys,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': version,
        'enabled': enabled,
        'trigger': trigger.name,
        'fallback': fallback.name,
        'fallbackFavcat': fallbackFavcat,
        'existing': existing.name,
        'listMenuStyle': listMenuStyle.name,
        'pickerStyle': pickerStyle.name,
        'migratedFromOneStep': migratedFromOneStep,
        'showMigrationBanner': showMigrationBanner,
        'rules': rules.map((r) => r.toJson()).toList(),
        if (dismissedRememberKeys.isNotEmpty)
          'dismissedRememberKeys': dismissedRememberKeys,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavRuleConfig &&
          version == other.version &&
          enabled == other.enabled &&
          trigger == other.trigger &&
          fallback == other.fallback &&
          fallbackFavcat == other.fallbackFavcat &&
          existing == other.existing &&
          listMenuStyle == other.listMenuStyle &&
          pickerStyle == other.pickerStyle &&
          migratedFromOneStep == other.migratedFromOneStep &&
          showMigrationBanner == other.showMigrationBanner &&
          const ListEquality<FavRule>().equals(rules, other.rules) &&
          const ListEquality<String>().equals(
            dismissedRememberKeys,
            other.dismissedRememberKeys,
          );

  @override
  int get hashCode => Object.hash(
        version,
        enabled,
        trigger,
        fallback,
        fallbackFavcat,
        existing,
        listMenuStyle,
        pickerStyle,
        migratedFromOneStep,
        showMigrationBanner,
        Object.hashAll(rules),
        Object.hashAll(dismissedRememberKeys),
      );
}

/// Normalized representation of a single gallery tag used during rule matching.
@immutable
class NormalizedTag {
  const NormalizedTag({
    required this.namespace,
    required this.title,
    required this.rawTitle,
    this.translation = '',
    this.rawTranslation = '',
  });

  /// Lowercase namespace, or empty string when unknown (e.g. `SimpleTag`).
  final String namespace;

  /// Normalized lowercase title with underscores collapsed to single spaces.
  final String title;

  /// Original display title as reported by E-Hentai.
  final String rawTitle;

  /// Normalized lowercase translation (stripped of markdown/images).
  final String translation;

  /// Original display translation.
  final String rawTranslation;

  /// Canonical key used for highlighting detail-page tags (`namespace:title`).
  String get key => namespace.isEmpty ? title : '$namespace:$title';

  bool get isCategory => namespace == kFavRuleCategoryNamespace;

  /// Compact display string shown in feedback banners and menus.
  String displayLabel({bool preferTranslation = false}) {
    if (isCategory) {
      return rawTitle.isNotEmpty ? rawTitle : title;
    }
    final text = (preferTranslation && rawTranslation.isNotEmpty)
        ? rawTranslation
        : rawTitle;
    return namespace.isEmpty ? text : '$namespace:$text';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NormalizedTag &&
          namespace == other.namespace &&
          title == other.title &&
          translation == other.translation;

  @override
  int get hashCode => Object.hash(namespace, title, translation);
}

@immutable
class FavRuleConditionHit {
  const FavRuleConditionHit({
    required this.condition,
    required this.tag,
  });

  final FavRuleCondition condition;
  final NormalizedTag tag;
}

@immutable
class FavRuleHit {
  const FavRuleHit({
    required this.rule,
    required this.conditionHits,
  });

  final FavRule rule;
  final List<FavRuleConditionHit> conditionHits;

  List<NormalizedTag> get matchedTags {
    final seen = <String>{};
    final result = <NormalizedTag>[];
    for (final hit in conditionHits) {
      if (seen.add(hit.tag.key)) {
        result.add(hit.tag);
      }
    }
    return result;
  }

  NormalizedTag? get primaryTag =>
      conditionHits.isEmpty ? null : conditionHits.first.tag;
}

@immutable
class FavRuleEvalResult {
  const FavRuleEvalResult({
    this.primary,
    this.others = const <FavRuleHit>[],
  });

  static const FavRuleEvalResult miss = FavRuleEvalResult();

  final FavRuleHit? primary;
  final List<FavRuleHit> others;

  bool get isHit => primary != null;

  List<FavRuleHit> get allHits => <FavRuleHit>[
        if (primary != null) primary!,
        ...others,
      ];
}
