import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:eros_fe/common/controller/favorite_state_store.dart';

enum FavoriteMutationFailure {
  rejected,
  authentication,
  unconfirmed,
  accountChanged
}

enum FavoriteMutationPhase { submit, confirmation }

class FavoriteMutationException implements Exception {
  const FavoriteMutationException(this.failure,
      {this.statusCode, this.phase = FavoriteMutationPhase.submit});

  final FavoriteMutationFailure failure;
  final int? statusCode;
  final FavoriteMutationPhase phase;

  String get diagnostic =>
      'favorite ${phase.name}: ${failure.name}, status=${statusCode ?? "unknown"}';

  @override
  String toString() {
    final status = statusCode == null ? '' : '（HTTP $statusCode）';
    switch (failure) {
      case FavoriteMutationFailure.accountChanged:
        return '账号已切换，未更新当前账号的收藏状态';
      case FavoriteMutationFailure.authentication:
        return phase == FavoriteMutationPhase.submit
            ? '收藏请求未通过登录验证，请重新登录后重试'
            : '收藏确认未通过登录验证，结果暂未确认，请登录后刷新查看';
      case FavoriteMutationFailure.rejected:
        return phase == FavoriteMutationPhase.submit
            ? '服务器拒绝了收藏请求$status，未更新收藏状态'
            : '服务器拒绝了收藏确认请求$status，结果暂未确认，请刷新查看';
      case FavoriteMutationFailure.unconfirmed:
        return '收藏结果暂时无法完整确认$status，请刷新查看；未重复提交';
    }
  }
}

/// null is unknown; an empty category is an explicit server-side removal.
class FavoriteServerSnapshot {
  const FavoriteServerSnapshot(
      {required this.category, this.title = '', this.note});

  final String? category;
  final String title;
  final String? note;
}

String normalizeFavoriteNote(String value) =>
    value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

/// Never stringify an arbitrary transport error into a toast.
String favoriteMutationMessage(Object error) {
  if (error is FavoriteMutationException) {
    return error.toString();
  }
  if (error is StateError &&
      const {
        '该画廊的收藏操作正在处理中',
        '账号已切换',
        '原收藏备注未能读取，未提交更改，请重试',
      }.contains(error.message)) {
    return error.message.toString();
  }
  return '收藏操作未完成，请刷新后重试';
}

void checkFavoriteResponse(
    Response<dynamic> response, FavoriteMutationPhase phase) {
  final location = response.headers.value('location') ?? '';
  final uri = Uri.tryParse(location);
  final body = response.data is String ? response.data as String : '';
  if (uri?.host == 'forums.e-hentai.org' ||
      location.contains('bounce_login.php') ||
      body.trim() == 'Failed login redirect setup' ||
      RegExp(r'<form\b[^>]*(?:id|name)=["\x27]login', caseSensitive: false)
          .hasMatch(body)) {
    throw FavoriteMutationException(FavoriteMutationFailure.authentication,
        phase: phase, statusCode: response.statusCode);
  }
  if (body.contains('Request forbidden by administrative rules') ||
      body.contains('cf-chl-') ||
      body.contains('<title>Just a moment')) {
    throw FavoriteMutationException(FavoriteMutationFailure.rejected,
        phase: phase, statusCode: response.statusCode);
  }
}

/// POST once. An uncertain delivery may be resolved only by fresh server reads.
Future<FavoriteServerSnapshot> confirmFavoriteMutation({
  required String category,
  String note = '',
  required Future<void> Function() submit,
  required Future<FavoriteServerSnapshot> Function() readBack,
  void Function()? checkAccount,
  Future<void> Function(Duration)? wait,
}) async {
  if (category != 'favdel' && !isNetworkFavoriteCategory(category)) {
    throw ArgumentError.value(category, 'category');
  }
  checkAccount?.call();
  int? submissionStatus;
  try {
    await submit();
  } on FavoriteMutationException catch (error) {
    if (error.failure != FavoriteMutationFailure.unconfirmed) {
      rethrow;
    }
    submissionStatus = error.statusCode;
  } on TimeoutException {
    // The server may have saved before the response was lost.
  }
  final delay = wait ?? (duration) => Future<void>.delayed(duration);
  const pauses = [
    Duration.zero,
    Duration(milliseconds: 400),
    Duration(seconds: 1)
  ];
  final expected = category == 'favdel' ? '' : category;
  for (final pause in pauses) {
    if (pause != Duration.zero) {
      await delay(pause);
    }
    checkAccount?.call();
    try {
      final snapshot = await readBack();
      checkAccount?.call();
      if (snapshot.category == expected &&
          (expected.isEmpty ||
              (snapshot.note != null &&
                  normalizeFavoriteNote(snapshot.note!) ==
                      normalizeFavoriteNote(note)))) {
        return snapshot;
      }
    } on FavoriteMutationException catch (error) {
      if (error.failure != FavoriteMutationFailure.unconfirmed) {
        rethrow;
      }
    } on Exception {
      // An unreadable page is unknown, never an implicit removal.
    }
  }
  checkAccount?.call();
  throw FavoriteMutationException(FavoriteMutationFailure.unconfirmed,
      phase: FavoriteMutationPhase.confirmation, statusCode: submissionStatus);
}

CacheOptions favoriteNetworkCacheOptions(CacheOptions base,
        {bool transient = false}) =>
    base.copyWith(
        policy: transient ? CachePolicy.noCache : CachePolicy.refresh,
        hitCacheOnErrorExcept: const Nullable(null));
