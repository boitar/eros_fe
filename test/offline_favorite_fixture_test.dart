import 'package:dio/dio.dart';
import 'package:eros_fe/common/parser/gallery_fav_parser.dart';
import 'package:eros_fe/common/parser/gallery_list_parser.dart';
import 'package:eros_fe/debug/offline_acceptance.dart';
import 'package:eros_fe/debug/offline_favorites.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting();
    await L10n.load(const Locale('en'));
  });

  test('native fixture uses production category and popup parsers', () {
    final list = parseGalleryListOfFav(
        offlineFavoriteList(offlineGalleryList(), categories: true));
    expect(list.favList, hasLength(10));
    expect(list.gallerys, hasLength(48));
    expect(list.gallerys!.every((gallery) => gallery.favcat == '7'), isTrue);
    final popup = parserAddFavPage(offlineFavoritePopup());
    expect(popup.selectFavcat, '7');
    expect(popup.favNote, 'Offline server note');
    expect(popup.favcats.last.favTitle, 'Offline folder 9');
  });

  test('favorite native fixture cannot handle writes or unknown routes', () async {
    for (final route in ['/gallerypopups.php', '/private']) {
      for (final method in ['POST', 'PUT', 'DELETE']) {
        expect(await offlineFavoriteResponse(
            RequestOptions(path: route, method: method), offlineGalleryList()),
            isNull);
      }
    }
    expect(await offlineFavoriteResponse(
        RequestOptions(path: '/private'), offlineGalleryList()), isNull);
  });
}
