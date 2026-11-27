import 'dart:math' as math;

import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:oktoast/oktoast.dart' as oktoast;
import 'package:eros_fe/widget/eh_svg_icon.dart';

void showToast(
  String msg, {
  Duration duration = const Duration(seconds: 3),
  oktoast.ToastPosition? position =
      const oktoast.ToastPosition(align: Alignment.bottomCenter, offset: -60.0),
}) {
  final Widget widget = CupertinoTheme(
    data: Get.find<ThemeService>().themeData!,
    child: Container(
      margin: const EdgeInsets.all(50.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: CupertinoDynamicColor.resolve(
                    CupertinoColors.darkBackgroundGray, Get.context!)
                .withOpacity(0.16),
            offset: const Offset(0, 8),
            blurRadius: 20, //阴影模糊程度
            spreadRadius: 4, //阴影扩散程度
          ),
        ],
      ),
      child: EhPopupSurface(
        child: Container(
          padding: const EdgeInsets.all(10),
          color: liquidGlassPopupsEnabled
              ? null
              : CupertinoTheme.of(Get.context!).barBackgroundColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                msg,
                textScaler: const TextScaler.linear(0.8),
                style: CupertinoTheme.of(Get.context!).textTheme.textStyle,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  oktoast.showToastWidget(
    widget,
    position: position,
    duration: duration,
  );
}

// 同时间只显示一个。防止叠加
bool _isShowing509 = false;
void show509Toast() {
  if (_isShowing509) {
    return;
  }
  _isShowing509 = true;
  final Widget widget = ClipRect(
    child: CupertinoTheme(
      data: Get.find<ThemeService>().themeData!,
      child: EhPopupSurface(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EhSvgFaIcon(
                // LineIcons.toriiGate,
                FontAwesomeIcons.fill,
                size: 80,
                color: CupertinoColors.systemPink,
              ),
              Text(
                'IMAGE 509',
                textScaler: const TextScaler.linear(0.8),
                style: CupertinoTheme.of(Get.context!).textTheme.textStyle,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  oktoast.showToastWidget(
    widget,
    position: oktoast.ToastPosition.center,
    onDismiss: () => _isShowing509 = false,
    duration: 3.seconds,
  );
}

bool _isShowing429 = false;
void show429Toast() {
  if (_isShowing429) {
    return;
  }
  _isShowing429 = true;
  final Widget widget = ClipRect(
    child: CupertinoTheme(
      data: Get.find<ThemeService>().themeData!,
      child: EhPopupSurface(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EhSvgFaIcon(
                // LineIcons.toriiGate,
                FontAwesomeIcons.roadBarrier,
                size: 80,
                color: CupertinoColors.systemPink,
              ),
              Text(
                '429, Too Many Requests',
                textScaler: const TextScaler.linear(0.8),
                style: CupertinoTheme.of(Get.context!).textTheme.textStyle,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  oktoast.showToastWidget(
    widget,
    position: oktoast.ToastPosition.center,
    onDismiss: () => _isShowing429 = false,
    duration: 3.seconds,
  );
}

oktoast.ToastFuture? showActionToast(
  String msg, {
  IconData? icon,
  VoidCallback? onPressed,
  String? actionLabel,
  VoidCallback? onAction,
  bool loading = false,
  Duration duration = const Duration(seconds: 5),
  BuildContext? context,
}) {
  if (actionLabel != null || loading || icon == null) {
    final ctx = context ?? Get.context;
    final themeData = Get.isRegistered<ThemeService>()
        ? Get.find<ThemeService>().themeData
        : null;
    final palette = ehTheme.palette;
    final env = ctx != null ? AdaptiveEnvironment.maybeOf(ctx) : null;
    final safeBottom = ctx != null ? MediaQuery.paddingOf(ctx).bottom : 0.0;
    final bottomOffset = -(math.max(88.0, safeBottom + 72.0));
    EdgeInsets sideMargin = const EdgeInsets.symmetric(horizontal: 16);
    if (env != null && env.hasDuoVerticalBar) {
      final preferred = Rect.fromLTWH(
        16,
        math.max(0, env.size.height - 140),
        math.max(0, env.size.width - 32),
        52,
      );
      final safe = env.unoccludedControlRect(preferred);
      sideMargin = EdgeInsets.only(
        left: math.max(16.0, safe.left + 8),
        right: math.max(16.0, (env.size.width - safe.right) + 8),
      );
    }

    oktoast.ToastFuture? future;
    final toastWidget = Builder(
      builder: (toastContext) {
        final effectiveTheme =
            themeData ?? CupertinoTheme.of(toastContext);
        final accent = EhPalette.accent.resolveFrom(toastContext);
        final text1 = palette.text1.resolveFrom(toastContext);
        final handler = onAction ?? onPressed;
        return CupertinoTheme(
          data: effectiveTheme,
          child: Padding(
            padding: sideMargin,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440, minHeight: 48),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoDynamicColor.resolve(
                        CupertinoColors.darkBackgroundGray,
                        toastContext,
                      ).withValues(alpha: 0.18),
                      offset: const Offset(0, 8),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: EhPopupSurface(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      actionLabel != null ? 4 : 12,
                      actionLabel != null ? 8 : 16,
                      actionLabel != null ? 4 : 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (loading) ...<Widget>[
                          const CupertinoActivityIndicator(radius: 8),
                          const SizedBox(width: 10),
                        ],
                        Flexible(
                          child: Text(
                            msg,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: effectiveTheme.textTheme.textStyle.copyWith(
                              fontSize: 14,
                              color: text1,
                            ),
                          ),
                        ),
                        if (actionLabel != null && handler != null) ...<Widget>[
                          const SizedBox(width: 8),
                          CupertinoButton(
                            minimumSize: const Size(44, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            onPressed: () {
                              future?.dismiss();
                              handler();
                            },
                            child: Text(
                              actionLabel,
                              style: effectiveTheme.textTheme.textStyle.copyWith(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    future = oktoast.showToastWidget(
      toastWidget,
      position: oktoast.ToastPosition(
        align: Alignment.bottomCenter,
        offset: bottomOffset,
      ),
      duration: loading ? const Duration(minutes: 1) : duration,
      handleTouch: true,
      dismissOtherToast: true,
    );
    return future;
  }

  SmartDialog.show(
    alignment: Alignment.bottomCenter,
    useAnimation: true,
    displayTime: duration,
    // consumeEvent: true,
    usePenetrate: true,
    clickMaskDismiss: false,
    maskColor: Colors.transparent,
    builder: (_) => Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 100),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: CupertinoDynamicColor.resolve(
                    CupertinoColors.darkBackgroundGray, Get.context!)
                .withOpacity(0.16),
            offset: const Offset(0, 0),
            blurRadius: 20, //阴影模糊程度
            spreadRadius: 4, //阴影扩散程度
          ),
        ],
      ),
      child: ClipRect(
        child: CupertinoTheme(
          data: Get.find<ThemeService>().themeData!,
          child: EhPopupSurface(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    msg,
                    textScaler: const TextScaler.linear(0.8),
                    style: CupertinoTheme.of(Get.context!).textTheme.textStyle,
                    softWrap: true,
                  ),
                  CupertinoButton(
                    minSize: 20,
                    child: EhSvgIcon(
                      icon,
                      size: 18,
                    ),
                    padding: const EdgeInsets.only(left: 28),
                    onPressed: () {
                      SmartDialog.dismiss();
                      onPressed?.call();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return null;
}
