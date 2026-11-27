import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:eros_fe/network/sni_bypass/sni_bypass_models.dart';

/// Maximum byte size accepted for a single DoH response (JSON or RFC 8484 wire).
const int kMaxDohResponseBytes = 64 * 1024;

/// Maximum byte size accepted for a synced DoH catalog JSON payload.
const int kMaxCatalogResponseBytes = 512 * 1024;

/// Reads all bytes from [stream] up to [maxBytes], throwing [FormatException]
/// immediately and canceling the stream subscription if the limit is exceeded.
Future<Uint8List> readBoundedBytes(
  Stream<List<int>> stream, {
  required int maxBytes,
  required Duration timeout,
}) async {
  final builder = BytesBuilder(copy: false);
  final iterator = StreamIterator<List<int>>(stream);
  final deadline = DateTime.now().add(timeout);
  try {
    while (true) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        throw TimeoutException('Response body read timed out');
      }
      final hasNext = await iterator.moveNext().timeout(remaining);
      if (!hasNext) {
        break;
      }
      final chunk = iterator.current;
      if (builder.length + chunk.length > maxBytes) {
        throw FormatException('Response exceeds $maxBytes bytes limit');
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  } finally {
    await iterator.cancel();
  }
}

/// Result of a single DoH A-record query.
class DohQueryResponse {
  const DohQueryResponse({
    required this.ips,
    required this.minTtlSeconds,
    required this.latencyMs,
  });

  final List<String> ips;
  final int minTtlSeconds;
  final int latencyMs;
}

/// Pure Dart DNS-over-HTTPS client supporting both JSON (`application/dns-json`)
/// and RFC 8484 wire format (`application/dns-message`), with direct bootstrap
/// IP connection via `HttpClient.connectionFactory` so DoH itself bypasses local
/// DNS poisoning while still validating the DoH server's TLS certificate.
class DohClient {
  DohClient({
    this.timeout = const Duration(seconds: 6),
    this.proxyDirectiveProvider,
  });

  final Duration timeout;

  /// Optional proxy directive (e.g. `PROXY 127.0.0.1:port`) used when querying
  /// DoH servers whose own SNI might be blocked on direct connections.
  final String? Function(String host)? proxyDirectiveProvider;

  /// Queries IPv4 `A` records for [domain] via [server].
  ///
  /// Throws [TimeoutException] on timeout or [HttpException]/[SocketException]
  /// on transport failure.
  Future<DohQueryResponse> resolveA(
    DohServerConfig server,
    String domain, {
    Duration? requestTimeout,
  }) async {
    final uri = server.uri;
    if (!isPermittedDohUrl(uri)) {
      throw FormatException('Disallowed or invalid DoH URL: ${server.url}');
    }
    final validUri = uri!;

    final effectiveTimeout = requestTimeout ?? timeout;
    final sw = Stopwatch()..start();

    // Try JSON API first (fast, lightweight), fall back to RFC 8484 binary DNS
    // when server rejects JSON with 400/406/415/404.
    try {
      final jsonUri = validUri.replace(
        queryParameters: <String, String>{
          ...validUri.queryParameters,
          'name': domain,
          'type': 'A',
        },
      );
      final body = await _fetchBytes(
        server: server,
        requestUri: jsonUri,
        accept: 'application/dns-json',
        requestTimeout: effectiveTimeout,
      );
      sw.stop();
      final parsed = parseDnsJsonResponse(utf8.decode(body));
      if (parsed.ips.isNotEmpty) {
        return DohQueryResponse(
          ips: parsed.ips,
          minTtlSeconds: parsed.minTtlSeconds,
          latencyMs: sw.elapsedMilliseconds,
        );
      }
    } on _UnsupportedJsonDohException {
      // Fall through to RFC 8484 wire format below.
    } on FormatException {
      // Some endpoints ignore Accept: application/dns-json and return binary or HTML.
    }

    final wireQuery = encodeDnsAQuery(domain);
    final b64 = base64UrlEncode(wireQuery).replaceAll('=', '');
    final wireUri = validUri.replace(
      queryParameters: <String, String>{
        ...validUri.queryParameters,
        'dns': b64,
      },
    );
    final wireBody = await _fetchBytes(
      server: server,
      requestUri: wireUri,
      accept: 'application/dns-message',
      requestTimeout: effectiveTimeout,
    );
    sw.stop();
    final parsed = decodeDnsAResponse(wireBody, expectedDomain: domain);
    return DohQueryResponse(
      ips: parsed.ips,
      minTtlSeconds: parsed.minTtlSeconds,
      latencyMs: sw.elapsedMilliseconds,
    );
  }

  /// Probes [server] by resolving `e-hentai.org` and `exhentai.org` to measure
  /// real latency and detect DNS pollution.
  Future<DohProbeResult> probeServer(
    DohServerConfig server, {
    Duration requestTimeout = const Duration(seconds: 5),
  }) async {
    final now = DateTime.now();
    try {
      final ehFuture = resolveA(
        server,
        'e-hentai.org',
        requestTimeout: requestTimeout,
      );
      final exFuture = resolveA(
        server,
        'exhentai.org',
        requestTimeout: requestTimeout,
      );
      final results =
          await Future.wait<DohQueryResponse>(<Future<DohQueryResponse>>[
        ehFuture,
        exFuture,
      ]);

      final ehRes = results[0];
      final exRes = results[1];
      final avgMs = ((ehRes.latencyMs + exRes.latencyMs) / 2).round();
      final allIps = <String>{...ehRes.ips, ...exRes.ips}.toList();

      if (ehRes.ips.isEmpty || exRes.ips.isEmpty) {
        return DohProbeResult(
          serverId: server.id,
          status: ProbeStatus.error,
          latencyMs: avgMs,
          detail: 'Empty DNS answer',
          testedAt: now,
        );
      }

      final hasPoisoned = allIps.any(isLikelyPoisonedEhIp);
      if (hasPoisoned) {
        return DohProbeResult(
          serverId: server.id,
          status: ProbeStatus.polluted,
          latencyMs: avgMs,
          resolvedIps: allIps,
          detail: 'Suspected polluted IP: ${allIps.join(', ')}',
          testedAt: now,
        );
      }

      return DohProbeResult(
        serverId: server.id,
        status: ProbeStatus.ok,
        latencyMs: avgMs,
        resolvedIps: allIps,
        testedAt: now,
      );
    } on TimeoutException {
      return DohProbeResult(
        serverId: server.id,
        status: ProbeStatus.timeout,
        testedAt: now,
      );
    } on SocketException catch (e) {
      final lower = e.message.toLowerCase();
      final isTimeout = lower.contains('timed out') || lower.contains('timeout');
      return DohProbeResult(
        serverId: server.id,
        status: isTimeout ? ProbeStatus.timeout : ProbeStatus.error,
        detail: e.message,
        testedAt: now,
      );
    } catch (e) {
      return DohProbeResult(
        serverId: server.id,
        status: ProbeStatus.error,
        detail: '$e',
        testedAt: now,
      );
    }
  }

  Future<Uint8List> _fetchBytes({
    required DohServerConfig server,
    required Uri requestUri,
    required String accept,
    required Duration requestTimeout,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = requestTimeout
      // Always enforce strict OS TLS certificate verification even if a global
      // HttpOverrides installed a permissive callback.
      ..badCertificateCallback = null;
    try {
      final proxyDirective = proxyDirectiveProvider?.call(requestUri.host);
      final publicBootstrap =
          server.bootstrapIps.where(isValidPublicIpv4).toList();
      if (proxyDirective != null && proxyDirective.isNotEmpty) {
        client.findProxy = (_) => proxyDirective;
      } else {
        client.findProxy = (_) => 'DIRECT';
        client.connectionFactory = (
          Uri targetUri,
          String? proxyHost,
          int? proxyPort,
        ) async {
          final targetPort = targetUri.hasPort ? targetUri.port : 443;
          if (targetPort != 443) {
            throw SocketException('Disallowed DoH port: $targetPort');
          }
          final List<String> candidateIps;
          if (publicBootstrap.isNotEmpty &&
              parseIpv4Octets(targetUri.host) == null) {
            candidateIps = publicBootstrap;
          } else if (parseIpv4Octets(targetUri.host) != null) {
            if (!isValidPublicIpv4(targetUri.host)) {
              throw SocketException(
                'Disallowed non-public DoH IP: ${targetUri.host}',
              );
            }
            candidateIps = <String>[targetUri.host];
          } else {
            final resolved = await InternetAddress.lookup(
              targetUri.host,
              type: InternetAddressType.IPv4,
            ).timeout(requestTimeout);
            candidateIps = resolved
                .map((a) => a.address)
                .where(isValidPublicIpv4)
                .toList();
            if (candidateIps.isEmpty) {
              throw SocketException(
                'DoH host ${targetUri.host} resolved to no public IPv4 addresses',
              );
            }
          }
          return _connectWithBootstrapIps(
            bootstrapIps: candidateIps,
            tlsHost: targetUri.host,
            port: targetPort,
            timeout: requestTimeout,
          );
        };
      }

      final req = await client.getUrl(requestUri).timeout(requestTimeout);
      req.headers.set(HttpHeaders.acceptHeader, accept);
      req.headers.set(HttpHeaders.userAgentHeader, 'Eros-FE/DoH');
      final resp = await req.close().timeout(requestTimeout);
      final bytes = await readBoundedBytes(
        resp,
        maxBytes: kMaxDohResponseBytes,
        timeout: requestTimeout,
      );

      if (resp.statusCode == 400 ||
          resp.statusCode == 404 ||
          resp.statusCode == 406 ||
          resp.statusCode == 415) {
        if (accept == 'application/dns-json') {
          throw const _UnsupportedJsonDohException();
        }
      }
      if (resp.statusCode != 200) {
        throw HttpException(
          'DoH HTTP ${resp.statusCode}',
          uri: requestUri,
        );
      }
      return bytes;
    } finally {
      client.close(force: true);
    }
  }

  Future<ConnectionTask<Socket>> _connectWithBootstrapIps({
    required List<String> bootstrapIps,
    required String tlsHost,
    required int port,
    required Duration timeout,
  }) async {
    Object? lastError;
    for (final ip in bootstrapIps) {
      if (!isValidPublicIpv4(ip)) {
        continue;
      }
      Socket? rawSocket;
      try {
        final rawTask = await Socket.startConnect(ip, port);
        rawSocket = await rawTask.socket.timeout(
          timeout,
          onTimeout: () {
            rawTask.cancel();
            throw TimeoutException('DoH TCP connect timeout to $ip:$port');
          },
        );
        try {
          rawSocket.setOption(SocketOption.tcpNoDelay, true);
        } catch (_) {}
        final secureSocket = await SecureSocket.secure(
          rawSocket,
          host: tlsHost,
        ).timeout(timeout);
        return ConnectionTask.fromSocket<Socket>(
          Future<Socket>.value(secureSocket),
          () {
            rawTask.cancel();
            secureSocket.destroy();
          },
        );
      } catch (e) {
        rawSocket?.destroy();
        lastError = e;
      }
    }
    throw lastError ?? SocketException('Failed to connect to DoH $tlsHost');
  }
}

class _UnsupportedJsonDohException implements Exception {
  const _UnsupportedJsonDohException();
}

/// Parses a `application/dns-json` payload (Cloudflare / Google / DNS.SB / DNSPod).
({List<String> ips, int minTtlSeconds}) parseDnsJsonResponse(String body) {
  final dynamic decoded = jsonDecode(body);
  if (decoded is! Map) {
    throw const FormatException('DNS JSON root is not an object');
  }
  final status = decoded['Status'];
  if (status is int && status != 0) {
    return (ips: const <String>[], minTtlSeconds: 300);
  }
  final answer = decoded['Answer'];
  if (answer is! List) {
    return (ips: const <String>[], minTtlSeconds: 300);
  }
  final ips = <String>[];
  int minTtl = 3600;
  for (final item in answer) {
    if (item is! Map) {
      continue;
    }
    final type = item['type'];
    final data = item['data'];
    if (type == 1 && data is String && isValidPublicIpv4(data.trim())) {
      final ip = data.trim();
      if (!ips.contains(ip)) {
        ips.add(ip);
      }
      final ttl = item['TTL'];
      if (ttl is int && ttl > 0 && ttl < minTtl) {
        minTtl = ttl;
      }
    }
  }
  return (ips: ips, minTtlSeconds: minTtl.clamp(60, 3600));
}

/// Encodes a standard RFC 1035 DNS A-record query packet (used by RFC 8484 DoH).
Uint8List encodeDnsAQuery(String domain) {
  final labels = _normalizeDnsName(domain)
      .split('.')
      .where((label) => label.isNotEmpty)
      .toList();
  if (labels.isEmpty) {
    throw FormatException('Invalid DNS domain: $domain');
  }
  final builder = BytesBuilder(copy: false);
  // Header: ID=0x0000, Flags=0x0100 (RD=1), QDCOUNT=1, AN/NS/AR=0
  builder.add(<int>[
    0x00, 0x00,
    0x01, 0x00,
    0x00, 0x01,
    0x00, 0x00,
    0x00, 0x00,
    0x00, 0x00,
  ]);
  for (final label in labels) {
    final encoded = ascii.encode(label);
    if (encoded.length > 63) {
      throw FormatException('DNS label too long: $label');
    }
    builder.addByte(encoded.length);
    builder.add(encoded);
  }
  builder.addByte(0x00); // root label
  builder.add(<int>[0x00, 0x01]); // QTYPE = A (1)
  builder.add(<int>[0x00, 0x01]); // QCLASS = IN (1)
  return builder.takeBytes();
}

/// Decodes and strictly validates IPv4 A records and minimum TTL from an
/// RFC 1035 DNS wire response.
///
/// Validates QR=1, TC=0, RCODE=0, question section domain/QTYPE/QCLASS match
/// (when [expectedDomain] is supplied), safe compression pointers, and CNAME/A
/// answer name linkage.
({List<String> ips, int minTtlSeconds}) decodeDnsAResponse(
  Uint8List packet, {
  String? expectedDomain,
}) {
  if (packet.length < 12) {
    throw const FormatException('DNS wire packet too short');
  }
  final flags1 = packet[2];
  final flags2 = packet[3];
  final isResponse = (flags1 & 0x80) != 0;
  final isTruncated = (flags1 & 0x02) != 0;
  final rcode = flags2 & 0x0F;
  if (!isResponse) {
    throw const FormatException('DNS wire packet is not a response (QR=0)');
  }
  if (isTruncated) {
    throw const FormatException('DNS wire response is truncated (TC=1)');
  }
  if (rcode != 0) {
    return (ips: const <String>[], minTtlSeconds: 300);
  }

  final qdCount = (packet[4] << 8) | packet[5];
  final anCount = (packet[6] << 8) | packet[7];
  if (qdCount != 1) {
    throw FormatException('Unexpected DNS question count: $qdCount');
  }

  int offset = 12;
  final question = _readDnsName(packet, offset);
  offset = question.nextOffset;
  if (offset + 4 > packet.length) {
    throw const FormatException('Truncated DNS question section');
  }
  final qType = (packet[offset] << 8) | packet[offset + 1];
  final qClass = (packet[offset + 2] << 8) | packet[offset + 3];
  offset += 4;
  if (qType != 1 || qClass != 1) {
    throw FormatException('Unexpected DNS question type/class: $qType/$qClass');
  }

  final normalizedExpected = expectedDomain == null
      ? question.name
      : _normalizeDnsName(expectedDomain);
  if (question.name != normalizedExpected) {
    throw FormatException(
      'DNS question mismatch: expected $normalizedExpected, got ${question.name}',
    );
  }

  // Track owner names valid for A records (starts with expected domain and
  // expands along verified CNAME hops).
  final allowedOwners = <String>{normalizedExpected};
  final rawARecords = <({String owner, String ip, int ttl})>[];
  final cnames = <String, String>{};

  for (int i = 0; i < anCount; i++) {
    if (offset >= packet.length) {
      throw const FormatException('Truncated DNS answer section');
    }
    final owner = _readDnsName(packet, offset);
    offset = owner.nextOffset;
    if (offset + 10 > packet.length) {
      throw const FormatException('Truncated DNS answer RR header');
    }
    final type = (packet[offset] << 8) | packet[offset + 1];
    final rrClass = (packet[offset + 2] << 8) | packet[offset + 3];
    final ttl = (packet[offset + 4] << 24) |
        (packet[offset + 5] << 16) |
        (packet[offset + 6] << 8) |
        packet[offset + 7];
    final rdLength = (packet[offset + 8] << 8) | packet[offset + 9];
    offset += 10;
    if (offset + rdLength > packet.length) {
      throw const FormatException('Truncated DNS answer RDATA');
    }

    if (rrClass == 1 && type == 5) {
      // CNAME record
      final target = _readDnsName(packet, offset);
      if (target.nextOffset != offset + rdLength) {
        throw const FormatException('Malformed CNAME RDATA length');
      }
      cnames[owner.name] = target.name;
    } else if (rrClass == 1 && type == 1) {
      if (rdLength != 4) {
        throw FormatException('Invalid A-record RDLENGTH: $rdLength');
      }
      final ip =
          '${packet[offset]}.${packet[offset + 1]}.${packet[offset + 2]}.${packet[offset + 3]}';
      rawARecords.add((owner: owner.name, ip: ip, ttl: ttl));
    }
    offset += rdLength;
  }

  // Expand CNAME chain starting from normalizedExpected (bounded hops).
  String cursor = normalizedExpected;
  for (int hop = 0; hop < 8; hop++) {
    final next = cnames[cursor];
    if (next == null || !allowedOwners.add(next)) {
      break;
    }
    cursor = next;
  }

  final ips = <String>[];
  int minTtl = 3600;
  for (final rec in rawARecords) {
    if (!allowedOwners.contains(rec.owner)) {
      continue;
    }
    if (!isValidPublicIpv4(rec.ip)) {
      continue;
    }
    if (!ips.contains(rec.ip)) {
      ips.add(rec.ip);
    }
    if (rec.ttl > 0 && rec.ttl < minTtl) {
      minTtl = rec.ttl;
    }
  }

  return (ips: ips, minTtlSeconds: minTtl.clamp(60, 3600));
}

String _normalizeDnsName(String name) {
  var trimmed = name.trim().toLowerCase();
  while (trimmed.endsWith('.')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}

({String name, int nextOffset}) _readDnsName(Uint8List packet, int start) {
  final labels = <String>[];
  int pos = start;
  int? nextOffsetAfterPointer;
  final visitedOffsets = <int>{};
  int labelGuard = 0;

  while (pos < packet.length && labelGuard++ < 128) {
    final len = packet[pos];
    if (len == 0) {
      return (
        name: labels.join('.').toLowerCase(),
        nextOffset: nextOffsetAfterPointer ?? (pos + 1),
      );
    }
    if ((len & 0xC0) == 0xC0) {
      if (pos + 2 > packet.length) {
        throw const FormatException('Truncated DNS compression pointer');
      }
      final ptr = ((len & 0x3F) << 8) | packet[pos + 1];
      if (ptr >= packet.length || ptr >= pos || !visitedOffsets.add(ptr)) {
        throw FormatException('Invalid DNS compression pointer: $ptr');
      }
      nextOffsetAfterPointer ??= pos + 2;
      pos = ptr;
      continue;
    }
    if ((len & 0xC0) != 0) {
      throw FormatException('Unsupported DNS label type: $len');
    }
    if (pos + 1 + len > packet.length) {
      throw const FormatException('Truncated DNS label');
    }
    labels.add(ascii.decode(Uint8List.sublistView(packet, pos + 1, pos + 1 + len)));
    pos += 1 + len;
  }
  throw const FormatException('Malformed or cyclic DNS name');
}
