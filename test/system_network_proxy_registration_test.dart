import 'package:flutter_test/flutter_test.dart';
import 'package:system_network_proxy/system_network_proxy.dart';
// Exercise the overridden federated implementation and its transitive interface.
// ignore: depend_on_referenced_packages
import 'package:system_network_proxy_macos/system_network_proxy_macos.dart';
// ignore: depend_on_referenced_packages
import 'package:system_network_proxy_platform_interface/system_network_proxy_platform_interface.dart';

class ProbeProxy extends SystemNetworkProxyMacos {
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
}
