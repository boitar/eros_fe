import 'package:eros_fe/extension.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:get/get.dart';

bool isNetworkFavoriteCategory(String? category) =>
    category != null && RegExp(r'^[0-9]$').hasMatch(category);

class FavoriteState {
  const FavoriteState(
    this.category,
    this.title,
    this.version, {
    this.note,
  });
  final String category;
  final String title;
  final int version;

  /// Latest confirmed favorite note when known (`null` means unknown/not
  /// overridden; `''` means explicitly empty/cleared).
  final String? note;
}

/// Snapshot of favorite state captured immediately after an automatic rule or
/// fallback save so a delayed "Undo" banner tap becomes a safe no-op if any
/// subsequent favorite mutation or account switch occurred in the meantime.
class FavoriteUndoSnapshot {
  const FavoriteUndoSnapshot({
    required this.gid,
    required this.epoch,
    required this.storeMutationCount,
    required this.controllerMutationSeq,
    required this.expectedFavcat,
  });

  final String gid;
  final int epoch;
  final int storeMutationCount;
  final int controllerMutationSeq;
  final String expectedFavcat;

  bool canUndo({
    required String currentFavcat,
    required int currentControllerSeq,
    FavoriteStateStore? store,
  }) {
    final s = store ?? favoriteStates;
    if (gid.isNotEmpty && s.isBusy(gid)) {
      return false;
    }
    if (s.epoch != epoch) {
      return false;
    }
    if (gid.isNotEmpty && s.mutationCount(gid) != storeMutationCount) {
      return false;
    }
    if (currentControllerSeq != controllerMutationSeq) {
      return false;
    }
    return currentFavcat == expectedFavcat;
  }
}

/// Account-scoped favorite state, independent of widget/controller lifetimes.
/// Request stamps fence off responses started before a mutation or account switch.
class FavoriteStateStore {
  final states = <String, FavoriteState>{}.obs;
  final _busy = <String>{};
  final _mutationCounts = <String, int>{};
  int _version = 0;
  int _epoch = 0;
  String? _account;

  int get version => _version;
  int get epoch => _epoch;
  bool isBusy(String gid) => _busy.contains(gid);
  int mutationCount(String? gid) => _mutationCounts[gid ?? ''] ?? 0;

  void recordMutation(String? gid) {
    if (gid == null || gid.isEmpty) {
      return;
    }
    _mutationCounts[gid] = (_mutationCounts[gid] ?? 0) + 1;
  }

  FavoriteUndoSnapshot snapshotForUndo(
    String? gid, {
    required String expectedFavcat,
    required int controllerMutationSeq,
  }) {
    final resolvedGid = gid ?? '';
    return FavoriteUndoSnapshot(
      gid: resolvedGid,
      epoch: _epoch,
      storeMutationCount:
          resolvedGid.isEmpty ? 0 : mutationCount(resolvedGid),
      controllerMutationSeq: controllerMutationSeq,
      expectedFavcat: expectedFavcat,
    );
  }

  bool setAccount(String account) {
    if (_account == account) {
      return false;
    }
    _account = account;
    _epoch++;
    _version++;
    states.clear();
    _busy.clear();
    _mutationCounts.clear();
    return true;
  }

  FavoriteState? operator [](String? gid) => states[gid ?? ''];

  void commit(String gid, String category, String title, {String? note}) {
    if (gid.isEmpty) {
      return;
    }
    if (category.isNotEmpty && !isNetworkFavoriteCategory(category)) {
      throw ArgumentError.value(category, 'category');
    }
    recordMutation(gid);
    final resolvedNote =
        category.isEmpty ? '' : (note ?? states[gid]?.note);
    states[gid] =
        FavoriteState(category, title, ++_version, note: resolvedNote);
  }

  void commitNote(String gid, String note) {
    if (gid.isEmpty) {
      return;
    }
    final current = states[gid];
    if (current == null) {
      return;
    }
    states[gid] = FavoriteState(
      current.category,
      current.title,
      ++_version,
      note: note,
    );
  }

  void acceptRead(
      GalleryProvider provider, int requestVersion, int requestEpoch,
      {bool authoritative = false}) {
    if (requestEpoch != _epoch) {
      return;
    }
    final gid = provider.gid ?? '';
    final category = provider.favcat;
    if (gid.isEmpty || category == null) {
      return; // unknown, not unfavorited
    }
    if (!isNetworkFavoriteCategory(category) &&
        !(authoritative && category.isEmpty)) {
      return;
    }
    if (_busy.contains(gid) || (states[gid]?.version ?? -1) > requestVersion) {
      return;
    }
    final note = category.isEmpty
        ? ''
        : (provider.favNote ?? states[gid]?.note);
    states[gid] = FavoriteState(
      category,
      provider.favTitle ?? '',
      requestVersion,
      note: note,
    );
  }

  GalleryProvider overlay(GalleryProvider provider) {
    final state = this[provider.gid];
    if (state == null) {
      return provider;
    }
    return provider.copyWith(
      favcat: state.category.oN,
      favTitle: state.title.oN,
      favNote: state.note != null ? state.note!.oN : null,
    );
  }

  Future<T> mutate<T>(String gid, Future<T> Function() operation) async {
    if (!_busy.add(gid)) {
      throw StateError('该画廊的收藏操作正在处理中');
    }
    final operationEpoch = _epoch;
    try {
      return await operation();
    } finally {
      if (operationEpoch == _epoch) {
        _busy.remove(gid);
      }
    }
  }

  Future<T> mutateBatch<T>(
      Iterable<String> gids, Future<T> Function() operation) async {
    final unique = <String>[];
    for (final gid in gids) {
      if (gid.isNotEmpty && !unique.contains(gid)) {
        unique.add(gid);
      }
    }
    final added = <String>[];
    for (final gid in unique) {
      if (!_busy.add(gid)) {
        for (final rollback in added) {
          _busy.remove(rollback);
        }
        throw StateError('所选画廊中有收藏操作正在处理中');
      }
      added.add(gid);
    }
    final operationEpoch = _epoch;
    try {
      return await operation();
    } finally {
      if (operationEpoch == _epoch) {
        for (final gid in added) {
          _busy.remove(gid);
        }
      }
    }
  }
}

final favoriteStates = FavoriteStateStore();
