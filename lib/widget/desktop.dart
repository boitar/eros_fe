import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/widget/detail_window_backdrop.dart';
import 'package:eros_fe/widget/macos_window_chrome.dart';
import 'package:eros_fe/widget/windows_window_content.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:window_size/window_size.dart';

import 'sys_title.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';

class Desktop extends StatelessWidget {
  const Desktop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (PlatformCapabilities.hostPlatform == TargetPlatform.macOS) {
      return StreamBuilder<DesktopTitle>(
        stream: SysTitle.currentStream,
        builder: (context, snapshot) {
          final title = (snapshot.data ?? SysTitle.current)?.title ?? '';
          if (title.isNotEmpty) {
            setWindowTitle('$title · Eros-N');
          }
          return MacOSWindowContent(
            dragRegion: MoveWindow(child: const SizedBox.expand()),
            child: child,
          );
        },
      );
    }
    final mq = MediaQuery.of(context);
    final windows = PlatformCapabilities.hostPlatform == TargetPlatform.windows;
    return Stack(
      children: [
        if (windows)
          Positioned.fill(
            child: ColoredBox(
              key: const ValueKey('windows-window-canvas'),
              color: CupertinoTheme.of(context).scaffoldBackgroundColor,
            ),
          ),
        if (windows)
          Positioned.fill(
            child: WindowsWindowContent(
              titleBarHeight: appWindow.titleBarHeight,
              child: child,
            ),
          )
        else
          MediaQuery(
              data: mq.copyWith(
                  padding: mq.padding.copyWith(top: appWindow.titleBarHeight)),
              child: Positioned.fill(child: child)),
        Positioned(
            left: 0,
            top: 0,
            right: 0,
            height: appWindow.titleBarHeight,
            child: StreamBuilder<DesktopTitle>(
                stream: SysTitle.currentStream,
                builder: (context, snapshot) {
                  final data = snapshot.data ?? SysTitle.current;
                  final titleVisible = data?.titleVisible ?? true;
                  final buttonVisible = data?.buttonVisible ?? true;
                  final title = data?.title ?? '';
                  final palette = ehTheme.palette;

                  final titleWidget = titleVisible
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: EhPalette.accent.resolveFrom(context),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'E',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                  color: EhPalette.onAccent.resolveFrom(
                                    context,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Eros-N',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: palette.text1.resolveFrom(context),
                              ),
                            ),
                            if (title.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '· $title',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: palette.text2.resolveFrom(context),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        )
                      : null;
                  if (title != '') {
                    setWindowTitle('$title · Eros-N');
                  }

                  return ValueListenableBuilder<bool>(
                    valueListenable: DetailWindowBackdrop.active,
                    builder: (context, transparent, _) => DecoratedBox(
                      decoration: BoxDecoration(
                        border: transparent
                            ? null
                            : Border(
                                bottom: BorderSide(
                                  color: palette.hairline.resolveFrom(context),
                                  width: 0.5,
                                ),
                              ),
                      ),
                      child: WindowTitleBarBox(
                        child: Row(
                          children: [
                            Expanded(
                              child: MoveWindow(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 13),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: titleWidget,
                                  ),
                                ),
                              ),
                            ),
                            if (buttonVisible) const WindowButtons(),
                          ],
                        ),
                      ),
                    ),
                  );
                })),
      ],
    );
  }
}

final buttonColors = WindowButtonColors(
    iconNormal: const Color(0xFF171717),
    mouseOver: const Color(0x16000000),
    mouseDown: const Color(0x12000000),
    iconMouseOver: const Color(0xFF000000),
    iconMouseDown: const Color(0xFF5F5F5F));

final closeButtonColors = WindowButtonColors(
    iconNormal: const Color(0xFF171717),
    mouseOver: const Color(0xFFC42B1C),
    mouseDown: const Color(0xFFC83C31),
    iconMouseDown: const Color(0xFFEDBEBB),
    iconMouseOver: Colors.white);

final darkButtonColors = WindowButtonColors(
    iconNormal: const Color(0xFFF2F2F2),
    mouseOver: const Color(0x2DFFFFFF),
    mouseDown: const Color(0x29FFFFFF),
    iconMouseOver: const Color(0xFFFFFFFF),
    iconMouseDown: const Color(0xFFA7A7A7));

final darkCloseButtonColors = WindowButtonColors(
    iconNormal: const Color(0xFFF2F2F2),
    mouseOver: const Color(0xFFC42B1C),
    mouseDown: const Color(0xFFC83C31),
    iconMouseDown: const Color(0xFFEDBEBB),
    iconMouseOver: Colors.white);

class WindowButtons extends StatelessWidget {
  const WindowButtons({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    return Row(
      children: [
        WindowButton(
            colors: isDark ? darkButtonColors : buttonColors,
            padding: EdgeInsets.zero,
            iconBuilder: (buttonContext) {
              return EhSvgIcon(FluentIcons.line_horizontal_1_20_regular,
                  size: 16, color: buttonContext.iconColor);
            },
            onPressed: () => appWindow.minimize()),
        WindowButton(
            colors: isDark ? darkButtonColors : buttonColors,
            padding: EdgeInsets.zero,
            iconBuilder: (buttonContext) {
              final maximizeIcon = appWindow.isMaximized
                  ? FluentIcons.square_multiple_16_regular
                  : FluentIcons.maximize_16_regular;
              return EhSvgIcon(maximizeIcon,
                  size: 16, color: buttonContext.iconColor);
            },
            onPressed: () => appWindow.maximizeOrRestore()),
        WindowButton(
            colors: isDark ? darkCloseButtonColors : closeButtonColors,
            padding: EdgeInsets.zero,
            iconBuilder: (buttonContext) => EhSvgIcon(FluentIcons.dismiss_16_regular,
                size: 16, color: buttonContext.iconColor),
            onPressed: () => appWindow.close()),
      ],
    );
  }
}
