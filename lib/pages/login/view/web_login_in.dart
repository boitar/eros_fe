import 'package:eros_fe/pages/setting/webview/cf_verify_in.dart';
import 'package:eros_fe/utils/cf_verification.dart';
import 'package:flutter/cupertino.dart';

/// 兼容 `EHRoutes.webLogin` 路由：复用重构后的应用内验证与网页登录视图
class WebLoginViewIn extends StatefulWidget {
  const WebLoginViewIn({super.key});

  static String? lastUserAgent;

  @override
  State<WebLoginViewIn> createState() => _WebLoginViewInState();
}

class _WebLoginViewInState extends State<WebLoginViewIn> {
  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && result is CfVerification) {
          WebLoginViewIn.lastUserAgent = result.userAgent;
        }
      },
      child: const CfVerifyWebView(
        interactiveWebLogin: true,
        acquireExSession: true,
      ),
    );
  }
}
