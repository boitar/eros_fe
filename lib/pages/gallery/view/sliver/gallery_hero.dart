import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:eros_fe/common/controller/download_controller.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_fav_controller.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_controller.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_state.dart';
import 'package:eros_fe/pages/gallery/view/gallery_title_sheet.dart';
import 'package:eros_fe/pages/gallery/view/rate_dialog.dart';
import 'package:eros_fe/pages/item/cover_ratio.dart';
import 'package:eros_fe/pages/item/gallery_item.dart';
import 'package:eros_fe/utils/gallery_title.dart';
import 'package:eros_fe/widget/rating_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Detail cover area: every cover gets the visual weight of a 168×240
/// portrait, whatever its shape, so wide covers are not shrunk to a strip.
const double kHeroCoverArea = 168.0 * 240.0;

/// Widest a cover may grow, for banner-shaped covers.
const double kHeroCoverMaxWidth = 280;

/// Corner shared with the list card, so the Hero flight keeps one shape.
const double kHeroCoverRadius = 16;

/// Widest the header column grows on iPad and unfolded iPhone Duo.
const double kHeroMaxWidth = 520;

/// Cover size at its real aspect ratio, limited to 1:2–2:1, with a constant
/// area. Unknown sizes fall back to the usual 210:300 portrait.
Size heroCoverSize(GalleryProvider? provider) {
  final ratio = coverAspectRatio(
    imgWidth: provider?.imgWidth ?? 0,
    imgHeight: provider?.imgHeight ?? 0,
    maxRatio: 2,
  );
  var width = math.sqrt(kHeroCoverArea * ratio);
  if (width > kHeroCoverMaxWidth) {
    width = kHeroCoverMaxWidth;
  }
  return Size(width.roundToDouble(), (width / ratio).roundToDouble());
}

bool _hasCoverSize(GalleryProvider? provider) =>
    (provider?.imgWidth ?? 0) > 0 && (provider?.imgHeight ?? 0) > 0;

/// The list's dimensions keep the Hero flight exact; a gallery opened from
/// a link only learns its size from the detail page.
GalleryProvider? heroCoverSource(
        GalleryProvider? initial, GalleryProvider? loaded) =>
    _hasCoverSize(initial) ? initial : loaded ?? initial;

/// Detail header: cover, title, byline, the primary actions and the
/// at-a-glance numbers. Replaces the side-by-side cover and title row.
class GalleryHeroSliver extends StatelessWidget {
  const GalleryHeroSliver({
    super.key,
    required this.initGalleryProvider,
    this.tabTag,
  });

  final GalleryProvider initGalleryProvider;
  final Object? tabTag;

  @override
  Widget build(BuildContext context) {
    final tag = pageCtrlTagOf(context);
    return SliverToBoxAdapter(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kHeroMaxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: GetBuilder<GalleryPageController>(
              assignId: true,
              id: GetIds.PAGE_VIEW_HEADER,
              tag: tag,
              builder: (logic) => _GalleryHero(
                controller: logic,
                initProvider: initGalleryProvider,
                tabTag: tabTag,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryHero extends StatelessWidget {
  const _GalleryHero({
    required this.controller,
    required this.initProvider,
    required this.tabTag,
  });

  final GalleryPageController controller;
  final GalleryProvider initProvider;
  final Object? tabTag;

  @override
  Widget build(BuildContext context) {
    final state = controller.gState;
    final provider = state.galleryProvider ?? initProvider;
    final fullTitle = state.displayTitle.isNotEmpty
        ? state.displayTitle
        : (provider.englishTitle ?? '');
    final parts = GalleryTitleParts.parse(fullTitle);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        HeroMode(
          enabled: state.hideNavigationBtn || isLayoutLarge,
          child: _HeroCover(
            // The list hands over the cover it already shows, so the flight
            // lands on the same image before the detail page has loaded.
            imageUrl: initProvider.imgUrl ?? provider.imgUrl ?? '',
            size: heroCoverSize(heroCoverSource(initProvider, provider)),
            heroTag: '${initProvider.gid}_cover_$tabTag',
            category: provider.category,
          ),
        ),
        const SizedBox(height: 20),
        _HeroTitle(
          title: parts.title,
          fullTitle: fullTitle,
          onPressed: () => showGalleryTitleSheet(
            context,
            englishTitle: provider.englishTitle ?? '',
            japaneseTitle: provider.japaneseTitle ?? '',
            showingJapanese: state.showingJapaneseTitle,
            onToggleLanguage: state.hasBothTitles
                ? () {
                    state.toggleDisplayTitleLanguage();
                    controller.update([GetIds.PAGE_VIEW_HEADER]);
                  }
                : null,
            onSearch: () => NavigatorUtil.goSearchPageWithParam(
                simpleSearch: 'title:"${parts.title}"'),
          ),
        ),
        if (parts.byline.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          _Byline(parts: parts),
        ],
        const SizedBox(height: 8),
        _MetaLine(provider: provider),
        const SizedBox(height: 20),
        _PrimaryActions(controller: controller),
        const SizedBox(height: 18),
        _DataStrip(provider: provider, state: state),
      ],
    );
  }
}

class _HeroCover extends StatelessWidget {
  const _HeroCover({
    required this.imageUrl,
    required this.size,
    required this.heroTag,
    required this.category,
  });

  final String imageUrl;
  final Size size;
  final Object heroTag;
  final String? category;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final decodeWidth =
        (size.width * MediaQuery.devicePixelRatioOf(context)).ceil();
    return Hero(
      tag: heroTag,
      // Animates once if a linked gallery learns its real shape on load.
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kHeroCoverRadius),
          // An object resting on the page: one soft, low shadow.
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x4D000000),
              blurRadius: 30,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: ClipRSuperellipse(
          borderRadius: BorderRadius.circular(kHeroCoverRadius),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ColoredBox(
                color: CupertinoDynamicColor.resolve(palette.surface, context),
              ),
              if (imageUrl.isNotEmpty)
                CoverImg(
                  imgUrl: imageUrl,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  decodeWidth: decodeWidth,
                  fadeInDuration: const Duration(milliseconds: 180),
                  placeholder: (_) => const SizedBox.expand(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroTitle extends StatelessWidget {
  const _HeroTitle({
    required this.title,
    required this.fullTitle,
    required this.onPressed,
  });

  final String title;
  final String fullTitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: fullTitle,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Text(
          title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            height: 1.25,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color:
                CupertinoDynamicColor.resolve(ehTheme.palette.text1, context),
          ),
        ),
      ),
    );
  }
}

/// "Circle · Artist" in the accent, since it is a search.
class _Byline extends StatelessWidget {
  const _Byline({required this.parts});

  final GalleryTitleParts parts;

  @override
  Widget build(BuildContext context) {
    final query = parts.artist.isNotEmpty
        ? 'artist:"${parts.artist}"'
        : 'group:"${parts.circle}"';
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      minimumSize: Size.zero,
      onPressed: () => NavigatorUtil.goSearchPageWithParam(simpleSearch: query),
      child: Text(
        parts.byline,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: CupertinoDynamicColor.resolve(EhPalette.accent, context),
        ),
      ),
    );
  }
}

/// Category dot · uploader · date.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.provider});

  final GalleryProvider provider;

  @override
  Widget build(BuildContext context) {
    final text2 = CupertinoDynamicColor.resolve(ehTheme.palette.text2, context);
    final style = TextStyle(fontSize: 13, height: 1.3, color: text2);
    final category = provider.category?.trim() ?? '';
    final uploader = provider.uploader?.trim() ?? '';
    final date = (provider.postTime ?? '').trim().split(' ').first;
    final dot = ThemeColors.catColor[category];

    final pieces = <Widget>[
      if (category.isNotEmpty)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DecoratedBox(
              decoration: ShapeDecoration(
                color: dot == null
                    ? text2
                    : CupertinoDynamicColor.resolve(dot, context),
                shape: const CircleBorder(),
              ),
              child: const SizedBox.square(dimension: 7),
            ),
            const SizedBox(width: 5),
            Text(category, style: style),
          ],
        ),
      if (uploader.isNotEmpty)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => NavigatorUtil.goSearchPageWithParam(
              simpleSearch: 'uploader:$uploader'),
          child: Text(uploader, style: style),
        ),
      if (date.isNotEmpty) Text(date, style: style),
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        for (var i = 0; i < pieces.length; i++) ...<Widget>[
          if (i > 0) Text('  ·  ', style: style),
          pieces[i],
        ],
      ],
    );
  }
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({required this.controller});

  final GalleryPageController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: _ReadCapsule(controller: controller)),
        const SizedBox(width: 10),
        const _FavoriteCircle(),
        const SizedBox(width: 10),
        _DownloadCircle(controller: controller),
      ],
    );
  }
}

/// The one filled control on the page: HIG gives the primary action a
/// coloured background.
class _ReadCapsule extends StatelessWidget {
  const _ReadCapsule({required this.controller});

  final GalleryPageController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.gState;
    final l10n = L10n.of(context);
    return Obx(() {
      final enabled = state.enableRead;
      final last = state.lastIndex;
      final accent = CupertinoDynamicColor.resolve(EhPalette.accent, context);
      return CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: enabled
            ? () => NavigatorUtil.goGalleryViewPage(last, state.gid,
                galleryTag: pageCtrlTagOf(context))
            : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: ShapeDecoration(
            color: enabled ? accent : accent.withValues(alpha: 0.4),
            shape: const StadiumBorder(),
          ),
          child: Text(
            last > 0 ? l10n.continue_reading_page(last + 1) : l10n.read,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: CupertinoDynamicColor.resolve(EhPalette.onAccent, context),
            ),
          ),
        ),
      );
    });
  }
}

/// 50pt circular secondary action on a quiet fill.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.child,
    required this.label,
    this.onTap,
    this.onLongPress,
    this.progress,
  });

  final Widget child;
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 0–1 ring around the button, for a running download.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final size = math.max(50.0, MediaQuery.textScalerOf(context).scale(50));
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: onTap ?? (onLongPress != null ? () {} : null),
          child: CustomPaint(
            foregroundPainter: progress == null
                ? null
                : _RingPainter(
                    progress: progress!,
                    color: CupertinoDynamicColor.resolve(
                        EhPalette.accent, context),
                    track: CupertinoDynamicColor.resolve(
                        palette.hairline, context),
                  ),
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color:
                    CupertinoDynamicColor.resolve(palette.fillPressed, context),
                shape: const CircleBorder(),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 2.5;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress.clamp(0, 1),
        false, paint..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}

class _FavoriteCircle extends StatelessWidget {
  const _FavoriteCircle();

  @override
  Widget build(BuildContext context) {
    final favorites =
        Get.find<GalleryFavController>(tag: pageCtrlTagOf(context));
    final l10n = L10n.of(context);
    return Obx(() {
      final isFav = favorites.isFav;
      return _RoundAction(
        label: isFav ? l10n.change_to_favorites : l10n.add_to_favorites,
        onTap: favorites.isLoading ? null : () => favorites.tapFav(),
        onLongPress: favorites.isLoading ? null : () => favorites.longTapFav(),
        child: favorites.isLoading
            ? const CupertinoActivityIndicator()
            : Icon(
                isFav ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                size: 23,
                color: isFav
                    ? ThemeColors.favColorFor(favorites.favcat)
                    : CupertinoDynamicColor.resolve(
                        ehTheme.palette.text1, context),
              ),
      );
    });
  }
}

class _DownloadCircle extends StatelessWidget {
  const _DownloadCircle({required this.controller});

  final GalleryPageController controller;

  DownloadController get _downloads => Get.find();

  @override
  Widget build(BuildContext context) {
    final state = controller.gState;
    final l10n = L10n.of(context);
    final text1 = CupertinoDynamicColor.resolve(ehTheme.palette.text1, context);
    return Obx(() {
      final status = state.downloadState;
      final gid = int.tryParse(state.gid) ?? 0;
      if (status == TaskStatus.complete) {
        return _RoundAction(
          label: l10n.downloaded,
          child: Icon(CupertinoIcons.checkmark_alt,
              size: 23,
              color: CupertinoDynamicColor.resolve(EhPalette.accent, context)),
        );
      }
      if (status == TaskStatus.running || status == TaskStatus.enqueued) {
        return _RoundAction(
          label: l10n.downloading,
          progress: state.downloadProcess / 100,
          onTap: () => status == TaskStatus.running
              ? _downloads.galleryTaskPaused(gid)
              : _downloads.galleryTaskResume(gid),
          child: Icon(CupertinoIcons.pause_fill, size: 20, color: text1),
        );
      }
      if (status == TaskStatus.paused) {
        return _RoundAction(
          label: l10n.paused,
          progress: state.downloadProcess / 100,
          onTap: () => _downloads.galleryTaskResume(gid),
          child: Icon(CupertinoIcons.play_fill, size: 20, color: text1),
        );
      }
      return _RoundAction(
        label: l10n.p_Download,
        onTap: () => controller.downloadGallery(context),
        child: Icon(CupertinoIcons.arrow_down_to_line, size: 22, color: text1),
      );
    });
  }
}

/// Rating, pages, language and size in four cells. Rating opens the rating
/// dialog; the rest open the full information page.
class _DataStrip extends StatelessWidget {
  const _DataStrip({required this.provider, required this.state});

  final GalleryProvider provider;
  final GalleryPageState state;

  void _openInfo() => Get.toNamed(EHRoutes.galleryInfo, id: detailNavigatorId);

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final divider = CupertinoDynamicColor.resolve(EhPalette.separator, context);
    final rating = provider.rating ?? 0;
    final canRate = provider.apiuid?.isNotEmpty ?? false;

    String orDash(String? value) =>
        (value?.trim().isNotEmpty ?? false) ? value!.trim() : '—';

    Widget separator() => Container(
          width: 0.5,
          height: 30,
          color: divider,
        );

    return Row(
      children: <Widget>[
        Expanded(
          child: _DataCell(
            value: rating > 0 ? rating.toStringAsFixed(2) : '—',
            caption: Obx(() {
              return StaticRatingBar(
                size: 11,
                rate: provider.ratingFallBack ?? 0,
                radiusRatio: 1.5,
                colorLight: state.isRatinged
                    ? ThemeColors
                        .colorRatingMap[provider.colorRating?.trim() ?? 'ir']
                    : CupertinoDynamicColor.resolve(EhPalette.star, context),
                colorDark:
                    CupertinoDynamicColor.resolve(EhPalette.separator, context),
              );
            }),
            semanticLabel: '${l10n.p_Rate} $rating',
            onTap: canRate ? () => showRateDialog(context) : _openInfo,
          ),
        ),
        separator(),
        Expanded(
          child: _DataCell(
            value: orDash(provider.filecount),
            caption: _caption(l10n.s_pages, palette, context),
            onTap: _openInfo,
          ),
        ),
        separator(),
        Expanded(
          child: _DataCell(
            value: orDash(provider.language),
            caption: _caption(l10n.tagNamespace('language'), palette, context),
            onTap: _openInfo,
          ),
        ),
        separator(),
        Expanded(
          child: _DataCell(
            value: orDash(provider.filesizeText),
            caption: _caption(l10n.file_size, palette, context),
            onTap: _openInfo,
          ),
        ),
      ],
    );
  }

  Widget _caption(String text, EhPalette palette, BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        color: CupertinoDynamicColor.resolve(palette.text2, context),
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  const _DataCell({
    required this.value,
    required this.caption,
    required this.onTap,
    this.semanticLabel,
  });

  final String value;
  final Widget caption;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures()
                    ],
                    color: CupertinoDynamicColor.resolve(
                        ehTheme.palette.text1, context),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              caption,
            ],
          ),
        ),
      ),
    );
  }
}

/// Blurred cover behind the top of the page. Liquid Glass picks up its
/// colour; it fades into the canvas before the title, so text never sits
/// on busy imagery. Moves at half the scroll speed.
class GalleryAmbientBackdrop extends StatelessWidget {
  const GalleryAmbientBackdrop({
    super.key,
    required this.imageUrl,
    required this.category,
    required this.height,
    required this.scrollOffset,
  });

  final String imageUrl;
  final String? category;
  final double height;
  final ValueListenable<double> scrollOffset;

  /// Saturation matrix; 1 keeps the colours.
  static List<double> saturation(double s) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    return <double>[
      r * (1 - s) + s, g * (1 - s), b * (1 - s), 0, 0, //
      r * (1 - s), g * (1 - s) + s, b * (1 - s), 0, 0, //
      r * (1 - s), g * (1 - s), b * (1 - s) + s, 0, 0, //
      0, 0, 0, 1, 0,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final EhSettingService settings = Get.find();
    return Obx(() {
      if (!settings.detailAmbientBackground) {
        return const SizedBox.shrink();
      }
      final privacy = settings.isGalleryImgBlur.value;
      final canvas =
          CupertinoDynamicColor.resolve(ehTheme.palette.canvas, context);
      final overlay = MediaQuery.highContrastOf(context) ? 0.6 : 0.4;

      final Widget art;
      if (imageUrl.isEmpty) {
        final tint = ThemeColors.catColor[category?.trim()];
        art = ColoredBox(
          color: tint == null
              ? canvas
              : Color.alphaBlend(
                  CupertinoDynamicColor.resolve(tint, context)
                      .withValues(alpha: 0.06),
                  canvas),
        );
      } else {
        final sigma = privacy ? 60.0 : 40.0;
        art = RepaintBoundary(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
                sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp),
            child: ColorFiltered(
              colorFilter: ColorFilter.matrix(saturation(privacy ? 0.6 : 1.15)),
              child: EhNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                // A 64px source is all a 40pt blur needs.
                decodeWidth: 64,
                placeholder: (_, __) => const SizedBox.expand(),
              ),
            ),
          ),
        );
      }

      final layers = SizedBox(
        height: height.roundToDouble(),
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // The fade is opaque from 88%, so the art can stop at 90%. This
              // keeps its edge under solid canvas instead of on the box edge,
              // where a fractional pixel would let one row of art through.
              Align(
                alignment: Alignment.topCenter,
                heightFactor: 1,
                child: FractionallySizedBox(
                  widthFactor: 1,
                  heightFactor: 0.9,
                  child: ClipRect(child: art),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      canvas.withValues(alpha: overlay),
                      canvas.withValues(alpha: overlay),
                      canvas,
                    ],
                    stops: const <double>[0, 0.36, 0.88],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      return IgnorePointer(
        child: ValueListenableBuilder<double>(
          valueListenable: scrollOffset,
          child: layers,
          builder: (context, pixels, child) {
            if (pixels > height * 2) {
              return const SizedBox.shrink();
            }
            return Transform.translate(
              offset: Offset(0, pixels > 0 ? -pixels * 0.5 : 0),
              child: child,
            );
          },
        ),
      );
    });
  }
}
