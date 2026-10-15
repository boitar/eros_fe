import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:eros_fe/debug/offline_favorites.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

const bool offlineAcceptanceEnabled =
    kDebugMode && bool.fromEnvironment('EROS_OFFLINE_ACCEPTANCE');

SemanticsHandle? _acceptanceSemantics;

Widget offlineGallerySemantics(String? gid, Widget child) {
  if (!offlineAcceptanceEnabled) {
    return child;
  }
  // Compact waterfall cards have no title; identify fixtures without altering
  // production accessibility or card layout.
  return Semantics(
    container: true,
    identifier: 'offline-gallery-$gid',
    label: 'Offline fixture gallery $gid',
    child: child,
  );
}

Future<void> initializeOfflineAcceptance() async {
  if (offlineAcceptanceEnabled) {
    // XCTest does not reliably request Flutter semantics in the iPad scene.
    // This explicit test handle collects existing semantics, not new labels.
    _acceptanceSemantics ??= WidgetsBinding.instance.ensureSemantics();
    await initializeDateFormatting();
  }
}

class OfflineAcceptanceAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (offlineFavoriteAcceptanceEnabled) {
      final page = int.tryParse('${options.queryParameters['page'] ?? 0}') ?? 0;
      final response = await offlineFavoriteResponse(
          options, offlineGalleryList(page: page,
              invalidCoverSizes:
                  const bool.fromEnvironment('EROS_WATERFALL_EDGE_CASES')));
      if (response != null) {
        return response;
      }
    }
    if (options.method != 'GET') {
      return ResponseBody.fromString('Offline fixture: mutation blocked', 501);
    }
    if (options.uri.path.startsWith('/offline-cover/')) {
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8'
        '/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
      );
      return ResponseBody.fromBytes(bytes, 200, headers: {
        Headers.contentTypeHeader: ['image/png'],
        Headers.contentLengthHeader: ['${bytes.length}'],
      });
    }
    if (['/', '/popular', '/watched', '/toplist.php']
        .contains(options.uri.path)) {
      final page = int.tryParse('${options.queryParameters['page'] ?? 0}') ?? 0;
      final group = const bool.fromEnvironment('EROS_GROUP_INDEX_ACCEPTANCE')
          ? RegExp(r'offline_group_([abcd])').firstMatch(
              '${options.queryParameters['f_search'] ?? ''}')?.group(1)
          : null;
      final html = offlineGalleryList(
        page: page,
        titlePrefix: group == null ? 'Offline gallery' : 'Offline group ${group.toUpperCase()} gallery',
        gidBase: group == null ? 9100000 : 9444000 + group.codeUnitAt(0) * 1000,
        invalidCoverSizes:
            const bool.fromEnvironment('EROS_WATERFALL_EDGE_CASES'),
      );
      return ResponseBody.fromString(html, 200, headers: {
        Headers.contentTypeHeader: ['text/html; charset=utf-8'],
        Headers.contentLengthHeader: ['${utf8.encode(html).length}'],
      });
    }
    return ResponseBody.fromString('Offline fixture: request blocked', 503);
  }

  @override
  void close({bool force = false}) {}
}

String offlineGalleryList({int page = 0, bool invalidCoverSizes = false,
    String titlePrefix = 'Offline gallery', int gidBase = 9100000}) {
  final rows = List.generate(48, (index) {
    final gid = gidBase + page * 48 + index;
    final dimensions = invalidCoverSizes && index % 3 == 0
        ? 'height:0px;width:0px'
        : 'height:${280 + index % 7 * 20}px;width:200px';
    return '''
<tr>
<td class="gl1c glcat"><div>Non-H</div></td>
<td class="gl2c">
<div><div><img src="http://127.0.0.1/offline-cover/$gid.png"
style="$dimensions"></div></div>
<div></div>
<div><div>2026-01-01 00:00</div><div class="ir"
style="background-position:32px 0px"></div></div>
</td>
<td class="gl3c glname"><a href="https://e-hentai.org/g/$gid/0000000000/">
<div class="glink">$titlePrefix $index - neutral layout fixture</div></a>
<div class="gt">offline</div><div class="gt">long-neutral-layout-tag</div></td>
<td class="gl4c glhide"><div>offline</div><div>20 pages</div></td>
</tr>''';
  }).join();
  return '''
<!doctype html><html><body>
<div id="dms"><div><select><option value="l" selected>Compact</option>
</select></div></div>
<table class="ptt"><tbody><tr><td>0</td><td class="ptds">1</td>
<td>2</td><td>3</td><td>4</td></tr></tbody></table>
<table class="itg"><tbody>$rows</tbody></table>
</body></html>'''
      .replaceAll(RegExp(r'>\s+<'), '><');
}
