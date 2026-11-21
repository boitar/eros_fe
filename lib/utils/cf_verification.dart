import 'dart:io';

/// 内置 WebView 完成 Cloudflare 验证或应用内浏览器登录后带回的完整 Cookie 与 UA
class CfVerification {
  const CfVerification(
    this.cookies,
    this.userAgent, {
    this.exVisited = false,
  });

  /// Cloudflare 验证核心凭据名
  static const cookieNames = <String>{'cf_clearance', 'cf_duid'};

  /// 登录与站点会话相关的全部关键凭据名
  static const sessionCookieNames = <String>{
    'ipb_member_id',
    'ipb_pass_hash',
    'igneous',
    'hath_perks',
    'sk',
    'star',
    'yay',
    'iq',
    'cf_clearance',
    'cf_duid',
  };

  final List<Cookie> cookies;
  final String? userAgent;
  final bool exVisited;

  bool get isComplete => cookies.any(
      (cookie) => cookie.name == 'cf_clearance' && cookie.value.isNotEmpty);

  bool get hasLoginSession {
    final id = value('ipb_member_id')?.trim();
    final hash = value('ipb_pass_hash')?.trim();
    return id != null &&
        id.isNotEmpty &&
        id != '0' &&
        hash != null &&
        hash.isNotEmpty;
  }

  bool get hasValidIgneous {
    final ig = value('igneous')?.trim();
    return ig != null && ig.isNotEmpty && ig != 'mystery';
  }

  String? value(String name) {
    for (final cookie in cookies) {
      if (cookie.name == name && cookie.value.isNotEmpty) {
        return cookie.value;
      }
    }
    return null;
  }
}
