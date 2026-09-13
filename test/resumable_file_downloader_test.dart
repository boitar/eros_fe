import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:eros_fe/common/controller/download/resumable_file_downloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  late _TestHttpServer httpServer;
  late Directory tempDirectory;

  final payload = List<int>.generate(8192, (index) => index % 251);

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('eros-resume-test-');
    httpServer = _TestHttpServer();
    await httpServer.start();
  });

  tearDown(() async {
    await httpServer.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  String destinationPath(String name) => path.join(tempDirectory.path, name);

  Future<ResumableDownloadResult> downloadUrl(Uri url, String name,
      {CancelToken? cancelToken, ProgressCallback? onReceiveProgress}) {
    return ResumableFileDownloader(Dio()).download(
      url: url.toString(),
      destinationPath: destinationPath(name),
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<ResumableDownloadResult> download(String route, String name,
      {CancelToken? cancelToken, ProgressCallback? onReceiveProgress}) {
    return downloadUrl(
      httpServer.url(route),
      name,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }

  test('downloads a normal 200 response and atomically finalizes it', () async {
    httpServer.onRequest = (request) => httpServer.sendFullResponse(
          request,
          payload,
          etag: '"v1"',
        );

    final result = await download('/full', 'full.bin');
    final destination = File(destinationPath('full.bin'));

    expect(result.resumed, isFalse);
    expect(result.bytes, payload.length);
    expect(await destination.readAsBytes(), payload);
    expect(await File('${destination.path}.part').exists(), isFalse);
    expect(await File('${destination.path}.part.json').exists(), isFalse);
    expect(httpServer.requests.single.range, isNull);
  });

  test('appends a 206 response to an existing partial file', () async {
    final url = httpServer.url('/range').toString();
    final destination = File(destinationPath('range.bin'));
    const prefixLength = 1379;
    await File('${destination.path}.part')
        .writeAsBytes(payload.sublist(0, prefixLength));
    await File('${destination.path}.part.json').writeAsString(jsonEncode({
      'url': url,
      'etag': '"v1"',
    }));
    httpServer.onRequest = (request) => httpServer.sendRangeResponse(
          request,
          payload,
          etag: '"v1"',
        );

    final result = await download('/range', 'range.bin');

    expect(result.resumed, isTrue);
    expect(await destination.readAsBytes(), payload);
    expect(httpServer.requests.single.range, 'bytes=$prefixLength-');
    expect(httpServer.requests.single.ifRange, '"v1"');
  });

  test('replaces the partial file when the server ignores Range', () async {
    final destination = File(destinationPath('ignore-range.bin'));
    const prefixLength = 512;
    await File('${destination.path}.part')
        .writeAsBytes(payload.sublist(0, prefixLength));
    await File('${destination.path}.part.json').writeAsString(jsonEncode({
      'url': httpServer.url('/ignore-range').toString(),
      'etag': '"v1"',
    }));
    httpServer.onRequest = (request) => httpServer.sendFullResponse(
          request,
          payload,
          etag: '"v1"',
        );

    final result = await download('/ignore-range', 'ignore-range.bin');

    expect(result.resumed, isFalse);
    expect(await destination.readAsBytes(), payload);
    expect(httpServer.requests.single.range, 'bytes=$prefixLength-');
  });

  test('accepts 416 when the existing partial file is already complete',
      () async {
    final destination = File(destinationPath('already-complete.bin'));
    await File('${destination.path}.part').writeAsBytes(payload);
    await File('${destination.path}.part.json').writeAsString(jsonEncode({
      'url': httpServer.url('/already-complete').toString(),
      'etag': '"v1"',
    }));
    httpServer.onRequest = (request) => httpServer.sendRangeResponse(
          request,
          payload,
          etag: '"v1"',
        );

    final result = await download('/already-complete', 'already-complete.bin');

    expect(result.resumed, isTrue);
    expect(result.bytes, payload.length);
    expect(await destination.readAsBytes(), payload);
    expect(httpServer.requests.single.statusExpected,
        HttpStatus.requestedRangeNotSatisfiable);
  });

  test('keeps the partial file after a truncated response', () async {
    final destination = File(destinationPath('truncated.bin'));
    final prefix = payload.sublist(0, 1024);
    final truncatedServer = _TruncatedHttpServer(
      bodyLength: payload.length,
      prefix: prefix,
    );
    await truncatedServer.start();
    try {
      await expectLater(
        downloadUrl(truncatedServer.url, 'truncated.bin'),
        throwsA(anything),
      );

      expect(await File('${destination.path}.part').readAsBytes(), prefix);
      expect(await File('${destination.path}.part.json').exists(), isTrue);
      expect(await destination.exists(), isFalse);
    } finally {
      await truncatedServer.close();
    }
  });

  test('keeps the partial file when the request is cancelled', () async {
    final destination = File(destinationPath('cancelled.bin'));
    final cancelToken = CancelToken();
    final firstProgress = Completer<void>();
    final cancelPayload =
        List<int>.generate(1024 * 1024, (index) => index % 251);
    httpServer.onRequest = (request) => httpServer.sendChunkedResponse(
          request,
          cancelPayload,
          chunkSize: 1024,
          delay: const Duration(milliseconds: 5),
        );

    final future = download(
      '/cancelled',
      'cancelled.bin',
      cancelToken: cancelToken,
      onReceiveProgress: (count, total) {
        if (count > 0 && !cancelToken.isCancelled) {
          firstProgress.complete();
          cancelToken.cancel('test cancellation');
        }
      },
    );
    await firstProgress.future.timeout(const Duration(seconds: 2));
    await expectLater(future, throwsA(anything));

    final partial = File('${destination.path}.part');
    expect(await partial.exists(), isTrue);
    expect(await partial.length(), greaterThan(0));
    expect(await partial.length(), lessThan(cancelPayload.length));
    expect(await destination.exists(), isFalse);
  });
}

class _TestHttpServer {
  late HttpServer _server;
  late StreamSubscription<HttpRequest> _subscription;
  Future<void> Function(HttpRequest request)? onRequest;
  final requests = <_RequestRecord>[];

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _subscription = _server.listen((request) async {
      final range = request.headers.value(HttpHeaders.rangeHeader);
      final ifRange = request.headers.value(HttpHeaders.ifRangeHeader);
      requests.add(_RequestRecord(
        range: range,
        ifRange: ifRange,
        statusExpected: null,
      ));
      try {
        await onRequest?.call(request);
      } catch (_) {
        // Cancellation closes the client socket while a response is writing.
      }
    });
  }

  Uri url(String route) => Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.host,
      port: _server.port,
      path: route);

  Future<void> close() async {
    await _subscription.cancel();
    await _server.close(force: true);
  }

  Future<void> sendFullResponse(HttpRequest request, List<int> body,
      {required String etag}) async {
    final response = request.response;
    response.statusCode = HttpStatus.ok;
    response.headers.contentLength = body.length;
    response.headers.set('etag', etag);
    response.add(body);
    await response.close();
  }

  Future<void> sendRangeResponse(HttpRequest request, List<int> body,
      {required String etag}) async {
    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
    final match = rangeHeader == null
        ? null
        : RegExp(r'^bytes=(\d+)-$').firstMatch(rangeHeader);
    final start = int.tryParse(match?.group(1) ?? '');
    final response = request.response;
    final record = requests.last;
    if (start != null && start >= body.length) {
      response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      response.headers.set('content-range', 'bytes */${body.length}');
      record.statusExpected = HttpStatus.requestedRangeNotSatisfiable;
      await response.close();
      return;
    }

    if (start != null) {
      response.statusCode = HttpStatus.partialContent;
      response.headers.contentLength = body.length - start;
      response.headers.set(
        'content-range',
        'bytes $start-${body.length - 1}/${body.length}',
      );
      record.statusExpected = HttpStatus.partialContent;
      response.headers.set('etag', etag);
      response.add(body.sublist(start));
      await response.close();
      return;
    }

    await sendFullResponse(request, body, etag: etag);
  }

  Future<void> sendChunkedResponse(
    HttpRequest request,
    List<int> body, {
    required int chunkSize,
    required Duration delay,
  }) async {
    final response = request.response;
    response.statusCode = HttpStatus.ok;
    response.headers.contentLength = body.length;
    response.headers.set('etag', '"v1"');
    for (var offset = 0; offset < body.length; offset += chunkSize) {
      final end =
          offset + chunkSize < body.length ? offset + chunkSize : body.length;
      response.add(body.sublist(offset, end));
      await response.flush();
      await Future<void>.delayed(delay);
    }
    await response.close();
  }
}

class _RequestRecord {
  _RequestRecord({
    required this.range,
    required this.ifRange,
    required this.statusExpected,
  });

  final String? range;
  final String? ifRange;
  int? statusExpected;
}

class _TruncatedHttpServer {
  _TruncatedHttpServer({required this.bodyLength, required this.prefix});

  final int bodyLength;
  final List<int> prefix;
  late ServerSocket _server;
  late StreamSubscription<Socket> _subscription;

  Uri get url => Uri(
        scheme: 'http',
        host: InternetAddress.loopbackIPv4.host,
        port: _server.port,
        path: '/truncated',
      );

  Future<void> start() async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _subscription = _server.listen((socket) async {
      try {
        await _readRequest(socket);
        socket.add(utf8.encode(
          'HTTP/1.1 200 OK\r\n'
          'Content-Length: $bodyLength\r\n'
          'ETag: "v1"\r\n'
          'Connection: close\r\n'
          '\r\n',
        ));
        socket.add(prefix);
        await socket.flush();
      } catch (_) {
        // The client may close the connection while the truncated response
        // is being delivered.
      } finally {
        socket.destroy();
      }
    });
  }

  Future<void> _readRequest(Socket socket) async {
    final requestBytes = <int>[];
    await for (final chunk in socket) {
      requestBytes.addAll(chunk);
      if (utf8
          .decode(requestBytes, allowMalformed: true)
          .contains('\r\n\r\n')) {
        break;
      }
    }
  }

  Future<void> close() async {
    await _subscription.cancel();
    await _server.close();
  }
}
