import 'dart:math' as math;

import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/widget/cupertino/sliver_list_section.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

/// Resolves safe insets for floating sheets, popovers, context menus, and
/// feedback banners so interactive controls never collide with iPhone side
/// safe areas (landscape Dynamic Island / notch) or vertical system / glass
/// navigation bars (such as iPhone Duo).
EdgeInsets resolvePopupSafeInsets(BuildContext context) {
  final media = MediaQuery.maybeOf(context);
  final size = media?.size ?? Size.zero;
  final padding = media?.padding ?? EdgeInsets.zero;
  final viewPadding = media?.viewPadding ?? EdgeInsets.zero;
  final viewInsets = media?.viewInsets ?? EdgeInsets.zero;

  var left = math.max(padding.left, viewPadding.left);
  var top = math.max(padding.top, viewPadding.top);
  var right = math.max(padding.right, viewPadding.right);
  var bottom = viewInsets.bottom > 0
      ? padding.bottom
      : math.max(padding.bottom, viewPadding.bottom);

  final scopedEnv = AdaptiveEnvironment.maybeOf(context);
  final serviceEnv = Get.isRegistered<AdaptiveEnvironmentService>()
      ? Get.find<AdaptiveEnvironmentService>().snapshot.value
      : null;

  void mergeSnapshot(AdaptiveEnvironmentSnapshot? env) {
    if (env == null || env.size.isEmpty) {
      return;
    }
    if (!size.isEmpty && !env.isCompatibleWith(size)) {
      return;
    }
    left = math.max(left, env.safeArea.left);
    top = math.max(top, env.safeArea.top);
    right = math.max(right, env.safeArea.right);
    if (viewInsets.bottom <= 0) {
      bottom = math.max(bottom, env.safeArea.bottom);
    }
    for (final region in env.activeOcclusionRegions) {
      final f = region.frame;
      if (f.left <= 24 && f.right < env.size.width * 0.45) {
        left = math.max(left, f.right);
      }
      if (f.right >= env.size.width - 24 && f.left > env.size.width * 0.55) {
        right = math.max(right, env.size.width - f.left);
      }
      if (f.top <= 24 && f.bottom < env.size.height * 0.25) {
        top = math.max(top, f.bottom);
      }
    }
  }

  mergeSnapshot(scopedEnv);
  mergeSnapshot(serviceEnv);

  return EdgeInsets.fromLTRB(left, top, right, bottom);
}

/// Collects active hardware division regions (such as an iPhone Duo book hinge
/// or tabletop fold) that match [targetSize] in root-overlay coordinates.
List<Rect> resolvePopupDivisionRects(
  BuildContext context, {
  Size? targetSize,
}) {
  final effectiveSize = targetSize ?? MediaQuery.maybeOf(context)?.size ?? Size.zero;
  final scopedEnv = AdaptiveEnvironment.maybeOf(context);
  final serviceEnv = Get.isRegistered<AdaptiveEnvironmentService>()
      ? Get.find<AdaptiveEnvironmentService>().snapshot.value
      : null;

  final result = <Rect>[];
  void collectFrom(AdaptiveEnvironmentSnapshot? env) {
    if (env == null || env.size.isEmpty) {
      return;
    }
    if (!effectiveSize.isEmpty && !env.isCompatibleWith(effectiveSize)) {
      return;
    }
    for (final region in env.activeDivisionRegions) {
      final f = region.frame;
      final alreadyAdded = result.any(
        (r) =>
            (r.left - f.left).abs() < 0.5 &&
            (r.top - f.top).abs() < 0.5 &&
            (r.width - f.width).abs() < 0.5 &&
            (r.height - f.height).abs() < 0.5,
      );
      if (!alreadyAdded) {
        result.add(f);
      }
    }
  }

  collectFrom(scopedEnv);
  collectFrom(serviceEnv);
  return result;
}

/// Splits [safeBounds] around any [divisionRects] (vertical book folds or
/// horizontal tabletop folds) and returns the single pane containing [anchorRect]
/// so floating menus and lifted cards never straddle a hinge or spill into an
/// adjacent pane.
Rect constrainBoundsToAnchorPane({
  required Rect safeBounds,
  required Rect anchorRect,
  required Iterable<Rect> divisionRects,
}) {
  var panes = <Rect>[safeBounds];
  for (final division in divisionRects) {
    final fold = division.intersect(safeBounds);
    if (fold.isEmpty) {
      continue;
    }
    final isVertical = fold.height >= fold.width;
    final next = <Rect>[];
    for (final pane in panes) {
      if (!fold.overlaps(pane)) {
        next.add(pane);
        continue;
      }
      if (isVertical) {
        final left = Rect.fromLTRB(
          pane.left,
          pane.top,
          math.min(fold.left, pane.right),
          pane.bottom,
        );
        final right = Rect.fromLTRB(
          math.max(fold.right, pane.left),
          pane.top,
          pane.right,
          pane.bottom,
        );
        if (left.width > 0 && left.height > 0) {
          next.add(left);
        }
        if (right.width > 0 && right.height > 0) {
          next.add(right);
        }
      } else {
        final top = Rect.fromLTRB(
          pane.left,
          pane.top,
          pane.right,
          math.min(fold.top, pane.bottom),
        );
        final bottom = Rect.fromLTRB(
          pane.left,
          math.max(fold.bottom, pane.top),
          pane.right,
          pane.bottom,
        );
        if (top.width > 0 && top.height > 0) {
          next.add(top);
        }
        if (bottom.width > 0 && bottom.height > 0) {
          next.add(bottom);
        }
      }
    }
    if (next.isNotEmpty) {
      panes = next;
    }
  }

  if (panes.length <= 1) {
    return panes.first;
  }

  Rect? bestByOverlap;
  var bestOverlapArea = 0.0;
  for (final pane in panes) {
    final inter = pane.intersect(anchorRect);
    if (!inter.isEmpty) {
      final area = inter.width * inter.height;
      if (area > bestOverlapArea) {
        bestOverlapArea = area;
        bestByOverlap = pane;
      }
    }
  }
  if (bestByOverlap != null) {
    return bestByOverlap;
  }

  final anchorCenter = anchorRect.center;
  Rect bestByDistance = panes.first;
  var bestDistSq = double.infinity;
  for (final pane in panes) {
    final cx = anchorCenter.dx.clamp(pane.left, pane.right).toDouble();
    final cy = anchorCenter.dy.clamp(pane.top, pane.bottom).toDouble();
    final dx = anchorCenter.dx - cx;
    final dy = anchorCenter.dy - cy;
    final distSq = dx * dx + dy * dy;
    if (distSq < bestDistSq) {
      bestDistSq = distSq;
      bestByDistance = pane;
    }
  }
  return bestByDistance;
}

/// Resolves safe usable bounds inside a single unobstructed pane (avoiding side
/// rails, software keyboard, AND any active Duo book/tabletop division region).
///
/// When [preferredAnchor] is provided, selects the pane containing that anchor;
/// otherwise selects the largest single unobstructed pane so floating banners
/// and sheets never straddle a hinge.
Rect resolveSinglePaneSafeBounds(
  BuildContext context, {
  Rect? preferredAnchor,
  Iterable<Rect> extraDivisionRects = const <Rect>[],
}) {
  final size = MediaQuery.sizeOf(context);
  final viewInsets = MediaQuery.viewInsetsOf(context);
  final safe = resolvePopupSafeInsets(context);

  final left = safe.left.clamp(0.0, size.width).toDouble();
  final top = safe.top.clamp(0.0, size.height).toDouble();
  final right = (size.width - safe.right).clamp(left, size.width).toDouble();
  final bottomInset = viewInsets.bottom > 0 ? viewInsets.bottom : safe.bottom;
  final bottom = (size.height - bottomInset).clamp(top, size.height).toDouble();
  final rawSafeBounds = Rect.fromLTRB(left, top, right, bottom);

  final liveDivisions = resolvePopupDivisionRects(context, targetSize: size);
  final divisions = liveDivisions.isNotEmpty
      ? liveDivisions
      : extraDivisionRects.toList(growable: false);
  if (divisions.isEmpty) {
    return rawSafeBounds;
  }

  if (preferredAnchor != null) {
    return constrainBoundsToAnchorPane(
      safeBounds: rawSafeBounds,
      anchorRect: preferredAnchor,
      divisionRects: divisions,
    );
  }

  // Split around all divisions and pick the largest unobstructed pane.
  var panes = <Rect>[rawSafeBounds];
  for (final division in divisions) {
    final fold = division.intersect(rawSafeBounds);
    if (fold.isEmpty) {
      continue;
    }
    final isVertical = fold.height >= fold.width;
    final next = <Rect>[];
    for (final pane in panes) {
      if (!fold.overlaps(pane)) {
        next.add(pane);
        continue;
      }
      if (isVertical) {
        final l = Rect.fromLTRB(
          pane.left,
          pane.top,
          math.min(fold.left, pane.right),
          pane.bottom,
        );
        final r = Rect.fromLTRB(
          math.max(fold.right, pane.left),
          pane.top,
          pane.right,
          pane.bottom,
        );
        if (l.width > 0 && l.height > 0) {
          next.add(l);
        }
        if (r.width > 0 && r.height > 0) {
          next.add(r);
        }
      } else {
        final t = Rect.fromLTRB(
          pane.left,
          pane.top,
          pane.right,
          math.min(fold.top, pane.bottom),
        );
        final b = Rect.fromLTRB(
          pane.left,
          math.max(fold.bottom, pane.top),
          pane.right,
          pane.bottom,
        );
        if (t.width > 0 && t.height > 0) {
          next.add(t);
        }
        if (b.width > 0 && b.height > 0) {
          next.add(b);
        }
      }
    }
    if (next.isNotEmpty) {
      panes = next;
    }
  }
  panes.sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));
  return panes.first;
}

/// Renders [LiquidGlassPopupSurface] when Liquid Glass popups are active, and
/// paints a clean superellipse raised-card fallback when Liquid Glass is off
/// (e.g. Android, Windows, or when the user disabled Liquid Glass in settings)
/// so popup content never floats naked over the screen.
Widget buildFavRuleGlassOrCardSurface({
  Key? key,
  required BuildContext context,
  required BorderRadius borderRadius,
  required Widget child,
}) {
  final glassActive = liquidGlassPopupsEnabled &&
      GlassMode.of(context).forComponent(flutterImplemented: true) !=
          GlassMode.off;

  Widget effectiveChild = child;
  if (!glassActive) {
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final raised = CupertinoDynamicColor.resolve(palette.raised, context);
    final borderColor = dark
        ? CupertinoDynamicColor.resolve(palette.edgeLight, context)
        : CupertinoDynamicColor.resolve(palette.hairline, context);

    effectiveChild = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, dark ? 0.44 : 0.16),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, dark ? 0.20 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRSuperellipse(
        borderRadius: borderRadius,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: raised,
            shape: RoundedSuperellipseBorder(
              borderRadius: borderRadius,
              side: BorderSide(color: borderColor, width: 0.5),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  return LiquidGlassPopupSurface(
    key: key,
    borderRadius: borderRadius,
    child: effectiveChild,
  );
}

/// Wraps modal sheet content in a detached Liquid Glass surface that strictly
/// clears horizontal/vertical safe areas, side rails, and the software keyboard.
Widget buildSafeFloatingSheet({
  required BuildContext context,
  required Widget child,
  double maxWidth = 500,
  double heightFactor = 0.88,
}) {
  final size = MediaQuery.sizeOf(context);
  final viewInsets = MediaQuery.viewInsetsOf(context);
  final paneBounds = resolveSinglePaneSafeBounds(context);

  final leftPad = paneBounds.left + 8.0;
  final rightPad = math.max(0.0, size.width - paneBounds.right) + 8.0;
  final topPad = paneBounds.top + 12.0;
  final rawBottomInset = math.max(0.0, size.height - paneBounds.bottom);
  final bottomPad = viewInsets.bottom > 0
      ? rawBottomInset + 8.0
      : math.max(rawBottomInset, 8.0);

  final availableHeight = math.max(0.0, size.height - topPad - bottomPad);
  final availableWidth = math.max(0.0, size.width - leftPad - rightPad);
  final constrainedMaxHeight = math.min(
    size.height * heightFactor,
    availableHeight,
  );
  final constrainedMaxWidth = math.min(maxWidth, availableWidth);

  return Padding(
    padding: EdgeInsets.fromLTRB(leftPad, topPad, rightPad, bottomPad),
    child: Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1.0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: constrainedMaxWidth,
          maxHeight: constrainedMaxHeight,
        ),
        child: buildFavRuleGlassOrCardSurface(
          context: context,
          borderRadius: const BorderRadius.all(Radius.circular(26)),
          child: child,
        ),
      ),
    ),
  );
}

/// Consistent grouped card decoration matching `EhPalette` light card shadows
/// and dark top/perimeter edge highlights.
ShapeDecoration groupedSectionDecoration(BuildContext context) {
  final palette = ehTheme.palette;
  final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
  final surface = palette.surface.resolveFrom(context);
  final borderColor = dark
      ? palette.edgeLight.resolveFrom(context)
      : palette.hairline.resolveFrom(context);

  return ShapeDecoration(
    color: surface,
    shadows: dark ? null : EhPalette.lightCardShadows,
    shape: RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(kInsetGroupedSectionRadius),
      side: BorderSide(color: borderColor, width: 0.5),
    ),
  );
}
