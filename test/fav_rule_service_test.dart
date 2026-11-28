import 'dart:async';
import 'dart:convert';

import 'package:eros_fe/common/controller/cache_controller.dart';
import 'package:eros_fe/common/controller/favorite_state_store.dart';
import 'package:eros_fe/common/controller/localfav_controller.dart';
import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/fav_rule_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/fav_rule.dart';
import 'package:eros_fe/models/favcat.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/models/gallery_tag.dart';
import 'package:eros_fe/models/simple_tag.dart';
import 'package:eros_fe/models/tag_group.dart';
import 'package:eros_fe/models/user.dart';
import 'package:eros_fe/pages/controller/fav_controller.dart';
import 'package:eros_fe/pages/controller/favorite_sel_controller.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_fav_controller.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_controller.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_state.dart';
import 'package:eros_fe/pages/item/controller/galleryitem_controller.dart';
import 'package:eros_fe/widget/fav_rule_toast.dart';
import 'package:eros_fe/widget/fav_rule_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:oktoast/oktoast.dart';

void main() {
  group('FavRuleService migration & persistence', () {
    test('migrates legacy one-step favorite user cleanly once', () async {
      String? stored;
      var legacyOneStepFlag = true;
      final service = FavRuleService(
        readJson: () => stored,
        writeJson: (json) async => stored = json,
        readLegacyOneStep: () => legacyOneStepFlag,
        syncLegacyOneStep: (val) => legacyOneStepFlag = val,
        readLegacyFavPicker: () => true,
      );

      service.loadAndMigrate();
      expect(service.config.enabled, isTrue);
      expect(service.config.trigger, FavRuleTrigger.tap);
      expect(service.config.fallback, FavRuleFallback.last);
      expect(service.config.pickerStyle, FavPickerStyle.wheel);
      expect(service.config.migratedFromOneStep, isTrue);
      expect(service.config.showMigrationBanner, isTrue);
      // Legacy one-step flag is consumed so disabling Rule Favorites later
      // cannot silently auto-save via `isFavLongTap`.
      expect(legacyOneStepFlag, isFalse);

      // User changes trigger and dismisses banner.
      await service.setTrigger(FavRuleTrigger.longPress);
      await service.dismissMigrationBanner();

      // Reloading should NOT re-run migration or overwrite user choices.
      final reloaded = FavRuleService(
        readJson: () => stored,
        writeJson: (json) async => stored = json,
        readLegacyOneStep: () => true,
        readLegacyFavPicker: () => true,
      );
      reloaded.loadAndMigrate();
      expect(reloaded.config.trigger, FavRuleTrigger.longPress);
      expect(reloaded.config.showMigrationBanner, isFalse);
    });

    test('upgrades v1 stored config to v2 tap trigger even when unmigrated', () {
      var stored = jsonEncode(<String, dynamic>{
        'version': 1,
        'enabled': true,
        'trigger': 'longPress',
        'migratedFromOneStep': false,
        'rules': <Map<String, dynamic>>[],
      });
      final service = FavRuleService(
        readJson: () => stored,
        writeJson: (json) async => stored = json,
        readLegacyOneStep: () => false,
        readLegacyFavPicker: () => false,
      );

      service.loadAndMigrate();
      expect(service.config.version, FavRuleConfig.currentVersion);
      expect(service.config.trigger, FavRuleTrigger.tap);
      expect(service.config.migratedFromOneStep, isTrue);
    });

    test('CRUD, reorder, style toggles, and hit recording persist', () async {
      String? stored;
      bool? syncedWheel;
      final service = FavRuleService(
        readJson: () => stored,
        writeJson: (json) async => stored = json,
        readLegacyOneStep: () => false,
        readLegacyFavPicker: () => false,
        syncLegacyFavPicker: (val) => syncedWheel = val,
      );
      service.loadAndMigrate();
      expect(service.enabled, isFalse);

      final r1 = await service.addRule(
        const FavRule(
          id: '',
          name: 'Artist A',
          favcat: '1',
          conditions: <FavRuleCondition>[
            FavRuleCondition(namespace: 'artist', value: 'mitsuki'),
          ],
        ),
      );
      // Adding first rule auto-enables rule favorites.
      expect(service.enabled, isTrue);
      expect(r1.id, isNotEmpty);

      final r2 = await service.addRule(
        const FavRule(
          id: '',
          name: 'Foot',
          favcat: '2',
          conditions: <FavRuleCondition>[
            FavRuleCondition(op: FavRuleOp.contains, value: 'foot'),
          ],
        ),
      );

      await service.reorderRules(1, 0);
      expect(service.rules.map((r) => r.id).toList(), <String>[r2.id, r1.id]);

      await service.recordHit(r2.id);
      expect(service.rules.first.hitCount, 1);
      expect(service.rules.first.lastHitAt, isNotNull);

      await service.setListMenuStyle(FavListMenuStyle.actionSheet);
      expect(service.config.listMenuStyle, FavListMenuStyle.actionSheet);

      await service.setPickerStyle(FavPickerStyle.wheel);
      expect(service.config.pickerStyle, FavPickerStyle.wheel);
      expect(syncedWheel, isTrue);

      await service.setPickerStyle(FavPickerStyle.grid);
      expect(syncedWheel, isFalse);

      await service.deleteRule(r1.id);
      expect(service.rules.length, 1);
    });

    test('fetches full API tags once and caches by gid', () async {
      var apiCalls = 0;
      String? stored;
      final service = FavRuleService(
        readJson: () => stored,
        writeJson: (json) async => stored = json,
        readLegacyOneStep: () => false,
        readLegacyFavPicker: () => false,
        fetchApiTags: (gid, token) async {
          apiCalls++;
          return <String>['artist:mitsuki', 'female:stockings'];
        },
      );
      service.loadAndMigrate();
      await service.addRule(
        const FavRule(
          id: 'r1',
          name: 'Artist',
          favcat: '1',
          conditions: <FavRuleCondition>[
            FavRuleCondition(namespace: 'artist', value: 'mitsuki'),
          ],
        ),
      );

      const listCard = GalleryProvider(
        gid: '42',
        token: 'tok',
        simpleTags: <SimpleTag>[SimpleTag(text: 'stockings')],
      );

      final first = await service.evaluateGalleryWithFetch(listCard);
      expect(first.isHit, isTrue);
      expect(first.primary!.rule.favcat, '1');
      expect(apiCalls, 1);

      // Second evaluation hits cache with zero extra API calls.
      final second = await service.evaluateGalleryWithFetch(listCard);
      expect(second.isHit, isTrue);
      expect(apiCalls, 1);
    });

    test('failed tag fetch produces no unobserved error future and allows retry',
        () async {
      var attempts = 0;
      String? stored;
      final uncaught = <Object>[];

      await runZonedGuarded(() async {
        final service = FavRuleService(
          readJson: () => stored,
          writeJson: (json) async => stored = json,
          readLegacyOneStep: () => false,
          readLegacyFavPicker: () => false,
          fetchApiTags: (gid, token) async {
            attempts++;
            if (attempts == 1) {
              throw StateError('network down');
            }
            return <String>['artist:mitsuki'];
          },
        );
        service.loadAndMigrate();
        await service.addRule(
          const FavRule(
            id: 'r1',
            favcat: '1',
            conditions: <FavRuleCondition>[
              FavRuleCondition(namespace: 'artist', value: 'mitsuki'),
            ],
          ),
        );

        const card = GalleryProvider(
          gid: '501',
          token: 'tok',
          simpleTags: <SimpleTag>[SimpleTag(text: 'stockings')],
        );

        await expectLater(
          service.evaluateGalleryWithFetch(card),
          throwsA(isA<StateError>()),
        );
        await Future<void>.delayed(Duration.zero);

        final retry = await service.evaluateGalleryWithFetch(card);
        expect(retry.isHit, isTrue);
        expect(attempts, 2);
      }, (error, _) {
        uncaught.add(error);
      });

      expect(uncaught, isEmpty);
    });

    test(
        'upgrades stored v1 config (build 216/218) to v2 tap trigger once and preserves rules',
        () async {
      var stored = jsonEncode(<String, dynamic>{
        'version': 1,
        'enabled': true,
        'trigger': 'longPress',
        'fallback': 'picker',
        'fallbackFavcat': '0',
        'existing': 'move',
        'listMenuStyle': 'contextMenu',
        'pickerStyle': 'grid',
        'migratedFromOneStep': true,
        'showMigrationBanner': false,
        'rules': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'r_v1',
            'name': 'Artist Mitsuki',
            'enabled': true,
            'match': 'any',
            'favcat': '2',
            'hitCount': 5,
            'conditions': <Map<String, dynamic>>[
              <String, dynamic>{
                'namespace': 'artist',
                'op': 'equals',
                'value': 'mitsuki',
                'matchTranslation': false,
              },
            ],
          },
        ],
      });

      final service = FavRuleService(
        readJson: () => stored,
        writeJson: (json) async => stored = json,
        readLegacyOneStep: () => false,
        readLegacyFavPicker: () => false,
      );

      service.loadAndMigrate();
      expect(service.config.version, 2);
      expect(service.config.trigger, FavRuleTrigger.tap);
      expect(service.config.enabled, isTrue);
      expect(service.config.rules.length, 1);
      expect(service.config.rules.first.id, 'r_v1');

      final persistedJson = jsonDecode(stored) as Map<String, dynamic>;
      expect(persistedJson['version'], 2);
      expect(persistedJson['trigger'], 'tap');

      // If the user explicitly chooses longPress AFTER v2 upgrade, reloading
      // keeps their explicit choice without re-running the v2 migration.
      await service.setTrigger(FavRuleTrigger.longPress);
      final reloaded = FavRuleService(
        readJson: () => stored,
        writeJson: (json) async => stored = json,
        readLegacyOneStep: () => false,
        readLegacyFavPicker: () => false,
      );
      reloaded.loadAndMigrate();
      expect(reloaded.config.version, 2);
      expect(reloaded.config.trigger, FavRuleTrigger.longPress);
    });

    test('reuses cached detail-page TagGroup tags in O(1) without extra allocations or network',
        () {
      var apiCalls = 0;
      String? stored;
      final service = FavRuleService(
        readJson: () => stored,
        writeJson: (json) async => stored = json,
        readLegacyOneStep: () => false,
        readLegacyFavPicker: () => false,
        fetchApiTags: (_, _) async {
          apiCalls++;
          return const <String>[];
        },
      );
      service.loadAndMigrate();

      const detailProvider = GalleryProvider(
        gid: '9001',
        token: 'tok9001',
        tagGroup: <TagGroup>[
          TagGroup(
            tagType: 'artist',
            galleryTags: <GalleryTag>[
              GalleryTag(title: 'mitsuki', type: 'artist', tagTranslat: '三月'),
            ],
          ),
        ],
      );

      service.cacheTagsForGallery(detailProvider);
      final first = service.resolveCachedFullTags(detailProvider);
      final second = service.resolveCachedFullTags(detailProvider);
      expect(first, isNotNull);
      expect(identical(first, second), isTrue);
      expect(service.needsAsyncTagFetch(detailProvider), isFalse);
      expect(apiCalls, 0);
    });

    test(
        'countRulesUsingCategory and hasEnabledPureCategoryRuleFor track Non-H category rules accurately',
        () async {
      String? stored;
      final service = FavRuleService(
        readJson: () => stored,
        writeJson: (json) async => stored = json,
        readLegacyOneStep: () => false,
        readLegacyFavPicker: () => false,
      );
      service.loadAndMigrate();

      expect(service.countRulesUsingCategory('Non-H'), 0);
      expect(service.hasEnabledPureCategoryRuleFor('Non-H'), isFalse);

      // 1) Disabled pure-category rule counts toward usage, but NOT enabled pure rule.
      await service.addRule(
        FavRule(
          id: 'r_disabled_nonh',
          enabled: false,
          favcat: '0',
          conditions: <FavRuleCondition>[
            FavRuleCondition.category(const <String>['Non-H']),
          ],
        ),
      );
      expect(service.countRulesUsingCategory('Non-H'), 1);
      expect(service.countRulesUsingCategory('non-h'), 1);
      expect(service.hasEnabledPureCategoryRuleFor('Non-H'), isFalse);

      // 2) Enabled negated category rule counts toward usage, but NOT positive pure rule.
      await service.addRule(
        FavRule(
          id: 'r_neg_nonh',
          enabled: true,
          favcat: '1',
          conditions: <FavRuleCondition>[
            FavRuleCondition.category(const <String>['Non-H'], negated: true),
          ],
        ),
      );
      expect(service.countRulesUsingCategory('Non-H'), 2);
      expect(service.hasEnabledPureCategoryRuleFor('Non-H'), isFalse);

      // 3) Enabled mixed category + tag rule counts toward usage, but NOT pure-category rule.
      await service.addRule(
        FavRule(
          id: 'r_mixed_nonh',
          enabled: true,
          match: FavRuleMatch.all,
          favcat: '2',
          conditions: <FavRuleCondition>[
            FavRuleCondition.category(const <String>['Non-H']),
            const FavRuleCondition(namespace: 'artist', value: 'mitsuki'),
          ],
        ),
      );
      expect(service.countRulesUsingCategory('Non-H'), 3);
      expect(service.hasEnabledPureCategoryRuleFor('Non-H'), isFalse);

      // 4) Enabled positive pure-category rule (single or multi-value) satisfies both!
      await service.addRule(
        FavRule(
          id: 'r_pure_nonh',
          enabled: true,
          favcat: '0',
          conditions: <FavRuleCondition>[
            FavRuleCondition.category(const <String>['Non-H', 'Image Set']),
          ],
        ),
      );
      expect(service.countRulesUsingCategory('Non-H'), 4);
      expect(service.hasEnabledPureCategoryRuleFor('Non-H'), isTrue);
      expect(service.hasEnabledPureCategoryRuleFor('Image Set'), isTrue);
      expect(service.hasEnabledPureCategoryRuleFor('Manga'), isFalse);
    });

    test('dismissRememberCombo persists Non-H + favcat dismissal across reload',
        () async {
      String? stored;
      final service = FavRuleService(
        readJson: () => stored,
        writeJson: (json) async => stored = json,
        readLegacyOneStep: () => false,
        readLegacyFavPicker: () => false,
      );
      service.loadAndMigrate();

      expect(service.isRememberComboDismissed('Non-H', '0'), isFalse);

      await service.dismissRememberCombo('non-h', '0');
      await service.dismissRememberCombo('Non-H', '0'); // deduplicated
      expect(service.isRememberComboDismissed('Non-H', '0'), isTrue);
      expect(service.isRememberComboDismissed('无H', '0'), isTrue);
      expect(service.isRememberComboDismissed('Non-H', '1'), isFalse);
      expect(service.config.dismissedRememberKeys, <String>['Non-H->0']);

      final reloaded = FavRuleService(
        readJson: () => stored,
        writeJson: (json) async => stored = json,
        readLegacyOneStep: () => false,
        readLegacyFavPicker: () => false,
      );
      reloaded.loadAndMigrate();
      expect(reloaded.isRememberComboDismissed('Non-H', '0'), isTrue);
      expect(reloaded.isRememberComboDismissed('Non-H', '2'), isFalse);
    });

    test(
        'extractSuggestionTags places gallery category Non-H first ahead of parody and artist tags',
        () {
      String? stored;
      final service = FavRuleService(
        readJson: () => stored,
        writeJson: (json) async => stored = json,
        readLegacyOneStep: () => false,
        readLegacyFavPicker: () => false,
      );
      service.loadAndMigrate();

      const provider = GalleryProvider(
        gid: '9100',
        token: 'tok9100',
        category: 'Non-H',
        tagGroup: <TagGroup>[
          TagGroup(
            tagType: 'female',
            galleryTags: <GalleryTag>[
              GalleryTag(title: 'glasses', type: 'female', tagTranslat: '眼镜'),
            ],
          ),
          TagGroup(
            tagType: 'artist',
            galleryTags: <GalleryTag>[
              GalleryTag(title: 'mitsuki', type: 'artist', tagTranslat: '三月'),
            ],
          ),
          TagGroup(
            tagType: 'parody',
            galleryTags: <GalleryTag>[
              GalleryTag(
                title: 'blue archive',
                type: 'parody',
                tagTranslat: '蔚蓝档案',
              ),
            ],
          ),
        ],
      );

      final suggestions = service.extractSuggestionTags(provider, maxCount: 4);
      expect(suggestions, hasLength(4));
      expect(suggestions[0].isCategory, isTrue);
      expect(suggestions[0].rawTitle, 'Non-H');
      expect(suggestions[1].key, 'parody:blue archive');
      expect(suggestions[2].key, 'artist:mitsuki');
      expect(suggestions[3].key, 'female:glasses');
    });

    test(
        'gdata-fetched _tagCache[gid] preserves provider.category Non-H for category rule matching',
        () async {
      var apiCalls = 0;
      String? stored;
      final service = FavRuleService(
        readJson: () => stored,
        writeJson: (json) async => stored = json,
        readLegacyOneStep: () => false,
        readLegacyFavPicker: () => false,
        fetchApiTags: (gid, token) async {
          apiCalls++;
          // E-Hentai gdata tags list never contains synthetic category:Non-H!
          return <String>['artist:hanako', 'other:full color'];
        },
      );
      service.loadAndMigrate();

      // High-priority namespaced rule misses ('artist:mitsuki'), forcing gdata fetch
      // on the incomplete list card while lower-priority rule matches category Non-H.
      await service.addRule(
        const FavRule(
          id: 'r_artist_miss',
          favcat: '1',
          conditions: <FavRuleCondition>[
            FavRuleCondition(namespace: 'artist', value: 'mitsuki'),
          ],
        ),
      );
      await service.addRule(
        FavRule(
          id: 'r_cat_nonh',
          favcat: '0',
          conditions: <FavRuleCondition>[
            FavRuleCondition.category(const <String>['Non-H']),
          ],
        ),
      );

      const listCard = GalleryProvider(
        gid: '701',
        token: 'tok701',
        category: 'Non-H',
        simpleTags: <SimpleTag>[SimpleTag(text: 'full color')],
      );

      final firstEval = await service.evaluateGalleryWithFetch(listCard);
      expect(apiCalls, 1);
      expect(firstEval.isHit, isTrue);
      expect(firstEval.primary!.rule.id, 'r_cat_nonh');
      expect(firstEval.primary!.primaryTag!.isCategory, isTrue);
      expect(firstEval.primary!.primaryTag!.rawTitle, 'Non-H');

      // Subsequent sync & async evaluations reuse _tagCache['701'] with Non-H preserved
      // (even if a bare gid-only provider is passed) and 0 extra network calls!
      const bareProviderWithSameGid = GalleryProvider(
        gid: '701',
        token: 'tok701',
      );
      final cachedSync = service.evaluateGallerySync(bareProviderWithSameGid);
      expect(cachedSync.isHit, isTrue);
      expect(cachedSync.primary!.rule.id, 'r_cat_nonh');

      final secondEval = await service.evaluateGalleryWithFetch(listCard);
      expect(secondEval.isHit, isTrue);
      expect(secondEval.primary!.rule.id, 'r_cat_nonh');
      expect(apiCalls, 1);
    });
  });

  group('GalleryFavController detail-page heart tap & long-press behavior', () {
    const galleryTag = 'detail_heart_test';

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('eros/accessibility-settings'),
        (_) async => null,
      );
      Get.testMode = true;
      Get.reset();
    });

    tearDown(() {
      dismissFavRuleFeedbackBanner();
      Get.reset();
    });

    testWidgets(
        'tapFav evaluates rules directly (auto-saves on hit, opens picker with missContext on miss) '
        'and longTapFav always opens manual folder picker', (tester) async {
      Get.put<EhSettingService>(_HeartTestSettings());
      Get.put<ThemeService>(_HeartTestTheme());
      Get.put<CacheController>(_NoopCacheController());
      Get.put<UserController>(_HeartLoggedInUser());
      Get.put<FavoriteSelectorController>(_FakeFavoriteSelectorController());
      final fakeFav = _HeartRecordingFavController();
      Get.put<FavController>(fakeFav);

      String? stored;
      final ruleService = FavRuleService(
        readJson: () => stored,
        writeJson: (json) async => stored = json,
        readLegacyOneStep: () => false,
        readLegacyFavPicker: () => false,
      );
      ruleService.loadAndMigrate();
      expect(ruleService.config.trigger, FavRuleTrigger.tap);
      await ruleService.addRule(
        const FavRule(
          id: 'r_artist',
          name: '喜欢的画师',
          favcat: '2',
          conditions: <FavRuleCondition>[
            FavRuleCondition(namespace: 'artist', value: 'mitsuki'),
          ],
        ),
      );
      Get.put<FavRuleService>(ruleService);

      final pageState = GalleryPageState()
        ..galleryProvider = const GalleryProvider(
          gid: '1001',
          token: 'tok1001',
          englishTitle: 'Mitsuki Artworks',
          tagGroup: <TagGroup>[
            TagGroup(
              tagType: 'artist',
              galleryTags: <GalleryTag>[
                GalleryTag(title: 'mitsuki', type: 'artist', tagTranslat: '三月'),
              ],
            ),
          ],
        );
      Get.put<GalleryPageController>(
        _FakeGalleryPageController(pageState),
        tag: galleryTag,
      );

      await tester.pumpWidget(_wrapHeartApp());
      await tester.pumpAndSettle();

      final favCtrl = Get.put<GalleryFavController>(
        GalleryFavController(galleryTag: galleryTag),
        tag: galleryTag,
      );

      // 1) Un-favorited + rule matches: tapping ♡ saves directly to rule's folder ('2')!
      await favCtrl.tapFav();
      await tester.pump();
      expect(fakeFav.savedFavcats, <String>['2']);
      expect(fakeFav.selectCalls, 0);
      expect(favCtrl.isFav, isTrue);
      expect(favCtrl.favcat, '2');

      // 2) Already favorited + trigger == tap: long-pressing ♡ ALWAYS opens manual picker!
      fakeFav.nextPickerSelection =
          const Favcat(favId: '5', favTitle: '收藏夹 5');
      await favCtrl.longTapFav();
      await tester.pump();
      expect(fakeFav.selectCalls, 1);
      expect(fakeFav.lastSelectOriFavcat, '2');
      expect(fakeFav.lastMissContext, isNull);
      expect(favCtrl.favcat, '5');

      // 3) Already favorited: tapping ♡ unfavorites (`delFav`).
      await favCtrl.tapFav();
      await tester.pump();
      expect(fakeFav.deletedGids, <String>['1001']);
      expect(favCtrl.isFav, isFalse);

      // 4) Un-favorited (even when matching rule exists!) + long-pressing ♡:
      // still opens manual picker instead of auto-applying rule!
      fakeFav.nextPickerSelection = null; // user cancels picker
      await favCtrl.longTapFav();
      await tester.pump();
      expect(fakeFav.selectCalls, 2);
      expect(fakeFav.lastMissContext, isNull);
      expect(favCtrl.isFav, isFalse);

      // 5) Un-favorited + NO rule matches + default fallback (picker):
      // tapping ♡ opens folder picker with `ruleMissContext` populated!
      pageState.galleryProvider = const GalleryProvider(
        gid: '1001',
        token: 'tok1001',
        englishTitle: 'Unmatched Gallery',
        tagGroup: <TagGroup>[
          TagGroup(
            tagType: 'artist',
            galleryTags: <GalleryTag>[
              GalleryTag(title: 'hanako', type: 'artist', tagTranslat: '花子'),
            ],
          ),
        ],
      );
      ruleService.cacheTagsForGallery(pageState.galleryProvider!);
      await favCtrl.tapFav();
      await tester.pump();
      expect(fakeFav.selectCalls, 3);
      expect(fakeFav.lastMissContext, isNotNull);
      expect(
        fakeFav.lastMissContext!.keyTags.map((t) => t.key),
        contains('artist:hanako'),
      );

      // 6) Explicit fallback (FavRuleFallback.fixed) is still respected on miss!
      await ruleService.setFallback(FavRuleFallback.fixed);
      await ruleService.setFallbackFavcat('4');
      await favCtrl.tapFav();
      await tester.pump();
      expect(fakeFav.savedFavcats, <String>['2', '4']);
      expect(fakeFav.selectCalls, 3);
      expect(favCtrl.favcat, '4');

      // 7) Under trigger=longPress, moving an already-favorited gallery aborts
      //    both fallback move AND rule-hit move if loadFavoriteNote fails!
      await ruleService.setTrigger(FavRuleTrigger.longPress);
      await ruleService.setExisting(FavRuleExisting.move);
      await ruleService.setFallbackFavcat('5');
      fakeFav.throwOnNoteRead = true;
      fakeFav.storedNote = 'detail precious note';

      // 7a) Fallback move (4 -> 5) aborts when note lookup fails
      await favCtrl.longTapFav();
      await tester.pump();
      expect(fakeFav.savedFavcats, <String>['2', '4']);
      expect(favCtrl.favcat, '4');

      // 7b) Rule-hit move (4 -> 2) ALSO aborts when note lookup fails
      pageState.galleryProvider = const GalleryProvider(
        gid: '1001',
        token: 'tok1001',
        englishTitle: 'Matched Again',
        tagGroup: <TagGroup>[
          TagGroup(
            tagType: 'artist',
            galleryTags: <GalleryTag>[
              GalleryTag(title: 'mitsuki', type: 'artist', tagTranslat: '光月'),
            ],
          ),
        ],
      );
      ruleService.cacheTagsForGallery(pageState.galleryProvider!);
      await favCtrl.longTapFav();
      await tester.pump();
      expect(fakeFav.savedFavcats, <String>['2', '4']);
      expect(favCtrl.favcat, '4');

      // 7c) Once loadFavoriteNote succeeds, move proceeds with preserved note
      fakeFav.throwOnNoteRead = false;
      await favCtrl.longTapFav();
      await tester.pump();
      expect(fakeFav.savedFavcats, <String>['2', '4', '2']);
      expect(fakeFav.savedNotes.last, 'detail precious note');
      expect(favCtrl.favcat, '2');

      dismissAllToast(showAnim: false);
      dismissFavRuleFeedbackBanner();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets(
        'detail and list manual picker saves on Non-H rule miss trigger Remember banner, '
        'create/undo Non-H rule, and persist explicit close dismissal',
        (tester) async {
      Get.put<EhSettingService>(_HeartTestSettings());
      Get.put<ThemeService>(_HeartTestTheme());
      Get.put<CacheController>(_NoopCacheController());
      Get.put<UserController>(_HeartLoggedInUser());
      Get.put<FavoriteSelectorController>(_FakeFavoriteSelectorController());
      final fakeFav = _HeartRecordingFavController();
      Get.put<FavController>(fakeFav);

      String? stored;
      final ruleService = FavRuleService(
        readJson: () => stored,
        writeJson: (json) async => stored = json,
        readLegacyOneStep: () => false,
        readLegacyFavPicker: () => false,
      );
      ruleService.loadAndMigrate();
      expect(ruleService.enabled, isFalse);
      expect(ruleService.rules, isEmpty);
      Get.put<FavRuleService>(ruleService);

      const rememberTag = 'detail_remember_test';
      final pageState = GalleryPageState()
        ..galleryProvider = const GalleryProvider(
          gid: '2001',
          token: 'tok2001',
          englishTitle: 'All-Ages Art Collection',
          category: 'Non-H',
          tagGroup: <TagGroup>[
            TagGroup(
              tagType: 'artist',
              galleryTags: <GalleryTag>[
                GalleryTag(title: 'hanako', type: 'artist', tagTranslat: '花子'),
              ],
            ),
          ],
        );
      Get.put<GalleryPageController>(
        _FakeGalleryPageController(pageState),
        tag: rememberTag,
      );

      await tester.pumpWidget(_wrapHeartApp());
      await tester.pumpAndSettle();

      final favCtrl = Get.put<GalleryFavController>(
        GalleryFavController(galleryTag: rememberTag),
        tag: rememberTag,
      );

      // 1) Detail manual picker save on rule miss (0 rules) triggers Step 1 "记住" banner!
      fakeFav.nextPickerSelection = const Favcat(favId: '0', favTitle: '全年龄');
      await favCtrl.tapFav();
      await tester.pumpAndSettle();

      expect(fakeFav.selectCalls, 1);
      expect(fakeFav.lastMissContext, isNotNull);
      expect(fakeFav.lastMissContext!.keyTags.first.isCategory, isTrue);
      expect(fakeFav.lastMissContext!.keyTags.first.rawTitle, 'Non-H');

      expect(find.text('已收进「全年龄」'), findsOneWidget);
      expect(find.text('以后 '), findsOneWidget);
      expect(find.byType(FavCategoryBadge), findsOneWidget);
      expect(find.text('Non-H'), findsOneWidget);
      expect(find.text(' 也收进这里？'), findsOneWidget);
      expect(find.text('记住'), findsOneWidget);
      expect(find.byKey(kFavRuleBannerCloseButtonKey), findsOneWidget);

      // 2) Tapping `记住` creates an enabled Non-H -> '0' rule and transitions to `已新建规则`!
      await tester.tap(find.text('记住'));
      await tester.pumpAndSettle();

      expect(ruleService.enabled, isTrue);
      expect(ruleService.rules, hasLength(1));
      final createdRule = ruleService.rules.single;
      expect(createdRule.enabled, isTrue);
      expect(createdRule.favcat, '0');
      expect(createdRule.conditions, hasLength(1));
      expect(createdRule.conditions.single.isCategory, isTrue);
      expect(createdRule.conditions.single.categoryValues, <String>['Non-H']);
      expect(ruleService.hasEnabledPureCategoryRuleFor('Non-H'), isTrue);

      expect(find.text('已新建规则'), findsOneWidget);
      expect(find.textContaining('收进「全年龄」'), findsOneWidget);
      expect(find.text('撤销'), findsOneWidget);

      // 3) Tapping `撤销` deletes that newly created rule!
      await tester.tap(find.text('撤销'));
      await tester.pumpAndSettle();
      expect(ruleService.rules, isEmpty);
      expect(ruleService.hasEnabledPureCategoryRuleFor('Non-H'), isFalse);

      // 4) List manual picker save (`GalleryItemController.addFavorite`) on rule miss
      //    also shows the "记住" banner; tapping `×` dismisses and suppresses future
      //    prompts for the same `Non-H + '0'` pair!
      final listItem1 = GalleryItemController(
        galleryProvider: const GalleryProvider(
          gid: '2002',
          token: 'tok2002',
          englishTitle: 'List Non-H Sketchbook 1',
          category: 'Non-H',
        ),
      );
      fakeFav.nextPickerSelection = const Favcat(favId: '0', favTitle: '全年龄');
      await listItem1.addFavorite();
      await tester.pumpAndSettle();

      expect(find.text('记住'), findsOneWidget);
      expect(find.byKey(kFavRuleBannerCloseButtonKey), findsOneWidget);

      await tester.tap(find.byKey(kFavRuleBannerCloseButtonKey));
      await tester.pumpAndSettle();
      expect(ruleService.isRememberComboDismissed('Non-H', '0'), isTrue);
      expect(ruleService.rules, isEmpty);

      // Saving another Non-H gallery to the dismissed '0' folder suppresses the prompt:
      final listItem2 = GalleryItemController(
        galleryProvider: const GalleryProvider(
          gid: '2003',
          token: 'tok2003',
          englishTitle: 'List Non-H Sketchbook 2',
          category: 'Non-H',
        ),
      );
      await listItem2.addFavorite();
      await tester.pump();
      expect(find.text('记住'), findsNothing);

      // Whereas choosing a different folder ('1') for Non-H still offers to remember:
      final listItem3 = GalleryItemController(
        galleryProvider: const GalleryProvider(
          gid: '2004',
          token: 'tok2004',
          englishTitle: 'List Non-H Sketchbook 3',
          category: 'Non-H',
        ),
      );
      fakeFav.nextPickerSelection =
          const Favcat(favId: '1', favTitle: '收藏夹 1');
      await listItem3.addFavorite();
      await tester.pumpAndSettle();
      expect(find.text('记住'), findsOneWidget);

      dismissAllToast(showAnim: false);
      dismissFavRuleFeedbackBanner();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });

  group('Partial translation enrichment & local/network favorite transitions', () {
    setUp(() {
      Get.testMode = true;
      favoriteStates.setAccount('test-round2');
    });

    tearDown(() async {
      dismissFavRuleFeedbackBanner();
      await Get.deleteAll(force: true);
      Get.reset();
    });

    test(
        'enriches individual missing translations when some tags are already translated',
        () async {
      final lookedUp = <String>[];
      String? stored;
      final service = FavRuleService(
        readJson: () => stored,
        writeJson: (json) async => stored = json,
        readLegacyOneStep: () => false,
        readLegacyFavPicker: () => false,
        lookupTranslation: (rawTitle, {namespace}) async {
          lookedUp.add('${namespace ?? ''}:$rawTitle');
          if (rawTitle == 'glasses') {
            return '眼镜';
          }
          return null;
        },
      );
      service.loadAndMigrate();
      await service.addRule(
        const FavRule(
          id: 'r_trans',
          name: '眼镜控',
          favcat: '3',
          conditions: <FavRuleCondition>[
            FavRuleCondition(
              value: '眼镜',
              matchTranslation: true,
            ),
          ],
        ),
      );

      const partialProvider = GalleryProvider(
        gid: '3001',
        token: 'tok3001',
        tagGroup: <TagGroup>[
          TagGroup(
            tagType: 'female',
            galleryTags: <GalleryTag>[
              // Already translated -> should NOT block enriching `glasses`!
              GalleryTag(
                title: 'stockings',
                type: 'female',
                tagTranslat: '丝袜',
              ),
              GalleryTag(
                title: 'glasses',
                type: 'female',
                tagTranslat: '',
              ),
            ],
          ),
        ],
      );

      expect(service.needsAsyncTagFetch(partialProvider), isTrue);
      final eval = await service.evaluateGalleryWithFetch(partialProvider);
      expect(eval.isHit, isTrue);
      expect(eval.primary?.rule.favcat, '3');
      // Only the untranslated tag (`female:glasses`) needed a lookup!
      expect(lookedUp, <String>['female:glasses']);
      // Marked enriched -> subsequent check is synchronous O(1) (`false`)
      expect(service.needsAsyncTagFetch(partialProvider), isFalse);
      expect(service.evaluateGallerySync(partialProvider).isHit, isTrue);
    });

    testWidgets(
        'FavController selectToSave and saveToFavcat move cleanly between local and network without duplicates or stale metadata',
        (tester) async {
      Get.put<EhSettingService>(_HeartTestSettings());
      Get.put<ThemeService>(_HeartTestTheme());
      Get.put<UserController>(_HeartLoggedInUser());
      final selector = _FakeFavoriteSelectorController();
      Get.put<FavoriteSelectorController>(selector);
      final localFavs = _MemoryLocalFavController();
      Get.put<LocalFavController>(localFavs);
      final realFav = _TestableFavController();
      Get.put<FavController>(realFav);

      await tester.pumpWidget(_wrapHeartApp());
      await tester.pumpAndSettle();

      const staleNetworkProvider = GalleryProvider(
        gid: '4001',
        token: 'tok4001',
        englishTitle: 'Transition Test Gallery',
        favcat: '2',
        favTitle: '收藏夹 2',
        favNote: 'old note',
        localFav: false,
      );
      favoriteStates.commit('4001', '2', '收藏夹 2');

      // 1) Picker move from network ('2') -> local ('l'):
      // removes network favorite AND stores normalized provider (`localFav: true`, `favcat: ''`).
      realFav.dialogChoice = const Favcat(favId: 'l', favTitle: '本地收藏');
      final movedToLocal = await realFav.selectToSave(
        '4001',
        'tok4001',
        oriFavcat: '2',
        galleryProvider: staleNetworkProvider,
      );
      expect(movedToLocal?.favId, 'l');
      expect(realFav.networkCalls, <String>['4001:favdel']);
      expect(localFavs.loacalFavs, hasLength(1));
      final storedLocal = localFavs.loacalFavs.single;
      expect(storedLocal.localFav, isTrue);
      expect(storedLocal.favcat, isEmpty);
      expect(storedLocal.favTitle, isEmpty);

      // Reopening from Local Favorites recognizes `favCat == 'l'` and `isFav == true`!
      final reopenedItem = GalleryItemController(galleryProvider: storedLocal);
      expect(reopenedItem.isFav, isTrue);
      expect(reopenedItem.favCat, 'l');

      // 2) Simulate detail page authoritative empty network read (`''`), then
      // picker move from local ('l') -> network ('5'): must remove local membership!
      favoriteStates.acceptRead(
        const GalleryProvider(gid: '4001', favcat: '', favTitle: ''),
        favoriteStates.version,
        favoriteStates.epoch,
        authoritative: true,
      );
      realFav.dialogChoice = const Favcat(favId: '5', favTitle: '收藏夹 5');
      final movedToNet = await realFav.selectToSave(
        '4001',
        'tok4001',
        oriFavcat: 'l',
        galleryProvider: storedLocal,
      );
      expect(movedToNet?.favId, '5');
      expect(realFav.networkCalls, <String>['4001:favdel', '4001:5']);
      expect(localFavs.loacalFavs, isEmpty);
    });

    test(
        'LocalFavController.onInit normalizes legacy entries, deduplicates by gid, and persists corrections once',
        () {
      var persistedSnapshots = 0;
      List<GalleryProvider> backingStore = <GalleryProvider>[
        const GalleryProvider(
          gid: '5001',
          token: 'tok5001',
          englishTitle: 'Legacy Unmarked Local Fav',
          favcat: '4',
          favTitle: 'Stale Network Folder',
          favNote: 'stale note',
          localFav: null,
        ),
        const GalleryProvider(
          gid: '5001',
          token: 'tok5001',
          englishTitle: 'Duplicate Legacy Entry',
          localFav: true,
        ),
      ];

      final firstLoad = _MemoryLocalFavController(
        initialItems: backingStore,
        onPersist: (items) {
          persistedSnapshots++;
          backingStore = List<GalleryProvider>.of(items);
        },
      );
      firstLoad.onInit();

      expect(persistedSnapshots, 1);
      expect(firstLoad.loacalFavs, hasLength(1));
      final migrated = firstLoad.loacalFavs.single;
      expect(migrated.localFav, isTrue);
      expect(migrated.favcat, isEmpty);
      expect(migrated.favTitle, isEmpty);
      expect(migrated.favNote, isEmpty);

      final itemCtrl = GalleryItemController(galleryProvider: migrated);
      expect(itemCtrl.isFav, isTrue);
      expect(itemCtrl.favCat, 'l');

      // Second load on already-normalized backing store causes zero redundant writes.
      final secondLoad = _MemoryLocalFavController(
        initialItems: backingStore,
        onPersist: (_) => persistedSnapshots++,
      );
      secondLoad.onInit();
      expect(persistedSnapshots, 1);
      expect(secondLoad.loacalFavs, hasLength(1));
    });

    testWidgets(
        'stale undo callbacks do not overwrite subsequent favorite mutations in detail or list controllers',
        (tester) async {
      String? stored;
      final ruleService = FavRuleService(
        readJson: () => stored,
        writeJson: (json) async => stored = json,
        readLegacyOneStep: () => false,
        readLegacyFavPicker: () => false,
      );
      ruleService.loadAndMigrate();
      await ruleService.addRule(
        FavRule(
          id: 'r_nonh_1',
          favcat: '1',
          conditions: <FavRuleCondition>[
            FavRuleCondition.category(const <String>['Non-H']),
          ],
        ),
      );

      final settings = Get.put<EhSettingService>(_HeartTestSettings());
      Get.put<ThemeService>(_HeartTestTheme());
      Get.put<CacheController>(_NoopCacheController());
      Get.put<UserController>(_HeartLoggedInUser());
      final fakeFav = _HeartRecordingFavController();
      Get.put<FavController>(fakeFav);
      Get.put<FavRuleService>(ruleService);

      const detailTag = 'stale_undo_detail';
      final pageState = GalleryPageState()
        ..galleryProvider = const GalleryProvider(
          gid: '9401',
          token: 'tok9401',
          englishTitle: 'Detail Undo Guard Gallery',
          category: 'Non-H',
        );
      Get.put<GalleryPageController>(
        _FakeGalleryPageController(pageState),
        tag: detailTag,
      );

      await tester.pumpWidget(_wrapHeartApp());
      await tester.pumpAndSettle();

      final favCtrl = Get.put<GalleryFavController>(
        GalleryFavController(galleryTag: detailTag),
        tag: detailTag,
      );

      // 1) Detail rule-hit saves to '1' and displays undo banner:
      await favCtrl.tapFav();
      await tester.pumpAndSettle();
      expect(favCtrl.favcat, '1');
      expect(fakeFav.savedFavcats, <String>['1']);
      expect(find.text('撤销'), findsOneWidget);

      final staleDetailUndoGesture = tester.widget<GestureDetector>(
        find
            .ancestor(
              of: find.text('撤销'),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      final staleDetailOnTap = staleDetailUndoGesture.onTap!;

      // User manually moves gallery to '2' while banner was open:
      fakeFav.nextPickerSelection =
          const Favcat(favId: '2', favTitle: '收藏夹 2');
      await favCtrl.longTapFav();
      await tester.pumpAndSettle();
      expect(favCtrl.favcat, '2');
      expect(find.text('撤销'), findsNothing);

      // Even invoking the stale undo callback directly is a no-op:
      staleDetailOnTap();
      await tester.pumpAndSettle();
      expect(favCtrl.favcat, '2');
      expect(fakeFav.deletedGids, isEmpty);
      expect(fakeFav.savedFavcats, <String>['1']);

      // 2) List item rule-hit saves to '1', then user manually changes to '3':
      const listProvider = GalleryProvider(
        gid: '9402',
        token: 'tok9402',
        englishTitle: 'List Undo Guard Gallery',
        category: 'Non-H',
      );
      final listItem = GalleryItemController(galleryProvider: listProvider);
      final eval = ruleService.evaluateGallerySync(listProvider);
      expect(eval.isHit, isTrue);

      await listItem.applyRuleFavorite(eval);
      await tester.pumpAndSettle();
      expect(listItem.favCat, '1');
      expect(find.text('撤销'), findsOneWidget);

      final staleListUndoGesture = tester.widget<GestureDetector>(
        find
            .ancestor(
              of: find.text('撤销'),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      final staleListOnTap = staleListUndoGesture.onTap!;

      fakeFav.nextPickerSelection =
          const Favcat(favId: '3', favTitle: '收藏夹 3');
      await listItem.changeFavorite();
      await tester.pumpAndSettle();
      expect(listItem.favCat, '3');
      expect(find.text('撤销'), findsNothing);

      staleListOnTap();
      await tester.pumpAndSettle();
      expect(listItem.favCat, '3');
      expect(fakeFav.deletedGids, isEmpty);
      expect(fakeFav.savedFavcats, <String>['1', '1']);
      expect(settings.lastFavcat, isNotEmpty);

      dismissAllToast(showAnim: false);
      dismissFavRuleFeedbackBanner();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets(
        'undoing a Remember category rule restores prior disabled state so fallback last is not triggered',
        (tester) async {
      String? stored = jsonEncode(
        const FavRuleConfig(
          enabled: false,
          trigger: FavRuleTrigger.tap,
          fallback: FavRuleFallback.last,
        ).toJson(),
      );
      final ruleService = FavRuleService(
        readJson: () => stored,
        writeJson: (json) async => stored = json,
        readLegacyOneStep: () => false,
        readLegacyFavPicker: () => false,
      );
      ruleService.loadAndMigrate();
      expect(ruleService.enabled, isFalse);

      final settings = _HeartTestSettings()..lastFavcat = '4';
      Get.put<EhSettingService>(settings);
      Get.put<ThemeService>(_HeartTestTheme());
      Get.put<CacheController>(_NoopCacheController());
      Get.put<UserController>(_HeartLoggedInUser());
      final fakeFav = _HeartRecordingFavController();
      Get.put<FavController>(fakeFav);
      Get.put<FavRuleService>(ruleService);

      const firstTag = 'remember_undo_first';
      final firstState = GalleryPageState()
        ..galleryProvider = const GalleryProvider(
          gid: '9403',
          token: 'tok9403',
          englishTitle: 'First Non-H Gallery',
          category: 'Non-H',
        );
      Get.put<GalleryPageController>(
        _FakeGalleryPageController(firstState),
        tag: firstTag,
      );

      const secondTag = 'remember_undo_second';
      final secondState = GalleryPageState()
        ..galleryProvider = const GalleryProvider(
          gid: '9404',
          token: 'tok9404',
          englishTitle: 'Second Manga Gallery',
          category: 'Manga',
        );
      Get.put<GalleryPageController>(
        _FakeGalleryPageController(secondState),
        tag: secondTag,
      );

      await tester.pumpWidget(_wrapHeartApp());
      await tester.pumpAndSettle();

      final firstFavCtrl = Get.put<GalleryFavController>(
        GalleryFavController(galleryTag: firstTag),
        tag: firstTag,
      );
      final secondFavCtrl = Get.put<GalleryFavController>(
        GalleryFavController(galleryTag: secondTag),
        tag: secondTag,
      );

      fakeFav.nextPickerSelection = const Favcat(favId: '0', favTitle: '全年龄');
      await firstFavCtrl.tapFav();
      await tester.pumpAndSettle();
      expect(fakeFav.selectCalls, 1);
      expect(find.text('记住'), findsOneWidget);

      await tester.tap(find.text('记住'));
      await tester.pumpAndSettle();
      expect(ruleService.enabled, isTrue);
      expect(ruleService.rules, hasLength(1));

      await tester.tap(find.text('撤销'));
      await tester.pumpAndSettle();
      expect(ruleService.rules, isEmpty);
      expect(ruleService.enabled, isFalse);

      // Next heart tap on an unfavorited Manga gallery must open manual picker,
      // NOT auto-save to lastFavcat ('4') via FavRuleFallback.last!
      fakeFav.nextPickerSelection = null;
      await secondFavCtrl.tapFav();
      await tester.pumpAndSettle();
      expect(fakeFav.selectCalls, 2);
      expect(fakeFav.savedFavcats, isEmpty);

      dismissAllToast(showAnim: false);
      dismissFavRuleFeedbackBanner();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });
}

Widget _wrapHeartApp() {
  return OKToast(
    child: GetCupertinoApp(
      locale: const Locale('zh', 'CN'),
      supportedLocales: L10n.delegate.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const CupertinoPageScaffold(child: SizedBox.expand()),
    ),
  );
}

class _HeartTestSettings extends GetxService implements EhSettingService {
  @override
  RxBool isFavPicker = false.obs;
  @override
  RxBool isFavLongTap = false.obs;
  @override
  final RxBool vibrate = false.obs;
  @override
  final RxBool isSiteEx = false.obs;
  @override
  String lastFavcat = '1';
  @override
  bool get isPureDarkTheme => false;
  @override
  bool get liquidGlass => true;
  @override
  bool get liquidGlassMaterial => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HeartTestTheme extends GetxService implements ThemeService {
  @override
  ThemesModeEnum get themeModel => ThemesModeEnum.darkMode;
  @override
  EhPalette get palette => EhPalette.graphite;
  @override
  CupertinoThemeData? get themeData =>
      const CupertinoThemeData(brightness: Brightness.dark);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopCacheController extends GetxController implements CacheController {
  @override
  Future<void> clearDioCache({required String path}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HeartLoggedInUser extends GetxController implements UserController {
  @override
  final Rx<User> user = const User(memberId: '1', passHash: 'hash').obs;
  @override
  bool get isLogin => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFavoriteSelectorController extends GetxController
    implements FavoriteSelectorController {
  @override
  final RxList<Favcat> favcatList = <Favcat>[
    const Favcat(favId: 'l', favTitle: '本地收藏', totNum: 5),
    for (var i = 0; i <= 9; i++)
      Favcat(favId: '$i', favTitle: '收藏夹 $i', totNum: 10),
  ].obs;

  @override
  void increase(String favcat) {}

  @override
  void decrease(String favcat) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryLocalFavController extends LocalFavController {
  _MemoryLocalFavController({
    this.initialItems = const <GalleryProvider>[],
    this.onPersist,
  });

  final List<GalleryProvider> initialItems;
  final ValueChanged<List<GalleryProvider>>? onPersist;

  @override
  List<GalleryProvider> readPersistedLocalFavs() => initialItems;

  @override
  void persistLocalFavsSnapshot(List<GalleryProvider> items) {
    onPersist?.call(items);
  }

  @override
  Worker everProfile<T>(RxInterface<T> listener, ValueChanged<T> onChange) =>
      ever<T>(listener, (value) {
        onChange(value);
        if (value is List<GalleryProvider>) {
          onPersist?.call(value);
        }
      });
}

class _TestableFavController extends FavController {
  final List<String> networkCalls = <String>[];
  Favcat? dialogChoice;

  @override
  Future<String?> loadFavoriteNote(String gid, String token) async => '';

  @override
  Future<Favcat?> showFavListDialog(
    BuildContext context,
    List<Favcat> favList, {
    String? galleryTitle,
    FavRuleMissContext? ruleMissContext,
  }) async =>
      dialogChoice;

  @override
  Future<void> mutateNetworkFavorite(
    String gid,
    String token, {
    String favcat = 'favdel',
    String favnote = '',
  }) async {
    networkCalls.add('$gid:$favcat');
    favoriteStates.commit(
      gid,
      favcat == 'favdel' ? '' : favcat,
      favcat == 'favdel' ? '' : '收藏夹 $favcat',
    );
  }
}

class _FakeGalleryPageController extends GetxController
    implements GalleryPageController {
  _FakeGalleryPageController(this.gState);
  @override
  final GalleryPageState gState;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HeartRecordingFavController extends GetxController
    implements FavController {
  final List<String> savedFavcats = <String>[];
  final List<String> savedNotes = <String>[];
  final List<String> deletedGids = <String>[];
  int selectCalls = 0;
  String? lastSelectOriFavcat;
  FavRuleMissContext? lastMissContext;
  Favcat? nextPickerSelection;
  String? storedNote = '';
  bool throwOnNoteRead = false;

  @override
  Future<Favcat> saveToFavcat(
    String gid,
    String token,
    String targetFavcat, {
    String oriFavcat = '',
    String favnote = '',
    GalleryProvider? galleryProvider,
  }) async {
    savedFavcats.add(targetFavcat);
    savedNotes.add(favnote);
    return Favcat(favId: targetFavcat, favTitle: '收藏夹 $targetFavcat');
  }

  @override
  Future<Favcat?> addFav(
    String gid,
    String token, {
    String oriFavcat = '',
    String oriFavnote = '',
    String? galleryTitle,
    GalleryProvider? galleryProvider,
    FavRuleMissContext? ruleMissContext,
  }) {
    return selectToSave(
      gid,
      token,
      oriFavcat: oriFavcat,
      galleryTitle: galleryTitle,
      ruleMissContext: ruleMissContext,
      galleryProvider: galleryProvider,
    );
  }

  @override
  Future<Favcat?> selectToSave(
    String gid,
    String token, {
    String oriFavcat = '',
    VoidCallback? startLoading,
    String? galleryTitle,
    FavRuleMissContext? ruleMissContext,
    GalleryProvider? galleryProvider,
  }) async {
    selectCalls++;
    lastSelectOriFavcat = oriFavcat;
    lastMissContext = ruleMissContext;
    return nextPickerSelection;
  }

  @override
  Future<void> delFav(String favcat, String gid, String token) async {
    deletedGids.add(gid);
  }

  @override
  Future<String?> loadFavoriteNote(String gid, String token) async {
    if (throwOnNoteRead) {
      throw StateError('note read failed');
    }
    return storedNote;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
