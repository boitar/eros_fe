import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../controller/splash_controller.dart';

/// 闪屏页
class SplashPage extends GetView<SplashController> {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bool hasSharedText =
        controller.sharedText != null &&
        (controller.sharedText?.isNotEmpty ?? false);
    final Widget container = hasSharedText
        ? const Center(child: CupertinoActivityIndicator(radius: 20.0))
        : Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const EhFeAppLogo(
                  size: 108.0,
                  style: EhFeLogoStyle.minimal,
                ),
                const SizedBox(height: 18),
                Text(
                  L10n.of(context).app_title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: ehTheme.palette.text2.resolveFrom(context),
                  ),
                ),
              ],
            ),
          );

    return CupertinoPageScaffold(
      child: container,
    );
  }
}
