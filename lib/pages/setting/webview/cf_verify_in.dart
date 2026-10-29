import 'dart:io' as io;

import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/utils/avatar_upload_retry.dart';
import 'package:eros_fe/utils/logger.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

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
      final verification = AvatarVerification(
        cookies
            .where((cookie) =>
                <String>{'cf_clearance', 'cf_duid'}.contains(cookie.name))
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
      logger.e('avatar verification failed: $error');
    } finally {
      _finishing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingScaffold(
      title: L10n.of(context).avatar_cf_verify_title,
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
          initialSettings: InAppWebViewSettings(
            useShouldOverrideUrlLoading: true,
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
