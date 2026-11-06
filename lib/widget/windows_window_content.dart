import 'dart:math' as math;

import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:flutter/widgets.dart';

/// Reserve the custom Windows titlebar outside the Navigator and its overlays.
/// Like MacOSWindowContent, descendants receive content-local geometry and no
/// residual top safe area, including headers that never consume SafeArea.
class WindowsWindowContent extends StatelessWidget {
  const WindowsWindowContent({
    super.key,
    required this.titleBarHeight,
    required this.child,
  });

  final double titleBarHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final media = MediaQuery.of(context);
      final top = titleBarHeight.clamp(0.0, constraints.maxHeight);
      final size = Size(
        constraints.maxWidth,
        math.max(0, constraints.maxHeight - top),
      );
      final environment =
          AdaptiveEnvironment.maybeOf(context) ??
          AdaptiveEnvironmentSnapshot.fromMediaQuery(context);
      final contentEnvironment = environment
          .inRect(Rect.fromLTWH(0, top, size.width, size.height))
          .copyWithGeometry(
            safeArea: media.padding.copyWith(top: 0),
            viewPadding: media.viewPadding.copyWith(top: 0),
            viewInsets: media.viewInsets,
          );
      return Padding(
        padding: EdgeInsets.only(top: top),
        child: AdaptiveEnvironmentScope(
          snapshot: contentEnvironment,
          child: MediaQuery(
            data: media.copyWith(
              size: size,
              padding: media.padding.copyWith(top: 0),
              viewPadding: media.viewPadding.copyWith(top: 0),
            ),
            child: child,
          ),
        ),
      );
    },
  );
}
