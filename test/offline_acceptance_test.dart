import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:eros_fe/common/parser/gallery_list_parser.dart';
import 'package:eros_fe/debug/offline_acceptance.dart';
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

  test('offline list is parsed by the production parser', () {
    expect(isGalleryListDmL(offlineGalleryList()), isTrue);
    final list = parseGalleryList(offlineGalleryList(invalidCoverSizes: true));
    expect(list.gallerys, hasLength(48));
    expect(list.gallerys!.first.englishTitle, startsWith('Offline gallery'));
    expect(list.gallerys!.first.imgWidth, 0);
    expect(list.gallerys!.first.imgHeight, 0);
    expect(list.gallerys![1].imgWidth, 200);
    expect(list.gallerys!.map((item) => item.gid).toSet(), hasLength(48));
  });

  test('pages have independent gallery identities', () {
    final first = parseGalleryList(offlineGalleryList());
    final second = parseGalleryList(offlineGalleryList(page: 1));
    final ids = first.gallerys!.map((item) => item.gid).toSet();
    expect(second.gallerys!.any((item) => ids.contains(item.gid)), isFalse);
  });

  test('offline adapter never sends mutations or unknown requests', () async {
    final dio = Dio()..httpClientAdapter = OfflineAcceptanceAdapter();
    final blocked = Options(validateStatus: (_) => true);
    final post = await dio.post('https://example.invalid/upload',
        data: 'fixture', options: blocked);
    final unknown =
        await dio.get('https://example.invalid/private', options: blocked);
    expect(post.statusCode, 501);
    expect(unknown.statusCode, 503);
    dio.close();
  });

  test('offline cover bytes decode without network access', () async {
    final dio = Dio()..httpClientAdapter = OfflineAcceptanceAdapter();
    final response = await dio.get<List<int>>(
      'http://127.0.0.1/offline-cover/9100000.png',
      options: Options(responseType: ResponseType.bytes),
    );
    final codec =
        await ui.instantiateImageCodec(Uint8List.fromList(response.data!));
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 1);
    expect(frame.image.height, 1);
    frame.image.dispose();
    codec.dispose();
    dio.close();
  });
}
