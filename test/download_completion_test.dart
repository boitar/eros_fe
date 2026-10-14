import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/network/api.dart';
import 'package:eros_fe/network/app_dio/pdio.dart';
import 'package:eros_fe/network/request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;

class _Settings extends GetxService implements EhSettingService {
  @override
  bool get nativeHttpClientAdapter => false;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected setting: ${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late HttpServer server;
  late Dio transport;
  late DioHttpConfig previousConfig;
  final payload = List.generate(4096, (index) => index % 251);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('eros-download-completion-');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.contentLength = payload.length;
      request.response.add(payload);
      await request.response.close();
    });
    Get.testMode = true;
    Get.put<EhSettingService>(_Settings());
    // The widget binding replaces HTTP with synthetic 400 responses. These
    // integration cases use only the loopback server bound above.
    HttpOverrides.global = null;
    Api.cacheOption = CacheOptions(store: MemCacheStore());
    previousConfig = globalDioConfig;
    globalDioConfig = DioHttpConfig(
        baseUrl: 'http://127.0.0.1:${server.port}', domainFronting: false);
    transport = DioHttpClient(dioConfig: globalDioConfig).dio;
    transport.interceptors.clear();
    transport.httpClientAdapter = IOHttpClientAdapter();
  });
  tearDown(() async {
    transport.close(force: true);
    globalDioConfig = previousConfig;
    await server.close(force: true);
    await root.delete(recursive: true);
    Get.reset();
  });

  String getUrl() => 'http://127.0.0.1:${server.port}/image.jpg';

  test('completion waits for the file and asynchronous database callback', () async {
    final callbackStarted = Completer<void>();
    final release = Completer<void>();
    final output = File('${root.path}/image.jpg');
    var completed = false;
    var calls = 0;
    final download = ehDownload(
      url: getUrl(),
      savePath: output.path,
      onDownloadComplete: () async {
        calls++;
        expect(await output.readAsBytes(), payload);
        callbackStarted.complete();
        await release.future;
      },
    ).then((_) => completed = true);
    await callbackStarted.future;
    expect(completed, isFalse);
    release.complete();
    await download;
    expect(calls, 1);
  });

  test('cancellation propagates without publishing successful completion', () async {
    final token = CancelToken()..cancel('fixture cancellation');
    var calls = 0;
    await expectLater(
      ehDownload(
        url: getUrl(),
        savePath: '${root.path}/cancelled.jpg',
        cancelToken: token,
        onDownloadComplete: () => calls++,
      ),
      throwsA(isA<DioException>().having(
          (error) => error.type, 'type', DioExceptionType.cancel)),
    );
    expect(calls, 0);
  });

  test('a failed completion write remains a failure for the caller', () async {
    await expectLater(
      ehDownload(
        url: getUrl(),
        savePath: '${root.path}/write-failed.jpg',
        onDownloadComplete: () async => throw StateError('fixture write failed'),
      ),
      throwsStateError,
    );
  });
}
