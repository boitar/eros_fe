import 'dart:async';
import 'dart:math' as math;

import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/adaptive/native_top_header.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/controller/download/gallery_update_service.dart';
import 'package:eros_fe/common/controller/download_controller.dart';
import 'package:eros_fe/common/controller/image_block_controller.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_controller.dart';
import 'package:eros_fe/pages/gallery/view/gallery_incremental_update_sheet.dart';
import 'package:eros_fe/pages/item/gallery_item.dart';
import 'package:eros_fe/route/navigator_util.dart';
import 'package:eros_fe/store/db/entity/gallery_task.dart';
import 'package:eros_fe/utils/logger.dart';
import 'package:eros_fe/utils/toast.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:eros_fe/widget/image/eh_cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, SelectableText;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

const double _kCardRadius = 20.0;
const double _kContentMaxWidth = 640.0;

double _actionTargetSize() =>
    PlatformCapabilities.hostPlatform == TargetPlatform.android ? 48.0 : 44.0;

String? _monoFontFamily() {
  switch (PlatformCapabilities.hostPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return 'Menlo';
    case TargetPlatform.windows:
      return 'Consolas';
    case TargetPlatform.android:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
    case null:
      return 'monospace';
  }
}

const List<String> _kMonoFallbacks = <String>[
  'SF Mono',
  'Menlo',
  'Consolas',
  'monospace',
];

const List<FontFeature> _kTabularFigures = <FontFeature>[
  FontFeature.tabularFigures(),
];

String _orDash(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? '—' : trimmed;
}

typedef _CopyHandler = Future<bool> Function(String value);
typedef _CopyAction = Future<bool> Function();

class GalleryInfoPage extends StatefulWidget {
  const GalleryInfoPage({
    super.key,
    this.onOpenGalleryUrl,
    this.onIncrementalUpdate,
    this.onSearchUploader,
    this.onOpenExternalUrl,
    this.externalUrlLauncher,
  });

  /// Stable key on the first content block so native bar gap tests can measure
  /// where the page content starts.
  static const Key contentStartKey = ValueKey<String>(
    'galleryInfo.contentStart',
  );

  /// Stable key on the polite semantic live region used when the host platform
  /// discourages direct accessibility announcements (e.g. Android TalkBack).
  static const Key copyLiveRegionKey = ValueKey<String>(
    'galleryInfo.copyLiveRegion',
  );

  /// Optional override for navigating to a parent or newer gallery URL.
  final ValueChanged<String>? onOpenGalleryUrl;

  /// Optional override for launching the incremental update sheet.
  final void Function(
    BuildContext context,
    GalleryTask task,
    List<GalleryNewerVersion> versions,
  )?
  onIncrementalUpdate;

  /// Optional override for searching galleries by uploader.
  final ValueChanged<String>? onSearchUploader;

  /// Optional override for opening a gallery URL in an external browser.
  final ValueChanged<String>? onOpenExternalUrl;

  /// Optional override for the underlying external URL launcher call (used in
  /// tests to verify failure and exception handling).
  final Future<bool> Function(String url)? externalUrlLauncher;

  /// Resolves and validates a canonical E-Hentai / ExHentai gallery URL from
  /// [provider], handling protocol-relative, bare-relative, root-relative, and
  /// uppercase-scheme URLs while rejecting malformed or foreign URLs.
  static String resolveGalleryUrl(GalleryProvider provider, {Uri? baseUri}) {
    final raw = provider.url?.trim() ?? '';
    if (raw.isNotEmpty) {
      final normalized = normalizeGalleryUrl(raw, baseUri: baseUri);
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    final gid = provider.gid?.trim() ?? '';
    final token = provider.token?.trim() ?? '';
    if (gid.isNotEmpty && token.isNotEmpty) {
      final fallback = normalizeGalleryUrl('/g/$gid/$token/', baseUri: baseUri);
      if (fallback.isNotEmpty) {
        return fallback;
      }
    }
    return '';
  }

  static Future<bool> _defaultLaunchExternalUrl(String url) =>
      launchUrlString(url, mode: LaunchMode.externalApplication);

  @override
  State<GalleryInfoPage> createState() => _GalleryInfoPageState();
}

class _GalleryInfoPageState extends State<GalleryInfoPage> {
  String? _liveCopyAnnouncement;
  Timer? _liveAnnouncementTimer;
  int _liveAnnouncementToken = 0;

  @override
  void dispose() {
    _liveAnnouncementTimer?.cancel();
    super.dispose();
  }

  void _openGalleryUrl(String rawUrl) {
    final normalized = normalizeGalleryUrl(rawUrl);
    if (normalized.isEmpty) {
      return;
    }
    if (widget.onOpenGalleryUrl != null) {
      widget.onOpenGalleryUrl!(normalized);
      return;
    }
    NavigatorUtil.goGalleryPage(url: normalized);
  }

  void _searchUploader(String uploader) {
    final trimmed = uploader.trim();
    if (trimmed.isEmpty) {
      return;
    }
    if (widget.onSearchUploader != null) {
      widget.onSearchUploader!(trimmed);
      return;
    }
    NavigatorUtil.goSearchPageWithParam(simpleSearch: 'uploader:$trimmed');
  }

  Future<void> _openExternalUrl(BuildContext context, String rawUrl) async {
    final normalized = normalizeGalleryUrl(rawUrl);
    if (normalized.isEmpty) {
      if (context.mounted) {
        showToast(L10n.of(context).gallery_info_open_browser_failed);
      }
      return;
    }
    if (widget.onOpenExternalUrl != null) {
      widget.onOpenExternalUrl!(normalized);
      return;
    }
    try {
      final launcher =
          widget.externalUrlLauncher ??
          GalleryInfoPage._defaultLaunchExternalUrl;
      final launched = await launcher(normalized);
      if (!launched && context.mounted) {
        showToast(L10n.of(context).gallery_info_open_browser_failed);
      }
    } on Object catch (e, stack) {
      logger.e(
        'Failed to launch gallery URL: $normalized',
        error: e,
        stackTrace: stack,
      );
      if (context.mounted) {
        showToast(L10n.of(context).gallery_info_open_browser_failed);
      }
    }
  }

  Future<bool> _copyValue(BuildContext context, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    try {
      await Clipboard.setData(ClipboardData(text: trimmed));
    } on Object catch (e, stack) {
      logger.e('Failed to write clipboard', error: e, stackTrace: stack);
      return false;
    }
    vibrateUtil.light();
    if (!mounted || !context.mounted) {
      return true;
    }
    final message = L10n.of(context).copied_to_clipboard;
    showToast(message);
    if (MediaQuery.supportsAnnounceOf(context)) {
      final view = View.maybeOf(context);
      if (view != null) {
        unawaited(
          SemanticsService.sendAnnouncement(
            view,
            message,
            Directionality.of(context),
          ),
        );
      }
    } else {
      final token = ++_liveAnnouncementToken;
      _liveAnnouncementTimer?.cancel();
      if (_liveCopyAnnouncement != null) {
        setState(() => _liveCopyAnnouncement = null);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _liveAnnouncementToken == token) {
            setState(() => _liveCopyAnnouncement = message);
          }
        });
      } else {
        setState(() => _liveCopyAnnouncement = message);
      }
      _liveAnnouncementTimer = Timer(const Duration(milliseconds: 1400), () {
        if (mounted && _liveAnnouncementToken == token) {
          setState(() => _liveCopyAnnouncement = null);
        }
      });
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final nativeBar = NativeNavigationScope.isEnabled(context);
    final supportsAnnounce = MediaQuery.supportsAnnounceOf(context);
    final topMargin = nativeBar
        ? math.max(10.0, NativeTopTabHeader.contentGapFor(context))
        : 12.0;
    final bottomPadding = math.max(
      32.0,
      MediaQuery.paddingOf(context).bottom + 20.0,
    );

    final scrollView = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: GetBuilder<GalleryPageController>(
        tag: pageCtrlTagOf(context),
        id: GetIds.PAGE_VIEW_HEADER,
        builder: (GalleryPageController controller) {
          final pageState = controller.gState;
          final provider = pageState.galleryProvider;
          if (provider == null) {
            return const SizedBox.shrink();
          }

          final newerVersions = provider.newerVersionsNewestFirst;
          final hasNewer = newerVersions.isNotEmpty;
          final rawParent = provider.parent?.trim() ?? '';
          final hasParentLink = provider.hasParentLink;
          final hasParentDisplay =
              hasParentLink ||
              (rawParent.isNotEmpty && rawParent.toLowerCase() != 'none');
          final showLineageSection = hasParentDisplay || hasNewer;
          final galleryUrl = GalleryInfoPage.resolveGalleryUrl(provider);
          final imgUrl = provider.imgUrl?.trim() ?? '';

          final sections = <Widget>[
            _GalleryOverviewCard(
              key: GalleryInfoPage.contentStartKey,
              provider: provider,
              showingJapaneseTitle: pageState.showingJapaneseTitle,
              onCopy: (value) => _copyValue(context, value),
            ),
            if (showLineageSection) ...<Widget>[
              _SectionHeader(
                title: l10n.gallery_lineage,
                hint: l10n.gallery_lineage_tap_hint,
              ),
              _LineageCard(
                provider: provider,
                rawParent: rawParent,
                hasParentDisplay: hasParentDisplay,
                hasParentLink: hasParentLink,
                newerVersions: newerVersions,
                onOpenGalleryUrl: _openGalleryUrl,
                onCopy: (value) => _copyValue(context, value),
                onIncrementalUpdate: widget.onIncrementalUpdate,
              ),
            ],
            _SectionHeader(
              title: l10n.gallery_info_section_details,
              hint: l10n.gallery_metadata_copy_hint,
            ),
            _DetailsCard(
              provider: provider,
              onCopy: (value) => _copyValue(context, value),
              onSearchUploader: _searchUploader,
            ),
            _SectionHeader(
              title: l10n.gallery_info_section_identifiers,
              hint: l10n.gallery_metadata_copy_hint,
            ),
            _IdentifiersCard(
              gid: provider.gid?.trim() ?? '',
              token: provider.token?.trim() ?? '',
              galleryUrl: galleryUrl,
              coverUrl: imgUrl,
              onCopy: (value) => _copyValue(context, value),
              onOpenExternalUrl: (url) => _openExternalUrl(context, url),
            ),
          ];

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: _kContentMaxWidth,
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  topMargin,
                  16,
                  bottomPadding,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: sections,
                ),
              ),
            ),
          );
        },
      ),
    );

    return SettingScaffold(
      title: l10n.gallery_info,
      child: SafeArea(
        bottom: false,
        child: supportsAnnounce
            ? scrollView
            : Semantics(
                key: GalleryInfoPage.copyLiveRegionKey,
                container: true,
                liveRegion: true,
                accessibilityFocusBlockType:
                    AccessibilityFocusBlockType.blockNode,
                label: _liveCopyAnnouncement,
                child: scrollView,
              ),
      ),
    );
  }
}

/// Observes [DownloadState.galleryTaskMap] reactively when newer versions exist
/// so the incremental-update action appears immediately if a download completes
/// while this page is open.
class _LineageCard extends StatelessWidget {
  const _LineageCard({
    required this.provider,
    required this.rawParent,
    required this.hasParentDisplay,
    required this.hasParentLink,
    required this.newerVersions,
    required this.onOpenGalleryUrl,
    required this.onCopy,
    this.onIncrementalUpdate,
  });

  final GalleryProvider provider;
  final String rawParent;
  final bool hasParentDisplay;
  final bool hasParentLink;
  final List<GalleryNewerVersion> newerVersions;
  final ValueChanged<String> onOpenGalleryUrl;
  final _CopyHandler onCopy;
  final void Function(
    BuildContext context,
    GalleryTask task,
    List<GalleryNewerVersion> versions,
  )?
  onIncrementalUpdate;

  Widget _buildCard(BuildContext context, GalleryTask? downloadedTask) {
    final items = <_MetaCardItem>[
      if (hasParentDisplay)
        _MetaCardItem(
          child: _ParentLineageRow(
            parentText: rawParent,
            parentGid: provider.parentGid,
            hasLink: hasParentLink,
            onTap: hasParentLink
                ? () => onOpenGalleryUrl(provider.parentHref!)
                : () => unawaited(onCopy(rawParent)),
            onLongPress: () => unawaited(
              onCopy(
                hasParentLink
                    ? normalizeGalleryUrl(provider.parentHref!)
                    : rawParent,
              ),
            ),
          ),
        ),
      for (var i = 0; i < newerVersions.length; i++)
        _MetaCardItem(
          dividerIndentBefore: 56.0,
          child: _NewerVersionRow(
            version: newerVersions[i],
            isLatest: i == 0,
            onTap: () => onOpenGalleryUrl(newerVersions[i].url),
            onLongPress: () => unawaited(
              onCopy(normalizeGalleryUrl(newerVersions[i].url)),
            ),
          ),
        ),
      if (downloadedTask != null)
        _MetaCardItem(
          dividerIndentBefore: 0.0,
          child: _IncrementalUpdateEntryRow(
            onTap: () {
              if (onIncrementalUpdate != null) {
                onIncrementalUpdate!(
                  context,
                  downloadedTask,
                  newerVersions,
                );
                return;
              }
              showGalleryIncrementalUpdateSheet(
                context,
                oldTask: downloadedTask,
                newerVersions: newerVersions,
              );
            },
          ),
        ),
    ];

    return _MetaSurfaceCard.items(items: items);
  }

  @override
  Widget build(BuildContext context) {
    final gid = int.tryParse(provider.gid?.trim() ?? '');
    final canObserveDownload =
        newerVersions.isNotEmpty &&
        gid != null &&
        Get.isRegistered<DownloadController>();
    if (!canObserveDownload) {
      return _buildCard(context, null);
    }

    return Obx(() {
      final task = Get.find<DownloadController>().dState.galleryTaskMap[gid];
      final completeTask =
          (task != null && task.status == TaskStatus.complete.value)
          ? task
          : null;
      return _buildCard(context, completeTask);
    });
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.hint,
  });

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 20, 12, 8),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          spacing: 8,
          runSpacing: 2,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.text2.resolveFrom(context),
                ),
              ),
            ),
            if (hint != null && hint!.isNotEmpty)
              Text(
                hint!,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  color: palette.text3.resolveFrom(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetaCardItem {
  const _MetaCardItem({
    required this.child,
    this.dividerIndentBefore,
  });

  final Widget child;
  final double? dividerIndentBefore;
}

class _MetaSurfaceCard extends StatelessWidget {
  const _MetaSurfaceCard({
    required List<Widget> this.children,
    this.dividerIndent = 16.0,
  }) : items = null;

  const _MetaSurfaceCard.items({
    required List<_MetaCardItem> this.items,
  }) : children = null,
       dividerIndent = 16.0;

  final List<Widget>? children;
  final List<_MetaCardItem>? items;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final separator = EhPalette.separator.resolveFrom(context);
    final dividerHeight = 1.0 / MediaQuery.devicePixelRatioOf(context);
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(_kCardRadius),
      side: BorderSide(
        color: palette.hairline.resolveFrom(context),
        width: 0.5,
      ),
    );

    final resolvedItems =
        items ??
        <Widget>[...?children]
            .map((w) => _MetaCardItem(child: w))
            .toList(growable: false);

    final columnChildren = <Widget>[];
    for (var i = 0; i < resolvedItems.length; i++) {
      final item = resolvedItems[i];
      if (i > 0) {
        final indent = item.dividerIndentBefore ?? dividerIndent;
        columnChildren.add(
          Padding(
            padding: EdgeInsetsDirectional.only(start: indent),
            child: ColoredBox(
              color: separator,
              child: SizedBox(width: double.infinity, height: dividerHeight),
            ),
          ),
        );
      }
      columnChildren.add(item.child);
    }

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: palette.surface.resolveFrom(context),
        shape: shape,
      ),
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.circular(_kCardRadius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: columnChildren,
        ),
      ),
    );
  }
}

class _GalleryOverviewCard extends StatelessWidget {
  const _GalleryOverviewCard({
    super.key,
    required this.provider,
    required this.showingJapaneseTitle,
    required this.onCopy,
  });

  final GalleryProvider provider;
  final bool showingJapaneseTitle;
  final _CopyHandler onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final imgUrl = provider.imgUrl?.trim() ?? '';
    final showCover =
        imgUrl.isNotEmpty &&
        Get.isRegistered<EhSettingService>() &&
        Get.isRegistered<ImageBlockController>();
    final category = provider.category?.trim() ?? '';
    final gid = provider.gid?.trim() ?? '';
    final uploader = provider.uploader?.trim() ?? '';
    final postTime = provider.postTime?.trim() ?? '';
    final expunged = provider.expunged == true;

    final english = provider.englishTitle?.trim() ?? '';
    final japanese = provider.japaneseTitle?.trim() ?? '';
    final titleEntries = <(String, String)>[
      if (japanese.isNotEmpty) (l10n.japanese_title, japanese),
      if (english.isNotEmpty) (l10n.english_title, english),
    ];
    if (!showingJapaneseTitle && titleEntries.length == 2) {
      titleEntries.insert(0, titleEntries.removeLast());
    }

    final bylineParts = <String>[
      if (uploader.isNotEmpty) uploader,
      if (postTime.isNotEmpty) postTime,
    ];
    final hasHeaderBand =
        showCover ||
        category.isNotEmpty ||
        gid.isNotEmpty ||
        expunged ||
        bylineParts.isNotEmpty;

    final sections = <Widget>[
      if (hasHeaderBand)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (showCover) ...<Widget>[
                _CompactCoverThumb(imageUrl: imgUrl),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        if (category.isNotEmpty)
                          _CategoryPill(category: category),
                        if (gid.isNotEmpty) _MonoBadgeChip(text: '#$gid'),
                        if (expunged)
                          _StatusBadgeChip(
                            label: l10n.gallery_info_expunged,
                            color: CupertinoDynamicColor.resolve(
                              CupertinoColors.systemRed,
                              context,
                            ),
                          ),
                      ],
                    ),
                    if (bylineParts.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        bylineParts.join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: palette.text2.resolveFrom(context),
                          fontFeatures: _kTabularFigures,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      for (final entry in titleEntries)
        _CopyableTextBlock(
          label: entry.$1,
          text: entry.$2,
          textStyle: TextStyle(
            fontSize: 15,
            height: 1.42,
            fontWeight: FontWeight.w500,
            color: palette.text1.resolveFrom(context),
          ),
          onCopy: () => onCopy(entry.$2),
        ),
      _MetricsStrip(
        provider: provider,
        onCopy: onCopy,
      ),
    ];

    return _MetaSurfaceCard(
      dividerIndent: 0,
      children: sections,
    );
  }
}

class _CompactCoverThumb extends StatelessWidget {
  const _CompactCoverThumb({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final settings = Get.find<EhSettingService>();
    final fillColor = palette.fill.resolveFrom(context);

    return Container(
      width: 52,
      height: 72,
      decoration: ShapeDecoration(
        color: fillColor,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: palette.hairline.resolveFrom(context),
            width: 0.5,
          ),
        ),
      ),
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.circular(10),
        child: Obx(() {
          final privacyBlur = settings.isGalleryImgBlur.value;
          return CoverImg(
            key: ValueKey<bool>(privacyBlur),
            imgUrl: imageUrl,
            width: 52,
            height: 72,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            decodeWidth: (52 * dpr).ceil(),
            fadeInDuration: const Duration(milliseconds: 160),
            // Never reuse an unblurred cached cover while privacy blur is on.
            placeholder: privacyBlur
                ? (_) => ColoredBox(color: fillColor)
                : (_) => ShownImage(
                    imageUrl,
                    alignment: Alignment.topCenter,
                  ),
            placeholderWhileDecoding: !privacyBlur,
          );
        }),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final rawColor = ThemeColors.catColor[category];
    final dotColor = rawColor == null
        ? palette.text2.resolveFrom(context)
        : CupertinoDynamicColor.resolve(rawColor, context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: ShapeDecoration(
        color: rawColor == null
            ? palette.fill.resolveFrom(context)
            : dotColor.withValues(alpha: 0.14),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DecoratedBox(
            decoration: ShapeDecoration(
              color: dotColor,
              shape: const CircleBorder(),
            ),
            child: const SizedBox.square(dimension: 6.5),
          ),
          const SizedBox(width: 6),
          Text(
            category,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.15,
              color: palette.text1.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonoBadgeChip extends StatelessWidget {
  const _MonoBadgeChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: ShapeDecoration(
        color: palette.fill.resolveFrom(context),
        shape: const StadiumBorder(),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          height: 1.2,
          fontFamily: _monoFontFamily(),
          fontFamilyFallback: _kMonoFallbacks,
          fontFeatures: _kTabularFigures,
          color: palette.text2.resolveFrom(context),
        ),
      ),
    );
  }
}

class _StatusBadgeChip extends StatelessWidget {
  const _StatusBadgeChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.14),
        shape: const StadiumBorder(),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          height: 1.15,
          color: color,
        ),
      ),
    );
  }
}

/// Full-width left-aligned selectable block (titles, URLs) with harmonized
/// optical padding and explicit 44pt/48dp copy/action buttons so normal text
/// selection never triggers unintended clipboard writes.
class _CopyableTextBlock extends StatefulWidget {
  const _CopyableTextBlock({
    required this.label,
    required this.text,
    required this.textStyle,
    required this.onCopy,
    this.extraAction,
  });

  final String label;
  final String text;
  final TextStyle textStyle;
  final _CopyAction onCopy;
  final Widget? extraAction;

  @override
  State<_CopyableTextBlock> createState() => _CopyableTextBlockState();
}

class _CopyableTextBlockState extends State<_CopyableTextBlock> {
  bool _copied = false;
  Timer? _resetTimer;

  Future<void> _triggerCopy() async {
    final copied = await widget.onCopy();
    if (!copied || !mounted) {
      return;
    }
    setState(() => _copied = true);
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final l10n = L10n.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 2, 2, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => unawaited(_triggerCopy()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.text2.resolveFrom(context),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.extraAction != null) widget.extraAction!,
              _CopyStatusButton(
                copied: _copied,
                semanticLabel: '${l10n.copy} ${widget.label}',
                copiedSemanticLabel: l10n.copied_to_clipboard,
                onPressed: () => unawaited(_triggerCopy()),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 14),
            child: SelectableText(
              widget.text,
              textAlign: TextAlign.start,
              style: widget.textStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsStrip extends StatelessWidget {
  const _MetricsStrip({
    required this.provider,
    required this.onCopy,
  });

  final GalleryProvider provider;
  final _CopyHandler onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final separator = EhPalette.separator.resolveFrom(context);
    final starColor = EhPalette.star.resolveFrom(context);
    final dividerThickness = 1.0 / MediaQuery.devicePixelRatioOf(context);

    final rating = provider.rating ?? 0;
    final hasRating = rating > 0;
    final ratingText = hasRating ? rating.toStringAsFixed(2) : '—';
    final ratingCountRaw = provider.ratingCount?.trim() ?? '';
    final ratingCountNum = int.tryParse(ratingCountRaw.replaceAll(',', ''));
    final ratingCaption = ratingCountNum != null
        ? l10n.gallery_info_rating_votes(ratingCountNum)
        : l10n.p_Rate;

    final pagesRaw = provider.filecount?.trim() ?? '';
    final sizeRaw = provider.filesizeText?.trim() ?? '';
    final favCountRaw = provider.favoritedCount?.trim() ?? '';

    final cells = <Widget>[
      _MetricCell(
        value: ratingText,
        caption: ratingCaption,
        leadingIcon: hasRating
            ? EhSvgIcon(
                CupertinoIcons.star_fill,
                size: 12,
                color: starColor,
              )
            : null,
        onTap: hasRating ? () => unawaited(onCopy(ratingText)) : null,
      ),
      _MetricCell(
        value: _orDash(pagesRaw),
        caption: l10n.s_pages,
        onTap: pagesRaw.isNotEmpty ? () => unawaited(onCopy(pagesRaw)) : null,
      ),
      _MetricCell(
        value: _orDash(sizeRaw),
        caption: l10n.file_size,
        onTap: sizeRaw.isNotEmpty ? () => unawaited(onCopy(sizeRaw)) : null,
      ),
      _MetricCell(
        value: _orDash(favCountRaw),
        caption: l10n.uc_fav,
        onTap: favCountRaw.isNotEmpty
            ? () => unawaited(onCopy(favCountRaw))
            : null,
      ),
    ];

    Widget vDivider() => ColoredBox(
      color: separator,
      child: SizedBox(width: dividerThickness, height: 28),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final twoByTwo = constraints.maxWidth < 320 || textScale >= 1.45;
        if (twoByTwo) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IntrinsicHeight(
                child: Row(
                  children: <Widget>[
                    Expanded(child: cells[0]),
                    ColoredBox(
                      color: separator,
                      child: SizedBox(width: dividerThickness),
                    ),
                    Expanded(child: cells[1]),
                  ],
                ),
              ),
              ColoredBox(
                color: separator,
                child: SizedBox(
                  width: double.infinity,
                  height: dividerThickness,
                ),
              ),
              IntrinsicHeight(
                child: Row(
                  children: <Widget>[
                    Expanded(child: cells[2]),
                    ColoredBox(
                      color: separator,
                      child: SizedBox(width: dividerThickness),
                    ),
                    Expanded(child: cells[3]),
                  ],
                ),
              ),
            ],
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: <Widget>[
              Expanded(child: cells[0]),
              vDivider(),
              Expanded(child: cells[1]),
              vDivider(),
              Expanded(child: cells[2]),
              vDivider(),
              Expanded(child: cells[3]),
            ],
          ),
        );
      },
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.value,
    required this.caption,
    this.leadingIcon,
    this.onTap,
  });

  final String value;
  final String caption;
  final Widget? leadingIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (leadingIcon != null) ...<Widget>[
                  leadingIcon!,
                  const SizedBox(width: 4),
                ],
                Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFeatures: _kTabularFigures,
                    color: palette.text1.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: palette.text2.resolveFrom(context),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }
    return EhPressable(
      onPressed: onTap,
      borderRadius: BorderRadius.zero,
      child: content,
    );
  }
}

class _ParentLineageRow extends StatelessWidget {
  const _ParentLineageRow({
    required this.parentText,
    required this.parentGid,
    required this.hasLink,
    required this.onTap,
    required this.onLongPress,
  });

  final String parentText;
  final String? parentGid;
  final bool hasLink;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final label = hasLink
        ? (parentGid != null && parentGid!.isNotEmpty
            ? '#$parentGid'
            : parentText)
        : (parentText.isNotEmpty
            ? parentText
            : l10n.gallery_parent_unavailable);

    return EhPressable(
      onPressed: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hasLink
                    ? EhPalette.accentSoft.resolveFrom(context)
                    : palette.fill.resolveFrom(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: EhSvgIcon(
                CupertinoIcons.arrow_up_left,
                size: 14,
                color: hasLink ? accent : palette.text3.resolveFrom(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    l10n.gallery_parent,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: palette.text2.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: hasLink ? FontWeight.w600 : FontWeight.w500,
                      fontFamily: _monoFontFamily(),
                      fontFamilyFallback: _kMonoFallbacks,
                      fontFeatures: _kTabularFigures,
                      color: hasLink
                          ? accent
                          : palette.text2.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            EhSvgIcon(
              hasLink
                  ? CupertinoIcons.chevron_right
                  : CupertinoIcons.doc_on_doc,
              size: 14,
              color: palette.text3.resolveFrom(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewerVersionRow extends StatelessWidget {
  const _NewerVersionRow({
    required this.version,
    required this.isLatest,
    required this.onTap,
    required this.onLongPress,
  });

  final GalleryNewerVersion version;
  final bool isLatest;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final subtitleParts = <String>[
      '#${version.gid}',
      if (version.addedDate?.trim().isNotEmpty ?? false)
        version.addedDate!.trim(),
    ];

    return EhPressable(
      onPressed: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 28,
              child: Center(
                child: isLatest
                    ? Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: EhPalette.accentSoft.resolveFrom(context),
                        ),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent,
                          ),
                        ),
                      )
                    : Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.transparent,
                          border: Border.all(
                            color: palette.text3.resolveFrom(context),
                            width: 1.6,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    version.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: isLatest ? FontWeight.w600 : FontWeight.w500,
                      color: palette.text1.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      if (isLatest)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 1.5,
                          ),
                          decoration: ShapeDecoration(
                            color: EhPalette.accentSoft.resolveFrom(context),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            l10n.gallery_latest_version,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: accent,
                            ),
                          ),
                        ),
                      Text(
                        subtitleParts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.text2.resolveFrom(context),
                          fontFeatures: _kTabularFigures,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            EhSvgIcon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: isLatest ? accent : palette.text3.resolveFrom(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncrementalUpdateEntryRow extends StatelessWidget {
  const _IncrementalUpdateEntryRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final accent = EhPalette.accent.resolveFrom(context);
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return EhPressable(
      onPressed: onTap,
      borderRadius: BorderRadius.zero,
      child: ColoredBox(
        color: accent.withValues(alpha: dark ? 0.11 : 0.07),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: EhPalette.accentSoft.resolveFrom(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: EhSvgIcon(
                  CupertinoIcons.arrow_2_circlepath,
                  size: 15,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.incremental_update_entry,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              EhSvgIcon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.provider,
    required this.onCopy,
    required this.onSearchUploader,
  });

  final GalleryProvider provider;
  final _CopyHandler onCopy;
  final ValueChanged<String> onSearchUploader;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;

    final category = provider.category?.trim() ?? '';
    final catColor = ThemeColors.catColor[category];
    final uploader = provider.uploader?.trim() ?? '';
    final canSearchUploader =
        uploader.isNotEmpty && uploader.toLowerCase() != '(disowned)';
    final postTime = provider.postTime?.trim() ?? '';
    final language = provider.language?.trim() ?? '';
    final rawFavcat = provider.favcat;
    final trimmedFavcat = rawFavcat?.trim();
    final isFav = trimmedFavcat != null && trimmedFavcat.isNotEmpty;
    final favTitle = provider.favTitle?.trim() ?? '';
    final favDisplay = rawFavcat == null
        ? '—'
        : isFav
        ? (favTitle.isNotEmpty ? favTitle : l10n.favcat)
        : l10n.notFav;
    final torrents = provider.torrentcount?.trim() ?? '';
    final visible = provider.visible?.trim() ?? '';
    final expunged = provider.expunged == true;

    final rows = <Widget>[
      _MetaKeyValueRow(
        label: l10n.gallery_info_category,
        value: _orDash(category),
        leadingValueDot: category.isNotEmpty && catColor != null
            ? CupertinoDynamicColor.resolve(catColor, context)
            : null,
        onTap: category.isNotEmpty ? () => unawaited(onCopy(category)) : null,
      ),
      _MetaKeyValueRow(
        label: l10n.uploader,
        value: _orDash(uploader),
        onTap: uploader.isNotEmpty ? () => unawaited(onCopy(uploader)) : null,
        trailingAction: canSearchUploader
            ? _MiniActionIconButton(
                icon: CupertinoIcons.search,
                semanticLabel: l10n.filter_by_uploader,
                onPressed: () => onSearchUploader(uploader),
              )
            : null,
      ),
      _MetaKeyValueRow(
        label: l10n.gallery_info_posted,
        value: _orDash(postTime),
        tabular: true,
        onTap: postTime.isNotEmpty ? () => unawaited(onCopy(postTime)) : null,
      ),
      _MetaKeyValueRow(
        label: l10n.uc_language,
        value: _orDash(language),
        onTap: language.isNotEmpty ? () => unawaited(onCopy(language)) : null,
      ),
      _MetaKeyValueRow(
        label: l10n.gallery_info_favorite_status,
        value: favDisplay,
        mutedValue: !isFav,
        leadingValueIcon: isFav
            ? EhSvgIcon(
                CupertinoIcons.heart_fill,
                size: 13,
                color: ThemeColors.favColorFor(provider.favcat),
              )
            : null,
        onTap: isFav ? () => unawaited(onCopy(favDisplay)) : null,
      ),
      _MetaKeyValueRow(
        label: l10n.p_Torrent,
        value: _orDash(torrents),
        tabular: true,
        onTap: torrents.isNotEmpty ? () => unawaited(onCopy(torrents)) : null,
      ),
      if (visible.isNotEmpty || expunged)
        _MetaKeyValueRow(
          label: l10n.gallery_info_visible,
          value: expunged ? l10n.gallery_info_expunged : visible,
          valueColor: expunged
              ? CupertinoDynamicColor.resolve(
                  CupertinoColors.systemRed,
                  context,
                )
              : palette.text1.resolveFrom(context),
          onTap: () => unawaited(
            onCopy(expunged ? l10n.gallery_info_expunged : visible),
          ),
        ),
    ];

    return _MetaSurfaceCard(children: rows);
  }
}

class _MetaKeyValueRow extends StatelessWidget {
  const _MetaKeyValueRow({
    required this.label,
    required this.value,
    this.tabular = false,
    this.mutedValue = false,
    this.valueColor,
    this.leadingValueDot,
    this.leadingValueIcon,
    this.trailingAction,
    this.onTap,
  });

  final String label;
  final String value;
  final bool tabular;
  final bool mutedValue;
  final Color? valueColor;
  final Color? leadingValueDot;
  final Widget? leadingValueIcon;
  final Widget? trailingAction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final resolvedValueColor =
        valueColor ??
        (mutedValue
            ? palette.text3.resolveFrom(context)
            : palette.text1.resolveFrom(context));

    final labelWidget = Text(
      label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: palette.text2.resolveFrom(context),
      ),
    );

    Widget buildValueWidget({required bool stacked}) {
      return Row(
        mainAxisSize: stacked ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: stacked
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: <Widget>[
          if (leadingValueDot != null) ...<Widget>[
            DecoratedBox(
              decoration: ShapeDecoration(
                color: leadingValueDot,
                shape: const CircleBorder(),
              ),
              child: const SizedBox.square(dimension: 7),
            ),
            const SizedBox(width: 6),
          ],
          if (leadingValueIcon != null) ...<Widget>[
            leadingValueIcon!,
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: stacked ? TextAlign.start : TextAlign.end,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: mutedValue ? FontWeight.w400 : FontWeight.w500,
                fontFeatures: tabular ? _kTabularFigures : null,
                color: resolvedValueColor,
              ),
            ),
          ),
          if (trailingAction != null) trailingAction!,
        ],
      );
    }

    final minRowHeight = math.max(46.0, _actionTargetSize());
    final body = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minRowHeight),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          16,
          trailingAction == null ? 10 : 1,
          trailingAction == null ? 16 : 2,
          trailingAction == null ? 10 : 1,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final stacked = textScale >= 1.45 || constraints.maxWidth < 250;
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  labelWidget,
                  const SizedBox(height: 4),
                  buildValueWidget(stacked: true),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.42,
                  ),
                  child: labelWidget,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: buildValueWidget(stacked: false),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    if (onTap == null) {
      return body;
    }
    return EhPressable(
      onPressed: onTap,
      borderRadius: BorderRadius.zero,
      child: body,
    );
  }
}

class _IdentifiersCard extends StatelessWidget {
  const _IdentifiersCard({
    required this.gid,
    required this.token,
    required this.galleryUrl,
    required this.coverUrl,
    required this.onCopy,
    required this.onOpenExternalUrl,
  });

  final String gid;
  final String token;
  final String galleryUrl;
  final String coverUrl;
  final _CopyHandler onCopy;
  final ValueChanged<String> onOpenExternalUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final children = <Widget>[
      _IdPairRow(
        gid: gid,
        token: token,
        onCopy: onCopy,
      ),
      if (galleryUrl.isNotEmpty)
        _CopyableTextBlock(
          label: l10n.gallery_info_gallery_url,
          text: galleryUrl,
          textStyle: TextStyle(
            fontSize: 12.5,
            height: 1.42,
            fontFamily: _monoFontFamily(),
            fontFamilyFallback: _kMonoFallbacks,
            color: palette.text1.resolveFrom(context),
          ),
          extraAction: _MiniActionIconButton(
            icon: CupertinoIcons.globe,
            semanticLabel: l10n.gallery_info_open_browser,
            onPressed: () => onOpenExternalUrl(galleryUrl),
          ),
          onCopy: () => onCopy(galleryUrl),
        ),
      if (coverUrl.isNotEmpty)
        _CopyableTextBlock(
          label: l10n.gallery_info_cover_url,
          text: coverUrl,
          textStyle: TextStyle(
            fontSize: 12,
            height: 1.42,
            fontFamily: _monoFontFamily(),
            fontFamilyFallback: _kMonoFallbacks,
            color: palette.text2.resolveFrom(context),
          ),
          onCopy: () => onCopy(coverUrl),
        ),
    ];

    return _MetaSurfaceCard(
      dividerIndent: 0,
      children: children,
    );
  }
}

class _IdPairRow extends StatelessWidget {
  const _IdPairRow({
    required this.gid,
    required this.token,
    required this.onCopy,
  });

  final String gid;
  final String token;
  final _CopyHandler onCopy;

  @override
  Widget build(BuildContext context) {
    final separator = EhPalette.separator.resolveFrom(context);
    final dividerThickness = 1.0 / MediaQuery.devicePixelRatioOf(context);

    final gidTile = _IdCell(
      label: 'GID',
      value: gid,
      onCopy: gid.isNotEmpty ? () => onCopy(gid) : null,
    );
    final tokenTile = _IdCell(
      label: 'Token',
      value: token,
      onCopy: token.isNotEmpty ? () => onCopy(token) : null,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final stacked = constraints.maxWidth < 290 || textScale >= 1.45;
        if (stacked) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              gidTile,
              ColoredBox(
                color: separator,
                child: SizedBox(
                  width: double.infinity,
                  height: dividerThickness,
                ),
              ),
              tokenTile,
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: gidTile),
              ColoredBox(
                color: separator,
                child: SizedBox(width: dividerThickness),
              ),
              Expanded(child: tokenTile),
            ],
          ),
        );
      },
    );
  }
}

class _IdCell extends StatefulWidget {
  const _IdCell({
    required this.label,
    required this.value,
    this.onCopy,
  });

  final String label;
  final String value;
  final _CopyAction? onCopy;

  @override
  State<_IdCell> createState() => _IdCellState();
}

class _IdCellState extends State<_IdCell> {
  bool _copied = false;
  Timer? _resetTimer;

  Future<void> _handleTap() async {
    final onCopy = widget.onCopy;
    if (onCopy == null) {
      return;
    }
    final copied = await onCopy();
    if (!copied || !mounted) {
      return;
    }
    setState(() => _copied = true);
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final display = _orDash(widget.value);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);

    final inner = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: palette.text2.resolveFrom(context),
                  ),
                ),
              ),
              if (widget.onCopy != null)
                AnimatedSwitcher(
                  duration: duration,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: Tween<double>(begin: 0.72, end: 1).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: EhSvgIcon(
                    _copied
                        ? CupertinoIcons.checkmark_alt
                        : CupertinoIcons.doc_on_doc,
                    key: ValueKey<bool>(_copied),
                    size: 13,
                    color: _copied
                        ? accent
                        : palette.text3.resolveFrom(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            display,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              fontFamily: _monoFontFamily(),
              fontFamilyFallback: _kMonoFallbacks,
              fontFeatures: _kTabularFigures,
              color: widget.value.isEmpty
                  ? palette.text3.resolveFrom(context)
                  : palette.text1.resolveFrom(context),
            ),
          ),
        ],
      ),
    );

    if (widget.onCopy == null) {
      return inner;
    }
    return Semantics(
      button: true,
      value: _copied ? L10n.of(context).copied_to_clipboard : null,
      child: EhPressable(
        onPressed: () => unawaited(_handleTap()),
        borderRadius: BorderRadius.zero,
        child: inner,
      ),
    );
  }
}

class _MiniActionIconButton extends StatelessWidget {
  const _MiniActionIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final target = _actionTargetSize();
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onPressed,
      child: EhPressable(
        onPressed: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: target,
          height: target,
          child: Center(
            child: EhSvgIcon(
              icon,
              size: 15,
              color: palette.text2.resolveFrom(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _CopyStatusButton extends StatelessWidget {
  const _CopyStatusButton({
    required this.copied,
    required this.semanticLabel,
    required this.copiedSemanticLabel,
    required this.onPressed,
  });

  final bool copied;
  final String semanticLabel;
  final String copiedSemanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final target = _actionTargetSize();
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);

    return Semantics(
      button: true,
      label: copied ? copiedSemanticLabel : semanticLabel,
      excludeSemantics: true,
      onTap: onPressed,
      child: EhPressable(
        onPressed: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: target,
          height: target,
          child: Center(
            child: AnimatedSwitcher(
              duration: duration,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: Tween<double>(begin: 0.72, end: 1).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: EhSvgIcon(
                copied
                    ? CupertinoIcons.checkmark_alt
                    : CupertinoIcons.doc_on_doc,
                key: ValueKey<bool>(copied),
                size: 15,
                color: copied ? accent : palette.text2.resolveFrom(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
