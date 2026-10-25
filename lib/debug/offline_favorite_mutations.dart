import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/debug/offline_favorites.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' show parse;
import 'package:path/path.dart' as path;

const offlineFavoriteMutationsEnabled = kDebugMode &&
    bool.fromEnvironment('EROS_OFFLINE_ACCEPTANCE') &&
    bool.fromEnvironment('EROS_FAVORITE_ACCEPTANCE') &&
    bool.fromEnvironment('EROS_FAVORITE_MUTATION_ACCEPTANCE');

Future<OfflineFavoriteMutationStore>? _store;

/// Synthetic server state only. Never connects to EH/EX or a real account.
class OfflineFavoriteMutationStore {
  OfflineFavoriteMutationStore(this.file);
  final File file;
  final records = <String, Map<String, String>>{};
  final requests = <Map<String, Object?>>[];

  Future<void> load() async {
    if (await file.exists()) {
      final saved =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      for (final entry in (saved['records'] as Map<String, dynamic>).entries) {
        records[entry.key] = Map<String, String>.from(entry.value as Map);
      }
      requests.addAll((saved['requests'] as List)
          .map((value) => Map<String, Object?>.from(value as Map)));
    }
  }

  String category(String gid) =>
      records[gid]?['category'] ??
      (gid == '9100000' || gid == '9100002' ? '' : '7');
  String note(String gid) =>
      records[gid]?['note'] ??
      (category(gid).isEmpty ? '' : 'Offline server note');

  Future<void> save() async {
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
        jsonEncode({'records': records, 'requests': requests}),
        flush: true);
    await temporary.rename(file.path);
  }

  String popup(String gid) => '''
<div id="galpop"><div><div class="nosel">
${List.generate(10, (i) => '''
<div><div><input type="radio" name="favcat" value="$i"
${i == 0 ? 'checked' : ''}></div><div>icon</div>
<div>Offline folder $i</div></div>''').join()}
</div><textarea>${const HtmlEscape().convert(note(gid))}</textarea></div></div>''';

  String detail(String gid) => '''
<html><body><div id="gn">Offline gallery ${int.parse(gid) - 9100000} - neutral layout fixture</div>
<div id="gdc"><div>Non-H</div></div>
<div id="fav">${category(gid).isEmpty ? '' : '<div style="background-position:0px -${2 + int.parse(category(gid)) * 19}px"></div>'}</div>
<a id="favoritelink">${category(gid).isEmpty ? 'Add to Favorites' : 'Offline folder ${category(gid)}'}</a>
<div id="gdd"><table><tbody>
<tr><td>Posted:</td><td>2026-01-01 00:00</td></tr>
<tr><td>Length:</td><td>20 pages</td></tr>
</tbody></table></div></body></html>''';

  String list(String html, {String? favoriteCategory}) {
    final document = parse(offlineFavoriteList(html, categories: true));
    final counts = List<int>.filled(10, 0);
    for (var i = 0; i < 48; i++) {
      final cat = category('${9100000 + i}');
      if (cat.isNotEmpty) {
        counts[int.parse(cat)]++;
      }
    }
    final folders = document.querySelectorAll('.ido .nosel > div');
    for (var i = 0; i < 10; i++) {
      folders[i].children.first.text = '${counts[i]}';
    }
    for (final row in document.querySelectorAll('tr')) {
      final href = row.querySelector('a[href*="/g/"]')?.attributes['href'];
      if (href == null) {
        continue;
      }
      final gid = RegExp(r'/g/(\d+)/').firstMatch(href)!.group(1)!;
      final cat = category(gid);
      if (favoriteCategory != null &&
          (cat.isEmpty ||
              (favoriteCategory != 'a' && cat != favoriteCategory))) {
        row.remove();
        continue;
      }
      for (final marker in row.querySelectorAll('div[title][style]')) {
        marker.attributes.remove('title');
        marker.attributes.remove('style');
      }
      final dates = row.querySelectorAll('div').where(
          (node) => node.children.isEmpty && node.text == '2026-01-01 00:00');
      if (cat.isNotEmpty && dates.isNotEmpty) {
        final color = EHConst.favCat.entries
            .firstWhere((entry) => entry.value == cat)
            .key;
        dates.first.attributes.addAll({
          'id': 'posted_$gid',
          'title': 'Offline folder $cat',
          'style': 'border-color:$color;',
        });
      }
    }
    return document.outerHtml;
  }
}

Future<ResponseBody?> offlineFavoriteMutationResponse(RequestOptions options,
    Stream<Uint8List>? stream, String galleryHtml) async {
  if (!offlineFavoriteMutationsEnabled) {
    return null;
  }
  if (Global.profile.user.memberId != '9000999') {
    throw StateError(
        'Favorite mutation fixture requires the synthetic account');
  }
  _store ??= () async {
    final store = OfflineFavoriteMutationStore(
        File(path.join(Global.appDocPath, 'offline-favorite-mutations.json')));
    await store.load();
    return store;
  }();
  final store = await _store!;
  final route = options.uri.path;
  final gid =
      '${options.queryParameters['gid'] ?? RegExp(r'^/g/(\d+)/0000000000/?$').firstMatch(route)?.group(1) ?? ''}';
  final validGallery = RegExp(r'^91000[0-3][0-9]$|^910004[0-7]$').hasMatch(gid);
  ResponseBody response(String body, [int status = 200]) =>
      ResponseBody.fromString(body, status, headers: {
        Headers.contentTypeHeader: ['text/html; charset=utf-8'],
      });
  if (options.method == 'POST') {
    if (route != '/gallerypopups.php' ||
        !validGallery ||
        options.queryParameters['t'] != '0000000000' ||
        options.queryParameters['act'] != 'addfav') {
      return response('Synthetic mutation not allowed', 501);
    }
    final bytes = <int>[];
    if (stream != null) {
      await stream.forEach(bytes.addAll);
    }
    final textForm = options.contentType == Headers.formUrlEncodedContentType;
    final fields = textForm
        ? Uri.splitQueryString(utf8.decode(bytes))
        : <String, String>{};
    final cat = fields['favcat'] ?? '';
    final status = !textForm || gid == '9100002'
        ? 403
        : (RegExp(r'^[0-9]$').hasMatch(cat) || cat == 'favdel')
            ? 200
            : 400;
    store.requests.add({
      'method': 'POST',
      'gid': gid,
      'category': cat,
      'status': status,
      'textForm': textForm
    });
    if (status == 200) {
      store.records[gid] = {
        'category': cat == 'favdel' ? '' : cat,
        'note': fields['favnote'] ?? '',
      };
    }
    await store.save();
    return response(
        status == 200
            ? '<script>window.close()</script>'
            : 'Request forbidden by administrative rules',
        status);
  }
  if (options.method != 'GET') {
    return null;
  }
  if (route == '/gallerypopups.php' && validGallery) {
    return response(store.popup(gid));
  }
  if (route.startsWith('/g/') && validGallery) {
    return response(store.detail(gid));
  }
  if (['/', '/popular', '/watched', '/toplist.php', '/favorites.php']
      .contains(route)) {
    return response(store.list(galleryHtml,
        favoriteCategory: route == '/favorites.php'
            ? '${options.queryParameters['favcat'] ?? 'a'}'
            : null));
  }
  return null;
}
