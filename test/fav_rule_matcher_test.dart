import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:eros_fe/common/service/fav_rule_matcher.dart';
import 'package:eros_fe/models/fav_rule.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/models/gallery_tag.dart';
import 'package:eros_fe/models/simple_tag.dart';
import 'package:eros_fe/models/tag_group.dart';
import 'package:eros_fe/store/db/entity/tag_translat.dart';
import 'package:eros_fe/store/db/isar_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

void main() {
  group('FavRuleMatcher normalization & extraction', () {
    test('normalizes case, underscores, and extra spaces', () {
      expect(FavRuleMatcher.normalize('  Foot_Focus  '), 'foot focus');
      expect(FavRuleMatcher.normalize('ARTIST'), 'artist');
      expect(
        FavRuleMatcher.cleanTranslation('![img](https://x/y.png) 足控'),
        '足控',
      );
      final tag = FavRuleMatcher.parseApiTag('artist:mitsuki_san');
      expect(
        FavRuleMatcher.matchCondition(
          const FavRuleCondition(
            op: FavRuleOp.equals,
            value: 'artist : Mitsuki San',
          ),
          <NormalizedTag>[tag],
        ),
        isNotNull,
      );
    });

    test('parses freeform tags separated by commas or newlines', () {
      final tags = FavRuleMatcher.parseFreeformTags(
        'artist:Mitsuki, female:foot_focus\nlanguage:chinese',
      );
      expect(tags.length, 3);
      expect(tags[0].namespace, 'artist');
      expect(tags[0].title, 'mitsuki');
      expect(tags[1].namespace, 'female');
      expect(tags[1].title, 'foot focus');
      expect(tags[2].namespace, 'language');
      expect(tags[2].title, 'chinese');
    });
  });

  group('FavRuleMatcher evaluation', () {
    final sampleTags = FavRuleMatcher.fromTagGroups(<TagGroup>[
      const TagGroup(
        tagType: 'artist',
        galleryTags: <GalleryTag>[
          GalleryTag(title: 'mitsuki', type: 'artist', tagTranslat: '三月'),
        ],
      ),
      const TagGroup(
        tagType: 'female',
        galleryTags: <GalleryTag>[
          GalleryTag(
            title: 'foot focus',
            type: 'female',
            tagTranslat: '赤足',
          ),
          GalleryTag(
            title: 'stockings',
            type: 'female',
            tagTranslat: '长筒袜',
          ),
        ],
      ),
      const TagGroup(
        tagType: 'language',
        galleryTags: <GalleryTag>[
          GalleryTag(title: 'chinese', type: 'language', tagTranslat: '中文'),
        ],
      ),
    ]);

    test('matches exact artist rule and records lower-priority hits', () {
      const rules = <FavRule>[
        FavRule(
          id: 'r1',
          name: '喜欢的画师',
          favcat: '1',
          conditions: <FavRuleCondition>[
            FavRuleCondition(
              namespace: 'artist',
              op: FavRuleOp.equals,
              value: 'Mitsuki',
            ),
          ],
        ),
        FavRule(
          id: 'r2',
          name: '足控',
          favcat: '2',
          conditions: <FavRuleCondition>[
            FavRuleCondition(
              op: FavRuleOp.contains,
              value: 'foot',
            ),
          ],
        ),
      ];

      final res = FavRuleMatcher.evaluate(rules, sampleTags);
      expect(res.isHit, isTrue);
      expect(res.primary!.rule.id, 'r1');
      expect(res.primary!.primaryTag!.key, 'artist:mitsuki');
      expect(res.others.length, 1);
      expect(res.others.first.rule.id, 'r2');
      expect(res.others.first.primaryTag!.key, 'female:foot focus');
    });

    test('skips disabled rules and supports match=all', () {
      const rules = <FavRule>[
        FavRule(
          id: 'disabled',
          enabled: false,
          favcat: '0',
          conditions: <FavRuleCondition>[
            FavRuleCondition(
              namespace: 'artist',
              op: FavRuleOp.equals,
              value: 'mitsuki',
            ),
          ],
        ),
        FavRule(
          id: 'all-miss',
          favcat: '3',
          match: FavRuleMatch.all,
          conditions: <FavRuleCondition>[
            FavRuleCondition(
              namespace: 'language',
              op: FavRuleOp.equals,
              value: 'chinese',
            ),
            FavRuleCondition(
              namespace: 'female',
              op: FavRuleOp.equals,
              value: 'glasses',
            ),
          ],
        ),
        FavRule(
          id: 'all-hit',
          favcat: '4',
          match: FavRuleMatch.all,
          conditions: <FavRuleCondition>[
            FavRuleCondition(
              namespace: 'language',
              op: FavRuleOp.equals,
              value: 'chinese',
            ),
            FavRuleCondition(
              namespace: 'female',
              op: FavRuleOp.contains,
              value: 'stock',
            ),
          ],
        ),
      ];

      final res = FavRuleMatcher.evaluate(rules, sampleTags);
      expect(res.isHit, isTrue);
      expect(res.primary!.rule.id, 'all-hit');
      expect(res.primary!.matchedTags.length, 2);
      expect(res.others, isEmpty);
    });

    test('supports translation matching and safe regex handling', () {
      const transRule = FavRule(
        id: 'zh',
        favcat: '5',
        conditions: <FavRuleCondition>[
          FavRuleCondition(
            op: FavRuleOp.contains,
            value: '足',
            matchTranslation: true,
          ),
        ],
      );
      expect(FavRuleMatcher.matchRule(transRule, sampleTags), isNotNull);

      const noTransRule = FavRule(
        id: 'no-zh',
        favcat: '5',
        conditions: <FavRuleCondition>[
          FavRuleCondition(
            op: FavRuleOp.contains,
            value: '足',
            matchTranslation: false,
          ),
        ],
      );
      expect(FavRuleMatcher.matchRule(noTransRule, sampleTags), isNull);

      const regexRule = FavRule(
        id: 'rx',
        favcat: '6',
        conditions: <FavRuleCondition>[
          FavRuleCondition(
            namespace: 'female',
            op: FavRuleOp.regex,
            value: r'^foot\s+foc',
          ),
        ],
      );
      expect(FavRuleMatcher.matchRule(regexRule, sampleTags), isNotNull);

      const badRegexRule = FavRule(
        id: 'bad-rx',
        favcat: '6',
        conditions: <FavRuleCondition>[
          FavRuleCondition(
            op: FavRuleOp.regex,
            value: '[unclosed',
          ),
        ],
      );
      expect(badRegexRule.conditions.first.isValidRegex, isFalse);
      expect(FavRuleMatcher.matchRule(badRegexRule, sampleTags), isNull);
    });
  });

  group('FavRuleMatcher truncation detection & serialization', () {
    test('detects when list simpleTags require full gdata fetch', () {
      const listProvider = GalleryProvider(
        gid: '100',
        token: 'abc',
        simpleTags: <SimpleTag>[
          SimpleTag(text: 'foot focus', translat: '赤足'),
        ],
      );

      const ruleWithoutNs = FavRule(
        id: 'r1',
        favcat: '2',
        conditions: <FavRuleCondition>[
          FavRuleCondition(op: FavRuleOp.contains, value: 'foot'),
        ],
      );
      const ruleWithNs = FavRule(
        id: 'r0',
        favcat: '1',
        conditions: <FavRuleCondition>[
          FavRuleCondition(
            namespace: 'artist',
            op: FavRuleOp.equals,
            value: 'mitsuki',
          ),
        ],
      );

      // Highest-priority rule has no namespace and already matches -> no fetch needed.
      expect(
        FavRuleMatcher.needsFullTagFetch(listProvider, <FavRule>[ruleWithoutNs]),
        isFalse,
      );

      // Higher-priority rule needs namespace -> must fetch to guarantee order.
      expect(
        FavRuleMatcher.needsFullTagFetch(
          listProvider,
          <FavRule>[ruleWithNs, ruleWithoutNs],
        ),
        isTrue,
      );

      // Complete tags already present -> never needs fetch.
      const completeProvider = GalleryProvider(
        gid: '100',
        token: 'abc',
        tagsFromApi: <dynamic>['artist:mitsuki', 'female:foot focus'],
      );
      expect(
        FavRuleMatcher.needsFullTagFetch(
          completeProvider,
          <FavRule>[ruleWithNs, ruleWithoutNs],
        ),
        isFalse,
      );
    });

    test('FavRuleConfig defaults to v2 tap trigger and JSON round-trip preserves fields', () {
      const defaults = FavRuleConfig();
      expect(defaults.version, 2);
      expect(defaults.trigger, FavRuleTrigger.tap);
      expect(defaults.fallback, FavRuleFallback.picker);

      final legacyJsonDecoded = FavRuleConfig.fromJson(const <String, dynamic>{});
      expect(legacyJsonDecoded.version, 1);
      expect(legacyJsonDecoded.trigger, FavRuleTrigger.tap);

      const config = FavRuleConfig(
        version: 2,
        enabled: true,
        trigger: FavRuleTrigger.tap,
        fallback: FavRuleFallback.fixed,
        fallbackFavcat: '3',
        existing: FavRuleExisting.keep,
        listMenuStyle: FavListMenuStyle.actionSheet,
        pickerStyle: FavPickerStyle.wheel,
        migratedFromOneStep: true,
        showMigrationBanner: true,
        rules: <FavRule>[
          FavRule(
            id: 'r1',
            name: 'My Artist',
            enabled: true,
            match: FavRuleMatch.all,
            favcat: '1',
            hitCount: 23,
            lastHitAt: 1700000000000,
            conditions: <FavRuleCondition>[
              FavRuleCondition(
                namespace: 'artist',
                op: FavRuleOp.equals,
                value: 'mitsuki',
                matchTranslation: true,
              ),
            ],
          ),
        ],
      );

      final decoded = FavRuleConfig.fromJson(config.toJson());
      expect(decoded, config);
    });

    test('parseConditionPreviewQuery extracts inline namespace:key forms', () {
      final inline = FavRuleMatcher.parseConditionPreviewQuery(
        value: ' artist : Mitsuki_San ',
      );
      expect(inline.explicitNamespace, isNull);
      expect(inline.inlineNamespace, 'artist');
      expect(inline.inlineKeyNormalized, 'mitsuki san');
      expect(inline.normalizedFull, 'artist:mitsuki san');

      final nsOnly = FavRuleMatcher.parseConditionPreviewQuery(value: 'artist:');
      expect(nsOnly.inlineNamespace, 'artist');
      expect(nsOnly.inlineKeyNormalized, isEmpty);

      final rx = FavRuleMatcher.parseConditionPreviewQuery(
        value: '^artist:mit.*',
      );
      expect(rx.regexNamespaceHint, 'artist');

      const tag = NormalizedTag(
        namespace: 'artist',
        title: 'mitsuki',
        rawTitle: 'mitsuki',
        translation: '三月',
        rawTranslation: '三月',
      );
      expect(
        FavRuleMatcher.matchCondition(
          const FavRuleCondition(
            op: FavRuleOp.equals,
            value: 'artist:三月',
            matchTranslation: true,
          ),
          <NormalizedTag>[tag],
        ),
        isNotNull,
      );
    });

    test(
        'preview query tokens/variants and filterPreviewCandidates match underscore keys like black_hair for space input black hair',
        () {
      final parsed = FavRuleMatcher.parseConditionPreviewQuery(
        value: 'black hair',
      );
      expect(parsed.normalizedFullTokens, <String>['black', 'hair']);
      expect(
        parsed.normalizedFullKeyVariants,
        <String>['black hair', 'black_hair'],
      );

      final inlineParsed = FavRuleMatcher.parseConditionPreviewQuery(
        value: 'female:black hair',
      );
      expect(inlineParsed.inlineKeyTokens, <String>['black', 'hair']);
      expect(
        inlineParsed.inlineKeyVariants,
        <String>['black hair', 'black_hair'],
      );

      final dbPool = <({String ns, String key, String? name})>[
        (
          ns: 'female',
          key: 'black_hair',
          name: '![img](https://ehgt.org/g/blank.gif)黑发',
        ),
        (ns: 'female', key: 'long_black_hair', name: '长黑发'),
        (ns: 'female', key: 'hair_black', name: '反转顺序'),
        (ns: 'female', key: 'school swimsuit', name: '死库水'),
        (ns: 'category', key: 'black_hair', name: '黑发'),
      ];

      // 1) Space input 'black hair' with equals matches 'black_hair' ONLY (not 'long_black_hair' or category):
      final (eqItems, eqTotal) = FavRuleMatcher.filterPreviewCandidates(
        candidates: dbPool,
        condition: const FavRuleCondition(
          op: FavRuleOp.equals,
          value: 'black hair',
        ),
        namespaceOf: (e) => e.ns,
        keyOf: (e) => e.key,
        translationOf: (e) => e.name,
      );
      expect(eqTotal, 1);
      expect(eqItems.single.key, 'black_hair');

      // 2) Inline 'female:black hair' with equals matches 'black_hair':
      final (inlineItems, inlineTotal) = FavRuleMatcher.filterPreviewCandidates(
        candidates: dbPool,
        condition: const FavRuleCondition(
          op: FavRuleOp.equals,
          value: 'female:black hair',
        ),
        namespaceOf: (e) => e.ns,
        keyOf: (e) => e.key,
        translationOf: (e) => e.name,
      );
      expect(inlineTotal, 1);
      expect(inlineItems.single.key, 'black_hair');

      // 3) Space input 'black hair' with contains matches 'black_hair' and 'long_black_hair', NOT 'hair_black':
      final (containsItems, containsTotal) =
          FavRuleMatcher.filterPreviewCandidates(
        candidates: dbPool,
        condition: const FavRuleCondition(
          op: FavRuleOp.contains,
          value: 'black hair',
        ),
        namespaceOf: (e) => e.ns,
        keyOf: (e) => e.key,
        translationOf: (e) => e.name,
      );
      expect(containsTotal, 2);
      expect(
        containsItems.map((e) => e.key).toList(),
        <String>['black_hair', 'long_black_hair'],
      );

      // 4) Underscore input 'school_swimsuit' matches 'school swimsuit':
      final (swItems, swTotal) = FavRuleMatcher.filterPreviewCandidates(
        candidates: dbPool,
        condition: const FavRuleCondition(
          namespace: 'female',
          op: FavRuleOp.equals,
          value: 'school_swimsuit',
        ),
        namespaceOf: (e) => e.ns,
        keyOf: (e) => e.key,
        translationOf: (e) => e.name,
      );
      expect(swTotal, 1);
      expect(swItems.single.key, 'school swimsuit');

      // 5) Markdown-prefixed translation '![img](...)黑发' matches equals '黑发' and ignores image URL in regex:
      final (trItems, trTotal) = FavRuleMatcher.filterPreviewCandidates(
        candidates: dbPool,
        condition: const FavRuleCondition(
          op: FavRuleOp.equals,
          value: '黑发',
          matchTranslation: true,
        ),
        namespaceOf: (e) => e.ns,
        keyOf: (e) => e.key,
        translationOf: (e) => e.name,
      );
      expect(trTotal, 1);
      expect(trItems.single.key, 'black_hair');

      final (_, urlRegexTotal) = FavRuleMatcher.filterPreviewCandidates(
        candidates: dbPool,
        condition: const FavRuleCondition(
          op: FavRuleOp.regex,
          value: r'ehgt\.org',
          matchTranslation: true,
        ),
        namespaceOf: (e) => e.ns,
        keyOf: (e) => e.key,
        translationOf: (e) => e.name,
      );
      expect(urlRegexTotal, 0);
    });

    test(
        r'real Isar findTagTranslatesForRuleCondition matches :black hair, >8000 regex rows, and ^artist:example$ translation across namespaces',
        () async {
      File? dylibFile;
      final cfgFile = File('.dart_tool/package_config.json');
      if (Platform.isMacOS && cfgFile.existsSync()) {
        final cfg =
            jsonDecode(cfgFile.readAsStringSync()) as Map<String, dynamic>;
        final packages =
            (cfg['packages'] as List<dynamic>?) ?? const <dynamic>[];
        for (final entry in packages) {
          final map = entry as Map<String, dynamic>;
          if (map['name'] == 'isar_community_flutter_libs') {
            var rawRoot = map['rootUri'] as String;
            if (!rawRoot.endsWith('/')) {
              rawRoot = '$rawRoot/';
            }
            final rootUri = cfgFile.uri.resolve(rawRoot);
            final candidate =
                File.fromUri(rootUri.resolve('macos/libisar.dylib'));
            if (candidate.existsSync()) {
              dylibFile = candidate;
            }
            break;
          }
        }
      }
      expect(dylibFile, isNotNull);

      await Isar.initializeIsarCore(
        libraries: <Abi, String>{Abi.current(): dylibFile!.path},
      );
      final tempDir =
          await Directory.systemTemp.createTemp('fav_rule_isar_preview_');
      final isar = await Isar.open(
        <CollectionSchema<dynamic>>[TagTranslatSchema],
        directory: tempDir.path,
        name: 'fav_rule_preview_test',
      );
      addTearDown(() async {
        if (isar.isOpen) {
          await isar.close(deleteFromDisk: true);
        }
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final rows = <TagTranslat>[
        TagTranslat(
          namespace: 'female',
          key: 'black_hair',
          name: '![img](https://ehgt.org/g/blank.gif)黑发',
        ),
        TagTranslat(
          namespace: 'female',
          key: 'alias_tag',
          name: 'artist:example',
        ),
        TagTranslat(namespace: 'rows', key: 'black_hair', name: '黑发'),
        TagTranslat(namespace: 'category', key: 'non-h', name: '无H'),
        for (var i = 0; i < 9000; i++)
          TagTranslat(
            namespace: 'other',
            key: 'filler_tag_$i',
            name: '填充_$i',
          ),
        TagTranslat(
          namespace: 'artist',
          key: 'tail_artist_9005',
          name: '尾部画师',
        ),
      ];
      await isar.writeTxn(() async {
        await isar.tagTranslats.putAllByKeyNamespace(rows);
      });

      final helper = IsarHelper()..isar = isar;

      // 1) Space input 'black hair' with equals matches 'female:black_hair':
      final (eqItems, eqTotal) = await helper.findTagTranslatesForRuleCondition(
        value: 'black hair',
        opName: 'equals',
      );
      expect(eqTotal, 1);
      expect(eqItems.single.namespace, 'female');
      expect(eqItems.single.key, 'black_hair');

      // 2) Leading-colon contains ':black hair' matches 'female:black_hair':
      final (leadItems, leadTotal) =
          await helper.findTagTranslatesForRuleCondition(
        value: ':black hair',
        opName: 'contains',
      );
      expect(leadTotal, 1);
      expect(leadItems.single.namespace, 'female');
      expect(leadItems.single.key, 'black_hair');

      // 3) Leading-colon translation contains ':黑发' with matchTranslation matches 'female:black_hair':
      final (leadTrItems, leadTrTotal) =
          await helper.findTagTranslatesForRuleCondition(
        value: ':黑发',
        opName: 'contains',
        matchTranslation: true,
      );
      expect(leadTrTotal, 1);
      expect(leadTrItems.single.key, 'black_hair');

      // 4) Regex scans past 8,000 rows to match row #9005 ('tail_artist_9005'),
      //    both against raw key ('^tail_artist_9005$') and normalized tag.title ('^tail artist 9005$'):
      final (tailRawItems, tailRawTotal) =
          await helper.findTagTranslatesForRuleCondition(
        value: r'^tail_artist_9005$',
        opName: 'regex',
      );
      expect(tailRawTotal, 1);
      expect(tailRawItems.single.namespace, 'artist');
      expect(tailRawItems.single.key, 'tail_artist_9005');

      final (tailNormItems, tailNormTotal) =
          await helper.findTagTranslatesForRuleCondition(
        value: r'^tail artist 9005$',
        opName: 'regex',
      );
      expect(tailNormTotal, 1);
      expect(tailNormItems.single.namespace, 'artist');
      expect(tailNormItems.single.key, 'tail_artist_9005');

      // 5) Regex '^artist:example$' with matchTranslation matches 'female:alias_tag' whose name is 'artist:example':
      final (crossNsItems, crossNsTotal) =
          await helper.findTagTranslatesForRuleCondition(
        value: r'^artist:example$',
        opName: 'regex',
        matchTranslation: true,
      );
      expect(crossNsTotal, 1);
      expect(crossNsItems.single.namespace, 'female');
      expect(crossNsItems.single.key, 'alias_tag');

      // 6) Broad regex '.*' counts all 9,003 real tag rows (excluding 'rows' and 'category') and caps returned list at limit=40:
      final (allItems, allTotal) =
          await helper.findTagTranslatesForRuleCondition(
        value: '.*',
        opName: 'regex',
        limit: 40,
      );
      expect(allTotal, 9003);
      expect(allItems, hasLength(40));
    });
  });

  group('FavRuleMatcher gallery category rules & strict namespace isolation', () {
    test(
        'legacy single-value category JSON compatibility canonicalizes to Non-H and matches provider',
        () {
      final legacyCondition = FavRuleCondition.fromJson(const <String, dynamic>{
        'namespace': 'category',
        'op': 'equals',
        'value': 'non-h',
      });
      expect(legacyCondition.isCategory, isTrue);
      expect(legacyCondition.negated, isFalse);
      expect(legacyCondition.hasValidValue, isTrue);
      expect(legacyCondition.categoryValues, <String>['Non-H']);
      expect(legacyCondition.describe(), '分类 是 Non-H');

      final nonHTags = FavRuleMatcher.extractAvailableTags(
        const GalleryProvider(
          gid: '201',
          token: 'tok201',
          category: 'Non-H',
          simpleTags: <SimpleTag>[SimpleTag(text: 'full color')],
        ),
      );
      final hit = FavRuleMatcher.matchCondition(legacyCondition, nonHTags);
      expect(hit, isNotNull);
      expect(hit!.isCategory, isTrue);
      expect(hit.rawTitle, 'Non-H');
      expect(hit.displayLabel(), 'Non-H');

      // Chinese & underscored aliases canonicalize identically and deduplicate.
      final aliasDedup = FavRuleCondition.category(
        const <String>['non-h', '无H', '全年龄', 'artist_cg'],
      );
      expect(aliasDedup.categoryValues, <String>['Non-H', 'Artist CG']);

      // Building a condition from a synthetic category NormalizedTag preserves canonical Non-H.
      final catTag = FavRuleMatcher.categoryTagFromString('non-h');
      expect(catTag, isNotNull);
      final fromTag = FavRuleCondition.fromNormalizedTag(catTag!);
      expect(fromTag.isCategory, isTrue);
      expect(fromTag.categoryValues, <String>['Non-H']);
    });

    test(
        'multi-value category OR matching and JSON round-trip preserve values, negated, and dismissedRememberKeys',
        () {
      final multiCat = FavRuleCondition.category(
        const <String>['Non-H', 'Image Set'],
      );
      expect(multiCat.isCategory, isTrue);
      expect(multiCat.categoryValues, <String>['Non-H', 'Image Set']);
      expect(multiCat.describe(), '分类 是其中之一 Non-H / Image Set');

      final nonHProviderTags = FavRuleMatcher.extractAvailableTags(
        const GalleryProvider(category: 'Non-H'),
      );
      final imageSetProviderTags = FavRuleMatcher.extractAvailableTags(
        const GalleryProvider(category: 'Image Set'),
      );
      final mangaProviderTags = FavRuleMatcher.extractAvailableTags(
        const GalleryProvider(category: 'Manga'),
      );

      expect(FavRuleMatcher.matchCondition(multiCat, nonHProviderTags), isNotNull);
      expect(
        FavRuleMatcher.matchCondition(multiCat, imageSetProviderTags),
        isNotNull,
      );
      expect(FavRuleMatcher.matchCondition(multiCat, mangaProviderTags), isNull);

      final config = FavRuleConfig(
        version: 2,
        enabled: true,
        dismissedRememberKeys: const <String>['Non-H->0'],
        rules: <FavRule>[
          FavRule(
            id: 'r_cat_multi',
            favcat: '0',
            conditions: <FavRuleCondition>[multiCat],
          ),
          FavRule(
            id: 'r_cat_neg',
            favcat: '1',
            conditions: <FavRuleCondition>[
              FavRuleCondition.category(
                const <String>['Non-H', 'Artist CG'],
                negated: true,
              ),
            ],
          ),
        ],
      );

      expect(config.rules[0].displayName(), 'Non-H 等 2 类');
      expect(config.rules[1].displayName(), '不是 Non-H 等 2 类');

      final roundTripped = FavRuleConfig.fromJson(config.toJson());
      expect(roundTripped, config);
      expect(
        roundTripped.rules.first.conditions.single.categoryValues,
        <String>['Non-H', 'Image Set'],
      );
      expect(roundTripped.rules.last.conditions.single.negated, isTrue);
      expect(roundTripped.dismissedRememberKeys, <String>['Non-H->0']);
    });

    test(
        'negated category exclusion misses Non-H, matches Manga, and returns null when gallery has no category',
        () {
      final excludeNonH = FavRuleCondition.category(
        const <String>['Non-H'],
        negated: true,
      );
      expect(excludeNonH.describe(), '分类 不是 Non-H');

      final nonHTags = FavRuleMatcher.extractAvailableTags(
        const GalleryProvider(category: 'Non-H'),
      );
      final mangaTags = FavRuleMatcher.extractAvailableTags(
        const GalleryProvider(category: 'Manga'),
      );
      final missingCategoryTags = FavRuleMatcher.extractAvailableTags(
        const GalleryProvider(
          category: '   ',
          simpleTags: <SimpleTag>[SimpleTag(text: 'full color')],
        ),
      );
      final nullCategoryTags = FavRuleMatcher.extractAvailableTags(
        const GalleryProvider(
          simpleTags: <SimpleTag>[SimpleTag(text: 'full color')],
        ),
      );

      expect(FavRuleMatcher.matchCondition(excludeNonH, nonHTags), isNull);

      final mangaHit = FavRuleMatcher.matchCondition(excludeNonH, mangaTags);
      expect(mangaHit, isNotNull);
      expect(mangaHit!.rawTitle, 'Manga');

      expect(
        FavRuleMatcher.matchCondition(excludeNonH, missingCategoryTags),
        isNull,
      );
      expect(
        FavRuleMatcher.matchCondition(excludeNonH, nullCategoryTags),
        isNull,
      );
    });

    test(
        'strict namespace isolation prevents Any-tag or tag conditions from matching synthetic category Non-H',
        () {
      final tagsWithNonHCategory = FavRuleMatcher.extractAvailableTags(
        const GalleryProvider(
          gid: '301',
          token: 'tok301',
          category: 'Non-H',
          simpleTags: <SimpleTag>[SimpleTag(text: 'full color', translat: '全彩')],
        ),
      );
      expect(tagsWithNonHCategory.first.isCategory, isTrue);
      expect(tagsWithNonHCategory.first.rawTitle, 'Non-H');

      // Unnamespaced ("Any tag", namespace: null) conditions MUST NEVER match category:Non-H!
      const containsNon = FavRuleCondition(
        namespace: null,
        op: FavRuleOp.contains,
        value: 'non',
      );
      const containsH = FavRuleCondition(
        namespace: null,
        op: FavRuleOp.contains,
        value: 'h',
      );
      const equalsNonH = FavRuleCondition(
        namespace: null,
        op: FavRuleOp.equals,
        value: 'non-h',
      );
      const regexNonH = FavRuleCondition(
        namespace: null,
        op: FavRuleOp.regex,
        value: r'non-h',
      );
      const transNonH = FavRuleCondition(
        namespace: null,
        op: FavRuleOp.contains,
        value: '无h',
        matchTranslation: true,
      );

      expect(
        FavRuleMatcher.matchCondition(containsNon, tagsWithNonHCategory),
        isNull,
      );
      expect(
        FavRuleMatcher.matchCondition(containsH, tagsWithNonHCategory),
        isNull,
      );
      expect(
        FavRuleMatcher.matchCondition(equalsNonH, tagsWithNonHCategory),
        isNull,
      );
      expect(
        FavRuleMatcher.matchCondition(regexNonH, tagsWithNonHCategory),
        isNull,
      );
      expect(
        FavRuleMatcher.matchCondition(transNonH, tagsWithNonHCategory),
        isNull,
      );

      // Conversely, a category rule for Non-H must not match an unnamespaced tag named 'non-h'
      // when the gallery's actual category is Manga.
      final mangaWithFakeTag = FavRuleMatcher.extractAvailableTags(
        const GalleryProvider(
          category: 'Manga',
          simpleTags: <SimpleTag>[SimpleTag(text: 'non-h')],
        ),
      );
      expect(
        FavRuleMatcher.matchCondition(
          FavRuleCondition.category(const <String>['Non-H']),
          mangaWithFakeTag,
        ),
        isNull,
      );

      // Combined category + regular tag rule (FavRuleMatch.all) works cleanly together.
      final combinedRule = FavRule(
        id: 'r_combo',
        match: FavRuleMatch.all,
        favcat: '0',
        conditions: <FavRuleCondition>[
          FavRuleCondition.category(const <String>['Non-H']),
          const FavRuleCondition(op: FavRuleOp.equals, value: 'full color'),
        ],
      );
      expect(
        FavRuleMatcher.matchRule(combinedRule, tagsWithNonHCategory),
        isNotNull,
      );
    });

    test(
        'needsFullTagFetch returns false (0 network calls) for category-only rules and top-priority category hits',
        () {
      const incompleteNonHCard = GalleryProvider(
        gid: '401',
        token: 'tok401',
        category: 'Non-H',
        simpleTags: <SimpleTag>[SimpleTag(text: 'full color')],
      );
      const incompleteMangaCard = GalleryProvider(
        gid: '402',
        token: 'tok402',
        category: 'Manga',
        simpleTags: <SimpleTag>[SimpleTag(text: 'full color')],
      );
      const incompleteNoCategoryCard = GalleryProvider(
        gid: '403',
        token: 'tok403',
        simpleTags: <SimpleTag>[SimpleTag(text: 'full color')],
      );

      final nonHRule = FavRule(
        id: 'r_nonh',
        favcat: '0',
        conditions: <FavRuleCondition>[
          FavRuleCondition.category(const <String>['Non-H']),
        ],
      );
      final artistCGOrImageSetRule = FavRule(
        id: 'r_art',
        favcat: '1',
        conditions: <FavRuleCondition>[
          FavRuleCondition.category(const <String>['Artist CG', 'Image Set']),
        ],
      );
      const namespacedTagRule = FavRule(
        id: 'r_artist',
        favcat: '2',
        conditions: <FavRuleCondition>[
          FavRuleCondition(
            namespace: 'artist',
            op: FavRuleOp.equals,
            value: 'mitsuki',
          ),
        ],
      );

      // 1) All enabled rules are category-only -> 0 network calls on both hit and miss!
      expect(
        FavRuleMatcher.needsFullTagFetch(
          incompleteNonHCard,
          <FavRule>[nonHRule, artistCGOrImageSetRule],
        ),
        isFalse,
      );
      expect(
        FavRuleMatcher.needsFullTagFetch(
          incompleteMangaCard,
          <FavRule>[nonHRule, artistCGOrImageSetRule],
        ),
        isFalse,
      );

      // 2) Highest-priority rule is a category rule that matches provider.category ->
      //    returns false even when lower-priority rules inspect namespaced tags!
      expect(
        FavRuleMatcher.needsFullTagFetch(
          incompleteNonHCard,
          <FavRule>[nonHRule, namespacedTagRule],
        ),
        isFalse,
      );

      // 3) Highest-priority category rule misses provider.category AND lower-priority
      //    rule needs namespaced tags -> must fetch full tags!
      expect(
        FavRuleMatcher.needsFullTagFetch(
          incompleteMangaCard,
          <FavRule>[nonHRule, namespacedTagRule],
        ),
        isTrue,
      );

      // 4) Card missing category altogether requires full tag fetch.
      expect(
        FavRuleMatcher.needsFullTagFetch(
          incompleteNoCategoryCard,
          <FavRule>[nonHRule],
        ),
        isTrue,
      );
    });
  });

  group('FavRuleMatcher deterministic performance benchmark', () {
    test(
        'evaluates 30 realistic rules (exact, contains, regex, translation, match=all) '
        'against 80 TagGroup gallery tags across 1,000 iterations', () {
      // Build 80 realistic detail-page GalleryTags across 9 canonical TagGroups
      // (2 + 3 + 8 + 2 + 3 + 12 + 35 + 5 + 10 = 80 tags).
      List<GalleryTag> genTags(
        String ns,
        List<(String, String)> pairs,
      ) =>
          <GalleryTag>[
            for (final (title, trans) in pairs)
              GalleryTag(title: title, type: ns, tagTranslat: trans),
          ];

      final tagGroups = <TagGroup>[
        TagGroup(
          tagType: 'language',
          galleryTags: genTags('language', const <(String, String)>[
            ('chinese', '中文'),
            ('translated', '翻译'),
          ]),
        ),
        TagGroup(
          tagType: 'parody',
          galleryTags: genTags('parody', const <(String, String)>[
            ('blue archive', '蔚蓝档案'),
            ('azur lane', '碧蓝航线'),
            ('genshin impact', '原神'),
          ]),
        ),
        TagGroup(
          tagType: 'character',
          galleryTags: genTags('character', const <(String, String)>[
            ('yuuka hayase', '早濑优香'),
            ('noa ushio', '生盐诺亚'),
            ('rio tsukatsuki', '调月莉音'),
            ('toki asuma', '飞鸟马时'),
            ('formidable', '可畏'),
            ('bremerton', '布莱默顿'),
            ('furina', '芙宁娜'),
            ('navia', '娜维娅'),
          ]),
        ),
        TagGroup(
          tagType: 'group',
          galleryTags: genTags('group', const <(String, String)>[
            ('atelier stella', '星辰工坊'),
            ('snow drop', '雪滴社'),
          ]),
        ),
        TagGroup(
          tagType: 'artist',
          galleryTags: genTags('artist', const <(String, String)>[
            ('mitsuki', '三月'),
            ('kurokawa_rei', '黑川怜'),
            ('minato_haru', '凑春'),
          ]),
        ),
        TagGroup(
          tagType: 'male',
          galleryTags: <GalleryTag>[
            const GalleryTag(
              title: 'sole male',
              type: 'male',
              tagTranslat: '唯一男性',
            ),
            const GalleryTag(
              title: 'glasses',
              type: 'male',
              tagTranslat: '眼镜',
            ),
            for (var i = 1; i <= 10; i++)
              GalleryTag(
                title: 'male_trait_$i',
                type: 'male',
                tagTranslat: '男性特征$i',
              ),
          ],
        ),
        TagGroup(
          tagType: 'female',
          galleryTags: <GalleryTag>[
            const GalleryTag(
              title: 'stockings',
              type: 'female',
              tagTranslat: '长筒袜',
            ),
            const GalleryTag(
              title: 'pantyhose',
              type: 'female',
              tagTranslat: '连裤袜',
            ),
            const GalleryTag(
              title: 'foot focus',
              type: 'female',
              tagTranslat: '足控',
            ),
            const GalleryTag(
              title: 'halo',
              type: 'female',
              tagTranslat: '光环',
            ),
            const GalleryTag(
              title: 'schoolgirl uniform',
              type: 'female',
              tagTranslat: '女学生制服',
            ),
            for (var i = 1; i <= 30; i++)
              GalleryTag(
                title: 'female_attribute_$i',
                type: 'female',
                tagTranslat: '女性属性$i',
              ),
          ],
        ),
        TagGroup(
          tagType: 'mixed',
          galleryTags: <GalleryTag>[
            for (var i = 1; i <= 5; i++)
              GalleryTag(
                title: 'mixed_scene_$i',
                type: 'mixed',
                tagTranslat: '混合场景$i',
              ),
          ],
        ),
        TagGroup(
          tagType: 'other',
          galleryTags: <GalleryTag>[
            const GalleryTag(
              title: 'full color',
              type: 'other',
              tagTranslat: '全彩',
            ),
            const GalleryTag(
              title: 'mosaic censorship',
              type: 'other',
              tagTranslat: '马赛克修正',
            ),
            for (var i = 1; i <= 8; i++)
              GalleryTag(
                title: 'other_meta_$i',
                type: 'other',
                tagTranslat: '其他元数据$i',
              ),
          ],
        ),
      ];

      final tags = FavRuleMatcher.fromTagGroups(tagGroups);
      expect(tags.length, 80);

      // Build 30 realistic rules exercising exact, contains, regex,
      // matchTranslation: true, and FavRuleMatch.all.
      // Note: `FavRuleMatcher.evaluate` evaluates ALL 30 enabled rules on every
      // iteration so secondary hits (`others`) are also collected.
      final rules = <FavRule>[
        for (var i = 1; i <= 8; i++)
          FavRule(
            id: 'exact_artist_$i',
            name: '画师精确规则 $i',
            favcat: '${i % 10}',
            conditions: <FavRuleCondition>[
              FavRuleCondition(
                namespace: 'artist',
                op: FavRuleOp.equals,
                value: i == 6 ? 'kurokawa rei' : 'other_artist_$i',
              ),
            ],
          ),
        for (var i = 1; i <= 6; i++)
          FavRule(
            id: 'contains_rule_$i',
            name: '包含匹配规则 $i',
            favcat: '${(i + 1) % 10}',
            conditions: <FavRuleCondition>[
              FavRuleCondition(
                namespace: i.isEven ? 'female' : null,
                op: FavRuleOp.contains,
                value: i == 5 ? 'schoolgirl' : 'nonexistent_keyword_$i',
              ),
            ],
          ),
        for (var i = 1; i <= 6; i++)
          FavRule(
            id: 'regex_rule_$i',
            name: '正则规则 $i',
            favcat: '${(i + 2) % 10}',
            conditions: <FavRuleCondition>[
              FavRuleCondition(
                namespace: i <= 4 ? 'female' : 'other',
                op: FavRuleOp.regex,
                value: i == 4
                    ? r'^(foot|leg)\s+focus$'
                    : '^unmatched_pattern_${i}_[a-z]+\$',
              ),
            ],
          ),
        for (var i = 1; i <= 5; i++)
          FavRule(
            id: 'trans_rule_$i',
            name: '中文译文规则 $i',
            favcat: '${(i + 3) % 10}',
            conditions: <FavRuleCondition>[
              FavRuleCondition(
                namespace: i.isOdd ? 'female' : 'parody',
                op: i.isOdd ? FavRuleOp.contains : FavRuleOp.equals,
                value: i == 3 ? '长筒袜' : '未命中译文$i',
                matchTranslation: true,
              ),
            ],
          ),
        for (var i = 1; i <= 5; i++)
          FavRule(
            id: 'all_combo_$i',
            name: '多条件组合规则 $i',
            match: FavRuleMatch.all,
            favcat: '${(i + 4) % 10}',
            conditions: <FavRuleCondition>[
              const FavRuleCondition(
                namespace: 'language',
                op: FavRuleOp.equals,
                value: 'chinese',
              ),
              FavRuleCondition(
                namespace: 'parody',
                op: FavRuleOp.equals,
                value: i == 5 ? '蔚蓝档案' : 'other_parody_$i',
                matchTranslation: true,
              ),
              FavRuleCondition(
                namespace: 'other',
                op: FavRuleOp.regex,
                value: i == 5 ? r'^full\s+color$' : r'^uncensored$',
              ),
            ],
          ),
      ];
      expect(rules.length, 30);

      // Warm up JIT across 100 iterations.
      for (var i = 0; i < 100; i++) {
        FavRuleMatcher.fromTagGroups(tagGroups);
        FavRuleMatcher.evaluate(rules, tags);
      }

      const iterations = 1000;
      final extractWatch = Stopwatch()..start();
      List<NormalizedTag> extracted = const <NormalizedTag>[];
      for (var i = 0; i < iterations; i++) {
        extracted = FavRuleMatcher.fromTagGroups(tagGroups);
      }
      extractWatch.stop();

      final evalWatch = Stopwatch()..start();
      FavRuleEvalResult result = FavRuleEvalResult.miss;
      for (var i = 0; i < iterations; i++) {
        result = FavRuleMatcher.evaluate(rules, extracted);
      }
      evalWatch.stop();

      final avgExtractUs = extractWatch.elapsedMicroseconds / iterations;
      final avgEvalUs = evalWatch.elapsedMicroseconds / iterations;

      // ignore: avoid_print
      print(
        '[FavRuleBenchmark] rules=30 tags=80 iterations=$iterations '
        'evalTotalUs=${evalWatch.elapsedMicroseconds} '
        'evalAvgUs=${avgEvalUs.toStringAsFixed(2)} '
        'coldExtractAvgUs=${avgExtractUs.toStringAsFixed(2)} '
        'combinedColdTapAvgUs=${(avgExtractUs + avgEvalUs).toStringAsFixed(2)}',
      );

      expect(result.isHit, isTrue);
      expect(result.primary!.rule.id, 'exact_artist_6');
      expect(
        result.others.map((h) => h.rule.id).toList(),
        <String>[
          'contains_rule_5',
          'regex_rule_4',
          'trans_rule_3',
          'all_combo_5',
        ],
      );
      // Sub-2ms per tap budget even on loaded CI runners (typically ~30-90 us).
      expect(avgEvalUs, lessThan(2000));
    });
  });
}
