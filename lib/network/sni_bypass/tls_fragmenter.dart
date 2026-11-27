import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;

/// Fragmentation mode used by [LocalSniProxy] on the initial TLS ClientHello.
enum TlsFragmentMode {
  /// Splits the first TLS Handshake record into multiple valid TLS records
  /// directly across the SNI hostname (preserves real SNI & full TLS cert check).
  tlsRecords,

  /// Keeps the first TLS Handshake record completely intact as one TLS record
  /// and splits it into multiple flushed TCP segments across the SNI hostname
  /// (for networks/middleboxes that reject multi-record ClientHello).
  tcpSegments,
}

/// Parsed metadata of a TLS ClientHello record.
@immutable
class TlsClientHelloInfo {
  const TlsClientHelloInfo({
    required this.recordMajorVersion,
    required this.recordMinorVersion,
    required this.recordPayloadLength,
    this.serverName,
    this.sniStartOffset,
    this.sniEndOffset,
  });

  final int recordMajorVersion;
  final int recordMinorVersion;
  final int recordPayloadLength;
  final String? serverName;

  /// Byte offsets of the ASCII hostname inside the full TLS record buffer
  /// (including the 5-byte TLS record header).
  final int? sniStartOffset;
  final int? sniEndOffset;

  int get totalRecordLength => 5 + recordPayloadLength;

  bool get hasSni =>
      serverName != null &&
      sniStartOffset != null &&
      sniEndOffset != null &&
      sniEndOffset! > sniStartOffset!;
}

/// Checks whether [bytes] starts with a TLS Handshake record header (`0x16 0x03`).
bool looksLikeTlsHandshakeRecord(Uint8List bytes) {
  return bytes.length >= 5 && bytes[0] == 0x16 && bytes[1] == 0x03;
}

/// Reads the expected total byte length (`5 + payloadLength`) of the first TLS
/// record in [bytes], or null if [bytes] is shorter than 5 bytes or not a TLS
/// Handshake record.
int? expectedTlsRecordLength(Uint8List bytes) {
  if (!looksLikeTlsHandshakeRecord(bytes)) {
    return null;
  }
  final payloadLen = (bytes[3] << 8) | bytes[4];
  if (payloadLen <= 0 || payloadLen > 16384 + 2048) {
    return null;
  }
  return 5 + payloadLen;
}

/// Parses a single TLS Handshake record containing a ClientHello message and
/// locates the SNI extension hostname byte range inside [bytes].
///
/// Returns null if [bytes] is not a complete TLS ClientHello record.
TlsClientHelloInfo? parseTlsClientHello(Uint8List bytes) {
  final expectedTotal = expectedTlsRecordLength(bytes);
  if (expectedTotal == null || bytes.length < expectedTotal) {
    return null;
  }
  final recordMajor = bytes[1];
  final recordMinor = bytes[2];
  final recordPayloadLen = expectedTotal - 5;

  // Handshake header starts at offset 5: type(1) + length(3)
  int pos = 5;
  if (pos + 4 > expectedTotal) {
    return null;
  }
  if (bytes[pos] != 0x01) {
    // Not ClientHello
    return null;
  }
  final hsLen =
      (bytes[pos + 1] << 16) | (bytes[pos + 2] << 8) | bytes[pos + 3];
  pos += 4;
  final hsEnd = pos + hsLen;
  if (hsEnd > expectedTotal) {
    return null;
  }

  // client_version(2) + random(32)
  if (pos + 34 > hsEnd) {
    return null;
  }
  pos += 34;

  // session_id
  if (pos + 1 > hsEnd) {
    return null;
  }
  final sessionIdLen = bytes[pos];
  pos += 1 + sessionIdLen;
  if (pos + 2 > hsEnd) {
    return null;
  }

  // cipher_suites
  final cipherSuitesLen = (bytes[pos] << 8) | bytes[pos + 1];
  pos += 2 + cipherSuitesLen;
  if (pos + 1 > hsEnd) {
    return null;
  }

  // compression_methods
  final compMethodsLen = bytes[pos];
  pos += 1 + compMethodsLen;
  if (pos == hsEnd) {
    return TlsClientHelloInfo(
      recordMajorVersion: recordMajor,
      recordMinorVersion: recordMinor,
      recordPayloadLength: recordPayloadLen,
    );
  }
  if (pos + 2 > hsEnd) {
    return null;
  }

  // extensions
  final extensionsLen = (bytes[pos] << 8) | bytes[pos + 1];
  pos += 2;
  final extensionsEnd = pos + extensionsLen;
  if (extensionsEnd > hsEnd) {
    return null;
  }

  while (pos + 4 <= extensionsEnd) {
    final extType = (bytes[pos] << 8) | bytes[pos + 1];
    final extLen = (bytes[pos + 2] << 8) | bytes[pos + 3];
    pos += 4;
    if (pos + extLen > extensionsEnd) {
      break;
    }
    if (extType == 0x0000 && extLen >= 5) {
      // server_name extension: server_name_list_length(2), name_type(1), host_name_len(2), host_name
      int sniPos = pos;
      final listLen = (bytes[sniPos] << 8) | bytes[sniPos + 1];
      sniPos += 2;
      final listEnd = sniPos + listLen;
      if (listEnd <= pos + extLen) {
        while (sniPos + 3 <= listEnd) {
          final nameType = bytes[sniPos];
          final nameLen = (bytes[sniPos + 1] << 8) | bytes[sniPos + 2];
          sniPos += 3;
          if (sniPos + nameLen > listEnd) {
            break;
          }
          if (nameType == 0x00 && nameLen > 0) {
            final hostBytes = Uint8List.sublistView(
              bytes,
              sniPos,
              sniPos + nameLen,
            );
            final host = ascii.decode(hostBytes, allowInvalid: true);
            return TlsClientHelloInfo(
              recordMajorVersion: recordMajor,
              recordMinorVersion: recordMinor,
              recordPayloadLength: recordPayloadLen,
              serverName: host,
              sniStartOffset: sniPos,
              sniEndOffset: sniPos + nameLen,
            );
          }
          sniPos += nameLen;
        }
      }
    }
    pos += extLen;
  }

  return TlsClientHelloInfo(
    recordMajorVersion: recordMajor,
    recordMinorVersion: recordMinor,
    recordPayloadLength: recordPayloadLen,
  );
}

/// Splits a TLS ClientHello record at the TLS Record Layer directly through the
/// SNI hostname so DPI middleboxes inspecting the first record cannot match the
/// plaintext SNI while every compliant TLS 1.2/1.3 server (including Cloudflare
/// and E-Hentai origins) reassembles the handshake stream transparently.
///
/// Any trailing bytes after the first TLS record are returned untouched as the
/// final chunk. Non-ClientHello inputs are returned untouched in a single chunk.
List<Uint8List> fragmentTlsClientHello(Uint8List rawBytes) {
  final info = parseTlsClientHello(rawBytes);
  if (info == null || info.recordPayloadLength < 8) {
    return <Uint8List>[rawBytes];
  }

  final payload = Uint8List.sublistView(rawBytes, 5, info.totalRecordLength);
  final splitPoints = _computePayloadSplitPoints(info);

  final chunks = <Uint8List>[];
  int start = 0;
  for (final end in splitPoints) {
    if (end <= start || end > payload.length) {
      continue;
    }
    chunks.add(
      _wrapTlsRecord(
        majorVersion: info.recordMajorVersion,
        minorVersion: info.recordMinorVersion,
        payloadSlice: Uint8List.sublistView(payload, start, end),
      ),
    );
    start = end;
  }
  if (start < payload.length) {
    chunks.add(
      _wrapTlsRecord(
        majorVersion: info.recordMajorVersion,
        minorVersion: info.recordMinorVersion,
        payloadSlice: Uint8List.sublistView(payload, start),
      ),
    );
  }

  if (rawBytes.length > info.totalRecordLength) {
    chunks.add(Uint8List.sublistView(rawBytes, info.totalRecordLength));
  }

  return chunks.isEmpty ? <Uint8List>[rawBytes] : chunks;
}

/// Splits a TLS ClientHello byte stream at the TCP segment layer WITHOUT
/// altering TLS record framing. The concatenated output is byte-for-byte
/// identical to [rawBytes], with split boundaries slicing directly across the
/// SNI hostname so `TCP_NODELAY` writes place SNI across separate TCP packets.
List<Uint8List> splitTlsClientHelloTcpSegments(Uint8List rawBytes) {
  final info = parseTlsClientHello(rawBytes);
  if (info == null || info.recordPayloadLength < 8) {
    return <Uint8List>[rawBytes];
  }

  final payloadSplits = _computePayloadSplitPoints(info);
  final rawSplits = <int>[
    for (final p in payloadSplits) 5 + p,
  ];

  final chunks = <Uint8List>[];
  int start = 0;
  for (final end in rawSplits) {
    if (end <= start || end >= rawBytes.length) {
      continue;
    }
    chunks.add(Uint8List.sublistView(rawBytes, start, end));
    start = end;
  }
  if (start < rawBytes.length) {
    chunks.add(Uint8List.sublistView(rawBytes, start));
  }
  return chunks.isEmpty ? <Uint8List>[rawBytes] : chunks;
}

List<int> _computePayloadSplitPoints(TlsClientHelloInfo info) {
  final payloadLen = info.recordPayloadLength;
  final splitPoints = <int>[];

  if (info.hasSni) {
    final sniStart = info.sniStartOffset! - 5;
    final sniEnd = info.sniEndOffset! - 5;
    final sniLen = sniEnd - sniStart;

    // Split early in the hostname and again past the midpoint so no single
    // segment carries the full domain name.
    final cut1 = sniStart + (sniLen >= 4 ? 2 : 1);
    final cut2 = sniStart + (sniLen ~/ 2) + 1;
    if (cut1 > 0 && cut1 < payloadLen) {
      splitPoints.add(cut1);
    }
    if (cut2 > cut1 && cut2 < payloadLen) {
      splitPoints.add(cut2);
    }
  } else {
    final mid = payloadLen ~/ 2;
    if (mid > 0 && mid < payloadLen) {
      splitPoints.add(mid);
    }
  }

  return splitPoints;
}

Uint8List _wrapTlsRecord({
  required int majorVersion,
  required int minorVersion,
  required Uint8List payloadSlice,
}) {
  final out = Uint8List(5 + payloadSlice.length);
  out[0] = 0x16; // Handshake
  out[1] = majorVersion;
  out[2] = minorVersion;
  out[3] = (payloadSlice.length >> 8) & 0xFF;
  out[4] = payloadSlice.length & 0xFF;
  out.setRange(5, out.length, payloadSlice);
  return out;
}
