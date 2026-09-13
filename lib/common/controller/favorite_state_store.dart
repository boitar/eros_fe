import 'package:eros_fe/models/gallery_provider.dart';
import 'package:get/get.dart';
import 'package:quiver/core.dart';

bool isNetworkFavoriteCategory(String? category) =>
    category != null && RegExp(r'^[0-9]$').hasMatch(category);

class FavoriteState {
  const FavoriteState(this.category, this.title, this.version);
  final String category;
  final String title;
  final int version;
}

/// Account-scoped favorite state, independent of widget/controller lifetimes.
/// Request stamps fence off responses started before a mutation or account switch.
class FavoriteStateStore {
  final states = <String, FavoriteState>{}.obs;
  final _busy = <String>{};
  int _version = 0;
  int _epoch = 0;
  String? _account;

  int get version => _version;
  int get epoch => _epoch;
  bool isBusy(String gid) => _busy.contains(gid);

  bool setAccount(String account) {
    if (_account == account) return false;
    _account = account;
    _epoch++;
    _version++;
    states.clear();
    _busy.clear();
    return true;
  }

  FavoriteState? operator [](String? gid) => states[gid ?? ''];

  void commit(String gid, String category, String title) {
    if (gid.isEmpty) return;
    if (category.isNotEmpty && !isNetworkFavoriteCategory(category)) {
      throw ArgumentError.value(category, 'category');
    }
    states[gid] = FavoriteState(category, title, ++_version);
  }

  void acceptRead(
      GalleryProvider provider, int requestVersion, int requestEpoch,
      {bool authoritative = false}) {
    if (requestEpoch != _epoch) return;
    final gid = provider.gid ?? '';
    final category = provider.favcat;
    if (gid.isEmpty || category == null) return; // unknown, not unfavorited
    if (!isNetworkFavoriteCategory(category) &&
        !(authoritative && category.isEmpty)) return;
    if (_busy.contains(gid) || (states[gid]?.version ?? -1) > requestVersion) {
      return;
    }
    states[gid] =
        FavoriteState(category, provider.favTitle ?? '', requestVersion);
  }

  GalleryProvider overlay(GalleryProvider provider) {
    final state = this[provider.gid];
    if (state == null) return provider;
    return provider.copyWith(
      favcat: Optional.of(state.category),
      favTitle: Optional.of(state.title),
    );
  }

  Future<T> mutate<T>(String gid, Future<T> Function() operation) async {
    if (!_busy.add(gid)) throw StateError('该画廊的收藏操作正在处理中');
    final operationEpoch = _epoch;
    try {
      return await operation();
    } finally {
      if (operationEpoch == _epoch) _busy.remove(gid);
    }
  }
}

final favoriteStates = FavoriteStateStore();
