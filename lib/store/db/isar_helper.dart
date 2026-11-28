import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:eros_fe/common/service/fav_rule_matcher.dart';
import 'package:eros_fe/models/fav_rule.dart';
import 'package:eros_fe/store/db/entity/gallery_task.dart';
import 'package:eros_fe/store/db/entity/tag_translate_info.dart';
import 'package:eros_fe/store/db/entity/view_history.dart';
import 'package:eros_fe/store/db/isar.dart';
import 'package:eros_fe/store/db/isar_isolate.dart';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';

import '../../index.dart';
import 'entity/gallery_image_task.dart';
import 'entity/tag_translat.dart';

class IsarHelper {
  late final Isar isar;

  Future<void> initIsar() async {
    isar = await openIsar();
  }

  Future<List<GalleryProvider>> getAllHistory() async {
    final viewHistories =
        await isar.viewHistorys.where().sortByLastViewTimeDesc().findAll();
    final _histories = viewHistories
        .map((e) => GalleryProvider.fromJson(
            jsonDecode(e.galleryProviderText) as Map<String, dynamic>))
        .toList();
    return _histories;
  }

  Future<GalleryProvider?> getHistory(String gid) async {
    final _gid = int.tryParse(gid) ?? 0;
    final viewHistory = await isar.viewHistorys.get(_gid);
    if (viewHistory == null) {
      return null;
    }
    return GalleryProvider.fromJson(
        jsonDecode(viewHistory.galleryProviderText) as Map<String, dynamic>);
  }

  Future<void> addHistoryAsync(GalleryProvider galleryProvider) async {
    // return;
    final gid = int.tryParse(galleryProvider.gid ?? '0') ?? 0;
    final lastViewTime = galleryProvider.lastViewTime ?? 0;

    await isar.writeTxn(() async {
      await isar.viewHistorys.put(ViewHistory(
          gid: gid,
          lastViewTime: lastViewTime,
          galleryProviderText: jsonEncode(galleryProvider)));
    });
  }

  Future<void> addHistoryIsolate(GalleryProvider galleryProvider) async {
    // return;
    await compute(iAddHistory, galleryProvider);
  }

  Future<void> removeHistory(String gidStr) async {
    final gid = int.tryParse(gidStr) ?? 0;
    await isar.writeTxn(() async {
      await isar.viewHistorys.delete(gid);
    });
  }

  Future<void> cleanHistory() async {
    await isar.writeTxn(() async {
      await isar.viewHistorys.where().deleteAll();
    });
  }

  Future<void> addHistoriesAsync(List<GalleryProvider> allHistory) async {
    final viewHistories = allHistory
        .map((e) => ViewHistory(
            gid: int.tryParse(e.gid ?? '0') ?? 0,
            lastViewTime: e.lastViewTime ?? 0,
            galleryProviderText: jsonEncode(e)))
        .toList();

    await isar.writeTxn(() async {
      await isar.viewHistorys.putAll(viewHistories);
    });
  }

  Future<void> addHistoriesIsolate(List<GalleryProvider> allHistory) async {
    await compute(iAddHistories, allHistory);
  }

  Future<void> putAllTagTranslate(
    List<TagTranslat> tagTranslates,
  ) async {
    final tagTranslate = isar.tagTranslats;
    await isar.writeTxn(() async {
      await tagTranslate.putAll(tagTranslates);
    });
  }

  Future<void> putAllTagTranslateIsolate(
    List<TagTranslat> tagTranslates,
  ) async {
    compute(iPutAllTagTranslate, tagTranslates);
  }

  Future<List<String?>> findAllTagNamespace() async {
    final result = await isar.tagTranslats
        .where()
        .distinctByNamespace()
        .namespaceProperty()
        .findAll();
    return result;
  }

  // 查询 tag
  Future<TagTranslat?> findTagTranslate(String key, {String? namespace}) async {
    if (namespace != null && namespace.isNotEmpty) {
      final result = await isar.tagTranslats
          .where()
          .keyEqualTo(key)
          .filter()
          .namespaceEqualTo(namespace)
          .findAll();
      return result.lastOrNull;
    } else {
      final result = await isar.tagTranslats
          .where()
          .namespaceNotEqualTo('rows')
          .filter()
          .keyEqualTo(key)
          .findAll();
      return result.lastOrNull;
    }
  }

  // 模糊查询 通过tag或者tag翻译的部分内容
  Future<List<TagTranslat>> findTagTranslateContains(
      String text, int limit) async {
    final result = await isar.tagTranslats
        .where(sort: Sort.desc)
        .anyLastUseTime()
        .filter()
        .not()
        .namespaceEqualTo('rows')
        .and()
        .keyContains(text)
        .or()
        .nameContains(text)
        .limit(limit)
        .findAll();

    logger.d('result.len ${result.length}');

    return result;
  }

  Future<int> countTagTranslates() async {
    return isar.tagTranslats
        .filter()
        .not()
        .namespaceEqualTo('rows')
        .count();
  }

  QueryBuilder<TagTranslat, TagTranslat, QAfterFilterCondition> _nsEqualsFilter(
    QueryBuilder<TagTranslat, TagTranslat, QFilterCondition> q,
    String normNs,
  ) {
    final variants = FavRuleMatcher.previewStorageVariants(normNs);
    if (variants.length <= 1) {
      return q.namespaceEqualTo(normNs, caseSensitive: false);
    }
    return q.group((g) {
      var b = g.namespaceEqualTo(variants.first, caseSensitive: false);
      for (var i = 1; i < variants.length; i++) {
        b = b.or().namespaceEqualTo(variants[i], caseSensitive: false);
      }
      return b;
    });
  }

  QueryBuilder<TagTranslat, TagTranslat, QAfterFilterCondition>
      _nsEndsWithTokensFilter(
    QueryBuilder<TagTranslat, TagTranslat, QFilterCondition> q,
    String normNs,
  ) {
    final tokens = FavRuleMatcher.previewTokens(normNs);
    if (tokens.isEmpty) {
      return q.namespaceIsNotEmpty();
    }
    if (tokens.length == 1) {
      return q.namespaceEndsWith(tokens.first, caseSensitive: false);
    }
    return q.group((g) {
      var b = g.namespaceContains(tokens.first, caseSensitive: false);
      for (var i = 1; i < tokens.length; i++) {
        b = b.and().namespaceContains(tokens[i], caseSensitive: false);
      }
      return b;
    });
  }

  QueryBuilder<TagTranslat, TagTranslat, QAfterFilterCondition>
      _nsPrefixForContains(
    QueryBuilder<TagTranslat, TagTranslat, QFilterCondition> q,
    String lhsNorm,
  ) {
    if (lhsNorm.isEmpty) {
      return q.namespaceIsNotEmpty();
    }
    return _nsEndsWithTokensFilter(q, lhsNorm);
  }

  QueryBuilder<TagTranslat, TagTranslat, QAfterFilterCondition>
      _keyTokensFilter(
    QueryBuilder<TagTranslat, TagTranslat, QFilterCondition> q,
    List<String> tokens, {
    required bool exactSingleToken,
  }) {
    if (tokens.isEmpty) {
      return q.keyIsNotEmpty();
    }
    if (tokens.length == 1) {
      final token = tokens.first;
      if (exactSingleToken && token.length == 1) {
        return q.group(
          (g) => g
              .keyEqualTo(token, caseSensitive: false)
              .or()
              .keyContains('_$token', caseSensitive: false)
              .or()
              .keyContains('${token}_', caseSensitive: false)
              .or()
              .keyContains(' $token', caseSensitive: false)
              .or()
              .keyContains('$token ', caseSensitive: false),
        );
      }
      return q.keyContains(token, caseSensitive: false);
    }
    return q.group((g) {
      var b = g.keyContains(tokens.first, caseSensitive: false);
      for (var i = 1; i < tokens.length; i++) {
        b = b.and().keyContains(tokens[i], caseSensitive: false);
      }
      return b;
    });
  }

  List<String> _cleanedTranslationTokens(String rawText) {
    final cleanedNorm = FavRuleMatcher.normalize(
      FavRuleMatcher.cleanTranslation(rawText),
    );
    return FavRuleMatcher.previewTokens(cleanedNorm);
  }

  QueryBuilder<TagTranslat, TagTranslat, QAfterFilterCondition>
      _orNameTokensFilter(
    QueryBuilder<TagTranslat, TagTranslat, QAfterFilterCondition> branch,
    String rawText,
  ) {
    final tokens = _cleanedTranslationTokens(rawText);
    if (tokens.isEmpty) {
      return branch;
    }
    if (tokens.length == 1) {
      return branch.or().nameContains(tokens.first, caseSensitive: false);
    }
    return branch.or().group((g) {
      var b = g.nameContains(tokens.first, caseSensitive: false);
      for (var i = 1; i < tokens.length; i++) {
        b = b.and().nameContains(tokens[i], caseSensitive: false);
      }
      return b;
    });
  }

  QueryBuilder<TagTranslat, TagTranslat, QAfterFilterCondition>
      _nameTokensGroup(
    QueryBuilder<TagTranslat, TagTranslat, QFilterCondition> q,
    List<String> tokens,
  ) {
    if (tokens.length == 1) {
      return q.nameContains(tokens.first, caseSensitive: false);
    }
    return q.group((g) {
      var b = g.nameContains(tokens.first, caseSensitive: false);
      for (var i = 1; i < tokens.length; i++) {
        b = b.and().nameContains(tokens[i], caseSensitive: false);
      }
      return b;
    });
  }

  /// Queries known tags matching a rule condition for live condition preview.
  /// Returns `(matches, totalCount)`.
  Future<(List<TagTranslat>, int)> findTagTranslatesForRuleCondition({
    required String value,
    String? namespace,
    required String opName,
    bool matchTranslation = false,
    int limit = 40,
  }) async {
    final parsed = FavRuleMatcher.parseConditionPreviewQuery(
      value: value,
      namespace: namespace,
    );
    if (parsed.isEmpty) {
      return (const <TagTranslat>[], 0);
    }
    final op = switch (opName) {
      'equals' => FavRuleOp.equals,
      'contains' => FavRuleOp.contains,
      'regex' => FavRuleOp.regex,
      _ => null,
    };
    if (op == null) {
      return (const <TagTranslat>[], 0);
    }

    final trimmed = parsed.rawValue;
    final normalized = parsed.normalizedFull;
    final fullTokens = parsed.normalizedFullTokens;
    final explicitNs = parsed.explicitNamespace;

    final colonPos = normalized.indexOf(':');
    final hasColon = colonPos >= 0;
    final colonLhs = hasColon ? normalized.substring(0, colonPos) : '';
    final colonRhs = hasColon ? normalized.substring(colonPos + 1) : '';
    final colonRhsTokens = FavRuleMatcher.previewTokens(colonRhs);
    final rawColonPos = trimmed.indexOf(':');
    final colonRhsRaw =
        rawColonPos >= 0 ? trimmed.substring(rawColonPos + 1).trim() : '';
    final colonRhsTransTokens = _cleanedTranslationTokens(colonRhsRaw);

    final condition = FavRuleCondition(
      namespace: explicitNs,
      op: op,
      value: trimmed,
      matchTranslation: matchTranslation,
    );

    final base = isar.tagTranslats
        .filter()
        .not()
        .namespaceEqualTo('rows')
        .and()
        .not()
        .namespaceEqualTo(kFavRuleCategoryNamespace, caseSensitive: false);

    if (op == FavRuleOp.equals) {
      final QueryBuilder<TagTranslat, TagTranslat, QAfterFilterCondition> query;
      if (explicitNs != null) {
        final scoped = base.and().group((q) => _nsEqualsFilter(q, explicitNs));
        final matchInlineKey =
            hasColon && colonLhs == explicitNs && colonRhsTokens.isNotEmpty;
        query = scoped.and().group((q) {
          var branch = matchInlineKey
              ? _keyTokensFilter(
                  q,
                  colonRhsTokens,
                  exactSingleToken: true,
                ).or().group(
                    (g) => _keyTokensFilter(
                      g,
                      fullTokens,
                      exactSingleToken: true,
                    ),
                  )
              : _keyTokensFilter(q, fullTokens, exactSingleToken: true);
          if (matchTranslation) {
            branch = _orNameTokensFilter(branch, trimmed);
            if (hasColon &&
                colonLhs == explicitNs &&
                colonRhsTransTokens.isNotEmpty) {
              branch = _orNameTokensFilter(branch, colonRhsRaw);
            }
          }
          return branch;
        });
      } else if (hasColon && colonLhs.isNotEmpty) {
        query = base.and().group((q) {
          var branch = colonRhsTokens.isNotEmpty
              ? q
                  .group(
                    (inner) => _nsEqualsFilter(inner, colonLhs).and().group(
                          (g) => _keyTokensFilter(
                            g,
                            colonRhsTokens,
                            exactSingleToken: true,
                          ),
                        ),
                  )
                  .or()
                  .group(
                    (g) => _keyTokensFilter(
                      g,
                      fullTokens,
                      exactSingleToken: true,
                    ),
                  )
              : _keyTokensFilter(q, fullTokens, exactSingleToken: true);
          if (matchTranslation) {
            branch = _orNameTokensFilter(branch, trimmed);
            if (colonRhsTransTokens.isNotEmpty) {
              branch = branch.or().group(
                    (inner) => _nsEqualsFilter(inner, colonLhs).and().group(
                          (g) => _nameTokensGroup(g, colonRhsTransTokens),
                        ),
                  );
            }
          }
          return branch;
        });
      } else {
        query = base.and().group((q) {
          var branch = _keyTokensFilter(q, fullTokens, exactSingleToken: true);
          if (matchTranslation) {
            branch = _orNameTokensFilter(branch, trimmed);
          }
          return branch;
        });
      }
      final candidates = await query.findAll();
      return FavRuleMatcher.filterPreviewCandidates<TagTranslat>(
        candidates: candidates,
        condition: condition,
        namespaceOf: (t) => t.namespace,
        keyOf: (t) => t.key,
        translationOf: (t) => t.name,
        limit: limit,
      );
    }

    if (op == FavRuleOp.contains) {
      // Fast exact path for single-word key substring queries without spaces,
      // underscores, colons, or translation matching.
      final singleWordFastPath = !matchTranslation &&
          !hasColon &&
          fullTokens.length == 1 &&
          !trimmed.contains(' ') &&
          !trimmed.contains('_') &&
          !trimmed.contains(':') &&
          (explicitNs == null || !explicitNs.contains(' '));
      if (singleWordFastPath) {
        final fastQuery = explicitNs != null
            ? base
                .and()
                .namespaceEqualTo(explicitNs, caseSensitive: false)
                .and()
                .keyContains(normalized, caseSensitive: false)
            : base.and().keyContains(normalized, caseSensitive: false);
        final total = await fastQuery.count();
        final items = await fastQuery.limit(limit).findAll();
        return (items, total);
      }

      final QueryBuilder<TagTranslat, TagTranslat, QAfterFilterCondition> query;
      if (explicitNs != null) {
        final scoped = base.and().group((q) => _nsEqualsFilter(q, explicitNs));
        final matchColonBoundary = hasColon && explicitNs.endsWith(colonLhs);
        if (matchColonBoundary && colonRhs.isEmpty) {
          query = scoped;
        } else {
          query = scoped.and().group((q) {
            var branch =
                _keyTokensFilter(q, fullTokens, exactSingleToken: false);
            if (matchColonBoundary && colonRhsTokens.isNotEmpty) {
              branch = branch.or().group(
                    (g) => _keyTokensFilter(
                      g,
                      colonRhsTokens,
                      exactSingleToken: false,
                    ),
                  );
            }
            if (matchTranslation) {
              branch = _orNameTokensFilter(branch, trimmed);
              if (matchColonBoundary && colonRhsTransTokens.isNotEmpty) {
                branch = _orNameTokensFilter(branch, colonRhsRaw);
              }
            }
            return branch;
          });
        }
      } else if (hasColon) {
        query = base.and().group((q) {
          var branch = _keyTokensFilter(q, fullTokens, exactSingleToken: false);
          if (colonRhs.isEmpty) {
            branch = branch.or().group(
                  (inner) => _nsPrefixForContains(inner, colonLhs),
                );
          } else if (colonRhsTokens.isNotEmpty) {
            branch = branch.or().group(
                  (inner) => _nsPrefixForContains(inner, colonLhs).and().group(
                        (g) => _keyTokensFilter(
                          g,
                          colonRhsTokens,
                          exactSingleToken: false,
                        ),
                      ),
                );
          }
          if (matchTranslation) {
            branch = _orNameTokensFilter(branch, trimmed);
            if (colonRhsTransTokens.isNotEmpty) {
              branch = branch.or().group(
                    (inner) =>
                        _nsPrefixForContains(inner, colonLhs).and().group(
                              (g) => _nameTokensGroup(g, colonRhsTransTokens),
                            ),
                  );
            }
          }
          return branch;
        });
      } else {
        query = base.and().group((q) {
          var branch =
              _keyTokensFilter(q, fullTokens, exactSingleToken: false);
          if (matchTranslation) {
            branch = _orNameTokensFilter(branch, trimmed);
          }
          return branch;
        });
      }
      final candidates = await query.findAll();
      return FavRuleMatcher.filterPreviewCandidates<TagTranslat>(
        candidates: candidates,
        condition: condition,
        namespaceOf: (t) => t.namespace,
        keyOf: (t) => t.key,
        translationOf: (t) => t.name,
        limit: limit,
      );
    }

    if (op == FavRuleOp.regex) {
      if (!condition.isValidRegex) {
        return (const <TagTranslat>[], 0);
      }
      final scoped = explicitNs != null
          ? base.and().group((q) => _nsEqualsFilter(q, explicitNs))
          : base;
      final candidates = await scoped.findAll();
      return FavRuleMatcher.filterPreviewCandidates<TagTranslat>(
        candidates: candidates,
        condition: condition,
        namespaceOf: (t) => t.namespace,
        keyOf: (t) => t.key,
        translationOf: (t) => t.name,
        limit: limit,
      );
    }

    return (const <TagTranslat>[], 0);
  }

  Future<void> tapTagTranslate(TagTranslat tagTranslate) async {
    final newTagTranslate = tagTranslate.copyWith(
      lastUseTime: DateTime.now().millisecondsSinceEpoch,
    );
    await isar.writeTxn(() async {
      await isar.tagTranslats.putByKeyNamespace(newTagTranslate);
    });
  }

  Future<void> removeAllTagTranslate() async {
    await isar.writeTxn(() async {
      final count = await isar.tagTranslats.where().deleteAll();
      logger.d('delete count $count');
    });
  }

  /// GalleryTasks
  Future<List<GalleryTask>> findAllGalleryTasks() async {
    return await isar.galleryTasks.where().sortByAddTimeDesc().findAll();
  }

  Future<List<GalleryTask>> findAllGalleryTasksIsolate() async {
    return compute(iFindAllGalleryTasks, null);
  }

  GalleryTask? findGalleryTaskByGidSync(int gid) {
    return isar.galleryTasks.getSync(gid);
  }

  Future<GalleryTask?> findGalleryTaskByGid(int gid) async {
    return await isar.galleryTasks.get(gid);
  }

  Future<GalleryTask?> findGalleryTaskByGidIsolate(int gid) async {
    return compute(iFindGalleryTaskByGid, gid);
  }

  Future<void> putGalleryTask(GalleryTask galleryTask,
      {bool replaceOnConflict = true}) async {
    final existGids = isar.galleryTasks.where().gidProperty().findAllSync();
    final taskExist = existGids.contains(galleryTask.gid);

    if (replaceOnConflict) {
      await isar.writeTxn(() async {
        await isar.galleryTasks.put(galleryTask);
      });
    } else {
      if (!taskExist) {
        await isar.writeTxn(() async {
          await isar.galleryTasks.put(galleryTask);
        });
      }
    }
  }

  Future<void> putGalleryTaskIsolate(
    GalleryTask galleryTask, {
    bool replaceOnConflict = true,
  }) async {
    await compute(iPutGalleryTaskIsolate, (galleryTask, replaceOnConflict));
  }

  Future<void> updateGalleryTask(
    int gid,
    GalleryTask Function(GalleryTask) func,
  ) async {
    final galleryTask = await findGalleryTaskByGid(gid);
    if (galleryTask != null) {
      await isar.writeTxn(() async {
        await isar.galleryTasks.put(func(galleryTask));
      });
    }
  }

  Future<void> updateGalleryTaskShowKey(
    int gid,
    String showKey,
  ) async {
    final galleryTask = await findGalleryTaskByGid(gid);
    if (galleryTask != null) {
      await isar.writeTxn(() async {
        await isar.galleryTasks.put(galleryTask.copyWith(showKey: showKey));
      });
    }
  }

  Future<void> updateGalleryTaskCover(
    int gid,
  ) async {
    final galleryTask = await findGalleryTaskByGid(gid);
    final imageTask = findImageTaskAllByGidSerSync(gid, 1);
    if (imageTask == null) {
      return;
    }
    if (imageTask.filePath == null) {
      return;
    }

    if (galleryTask != null) {
      await isar.writeTxn(() async {
        await isar.galleryTasks
            .put(galleryTask.copyWith(coverImage: imageTask.filePath));
      });
    }
  }

  Future<void> updateGalleryTaskIsolate(
    int gid,
    GalleryTask Function(GalleryTask) func,
  ) async {
    await compute(iUpdateGalleryTaskIsolate, (gid, func));
  }

  Future<void> putAllGalleryTasks(List<GalleryTask> galleryTasks) async {
    await isar.writeTxn(() async {
      await isar.galleryTasks.putAll(galleryTasks);
    });
  }

  Future<void> putAllGalleryTasksIsolate(
    List<GalleryTask> galleryTasks, {
    bool replaceOnConflict = true,
  }) async {
    await compute(iPutAllGalleryTasks, galleryTasks);
  }

  Future<void> removeGalleryTask(int gid) async {
    await isar.writeTxn(() async {
      await isar.galleryTasks.delete(gid);
    });
  }

  /// Atomically writes [newTask] + [newImageTasks] and optionally removes
  /// [removeOldGid] + its image tasks in a single Isar write transaction.
  Future<void> commitIncrementalUpdateIsolate({
    required GalleryTask newTask,
    required List<GalleryImageTask> newImageTasks,
    int? removeOldGid,
    String? expectedOldToken,
    String? expectedOldDirPath,
  }) async {
    await compute(
      iCommitIncrementalUpdate,
      (
        newTask,
        newImageTasks,
        removeOldGid,
        expectedOldToken,
        expectedOldDirPath,
      ),
    );
  }

  /// ImageTasks
  Future<List<GalleryImageTask>> findImageTaskAllByGid(int gid) async {
    return await isar.galleryImageTasks
        .where()
        .gidEqualTo(gid)
        .sortBySer()
        .findAll();
  }

  Future<List<GalleryImageTask>> findImageTaskAllByGidIsolate(int gid) async {
    return compute(iFindImageTaskAllByGid, gid);
  }

  List<GalleryImageTask> findImageTaskAllByGidSync(int gid) {
    return isar.galleryImageTasks
        .where()
        .gidEqualTo(gid)
        .sortBySer()
        .findAllSync();
  }

  GalleryImageTask? findImageTaskAllByGidSerSync(int gid, int ser) {
    return isar.galleryImageTasks.getByGidSerSync(gid, ser);
  }

  Future<GalleryImageTask?> findImageTaskAllByGidSer(int gid, int ser) {
    return isar.galleryImageTasks.getByGidSer(gid, ser);
  }

  Future<GalleryImageTask?> findImageTaskAllByGidSerIsolate(int gid, int ser) {
    return compute(iFindImageTaskAllByGidSer, (gid, ser));
  }

  Future<void> putImageTask(GalleryImageTask imageTask) async {
    await isar.writeTxn(() async {
      await isar.galleryImageTasks.putByGidSer(imageTask);
    });
  }

  Future<void> putImageTaskIsolate(GalleryImageTask imageTask) async {
    await compute(iPutImageTask, imageTask);
  }

  Future<void> putAllImageTask(List<GalleryImageTask> imageTasks) async {
    await isar.writeTxn(() async {
      await isar.galleryImageTasks.putAllByGidSer(imageTasks);
    });
  }

  Future<void> putAllImageTaskIsolate(List<GalleryImageTask> imageTasks) async {
    await compute(iPutAllImageTask, imageTasks);
  }

  Future<void> removeImageTask(int gid) async {
    await isar.writeTxn(() async {
      await isar.galleryImageTasks.where().gidEqualTo(gid).deleteAll();
    });
  }

  Future<void> updateImageTaskStatus(int gid, int ser, int status) async {
    await isar.writeTxn(() async {
      final tasks = await isar.galleryImageTasks.getByGidSer(gid, ser);
      if (tasks != null) {
        await isar.galleryImageTasks
            .putByGidSer(tasks.copyWith(status: status));
      }
    });
  }

  Future<List<GalleryImageTask>> onDownloadComplete(
    int gid,
    int ser,
    int status,
  ) async {
    return await isar.writeTxn(() async {
      final tasks = await isar.galleryImageTasks.getByGidSer(gid, ser);
      if (tasks != null) {
        await isar.galleryImageTasks
            .putByGidSer(tasks.copyWith(status: status));
      }
      return await isar.galleryImageTasks
          .where()
          .gidEqualTo(gid)
          .filter()
          .statusEqualTo(status)
          .findAll();
    });
  }

  // 在同一个事务中 updateImageTaskStatus 然后 finaAllImageTaskByGidAndStatus
  Future<List<GalleryImageTask>> onDownloadCompleteIsolate(
    int gid,
    int ser,
    int status,
  ) async {
    return compute(iOnDownloadComplete, (gid, ser, status));
  }

  Future<void> updateImageTaskStatusIsolate(
    int gid,
    int ser,
    int status,
  ) async {
    await compute(iUpdateImageTaskStatus, (gid, ser, status));
  }

  Future<List<GalleryImageTask>> finaAllImageTaskByGidAndStatus(
    int gid,
    int status,
  ) async {
    return await isar.galleryImageTasks
        .where()
        .gidEqualTo(gid)
        .filter()
        .statusEqualTo(status)
        .findAll();
  }

  Future<List<GalleryImageTask>> finaAllImageTaskByGidAndStatusIsolate(
    int gid,
    int status,
  ) async {
    return compute(iFinaAllImageTaskByGidAndStatus, (gid, status));
  }

  Future<void> putTagTranslateVersion(String version) async {
    final tagTranslateInfo = isar.tagTranslateInfos.getSync(0) ??
        TagTranslateInfo(localVersion: version);
    await isar.writeTxn(() async {
      await isar.tagTranslateInfos
          .put(tagTranslateInfo.copyWith(localVersion: version));
    });
  }

  String getTranslateVersion() {
    final tagTranslateInfo = isar.tagTranslateInfos.getSync(0);
    return tagTranslateInfo?.localVersion ?? '';
  }
}
