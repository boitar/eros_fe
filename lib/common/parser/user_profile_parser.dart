import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;

User parseUserProfile(String html) {
  final Document document = parse(html);

  final Element? profilenameElm = document.querySelector('#profilename');
  final String nickName = profilenameElm?.text ?? '';

  final Element? avatarElm =
      profilenameElm?.nextElementSibling?.nextElementSibling;

  String _avatarUrl = '';
  if (avatarElm?.children.isNotEmpty ?? false) {
    final Element? imageElm = avatarElm?.children.first;
    _avatarUrl = imageElm?.attributes['src'] ?? '';
    if (_avatarUrl.isNotEmpty) {
      final uri = Uri.parse('https://forums.e-hentai.org/').resolve(_avatarUrl);
      _avatarUrl =
          <String>{'http', 'https'}.contains(uri.scheme) ? uri.toString() : '';
    }
  }

  return kDefUser.copyWith(
    avatarUrl: _avatarUrl.oN,
    nickName: nickName.oN,
  );
}

/// 论坛 UserCP 头像表单页的解析结果
class AvatarCpResult {
  const AvatarCpResult({
    this.authKey,
    this.success = false,
    this.cfBlocked = false,
    this.message,
  });

  /// 头像上传表单的 auth_key
  final String? authKey;

  /// 上传/解析是否成功
  final bool success;

  /// 是否被 Cloudflare 拦截
  final bool cfBlocked;

  final String? message;
}

/// Cloudflare 人机验证页特征
bool isCloudflareChallenge(String html) {
  if (html.isEmpty) {
    return false;
  }
  return html.contains('Just a moment') ||
      html.contains('cf-browser-verification') ||
      html.contains('challenge-platform') ||
      html.contains('cf_chl_opt') ||
      html.contains('Attention Required');
}

/// 从 UserCP 头像设置页（act=UserCP&CODE=24）解析上传表单的 auth_key
String? parseAvatarAuthKey(String html) {
  final Document document = parse(html);

  final List<Element> forms =
      document.querySelectorAll('form[action*="auth_key"]');
  for (final Element form in forms) {
    final String? code =
        form.querySelector('input[name="CODE"]')?.attributes['value'];
    if (code == '25') {
      final Uri? action = Uri.tryParse(form.attributes['action'] ?? '');
      final String? authKey = action?.queryParameters['auth_key'];
      if (authKey != null && authKey.isNotEmpty) {
        return authKey;
      }
    }
  }

  // 兜底：直接按特征匹配
  final RegExpMatch? match = RegExp(r'auth_key=([\da-f]{32})').firstMatch(html);
  return match?.group(1);
}

/// 解析头像上传（CODE=25）的响应页面。
/// Require a recognizable avatar control panel or explicit update confirmation.
AvatarCpResult parseAvatarUpdateResult(String html) {
  if (isCloudflareChallenge(html)) {
    return const AvatarCpResult(
      cfBlocked: true,
      message: 'Cloudflare verification required',
    );
  }

  // 未登录时 UserCP 会跳转到登录页
  if (parse(html).querySelector('input[type="password"], input[name="PassWord"]') != null) {
    return const AvatarCpResult(success: false, message: 'Not logged in');
  }

  final Document document = parse(html);
  final Element? errorElm =
      document.querySelector('.errorwrap, div.error, div#ipb-error');
  if (errorElm != null) {
    final String text = errorElm.text.trim();
    return AvatarCpResult(
      success: false,
      message: text.isEmpty ? 'Avatar upload failed' : text,
    );
  }

  final text = document.body?.text.toLowerCase() ?? '';
  final confirmed = document.querySelectorAll('form').any((form) =>
          form.querySelector('input[name="CODE"]')?.attributes['value'] == '25' &&
          form.querySelector('input[name="upload_avatar"]') != null) ||
      text.contains('avatar has been updated') ||
      text.contains('avatar updated successfully');
  return AvatarCpResult(
    success: confirmed,
    message: confirmed ? null : 'Avatar upload could not be confirmed',
  );
}
