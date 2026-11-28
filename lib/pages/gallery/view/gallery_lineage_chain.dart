import 'dart:async';
import 'dart:math' as math;

import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/controller/download/gallery_update_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/route/navigator_util.dart';
import 'package:eros_fe/store/db/entity/gallery_task.dart';
import 'package:eros_fe/utils/toast.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

const List<String> _kMonoFallbacks = <String>[
  'SF Mono',
  'Menlo',
  'Consolas',
  'monospace',
];

const List<FontFeature> _kTabularFigures = <FontFeature>[
  FontFeature.tabularFigures(),
];

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

/// Whether [provider] carries a displayable parent entry (either a valid link
/// or non-empty parent metadata other than `"None"`).
bool galleryHasParentDisplay(GalleryProvider provider) {
  if (provider.hasParentLink) {
    return true;
  }
  final rawParent = provider.parent?.trim() ?? '';
  return rawParent.isNotEmpty && rawParent.toLowerCase() != 'none';
}

/// Total number of versions in [provider]'s visible lineage chain
/// (newer versions + current gallery + optional parent).
int galleryLineageTotalCount(GalleryProvider provider) {
  final newerCount = provider.newerVersionsNewestFirst.length;
  final parentCount = galleryHasParentDisplay(provider) ? 1 : 0;
  return newerCount + 1 + parentCount;
}

/// Filters [versions] to those not already present in [galleryTaskMap],
/// matching the download page's updatable check (`!galleryTaskMap.containsKey(v.gidInt)`).
List<GalleryNewerVersion> filterUndownloadedNewerVersions(
  List<GalleryNewerVersion> versions,
  Map<int, GalleryTask>? galleryTaskMap,
) {
  if (versions.isEmpty || galleryTaskMap == null || galleryTaskMap.isEmpty) {
    return versions;
  }
  return versions
      .where((v) => !galleryTaskMap.containsKey(v.gidInt))
      .toList();
}

/// Strips a shared word-boundary prefix (>= 12 chars) between [title] and
/// [currentTitle] so distinguishing version suffixes (such as
/// `"Updated 10/28/2026"`) remain visible instead of being ellipsized away.
///
/// Falls back to [title] when the shared prefix is too short or the remainder
/// is empty.
String formatLineageDistinguishingTitle({
  required String title,
  String? currentTitle,
}) {
  final target = title.trim();
  final base = currentTitle?.trim() ?? '';
  if (target.isEmpty || base.isEmpty) {
    return target;
  }

  final maxCommon = math.min(target.length, base.length);
  var common = 0;
  while (common < maxCommon &&
      target.codeUnitAt(common) == base.codeUnitAt(common)) {
    common++;
  }
  if (common < 12) {
    return target;
  }

  bool isWhitespace(int codeUnit) =>
      codeUnit == 0x20 || codeUnit == 0x09 || codeUnit == 0x3000;

  bool isBoundaryChar(int codeUnit) =>
      isWhitespace(codeUnit) ||
      codeUnit == 0x2F || // /
      codeUnit == 0x2D || // -
      codeUnit == 0x5F || // _
      codeUnit == 0x7C || // |
      codeUnit == 0xB7 || // ·
      codeUnit == 0x30FB; // ・

  var cut = common;
  if (cut < target.length && !isWhitespace(target.codeUnitAt(cut))) {
    var ws = cut;
    while (ws > 0 && !isWhitespace(target.codeUnitAt(ws - 1))) {
      ws--;
    }
    if (ws >= 12) {
      cut = ws;
    } else {
      var sep = cut;
      while (sep > 0 && !isBoundaryChar(target.codeUnitAt(sep - 1))) {
        sep--;
      }
      cut = sep;
    }
  }

  var tail = target.substring(cut).trimLeft();
  if (tail.isNotEmpty &&
      (RegExp(r'^[0-9]').hasMatch(tail) || tail.length < 12)) {
    var prevEnd = cut;
    while (prevEnd > 0 && isWhitespace(target.codeUnitAt(prevEnd - 1))) {
      prevEnd--;
    }
    var prevStart = prevEnd;
    while (prevStart > 0 && !isWhitespace(target.codeUnitAt(prevStart - 1))) {
      prevStart--;
    }
    if (prevStart >= 12) {
      cut = prevStart;
      tail = target.substring(cut).trimLeft();
    }
  }

  if (cut < 12 || tail.isEmpty) {
    return target;
  }
  return '…$tail';
}

/// Extracts `MM-dd` from `YYYY-MM-DD...` strings for compact lineage subtitles.
String formatLineageMonthDay(String? raw) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty) {
    return '';
  }
  final datePart = trimmed.split(' ').first;
  if (datePart.length >= 10 && datePart[4] == '-' && datePart[7] == '-') {
    return datePart.substring(5, 10);
  }
  return datePart;
}

String _resolveCurrentTitle(GalleryProvider provider, String? overrideTitle) {
  final override = overrideTitle?.trim() ?? '';
  if (override.isNotEmpty) {
    return override;
  }
  final jp = provider.japaneseTitle?.trim() ?? '';
  if (jp.isNotEmpty) {
    return jp;
  }
  final en = provider.englishTitle?.trim() ?? '';
  if (en.isNotEmpty) {
    return en;
  }
  final gid = provider.gid?.trim() ?? '';
  return gid.isNotEmpty ? '#$gid' : '—';
}

String _resolveCurrentUrl(GalleryProvider provider) {
  final raw = provider.url?.trim() ?? '';
  if (raw.isNotEmpty) {
    final normalized = normalizeGalleryUrl(raw);
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  final gid = provider.gid?.trim() ?? '';
  final token = provider.token?.trim() ?? '';
  if (gid.isNotEmpty && token.isNotEmpty) {
    return normalizeGalleryUrl('/g/$gid/$token/');
  }
  return '';
}

enum _ChainNodeKind { latest, newer, current, parent }

/// Shared version lineage chain displayed in both [GalleryLineageSheet] and
/// [GalleryInfoPage].
///
/// Order from top to bottom:
/// `newerVersionsNewestFirst` (latest first) -> current (non-interactive) -> parent.
class GalleryLineageChain extends StatelessWidget {
  const GalleryLineageChain({
    super.key,
    required this.provider,
    this.currentTitle,
    this.isDownloaded = false,
    this.nodeBackgroundColor,
    this.onOpen,
    this.onCopy,
  });

  final GalleryProvider provider;
  final String? currentTitle;
  final bool isDownloaded;

  /// Surface color painted inside hollow/dashed nodes so the connecting rail
  /// does not bleed through. Defaults to `ehTheme.palette.surface`.
  final Color? nodeBackgroundColor;

  /// Called with a normalized E-Hentai/ExHentai gallery URL on tap.
  final ValueChanged<String>? onOpen;

  /// Called with a URL or parent identifier on long press.
  final ValueChanged<String>? onCopy;

  void _handleOpen(String rawUrl) {
    final normalized = normalizeGalleryUrl(rawUrl);
    if (normalized.isEmpty) {
      return;
    }
    if (onOpen != null) {
      onOpen!(normalized);
      return;
    }
    NavigatorUtil.goGalleryPage(url: normalized);
  }

  void _handleCopy(BuildContext context, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }
    if (onCopy != null) {
      onCopy!(trimmed);
      return;
    }
    vibrateUtil.light();
    unawaited(Clipboard.setData(ClipboardData(text: trimmed)));
    if (context.mounted) {
      showToast(L10n.of(context).copied_to_clipboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final hairline = palette.hairline.resolveFrom(context);
    final nodeBg = nodeBackgroundColor ?? palette.surface.resolveFrom(context);

    final newerVersions = provider.newerVersionsNewestFirst;
    final resolvedCurrentTitle = _resolveCurrentTitle(provider, currentTitle);
    final rawParent = provider.parent?.trim() ?? '';
    final hasParentLink = provider.hasParentLink;
    final hasParentDisplay = galleryHasParentDisplay(provider);

    final entries = <_ChainEntry>[
      for (var i = 0; i < newerVersions.length; i++)
        _ChainEntry(
          key: ValueKey<String>('lineage-newer-${newerVersions[i].gid}'),
          kind: i == 0 ? _ChainNodeKind.latest : _ChainNodeKind.newer,
          title: formatLineageDistinguishingTitle(
            title: newerVersions[i].title,
            currentTitle: resolvedCurrentTitle,
          ),
          maxTitleLines: 2,
          tagText: i == 0 ? l10n.gallery_latest_version : null,
          accentTag: i == 0,
          dateText: newerVersions[i].shortMonthDay,
          monoText: '#${newerVersions[i].gid}',
          clickable: true,
          onTap: () => _handleOpen(newerVersions[i].url),
          onLongPress: () =>
              _handleCopy(context, normalizeGalleryUrl(newerVersions[i].url)),
        ),
      _ChainEntry(
        key: ValueKey<String>('lineage-current-${provider.gid ?? ''}'),
        kind: _ChainNodeKind.current,
        title: resolvedCurrentTitle,
        tagText: l10n.gallery_lineage_current,
        accentTag: false,
        dateText: formatLineageMonthDay(provider.postTime),
        suffixText: isDownloaded ? l10n.downloaded : null,
        clickable: false,
        onTap: null,
        onLongPress: () {
          final currentUrl = _resolveCurrentUrl(provider);
          if (currentUrl.isNotEmpty) {
            _handleCopy(context, currentUrl);
          }
        },
      ),
      if (hasParentDisplay)
        _ChainEntry(
          key: ValueKey<String>('lineage-parent-${provider.parentGid ?? rawParent}'),
          kind: _ChainNodeKind.parent,
          title: l10n.gallery_parent,
          monoText: hasParentLink
              ? (provider.parentGid != null && provider.parentGid!.isNotEmpty
                  ? '#${provider.parentGid}'
                  : rawParent)
              : (rawParent.isNotEmpty
                  ? rawParent
                  : l10n.gallery_parent_unavailable),
          clickable: hasParentLink,
          onTap: hasParentLink
              ? () => _handleOpen(provider.parentHref!)
              : null,
          onLongPress: () => _handleCopy(
            context,
            hasParentLink
                ? normalizeGalleryUrl(provider.parentHref!)
                : rawParent,
          ),
        ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < entries.length; i++) ...<Widget>[
          if (i > 0)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 44, end: 14),
              child: Container(height: 0.5, color: hairline),
            ),
          _ChainRow(
            entry: entries[i],
            isFirst: i == 0,
            isLast: i == entries.length - 1,
            showRail: entries.length > 1,
            nodeBackgroundColor: nodeBg,
          ),
        ],
      ],
    );
  }
}

class _ChainEntry {
  const _ChainEntry({
    this.key,
    required this.kind,
    required this.title,
    this.maxTitleLines = 1,
    this.tagText,
    this.accentTag = false,
    this.dateText = '',
    this.monoText = '',
    this.suffixText,
    required this.clickable,
    this.onTap,
    this.onLongPress,
  });

  final Key? key;
  final _ChainNodeKind kind;
  final String title;
  final int maxTitleLines;
  final String? tagText;
  final bool accentTag;
  final String dateText;
  final String monoText;
  final String? suffixText;
  final bool clickable;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
}

class _ChainRow extends StatelessWidget {
  const _ChainRow({
    required this.entry,
    required this.isFirst,
    required this.isLast,
    required this.showRail,
    required this.nodeBackgroundColor,
  });

  final _ChainEntry entry;
  final bool isFirst;
  final bool isLast;
  final bool showRail;
  final Color nodeBackgroundColor;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final text1 = palette.text1.resolveFrom(context);
    final text2 = palette.text2.resolveFrom(context);
    final text3 = palette.text3.resolveFrom(context);
    final accent = EhPalette.accent.resolveFrom(context);
    final accentSoft = EhPalette.accentSoft.resolveFrom(context);
    final hairline = palette.hairline.resolveFrom(context);
    final baseStyle = CupertinoTheme.of(context).textTheme.textStyle;

    final isCurrent = entry.kind == _ChainNodeKind.current;
    final isParent = entry.kind == _ChainNodeKind.parent;
    final titleColor = isCurrent ? text2 : text1;
    final titleWeight =
        (isCurrent || isParent) ? FontWeight.w500 : FontWeight.w600;

    final subtitleMeta = <String>[
      if (entry.dateText.isNotEmpty) entry.dateText,
      if (entry.suffixText != null && entry.suffixText!.isNotEmpty)
        entry.suffixText!,
    ].join(' · ');

    final rowContent = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 58),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 4, 0),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                width: 30,
                child: CustomPaint(
                  painter: showRail
                      ? _ChainRailPainter(
                          color: hairline,
                          drawTop: !isFirst,
                          drawBottom: !isLast,
                        )
                      : null,
                  child: Center(
                    child: _ChainNodeDot(
                      kind: entry.kind,
                      backgroundColor: nodeBackgroundColor,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        entry.title,
                        maxLines: entry.maxTitleLines,
                        overflow: TextOverflow.ellipsis,
                        style: baseStyle.copyWith(
                          fontSize: 14.5,
                          height: 1.3,
                          fontWeight: titleWeight,
                          letterSpacing: 0,
                          color: titleColor,
                        ),
                      ),
                      if (entry.tagText != null ||
                          subtitleMeta.isNotEmpty ||
                          entry.monoText.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Row(
                          children: <Widget>[
                            if (entry.tagText != null) ...<Widget>[
                              Container(
                                height: 18,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: entry.accentTag
                                      ? accentSoft
                                      : palette.fillPressed.resolveFrom(
                                          context,
                                        ),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  entry.tagText!,
                                  style: baseStyle.copyWith(
                                    fontSize: 11,
                                    height: 1.0,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0,
                                    color: entry.accentTag ? accent : text2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (subtitleMeta.isNotEmpty) ...<Widget>[
                              Flexible(
                                child: Text(
                                  subtitleMeta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: baseStyle.copyWith(
                                    fontSize: 12.5,
                                    letterSpacing: 0,
                                    color: text2,
                                    fontFeatures: _kTabularFigures,
                                  ),
                                ),
                              ),
                              if (entry.monoText.isNotEmpty)
                                const SizedBox(width: 6),
                            ],
                            if (entry.monoText.isNotEmpty)
                              Flexible(
                                child: Text(
                                  entry.monoText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: baseStyle.copyWith(
                                    fontSize: 11.5,
                                    letterSpacing: 0,
                                    fontFamily: _monoFontFamily(),
                                    fontFamilyFallback: _kMonoFallbacks,
                                    fontFeatures: _kTabularFigures,
                                    color: text2,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 36,
                child: entry.clickable
                    ? Center(
                        child: EhSvgIcon(
                          CupertinoIcons.chevron_right,
                          size: 13,
                          color: text3,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );

    if (!entry.clickable) {
      return Semantics(
        key: entry.key,
        container: true,
        label: entry.title,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: entry.onLongPress,
          child: rowContent,
        ),
      );
    }

    return Semantics(
      key: entry.key,
      button: true,
      label: entry.title,
      child: EhPressable(
        onPressed: entry.onTap,
        onLongPress: entry.onLongPress,
        borderRadius: BorderRadius.zero,
        child: rowContent,
      ),
    );
  }
}

class _ChainRailPainter extends CustomPainter {
  const _ChainRailPainter({
    required this.color,
    required this.drawTop,
    required this.drawBottom,
  });

  final Color color;
  final bool drawTop;
  final bool drawBottom;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final startY = drawTop ? 0.0 : centerY;
    final endY = drawBottom ? size.height : centerY;
    if (endY <= startY) {
      return;
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(centerX, startY), Offset(centerX, endY), paint);
  }

  @override
  bool shouldRepaint(_ChainRailPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.drawTop != drawTop ||
      oldDelegate.drawBottom != drawBottom;
}

class _ChainNodeDot extends StatelessWidget {
  const _ChainNodeDot({
    required this.kind,
    required this.backgroundColor,
  });

  final _ChainNodeKind kind;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final accent = EhPalette.accent.resolveFrom(context);
    final accentSoft = EhPalette.accentSoft.resolveFrom(context);
    final text3 = ehTheme.palette.text3.resolveFrom(context);

    switch (kind) {
      case _ChainNodeKind.latest:
        return Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent,
            boxShadow: <BoxShadow>[
              BoxShadow(color: accentSoft, spreadRadius: 4),
            ],
          ),
        );
      case _ChainNodeKind.current:
        return Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor,
            border: Border.all(color: accent, width: 2.4),
          ),
        );
      case _ChainNodeKind.newer:
        return Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor,
            border: Border.all(color: text3, width: 1.6),
          ),
        );
      case _ChainNodeKind.parent:
        return SizedBox(
          width: 11,
          height: 11,
          child: CustomPaint(
            painter: _DashedCirclePainter(
              strokeColor: text3,
              fillColor: backgroundColor,
              strokeWidth: 1.6,
            ),
          ),
        );
    }
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({
    required this.strokeColor,
    required this.fillColor,
    required this.strokeWidth,
  });

  final Color strokeColor;
  final Color fillColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    canvas.drawCircle(center, radius, Paint()..color = fillColor);

    final strokePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const dashCount = 6;
    const step = (math.pi * 2) / dashCount;
    const sweep = step * 0.52;
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(rect, i * step, sweep, false, strokePaint);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter oldDelegate) =>
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
