import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:eros_fe/common/controller/download/gallery_update_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/pages/tab/controller/download_view_controller.dart';
import 'package:eros_fe/route/navigator_util.dart';
import 'package:eros_fe/store/db/entity/gallery_task.dart';
import 'package:eros_fe/utils/toast.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/eh_sheet.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

typedef IncrementalPlanAnalyzer = Future<GalleryIncrementalPlan> Function({
  required GalleryTask oldTask,
  required GalleryNewerVersion targetVersion,
  CancelToken? cancelToken,
});

typedef IncrementalPlanExecutor = Future<GalleryIncrementalExecutionResult?>
    Function(
      GalleryIncrementalPlan plan, {
      required GalleryIncrementalUpdateMode mode,
    });

/// Presents an [EhSheet] comparing a downloaded gallery against its newer
/// version(s) and letting the user launch an incremental update.
Future<void> showGalleryIncrementalUpdateSheet(
  BuildContext context, {
  required GalleryTask oldTask,
  required List<GalleryNewerVersion> newerVersions,
  IncrementalPlanAnalyzer? analyzePlan,
  IncrementalPlanExecutor? executePlan,
  ValueChanged<GalleryNewerVersion>? onOpenVersion,
}) {
  if (newerVersions.isEmpty) {
    return Future<void>.value();
  }
  return showEhSheet<void>(
    context: context,
    builder: (sheetContext) => GalleryIncrementalUpdateSheet(
      oldTask: oldTask,
      newerVersions: newerVersions,
      analyzePlan: analyzePlan,
      executePlan: executePlan,
      onOpenVersion: onOpenVersion,
    ),
  );
}

class GalleryIncrementalUpdateSheet extends StatefulWidget {
  const GalleryIncrementalUpdateSheet({
    super.key,
    required this.oldTask,
    required this.newerVersions,
    this.analyzePlan,
    this.executePlan,
    this.onOpenVersion,
  });

  final GalleryTask oldTask;
  final List<GalleryNewerVersion> newerVersions;
  final IncrementalPlanAnalyzer? analyzePlan;
  final IncrementalPlanExecutor? executePlan;
  final ValueChanged<GalleryNewerVersion>? onOpenVersion;

  @override
  State<GalleryIncrementalUpdateSheet> createState() =>
      _GalleryIncrementalUpdateSheetState();
}

class _GalleryIncrementalUpdateSheetState
    extends State<GalleryIncrementalUpdateSheet> {
  static const Color _reuseGreen = Color(0xFF4CD98B);

  late int _selectedVersionIndex;
  late GalleryIncrementalUpdateMode _mode;
  GalleryIncrementalPlan? _plan;
  String? _error;
  bool _loading = true;
  bool _executing = false;
  CancelToken? _cancelToken;
  int _analyzeSeq = 0;

  bool get _targetBaseIsSaf =>
      Get.isRegistered<EhSettingService>() &&
      Get.find<EhSettingService>().downloadLocatino.isContentUri;

  bool get _isSaf =>
      (widget.oldTask.realDirPath?.isContentUri ?? false) ||
      _targetBaseIsSaf ||
      (_plan != null && !_plan!.canReuseLocalFiles);

  GalleryNewerVersion get _targetVersion =>
      widget.newerVersions[_selectedVersionIndex];

  @override
  void initState() {
    super.initState();
    _selectedVersionIndex = 0;
    _mode = _isSaf
        ? GalleryIncrementalUpdateMode.newTask
        : GalleryIncrementalUpdateMode.inPlace;
    _analyze();
  }

  @override
  void dispose() {
    _analyzeSeq++;
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<GalleryIncrementalPlan> _runAnalyze(
    GalleryNewerVersion target,
    CancelToken cancelToken,
  ) {
    if (widget.analyzePlan != null) {
      return widget.analyzePlan!(
        oldTask: widget.oldTask,
        targetVersion: target,
        cancelToken: cancelToken,
      );
    }
    return Get.find<DownloadViewController>().analyzeIncrementalUpdate(
      oldTask: widget.oldTask,
      targetVersion: target,
      cancelToken: cancelToken,
    );
  }

  Future<GalleryIncrementalExecutionResult?> _runExecute(
    GalleryIncrementalPlan plan,
    GalleryIncrementalUpdateMode mode,
  ) {
    if (widget.executePlan != null) {
      return widget.executePlan!(plan, mode: mode);
    }
    return Get.find<DownloadViewController>().executeIncrementalUpdate(
      plan,
      mode: mode,
    );
  }

  Future<void> _analyze() async {
    final requestId = ++_analyzeSeq;
    _cancelToken?.cancel();
    final token = CancelToken();
    _cancelToken = token;
    setState(() {
      _loading = true;
      _error = null;
      _plan = null;
    });
    try {
      final plan = await _runAnalyze(_targetVersion, token);
      if (!mounted || requestId != _analyzeSeq || token.isCancelled) {
        return;
      }
      setState(() {
        _plan = plan;
        _error = null;
        _loading = false;
        if (!plan.canReuseLocalFiles || _isSaf) {
          _mode = GalleryIncrementalUpdateMode.newTask;
        }
      });
    } on Object catch (e) {
      if (!mounted ||
          requestId != _analyzeSeq ||
          token.isCancelled ||
          isCancelError(e)) {
        return;
      }
      final message = e is DioException ? (e.message ?? e.toString()) : '$e';
      setState(() {
        _error = message;
        _loading = false;
      });
    }
  }

  Future<void> _confirm() async {
    final plan = _plan;
    if (plan == null || _executing) {
      return;
    }
    final effectiveMode = _isSaf
        ? GalleryIncrementalUpdateMode.newTask
        : _mode;
    setState(() => _executing = true);
    try {
      final result = await _runExecute(plan, effectiveMode);
      if (!mounted) {
        return;
      }
      final l10n = L10n.of(context);
      if (result != null) {
        vibrateUtil.light();
        if (result.completedLocally) {
          showToast(
            l10n.incremental_update_completed_locally(
              result.task.gid,
              result.reusedCount,
            ),
          );
        } else {
          showToast(
            l10n.incremental_update_started(
              result.reusedCount,
              result.downloadCount,
            ),
          );
        }
        Navigator.of(context).pop();
      } else {
        setState(() => _executing = false);
      }
    } on UnsupportedError {
      if (!mounted) {
        return;
      }
      showToast(L10n.of(context).incremental_update_saf_inplace_unsupported);
      setState(() {
        _mode = GalleryIncrementalUpdateMode.newTask;
        _executing = false;
      });
    } on Object catch (e) {
      if (!mounted) {
        return;
      }
      showToast('$e');
      setState(() => _executing = false);
    }
  }

  void _cycleTargetVersion() {
    if (widget.newerVersions.length <= 1 || _executing) {
      return;
    }
    setState(() {
      _selectedVersionIndex =
          (_selectedVersionIndex + 1) % widget.newerVersions.length;
    });
    _analyze();
  }

  void _openNewerDetail() {
    final version = _targetVersion;
    Navigator.of(context).pop();
    if (widget.onOpenVersion != null) {
      widget.onOpenVersion!(version);
      return;
    }
    NavigatorUtil.goGalleryPage(url: normalizeGalleryUrl(version.url));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final text1 = palette.text1.resolveFrom(context);
    final text2 = palette.text2.resolveFrom(context);
    final baseStyle = CupertinoTheme.of(context).textTheme.textStyle;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            EhSheetHeader(
              title: l10n.incremental_update_title,
              subtitle: l10n.incremental_update_subtitle,
            ),
            EhSheetSectionLabel(
              l10n.incremental_update_version_compare,
              trailing: widget.newerVersions.length > 1
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _cycleTargetVersion,
                      child: Text(
                        '#${_targetVersion.gid} (${_selectedVersionIndex + 1}/${widget.newerVersions.length}) ▾',
                        style: baseStyle.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    )
                  : null,
            ),
            if (_loading)
              EhSheetGroup(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 28,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const CupertinoActivityIndicator(radius: 13),
                        const SizedBox(height: 12),
                        Text(
                          l10n.incremental_update_comparing,
                          style: baseStyle.copyWith(
                            fontSize: 13,
                            color: text2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else if (_error != null)
              EhSheetGroup(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          l10n.incremental_update_compare_failed,
                          style: baseStyle.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: text1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _error!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: baseStyle.copyWith(fontSize: 12, color: text2),
                        ),
                        const SizedBox(height: 12),
                        EhButton(
                          label: l10n.sp_retry,
                          icon: CupertinoIcons.arrow_clockwise,
                          style: EhButtonStyle.tonal,
                          selected: true,
                          onPressed: _analyze,
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else if (_plan != null) ...<Widget>[
              _buildDiffTray(context, _plan!),
              EhSheetSectionLabel(l10n.incremental_update_mode_title),
              EhSheetGroup(
                children: <Widget>[
                  _ModeOptionRow(
                    title: l10n.incremental_update_mode_inplace,
                    badge: _isSaf ? null : l10n.incremental_update_recommended,
                    description: _isSaf
                        ? l10n.incremental_update_saf_inplace_unsupported
                        : l10n.incremental_update_mode_inplace_desc(
                            _plan!.newGid,
                          ),
                    selected: _mode == GalleryIncrementalUpdateMode.inPlace,
                    enabled: !_isSaf && !_executing,
                    onTap: () => setState(
                      () => _mode = GalleryIncrementalUpdateMode.inPlace,
                    ),
                  ),
                  _ModeOptionRow(
                    title: l10n.incremental_update_mode_new,
                    description: l10n.incremental_update_mode_new_desc(
                      _plan!.newGid,
                    ),
                    selected: _mode == GalleryIncrementalUpdateMode.newTask,
                    enabled: !_executing,
                    onTap: () => setState(
                      () => _mode = GalleryIncrementalUpdateMode.newTask,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    EhButton(
                      label: _executing
                          ? l10n.incremental_update_applying
                          : _confirmLabel(l10n, _plan!),
                      icon: _executing
                          ? null
                          : CupertinoIcons.arrow_down_to_line,
                      style: EhButtonStyle.prominent,
                      size: 46,
                      expand: true,
                      onPressed: _executing ? null : _confirm,
                    ),
                    const SizedBox(height: 8),
                    EhButton(
                      label: l10n.incremental_update_view_newer,
                      style: EhButtonStyle.fill,
                      size: 38,
                      expand: true,
                      onPressed: _executing ? null : _openNewerDetail,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _confirmLabel(L10n l10n, GalleryIncrementalPlan plan) {
    if (_isSaf) {
      return l10n.incremental_update_start_saf_full(plan.totalNewPages);
    }
    if (plan.downloadCount == 0) {
      return l10n.incremental_update_start_reuse_only;
    }
    return _mode == GalleryIncrementalUpdateMode.inPlace
        ? l10n.incremental_update_start_inplace(plan.downloadCount)
        : l10n.incremental_update_start_new(plan.downloadCount);
  }

  Widget _buildDiffTray(BuildContext context, GalleryIncrementalPlan plan) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final text1 = palette.text1.resolveFrom(context);
    final text2 = palette.text2.resolveFrom(context);
    final accent = EhPalette.accent.resolveFrom(context);
    final amber = EhPalette.star.resolveFrom(context);
    final separator = EhPalette.separator.resolveFrom(context);
    final baseStyle = CupertinoTheme.of(context).textTheme.textStyle;

    final total = math.max(1, plan.totalNewPages);
    final displayReused = _isSaf ? 0 : plan.reusedCount;
    final displayAdded = _isSaf ? plan.totalNewPages : plan.addedCount;
    final displayReplaced = _isSaf ? 0 : plan.replacedCount;
    final reuseFlex = (displayReused * 1000 / total).round();
    final addFlex = (displayAdded * 1000 / total).round();
    final replaceFlex = (displayReplaced * 1000 / total).round();

    return EhSheetGroup(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            children: <Widget>[
              _VersionLine(
                tag: l10n.incremental_update_local_tag,
                tagBg: palette.fill.resolveFrom(context),
                tagFg: text2,
                label: '#${plan.oldTask.gid}',
                stat: '${plan.oldTask.fileCount} P',
                highlightStat: false,
              ),
              const SizedBox(height: 8),
              _VersionLine(
                tag: l10n.incremental_update_newer_tag,
                tagBg: EhPalette.accentSoft.resolveFrom(context),
                tagFg: accent,
                label: plan.targetVersion.shortDate.isNotEmpty
                    ? '#${plan.newGid} · ${plan.targetVersion.shortDate}'
                    : '#${plan.newGid}',
                stat: '${plan.totalNewPages} P',
                highlightStat: true,
              ),
            ],
          ),
        ),
        IntrinsicHeight(
          child: Row(
            children: <Widget>[
              Expanded(
                child: _DiffMetric(
                  value: '$displayReused',
                  label: l10n.incremental_update_reused,
                  color: _reuseGreen,
                ),
              ),
              Container(width: 0.5, color: separator),
              Expanded(
                child: _DiffMetric(
                  value: '+$displayAdded',
                  label: l10n.incremental_update_added,
                  color: accent,
                ),
              ),
              Container(width: 0.5, color: separator),
              Expanded(
                child: _DiffMetric(
                  value: '$displayReplaced',
                  label: l10n.incremental_update_replaced,
                  color: amber,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 6,
                  child: Row(
                    children: <Widget>[
                      if (reuseFlex > 0)
                        Expanded(
                          flex: reuseFlex,
                          child: const ColoredBox(color: _reuseGreen),
                        ),
                      if (addFlex > 0)
                        Expanded(
                          flex: addFlex,
                          child: ColoredBox(color: accent),
                        ),
                      if (replaceFlex > 0)
                        Expanded(
                          flex: replaceFlex,
                          child: ColoredBox(color: amber),
                        ),
                      if (reuseFlex == 0 && addFlex == 0 && replaceFlex == 0)
                        Expanded(
                          child: ColoredBox(
                            color: palette.fill.resolveFrom(context),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _isSaf
                          ? l10n.incremental_update_only_download(
                              plan.totalNewPages,
                            )
                          : (plan.downloadCount == 0
                              ? l10n.incremental_update_all_reused
                              : l10n.incremental_update_only_download(
                                  plan.downloadCount,
                                )),
                      style: baseStyle.copyWith(
                        fontSize: 11.5,
                        color: text2,
                      ),
                    ),
                  ),
                  Text(
                    '${_isSaf ? 0 : plan.reusedCount}/${plan.totalNewPages}',
                    style: baseStyle.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: text1,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VersionLine extends StatelessWidget {
  const _VersionLine({
    required this.tag,
    required this.tagBg,
    required this.tagFg,
    required this.label,
    required this.stat,
    required this.highlightStat,
  });

  final String tag;
  final Color tagBg;
  final Color tagFg;
  final String label;
  final String stat;
  final bool highlightStat;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final baseStyle = CupertinoTheme.of(context).textTheme.textStyle;
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            color: tagBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            tag,
            style: baseStyle.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: tagFg,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: baseStyle.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: palette.text1.resolveFrom(context),
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          stat,
          style: baseStyle.copyWith(
            fontSize: 12,
            fontWeight: highlightStat ? FontWeight.w600 : FontWeight.w500,
            color: (highlightStat ? palette.text1 : palette.text2)
                .resolveFrom(context),
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _DiffMetric extends StatelessWidget {
  const _DiffMetric({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final baseStyle = CupertinoTheme.of(context).textTheme.textStyle;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            style: baseStyle.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: baseStyle.copyWith(
              fontSize: 11,
              color: ehTheme.palette.text2.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeOptionRow extends StatelessWidget {
  const _ModeOptionRow({
    required this.title,
    required this.description,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String description;
  final String? badge;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final baseStyle = CupertinoTheme.of(context).textTheme.textStyle;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: EhSvgIcon(
                  selected
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.circle,
                  size: 19,
                  color: selected ? accent : palette.text3.resolveFrom(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          title,
                          style: baseStyle.copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: palette.text1.resolveFrom(context),
                          ),
                        ),
                        if (badge != null)
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
                              badge!,
                              style: baseStyle.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: baseStyle.copyWith(
                        fontSize: 11.5,
                        height: 1.35,
                        color: palette.text2.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
