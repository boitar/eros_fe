import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:eros_fe/network/text_form.dart';
import 'package:flutter_test/flutter_test.dart';

class _LoopbackHttp extends HttpOverrides {}

void main() {
  test('real socket receives text forms, binary multipart and JSON unchanged',
      () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final captured = <(String?, List<int>)>[];
      final listener = server.listen((request) async {
        final bytes = await request.fold<List<int>>(
            <int>[], (previous, next) => previous..addAll(next));
        captured.add((request.headers.contentType?.mimeType, bytes));
        request.response.write('ok');
        await request.response.close();
      });
      final dio = Dio(BaseOptions(
          baseUrl: 'http://127.0.0.1:${server.port}', followRedirects: false));
      try {
        const note = ' leading &+=\n备注 trailing ';
        await dio.post<String>('/text',
            data: {'favcat': '0', 'favnote': note, 'update': '1'},
            options: textFormOptions(Options()));
        expect(captured.last.$1, Headers.formUrlEncodedContentType);
        expect(Uri.splitQueryString(utf8.decode(captured.last.$2)),
            {'favcat': '0', 'favnote': note, 'update': '1'});
        final binary = [0, 255, 128, 13, 10, 42];
        await dio.post<String>('/file',
            data: FormData.fromMap({
              'file': MultipartFile.fromBytes(binary, filename: 'fixture.bin'),
            }));
        expect(captured.last.$1, 'multipart/form-data');
        expect(captured.last.$2, containsAllInOrder(binary));
        await dio.post<String>('/json',
            data: {'method': 'synthetic'},
            options: Options(contentType: Headers.jsonContentType));
        expect(captured.last.$1, Headers.jsonContentType);
        expect(
            jsonDecode(utf8.decode(captured.last.$2)), {'method': 'synthetic'});
      } finally {
        dio.close(force: true);
        await server.close(force: true);
        await listener.cancel();
      }
    }, _LoopbackHttp());
  });
}
