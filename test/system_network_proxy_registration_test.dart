import 'package:flutter_test/flutter_test.dart';
import 'package:system_network_proxy/system_network_proxy.dart';
// Exercise the overridden federated implementation and its transitive interface.
// ignore: depend_on_referenced_packages
import 'package:system_network_proxy_macos/system_network_proxy_macos.dart';
// ignore: depend_on_referenced_packages
import 'package:system_network_proxy_platform_interface/system_network_proxy_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:system_network_proxy_windows/system_network_proxy_windows.dart';

class ProbeProxy extends SystemNetworkProxyMacos {
  int reads = 0;
  @override
  Future<String> getProxyServer() async {
    reads++;
    return '127.0.0.1:7890';
  }
}

class ProbeWindowsProxy extends SystemNetworkProxyWindows {
  int reads = 0;

  @override
  Future<String> getProxyServer() async {
    reads++;
    return '127.0.0.1:7890';
  }
}

void main() {
  test(
      'Dart registration binds platform implementation and public API delegates',
      () async {
    final previousSingleton = SystemNetworkProxyMacos.instance;
    final previousPlatform = SystemNetworkProxyPlatform.instance;
    addTearDown(() {
      SystemNetworkProxyMacos.instance = previousSingleton;
      SystemNetworkProxyPlatform.instance = previousPlatform;
    });
    final probe = ProbeProxy();
    SystemNetworkProxyMacos.instance = probe;
    SystemNetworkProxyMacos.registerWith();
    expect(identical(SystemNetworkProxyPlatform.instance, probe), isTrue);
    SystemNetworkProxy.init();
    expect(identical(SystemNetworkProxyPlatform.instance, probe), isTrue);
    expect(await SystemNetworkProxy.getProxyServer(), '127.0.0.1:7890');
    expect(probe.reads, 1);
  });

  test('Windows Dart registration remains available without a native plugin',
      () async {
    final previousSingleton = SystemNetworkProxyWindows.instance;
    final previousPlatform = SystemNetworkProxyPlatform.instance;
    addTearDown(() {
      SystemNetworkProxyWindows.instance = previousSingleton;
      SystemNetworkProxyPlatform.instance = previousPlatform;
    });
    final probe = ProbeWindowsProxy();
    SystemNetworkProxyWindows.instance = probe;
    SystemNetworkProxyWindows.registerWith();
    expect(identical(SystemNetworkProxyPlatform.instance, probe), isTrue);
    expect(await SystemNetworkProxy.getProxyServer(), '127.0.0.1:7890');
    expect(probe.reads, 1);
  });
}
