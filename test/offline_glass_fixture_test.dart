import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:eros_fe/common/parser/eh_parser.dart';
import 'package:eros_fe/debug/offline_glass.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    await L10n.load(const Locale('en'));
  });
  Future<String> html(String route, {Map<String, dynamic>? query}) async {
    final response = await offlineGlassResponse(RequestOptions(path: route, method: 'GET', queryParameters: query));
    expect(response?.statusCode, 200);
    return utf8.decodeStream(response!.stream);
  }
  test('gallery fixture keeps distinct groups in the real master parser', () async {
    final first = parseGalleryList(await html('/', query: {'f_search': 'offline_glass_a'}));
    final second = parseGalleryList(await html('/', query: {'f_search': 'offline_glass_b'}));
    expect(first.gallerys, hasLength(48)); expect(second.gallerys, hasLength(48));
    expect(first.gallerys!.first.englishTitle, startsWith('Glass A gallery'));
    expect(second.gallerys!.first.englishTitle, startsWith('Glass B gallery'));
    expect(first.gallerys!.first.gid, isNot(second.gallerys!.first.gid));
  });
  test('favorite fixture parses all categories and list rows without enhanced favorites', () async {
    final result = parseGalleryListOfFav(await html('/favorites.php'));
    expect(result.gallerys, hasLength(48)); expect(result.favList, hasLength(10));
    expect(result.favList!.last.favTitle, 'Folder 9');
  });
  test('favorite form fixture is valid for the unchanged master parser', () async {
    final form = parserAddFavPage(await html('/gallerypopups.php'));
    expect(form.favcats, hasLength(10)); expect(form.selectFavcat, '0');
    expect(form.favNote, 'Offline server note');
  });
  test('unknown routes and mutations never receive a glass success response', () async {
    final before = offlineGlassRequests.value;
    expect(await offlineGlassResponse(RequestOptions(path: '/favorites.php', method: 'POST')), isNull);
    expect(await offlineGlassResponse(RequestOptions(path: '/private', method: 'GET')), isNull);
    expect(offlineGlassRequests.value, before);
  });
}
