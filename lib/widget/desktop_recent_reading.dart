import 'package:eros_fe/common/controller/recent_reading_store.dart';
import 'package:eros_fe/common/service/desktop_reading_source.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/route/navigator_util.dart';
import 'package:eros_fe/widget/desktop_browse_style.dart';
import 'package:eros_fe/widget/desktop_control.dart';
import 'package:eros_fe/widget/desktop_gallery_actions.dart';
import 'package:eros_fe/widget/image/eh_cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';

/// The compact, five-row reading projection used by the desktop sidebar.
/// It observes only successful reader presentations; browser history remains a
/// separate destination below the projection.
class DesktopRecentReading extends StatefulWidget {
  const DesktopRecentReading({
    super.key,
    required this.onHistory,
    this.store,
    this.openEntry,
  });

  final VoidCallback onHistory;
  final RecentReadingStore? store;
  final Future<bool> Function(RecentReadingEntry)? openEntry;

  @override
  State<DesktopRecentReading> createState() => _DesktopRecentReadingState();
}

class _DesktopRecentReadingState extends State<DesktopRecentReading> {
  final _source = const DesktopReadingSource();
  String? _opening;
  String? _failed;
  RecentReadingStore get store => widget.store ?? RecentReadingStore.instance;

  @override
  void initState() {
    super.initState();
    store.load();
  }

  Future<void> _open(RecentReadingEntry entry) async {
    if (_opening != null) return;
    setState(() {
      _opening = entry.id;
      _failed = null;
    });
    try {
      final opened = await (widget.openEntry ?? _source.open)(entry);
      if (!opened && mounted) setState(() => _failed = entry.id);
    } on Object {
      if (mounted) setState(() => _failed = entry.id);
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  void _details(
    BuildContext context,
    RecentReadingEntry entry,
    Offset position,
  ) {
    final provider = _source.providerFor(entry);
    if (provider == null) return;
    showDesktopGalleryMenu(
      context,
      position: position,
      entries: [
        DesktopMenuEntry(
          label: L10n.of(context).desktop_view_details,
          icon: CupertinoIcons.info_circle,
          onSelected: () =>
              NavigatorUtil.goGalleryPage(galleryProvider: provider),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final entries = store.recent;
      final l10n = L10n.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
              child: Text(
                l10n.desktop_recent_empty,
                style: TextStyle(
                  fontSize: 12,
                  color: ehTheme.palette.text2.resolveFrom(context),
                ),
              ),
            ),
          for (final entry in entries) ...[
            _RecentReadingRow(
              key: ValueKey(entry.id),
              entry: entry,
              busy: _opening == entry.id,
              onTap: _opening == null ? () => _open(entry) : null,
              onSecondaryTapDown: (event) =>
                  _details(context, entry, event.globalPosition),
            ),
            if (_failed == entry.id)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
                child: Text(
                  l10n.desktop_read_unavailable,
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemRed.resolveFrom(context),
                  ),
                ),
              ),
          ],
          DesktopControl(
            label: l10n.desktop_all_history,
            tooltip: false,
            hoverColor: DesktopBrowseStyle.capsuleHover(context),
            pressedColor: DesktopBrowseStyle.capsulePressed(context),
            onPressed: widget.onHistory,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                l10n.desktop_all_history,
                style: TextStyle(
                  fontSize: 12,
                  color: EhPalette.accent.resolveFrom(context),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _RecentReadingRow extends StatelessWidget {
  const _RecentReadingRow({
    super.key,
    required this.entry,
    required this.onTap,
    required this.busy,
    required this.onSecondaryTapDown,
  });

  final RecentReadingEntry entry;
  final VoidCallback? onTap;
  final bool busy;
  final GestureTapDownCallback onSecondaryTapDown;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final title = entry.title?.trim().isNotEmpty == true
        ? entry.title!.trim()
        : l10n.desktop_untitled;
    final progress = entry.total != null
        ? l10n.continue_reading_page('${entry.index + 1} / ${entry.total}')
        : l10n.continue_reading_page(entry.index + 1);
    final cover = entry.cover;
    return DesktopControl(
      label: '$title, $progress',
      tooltip: false,
      hoverColor: DesktopBrowseStyle.capsuleHover(context),
      pressedColor: DesktopBrowseStyle.capsulePressed(context),
      onPressed: onTap,
      onSecondaryTapDown: onSecondaryTapDown,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 36),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              height: 34,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: cover == null || cover.isEmpty
                    ? ColoredBox(
                        color: ehTheme.palette.text2
                            .resolveFrom(context)
                            .withValues(alpha: .12),
                        child: const EhSvgIcon(CupertinoIcons.book, size: 14),
                      )
                    : EhCachedNetworkImage(
                        imageUrl: cover,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            const EhSvgIcon(CupertinoIcons.book, size: 14),
                        errorWidget: (_, __, ___) =>
                            const EhSvgIcon(CupertinoIcons.book, size: 14),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            if (busy)
              const Padding(
                padding: EdgeInsetsDirectional.only(end: 6),
                child: CupertinoActivityIndicator(radius: 7),
              ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    progress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: ehTheme.palette.text2.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
