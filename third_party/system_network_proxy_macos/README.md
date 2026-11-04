# Local system_network_proxy_macos fix

Vendored from system_network_proxy_macos 1.0.2:
https://pub.dev/packages/system_network_proxy_macos/versions/1.0.2
Upstream: https://github.com/liudonghua123/system_network_proxy
The upstream LICENSE is retained.

This Dart-only plugin removes `pluginClass: none` (which generated an invalid
Swift `none.register` call), declares `implements: system_network_proxy`, and
adds `registerWith()` to install its existing singleton into the platform
interface. Its Dart SDK constraint is updated to `>=3.0.0 <4.0.0`.
The proxy implementation and public API are otherwise unchanged.
