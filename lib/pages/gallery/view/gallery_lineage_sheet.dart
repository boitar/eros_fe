import 'dart:async';

import 'package:eros_fe/common/controller/download/gallery_update_service.dart';
import 'package:eros_fe/common/controller/download_controller.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/pages/gallery/view/gallery_incremental_update_sheet.dart';
import 'package:eros_fe/pages/gallery/view/gallery_lineage_chain.dart';
import 'package:eros_fe/route/navigator_util.dart';
import 'package:eros_fe/store/db/entity/gallery_task.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/eh_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

/// Presents the version lineage sheet containing [GalleryLineageChain] and a
/// primary action when newer versions exist.
Future<void> showGalleryLineageSheet(
  BuildContext context, {
  required GalleryProvider provider,
  GalleryTask? downloadedTask,
  List<GalleryNewerVersion>? updatableNewerVersions,
  String? currentTitle,
  ValueChanged<String>? onOpenGalleryUrl,
  ValueChanged<String>? onCopy,
  VoidCallback? onIncrementalUpdate,
}) {
  final newerVersions = provider.newerVersionsNewestFirst;
  if (newerVersions.isEmpty && !galleryHasParentDisplay(provider)) {
    return Future<void>.value();
  }
  return showEhSheet<void>(
    context: context,
    builder: (sheetContext) => GalleryLineageSheet(
      provider: provider,
      downloadedTask: downloadedTask,
      updatableNewerVersions: updatableNewerVersions,
      currentTitle: currentTitle,
      onOpenGalleryUrl: onOpenGalleryUrl,
      onCopy: onCopy,
      onIncrementalUpdate: onIncrementalUpdate,
      hostContext: context,
    ),
  );
}

class GalleryLineageSheet extends StatelessWidget {
  const GalleryLineageSheet({
    super.key,
    required this.provider,
    this.downloadedTask,
    this.updatableNewerVersions,
    this.currentTitle,
    this.onOpenGalleryUrl,
    this.onCopy,
    this.onIncrementalUpdate,
    this.hostContext,
  });

  final GalleryProvider provider;
  final GalleryTask? downloadedTask;
  final List<GalleryNewerVersion>? updatableNewerVersions;
  final String? currentTitle;
  final ValueChanged<String>? onOpenGalleryUrl;
  final ValueChanged<String>? onCopy;
  final VoidCallback? onIncrementalUpdate;
  final BuildContext? hostContext;

  void _openUrl(BuildContext context, String rawUrl) {
    final normalized = normalizeGalleryUrl(rawUrl);
    if (normalized.isEmpty) {
      return;
    }
    Navigator.of(context).pop();
    if (onOpenGalleryUrl != null) {
      onOpenGalleryUrl!(normalized);
      return;
    }
    NavigatorUtil.goGalleryPage(url: normalized);
  }

  void _startIncrementalUpdate(
    BuildContext context,
    GalleryTask task,
    List<GalleryNewerVersion> versions,
  ) {
    final launchContext =
        (hostContext != null && hostContext!.mounted) ? hostContext! : context;
    Navigator.of(context).pop();
    if (onIncrementalUpdate != null) {
      onIncrementalUpdate!();
      return;
    }
    unawaited(
      showGalleryIncrementalUpdateSheet(
        launchContext,
        oldTask: task,
        newerVersions: versions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final newerVersions = provider.newerVersionsNewestFirst;
    final hasNewer = newerVersions.isNotEmpty;
    final effectiveUpdatable =
        updatableNewerVersions ??
        (Get.isRegistered<DownloadController>()
            ? filterUndownloadedNewerVersions(
                newerVersions,
                Get.find<DownloadController>().dState.galleryTaskMap,
              )
            : newerVersions);
    final canIncrementalUpdate =
        downloadedTask != null && effectiveUpdatable.isNotEmpty;
    final totalCount = galleryLineageTotalCount(provider);
    final baseStyle = CupertinoTheme.of(context).textTheme.textStyle;

    // Opaque approximation of the tray inside the sheet so hollow/dashed
    // nodes cleanly mask the connecting rail behind them.
    final nodeBg = dark
        ? const Color(0xFF2A2B31)
        : palette.surface.resolveFrom(context);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            EhSheetHeader(
              title: l10n.gallery_lineage,
              subtitle: l10n.gallery_lineage_count(totalCount),
            ),
            const SizedBox(height: 6),
            EhSheetGroup(
              children: <Widget>[
                GalleryLineageChain(
                  provider: provider,
                  currentTitle: currentTitle,
                  isDownloaded: downloadedTask != null,
                  nodeBackgroundColor: nodeBg,
                  onOpen: (url) => _openUrl(context, url),
                  onCopy: onCopy,
                ),
              ],
            ),
            if (hasNewer)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: canIncrementalUpdate
                    ? EhButton(
                        label: l10n.incremental_update_to_latest,
                        icon: CupertinoIcons.arrow_down_to_line,
                        style: EhButtonStyle.prominent,
                        size: 50,
                        expand: true,
                        onPressed: () => _startIncrementalUpdate(
                          context,
                          downloadedTask!,
                          effectiveUpdatable,
                        ),
                      )
                    : EhButton(
                        label: l10n.gallery_open_latest_version,
                        icon: CupertinoIcons.arrow_up_right_circle,
                        style: EhButtonStyle.prominent,
                        size: 50,
                        expand: true,
                        onPressed: () =>
                            _openUrl(context, newerVersions.first.url),
                      ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                l10n.gallery_lineage_copy_hint,
                textAlign: TextAlign.center,
                style: baseStyle.copyWith(
                  fontSize: 12,
                  height: 1.45,
                  letterSpacing: 0,
                  color: palette.text3.resolveFrom(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
