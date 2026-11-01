import 'dart:io' as io;

import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/network/api.dart';
import 'package:eros_fe/utils/cf_verification.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

/// 打开内置 WebView 完成论坛的 Cloudflare 验证；取消时返回 null
Future<CfVerification?> openCfVerification() async {
  return Get.to<CfVerification>(() => const CfVerifyWebView());
}

/// 把验证结果写入 cookie jar 与当前用户，之后的 Dio 请求带上同一组 cookie 与 UA
Future<void> applyCfVerification(
  CfVerification verification, {
  void Function()? checkAccount,
}) async {
  final jar = await Api.cookieJar;
  checkAccount?.call();
  await jar.saveFromResponse(
      Uri.parse('https://forums.e-hentai.org/'), verification.cookies);
  checkAccount?.call();
  final UserController controller = Get.find();
  controller.user(controller.user.value.copyWith(
    cfClearance: verification.value('cf_clearance')?.oN,
    cfDuid: verification.value('cf_duid')?.oN,
    userAgent: verification.userAgent?.oN,
  ));
}

/// 询问用户是否去验证；验证完成并已保存时返回 true
Future<bool> promptCfVerification() async {
  final context = Get.context;
  if (context == null) {
    return false;
  }
  final l10n = L10n.of(context);
  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => EhAlertDialog(
      title: Text(l10n.cf_verify_required),
      content: Text(l10n.cf_verify_prompt),
      actions: <CupertinoDialogAction>[
        CupertinoDialogAction(
          child: Text(l10n.cancel),
          onPressed: () => Navigator.pop(dialogContext),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          child: Text(l10n.cf_verify_action),
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
      ],
    ),
  );
  if (confirmed != true) {
    return false;
  }
  final verification = await openCfVerification();
  if (verification == null || !verification.isComplete) {
    return false;
  }
  await applyCfVerification(verification);
  return true;
}

class CfVerifyWebView extends StatefulWidget {
  const CfVerifyWebView({super.key});

  static const kVerifyUrl = 'https://forums.e-hentai.org/index.php';

  static bool isForumUri(Uri? uri) =>
      uri?.scheme == 'https' && uri?.host == 'forums.e-hentai.org';

  @override
  State<CfVerifyWebView> createState() => _CfVerifyWebViewState();
}

class _CfVerifyWebViewState extends State<CfVerifyWebView> {
  final _cookieManager = CookieManager.instance();
  InAppWebViewController? _controller;
  bool _finishing = false;
  bool _done = false;

  Future<void> _finish() async {
    if (_finishing || _done || !mounted) {
      return;
    }
    _finishing = true;
    final route = ModalRoute.of(context);
    try {
      final controller = _controller;
      if (controller == null) {
        return;
      }
      final uri = await controller.getUrl();
      if (!CfVerifyWebView.isForumUri(uri)) {
        return;
      }
      final title = await controller.getTitle() ?? '';
      if (title.contains('Just a moment') ||
          title.contains('Attention Required')) {
        return;
      }
      final rawUa =
          await controller.evaluateJavascript(source: 'navigator.userAgent');
      final userAgent = rawUa?.toString().trim();
      final cookies = await _cookieManager.getCookies(
          url: WebUri('https://forums.e-hentai.org/'));
      final verification = CfVerification(
        cookies
            .where((cookie) => CfVerification.cookieNames.contains(cookie.name))
            .map((cookie) => io.Cookie(cookie.name, '${cookie.value}'))
            .toList(),
        userAgent,
      );
      if (!mounted ||
          route?.isCurrent != true ||
          _done ||
          !verification.isComplete) {
        return;
      }
      _done = true;
      Navigator.of(context).pop(verification);
    } catch (error) {
      logger.e('cloudflare verification failed: $error');
    } finally {
      _finishing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingScaffold(
      title: L10n.of(context).cf_verify_title,
      actions: <NativeNavigationAction>[
        NativeNavigationAction(
          id: 'cfVerify.done',
          title: L10n.of(context).done,
          onPressed: _finish,
        ),
      ],
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _finish,
        child: Text(L10n.of(context).done),
      ),
      child: SafeArea(
        child: InAppWebView(
          initialUrlRequest:
              URLRequest(url: WebUri(CfVerifyWebView.kVerifyUrl)),
          // 不要开 useShouldOverrideUrlLoading：没有回调时 iOS 会取消首个导航，页面一直空白
          initialSettings: InAppWebViewSettings(
            mediaPlaybackRequiresUserGesture: false,
            useHybridComposition: true,
          ),
          onWebViewCreated: (controller) => _controller = controller,
          onLoadStop: (controller, uri) async {
            if (CfVerifyWebView.isForumUri(uri)) {
              await _finish();
            }
          },
        ),
      ),
    );
  }
}
