import 'package:dio/dio.dart';
import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/models/favcat.dart';
import 'package:eros_fe/models/user.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' show parse;

const offlineFavoriteAcceptanceEnabled = kDebugMode &&
    bool.fromEnvironment('EROS_OFFLINE_ACCEPTANCE') &&
    bool.fromEnvironment('EROS_FAVORITE_ACCEPTANCE');

/// Only a new isolated acceptance installation may use this synthetic account.
void initializeOfflineFavorites() {
  if (!offlineFavoriteAcceptanceEnabled) {
    return;
  }
  final member = Global.profile.user.memberId ?? '';
  if (member.isNotEmpty && member != '9000999') {
    throw StateError('Favorite acceptance requires an isolated empty account');
  }
  Global.profile = Global.profile.copyWith(
    locale: 'zh_CN',
    user: User(
      memberId: '9000999',
      passHash: 'offline-fixture-no-credential',
      nickName: 'Offline acceptance',
      favcat: [
        for (var index = 0; index < 10; index++)
          Favcat(favId: '$index', favTitle: 'Offline folder $index',
              totNum: index == 7 ? 48 : 0),
      ],
    ),
    ehConfig: Global.profile.ehConfig.copyWith(listMode: 'list'),
  );
}

String offlineFavoritePopup() => '''
<div id="galpop"><div><div class="nosel">
${List.generate(10, (index) => '''
<div><div><input type="radio" name="favcat" value="$index"
${index == 7 ? 'checked' : ''}></div><div>icon</div>
<div>Offline folder $index</div></div>''').join()}
</div><textarea>Offline server note</textarea></div></div>''';

String offlineFavoriteList(String galleryHtml, {bool categories = false}) {
  final color = EHConst.favCat.entries.firstWhere((entry) => entry.value == '7').key;
  var html = galleryHtml.replaceAll(
    '<div>2026-01-01 00:00</div>',
    '<div title="Offline folder 7" style="border-color:$color;">'
        '2026-01-01 00:00</div>',
  );
  if (categories) {
    final folders = List.generate(10, (index) => '''
<div><div>${index == 7 ? 48 : 0}</div><div>icon</div>
<div>Offline folder $index</div></div>''').join();
    html = html.replaceFirst(
        '<body>', '<body><div class="ido"><div class="nosel">$folders</div></div>');
  }
  final document = parse(html);
  for (final cell in document.querySelectorAll('td.gl2c')) {
    cell.children[1].remove();
    cell.querySelector('.ir')!.innerHtml =
        '<div></div><div><div></div><div>20 pages</div></div>';
  }
  return document.outerHtml;
}

/// Read-only UI fixtures: every mutation still reaches the adapter's 501 fence.
Future<ResponseBody?> offlineFavoriteResponse(
    RequestOptions options, String galleryHtml) async {
  if (options.method != 'GET') {
    return null;
  }
  final route = options.uri.path;
  String? html;
  if (route == '/gallerypopups.php' &&
      options.queryParameters['act'] == 'addfav') {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    html = offlineFavoritePopup();
  } else if (route == '/favorites.php') {
    html = offlineFavoriteList(galleryHtml, categories: true);
  } else if (['/', '/popular', '/watched', '/toplist.php'].contains(route)) {
    html = offlineFavoriteList(galleryHtml);
  }
  return html == null
      ? null
      : ResponseBody.fromString(html, 200, headers: {
          Headers.contentTypeHeader: ['text/html; charset=utf-8'],
        });
}
