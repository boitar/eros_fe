import 'dart:math' as math;

import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:flutter/cupertino.dart';

/// Geometry shared by the macOS and Windows browsing shells. Mobile pane
/// budgets deliberately remain in AdaptiveEnvironmentSnapshot.
abstract final class DesktopBrowseStyle {
  static const radius = 16.0;
  static const windowsRadius = 10.0;
  static const inset = 8.0;
  static const sidebarWidth = 232.0;
  static const sidebarExtent = sidebarWidth + inset * 2;
  static const minimumWindowWidth = 800.0;
  static const toolbarHeight = 48.0;
  static const minimumListWidth = 400.0;
  static const minimumDetailWidth = 440.0;
  static const defaultRatio = .44;

  static double get paneRadius =>
      PlatformCapabilities.hostPlatform == TargetPlatform.windows
      ? windowsRadius
      : radius;

  static double get cardRadius =>
      PlatformCapabilities.hostPlatform == TargetPlatform.windows ? 8.0 : 10.0;

  /// Elevated neutral card surface inside a floating desktop pane.
  static Color cardSurface(BuildContext context) {
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    if (dark) {
      return palette.raised.resolveFrom(context);
    }
    return Color.alphaBlend(
      palette.fill.resolveFrom(context).withValues(alpha: .55),
      palette.surface.resolveFrom(context),
    );
  }

  static const List<BoxShadow> lightPaneShadows = <BoxShadow>[
    BoxShadow(color: Color(0x0A14161C), blurRadius: 12, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x0814161C), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// The open gallery and gutters use a lower surface than either panel.
  static Color canvas(BuildContext context) {
    final palette = ehTheme.palette;
    if (CupertinoTheme.brightnessOf(context) == Brightness.dark) {
      return palette.canvas.resolveFrom(context);
    }
    if (PlatformCapabilities.hostPlatform == TargetPlatform.windows) {
      return palette.canvas.resolveFrom(context);
    }
    return Color.alphaBlend(
      palette.text1.resolveFrom(context).withValues(alpha: .10),
      palette.canvas.resolveFrom(context),
    );
  }

  static bool canSplit(double width) =>
      width >= minimumListWidth + minimumDetailWidth + inset * 2;

  static double listWidth(double width, double ratio) {
    final space = math.max(0.0, width - inset * 2);
    if (space < minimumListWidth + minimumDetailWidth) return space;
    return (space * ratio.clamp(0.0, 1.0)).clamp(
      minimumListWidth,
      space - minimumDetailWidth,
    );
  }

  static Duration motion(BuildContext context, int milliseconds) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Duration(milliseconds: milliseconds);
}

/// One persistent content shell, including its toolbar, empty and error states.
/// Root overlays remain outside this clip, so menus can cross panel edges.
class DesktopPaneSurface extends StatelessWidget {
  const DesktopPaneSurface({
    super.key,
    required this.child,
    this.sidebar = false,
  });
  final Widget child;
  final bool sidebar;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final border = BorderRadius.circular(DesktopBrowseStyle.paneRadius);
    final contrast = MediaQuery.highContrastOf(context);
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final surface = palette.surface.resolveFrom(context);
    final fill = dark
        ? (sidebar
              ? Color.alphaBlend(
                  surface.withValues(alpha: .72),
                  palette.canvas.resolveFrom(context),
                )
              : surface)
        : (sidebar
              ? Color.alphaBlend(
                  const Color(0xFFF6F7FA).withValues(alpha: .94),
                  surface,
                )
              : surface);
    final outline = contrast
        ? palette.text2.resolveFrom(context)
        : palette.text1
              .resolveFrom(context)
              .withValues(alpha: dark ? .10 : .09);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: border,
        boxShadow: dark || contrast
            ? null
            : DesktopBrowseStyle.lightPaneShadows,
      ),
      child: ClipRRect(
        borderRadius: border,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: border,
            border: Border.all(color: outline, width: contrast ? 1.5 : 1),
          ),
          child: CupertinoTheme(
            data: CupertinoTheme.of(context)
                .copyWith(scaffoldBackgroundColor: fill),
            child: child,
          ),
        ),
      ),
    );
  }
}
