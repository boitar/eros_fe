import 'dart:math' as math;

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/widget/desktop_control.dart';
import 'package:eros_fe/widget/macos_window_chrome.dart';
import 'package:flutter/cupertino.dart';

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
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: enabled ? 36 : 0,
        child: enabled
            ? Row(
                children: [
                  if (PlatformCapabilities.hostPlatform == TargetPlatform.macOS)
                    SizedBox(
                      width: math.max(
                        0,
                        MacOSWindowChrome.controls.value.leading - 8,
                      ),
                    ),
                  DesktopControl(
                    key: const ValueKey('desktop-show-sidebar'),
                    label: L10n.of(context).desktop_show_sidebar,
                    onPressed: onShowSidebar,
                    padding: const EdgeInsets.all(6),
                    child: const Icon(CupertinoIcons.sidebar_left, size: 18),
                  ),
                  Expanded(child: MoveWindow(child: const SizedBox.expand())),
                ],
              )
            : null,
      ),
      Expanded(child: child),
    ],
  );
}
