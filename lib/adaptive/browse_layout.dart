import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'adaptive_environment.dart';

/// Describes the actual presentation, including the user's split preference.
class BrowsePaneScope extends InheritedWidget {
  const BrowsePaneScope({
    super.key,
    required this.split,
    required super.child,
  });
  final bool split;

  static bool isSplit(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BrowsePaneScope>()?.split ??
      false;

  @override
  bool updateShouldNotify(BrowsePaneScope oldWidget) =>
      split != oldWidget.split;
}

/// Resizes the same two content trees instead of replacing phone/tablet pages.
class AdaptiveBrowseLayout extends StatelessWidget {
  const AdaptiveBrowseLayout({
    super.key,
    required this.environment,
    required this.split,
    required this.detailActive,
    required this.primary,
    required this.detail,
    this.sideProportion = 0,
    this.divider,
  });

  final AdaptiveEnvironmentSnapshot environment;
  final bool split;
  final bool detailActive;
  final Widget primary;
  final Widget detail;
  final double sideProportion;
  final Widget? divider;

  @override
  Widget build(BuildContext context) {
    final bounds = Offset.zero & environment.size;
    final safe = environment.contentRect;
    final available = Rect.fromLTRB(safe.left, 0, safe.right, bounds.bottom);
    final panes = environment.paneRects;
    Rect primaryRect = available;
    Rect detailRect = available;
    Rect separator = Rect.zero;
    if (split) {
      if (environment.isBookFolded && panes.length == 2) {
        primaryRect = Rect.fromLTRB(
            panes.first.left, 0, panes.first.right, bounds.bottom);
        detailRect =
            Rect.fromLTRB(panes.last.left, 0, panes.last.right, bounds.bottom);
      } else {
        const minimum = AdaptiveEnvironmentSnapshot.minimumPaneWidth;
        final width = minimum +
            math.max(0.0, available.width - minimum * 2 - 1) *
                sideProportion.clamp(0.0, 1.0);
        primaryRect = Rect.fromLTWH(available.left, 0, width, available.height);
        detailRect = Rect.fromLTRB(
            primaryRect.right + 1, 0, available.right, bounds.bottom);
        separator = Rect.fromLTWH(primaryRect.right, 0, 1, bounds.height);
      }
    }

    Widget pane(Widget child, Rect rect, bool visible) => BrowsePaneScope(
          split: split,
          child: AdaptivePane(
            environment: environment,
            rect: rect,
            child: Offstage(
              offstage: !visible,
              child: TickerMode(
                enabled: visible,
                child: ExcludeFocus(
                  excluding: !visible,
                  child: Semantics(
                    container: true,
                    explicitChildNodes: true,
                    child: ClipRect(child: child),
                  ),
                ),
              ),
            ),
          ),
        );

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fromRect(
          rect: primaryRect,
          child: pane(primary, primaryRect, split || !detailActive),
        ),
        Positioned.fromRect(
          rect: detailRect,
          child: pane(detail, detailRect, split || detailActive),
        ),
        if (!separator.isEmpty)
          Positioned.fromRect(
            rect: separator,
            child: ColoredBox(
              color: CupertinoDynamicColor.resolve(
                  CupertinoColors.separator, context),
            ),
          ),
        if (split && !environment.isBookFolded && divider != null)
          Positioned(
            left: detailRect.left,
            top: 0,
            bottom: 0,
            child: divider!,
          ),
      ],
    );
  }
}
