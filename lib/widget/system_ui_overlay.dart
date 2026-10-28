import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/debug/offline_duo_health.dart';
import 'package:eros_fe/route/main_observer.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class SystemUIOverlay extends StatelessWidget {
  const SystemUIOverlay({super.key, this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final brightnessLight = Theme.of(context).brightness == Brightness.light;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness:
            brightnessLight ? Brightness.dark : Brightness.light,
      ),
      child: offlineDuoHealth(
          child: NativeNavigationHost(
        observer: MainNavigatorObserver(),
        navigatorKey: Get.key,
        backTitle: L10n.of(context).back,
        child: AdaptiveEnvironmentHost(child: child ?? Container()),
      )),
    );
  }

  static TransitionBuilder? init({TransitionBuilder? builder}) {
    return (BuildContext context, Widget? child) => SystemUIOverlay(
          child: builder?.call(context, child),
        );
  }
}
