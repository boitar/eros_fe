import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:eros_fe/network/sni_bypass/sni_bypass_models.dart';
import 'package:eros_fe/network/sni_bypass/tls_fragmenter.dart';
import 'package:eros_fe/utils/logger.dart';

typedef HostIpResolver = Future<List<String>> Function(String host);
typedef HostAllowPredicate = bool Function(String host);
typedef IpConnectFailureCallback = void Function(String host, String ip);

/// Localhost-only HTTP CONNECT proxy that resolves target domains via a custom
/// resolver (Custom Hosts / DoH / fallback IPs) and fragments the initial TLS
/// ClientHello so SNI-inspecting DPI cannot block the handshake while
/// preserving real SNI and full HTTPS certificate verification.
class LocalSniProxy {
  LocalSniProxy({
    required this.resolveIps,
    required this.isHostAllowed,
    this.onIpConnectFailure,
    this.connectTimeout = const Duration(seconds: 10),
    this.fragmentWriteDelay = const Duration(milliseconds: 5),
    this.fragmentMode = TlsFragmentMode.tlsRecords,
    this.enableFragmentation = true,
    this.allowedPorts = const <int>{443},
    this.allowLoopbackTargets = false,
  });

  final HostIpResolver resolveIps;
  final HostAllowPredicate isHostAllowed;
  final IpConnectFailureCallback? onIpConnectFailure;
  final Duration connectTimeout;
  final Duration fragmentWriteDelay;
  final TlsFragmentMode fragmentMode;
  final bool enableFragmentation;

  /// Permitted CONNECT target ports. Defaults strictly to `{443}` to prevent
  /// arbitrary port tunneling / loopback SSRF.
  final Set<int> allowedPorts;

  /// Only enabled by loopback unit tests. Production always enforces public
  /// IPv4 targets only via [isValidPublicIpv4].
  final bool allowLoopbackTargets;

  ServerSocket? _server;
  final Set<Socket> _activeSockets = <Socket>{};

  bool get isRunning => _server != null;
  int? get port => _server?.port;
  String? get proxyDirective => port == null ? null : 'PROXY 127.0.0.1:$port';

  Future<int> start() async {
    if (_server != null) {
      return _server!.port;
    }
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(
      _handleClient,
      onError: (Object e, StackTrace s) {
        logger.e('LocalSniProxy accept error: $e');
      },
    );
    logger.i('LocalSniProxy listening on 127.0.0.1:${server.port} ($fragmentMode)');
    return server.port;
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    for (final socket in List<Socket>.from(_activeSockets)) {
      try {
        socket.destroy();
      } catch (_) {}
    }
    _activeSockets.clear();
    if (server != null) {
      try {
        await server.close();
      } catch (_) {}
    }
  }

  void _trackSocket(Socket socket) {
    _activeSockets.add(socket);
  }

  void _untrackSocket(Socket socket) {
    _activeSockets.remove(socket);
  }

  void _handleClient(Socket client) {
    _trackSocket(client);
    try {
      client.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {}

    final session = _ConnectSession(
      proxy: this,
      client: client,
    );
    unawaited(session.run());
  }
}

class _ConnectSession {
  _ConnectSession({
    required this.proxy,
    required this.client,
  });

  static const int _maxHeaderBytes = 8192;
  static const int _maxFirstTlsBufferBytes = 16384 + 2048;

  final LocalSniProxy proxy;
  final Socket client;

  Socket? _upstream;
  bool _closed = false;

  Future<void> run() async {
    final iterator = StreamIterator<Uint8List>(client);
    try {
      // 1. Read HTTP CONNECT request header.
      final headerBuf = BytesBuilder(copy: false);
      int headerEndIndex = -1;
      Uint8List? leftover;

      while (await iterator.moveNext().timeout(proxy.connectTimeout)) {
        headerBuf.add(iterator.current);
        if (headerBuf.length > _maxHeaderBytes) {
          await _writeErrorAndClose('400 Bad Request');
          return;
        }
        final bytes = headerBuf.toBytes();
        headerEndIndex = _findHeaderEnd(bytes);
        if (headerEndIndex != -1) {
          final headerText = ascii.decode(
            bytes.sublist(0, headerEndIndex),
            allowInvalid: true,
          );
          if (bytes.length > headerEndIndex + 4) {
            leftover = Uint8List.sublistView(bytes, headerEndIndex + 4);
          }
          await _handleConnectRequest(headerText, leftover, iterator);
          return;
        }
      }
      _closeAll();
    } catch (e) {
      logger.t('LocalSniProxy session ended: $e');
      _closeAll();
    } finally {
      try {
        await iterator.cancel();
      } catch (_) {}
    }
  }

  Future<void> _handleConnectRequest(
    String headerText,
    Uint8List? leftover,
    StreamIterator<Uint8List> iterator,
  ) async {
    final firstLine = headerText.split('\r\n').first.trim();
    final parts = firstLine.split(' ');
    if (parts.length < 2 || parts[0].toUpperCase() != 'CONNECT') {
      await _writeErrorAndClose('405 Method Not Allowed');
      return;
    }

    final parsedTarget = _parseAuthority(parts[1]);
    if (parsedTarget == null) {
      await _writeErrorAndClose('400 Bad Request');
      return;
    }

    final targetHost = parsedTarget.host;
    final targetPort = parsedTarget.port;

    if (!proxy.allowedPorts.contains(targetPort) ||
        !proxy.isHostAllowed(targetHost)) {
      await _writeErrorAndClose('403 Forbidden');
      return;
    }

    // 2. Connect upstream using validated candidate IPs (with failover).
    final candidates = await proxy.resolveIps(targetHost);
    final upstream = await _connectUpstream(
      targetHost: targetHost,
      targetPort: targetPort,
      candidates: candidates,
    );
    if (upstream == null || _closed) {
      await _writeErrorAndClose('502 Bad Gateway');
      return;
    }
    _upstream = upstream;
    proxy._trackSocket(upstream);
    try {
      upstream.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {}

    // 3. Acknowledge tunnel establishment.
    client.add(ascii.encode('HTTP/1.1 200 Connection Established\r\n\r\n'));
    await client.flush();

    // 4. Start upstream -> client relay immediately.
    final upstreamDone = Completer<void>();
    upstream.listen(
      (Uint8List data) {
        if (_closed) {
          return;
        }
        try {
          client.add(data);
        } catch (_) {
          _closeAll();
        }
      },
      onError: (_) => _closeAll(),
      onDone: () {
        if (!upstreamDone.isCompleted) {
          upstreamDone.complete();
        }
        _closeAll();
      },
      cancelOnError: true,
    );

    // 5. Intercept and fragment ONLY the first TLS ClientHello record.
    bool firstRecordHandled = !proxy.enableFragmentation;
    final firstBuf = BytesBuilder(copy: false);

    Future<void> forwardClientChunk(Uint8List chunk) async {
      if (_closed || chunk.isEmpty) {
        return;
      }
      if (firstRecordHandled) {
        upstream.add(chunk);
        return;
      }

      firstBuf.add(chunk);
      final buffered = firstBuf.toBytes();

      // If this doesn't look like TLS handshake, flush immediately and disable framing.
      if (buffered.length >= 2 &&
          !(buffered[0] == 0x16 && buffered[1] == 0x03)) {
        firstRecordHandled = true;
        upstream.add(buffered);
        firstBuf.clear();
        return;
      }

      if (buffered.length < 5) {
        return;
      }

      final expectedLen = expectedTlsRecordLength(buffered);
      if (expectedLen == null || expectedLen > _maxFirstTlsBufferBytes) {
        firstRecordHandled = true;
        upstream.add(buffered);
        firstBuf.clear();
        return;
      }

      if (buffered.length < expectedLen) {
        return;
      }

      // Complete ClientHello TLS record received -> fragment and send sequentially.
      firstRecordHandled = true;
      firstBuf.clear();
      final fragments = switch (proxy.fragmentMode) {
        TlsFragmentMode.tlsRecords => fragmentTlsClientHello(buffered),
        TlsFragmentMode.tcpSegments => splitTlsClientHelloTcpSegments(buffered),
      };
      for (int i = 0; i < fragments.length; i++) {
        if (_closed) {
          return;
        }
        upstream.add(fragments[i]);
        await upstream.flush();
        if (i < fragments.length - 1 &&
            proxy.fragmentWriteDelay > Duration.zero) {
          await Future<void>.delayed(proxy.fragmentWriteDelay);
        }
      }
    }

    if (leftover != null && leftover.isNotEmpty) {
      await forwardClientChunk(leftover);
    }

    while (!_closed && await iterator.moveNext()) {
      await forwardClientChunk(iterator.current);
    }

    // Flush any remaining partial first buffer if client half-closed early.
    if (!_closed && !firstRecordHandled && firstBuf.isNotEmpty) {
      upstream.add(firstBuf.takeBytes());
      await upstream.flush();
    }

    await upstreamDone.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    );
    _closeAll();
  }

  bool _isAllowedTargetIp(String ip) {
    if (isValidPublicIpv4(ip)) {
      return true;
    }
    if (proxy.allowLoopbackTargets) {
      final octets = parseIpv4Octets(ip);
      return octets != null && octets[0] == 127;
    }
    return false;
  }

  Future<Socket?> _connectUpstream({
    required String targetHost,
    required int targetPort,
    required List<String> candidates,
  }) async {
    final safeTargets = candidates.where(_isAllowedTargetIp).toList();
    if (safeTargets.isEmpty) {
      logger.w('LocalSniProxy refused $targetHost: no permitted IPv4 candidates');
      return null;
    }
    for (final addr in safeTargets) {
      if (_closed) {
        return null;
      }
      try {
        return await Socket.connect(
          addr,
          targetPort,
          timeout: proxy.connectTimeout,
        );
      } catch (e) {
        logger.t(
          'LocalSniProxy connect failed $targetHost ($addr:$targetPort): $e',
        );
        proxy.onIpConnectFailure?.call(targetHost, addr);
      }
    }
    return null;
  }

  Future<void> _writeErrorAndClose(String status) async {
    if (_closed) {
      return;
    }
    try {
      client.add(ascii.encode('HTTP/1.1 $status\r\nConnection: close\r\n\r\n'));
      await client.flush();
    } catch (_) {}
    _closeAll();
  }

  void _closeAll() {
    if (_closed) {
      return;
    }
    _closed = true;
    final up = _upstream;
    _upstream = null;
    if (up != null) {
      proxy._untrackSocket(up);
      try {
        up.destroy();
      } catch (_) {}
    }
    proxy._untrackSocket(client);
    try {
      client.destroy();
    } catch (_) {}
  }

  static int _findHeaderEnd(Uint8List bytes) {
    for (int i = 0; i <= bytes.length - 4; i++) {
      if (bytes[i] == 13 &&
          bytes[i + 1] == 10 &&
          bytes[i + 2] == 13 &&
          bytes[i + 3] == 10) {
        return i;
      }
    }
    return -1;
  }

  static ({String host, int port})? _parseAuthority(String authority) {
    final trimmed = authority.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.startsWith('[')) {
      final closeIdx = trimmed.indexOf(']');
      if (closeIdx <= 1) {
        return null;
      }
      final host = trimmed.substring(1, closeIdx);
      final rest = trimmed.substring(closeIdx + 1);
      final port = rest.startsWith(':')
          ? int.tryParse(rest.substring(1))
          : 443;
      if (port == null || port <= 0 || port > 65535) {
        return null;
      }
      return (host: host, port: port);
    }
    final colonIdx = trimmed.lastIndexOf(':');
    if (colonIdx == -1) {
      return (host: trimmed, port: 443);
    }
    final host = trimmed.substring(0, colonIdx).trim();
    final port = int.tryParse(trimmed.substring(colonIdx + 1));
    if (host.isEmpty || port == null || port <= 0 || port > 65535) {
      return null;
    }
    return (host: host, port: port);
  }
}
