import 'dart:io';

import 'package:dio/io.dart';
import 'package:eros_fe/index.dart';
import 'package:flutter_socks_proxy/socks_proxy.dart';
import 'package:get/get.dart';
import 'package:system_network_proxy/system_network_proxy.dart';
import 'package:system_proxy/system_proxy.dart';

typedef HostBypassPredicate = bool Function(String host);

class HttpProxyAdapter extends IOHttpClientAdapter {
  HttpProxyAdapter({
    required this.proxy,
    bool? skipCertificate,
    this.localSniProxy,
    this.shouldBypassHost,
  }) {
    createHttpClient = () {
      final client = createProxyHttpClient();
      final hasLocalBypass =
          localSniProxy != null && localSniProxy!.isNotEmpty;
      final hasExternalProxy = proxy.isNotEmpty && proxy != 'DIRECT';

      if (hasLocalBypass) {
        client.findProxy = (Uri url) {
          if (shouldBypassHost?.call(url.host) ?? false) {
            return localSniProxy!;
          }
          if (proxy.isNotEmpty) {
            return proxy;
          }
          return 'DIRECT';
        };
      } else if (proxy.isNotEmpty) {
        client.findProxy = (url) => proxy;
      }

      // Preserve standard OS TLS certificate chain verification for all direct
      // and SNI-bypassed hosts. Only keep legacy certificate relaxation when an
      // explicit external proxy (e.g. local debugging MITM proxy) is active on
      // non-bypassed hosts.
      if (hasExternalProxy || (skipCertificate ?? false)) {
        client.badCertificateCallback = (
          X509Certificate cert,
          String host,
          int port,
        ) {
          if (hasLocalBypass && (shouldBypassHost?.call(host) ?? false)) {
            return false;
          }
          return true;
        };
      } else {
        // Defense-in-depth: clear any permissive callback installed by global
        // HttpOverrides so direct and SNI-bypassed traffic enforces full OS TLS
        // chain verification.
        client.badCertificateCallback = null;
      }
      return client;
    };
  }

  final String proxy;
  final String? localSniProxy;
  final HostBypassPredicate? shouldBypassHost;
}

Future<String> getProxy({
  ProxyType proxyType = ProxyType.system,
  String? proxyHost,
  int? proxyPort,
  String? proxyUsername,
  String? proxyPassword,
}) async {
  String proxy = '$proxyHost:$proxyPort';
  if (proxyUsername != null &&
      proxyUsername.isNotEmpty &&
      proxyPassword != null &&
      proxyPassword.isNotEmpty) {
    proxy = '$proxyUsername:$proxyPassword@$proxy';
  }
  switch (proxyType) {
    case ProxyType.system:
      if (GetPlatform.isMobile) {
        Map<String, String>? systemProxy = await SystemProxy.getProxySettings();
        if (systemProxy != null) {
          proxy = 'PROXY ${systemProxy['host']}:${systemProxy['port']}';
        } else {
          proxy = 'DIRECT';
        }
      }

      if (GetPlatform.isDesktop) {
        final proxyEnable = await SystemNetworkProxy.getProxyEnable();
        final proxyServer = await SystemNetworkProxy.getProxyServer();
        logger.d('proxyEnable: $proxyEnable proxyServer: $proxyServer');
        if (proxyEnable && proxyServer.isNotEmpty) {
          proxy = 'PROXY $proxyServer';
        } else {
          proxy = 'DIRECT';
        }
      }
      break;
    case ProxyType.http:
      proxy = 'PROXY $proxy';
      break;
    case ProxyType.socks5:
      proxy = 'SOCKS5 $proxy';
      break;
    case ProxyType.socks4:
      proxy = 'SOCKS4 $proxy';
      break;
    case ProxyType.direct:
      proxy = 'DIRECT';
      break;
  }

  return proxy;
}
