import 'dart:io';

import 'package:eros_fe/common/parser/gallery_detail_parser.dart';
import 'package:eros_fe/common/parser/gallery_fav_parser.dart';
import 'package:eros_fe/common/parser/gallery_list_parser.dart';
import 'package:eros_fe/debug/offline_acceptance.dart';
import 'package:eros_fe/debug/offline_favorite_mutations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart';

void main() {
  late Directory directory;
  late OfflineFavoriteMutationStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('eros-favorite-fixture-');
    store = OfflineFavoriteMutationStore(File('${directory.path}/server.json'));
  });
  tearDown(() => directory.delete(recursive: true));

  test('default popup zero is distinct from explicit unfavorited detail', () {
    expect(parserAddFavPage(store.popup('9100000')).selectFavcat, '0');
    expect(parseDetailFavorite(parse(store.detail('9100000'))).$1, '');
  });

  test('synthetic server persists note and category across process replacement',
      () async {
    store.records['9100000'] = {
      'category': '9',
      'note': ' leading &+=\n备注 trailing ',
    };
    await store.save();
    final restarted = OfflineFavoriteMutationStore(store.file);
    await restarted.load();
    expect(restarted.category('9100000'), '9');
    expect(parserAddFavPage(restarted.popup('9100000')).favNote,
        ' leading &+=\n备注 trailing ');
    expect(parseDetailFavorite(parse(restarted.detail('9100000'))).$1, '9');
  });

  test('server list membership, category and removal follow server state',
      () async {
    final base = offlineGalleryList();
    expect(
        parseGalleryListOfFav(store.list(base, favoriteCategory: '0')).gallerys,
        isEmpty);
    store.records['9100000'] = {'category': '0', 'note': ''};
    final saved = parseGalleryListOfFav(store.list(base, favoriteCategory: '0'))
        .gallerys!;
    expect(saved, hasLength(1));
    expect(saved.single.gid, '9100000');
    expect(saved.single.favcat, '0');
    store.records['9100000'] = {'category': '', 'note': ''};
    expect(
        parseGalleryListOfFav(store.list(base, favoriteCategory: '0')).gallerys,
        isEmpty);
  });
}
