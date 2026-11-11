import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/utils/gallery_title.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

/// Keeps the original Text untouched while the preference is off. Full titles
/// share a line budget between prefix, primary and alternate title.
class GalleryCardTitle extends StatelessWidget {
  const GalleryCardTitle({
    super.key,
    required this.legacy,
    this.lines = 3,
    this.waterfall = false,
    this.small = false,
    this.showTags = false,
    this.immersive = false,
    this.availableWidth,
    this.fullTitleStyle,
  });

  final Text legacy;
  final int lines;
  final bool waterfall;
  final bool small;
  final bool showTags;
  final bool immersive;

  /// List cards use IntrinsicHeight, which cannot ask a LayoutBuilder for
  /// intrinsic sizes. Their outer layout supplies the exact text width.
  final double? availableWidth;

  /// Applied only while the preference is on, so the switch-off path keeps the
  /// original [legacy] style untouched. List-Small uses it to pin the line
  /// height of the extra title line inside its fixed-height card.
  final TextStyle? fullTitleStyle;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!Get.find<EhSettingService>().fullTitleInGalleryPage) {
        return legacy;
      }
      final parts = GalleryTitleDisplay.split(legacy.data ?? '');
      final scale = MediaQuery.textScalerOf(context).scale(13.5) / 13.5;
      final budget = waterfall
          ? 2 + (parts.prefix.isNotEmpty ? 1 : 0) + (parts.hasSecondary ? 1 : 0)
          : small && scale > (showTags ? 1.0 : 1.1)
          ? 2
          : lines;
      if (availableWidth != null) {
        return _title(context, parts, budget, availableWidth!);
      }
      return LayoutBuilder(
        builder: (context, constraints) =>
            _title(context, parts, budget, constraints.maxWidth),
      );
    });
  }

  Widget _title(
    BuildContext context,
    GalleryTitleDisplay parts,
    int budget,
    double width,
  ) {
    final style = DefaultTextStyle.of(
      context,
    ).style.merge(legacy.style).merge(fullTitleStyle);
    final dim = style.copyWith(
      color: immersive
          ? const Color(0xB3FFFFFF)
          : ehTheme.palette.text2.resolveFrom(context),
      fontWeight: style.fontWeight == FontWeight.w600
          ? FontWeight.w500
          : style.fontWeight,
    );
    final prefix = budget >= 3 && parts.prefix.isNotEmpty;
    final remaining = budget - (prefix ? 1 : 0);
    final split = parts.hasSecondary && remaining >= 2;
    final primary = TextSpan(
      style: style,
      children: [
        TextSpan(text: parts.primary),
        if (!split && parts.hasSecondary)
          TextSpan(text: ' ${parts.secondary}', style: dim),
        if (!split) TextSpan(text: parts.suffix, style: dim),
      ],
    );
    final primaryLimit = split ? remaining - 1 : remaining;
    // Only a split title needs the measured line count; every other case gives
    // the alternate block the whole remainder.
    var used = 1;
    if (split && primaryLimit > 1) {
      final painter = TextPainter(
        text: primary,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        textAlign: legacy.textAlign ?? TextAlign.start,
        locale: Localizations.maybeLocaleOf(context),
        maxLines: primaryLimit,
        ellipsis: '…',
      )..layout(maxWidth: width.clamp(1, double.infinity));
      used = painter.computeLineMetrics().length.clamp(1, primaryLimit);
      painter.dispose();
    }
    final blocks = <Widget>[
      if (prefix)
        Text(
          parts.prefix.trimRight(),
          key: const ValueKey('card-title-prefix'),
          style: dim,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: legacy.textAlign,
        ),
      Text.rich(
        primary,
        key: const ValueKey('card-title-primary'),
        maxLines: primaryLimit,
        overflow: TextOverflow.ellipsis,
        textAlign: legacy.textAlign,
      ),
      if (split)
        Text(
          '${parts.secondary}${parts.suffix}',
          key: const ValueKey('card-title-secondary'),
          style: dim,
          maxLines: remaining - used,
          overflow: TextOverflow.ellipsis,
          textAlign: legacy.textAlign,
        ),
    ];
    return Semantics(
      label: parts.accessibilityLabel,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: blocks,
      ),
    );
  }
}
