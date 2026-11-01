import 'dart:io';

/// 内置 WebView 完成 Cloudflare 验证后带回的 cookie 与 UA
class CfVerification {
  const CfVerification(this.cookies, this.userAgent);

  static const cookieNames = <String>{'cf_clearance', 'cf_duid'};

  final List<Cookie> cookies;
  final String? userAgent;

  bool get isComplete => cookies.any(
      (cookie) => cookie.name == 'cf_clearance' && cookie.value.isNotEmpty);

  String? value(String name) {
    for (final cookie in cookies) {
      if (cookie.name == name) {
        return cookie.value;
      }
    }
    return null;
  }
}
