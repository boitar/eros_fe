import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/network/api.dart';
import 'package:eros_fe/pages/setting/controller/web_setting_controller.dart';
import 'package:eros_fe/utils/logger.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

import 'eh_webview.dart';

class InWebMyTags extends StatelessWidget {
  const InWebMyTags({super.key});

  @override
  Widget build(BuildContext context) {
    InAppWebViewController? inAppWebViewController;

    void reload() => inAppWebViewController?.reload();

    final Widget cpf = SettingScaffold(
      title: L10n.of(context).ehentai_my_tags,
      actions: <NativeNavigationAction>[
        NativeNavigationAction(
          id: 'webMyTags.reload',
          title: L10n.of(context).reload,
          symbol: 'arrow.clockwise',
          onPressed: reload,
        ),
      ],
      trailing: CupertinoButton(
        padding: const EdgeInsets.all(0),
        onPressed: reload,
        child: const FaIcon(FontAwesomeIcons.rotateRight,
          size: 22,
        ),
      ),
      child: SafeArea(
        child: InAppWebView(
          initialUrlRequest:
              URLRequest(url: WebUri('${Api.getBaseUrl()}/mytags')),
          onWebViewCreated: (InAppWebViewController controller) {
            inAppWebViewController = controller;
          },
          initialSettings: inAppWebViewSettings,
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            final uri = navigationAction.request.url!;

            logger.d('to $uri');
            if (!(uri.path == '/mytags')) {
              logger.d('阻止打开 $uri');
              return NavigationActionPolicy.CANCEL;
            }

            return NavigationActionPolicy.ALLOW;
          },
          onLoadStop: (InAppWebViewController controller, Uri? url) async {
            logger.d('Page Finished loading: $url');
          },
        ),
      ),
    );

    return GetBuilder<WebSettingController>(
        init: WebSettingController(),
        builder: (controller) {
          return FutureBuilder<void>(
              future: controller.setcookieFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CupertinoActivityIndicator());
                }
                return cpf;
              });
        });
  }
}
