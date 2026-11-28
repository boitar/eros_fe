import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/controller/download_controller.dart';
import 'package:eros_fe/common/controller/favorite_state_store.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/controller/fav_controller.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_fav_controller.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_controller.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_state.dart';
import 'package:eros_fe/pages/gallery/view/favorite_note_edit_sheet.dart';
import 'package:eros_fe/pages/gallery/view/gallery_incremental_update_sheet.dart';
import 'package:eros_fe/pages/gallery/view/gallery_title_sheet.dart';
import 'package:eros_fe/pages/gallery/view/rate_dialog.dart';
import 'package:eros_fe/pages/gallery/view/taginfo_dialog.dart';
import 'package:eros_fe/pages/item/cover_ratio.dart';
import 'package:eros_fe/pages/item/gallery_item.dart';
import 'package:eros_fe/utils/gallery_title.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/fav_rule_widgets.dart';
import 'package:eros_fe/widget/favcat_grid.dart';
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

/// Android's glass detail page moves Read, Favourite and Download into a
/// floating bar at the bottom, so they stay in reach while the page scrolls.
bool usesGalleryActionDock(BuildContext context) =>
    PlatformCapabilities.topSearchCapsule &&
    GlassMode.of(context) != GlassMode.off;

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

/// Pixels the header cover decodes at. The backdrop asks for the same, so
/// both share one decode and appear in the same frame.
int heroCoverDecodeWidth(BuildContext context, double coverWidth) =>
    (coverWidth * MediaQuery.devicePixelRatioOf(context)).ceil();

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
    this.heroKey,
    this.topPadding = 8,
  });

  final GalleryProvider initGalleryProvider;
  final Object? tabTag;
  final Key? heroKey;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: GalleryHero(
        key: heroKey,
        initGalleryProvider: initGalleryProvider,
        tabTag: tabTag,
        topPadding: topPadding,
      ),
    );
  }
}

/// The header as a box, for the fixed side column of the two-column layout.
class GalleryHero extends StatelessWidget {
  const GalleryHero({
    super.key,
    required this.initGalleryProvider,
    this.tabTag,
    this.topPadding = defaultTopPadding,
  });

  static const double defaultTopPadding = 8;

  final GalleryProvider initGalleryProvider;
  final Object? tabTag;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final tag = pageCtrlTagOf(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kHeroMaxWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, topPadding, 20, 12),
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
    final setting = Get.find<EhSettingService>();
    return Obx(() {
      final state = controller.gState;
      final provider = state.galleryProvider ?? initProvider;
      final fullTitle = state.displayTitle.isNotEmpty
          ? state.displayTitle
          : (provider.englishTitle ?? '');
      final parts = GalleryTitleParts.parse(fullTitle);
      final showFullTitle = setting.fullTitleInGalleryPage;

      final titleAndMeta = Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GalleryHeroTitle(
            title: parts.title,
            fullTitle: fullTitle,
            showFullTitle: showFullTitle,
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
        ],
      );
      final scaledTitleAndMeta = showFullTitle
          ? MediaQuery.withClampedTextScaling(
              maxScaleFactor: 2.0,
              child: titleAndMeta,
            )
          : titleAndMeta;

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
          scaledTitleAndMeta,
          if (usesGalleryActionDock(context)) ...<Widget>[
            const SizedBox(height: 16),
            _FavNoteSection(controller: controller),
            const SizedBox(height: 16),
          ] else ...<Widget>[
            const SizedBox(height: 20),
            _PrimaryActions(controller: controller),
            _FavNoteSection(controller: controller),
            const SizedBox(height: 18),
          ],
          _DataStrip(provider: provider, state: state),
          GalleryLineageWhisper(
            provider: provider,
            isDownloadedComplete:
                state.downloadState == TaskStatus.complete,
            onTap: () => Get.toNamed(
              EHRoutes.galleryInfo,
              id: detailNavigatorId,
            ),
          ),
        ],
      );
    });
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
    final decodeWidth = heroCoverDecodeWidth(context, size.width);
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
                  // The list card's copy fills the first frames.
                  placeholder: (_) => ShownImage(
                    imageUrl,
                    alignment: Alignment.topCenter,
                  ),
                  placeholderWhileDecoding: true,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class GalleryHeroTitle extends StatelessWidget {
  const GalleryHeroTitle({
    super.key,
    required this.title,
    required this.fullTitle,
    this.showFullTitle = false,
    required this.onPressed,
  });

  final String title;
  final String fullTitle;
  final bool showFullTitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = showFullTitle
        ? GalleryTitleDisplay.split(fullTitle).accessibilityLabel
        : fullTitle;
    return Semantics(
      label: label,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: showFullTitle
            ? LayoutBuilder(
                builder: (context, constraints) =>
                    _buildFullTitle(context, constraints),
              )
            : Text(
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
                      CupertinoDynamicColor.resolve(
                          ehTheme.palette.text1, context),
                ),
              ),
      ),
    );
  }

  Widget _buildFullTitle(BuildContext context, BoxConstraints constraints) {
    final parts = GalleryTitleDisplay.split(fullTitle);
    final text1 =
        CupertinoDynamicColor.resolve(ehTheme.palette.text1, context);
    final text2 =
        CupertinoDynamicColor.resolve(ehTheme.palette.text2, context);
    final narrow = constraints.hasBoundedWidth && constraints.maxWidth < 320;
    final firstFontSize = narrow ? 18.0 : 20.0;
    final secondFontSize = narrow ? 15.0 : 17.0;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final extraLines = scale > 1.35 ? 2 : 0;
    final firstMaxLines = (parts.hasSecondary ? 4 : 5) + extraLines;
    final secondaryMaxLines = 3 + extraLines;

    final firstStyle = TextStyle(
      fontSize: firstFontSize,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: text1,
    );
    final secondaryStyle = TextStyle(
      fontSize: secondFontSize,
      height: 1.3,
      fontWeight: FontWeight.w500,
      color: text2,
    );

    TextSpan dimSpan(String text, FontWeight weight) => TextSpan(
          text: text,
          style: TextStyle(color: text2, fontWeight: weight),
        );

    final primary = Text.rich(
      TextSpan(
        style: firstStyle,
        children: <InlineSpan>[
          if (parts.prefix.isNotEmpty) dimSpan(parts.prefix, FontWeight.w500),
          TextSpan(text: parts.primary),
          if (!parts.hasSecondary && parts.suffix.isNotEmpty)
            dimSpan(parts.suffix, FontWeight.w500),
        ],
      ),
      maxLines: firstMaxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );

    if (!parts.hasSecondary) {
      return primary;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        primary,
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            style: secondaryStyle,
            children: <InlineSpan>[
              TextSpan(text: parts.secondary),
              if (parts.suffix.isNotEmpty)
                dimSpan(parts.suffix, FontWeight.w400),
            ],
          ),
          maxLines: secondaryMaxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
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
        ? 'artist:${parts.artist}'
        : 'group:${parts.circle}';
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

/// Interactive 28pt category color swatch button with a >=44×44pt hit target
/// that opens [showCategoryInfoPopover] anchored to the button.
class GalleryHeroCategoryButton extends StatelessWidget {
  const GalleryHeroCategoryButton({
    super.key,
    required this.category,
  });

  final String category;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (btnContext) {
        return Semantics(
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final overlay = Overlay.maybeOf(btnContext, rootOverlay: true);
              final overlayBox =
                  overlay?.context.findRenderObject() as RenderBox?;
              final btnBox = btnContext.findRenderObject() as RenderBox?;
              Rect? rect;
              if (btnBox != null && btnBox.hasSize && !btnBox.size.isEmpty) {
                final topLeft = (overlayBox != null && overlayBox.hasSize)
                    ? btnBox.localToGlobal(Offset.zero, ancestor: overlayBox)
                    : btnBox.localToGlobal(Offset.zero);
                rect = topLeft & btnBox.size;
              }
              unawaited(vibrateUtil.light());
              unawaited(
                showCategoryInfoPopover(
                  btnContext,
                  category: category,
                  anchorRect: rect,
                ),
              );
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              child: Align(
                alignment: Alignment.center,
                widthFactor: 1.0,
                heightFactor: 1.0,
                child: FavCategoryBadge(
                  category: category,
                  label: category,
                  height: 28,
                  borderRadius: 9,
                  fontSize: 13.5,
                  horizontalPadding: 11,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Category swatch · uploader · date.
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

    final pieces = <Widget>[
      if (category.isNotEmpty) GalleryHeroCategoryButton(category: category),
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

/// Flat hairline-separated favorite note section placed directly under
/// [_PrimaryActions]. Hidden when not favorited; shows an "Add note" row when
/// empty, or the note body (up to 4 lines, tap to expand) + edit button +
/// "Saved in ♥ {folder}" footer when non-empty.
class _FavNoteSection extends StatefulWidget {
  const _FavNoteSection({required this.controller});

  final GalleryPageController controller;

  @override
  State<_FavNoteSection> createState() => _FavNoteSectionState();
}

class _FavNoteSectionState extends State<_FavNoteSection> {
  bool _expanded = false;
  bool _loadingNote = false;
  String? _loadedKey;
  Future<String?>? _pendingLoad;

  void _ensureNoteLoaded({
    required String gid,
    required String token,
    required String favcat,
    required String? knownNote,
  }) {
    if (!isNetworkFavoriteCategory(favcat) || gid.isEmpty || token.isEmpty) {
      return;
    }
    if (knownNote != null) {
      return;
    }
    final key = '${favoriteStates.epoch}:$gid:$favcat';
    if (_loadedKey == key || _loadingNote) {
      return;
    }
    _loadedKey = key;
    _loadingNote = true;
    final requestEpoch = favoriteStates.epoch;
    final favTitle = widget.controller.gState.galleryProvider?.favTitle ?? '';
    final future = () async {
      try {
        if (!Get.isRegistered<FavController>()) {
          _loadedKey = null;
          return null;
        }
        final fetched =
            await Get.find<FavController>().loadFavoriteNote(gid, token);
        if (!mounted || requestEpoch != favoriteStates.epoch) {
          return null;
        }
        if (favoriteStates.isBusy(gid)) {
          return null;
        }
        final current = favoriteStates[gid];
        if (current != null) {
          if (current.category.isEmpty || current.note != null) {
            return current.note;
          }
          final normalized = (fetched ?? '').trim();
          favoriteStates.commitNote(gid, normalized);
          return normalized;
        }
        final normalized = (fetched ?? '').trim();
        favoriteStates.commit(gid, favcat, favTitle, note: normalized);
        return normalized;
      } catch (_) {
        _loadedKey = null;
        return null;
      } finally {
        if (mounted) {
          setState(() => _loadingNote = false);
        }
      }
    }();
    _pendingLoad = future;
  }

  Future<void> _openEditor({
    required String gid,
    required String token,
    required String favcat,
    required String favTitle,
    required String currentNote,
    required bool noteKnown,
  }) async {
    var resolvedNote = currentNote;
    if (!noteKnown) {
      if (_pendingLoad != null) {
        final loaded = await _pendingLoad;
        if (!mounted) {
          return;
        }
        if (loaded != null) {
          resolvedNote = loaded;
        }
      }
      final storeNote = favoriteStates[gid]?.note;
      if (storeNote != null) {
        resolvedNote = storeNote;
      } else if (Get.isRegistered<FavController>()) {
        try {
          final fetched =
              await Get.find<FavController>().loadFavoriteNote(gid, token);
          if (!mounted) {
            return;
          }
          resolvedNote = (fetched ?? '').trim();
        } catch (_) {
          if (mounted) {
            showToast('原收藏备注未能读取，未提交更改，请重试');
          }
          return;
        }
      }
    }
    if (!mounted) {
      return;
    }
    final updated = await showFavoriteNoteEditSheet(
      context,
      gid: gid,
      token: token,
      favcat: favcat,
      favTitle: favTitle,
      initialNote: resolvedNote,
    );
    if (updated != null && mounted) {
      final state = widget.controller.gState;
      state.galleryProvider =
          state.galleryProvider?.copyWith(favNote: updated.oN);
      widget.controller.update([GetIds.PAGE_VIEW_HEADER]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tag = pageCtrlTagOf(context);
    if (!Get.isRegistered<GalleryFavController>(tag: tag)) {
      return const SizedBox.shrink();
    }
    final favorites = Get.find<GalleryFavController>(tag: tag);
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;

    return Obx(() {
      final isFav = favorites.isFav;
      final favcat = favorites.favcat;
      if (!isFav || !isNetworkFavoriteCategory(favcat)) {
        return const SizedBox.shrink();
      }
      final state = widget.controller.gState;
      final provider = state.galleryProvider;
      final gid = state.gid;
      final token = provider?.token ?? '';
      final favTitle = favorites.favTitle.isNotEmpty
          ? favorites.favTitle
          : (provider?.favTitle ?? '');

      final storeNote = favoriteStates[gid]?.note;
      final providerNote = provider?.favNote;
      final String? knownNote = storeNote ??
          ((providerNote != null && providerNote.trim().isNotEmpty)
              ? providerNote.trim()
              : null);

      _ensureNoteLoaded(
        gid: gid,
        token: token,
        favcat: favcat,
        knownNote: knownNote,
      );

      final noteKnown = knownNote != null;
      final note = (knownNote ?? '').trim();
      final hairline = palette.hairline.resolveFrom(context);
      final text1 = palette.text1.resolveFrom(context);
      final text2 = palette.text2.resolveFrom(context);

      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(height: 0.5, color: hairline),
            if (note.isEmpty)
              Semantics(
                button: true,
                label: l10n.fav_note_add,
                excludeSemantics: true,
                onTap: () => _openEditor(
                  gid: gid,
                  token: token,
                  favcat: favcat,
                  favTitle: favTitle,
                  currentNote: '',
                  noteKnown: noteKnown,
                ),
                child: EhPressable(
                  onPressed: () => _openEditor(
                    gid: gid,
                    token: token,
                    favcat: favcat,
                    favTitle: favTitle,
                    currentNote: '',
                    noteKnown: noteKnown,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Row(
                      children: <Widget>[
                        EhSvgIcon(
                          CupertinoIcons.plus_circle,
                          size: 16,
                          color: text2,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.fav_note_add,
                            style: TextStyle(
                              fontSize: 14.5,
                              color: text2,
                            ),
                          ),
                        ),
                        if (_loadingNote)
                          const CupertinoActivityIndicator(radius: 8),
                      ],
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () =>
                                setState(() => _expanded = !_expanded),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                note,
                                maxLines: _expanded ? null : 4,
                                overflow: _expanded
                                    ? TextOverflow.visible
                                    : TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  height: 1.4,
                                  color: text1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Semantics(
                          button: true,
                          label: l10n.fav_note_edit,
                          excludeSemantics: true,
                          onTap: () => _openEditor(
                            gid: gid,
                            token: token,
                            favcat: favcat,
                            favTitle: favTitle,
                            currentNote: note,
                            noteKnown: true,
                          ),
                          child: CupertinoButton(
                            minimumSize: const Size(44, 44),
                            padding: EdgeInsets.zero,
                            onPressed: () => _openEditor(
                              gid: gid,
                              token: token,
                              favcat: favcat,
                              favTitle: favTitle,
                              currentNote: note,
                              noteKnown: true,
                            ),
                            child: EhSvgIcon(
                              CupertinoIcons.pencil,
                              size: 18,
                              color: text2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        EhSvgIcon(
                          CupertinoIcons.heart_fill,
                          size: 12,
                          color: favcatDisplayColor(context, favcat),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            l10n.fav_saved_in(favTitle),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: text2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            Container(height: 0.5, color: hairline),
          ],
        ),
      );
    });
  }
}

/// Read, Favourite and Download in one floating glass capsule. The host
/// places it at the bottom and keeps [reservedHeight] free under the content.
class GalleryActionDock extends StatelessWidget {
  const GalleryActionDock({super.key, required this.controller});

  final GalleryPageController controller;

  static const double barHeight = 64;
  static const double bottomGap = 12;

  /// A wide pane keeps the dock phone-sized, centred, so Read stays a button.
  static const double maxWidth = 480;

  /// Space the scroll content leaves free so its end clears the dock.
  static double reservedHeight(BuildContext context) =>
      barHeight + bottomGap + MediaQuery.paddingOf(context).bottom + 12;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: bottomGap),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxWidth),
            child: SizedBox(
              key: const ValueKey<String>('gallery-action-dock'),
              height: barHeight,
              child: LiquidGlassSurface(
                enabled: true,
                borderRadius: BorderRadius.circular(barHeight / 2),
                useNativeGlass: false,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child:
                            _ReadCapsule(controller: controller, docked: true),
                      ),
                      const SizedBox(width: 6),
                      const _FavoriteCircle(docked: true),
                      const SizedBox(width: 6),
                      _DownloadCircle(controller: controller, docked: true),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The one filled control on the page: HIG gives the primary action a
/// coloured background. Docked, it is tinted glass with a top highlight.
class _ReadCapsule extends StatelessWidget {
  const _ReadCapsule({required this.controller, this.docked = false});

  final GalleryPageController controller;
  final bool docked;

  @override
  Widget build(BuildContext context) {
    final state = controller.gState;
    final l10n = L10n.of(context);
    return Obx(() {
      final enabled = state.enableRead;
      final last = state.lastIndex;
      final accent = CupertinoDynamicColor.resolve(EhPalette.accent, context);
      final fill = enabled
          ? accent.withValues(alpha: docked ? 0.88 : 1)
          : accent.withValues(alpha: 0.4);
      return CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: enabled
            ? () => NavigatorUtil.goGalleryViewPage(last, state.gid,
                galleryTag: pageCtrlTagOf(context))
            : null,
        child: Container(
          constraints: BoxConstraints(minHeight: docked ? 52 : 50),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: docked
              ? ShapeDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color.alphaBlend(const Color(0x47FFFFFF), fill),
                      fill,
                    ],
                    stops: const <double>[0, 0.6],
                  ),
                  shape: const StadiumBorder(
                    side: BorderSide(color: Color(0x40FFFFFF), width: 0.5),
                  ),
                )
              : ShapeDecoration(
                  color: fill,
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
    this.docked = false,
  });

  final Widget child;
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 0–1 ring around the button, for a running download.
  final double? progress;

  /// Inside the glass dock: a lighter lens fill and the dock's fixed size.
  final bool docked;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final size = docked
        ? 52.0
        : math.max(50.0, MediaQuery.textScalerOf(context).scale(50));
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final fill = docked
        ? (dark ? const Color(0x29FFFFFF) : const Color(0x1414161C))
        : CupertinoDynamicColor.resolve(palette.fillPressed, context);
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
                color: fill,
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
  const _FavoriteCircle({this.docked = false});

  final bool docked;

  @override
  Widget build(BuildContext context) {
    final favorites =
        Get.find<GalleryFavController>(tag: pageCtrlTagOf(context));
    final l10n = L10n.of(context);
    return Obx(() {
      final isFav = favorites.isFav;
      return _RoundAction(
        docked: docked,
        label: isFav ? l10n.remove_from_favorites : l10n.add_to_favorites,
        onTap: favorites.isLoading ? null : () => favorites.tapFav(),
        onLongPress: favorites.isLoading ? null : () => favorites.longTapFav(),
        child: favorites.isLoading
            ? const CupertinoActivityIndicator()
            : EhSvgIcon(
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
  const _DownloadCircle({required this.controller, this.docked = false});

  final GalleryPageController controller;
  final bool docked;

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
        final provider = state.galleryProvider;
        final newerVersions =
            provider?.newerVersionsNewestFirst ?? const <GalleryNewerVersion>[];
        final task = _downloads.dState.galleryTaskMap[gid];
        final canIncrementalUpdate =
            newerVersions.isNotEmpty && task != null;
        return _RoundAction(
          docked: docked,
          label: canIncrementalUpdate
              ? l10n.incremental_update_title
              : l10n.downloaded,
          onTap: canIncrementalUpdate
              ? () => showGalleryIncrementalUpdateSheet(
                    context,
                    oldTask: task,
                    newerVersions: newerVersions,
                  )
              : null,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              EhSvgIcon(
                canIncrementalUpdate
                    ? CupertinoIcons.arrow_down_to_line
                    : CupertinoIcons.checkmark_alt,
                size: 23,
                color: CupertinoDynamicColor.resolve(EhPalette.accent, context),
              ),
              if (canIncrementalUpdate)
                Positioned(
                  top: -9,
                  right: -9,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: CupertinoDynamicColor.resolve(
                        EhPalette.accent,
                        context,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: CupertinoDynamicColor.resolve(
                          ehTheme.palette.canvas,
                          context,
                        ),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }
      if (status == TaskStatus.running || status == TaskStatus.enqueued) {
        return _RoundAction(
          docked: docked,
          label: l10n.downloading,
          progress: state.downloadProcess / 100,
          onTap: () => status == TaskStatus.running
              ? _downloads.galleryTaskPaused(gid)
              : _downloads.galleryTaskResume(gid),
          child: EhSvgIcon(CupertinoIcons.pause_fill, size: 20, color: text1),
        );
      }
      if (status == TaskStatus.paused) {
        return _RoundAction(
          docked: docked,
          label: l10n.paused,
          progress: state.downloadProcess / 100,
          onTap: () => _downloads.galleryTaskResume(gid),
          child: EhSvgIcon(CupertinoIcons.play_fill, size: 20, color: text1),
        );
      }
      return _RoundAction(
          docked: docked,
        label: l10n.p_Download,
        onTap: () => controller.downloadGallery(context),
        child: EhSvgIcon(CupertinoIcons.arrow_down_to_line, size: 22, color: text1),
      );
    });
  }
}

/// Single-line, borderless, soft-glow version lineage cue placed directly
/// below [_DataStrip]. Takes ~28pt so the first rows of tags remain visible
/// above the fold even on compact viewports such as a folded iPhone Duo.
class GalleryLineageWhisper extends StatelessWidget {
  const GalleryLineageWhisper({
    super.key,
    required this.provider,
    required this.isDownloadedComplete,
    required this.onTap,
  });

  final GalleryProvider provider;
  final bool isDownloadedComplete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final newerVersions = provider.newerVersionsNewestFirst;
    final hasNewer = newerVersions.isNotEmpty;
    final hasParent = provider.hasParentLink;
    if (!hasNewer && !hasParent) {
      return const SizedBox.shrink();
    }

    final l10n = L10n.of(context);
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    late final String primaryText;
    late final String secondaryText;
    if (hasNewer) {
      primaryText = newerVersions.length == 1
          ? l10n.gallery_newer_version_single
          : l10n.gallery_newer_version_count(newerVersions.length);
      if (isDownloadedComplete) {
        secondaryText = l10n.gallery_updatable_hint;
      } else if (hasParent) {
        secondaryText = l10n.gallery_has_parent_hint;
      } else {
        final date = newerVersions.first.shortDate;
        secondaryText = date.isNotEmpty
            ? l10n.gallery_updated_on(date)
            : l10n.gallery_view_lineage_hint;
      }
    } else {
      final parentGid = provider.parentGid ?? '';
      primaryText = parentGid.isNotEmpty
          ? l10n.gallery_from_parent_hint(parentGid)
          : l10n.gallery_parent;
      secondaryText = l10n.gallery_view_lineage_hint;
    }

    // Style A (极简中心柔光): borderless centered radial glow + soft-focus silver-gray text.
    final Color primaryColor = dark
        ? const Color(0xDBD2D7E2)
        : const Color(0xCC4B5263);
    final Color secondaryColor = dark
        ? const Color(0xB8B0B6C4)
        : const Color(0x9E5E6577);
    final Color chevronColor = dark
        ? const Color(0x8FBEC4D4)
        : const Color(0x855E6577);
    final List<Shadow> glowShadows = dark
        ? const <Shadow>[
            Shadow(color: Color(0x73DAE1F5), blurRadius: 8),
            Shadow(color: Color(0x3D9AA8FF), blurRadius: 18),
          ]
        : const <Shadow>[
            Shadow(color: Color(0x2E4A5BD8), blurRadius: 8),
            Shadow(color: Color(0x1C4A5BD8), blurRadius: 16),
          ];

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Semantics(
        button: true,
        label: '$primaryText $secondaryText',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                // Borderless soft radial ambient mist (no side edges, no divider).
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 2.2,
                          colors: dark
                              ? const <Color>[
                                  Color(0x1CCAD2EC),
                                  Color(0x0BA8B2DC),
                                  Color(0x00000000),
                                ]
                              : const <Color>[
                                  Color(0x124A5BD8),
                                  Color(0x064A5BD8),
                                  Color(0x00000000),
                                ],
                          stops: const <double>[0.0, 0.45, 0.85],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          primaryText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                            color: primaryColor,
                            shadows: glowShadows,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          secondaryText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.15,
                            color: secondaryColor,
                            shadows: glowShadows,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 12,
                        color: chevronColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
                      FontFeature.tabularFigures(),
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
    required this.coverWidth,
  });

  final String imageUrl;
  final String? category;
  final double height;
  final ValueListenable<double> scrollOffset;

  /// Width of the header cover. The backdrop decodes the very same image,
  /// so it is ready in the frame the cover is, instead of fading in over
  /// the canvas while a new page slides in.
  final double coverWidth;

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
            // Let the renderer choose the layer blur's edge sampling. Forcing
            // clamp makes Impeller reuse the clipped input edge while this
            // page slides in, then switch colours when it reaches the pane edge.
            imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: ColorFiltered(
              colorFilter: ColorFilter.matrix(saturation(privacy ? 0.6 : 1.15)),
              child: EhNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                blurHash: privacy,
                decodeWidth: heroCoverDecodeWidth(context, coverWidth),
                fadeInDuration: const Duration(milliseconds: 180),
                // The list card's copy fills the first frames; blurred, the
                // swap to the cover's own copy can't be seen.
                placeholder: (_, __) => ShownImage(imageUrl),
                placeholderWhileDecoding: true,
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

/// Two-column geometry for the detail page, or null for one column.
@immutable
class GalleryDetailColumns {
  const GalleryDetailColumns({required this.leading, required this.gap});

  /// Width of the fixed column holding the header.
  final double leading;

  /// Space between the columns: the fold on an unfolded Duo, else none.
  final double gap;

  /// Fixed header column on wide windows.
  static const double sideWidth = 320;

  /// Narrowest page that gets two columns without a fold.
  static const double wideWidth = 700;

  /// Narrowest column either side of a fold.
  static const double minPane = 260;

  /// [width] is the page's own width. A book fold only splits the page
  /// when the page fills the window, so window and page coordinates agree;
  /// split panes already sit either side of it.
  static GalleryDetailColumns? resolve({
    required double width,
    AdaptiveEnvironmentSnapshot? environment,
    bool split = false,
  }) {
    if (environment != null &&
        !split &&
        (width - environment.size.width).abs() < 1) {
      for (final region in environment.activeDivisionRegions) {
        final fold = region.frame;
        if (fold.height < fold.width) {
          continue;
        }
        if (fold.left >= minPane && width - fold.right >= minPane) {
          return GalleryDetailColumns(leading: fold.left, gap: fold.width);
        }
      }
    }
    final usableWidth = environment != null &&
            environment.hasDuoVerticalBar &&
            (width - environment.size.width).abs() < 1
        ? environment.contentRect.width
        : width;
    if (usableWidth >= wideWidth) {
      return const GalleryDetailColumns(leading: sideWidth, gap: 0);
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is GalleryDetailColumns &&
      other.leading == leading &&
      other.gap == gap;

  @override
  int get hashCode => Object.hash(leading, gap);
}
