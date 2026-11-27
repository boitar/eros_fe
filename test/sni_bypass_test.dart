import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/common/service/dns_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/sni_bypass_service.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/network/app_dio/app_dio.dart';
import 'package:eros_fe/network/app_dio/proxy.dart';
import 'package:eros_fe/network/sni_bypass/doh_client.dart';
import 'package:eros_fe/network/sni_bypass/local_sni_proxy.dart';
import 'package:eros_fe/network/sni_bypass/sni_bypass_models.dart';
import 'package:eros_fe/network/sni_bypass/tls_fragmenter.dart';
import 'package:eros_fe/pages/setting/sni_bypass_page.dart';
import 'package:eros_fe/pages/tab/controller/setting_controller.dart';
import 'package:eros_fe/pages/tab/view/setting_page.dart';
import 'package:eros_fe/utils/http_override.dart';
import 'package:eros_fe/widget/soft_status_indicator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'support/waterfall_fixture.dart';

/// Builds a valid RFC 5246/8446 TLS Record containing a ClientHello with SNI.
Uint8List _buildClientHelloRecord(
  String sniHost, {
  List<int> trailing = const <int>[],
}) {
  final hostBytes = ascii.encode(sniHost);

  final sniEntryLen = 1 + 2 + hostBytes.length;
  final sniExtDataLen = 2 + sniEntryLen;
  final sniExt = BytesBuilder()
    ..add(<int>[0x00, 0x00])
    ..add(<int>[(sniExtDataLen >> 8) & 0xFF, sniExtDataLen & 0xFF])
    ..add(<int>[(sniEntryLen >> 8) & 0xFF, sniEntryLen & 0xFF])
    ..addByte(0x00)
    ..add(<int>[(hostBytes.length >> 8) & 0xFF, hostBytes.length & 0xFF])
    ..add(hostBytes);

  final ext2 = <int>[0x00, 0x2B, 0x00, 0x03, 0x02, 0x03, 0x04];
  final allExts = BytesBuilder()
    ..add(sniExt.takeBytes())
    ..add(ext2);
  final allExtsBytes = allExts.takeBytes();

  final body = BytesBuilder()
    ..add(<int>[0x03, 0x03])
    ..add(List<int>.filled(32, 0xAB))
    ..addByte(0x00)
    ..add(<int>[0x00, 0x04, 0x13, 0x01, 0x13, 0x02])
    ..add(<int>[0x01, 0x00])
    ..add(<int>[(allExtsBytes.length >> 8) & 0xFF, allExtsBytes.length & 0xFF])
    ..add(allExtsBytes);
  final bodyBytes = body.takeBytes();

  final handshake = BytesBuilder()
    ..addByte(0x01)
    ..add(<int>[
      (bodyBytes.length >> 16) & 0xFF,
      (bodyBytes.length >> 8) & 0xFF,
      bodyBytes.length & 0xFF,
    ])
    ..add(bodyBytes);
  final hsBytes = handshake.takeBytes();

  final record = BytesBuilder()
    ..add(<int>[0x16, 0x03, 0x01])
    ..add(<int>[(hsBytes.length >> 8) & 0xFF, hsBytes.length & 0xFF])
    ..add(hsBytes)
    ..add(trailing);
  return record.takeBytes();
}

({List<Uint8List> recordPayloads, Uint8List trailing}) _parseTlsRecords(
  List<Uint8List> chunks,
) {
  final combined = BytesBuilder();
  chunks.forEach(combined.add);
  final all = combined.takeBytes();
  final payloads = <Uint8List>[];
  int pos = 0;
  while (pos + 5 <= all.length && all[pos] == 0x16 && all[pos + 1] == 0x03) {
    final len = (all[pos + 3] << 8) | all[pos + 4];
    if (pos + 5 + len > all.length) {
      break;
    }
    payloads.add(Uint8List.sublistView(all, pos + 5, pos + 5 + len));
    pos += 5 + len;
  }
  return (
    recordPayloads: payloads,
    trailing: Uint8List.sublistView(all, pos),
  );
}

Uint8List _encodeWireLabels(String domain) {
  final b = BytesBuilder();
  for (final label in domain.split('.')) {
    final raw = ascii.encode(label);
    b.addByte(raw.length);
    b.add(raw);
  }
  b.addByte(0x00);
  return b.takeBytes();
}

class _StubDnsService extends DnsService {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _PassThroughHttpOverrides extends HttpOverrides {}

void main() {
  group('TLS ClientHello Parser, Record Fragmenter & TCP Segmenter', () {
    test('parses SNI and splits record directly through hostname', () {
      const host = 'e-hentai.org';
      final trailing = <int>[0x14, 0x03, 0x03, 0x00, 0x01, 0x01];
      final raw = _buildClientHelloRecord(host, trailing: trailing);

      final parsed = parseTlsClientHello(raw);
      expect(parsed, isNotNull);
      expect(parsed!.serverName, host);
      expect(parsed.sniStartOffset, greaterThan(5));
      expect(parsed.sniEndOffset, parsed.sniStartOffset! + host.length);

      final fragments = fragmentTlsClientHello(raw);
      expect(fragments.length, greaterThanOrEqualTo(3));

      final inspected = _parseTlsRecords(fragments);
      expect(inspected.recordPayloads.length, greaterThanOrEqualTo(2));
      for (final payload in inspected.recordPayloads) {
        expect(latin1.decode(payload).contains(host), isFalse);
      }

      final reassembled = BytesBuilder();
      inspected.recordPayloads.forEach(reassembled.add);
      final originalPayload = Uint8List.sublistView(
        raw,
        5,
        5 + parsed.recordPayloadLength,
      );
      expect(reassembled.takeBytes(), originalPayload);
      expect(inspected.trailing, Uint8List.fromList(trailing));
    });

    test('TCP segment splitter preserves exact single TLS record while splitting SNI', () {
      const host = 'exhentai.org';
      final raw = _buildClientHelloRecord(host);

      final segments = splitTlsClientHelloTcpSegments(raw);
      expect(segments.length, greaterThanOrEqualTo(3));
      for (final seg in segments) {
        expect(latin1.decode(seg).contains(host), isFalse);
      }
      final reassembled = BytesBuilder();
      segments.forEach(reassembled.add);
      expect(reassembled.takeBytes(), raw);
    });

    test('passes through non-TLS and truncated payloads untouched', () {
      final httpReq = Uint8List.fromList(ascii.encode('GET / HTTP/1.1\r\n\r\n'));
      expect(parseTlsClientHello(httpReq), isNull);
      expect(fragmentTlsClientHello(httpReq), <Uint8List>[httpReq]);
      expect(splitTlsClientHelloTcpSegments(httpReq), <Uint8List>[httpReq]);

      final full = _buildClientHelloRecord('exhentai.org');
      final truncated = Uint8List.sublistView(full, 0, 20);
      expect(parseTlsClientHello(truncated), isNull);
      expect(fragmentTlsClientHello(truncated), <Uint8List>[truncated]);
    });
  });

  group('DoH Models, Pollution Detection, Bounded Reader & Strict Wire Codec', () {
    test('detects Fake-IP, private/reserved IPs, and poisoned EH IPs', () {
      expect(isFakeIpAddress('198.18.0.1'), isTrue);
      expect(isFakeIpAddress('198.19.255.254'), isTrue);
      expect(isFakeIpAddress('198.17.255.255'), isFalse);
      expect(isFakeIpAddress('198.20.0.1'), isFalse);
      expect(isFakeIpAddress('172.66.132.196'), isFalse);

      expect(isLikelyPoisonedEhIp('66.220.148.145'), isTrue);
      expect(isLikelyPoisonedEhIp('199.59.149.136'), isTrue);
      expect(isLikelyPoisonedEhIp('199.96.57.6'), isTrue);
      expect(isLikelyPoisonedEhIp('202.160.128.1'), isTrue);
      expect(isLikelyPoisonedEhIp('127.0.0.1'), isTrue);
      expect(isLikelyPoisonedEhIp('198.18.0.42'), isTrue);

      expect(isLikelyPoisonedEhIp('172.66.132.196'), isFalse);
      expect(isLikelyPoisonedEhIp('104.21.56.202'), isFalse);
      expect(isLikelyPoisonedEhIp('178.175.128.254'), isFalse);
    });

    test('filters private bootstrap IPs and poisoned fallbackHosts in JSON parsing', () {
      final server = DohServerConfig.fromJson(const <String, dynamic>{
        'id': 'test',
        'name': 'Test',
        'url': 'https://doh.example/dns-query',
        'bootstrapIps': <String>[
          '127.0.0.1',
          '10.0.0.1',
          '192.168.1.1',
          '169.254.169.254',
          '198.18.0.1',
          '1.1.1.1',
        ],
      });
      expect(server.bootstrapIps, <String>['1.1.1.1']);

      final snap = DohCatalogSnapshot.fromJson(<String, dynamic>{
        'version': 1,
        'servers': <Map<String, dynamic>>[
          server.toJson(),
          const <String, dynamic>{
            'id': 'evil-local',
            'name': 'Loopback',
            'url': 'https://127.0.0.1/dns-query',
          },
          const <String, dynamic>{
            'id': 'evil-cgnat',
            'name': 'CGNAT',
            'url': 'https://100.64.0.1/dns-query',
          },
        ],
        'fallbackHosts': const <String, List<String>>{
          'e-hentai.org': <String>[
            '66.220.148.145', // poisoned
            '127.0.0.1', // loopback
            '172.66.132.196', // valid
          ],
        },
      });
      expect(snap.servers.map((s) => s.id).toList(), <String>['test']);
      expect(snap.fallbackHosts['e-hentai.org'], <String>['172.66.132.196']);

      expect(isPermittedDohUrl(Uri.parse('https://1.1.1.1/dns-query')), isTrue);
      expect(isPermittedDohUrl(Uri.parse('https://dns.google/resolve')), isTrue);
      expect(isPermittedDohUrl(Uri.parse('https://127.0.0.1/dns-query')), isFalse);
      expect(isPermittedDohUrl(Uri.parse('https://10.0.0.1/dns-query')), isFalse);
      expect(isPermittedDohUrl(Uri.parse('https://100.64.0.1/dns-query')), isFalse);
      expect(isPermittedDohUrl(Uri.parse('https://localhost/dns-query')), isFalse);
      expect(isPermittedDohUrl(Uri.parse('https://[::1]/dns-query')), isFalse);
      expect(isPermittedDohUrl(Uri.parse('https://dns.google:8443/resolve')), isFalse);
    });

    test('matches managed E-Hentai domains accurately', () {
      expect(SniBypassDefaults.isManagedDomain('e-hentai.org'), isTrue);
      expect(SniBypassDefaults.isManagedDomain('api.e-hentai.org'), isTrue);
      expect(SniBypassDefaults.isManagedDomain('exhentai.org'), isTrue);
      expect(SniBypassDefaults.isManagedDomain('s.exhentai.org'), isTrue);
      expect(SniBypassDefaults.isManagedDomain('ehgt.org'), isTrue);
      expect(SniBypassDefaults.isManagedDomain('evil-e-hentai.org'), isFalse);
      expect(SniBypassDefaults.isManagedDomain('google.com'), isFalse);
    });

    test('encodes RFC 1035 A query and decodes compressed A + CNAME responses', () {
      final query = encodeDnsAQuery('e-hentai.org');
      expect(query.length, greaterThan(16));
      expect(query[2], 0x01);
      expect(query[5], 0x01);

      final resp = BytesBuilder()
        ..add(<int>[0x00, 0x00, 0x81, 0x80, 0x00, 0x01, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00])
        ..add(Uint8List.sublistView(query, 12))
        ..add(<int>[0xC0, 0x0C, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x78, 0x00, 0x04, 172, 66, 132, 196])
        ..add(<int>[0xC0, 0x0C, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x01, 0x2C, 0x00, 0x04, 172, 66, 140, 62]);

      final decoded = decodeDnsAResponse(
        resp.takeBytes(),
        expectedDomain: 'e-hentai.org',
      );
      expect(decoded.ips, <String>['172.66.132.196', '172.66.140.62']);
      expect(decoded.minTtlSeconds, 120);

      // CNAME chain: e-hentai.org -> edge.eh.net -> 172.66.132.196 (plus unrelated evil.com A record ignored)
      final cnameTarget = _encodeWireLabels('edge.eh.net');
      final evilOwner = _encodeWireLabels('evil.com');
      final cnameResp = BytesBuilder()
        ..add(<int>[0x00, 0x00, 0x81, 0x80, 0x00, 0x01, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00])
        ..add(Uint8List.sublistView(query, 12))
        // CNAME: e-hentai.org -> edge.eh.net
        ..add(<int>[0xC0, 0x0C, 0x00, 0x05, 0x00, 0x01, 0x00, 0x00, 0x00, 0x90, 0x00, cnameTarget.length])
        ..add(cnameTarget)
        // A for edge.eh.net
        ..add(cnameTarget)
        ..add(<int>[0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x80, 0x00, 0x04, 172, 66, 132, 196])
        // Unrelated A for evil.com (must be ignored)
        ..add(evilOwner)
        ..add(<int>[0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x80, 0x00, 0x04, 1, 2, 3, 4]);

      final cnameDecoded = decodeDnsAResponse(
        cnameResp.takeBytes(),
        expectedDomain: 'e-hentai.org',
      );
      expect(cnameDecoded.ips, <String>['172.66.132.196']);
    });

    test('rejects malformed, mismatched, non-response, and cyclic DNS wire packets', () {
      final query = encodeDnsAQuery('e-hentai.org');
      // QR=0 (query, not response)
      expect(
        () => decodeDnsAResponse(query, expectedDomain: 'e-hentai.org'),
        throwsFormatException,
      );

      // RCODE=3 (NXDOMAIN) returns empty cleanly
      final nxdomain = BytesBuilder()
        ..add(<int>[0x00, 0x00, 0x81, 0x83, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        ..add(Uint8List.sublistView(query, 12));
      expect(
        decodeDnsAResponse(nxdomain.takeBytes(), expectedDomain: 'e-hentai.org').ips,
        isEmpty,
      );

      // Mismatched question domain rejected
      final validResp = BytesBuilder()
        ..add(<int>[0x00, 0x00, 0x81, 0x80, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00])
        ..add(Uint8List.sublistView(query, 12))
        ..add(<int>[0xC0, 0x0C, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x78, 0x00, 0x04, 172, 66, 132, 196]);
      expect(
        () => decodeDnsAResponse(
          validResp.takeBytes(),
          expectedDomain: 'exhentai.org',
        ),
        throwsFormatException,
      );

      // Self-referencing compression pointer in question rejected
      final cyclic = Uint8List.fromList(<int>[
        0x00, 0x00, 0x81, 0x80, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0xC0, 0x0C, 0x00, 0x01, 0x00, 0x01,
      ]);
      expect(
        () => decodeDnsAResponse(cyclic, expectedDomain: 'e-hentai.org'),
        throwsFormatException,
      );
    });

    test('parses application/dns-json, rejects non-zero Status, and enforces byte caps', () async {
      const payload = '{"Status":0,"Answer":['
          '{"name":"e-hentai.org","type":1,"TTL":15,"data":"172.66.132.196"},'
          '{"name":"e-hentai.org","type":1,"TTL":240,"data":"127.0.0.1"},'
          '{"name":"e-hentai.org","type":1,"TTL":240,"data":"172.66.140.62"}'
          ']}';
      final parsed = parseDnsJsonResponse(payload);
      expect(parsed.ips, <String>['172.66.132.196', '172.66.140.62']);
      expect(parsed.minTtlSeconds, 60);

      const nxJson = '{"Status":3,"Answer":[{"type":1,"TTL":60,"data":"1.2.3.4"}]}';
      expect(parseDnsJsonResponse(nxJson).ips, isEmpty);

      // Oversized stream rejected immediately
      final hugeStream = Stream<List<int>>.fromIterable(<List<int>>[
        Uint8List(64),
        Uint8List(64),
        Uint8List(64),
      ]);
      await expectLater(
        readBoundedBytes(
          hugeStream,
          maxBytes: 100,
          timeout: const Duration(seconds: 2),
        ),
        throwsFormatException,
      );
    });
  });

  group('LocalSniProxy Loopback End-to-End & Security Guards', () {
    test('handles fragmented TCP arrival and splits ClientHello across TLS records', () async {
      final upstream = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(upstream.close);

      final receivedByUpstream = <Uint8List>[];
      final upstreamDone = Completer<void>();

      upstream.listen((Socket serverSock) {
        serverSock.listen(
          (Uint8List chunk) {
            receivedByUpstream.add(Uint8List.fromList(chunk));
            final total = receivedByUpstream.fold<int>(0, (s, b) => s + b.length);
            if (total >= 80 && !upstreamDone.isCompleted) {
              serverSock.add(ascii.encode('UPSTREAM_OK'));
              serverSock.flush().then((_) => serverSock.close());
              upstreamDone.complete();
            }
          },
          onError: (_) {},
        );
      });

      final proxy = LocalSniProxy(
        resolveIps: (String host) async => <String>['127.0.0.1'],
        isHostAllowed: (String host) => host == 'e-hentai.org',
        allowedPorts: <int>{upstream.port},
        allowLoopbackTargets: true,
      );
      await proxy.start();
      addTearDown(proxy.stop);

      final client = await Socket.connect(InternetAddress.loopbackIPv4, proxy.port!);
      addTearDown(client.destroy);

      final rawHello = _buildClientHelloRecord('e-hentai.org');
      client.add(
        ascii.encode(
          'CONNECT e-hentai.org:${upstream.port} HTTP/1.1\r\n'
          'Host: e-hentai.org:${upstream.port}\r\n\r\n',
        ),
      );
      await client.flush();

      final responseBytes = BytesBuilder();
      final connectOk = Completer<void>();
      final relayOk = Completer<void>();
      client.listen((Uint8List data) {
        responseBytes.add(data);
        final text = latin1.decode(responseBytes.toBytes());
        if (!connectOk.isCompleted &&
            text.contains('200 Connection Established\r\n\r\n')) {
          connectOk.complete();
        }
        if (!relayOk.isCompleted && text.contains('UPSTREAM_OK')) {
          relayOk.complete();
        }
      });

      await connectOk.future.timeout(const Duration(seconds: 3));

      // Drip-feed the ClientHello in tiny 3-byte TCP writes to verify buffering.
      for (int i = 0; i < rawHello.length; i += 3) {
        final end = (i + 3 < rawHello.length) ? i + 3 : rawHello.length;
        client.add(Uint8List.sublistView(rawHello, i, end));
        await client.flush();
      }

      await upstreamDone.future.timeout(const Duration(seconds: 3));
      await relayOk.future.timeout(const Duration(seconds: 3));

      final inspected = _parseTlsRecords(receivedByUpstream);
      expect(inspected.recordPayloads.length, greaterThanOrEqualTo(2));
      for (final payload in inspected.recordPayloads) {
        expect(latin1.decode(payload).contains('e-hentai.org'), isFalse);
      }
      final reassembled = BytesBuilder();
      inspected.recordPayloads.forEach(reassembled.add);
      expect(reassembled.takeBytes(), Uint8List.sublistView(rawHello, 5));
    });

    test('compat tcpSegments mode sends intact single TLS record across multiple chunks', () async {
      final upstream = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(upstream.close);

      final receivedChunks = <Uint8List>[];
      final rawHello = _buildClientHelloRecord('exhentai.org');
      final upstreamDone = Completer<void>();

      upstream.listen((Socket serverSock) {
        serverSock.listen(
          (Uint8List chunk) {
            receivedChunks.add(Uint8List.fromList(chunk));
            final total = receivedChunks.fold<int>(0, (s, b) => s + b.length);
            if (total >= rawHello.length && !upstreamDone.isCompleted) {
              serverSock.close();
              upstreamDone.complete();
            }
          },
          onError: (_) {},
        );
      });

      final proxy = LocalSniProxy(
        resolveIps: (_) async => <String>['127.0.0.1'],
        isHostAllowed: (String host) => host == 'exhentai.org',
        fragmentMode: TlsFragmentMode.tcpSegments,
        fragmentWriteDelay: const Duration(milliseconds: 25),
        allowedPorts: <int>{upstream.port},
        allowLoopbackTargets: true,
      );
      await proxy.start();
      addTearDown(proxy.stop);

      final client = await Socket.connect(InternetAddress.loopbackIPv4, proxy.port!);
      addTearDown(client.destroy);
      client.add(
        ascii.encode('CONNECT exhentai.org:${upstream.port} HTTP/1.1\r\n\r\n'),
      );
      await client.flush();

      final connectOk = Completer<void>();
      final respBuf = BytesBuilder();
      client.listen((d) {
        respBuf.add(d);
        if (!connectOk.isCompleted &&
            latin1.decode(respBuf.toBytes()).contains('200 Connection Established')) {
          connectOk.complete();
        }
      });
      await connectOk.future.timeout(const Duration(seconds: 3));

      client.add(rawHello);
      await client.flush();
      await upstreamDone.future.timeout(const Duration(seconds: 3));

      expect(receivedChunks.length, greaterThanOrEqualTo(2));
      final combined = BytesBuilder();
      receivedChunks.forEach(combined.add);
      // Byte-for-byte identical single TLS record (no record header mutation).
      expect(combined.takeBytes(), rawHello);
    });

    test('enforces port 443 allowlist, host allowlist, method check, and blocks loopback SSRF by default', () async {
      final proxy = LocalSniProxy(
        resolveIps: (_) async => <String>['127.0.0.1'],
        isHostAllowed: (String host) => host == 'e-hentai.org',
      );
      await proxy.start();
      addTearDown(proxy.stop);

      Future<String> sendRaw(String request) async {
        final s = await Socket.connect(InternetAddress.loopbackIPv4, proxy.port!);
        s.add(ascii.encode(request));
        await s.flush();
        final chunks = await s.toList().timeout(const Duration(seconds: 3));
        s.destroy();
        return latin1.decode(chunks.expand((c) => c).toList());
      }

      expect(
        await sendRaw('CONNECT evil.example.com:443 HTTP/1.1\r\n\r\n'),
        startsWith('HTTP/1.1 403'),
      );
      // Non-443 port rejected even for allowed host.
      expect(
        await sendRaw('CONNECT e-hentai.org:80 HTTP/1.1\r\n\r\n'),
        startsWith('HTTP/1.1 403'),
      );
      expect(
        await sendRaw('GET http://e-hentai.org/ HTTP/1.1\r\n\r\n'),
        startsWith('HTTP/1.1 405'),
      );
      // Allowed host on 443 whose resolver returns 127.0.0.1 is refused with 502 (SSRF guard).
      expect(
        await sendRaw('CONNECT e-hentai.org:443 HTTP/1.1\r\n\r\n'),
        startsWith('HTTP/1.1 502'),
      );
    });

    test('fails over to next IP and reports failure callback', () async {
      final upstream = await ServerSocket.bind(InternetAddress('127.0.0.1'), 0);
      addTearDown(upstream.close);
      upstream.listen((Socket s) {
        s.add(ascii.encode('FAILOVER_OK'));
        s.flush().then((_) => s.close());
      });

      final failedCalls = <(String, String)>[];
      final proxy = LocalSniProxy(
        resolveIps: (_) async => <String>['127.0.0.2', '127.0.0.1'],
        isHostAllowed: (_) => true,
        onIpConnectFailure: (host, ip) => failedCalls.add((host, ip)),
        connectTimeout: const Duration(milliseconds: 500),
        allowedPorts: <int>{upstream.port},
        allowLoopbackTargets: true,
      );
      await proxy.start();
      addTearDown(proxy.stop);

      final client = await Socket.connect(InternetAddress.loopbackIPv4, proxy.port!);
      addTearDown(client.destroy);
      client.add(
        ascii.encode('CONNECT e-hentai.org:${upstream.port} HTTP/1.1\r\n\r\n'),
      );
      await client.flush();
      final chunks = await client.toList().timeout(const Duration(seconds: 4));
      final text = latin1.decode(chunks.expand((c) => c).toList());
      expect(text, contains('200 Connection Established'));
      expect(text, contains('FAILOVER_OK'));
      expect(failedCalls, contains(('e-hentai.org', '127.0.0.2')));
    });
  });

  group('SniBypassService Lifecycle, Concurrency, Adapter & Conflict Guards', () {
    late Directory tempDir;

    setUpAll(() {
      tempDir = Directory.systemTemp.createTempSync('eros_sni_test_');
      Global.tempPath = tempDir.path;
    });

    tearDownAll(() {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    tearDown(() async {
      if (Get.isRegistered<SniBypassService>()) {
        final s = Get.find<SniBypassService>();
        await s.setMode(SniBypassMode.standard);
      }
      Get.reset();
    });

    test('standard mode opens zero sockets and executes zero DNS probes', () async {
      int dnsLookupCount = 0;
      final service = SniBypassService(
        autoLoadStorage: false,
        systemDnsLookup: (_) async {
          dnsLookupCount++;
          return <InternetAddress>[InternetAddress('198.18.0.1')];
        },
      );
      Get.put<SniBypassService>(service);

      await service.initializeRuntime();
      expect(service.mode, SniBypassMode.standard);
      expect(service.isProxyRunning, isFalse);
      expect(service.activeLocalProxyDirective, isNull);
      expect(await service.detectProxyConflict(), isNull);
      expect(dnsLookupCount, 0);

      // Verify AppDio in standard mode does not attach local SNI proxy.
      final dio = AppDio(dioConfig: globalDioConfig);
      expect(dio.httpClientAdapter, isA<HttpProxyAdapter>());
      final adapter = dio.httpClientAdapter as HttpProxyAdapter;
      expect(adapter.localSniProxy, isNull);
    });

    test('HttpProxyAdapter enforces strict TLS certificate validation on SNI-bypassed hosts', () async {
      // Spin up a loopback TLS server with an untrusted self-signed cert.
      final certDir = Directory.systemTemp.createTempSync('eros_tls_cert_');
      addTearDown(() => certDir.deleteSync(recursive: true));
      final gen = await Process.run('openssl', <String>[
        'req',
        '-x509',
        '-newkey',
        'rsa:2048',
        '-nodes',
        '-keyout',
        '${certDir.path}/k.pem',
        '-out',
        '${certDir.path}/c.pem',
        '-days',
        '1',
        '-subj',
        '/CN=e-hentai.org',
      ]);
      expect(gen.exitCode, 0);

      final ctx = SecurityContext()
        ..useCertificateChain('${certDir.path}/c.pem')
        ..usePrivateKey('${certDir.path}/k.pem');
      final tlsServer = await SecureServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
        ctx,
      );
      addTearDown(tlsServer.close);
      tlsServer.listen((s) => s.destroy(), onError: (_) {});

      // Even when an external proxy is configured, HttpProxyAdapter must NOT
      // accept untrusted certificates for SNI-bypassed hosts.
      final adapter = HttpProxyAdapter(
        proxy: 'PROXY 127.0.0.1:9999',
        localSniProxy: 'PROXY 127.0.0.1:8888',
        shouldBypassHost: (String host) => host == '127.0.0.1',
      );
      final client = adapter.createHttpClient!();
      addTearDown(() => client.close(force: true));
      client.findProxy = (_) => 'DIRECT';

      await expectLater(
        HttpOverrides.runWithHttpOverrides(
          () async {
            final req = await client.getUrl(
              Uri.parse('https://127.0.0.1:${tlsServer.port}/'),
            );
            await req.close();
          },
          _PassThroughHttpOverrides(),
        ),
        throwsA(isA<HandshakeException>()),
      );

      // Even if a permissive global HttpOverrides is active, HttpProxyAdapter
      // (both direct and SNI-bypassed) must reject untrusted certificates.
      final directAdapter = HttpProxyAdapter(proxy: '');
      final directClient = HttpOverrides.runWithHttpOverrides(
        () => directAdapter.createHttpClient!(),
        EhHttpOverrides(skipCertificateCheck: true),
      );
      addTearDown(() => directClient.close(force: true));
      directClient.findProxy = (_) => 'DIRECT';
      await expectLater(
        HttpOverrides.runWithHttpOverrides(
          () async {
            final req = await directClient.getUrl(
              Uri.parse('https://127.0.0.1:${tlsServer.port}/'),
            );
            await req.close();
          },
          _PassThroughHttpOverrides(),
        ),
        throwsA(isA<HandshakeException>()),
      );
    });

    test('switches cleanly across enhanced, compat, and concurrent enhanced->standard race', () async {
      final service = SniBypassService(
        autoLoadStorage: false,
        systemDnsLookup: (_) async => <InternetAddress>[
          InternetAddress('172.66.132.196'),
        ],
      );
      Get.put<SniBypassService>(service);

      await service.setMode(SniBypassMode.enhanced);
      expect(service.isProxyRunning, isTrue);
      expect(service.activeFragmentMode, TlsFragmentMode.tlsRecords);
      expect(globalDioConfig.sniBypassMode, 'enhanced');
      expect(globalDioConfig.domainFronting, isFalse);
      expect(globalDioConfig.localProxy, service.activeLocalProxyDirective);

      // Verify AppDio wires localSniProxy in enhanced mode.
      final enhancedDio = AppDio(dioConfig: globalDioConfig);
      final enhancedAdapter = enhancedDio.httpClientAdapter as HttpProxyAdapter;
      expect(enhancedAdapter.localSniProxy, service.activeLocalProxyDirective);

      // Switch to compat -> uses TCP segments mode & still zero DomainFronting bypass.
      await service.setMode(SniBypassMode.compat);
      expect(service.isProxyRunning, isTrue);
      expect(service.activeFragmentMode, TlsFragmentMode.tcpSegments);
      expect(globalDioConfig.sniBypassMode, 'compat');
      expect(globalDioConfig.domainFronting, isFalse);

      // Concurrent race: trigger standard immediately after enhanced without awaiting.
      final f1 = service.setMode(SniBypassMode.enhanced);
      final f2 = service.setMode(SniBypassMode.standard);
      await Future.wait<void>(<Future<void>>[f1, f2]);

      expect(service.mode, SniBypassMode.standard);
      expect(service.isProxyRunning, isFalse);
      expect(service.activeLocalProxyDirective, isNull);
      expect(globalDioConfig.localProxy, '');
    });

    test('initializeRuntime binds persisted bypass mode before startup requests', () async {
      final service = SniBypassService(
        autoLoadStorage: false,
        systemDnsLookup: (_) async => <InternetAddress>[
          InternetAddress('172.66.132.196'),
        ],
      );
      Get.put<SniBypassService>(service);

      // Simulate restored persisted enhanced mode without runtime started yet.
      await service.setMode(SniBypassMode.enhanced);
      final initialPort = service.activeLocalProxyDirective;
      expect(initialPort, startsWith('PROXY 127.0.0.1:'));

      // Re-running initializeRuntime is idempotent and keeps config ready.
      await service.initializeRuntime();
      expect(service.isProxyRunning, isTrue);
      expect(globalDioConfig.sniBypassMode, 'enhanced');
      expect(globalDioConfig.localProxy, service.activeLocalProxyDirective);
    });

    test('syncCatalog loads JSON from mock HTTP server and rejects oversized body', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      server.listen((HttpRequest req) {
        if (req.uri.path == '/stall-503') {
          req.response.statusCode = 503;
          req.response.bufferOutput = false;
          req.response.write('stalling');
          req.response.flush();
          // Intentionally leave response open to ensure syncCatalog aborts without draining.
          return;
        }
        if (req.uri.path == '/huge') {
          req.response.statusCode = 200;
          req.response.write('x' * (kMaxCatalogResponseBytes + 1024));
          req.response.close();
          return;
        }
        req.response.statusCode = 200;
        req.response.headers.contentType = ContentType.json;
        req.response.write(
          jsonEncode(<String, dynamic>{
            'version': 1,
            'updatedAt': '2026-11-25T00:00:00Z',
            'servers': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'synced-cf',
                'name': 'Synced Cloudflare',
                'url': 'https://cloudflare-dns.com/dns-query',
                'bootstrapIps': <String>['1.1.1.1', '127.0.0.1'],
              },
            ],
            'fallbackHosts': <String, List<String>>{
              'e-hentai.org': <String>['66.220.148.145', '172.66.132.196'],
            },
          }),
        );
        req.response.close();
      });

      final service = SniBypassService(autoLoadStorage: false);
      Get.put<SniBypassService>(service);

      final stallOk = await HttpOverrides.runWithHttpOverrides(
        () => service.syncCatalog(
          overrideUrls: <String>['http://127.0.0.1:${server.port}/stall-503'],
          requestTimeout: const Duration(seconds: 2),
        ),
        _PassThroughHttpOverrides(),
      );
      expect(stallOk, isFalse);
      expect(service.isSyncing.value, isFalse);

      final hugeOk = await HttpOverrides.runWithHttpOverrides(
        () => service.syncCatalog(
          overrideUrls: <String>['http://127.0.0.1:${server.port}/huge'],
        ),
        _PassThroughHttpOverrides(),
      );
      expect(hugeOk, isFalse);

      final ok = await HttpOverrides.runWithHttpOverrides(
        () => service.syncCatalog(
          overrideUrls: <String>['http://127.0.0.1:${server.port}/doh_list.json'],
        ),
        _PassThroughHttpOverrides(),
      );
      expect(ok, isTrue);
      expect(service.servers.first.id, 'synced-cf');
      expect(service.servers.first.bootstrapIps, <String>['1.1.1.1']);
      expect(service.lastCatalogSyncTime, DateTime.utc(2026, 11, 25));
      expect(service.fallbackHosts['e-hentai.org'], <String>['172.66.132.196']);
    });

    test('custom DoH validates https + public IPv4 bootstrap only', () async {
      final service = SniBypassService(autoLoadStorage: false);
      Get.put<SniBypassService>(service);

      expect(
        await service.addCustomDohServer(url: 'http://insecure.example/dns'),
        isNotNull,
      );
      expect(
        await service.addCustomDohServer(url: 'https://127.0.0.1/dns-query'),
        isNotNull,
      );
      expect(
        await service.addCustomDohServer(url: 'https://100.64.0.1/dns-query'),
        isNotNull,
      );
      expect(
        await service.addCustomDohServer(url: 'https://localhost/dns-query'),
        isNotNull,
      );
      expect(
        await service.addCustomDohServer(url: 'https://dns.google:8443/resolve'),
        isNotNull,
      );
      expect(
        await service.addCustomDohServer(
          url: 'https://doh.example.org/dns-query',
          bootstrapIp: '127.0.0.1',
        ),
        isNotNull,
      );
      expect(
        await service.addCustomDohServer(
          url: 'https://doh.example.org/dns-query',
          bootstrapIp: '192.168.1.1',
        ),
        isNotNull,
      );
      expect(
        await service.addCustomDohServer(
          url: 'https://doh.example.org/dns-query',
          name: 'My DoH',
          bootstrapIp: '1.1.1.1, 1.0.0.1',
        ),
        isNull,
      );
      expect(service.customServers.length, 1);
      final id = service.customServers.first.id;
      expect(service.selectedDohId, id);

      await service.removeCustomDohServer(id);
      expect(service.customServers, isEmpty);
      expect(service.selectedDohId, SniBypassDefaults.autoServerId);
    });

    test('detectProxyConflict identifies Fake-IP TUN when bypass is active', () async {
      final service = SniBypassService(
        autoLoadStorage: false,
        systemDnsLookup: (_) async => <InternetAddress>[
          InternetAddress('198.18.0.42'),
        ],
      );
      Get.put<SniBypassService>(service);
      await service.setMode(SniBypassMode.enhanced);

      final info = await service.detectProxyConflict();
      expect(info, isNotNull);
      expect(info!.kind, ProxyConflictKind.fakeIpTun);
      expect(info.detail, '198.18.0.42');
    });
  });

  group('SniBypassPage Widget, Alignment & Desktop UX Verification', () {
    Future<void> pumpSniPage(
      WidgetTester tester, {
      required Brightness brightness,
      required SniBypassService service,
      Size size = const Size(402, 920),
    }) async {
      registerWaterfallFixture();
      addTearDown(() async {
        await tester.runAsync(() => service.setMode(SniBypassMode.standard));
        Get.reset();
      });
      Get.put<DnsService>(_StubDnsService());
      Get.put<SniBypassService>(service);

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        CupertinoApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: L10n.delegate.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            L10n.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          theme: CupertinoThemeData(brightness: brightness),
          home: const SniBypassPage(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'renders cleanly in Dark, aligns all LEDs vertically, and places polluted label beside name',
      (tester) async {
        final service = SniBypassService(
          autoLoadStorage: false,
          systemDnsLookup: (_) async => <InternetAddress>[
            InternetAddress('172.66.132.196'),
          ],
        );
        await tester.runAsync(() => service.setMode(SniBypassMode.enhanced));
        service.probeResults.addAll(<String, DohProbeResult>{
          'dns-sb': const DohProbeResult(
            serverId: 'dns-sb',
            status: ProbeStatus.ok,
            latencyMs: 26,
          ),
          'cf-1001': const DohProbeResult(
            serverId: 'cf-1001',
            status: ProbeStatus.polluted,
            latencyMs: 14,
          ),
          'nextdns': const DohProbeResult(
            serverId: 'nextdns',
            status: ProbeStatus.timeout,
          ),
        });
        service.siteResults.addAll(<String, SiteCheckResult>{
          'e-hentai.org': const SiteCheckResult(
            host: 'e-hentai.org',
            status: ProbeStatus.ok,
            statusCode: 200,
            latencyMs: 182,
          ),
          'exhentai.org': const SiteCheckResult(
            host: 'exhentai.org',
            status: ProbeStatus.ok,
            statusCode: 200,
            latencyMs: 210,
          ),
          'api.e-hentai.org': const SiteCheckResult(
            host: 'api.e-hentai.org',
            status: ProbeStatus.timeout,
          ),
          'ehgt.org': const SiteCheckResult(
            host: 'ehgt.org',
            status: ProbeStatus.ok,
            statusCode: 200,
            latencyMs: 95,
          ),
        });

        await pumpSniPage(
          tester,
          brightness: Brightness.dark,
          service: service,
        );

        await tester.scrollUntilVisible(
          find.text('E 站节点检测'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('E 站节点检测'));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('疑似污染'),
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        final serverNameRect = tester.getRect(find.text('Cloudflare (1.0.0.1)'));
        final pollutedRect = tester.getRect(find.text('疑似污染'));
        expect(pollutedRect.left, greaterThan(serverNameRect.right));
        expect(
          (pollutedRect.center.dy - serverNameRect.center.dy).abs(),
          lessThan(4.0),
        );

        final metricFinder = find.byType(AlignedStatusMetric);
        expect(metricFinder, findsAtLeastNWidgets(4));
        final ledXValues = <double>[];
        for (final element in metricFinder.evaluate()) {
          final led = find.descendant(
            of: find.byElementPredicate((e) => identical(e, element)),
            matching: find.byType(SoftStatusLed),
          );
          if (led.evaluate().isNotEmpty) {
            ledXValues.add(tester.getRect(led.first).left);
          }
        }
        expect(ledXValues.length, greaterThanOrEqualTo(4));
        for (final x in ledXValues) {
          expect((x - ledXValues.first).abs(), lessThan(0.01));
        }

        await tester.scrollUntilVisible(
          find.text('ehgt.org'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        final ehTile = find.ancestor(
          of: find.text('ehgt.org'),
          matching: find.byType(CupertinoListTile),
        );
        final ehLed = find.descendant(
          of: ehTile.first,
          matching: find.byType(SoftStatusLed),
        );
        expect(
          (tester.getRect(ehLed.first).left - ledXValues.first).abs(),
          lessThan(0.01),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'shows Surge/Fake-IP conflict banner in Light mode and switches back to standard',
      (tester) async {
        final service = SniBypassService(
          autoLoadStorage: false,
          systemDnsLookup: (_) async => <InternetAddress>[
            InternetAddress('198.18.0.1'),
          ],
        );
        await tester.runAsync(() => service.setMode(SniBypassMode.enhanced));

        await pumpSniPage(
          tester,
          brightness: Brightness.light,
          service: service,
        );

        expect(find.text('检测到系统代理或 Fake-IP 接管'), findsOneWidget);
        expect(find.text('切回标准连接'), findsOneWidget);

        await tester.tap(find.text('切回标准连接'));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pumpAndSettle();

        expect(service.mode, SniBypassMode.standard);
        expect(find.text('检测到系统代理或 Fake-IP 接管'), findsNothing);
        expect(find.text('添加自定义 DoH 服务器'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'desktop viewport provides direct clickable delete action for custom DoH servers',
      (tester) async {
        final service = SniBypassService(
          autoLoadStorage: false,
          systemDnsLookup: (_) async => <InternetAddress>[
            InternetAddress('172.66.132.196'),
          ],
        );
        await tester.runAsync(() async {
          await service.setMode(SniBypassMode.enhanced);
          await service.addCustomDohServer(
            url: 'https://custom-doh.example/dns-query',
            name: 'My Custom DoH',
            bootstrapIp: '1.1.1.1',
          );
        });
        final customId = service.customServers.first.id;

        await pumpSniPage(
          tester,
          brightness: Brightness.light,
          service: service,
          size: const Size(1180, 900),
        );

        final deleteBtn = find.byKey(ValueKey<String>('delete_custom_doh_$customId'));
        await tester.scrollUntilVisible(
          deleteBtn,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(deleteBtn, findsOneWidget);

        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        // Confirm delete dialog.
        await tester.tap(find.widgetWithText(CupertinoDialogAction, '删除'));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pumpAndSettle();

        expect(service.customServers, isEmpty);
        expect(find.text('My Custom DoH'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Settings home Advanced row displays active network mode in single-pane and split-pane views',
      (tester) async {
        registerWaterfallFixture();
        Global.packageInfo = PackageInfo(
          appName: 'Eros-FE',
          packageName: 'cn.honjow.fehv',
          version: '1.11.1',
          buildNumber: '570',
        );
        final service = SniBypassService(
          autoLoadStorage: false,
          systemDnsLookup: (_) async => <InternetAddress>[
            InternetAddress('172.66.132.196'),
          ],
        );
        Get.put<SniBypassService>(service);
        Get.put<SettingViewController>(SettingViewController());
        addTearDown(() async {
          PlatformCapabilities.debugHostPlatformOverride = null;
          await tester.runAsync(() => service.setMode(SniBypassMode.standard));
          Get.reset();
        });

        // 1. Single-pane (mobile iOS) view
        PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.iOS;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(402, 874);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          CupertinoApp(
            locale: const Locale('zh', 'CN'),
            supportedLocales: L10n.delegate.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              L10n.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            home: const SettingTab(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('高级'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('标准连接'), findsOneWidget);

        await tester.runAsync(() => service.setMode(SniBypassMode.enhanced));
        await tester.pumpAndSettle();
        expect(find.text('增强连接'), findsOneWidget);

        await tester.runAsync(() => service.setMode(SniBypassMode.compat));
        await tester.pumpAndSettle();
        expect(find.text('兼容模式'), findsOneWidget);

        // 2. Split-pane (desktop macOS) view
        PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.macOS;
        final layout = _StubLayoutServices()..layoutMode = LayoutMode.large;
        Get.put<LayoutServices>(layout);
        tester.view.physicalSize = const Size(1180, 860);

        await tester.pumpWidget(
          CupertinoApp(
            locale: const Locale('zh', 'CN'),
            supportedLocales: L10n.delegate.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              L10n.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            home: const SettingTab(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('高级'), findsOneWidget);
        expect(find.text('兼容模式'), findsOneWidget);

        await tester.runAsync(() => service.setMode(SniBypassMode.enhanced));
        await tester.pumpAndSettle();
        expect(find.text('增强连接'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _StubLayoutServices extends LayoutServices {
  @override
  // ignore: must_call_super
  void onInit() {}
}
