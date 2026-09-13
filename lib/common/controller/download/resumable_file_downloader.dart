import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

/// Result returned after a file has been atomically moved to its final path.
class ResumableDownloadResult {
  const ResumableDownloadResult({
    required this.path,
    required this.bytes,
    required this.resumed,
  });

  final String path;
  final int bytes;
  final bool resumed;
}

/// Raised when a response cannot be used to complete a resumable download.
class ResumableDownloadException implements Exception {
  const ResumableDownloadException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'ResumableDownloadException(statusCode: $statusCode, message: $message)';
}

class ResumableFileDownloader {
  ResumableFileDownloader(this._dio);

  final Dio _dio;

  Future<ResumableDownloadResult> download({
    required String url,
    required String destinationPath,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    final destination = File(destinationPath);
    final part = File('$destinationPath.part');
    final metadataFile = File('$destinationPath.part.json');

    await destination.parent.create(recursive: true);

    _PartMetadata? metadata = await _readMetadata(metadataFile);
    if (metadata != null && metadata.url != url) {
      await _deleteIfExists(part);
      await _deleteIfExists(metadataFile);
      metadata = null;
    }

    // Files produced by older releases were written directly to the final
    // path. Treat one as a partial file so an interrupted upgrade can resume.
    if (!await part.exists() && await destination.exists()) {
      await destination.rename(part.path);
    }

    var offset = await _lengthIfExists(part);
    var resumed = offset > 0;

    // A server may return a response that cannot be matched to the local
    // offset. Retry once from byte zero after discarding that partial file.
    for (var requestAttempt = 0; requestAttempt < 2; requestAttempt++) {
      final requestHeaders = <String, String>{};
      if (offset > 0) {
        requestHeaders['Range'] = 'bytes=$offset-';
        final validator = metadata?.validator;
        if (validator != null) {
          requestHeaders['If-Range'] = validator;
        }
      }

      final response = await _dio.get<ResponseBody>(
        url,
        cancelToken: cancelToken,
        options: CacheOptions(
          policy: CachePolicy.noCache,
          store: MemCacheStore(),
        ).toOptions().copyWith(
              responseType: ResponseType.stream,
              headers: requestHeaders.isEmpty ? null : requestHeaders,
              validateStatus: (status) => status != null && status < 500,
            ),
      );

      final statusCode = response.statusCode ?? -1;
      if (statusCode == HttpStatus.requestedRangeNotSatisfiable) {
        final range = _parseContentRange(
          response.headers.value('content-range'),
        );
        await _drainResponseBody(response.data);
        if (range?.total != null && offset == range!.total) {
          await _finalize(part, destination);
          await _deleteIfExists(metadataFile);
          onReceiveProgress?.call(offset, range.total!);
          return ResumableDownloadResult(
            path: destination.path,
            bytes: offset,
            resumed: resumed,
          );
        }

        if (requestAttempt == 0) {
          await _resetPartial(part, metadataFile);
          offset = 0;
          resumed = false;
          metadata = null;
          continue;
        }

        throw ResumableDownloadException(
          'The server rejected the requested range',
          statusCode: statusCode,
        );
      }

      if (statusCode < 200 || statusCode >= 300) {
        final error = DioException.badResponse(
          statusCode: statusCode,
          requestOptions: response.requestOptions,
          response: response,
        );
        await _drainResponseBody(response.data);
        throw error;
      }

      var append = offset > 0;
      int? totalLength;
      if (append && statusCode == HttpStatus.partialContent) {
        final range = _parseContentRange(
          response.headers.value('content-range'),
        );
        if (range == null || range.start != offset) {
          await _drainResponseBody(response.data);
          if (requestAttempt == 0) {
            await _resetPartial(part, metadataFile);
            offset = 0;
            resumed = false;
            metadata = null;
            continue;
          }
          throw const ResumableDownloadException(
            'The server returned an invalid Content-Range header',
          );
        }
        totalLength = range.total;
      } else if (append && statusCode == HttpStatus.ok) {
        // Range is optional in HTTP. A 200 response means the server ignored
        // it, so replace the partial bytes with the complete response.
        append = false;
        offset = 0;
        resumed = false;
        totalLength = _contentLength(response.headers);
      } else {
        append = false;
        offset = 0;
        totalLength = _contentLength(response.headers);
      }

      final responseBody = response.data;
      if (responseBody == null) {
        throw const ResumableDownloadException('The response body is empty');
      }

      metadata = _PartMetadata(
        url: url,
        etag: response.headers.value('etag'),
        lastModified: response.headers.value('last-modified'),
        totalLength: totalLength,
      );
      await _writeMetadata(metadataFile, metadata);

      var received = append ? offset : 0;
      RandomAccessFile? output;
      try {
        output = await part.open(
          mode: append ? FileMode.append : FileMode.write,
        );
        await for (final chunk in responseBody.stream) {
          await output.writeFrom(chunk);
          received += chunk.length;
          onReceiveProgress?.call(received, totalLength ?? -1);
          if (cancelToken?.isCancelled ?? false) {
            throw cancelToken!.cancelError ??
                DioException.requestCancelled(
                  requestOptions: response.requestOptions,
                  reason: null,
                );
          }
        }
      } finally {
        await output?.close();
      }

      final actualLength = await part.length();
      if (totalLength != null && actualLength != totalLength) {
        throw ResumableDownloadException(
          'Downloaded length $actualLength does not match expected '
          'length $totalLength',
        );
      }

      await _finalize(part, destination);
      await _deleteIfExists(metadataFile);
      onReceiveProgress?.call(actualLength, totalLength ?? actualLength);
      return ResumableDownloadResult(
        path: destination.path,
        bytes: actualLength,
        resumed: resumed,
      );
    }

    throw const ResumableDownloadException('Unable to start download');
  }

  Future<_PartMetadata?> _readMetadata(File file) async {
    if (!await file.exists()) {
      return null;
    }
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic> || json['url'] is! String) {
        return null;
      }
      return _PartMetadata(
        url: json['url'] as String,
        etag: json['etag'] as String?,
        lastModified: json['lastModified'] as String?,
        totalLength: (json['totalLength'] as num?)?.toInt(),
      );
    } on Object {
      return null;
    }
  }

  Future<void> _writeMetadata(File file, _PartMetadata metadata) async {
    await file.writeAsString(jsonEncode(metadata.toJson()));
  }

  Future<void> _drainResponseBody(ResponseBody? responseBody) async {
    await responseBody?.stream.drain<void>();
  }

  Future<void> _resetPartial(File part, File metadata) async {
    await _deleteIfExists(part);
    await _deleteIfExists(metadata);
  }

  Future<void> _finalize(File part, File destination) async {
    if (!await part.exists()) {
      throw const ResumableDownloadException('Partial file is missing');
    }
    try {
      await part.rename(destination.path);
    } on FileSystemException {
      // rename replaces on Darwin/POSIX, but not on every Dart filesystem.
      // Keep the partial file until the replacement has succeeded.
      if (await destination.exists()) {
        await destination.delete();
      }
      await part.rename(destination.path);
    }
  }

  Future<int> _lengthIfExists(File file) async {
    if (!await file.exists()) {
      return 0;
    }
    return await file.length();
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  int? _contentLength(Headers headers) {
    final value = headers.value(Headers.contentLengthHeader);
    return int.tryParse(value ?? '');
  }

  _ContentRange? _parseContentRange(String? value) {
    if (value == null) {
      return null;
    }
    final match =
        RegExp(r'^bytes\s+(\d+)-(\d+)/(\d+|\*)$', caseSensitive: false)
            .firstMatch(value.trim());
    if (match == null) {
      final unsatisfied = RegExp(r'^bytes\s+\*/(\d+)$', caseSensitive: false)
          .firstMatch(value.trim());
      if (unsatisfied == null) {
        return null;
      }
      return _ContentRange(
        start: 0,
        end: -1,
        total: int.parse(unsatisfied.group(1)!),
      );
    }
    return _ContentRange(
      start: int.parse(match.group(1)!),
      end: int.parse(match.group(2)!),
      total: match.group(3) == '*' ? null : int.parse(match.group(3)!),
    );
  }
}

class _PartMetadata {
  const _PartMetadata({
    required this.url,
    this.etag,
    this.lastModified,
    this.totalLength,
  });

  final String url;
  final String? etag;
  final String? lastModified;
  final int? totalLength;

  String? get validator => etag ?? lastModified;

  Map<String, Object?> toJson() => {
        'url': url,
        'etag': etag,
        'lastModified': lastModified,
        'totalLength': totalLength,
      };
}

class _ContentRange {
  const _ContentRange({
    required this.start,
    required this.end,
    required this.total,
  });

  final int start;
  final int end;
  final int? total;
}
