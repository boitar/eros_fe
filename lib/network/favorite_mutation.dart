import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:eros_fe/common/controller/favorite_state_store.dart';
import 'package:eros_fe/models/fav_add.dart';

/// A timed-out POST may have succeeded. Read back once; never repeat the POST.
/// No HTTP response body or credential is included in user-facing failures.
Future<FavAdd> confirmFavoriteMutation({
  required String category,
  required Future<void> Function() submit,
  required Future<FavAdd> Function() readBack,
  Future<bool?> Function()? readRemoval,
}) async {
  if (category != 'favdel' && !isNetworkFavoriteCategory(category)) {
    throw ArgumentError.value(category, 'category');
  }
  try {
    await submit();
  } catch (_) {
    // Resolve an uncertain delivery using the same authoritative read below.
  }
  // A popup can preselect a category for a new favorite. That selection
  // alone cannot establish whether removal succeeded.
  if (category == 'favdel' && readRemoval != null) {
    final bool? removed;
    try {
      removed = await readRemoval();
    } catch (_) {
      throw StateError('取消收藏结果暂时无法确认，请刷新后查看；未重复提交');
    }
    if (removed != true) {
      throw StateError(removed == false
          ? '服务器仍显示该画廊已收藏，请刷新后重试'
          : '取消收藏结果暂时无法确认，请刷新后查看；未重复提交');
    }
    return const FavAdd(
        favcats: [], maxNoteSlots: '', usedNoteSlots: '', selectFavcat: null);
  }
  final FavAdd confirmed;
  try {
    confirmed = await readBack();
  } catch (_) {
    throw StateError('收藏结果暂时无法确认，请刷新后查看；未重复提交');
  }
  final expected = category == 'favdel' ? null : category;
  if (confirmed.selectFavcat != expected) {
    throw StateError('服务器尚未确认所选收藏状态，请刷新后重试');
  }
  return confirmed;
}

/// A readback must never silently fall back to a pre-mutation cached response.
CacheOptions favoriteNetworkCacheOptions(CacheOptions base,
        {bool transient = false}) =>
    base.copyWith(
        policy: transient ? CachePolicy.noCache : CachePolicy.refresh,
        hitCacheOnErrorExcept: const Nullable(null));
