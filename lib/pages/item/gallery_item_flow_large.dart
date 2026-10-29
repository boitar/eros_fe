import 'dart:math' as math;

import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/pages/item/controller/galleryitem_controller.dart';
import 'package:eros_fe/utils/utility.dart';
import 'package:eros_fe/widget/rating_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import 'cover_ratio.dart';
import 'gallery_item.dart';
import 'item_base.dart';

/// Card corner. Chips on the cover sit at inset `i` with radius `16 − i`,
/// so every nested corner shares the card's centre of curvature.
const double kCardRadius = 16.0;
const int kTitleMaxLines = 2;

const BorderRadius _coverRadius =
    BorderRadius.vertical(top: Radius.circular(kCardRadius));

/// Overlays on cover art stop growing here; title, meta and tags still
/// follow Dynamic Type in full.
const double _kOverlayMaxTextScale = 1.35;

class GalleryItemFlowLarge extends StatelessWidget {
  const GalleryItemFlowLarge({
    super.key,
    required this.tabTag,
    required this.galleryProvider,
  });

  final dynamic tabTag;
  final GalleryProvider galleryProvider;

  GalleryItemController get galleryProviderController =>
      Get.find(tag: galleryProvider.gid);

  @override
  Widget build(BuildContext context) {
    final EhSettingService settings = Get.find();
    return Obx(() => settings.immersiveLargeCards
        ? _buildImmersive(context)
        : _buildStandard(context));
  }

  Widget _buildStandard(BuildContext context) {
    final controller = galleryProviderController;
    final GalleryProvider provider = controller.galleryProvider;

    return _PressScale(
      onTap: () => controller.onTap(tabTag),
      onLongPress: controller.onLongPress,
      child: _CardFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Cover(
              provider: provider,
              controller: controller,
              tabTag: tabTag,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
              child: _Info(
                controller: controller,
                provider: provider,
              ),
            ),
          ],
        ),
      ),
    ).autoCompressKeyboard(context);
  }

  /// Only the cover: title and rating sit on a deeper scrim at its foot.
  Widget _buildImmersive(BuildContext context) {
    final controller = galleryProviderController;
    final GalleryProvider provider = controller.galleryProvider;

    return _PressScale(
      onTap: () => controller.onTap(tabTag),
      onLongPress: controller.onLongPress,
      child: _CardFrame(
        child: _Cover(
          provider: provider,
          controller: controller,
          tabTag: tabTag,
          immersive: true,
        ),
      ),
    ).autoCompressKeyboard(context);
  }
}

/// Continuous-corner card. Light mode floats on a two-layer soft shadow;
/// dark mode has no shadow and catches light along its top edge instead.
class _CardFrame extends StatelessWidget {
  const _CardFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final hairline = CupertinoDynamicColor.resolve(palette.hairline, context);
    final edgeTop = dark
        ? Color.alphaBlend(
            CupertinoDynamicColor.resolve(palette.edgeLight, context), hairline)
        : hairline;

    return DecoratedBox(
      // A circular rect is indistinguishable from the superellipse under a
      // 14pt blur and keeps the shadow on the fast blur path.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kCardRadius),
        boxShadow: dark ? null : EhPalette.lightCardShadows,
      ),
      child: CustomPaint(
        foregroundPainter: _CardEdgePainter(top: edgeTop, line: hairline),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: CupertinoDynamicColor.resolve(palette.surface, context),
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(kCardRadius),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 0.5pt outline drawn over the cover, fading from [top] into [line].
class _CardEdgePainter extends CustomPainter {
  const _CardEdgePainter({required this.top, required this.line});

  final Color top;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 0.5;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    if (top == line) {
      paint.color = line;
    } else {
      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[top, line],
        stops: <double>[0, math.min(1, 28 / size.height)],
      ).createShader(rect);
    }
    canvas.drawRSuperellipse(
      RSuperellipse.fromRectAndRadius(
          rect, const Radius.circular(kCardRadius - stroke / 2)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CardEdgePainter oldDelegate) =>
      oldDelegate.top != top || oldDelegate.line != line;
}

/// Shrinks the card slightly while pressed. Skipped with Reduce Motion.
class _PressScale extends StatefulWidget {
  const _PressScale({
    required this.child,
    required this.onTap,
    required this.onLongPress,
  });

  final Widget child;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed && !reduceMotion ? 0.97 : 1,
        duration: Duration(milliseconds: _pressed ? 100 : 220),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({
    required this.provider,
    required this.controller,
    required this.tabTag,
    this.immersive = false,
  });

  final GalleryProvider provider;
  final GalleryItemController controller;
  final dynamic tabTag;

  /// The cover is the whole card and carries the title.
  final bool immersive;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final language = provider.translated?.trim() ?? '';
    final count = provider.filecount?.trim() ?? '';
    final category = provider.category?.trim() ?? '';
    final BorderRadius radius =
        immersive ? BorderRadius.circular(kCardRadius) : _coverRadius;

    return AspectRatio(
      aspectRatio: coverAspectRatio(
        imgWidth: provider.imgWidth ?? 0,
        imgHeight: provider.imgHeight ?? 0,
        maxRatio: kMaxLargeCoverAspectRatio,
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final decodeWidth = constraints.maxWidth.isFinite
            ? (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                .ceil()
            : null;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Static placeholder: one quiet tint instead of a spinner per card.
            DecoratedBox(
              decoration: ShapeDecoration(
                color: CupertinoDynamicColor.resolve(palette.fill, context),
                shape: RoundedSuperellipseBorder(borderRadius: radius),
              ),
            ),
            Hero(
              tag: '${provider.gid}_cover_$tabTag',
              child: ClipRSuperellipse(
                borderRadius: radius,
                child: CoverImg(
                  imgUrl: provider.imgUrl ?? '',
                  fit: BoxFit.cover,
                  // Very tall covers keep their top, where titles usually are.
                  alignment: Alignment.topCenter,
                  decodeWidth: decodeWidth,
                  fadeInDuration: const Duration(milliseconds: 180),
                  placeholder: (_) => const SizedBox.expand(),
                ),
              ),
            ),
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: _kOverlayMaxTextScale,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (immersive)
                    _BottomShade.deep(radius: radius)
                  else if (language.isNotEmpty || count.isNotEmpty)
                    const _BottomShade(),
                  if (category.isNotEmpty)
                    PositionedDirectional(
                      top: 7,
                      start: 7,
                      child: _CategoryChip(category: category),
                    ),
                  PositionedDirectional(
                    top: 6,
                    end: 6,
                    child: _FavoriteBadge(controller: controller),
                  ),
                  if (immersive)
                    PositionedDirectional(
                      start: 10,
                      end: 10,
                      bottom: 9,
                      child: _ImmersiveCaption(
                        controller: controller,
                        language: language,
                        count: count,
                      ),
                    )
                  else
                    PositionedDirectional(
                      start: 8,
                      end: 8,
                      bottom: 6,
                      child: Row(
                        children: <Widget>[
                          if (language.isNotEmpty)
                            Text(language, style: _overlayText),
                          const Spacer(),
                          if (count.isNotEmpty)
                            Text('${count}P',
                                style: _overlayText.copyWith(
                                  fontFeatures: const <FontFeature>[
                                    FontFeature.tabularFigures()
                                  ],
                                )),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

const TextStyle _overlayText = TextStyle(
  fontSize: 11,
  height: 1.2,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.2,
  color: CupertinoColors.white,
  shadows: <Shadow>[
    Shadow(color: Color(0x40000000), offset: Offset(0, 1), blurRadius: 2),
  ],
);

/// Darkens the bottom third of the cover so white labels stay legible on
/// bright art.
class _BottomShade extends StatelessWidget {
  const _BottomShade()
      : deep = false,
        radius = BorderRadius.zero;

  /// Covers the lower half, deep enough for a two-line title.
  const _BottomShade.deep({required this.radius}) : deep = true;

  final bool deep;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    if (deep) {
      return IgnorePointer(
        child: ClipRSuperellipse(
          borderRadius: radius,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: <Color>[
                  Color(0xCC08080C),
                  Color(0x9908080C),
                  Color(0x0008080C),
                ],
                stops: <double>[0, 0.3, 0.62],
              ),
            ),
          ),
        ),
      );
    }
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: <Color>[
              Color(0x8C08080C),
              Color(0x6108080C),
              Color(0x0008080C),
            ],
            stops: <double>[0, 0.14, 0.32],
          ),
        ),
      ),
    );
  }
}

/// Title and rating of an immersive card, white on the cover's scrim.
class _ImmersiveCaption extends StatelessWidget {
  const _ImmersiveCaption({
    required this.controller,
    required this.language,
    required this.count,
  });

  final GalleryItemController controller;
  final String language;
  final String count;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (language.isNotEmpty) language,
      if (count.isNotEmpty) '${count}P',
    ].join(' · ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          controller.title,
          maxLines: kTitleMaxLines,
          overflow: TextOverflow.ellipsis,
          style: _overlayText.copyWith(
            fontSize: 14,
            height: 1.25,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 5),
        Obx(() {
          final colorRating = controller.colorRating.trim();
          final filled = colorRating.isEmpty || colorRating == 'ir'
              ? EhPalette.star.darkColor
              : ThemeColors.colorRatingMap[colorRating] ??
                  EhPalette.star.darkColor;
          final score = controller.rating > 0
              ? controller.rating
              : controller.ratingFallBack;
          return Row(
            children: <Widget>[
              StaticRatingBar(
                size: 10,
                rate: controller.ratingFallBack,
                radiusRatio: 1.5,
                colorLight: filled,
                colorDark: const Color(0x52FFFFFF),
              ),
              if (score > 0) ...<Widget>[
                const SizedBox(width: 4),
                Text(score.toStringAsFixed(1), style: _overlayText),
              ],
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: _overlayText.copyWith(
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures()
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

/// Category as a dot and name on a scrim, never glass: glass stays out of
/// the content layer.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final mapped = ThemeColors.catColor[category];
    // The light variants are the saturated ones that read on a dark scrim.
    final dot = mapped is CupertinoDynamicColor
        ? mapped.color
        : mapped ?? CupertinoColors.systemGrey.color;

    return Container(
      constraints: const BoxConstraints(minHeight: 18),
      padding: const EdgeInsetsDirectional.fromSTEB(6, 2, 8, 2),
      decoration: const ShapeDecoration(
        color: EhPalette.scrim,
        shape: StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DecoratedBox(
            decoration:
                ShapeDecoration(color: dot, shape: const CircleBorder()),
            child: const SizedBox.square(dimension: 6),
          ),
          const SizedBox(width: 4),
          Text(
            category,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 11,
              height: 1.1,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              color: CupertinoColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Heart in the favourite folder's colour; absent when not favourited.
class _FavoriteBadge extends StatelessWidget {
  const _FavoriteBadge({required this.controller});

  final GalleryItemController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final color = ThemeColors.favColor[controller.favCat];
      if (color == null) {
        return const SizedBox.shrink();
      }
      // Folder 0 is a dark grey that would vanish on the scrim.
      final legible = color.computeLuminance() < 0.18
          ? Color.lerp(color, CupertinoColors.white, 0.45)!
          : color;
      return Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: const ShapeDecoration(
          color: EhPalette.scrim,
          shape: CircleBorder(),
        ),
        child: Icon(CupertinoIcons.heart_fill, size: 12, color: legible),
      );
    });
  }
}

class _Info extends StatelessWidget {
  const _Info({
    required this.controller,
    required this.provider,
  });

  final GalleryItemController controller;
  final GalleryProvider provider;

  @override
  Widget build(BuildContext context) {
    // Read per build: the palette follows the dark-style setting, and these
    // widgets rebuild with the theme because they resolve colours from it.
    final palette = ehTheme.palette;
    final text2 = CupertinoDynamicColor.resolve(palette.text2, context);
    final metaStyle = TextStyle(
      fontSize: 11,
      height: 1.2,
      color: text2,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          controller.title,
          maxLines: kTitleMaxLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            height: 1.3,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
            color: CupertinoDynamicColor.resolve(palette.text1, context),
          ),
        ),
        const SizedBox(height: 6),
        _MetaRow(
          controller: controller,
          postTime: provider.postTime,
          style: metaStyle,
        ),
        _CardTags(
          simpleTags: provider.simpleTags,
          overflowStyle: metaStyle,
          // The cover already names the language.
          hideLanguage: (provider.translated?.trim() ?? '').isNotEmpty,
        ),
      ],
    );
  }
}

/// The day of [postTime] (`yyyy-MM-dd HH:mm`); the year is dropped while it
/// is the current one, so the date fits a narrow pane next to the rating.
String compactCardDate(String? postTime, {DateTime? now}) {
  final day = (postTime ?? '').trim().split(' ').first;
  final year = '${(now ?? DateTime.now()).year}-';
  return day.length == 10 && day.startsWith(year)
      ? day.substring(year.length)
      : day;
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.controller,
    required this.postTime,
    required this.style,
  });

  final GalleryItemController controller;
  final String? postTime;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final date = compactCardDate(postTime);
    final empty = CupertinoDynamicColor.resolve(EhPalette.separator, context);

    return Obx(() {
      final colorRating = controller.colorRating.trim();
      final filled = colorRating.isEmpty || colorRating == 'ir'
          ? CupertinoDynamicColor.resolve(EhPalette.star, context)
          : ThemeColors.colorRatingMap[colorRating] ??
              CupertinoDynamicColor.resolve(EhPalette.star, context);
      final score =
          controller.rating > 0 ? controller.rating : controller.ratingFallBack;

      return Row(
        children: <Widget>[
          StaticRatingBar(
            size: 10,
            rate: controller.ratingFallBack,
            radiusRatio: 1.5,
            colorLight: filled,
            colorDark: empty,
          ),
          if (score > 0) ...<Widget>[
            const SizedBox(width: 4),
            Text(score.toStringAsFixed(1), style: style),
          ],
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              date,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: style,
            ),
          ),
        ],
      );
    });
  }
}

/// Up to two rows of capsules, then "+N". Watched tags keep the colour the
/// user gave them in My Tags, as a tint rather than a solid fill.
class _CardTags extends StatelessWidget {
  const _CardTags({
    required this.simpleTags,
    required this.overflowStyle,
    required this.hideLanguage,
  });

  final List<SimpleTag>? simpleTags;
  final TextStyle overflowStyle;
  final bool hideLanguage;

  @override
  Widget build(BuildContext context) {
    final EhSettingService settings = Get.find();
    return Obx(() {
      final source = hideLanguage
          ? simpleTags
              ?.where((tag) =>
                  !EHConst.iso936.containsKey(tag.text?.trim().toLowerCase()))
              .toList()
          : simpleTags;
      final tags = getLimitSimpleTags(source, settings.listViewTagLimit) ?? [];
      if (tags.isEmpty) {
        return const SizedBox.shrink();
      }
      final translate = settings.isTagTranslate;
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: LimitedWrap(
          spacing: 4,
          runSpacing: 4,
          maxRuns: 2,
          overflowStyle: overflowStyle,
          overflowPadding: const EdgeInsets.symmetric(horizontal: 3),
          children: <Widget>[
            for (final tag in tags)
              _CardTag(
                text: (translate ? tag.translat : tag.text) ?? tag.text ?? '',
                userColor: ColorsUtil.getTagColor(tag.backgrondColor),
              ),
          ],
        ),
      );
    });
  }
}

class _CardTag extends StatelessWidget {
  const _CardTag({required this.text, this.userColor});

  final String text;
  final Color? userColor;

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final watched = userColor != null;
    final background = watched
        ? userColor!.withValues(alpha: dark ? 0.28 : 0.18)
        : CupertinoDynamicColor.resolve(ThemeColors.tagBackground, context);
    final foreground = watched
        ? CupertinoDynamicColor.resolve(ehTheme.palette.text1, context)
        : CupertinoDynamicColor.resolve(ThemeColors.tagText, context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: ShapeDecoration(
        color: background,
        shape: const StadiumBorder(),
      ),
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          height: 1.1,
          fontWeight: watched ? FontWeight.w600 : FontWeight.w400,
          color: foreground,
        ),
      ),
    );
  }
}
