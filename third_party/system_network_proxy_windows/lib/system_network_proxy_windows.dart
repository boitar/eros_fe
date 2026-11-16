import 'dart:io';

import 'package:system_network_proxy_platform_interface/system_network_proxy_platform_interface.dart';

class SystemNetworkProxyWindows extends SystemNetworkProxyPlatform {
  // Keep the upstream package's mutable singleton API so callers that replace
  // the implementation for tests or host integration remain source-compatible.
  static SystemNetworkProxyWindows instance = SystemNetworkProxyWindows();

  static void registerWith() {
    SystemNetworkProxyPlatform.instance = instance;
  }

  /// Returns `true` if this platform is able to getProxyEnable.
  @override
  Future<bool> getProxyEnable() async {
    try {
      final results = await Process.run('reg', [
        'query',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        '/v',
        'ProxyEnable',
      ]);
      final line = (results.stdout as String)
          .split('\r\n')
          .where((item) => item.contains('ProxyEnable'))
          .first;
      return line.trimRight().endsWith('1');
    } catch (_) {
      return false;
    }
  }

  /// Returns `true` if this platform is able to setProxyEnable.
  @override
  Future<bool> setProxyEnable(bool proxyEnable) async {
    try {
      final results = await Process.run('reg', [
        'add',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        '/v',
        'ProxyEnable',
        '/t',
        'REG_DWORD',
        '/f',
        '/d',
        proxyEnable ? '1' : '0',
      ]);
      return results.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Returns the configured proxy server, or an empty string when unavailable.
  @override
  Future<String> getProxyServer() async {
    try {
      final results = await Process.run('reg', [
        'query',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        '/v',
        'ProxyServer',
      ]);
      final line = (results.stdout as String)
          .split('\r\n')
          .where((item) => item.contains('ProxyServer'))
          .first;
      final fields = line.trim().split(RegExp(r'\s+'));
      return fields.isEmpty ? '' : fields.last;
    } catch (_) {
      return '';
    }
  }

  /// Returns `true` if this platform is able to setProxyServer.
  @override
  Future<bool> setProxyServer(String proxyServer) async {
    try {
      final results = await Process.run('reg', [
        'add',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        '/v',
        'ProxyServer',
        '/f',
        '/d',
        proxyServer,
      ]);
      return results.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
