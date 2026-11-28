import 'dart:async';
import 'dart:math' as math;

import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/fav_rule.dart';
import 'package:eros_fe/models/favcat.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:eros_fe/widget/fav_rule_safe_area.dart';
import 'package:flutter/cupertino.dart';

/// Resolves the theme-aware `ThemeColors.catColor` for [rawCategory].
Color favRuleCategoryColor(BuildContext context, String rawCategory) {
  final canonical =
      canonicalizeFavRuleCategory(rawCategory) ?? rawCategory.trim();
  final raw = ThemeColors.catColor[canonical] ??
      ThemeColors.catColor['Misc'] ??
      CupertinoColors.activeBlue;
  return CupertinoDynamicColor.resolve(raw, context);
}

/// Computes high-contrast foreground text/icon color (`#FFFFFF` vs `#1A1406`)
/// against [background] following the approved WCAG luminance pivot.
Color favRuleOnCategoryColor(Color background) {
  double toLinear(double channel) {
    return channel <= 0.03928
        ? channel / 12.92
        : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  }

  final lum = 0.2126 * toLinear(background.r) +
      0.7152 * toLinear(background.g) +
      0.0722 * toLinear(background.b);
  final whiteContrast = 1.05 / (lum + 0.05);
  final darkContrast = (lum + 0.05) / (0.0331 + 0.05);
  return whiteContrast >= darkContrast
      ? const Color(0xFFFFFFFF)
      : const Color(0xFF1A1406);
}

/// Rounded category color badge (`18pt` / `20pt` / `28pt` / `34pt`) with
/// automatic WCAG foreground contrast, optional `negated` outline+strikethrough,
/// and optional trailing `×` remove action.
class FavCategoryBadge extends StatelessWidget {
  const FavCategoryBadge({
    super.key,
    required this.category,
    this.label,
    this.height = 28,
    this.borderRadius = 9,
    this.fontSize = 13.5,
    this.horizontalPadding = 11,
    this.negated = false,
    this.onRemove,
  });

  /// Compact `18pt` inline badge used in menu hit reasons and feedback banners.
  const FavCategoryBadge.mini({
    super.key,
    required this.category,
    this.label,
    this.negated = false,
  })  : height = 18,
        borderRadius = 5,
        fontSize = 11.5,
        horizontalPadding = 6,
        onRemove = null;

  /// `20pt` summary pill used in `FavRuleSettingPage` list rows.
  const FavCategoryBadge.compact({
    super.key,
    required this.category,
    this.label,
    this.negated = false,
  })  : height = 20,
        borderRadius = 6,
        fontSize = 12,
        horizontalPadding = 7,
        onRemove = null;

  final String category;
  final String? label;
  final double height;
  final double borderRadius;
  final double fontSize;
  final double horizontalPadding;
  final bool negated;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final canonical =
        canonicalizeFavRuleCategory(category) ?? category.trim();
    final displayText = (label != null && label!.trim().isNotEmpty)
        ? label!.trim()
        : canonical;
    final catColor = favRuleCategoryColor(context, canonical);
    final fg = negated ? catColor : favRuleOnCategoryColor(catColor);
    final rightPad = onRemove != null
        ? math.max(5.0, horizontalPadding - 3.0)
        : horizontalPadding;

    return Container(
      height: height,
      padding: EdgeInsets.only(left: horizontalPadding, right: rightPad),
      decoration: BoxDecoration(
        color: negated ? const Color(0x00000000) : catColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: negated ? Border.all(color: catColor, width: 1.5) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: Text(
              displayText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                height: 1.1,
                color: fg,
                decoration: negated
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                decorationColor: fg,
                decorationThickness: 1.5,
              ),
            ),
          ),
          if (onRemove != null) ...<Widget>[
            const SizedBox(width: 5),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: negated
                      ? catColor.withValues(alpha: 0.16)
                      : fg.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: EhSvgIcon(
                  CupertinoIcons.xmark,
                  size: 10,
                  color: fg,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Square rounded category color swatch (`14pt` / `22pt` / `28pt` / `46pt`).
class FavCategorySwatchSquare extends StatelessWidget {
  const FavCategorySwatchSquare({
    super.key,
    required this.category,
    this.size = 22,
    this.borderRadius = 7,
    this.child,
  });

  final String category;
  final double size;
  final double borderRadius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final bg = favRuleCategoryColor(context, category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// Shared 2-column 50pt folder tile grid used in both the Favorite Picker
/// sheet (Panel ②) and `FavRuleEditPage` (`收进`).
class FavFolderTwoColumnGrid extends StatelessWidget {
  const FavFolderTwoColumnGrid({
    super.key,
    required this.choices,
    required this.onSelect,
    this.selectedFavcat,
    this.lastUsedFavcat,
    this.useSurfaceCards = false,
  });

  final List<Favcat> choices;
  final ValueChanged<Favcat> onSelect;
  final String? selectedFavcat;
  final String? lastUsedFavcat;

  /// When `true` (e.g. on `FavRuleEditPage` over page canvas), tiles render on
  /// `palette.surface` with subtle card borders; when `false` (inside floating
  /// picker sheets), tiles render on neutral `palette.fill`.
  final bool useSurfaceCards;

  @override
  Widget build(BuildContext context) {
    if (choices.isEmpty) {
      return const SizedBox.shrink();
    }
    final rowCount = (choices.length + 1) ~/ 2;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var row = 0; row < rowCount; row++) ...<Widget>[
          if (row > 0) const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: _FavFolderGridTile(
                  fav: choices[row * 2],
                  selected: selectedFavcat != null &&
                      selectedFavcat!.isNotEmpty &&
                      choices[row * 2].favId == selectedFavcat,
                  isLastUsed: lastUsedFavcat != null &&
                      lastUsedFavcat!.isNotEmpty &&
                      choices[row * 2].favId == lastUsedFavcat,
                  useSurfaceCards: useSurfaceCards,
                  onTap: () => onSelect(choices[row * 2]),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: (row * 2 + 1 < choices.length)
                    ? _FavFolderGridTile(
                        fav: choices[row * 2 + 1],
                        selected: selectedFavcat != null &&
                            selectedFavcat!.isNotEmpty &&
                            choices[row * 2 + 1].favId == selectedFavcat,
                        isLastUsed: lastUsedFavcat != null &&
                            lastUsedFavcat!.isNotEmpty &&
                            choices[row * 2 + 1].favId == lastUsedFavcat,
                        useSurfaceCards: useSurfaceCards,
                        onTap: () => onSelect(choices[row * 2 + 1]),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _FavFolderGridTile extends StatelessWidget {
  const _FavFolderGridTile({
    required this.fav,
    required this.selected,
    required this.isLastUsed,
    required this.useSurfaceCards,
    required this.onTap,
  });

  final Favcat fav;
  final bool selected;
  final bool isLastUsed;
  final bool useSurfaceCards;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final favColor = CupertinoDynamicColor.resolve(
      ThemeColors.favColorFor(fav.favId),
      context,
    );
    final accent = EhPalette.accent.resolveFrom(context);
    final accentSoft = EhPalette.accentSoft.resolveFrom(context);
    final baseBg = useSurfaceCards
        ? palette.surface.resolveFrom(context)
        : palette.fill.resolveFrom(context);
    final text1 = palette.text1.resolveFrom(context);
    final text3 = palette.text3.resolveFrom(context);
    final hairline = palette.hairline.resolveFrom(context);
    final edgeLight = palette.edgeLight.resolveFrom(context);

    final bgColor = selected
        ? Color.alphaBlend(
            favColor.withValues(alpha: dark ? 0.20 : 0.10),
            baseBg,
          )
        : baseBg;
    final Border? border;
    if (selected) {
      border = Border.all(color: favColor, width: 1.5);
    } else if (useSurfaceCards) {
      border = Border.all(
        color: dark ? edgeLight : hairline,
        width: 0.5,
      );
    } else {
      border = null;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(15),
          border: border,
        ),
        child: Row(
          children: <Widget>[
            EhSvgIcon(
              CupertinoIcons.heart_fill,
              size: 16,
              color: favColor,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                fav.favTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: text1,
                ),
              ),
            ),
            if (isLastUsed) ...<Widget>[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  l10n.fav_rule_last_used_badge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
            ] else if (fav.totNum != null) ...<Widget>[
              const SizedBox(width: 6),
              Text(
                '${fav.totNum}',
                style: TextStyle(
                  fontSize: 13,
                  color: text3,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Option item displayed inside [showFavRulePullDownMenu].
class FavRulePullDownItem<T> {
  const FavRulePullDownItem({
    required this.value,
    required this.title,
    this.subtitle,
    this.destructive = false,
  });

  final T value;
  final String title;
  final String? subtitle;
  final bool destructive;
}

/// Opens a compact iOS Liquid Glass pull-down menu anchored to [anchorContext],
/// strictly clamped within the anchor's single unobstructed Duo pane.
Future<T?> showFavRulePullDownMenu<T>({
  required BuildContext anchorContext,
  required List<FavRulePullDownItem<T>> items,
  required T selectedValue,
  double width = 228,
}) {
  unawaited(vibrateUtil.selection());
  final overlay = Overlay.maybeOf(anchorContext, rootOverlay: true);
  final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
  final anchorBox = anchorContext.findRenderObject() as RenderBox?;

  Rect anchorRect;
  if (anchorBox != null &&
      anchorBox.hasSize &&
      !anchorBox.size.isEmpty &&
      overlayBox != null &&
      overlayBox.hasSize) {
    final topLeft = anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    anchorRect = topLeft & anchorBox.size;
  } else {
    final sz = MediaQuery.sizeOf(anchorContext);
    anchorRect = Rect.fromCenter(
      center: Offset(sz.width / 2, sz.height * 0.3),
      width: 80,
      height: 30,
    );
  }

  return Navigator.of(anchorContext, rootNavigator: true).push<T>(
    PageRouteBuilder<T>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: const Color(0x00000000),
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (routeContext, animation, _) {
        final screen = MediaQuery.sizeOf(routeContext);
        final pane = resolveSinglePaneSafeBounds(
          routeContext,
          preferredAnchor: anchorRect,
        );
        final marginH = math.min(10.0, pane.width * 0.1);
        final menuW = math.min(
          width,
          math.max(0.0, pane.width - marginH * 2),
        );
        final left = anchorRect.left
            .clamp(
              pane.left + marginH,
              math.max(pane.left + marginH, pane.right - marginH - menuW),
            )
            .toDouble();
        final marginV = math.min(10.0, pane.height * 0.1);
        final minY = pane.top + marginV;
        final maxY = math.max(minY, pane.bottom - marginV);
        final paneMaxH = math.max(0.0, maxY - minY);
        final estH = items.fold<double>(
          4.0,
          (sum, item) =>
              sum +
              ((item.subtitle != null && item.subtitle!.isNotEmpty)
                  ? 62.0
                  : 44.0),
        );
        final desiredBelowTop = anchorRect.bottom + 6.0;
        final desiredAboveBottom = anchorRect.top - 6.0;
        final spaceBelow =
            math.max(0.0, maxY - math.max(minY, desiredBelowTop));
        final spaceAbove =
            math.max(0.0, math.min(maxY, desiredAboveBottom) - minY);

        late final bool fitsBelow;
        double? top;
        double? bottom;
        late final double maxMenuH;
        if (spaceBelow >= estH) {
          fitsBelow = true;
          top = desiredBelowTop.clamp(minY, maxY).toDouble();
          maxMenuH = math.max(0.0, maxY - top);
        } else if (spaceAbove >= estH) {
          fitsBelow = false;
          final anchoredBottom = desiredAboveBottom.clamp(minY, maxY).toDouble();
          bottom = screen.height - anchoredBottom;
          maxMenuH = math.max(0.0, anchoredBottom - minY);
        } else if (spaceBelow >= spaceAbove) {
          fitsBelow = true;
          final targetH = math.min(estH, paneMaxH);
          top = desiredBelowTop
              .clamp(minY, math.max(minY, maxY - targetH))
              .toDouble();
          maxMenuH = math.max(0.0, maxY - top);
        } else {
          fitsBelow = false;
          final targetH = math.min(estH, paneMaxH);
          final anchoredBottom = desiredAboveBottom
              .clamp(math.min(maxY, minY + targetH), maxY)
              .toDouble();
          bottom = screen.height - anchoredBottom;
          maxMenuH = math.max(0.0, anchoredBottom - minY);
        }

        final alignX = menuW > 0
            ? (((anchorRect.center.dx - left) / menuW) * 2.0 - 1.0)
                .clamp(-0.85, 0.85)
                .toDouble()
            : 0.0;
        final scaleAnim = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        final fadeAnim = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );

        final palette = ehTheme.palette;
        final text1 = palette.text1.resolveFrom(routeContext);
        final text2 = palette.text2.resolveFrom(routeContext);
        final hairline = palette.hairline.resolveFrom(routeContext);
        final accent = EhPalette.accent.resolveFrom(routeContext);

        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(routeContext).pop(),
                child: const ColoredBox(color: Color(0x00000000)),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              bottom: bottom,
              width: menuW,
              child: FadeTransition(
                opacity: fadeAnim,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.90, end: 1.0).animate(scaleAnim),
                  alignment: Alignment(alignX, fitsBelow ? -1.0 : 1.0),
                  child: buildFavRuleGlassOrCardSurface(
                    context: routeContext,
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxMenuH),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.zero,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            for (var i = 0; i < items.length; i++) ...<Widget>[
                              if (i > 0) Container(height: 0.5, color: hairline),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  unawaited(vibrateUtil.selection());
                                  Navigator.of(routeContext).pop(items[i].value);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            Text(
                                              items[i].title,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: items[i].value ==
                                                        selectedValue
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                                color: items[i].destructive
                                                    ? CupertinoColors.systemRed
                                                        .resolveFrom(
                                                          routeContext,
                                                        )
                                                    : text1,
                                                decoration: TextDecoration.none,
                                              ),
                                            ),
                                            if (items[i].subtitle != null &&
                                                items[i]
                                                    .subtitle!
                                                    .isNotEmpty) ...<Widget>[
                                              const SizedBox(height: 2),
                                              Text(
                                                items[i].subtitle!,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: text2,
                                                  decoration:
                                                      TextDecoration.none,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (items[i].value == selectedValue) ...[
                                        const SizedBox(width: 8),
                                        EhSvgIcon(
                                          CupertinoIcons.checkmark_alt,
                                          size: 16,
                                          color: accent,
                                        ),
                                      ],
                                    ],
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
            ),
          ],
        );
      },
    ),
  );
}
