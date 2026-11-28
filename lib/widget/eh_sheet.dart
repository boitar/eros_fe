import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:eros_fe/widget/flutter_glass.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Strengths of the sheet material, tuned for text legibility.
///
/// The glass only draws the rim and refraction; content sits on a backing of
/// [EhPalette.raised]. With the dimming barrier in front of the page, text2
/// keeps at least 4.6:1 (light) / 4.8:1 (dark) against a pure black or pure
/// white cover behind the sheet.
abstract final class EhSheetTokens {
  static const double radius = 34;
  static const double inset = 8;
  static const double maxWidth = 440;

  /// Width from which a sheet floats in the middle instead of the bottom.
  static const double centeredFrom = 600;

  static double dimAlpha({required bool dark}) => dark ? .40 : .22;

  /// Light sheets sit on the canvas grey so white trays read as layers.
  static double backingAlpha({required bool dark}) => dark ? .80 : .92;

  /// Blur under the backing when the refractive shader is not used.
  static const double frostSigma = 24;
}

/// How a sheet is painted on this platform and setting.
enum EhSheetMaterial { glass, frosted, solid }

EhSheetMaterial ehSheetMaterialOf(BuildContext context) {
  if (!liquidGlassPopupsEnabled || MediaQuery.highContrastOf(context)) {
    return EhSheetMaterial.solid;
  }
  LiquidGlassAccessibilitySettings.watch();
  final reduce = LiquidGlassAccessibilitySettings.reduceTransparency.value;
  if (PlatformCapabilities.uiKitGlass ? reduce != false : reduce == true) {
    return EhSheetMaterial.solid;
  }
  final mode = GlassMode.of(context).forComponent(flutterImplemented: true);
  if (mode == GlassMode.off) {
    return EhSheetMaterial.solid;
  }
  if (mode == GlassMode.flutter && FlutterGlassRuntime.available) {
    return GlassPreference.materialOf(context).isLiquid
        ? EhSheetMaterial.glass
        : EhSheetMaterial.frosted;
  }
  return EhSheetMaterial.frosted;
}

/// Presents [builder] as a floating sheet drawn by Flutter.
///
/// Used everywhere the UIKit sheet is not: Android, desktop, and iOS with
/// the glass effect turned off.
Future<T?> showEhSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
  final barrierColor = Color.fromRGBO(
    0,
    0,
    0,
    EhSheetTokens.dimAlpha(dark: dark),
  );
  final triggerGlobalOffset = _triggerGlobalOffsetOf(context);
  final triggerGlobalX = triggerGlobalOffset?.dx;
  final triggerGlobalY = triggerGlobalOffset?.dy;
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  final triggerViewportSize =
      MediaQuery.maybeSizeOf(rootNavigator.context) ??
      MediaQuery.maybeSizeOf(context);
  final triggerViewportWidth = triggerViewportSize?.width;
  final triggerViewportHeight = triggerViewportSize?.height;
  final inheritedEnv =
      AdaptiveEnvironmentScope.maybeOf(rootNavigator.context) ??
      AdaptiveEnvironmentScope.maybeOf(context);
  if (!PlatformCapabilities.uiKitGlass) {
    final navigator = rootNavigator;
    final themes = InheritedTheme.capture(from: context, to: navigator.context);
    return navigator.push<T>(
      RawDialogRoute<T>(
        barrierDismissible: barrierDismissible,
        barrierLabel: CupertinoLocalizations.of(context)
            .modalBarrierDismissLabel,
        barrierColor: barrierColor,
        requestFocus: true,
        traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
        transitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        pageBuilder: (sheetContext, _, _) => themes.wrap(
          EhSheetFrame(
            triggerGlobalX: triggerGlobalX,
            triggerGlobalY: triggerGlobalY,
            triggerViewportWidth: triggerViewportWidth,
            triggerViewportHeight: triggerViewportHeight,
            environmentOverride: inheritedEnv,
            child: Builder(builder: builder),
          ),
        ),
        transitionBuilder: (context, animation, _, child) {
          final fade = animation.drive(CurveTween(curve: Curves.easeOut));
          final centered =
              PlatformCapabilities.isDesktop ||
              MediaQuery.sizeOf(context).width >= EhSheetTokens.centeredFrom;
          return FadeTransition(
            opacity: fade,
            child: centered
                ? child
                : SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, .08),
                      end: Offset.zero,
                    ).animate(fade),
                    child: child,
                  ),
          );
        },
      ),
    );
  }
  return showCupertinoModalPopup<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    builder: (sheetContext) => EhSheetFrame(
      triggerGlobalX: triggerGlobalX,
      triggerGlobalY: triggerGlobalY,
      triggerViewportWidth: triggerViewportWidth,
      triggerViewportHeight: triggerViewportHeight,
      environmentOverride: inheritedEnv,
      child: builder(sheetContext),
    ),
  );
}

Offset? _triggerGlobalOffsetOf(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is RenderBox &&
      renderObject.attached &&
      renderObject.hasSize) {
    return renderObject.localToGlobal(renderObject.size.center(Offset.zero));
  }
  return null;
}

/// Resolved positioning metrics for [EhSheetFrame], keeping sheets off foldable
/// hinges such as an unfolded iPhone Duo (both vertical and tabletop poses).
@immutable
class EhSheetPlacement {
  const EhSheetPlacement({
    required this.padding,
    required this.alignment,
    required this.maxWidth,
    this.maxHeight,
    required this.avoidsFold,
  });

  final EdgeInsets padding;
  final Alignment alignment;
  final double maxWidth;
  final double? maxHeight;
  final bool avoidsFold;
}

/// Positions the sheet: bottom-floating on phones, centred on wide windows,
/// aligned to a safe half-pane on unfolded/tabletop foldable displays, and
/// lifted above the keyboard.
class EhSheetFrame extends StatelessWidget {
  const EhSheetFrame({
    super.key,
    required this.child,
    this.triggerGlobalX,
    this.triggerGlobalY,
    this.triggerViewportWidth,
    this.triggerViewportHeight,
    this.environmentOverride,
  });

  /// Minimum width treated as an unfolded Duo inner display when native
  /// division regions are absent (e.g. laid flat at 180°).
  static const double duoInnerMinWidth = 900;
  static const double _duoMinAvoidWidth = 27;
  static const double _minHalfPaneWidth = 260;
  static const double _minHalfPaneHeight = 200;

  final Widget child;
  final double? triggerGlobalX;
  final double? triggerGlobalY;
  final double? triggerViewportWidth;
  final double? triggerViewportHeight;
  final AdaptiveEnvironmentSnapshot? environmentOverride;

  static EhSheetPlacement? _placeAroundFold({
    required Size viewportSize,
    required EdgeInsets safeArea,
    required double avoidLeft,
    required double avoidRight,
    required double? effectiveTriggerX,
  }) {
    const inset = EhSheetTokens.inset;
    final topPad = math.max(safeArea.top, inset);
    final bottomPad = math.max(safeArea.bottom, inset);
    final leftUsableStart = math.max(safeArea.left, 0.0);
    final rightUsableEnd = viewportSize.width - math.max(safeArea.right, 0.0);
    final leftPaneWidth = avoidLeft - leftUsableStart;
    final rightPaneWidth = rightUsableEnd - avoidRight;
    if (leftPaneWidth < _minHalfPaneWidth ||
        rightPaneWidth < _minHalfPaneWidth) {
      return null;
    }
    final useLeft =
        effectiveTriggerX != null && effectiveTriggerX < avoidLeft;
    final paneStart = useLeft ? leftUsableStart : avoidRight;
    final paneEnd = useLeft ? avoidLeft : rightUsableEnd;
    final paneWidth = math.max(0.0, paneEnd - paneStart - inset * 2);
    return EhSheetPlacement(
      padding: EdgeInsets.fromLTRB(
        paneStart + inset,
        topPad,
        (viewportSize.width - paneEnd) + inset,
        bottomPad,
      ),
      alignment: Alignment.bottomCenter,
      maxWidth: math.min(EhSheetTokens.maxWidth, paneWidth),
      avoidsFold: true,
    );
  }

  static EhSheetPlacement? _placeAroundHorizontalFold({
    required Size viewportSize,
    required EdgeInsets safeArea,
    required double avoidTop,
    required double avoidBottom,
    required double? effectiveTriggerY,
  }) {
    const inset = EhSheetTokens.inset;
    final leftPad = math.max(safeArea.left, inset);
    final rightPad = math.max(safeArea.right, inset);
    final topUsableStart = math.max(safeArea.top, 0.0);
    final bottomUsableEnd = viewportSize.height - math.max(safeArea.bottom, 0.0);
    final topPaneHeight = avoidTop - topUsableStart;
    final bottomPaneHeight = bottomUsableEnd - avoidBottom;
    final topUsable = topPaneHeight >= _minHalfPaneHeight;
    final bottomUsable = bottomPaneHeight >= _minHalfPaneHeight;
    if (!topUsable && !bottomUsable) {
      return null;
    }
    // Prefer the lower interactive pane in tabletop/portrait horizontal-fold
    // poses unless the trigger explicitly lives in the upper pane (or only the
    // upper pane has enough room).
    final useTop =
        !bottomUsable ||
        (topUsable &&
            effectiveTriggerY != null &&
            effectiveTriggerY < avoidTop);
    final paneTop = useTop ? topUsableStart : avoidBottom;
    final paneBottom = useTop ? avoidTop : bottomUsableEnd;
    final usableWidth = math.max(0.0, viewportSize.width - leftPad - rightPad);
    final paneHeight = math.max(0.0, paneBottom - paneTop - inset * 2);
    return EhSheetPlacement(
      padding: EdgeInsets.fromLTRB(
        leftPad,
        paneTop + inset,
        rightPad,
        (viewportSize.height - paneBottom) + inset,
      ),
      alignment: Alignment.bottomCenter,
      maxWidth: math.min(EhSheetTokens.maxWidth, usableWidth),
      maxHeight: paneHeight,
      avoidsFold: true,
    );
  }

  /// Resolves sheet placement for the given viewport, safe area, and optional
  /// [environment] division regions (iOS 27.1 Duo vertical & tabletop hinges).
  static EhSheetPlacement resolvePlacement({
    required Size viewportSize,
    required EdgeInsets safeArea,
    required bool isDesktop,
    AdaptiveEnvironmentSnapshot? environment,
    double? triggerGlobalX,
    double? triggerGlobalY,
    double? triggerViewportWidth,
    double? triggerViewportHeight,
  }) {
    const inset = EhSheetTokens.inset;
    final topPad = math.max(safeArea.top, inset);
    final bottomPad = math.max(safeArea.bottom, inset);
    // Ignore stale trigger coordinates if posture changed substantially.
    final effectiveTriggerX =
        (triggerViewportWidth != null &&
            (viewportSize.width - triggerViewportWidth).abs() > 100)
        ? null
        : triggerGlobalX;
    final effectiveTriggerY =
        (triggerViewportHeight != null &&
            (viewportSize.height - triggerViewportHeight).abs() > 100)
        ? null
        : triggerGlobalY;

    if (environment != null) {
      for (final region in environment.activeDivisionRegions) {
        final fold = region.frame;
        if (fold.width <= 0 && fold.height <= 0) {
          continue;
        }
        if (fold.height > fold.width) {
          final foldCenter = (fold.left + fold.right) / 2;
          final halfAvoid = math.max(fold.width, _duoMinAvoidWidth) / 2;
          final splitPlacement = _placeAroundFold(
            viewportSize: viewportSize,
            safeArea: safeArea,
            avoidLeft: foldCenter - halfAvoid,
            avoidRight: foldCenter + halfAvoid,
            effectiveTriggerX: effectiveTriggerX,
          );
          if (splitPlacement != null) {
            return splitPlacement;
          }
        } else {
          final foldCenter = (fold.top + fold.bottom) / 2;
          final halfAvoid = math.max(fold.height, _duoMinAvoidWidth) / 2;
          final tabletopPlacement = _placeAroundHorizontalFold(
            viewportSize: viewportSize,
            safeArea: safeArea,
            avoidTop: foldCenter - halfAvoid,
            avoidBottom: foldCenter + halfAvoid,
            effectiveTriggerY: effectiveTriggerY,
          );
          if (tabletopPlacement != null) {
            return tabletopPlacement;
          }
        }
      }

      // When laid flat (180°), UIKit does not report an active division region
      // on iPhone Duo, so split strictly around the physical midline (±13.5pt)
      // only when confirmed to be an unfolded Duo inner display.
      if (environment.nativeSupported &&
          environment.duoVerticalBar &&
          viewportSize.width >= duoInnerMinWidth) {
        final midline = viewportSize.width / 2;
        const halfAvoid = _duoMinAvoidWidth / 2;
        final splitPlacement = _placeAroundFold(
          viewportSize: viewportSize,
          safeArea: safeArea,
          avoidLeft: midline - halfAvoid,
          avoidRight: midline + halfAvoid,
          effectiveTriggerX: effectiveTriggerX,
        );
        if (splitPlacement != null) {
          return splitPlacement;
        }
      }
    }

    final centered = isDesktop || viewportSize.width >= EhSheetTokens.centeredFrom;
    final leftPad = math.max(safeArea.left, inset);
    final rightPad = math.max(safeArea.right, inset);
    final usableWidth = math.max(0.0, viewportSize.width - leftPad - rightPad);
    return EhSheetPlacement(
      padding: EdgeInsets.fromLTRB(leftPad, topPad, rightPad, bottomPad),
      alignment: centered ? Alignment.center : Alignment.bottomCenter,
      maxWidth: math.min(EhSheetTokens.maxWidth, usableWidth),
      avoidsFold: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final liveServiceEnv = Get.isRegistered<AdaptiveEnvironmentService>()
        ? Get.find<AdaptiveEnvironmentService>().snapshot.value
        : null;
    final env =
        AdaptiveEnvironmentScope.maybeOf(context) ??
        (liveServiceEnv != null && !liveServiceEnv.size.isEmpty
            ? liveServiceEnv
            : null) ??
        environmentOverride;
    final placement = resolvePlacement(
      viewportSize: media.size,
      safeArea: media.padding,
      isDesktop: PlatformCapabilities.isDesktop,
      environment: env,
      triggerGlobalX: triggerGlobalX,
      triggerGlobalY: triggerGlobalY,
      triggerViewportWidth: triggerViewportWidth,
      triggerViewportHeight: triggerViewportHeight,
    );
    return AnimatedPadding(
      duration: media.disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: Padding(
          padding: placement.padding,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxHeight = placement.maxHeight != null
                  ? math.min(placement.maxHeight!, constraints.maxHeight)
                  : constraints.maxHeight;
              return Align(
                alignment: placement.alignment,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: math.min(
                      placement.maxWidth,
                      constraints.maxWidth,
                    ),
                    maxHeight: maxHeight,
                  ),
                  child: EhSheetSurface(child: child),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The sheet material: refractive glass, frosted blur or a solid card, each
/// with the legibility backing from [EhSheetTokens].
class EhSheetSurface extends StatelessWidget {
  const EhSheetSurface({
    super.key,
    required this.child,
    this.radius = EhSheetTokens.radius,
  });

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool?>(
      valueListenable: LiquidGlassAccessibilitySettings.reduceTransparency,
      builder: (context, _, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final material = ehSheetMaterialOf(context);
    final borderRadius = BorderRadius.circular(radius);
    final raised = dark
        ? palette.raised.resolveFrom(context)
        : palette.canvas.resolveFrom(context);
    final backing = material == EhSheetMaterial.solid
        ? raised
        : raised.withValues(alpha: EhSheetTokens.backingAlpha(dark: dark));
    final rim = dark ? const Color(0x29FFFFFF) : const Color(0xB3FFFFFF);

    final content = DefaultTextStyle(
      style: EhPopupTextStyles.body(context)
          .copyWith(color: palette.text1.resolveFrom(context)),
      child: child,
    );

    final painted = DecoratedBox(
      decoration: BoxDecoration(
        color: backing,
        borderRadius: borderRadius,
        border: material == EhSheetMaterial.solid
            ? Border.all(
                color: palette.hairline.resolveFrom(context),
                width: .5,
              )
            : Border.all(color: rim, width: .75),
      ),
      child: content,
    );

    final Widget body;
    switch (material) {
      case EhSheetMaterial.glass:
        body = GlassContainer(
          useOwnLayer: true,
          quality: GlassPreference.materialOf(context).quality,
          shape: LiquidRoundedSuperellipse(borderRadius: radius),
          child: painted,
        );
      case EhSheetMaterial.frosted:
        body = ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: EhSheetTokens.frostSigma,
              sigmaY: EhSheetTokens.frostSigma,
            ),
            child: painted,
          ),
        );
      case EhSheetMaterial.solid:
        body = ClipRRect(borderRadius: borderRadius, child: painted);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, dark ? .45 : .18),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: body,
    );
  }
}

/// Grabber, close button, centred title and an optional trailing action.
class EhSheetHeader extends StatelessWidget {
  const EhSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onClose,
    this.trailing,
    this.closeLabel,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onClose;
  final Widget? trailing;
  final String? closeLabel;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final base = CupertinoTheme.of(context).textTheme.textStyle;
    final actionWidth =
        PlatformCapabilities.hostPlatform == TargetPlatform.android
        ? 48.0
        : 44.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!PlatformCapabilities.isDesktop) ...[
            Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: palette.text3
                    .resolveFrom(context)
                    .withValues(alpha: .45),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 6),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                SizedBox(
                  width: actionWidth,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: EhButton(
                      icon: CupertinoIcons.xmark,
                      style: EhButtonStyle.glass,
                      semanticLabel:
                          closeLabel ??
                          CupertinoLocalizations.of(context)
                              .modalBarrierDismissLabel,
                      onPressed: onClose ?? () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: base.copyWith(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                          color: palette.text1.resolveFrom(context),
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: base.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0,
                            color: palette.text2.resolveFrom(context),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(minWidth: actionWidth),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: trailing ?? const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A content tray inside a sheet: small text (sizes, prices, translations)
/// only ever sits on one of these.
class EhSheetGroup extends StatelessWidget {
  const EhSheetGroup({
    super.key,
    required this.children,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
    this.dividerIndent = 14,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry margin;
  final double dividerIndent;

  static Color trayColor(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return dark
        ? const Color(0x0FFFFFFF)
        : ehTheme.palette.surface.resolveFrom(context).withValues(alpha: .96);
  }

  @override
  Widget build(BuildContext context) {
    final separator = EhPalette.separator.resolveFrom(context);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: trayColor(context),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Padding(
                padding: EdgeInsetsDirectional.only(start: dividerIndent),
                child: Container(height: .5, color: separator),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Section caption above an [EhSheetGroup].
class EhSheetSectionLabel extends StatelessWidget {
  const EhSheetSectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 18, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                color: ehTheme.palette.text2.resolveFrom(context),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Option or action row inside an [EhSheetGroup], matching the native action list.
class EhSheetOptionRow extends StatelessWidget {
  const EhSheetOptionRow({
    super.key,
    required this.label,
    required this.icon,
    this.selected = false,
    this.enabled = true,
    this.showChevron = false,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final bool showChevron;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final base = CupertinoTheme.of(context).textTheme.textStyle
        .copyWith(letterSpacing: 0);
    final interactive = enabled && onPressed != null;
    final content = Opacity(
      opacity: enabled ? 1 : .38,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected
                      ? EhPalette.accentSoft.resolveFrom(context)
                      : palette.fill.resolveFrom(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: EhSvgIcon(
                  icon,
                  size: 17,
                  color: selected ? accent : palette.text2.resolveFrom(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: base.copyWith(
                    fontSize: 15.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: palette.text1.resolveFrom(context),
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                EhSvgIcon(
                  CupertinoIcons.checkmark_circle_fill,
                  size: 20,
                  color: accent,
                ),
              ] else if (showChevron && enabled) ...[
                const SizedBox(width: 8),
                EhSvgIcon(
                  CupertinoIcons.chevron_forward,
                  size: 14,
                  color: palette.text3.resolveFrom(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: interactive ? onPressed : null,
      child: EhPressable(
        onPressed: interactive ? onPressed : null,
        child: content,
      ),
    );
  }
}
