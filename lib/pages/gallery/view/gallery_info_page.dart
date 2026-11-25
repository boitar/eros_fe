import 'dart:math' as math;

import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/adaptive/native_top_header.dart';
import 'package:eros_fe/common/controller/download/gallery_update_service.dart';
import 'package:eros_fe/common/controller/download_controller.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_controller.dart';
import 'package:eros_fe/pages/gallery/view/gallery_incremental_update_sheet.dart';
import 'package:eros_fe/route/navigator_util.dart';
import 'package:eros_fe/store/db/entity/gallery_task.dart';
import 'package:eros_fe/utils/toast.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

const kTextStyle = TextStyle(fontSize: 13);

class GalleryInfoPage extends StatelessWidget {
  const GalleryInfoPage({
    super.key,
    this.onOpenGalleryUrl,
    this.onIncrementalUpdate,
  });

  /// Optional override for navigating to a parent or newer gallery URL.
  final ValueChanged<String>? onOpenGalleryUrl;

  /// Optional override for launching the incremental update sheet.
  final void Function(
    BuildContext context,
    GalleryTask task,
    List<GalleryNewerVersion> versions,
  )?
  onIncrementalUpdate;

  void _openUrl(String rawUrl) {
    final normalized = normalizeGalleryUrl(rawUrl);
    if (normalized.isEmpty) {
      return;
    }
    if (onOpenGalleryUrl != null) {
      onOpenGalleryUrl!(normalized);
      return;
    }
    NavigatorUtil.goGalleryPage(url: normalized);
  }

  void _copyValue(BuildContext context, String value) {
    if (value.isEmpty) {
      return;
    }
    vibrateUtil.light();
    Clipboard.setData(ClipboardData(text: value));
    showToast(L10n.of(context).copied_to_clipboard);
  }

  GalleryTask? _downloadedCompleteTask(String? gidStr) {
    final gid = int.tryParse(gidStr ?? '');
    if (gid == null || !Get.isRegistered<DownloadController>()) {
      return null;
    }
    final task = Get.find<DownloadController>().dState.galleryTaskMap[gid];
    if (task == null || task.status != TaskStatus.complete.value) {
      return null;
    }
    return task;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final nativeBar = NativeNavigationScope.isEnabled(context);
    final topMargin = nativeBar
        ? math.max(10.0, NativeTopTabHeader.contentGapFor(context))
        : 10.0;

    return SettingScaffold(
      title: l10n.gallery_info,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
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
              final downloadedTask = hasNewer
                  ? _downloadedCompleteTask(provider.gid)
                  : null;

              final infoMap = <String, String?>{
                'Gid': provider.gid,
                'Token': provider.token,
                'Url': pageState.url,
                l10n.english_title: provider.englishTitle,
                l10n.japanese_title: provider.japaneseTitle,
                'Thumb': provider.imgUrl,
                'Category': provider.category,
                'Uploader': provider.uploader,
                'Posted': provider.postTime,
                'Language': provider.language,
                'Pages': provider.filecount,
                'Size': provider.filesizeText,
                'Favorite count': provider.favoritedCount,
                'Favorited': '${provider.favcat?.isNotEmpty ?? false}',
                'Favorite': provider.favTitle ?? '',
                'Rating count': provider.ratingCount,
                'Rating': '${provider.rating}',
                'Torrents': provider.torrentcount,
              };

              final metadataChildren = infoMap.entries
                  .map(
                    (e) => TextItem(
                      prefixText: e.key,
                      initialValue: e.value,
                    ),
                  )
                  .toList();

              if (!showLineageSection) {
                return CupertinoFormSection.insetGrouped(
                  backgroundColor: Colors.transparent,
                  margin: EdgeInsets.fromLTRB(16, topMargin, 16, 30),
                  children: metadataChildren,
                );
              }

              final lineageChildren = <Widget>[
                if (hasParentDisplay)
                  _ParentLineageRow(
                    parentText: rawParent,
                    parentGid: provider.parentGid,
                    parentHref: provider.parentHref,
                    hasLink: hasParentLink,
                    onTap: hasParentLink
                        ? () => _openUrl(provider.parentHref!)
                        : () => _copyValue(context, rawParent),
                    onLongPress: () => _copyValue(
                      context,
                      hasParentLink
                          ? normalizeGalleryUrl(provider.parentHref!)
                          : rawParent,
                    ),
                  ),
                for (var i = 0; i < newerVersions.length; i++)
                  _NewerVersionRow(
                    version: newerVersions[i],
                    isLatest: i == 0,
                    onTap: () => _openUrl(newerVersions[i].url),
                    onLongPress: () => _copyValue(
                      context,
                      normalizeGalleryUrl(newerVersions[i].url),
                    ),
                  ),
                if (downloadedTask != null)
                  _IncrementalUpdateEntryRow(
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
              ];

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CupertinoFormSection.insetGrouped(
                    backgroundColor: Colors.transparent,
                    header: _SectionHeaderRow(
                      title: l10n.gallery_lineage,
                      hint: l10n.gallery_lineage_tap_hint,
                    ),
                    margin: EdgeInsets.fromLTRB(16, topMargin, 16, 12),
                    children: lineageChildren,
                  ),
                  CupertinoFormSection.insetGrouped(
                    backgroundColor: Colors.transparent,
                    header: _SectionHeaderRow(
                      title: l10n.gallery_metadata,
                      hint: l10n.gallery_metadata_copy_hint,
                    ),
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                    children: metadataChildren,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SectionHeaderRow extends StatelessWidget {
  const _SectionHeaderRow({
    required this.title,
    required this.hint,
  });

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 8,
        runSpacing: 2,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.text2.resolveFrom(context),
            ),
          ),
          Text(
            hint,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
              color: palette.text3.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParentLineageRow extends StatelessWidget {
  const _ParentLineageRow({
    required this.parentText,
    required this.parentGid,
    required this.parentHref,
    required this.hasLink,
    required this.onTap,
    required this.onLongPress,
  });

  final String parentText;
  final String? parentGid;
  final String? parentHref;
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
        : (parentText.isNotEmpty ? parentText : l10n.gallery_parent_unavailable);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            Flexible(
              child: Text(
                l10n.gallery_parent,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: kTextStyle.copyWith(
                  fontWeight: FontWeight.w500,
                  color: palette.text2.resolveFrom(context),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  if (hasLink) ...<Widget>[
                    EhSvgIcon(
                      CupertinoIcons.arrow_turn_up_left,
                      size: 14,
                      color: accent,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: kTextStyle.copyWith(
                        fontWeight: hasLink ? FontWeight.w600 : FontWeight.w400,
                        color: hasLink
                            ? accent
                            : palette.text3.resolveFrom(context),
                      ),
                    ),
                  ),
                  if (hasLink) ...<Widget>[
                    const SizedBox(width: 4),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 14,
                      color: palette.text3.resolveFrom(context),
                    ),
                  ],
                ],
              ),
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: <Widget>[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isLatest ? accent : Colors.transparent,
                border: Border.all(
                  color: isLatest
                      ? accent
                      : palette.text3.resolveFrom(context),
                  width: 1.8,
                ),
                boxShadow: isLatest
                    ? <BoxShadow>[
                        BoxShadow(
                          color: accent.withValues(alpha: 0.32),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          version.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: kTextStyle.copyWith(
                            fontWeight:
                                isLatest ? FontWeight.w600 : FontWeight.w500,
                            color: palette.text1.resolveFrom(context),
                          ),
                        ),
                      ),
                      if (isLatest) ...<Widget>[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: EhPalette.accentSoft.resolveFrom(context),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            l10n.gallery_latest_version,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitleParts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: palette.text2.resolveFrom(context),
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ColoredBox(
        color: EhPalette.accentSoft.resolveFrom(context).withValues(alpha: 0.4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: <Widget>[
              EhSvgIcon(
                CupertinoIcons.arrow_2_circlepath,
                size: 16,
                color: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.incremental_update_entry,
                  style: kTextStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
              Icon(
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

class TextItem extends StatelessWidget {
  const TextItem({super.key, required this.prefixText, this.initialValue});
  final String prefixText;
  final String? initialValue;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        showToast(L10n.of(context).copied_to_clipboard);
        Clipboard.setData(ClipboardData(text: initialValue ?? ''));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Flexible(
              child: Text(
                prefixText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: kTextStyle.copyWith(
                  fontWeight: FontWeight.w500,
                  color: palette.text2.resolveFrom(context),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: SelectableText(
                  initialValue ?? '',
                  textAlign: TextAlign.end,
                  style: kTextStyle.copyWith(
                    color: palette.text1.resolveFrom(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
