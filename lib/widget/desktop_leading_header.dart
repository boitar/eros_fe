import 'dart:math' as math;

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/widget/desktop_browse_style.dart';
import 'package:eros_fe/widget/desktop_control.dart';
import 'package:eros_fe/widget/macos_window_chrome.dart';
import 'package:flutter/cupertino.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';

/// The leftmost content pane owns the restore button when the sidebar is
/// hidden, including a single-column detail route. The navigator stays mounted.
class DesktopLeadingHeader extends StatelessWidget {
  const DesktopLeadingHeader({
    super.key,
    required this.enabled,
    required this.child,
    this.onShowSidebar,
  });
  final bool enabled;
  final Widget child;
  final VoidCallback? onShowSidebar;

  @override
  Widget build(BuildContext context) {
    final mac = PlatformCapabilities.hostPlatform == TargetPlatform.macOS;
    return Column(
      children: [
        if (enabled)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: ehTheme.palette.hairline.resolveFrom(context),
                ),
              ),
            ),
            child: SizedBox(
              height: DesktopBrowseStyle.toolbarHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 10, 0),
                child: Row(
                  children: [
                    if (mac)
                      ValueListenableBuilder<MacOSWindowControls>(
                        valueListenable: MacOSWindowChrome.controls,
                        builder: (_, controls, _) => SizedBox(
                          width: math.max(
                            0.0,
                            controls.leading - DesktopBrowseStyle.inset - 6.0,
                          ),
                        ),
                      ),
                    DesktopControl(
                      key: const ValueKey('desktop-show-sidebar'),
                      label: L10n.of(context).desktop_show_sidebar,
                      minSize: 30,
                      radius: 8,
                      onPressed: onShowSidebar,
                      padding: const EdgeInsets.all(6),
                      child: const EhSvgIcon(CupertinoIcons.sidebar_left, size: 17),
                    ),
                    Expanded(
                      child: mac
                          ? MoveWindow(child: const SizedBox.expand())
                          : const SizedBox.expand(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}
