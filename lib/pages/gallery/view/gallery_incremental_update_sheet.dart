import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/controller/download/gallery_update_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/pages/gallery/view/gallery_lineage_chain.dart';
import 'package:eros_fe/pages/tab/controller/download_view_controller.dart';
import 'package:eros_fe/route/navigator_util.dart';
import 'package:eros_fe/store/db/entity/gallery_task.dart';
import 'package:eros_fe/utils/toast.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/eh_sheet.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:pull_down_button/pull_down_button.dart';

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
  static const double _kDiffCardMinHeight = 112;

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

  void _selectTargetVersion(int index) {
    if (_executing ||
        index < 0 ||
        index >= widget.newerVersions.length ||
        index == _selectedVersionIndex) {
      return;
    }
    setState(() => _selectedVersionIndex = index);
    _analyze();
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

  void _openNewerDetail() {
    final version = _targetVersion;
    Navigator.of(context).pop();
    if (widget.onOpenVersion != null) {
      widget.onOpenVersion!(version);
      return;
    }
    NavigatorUtil.goGalleryPage(url: normalizeGalleryUrl(version.url));
  }

  String _confirmLabel(L10n l10n, GalleryIncrementalPlan? plan) {
    if (_executing) {
      return l10n.incremental_update_applying;
    }
    if (_isSaf) {
      return l10n.incremental_update_start_saf_full;
    }
    if (plan != null && plan.downloadCount == 0) {
      return l10n.incremental_update_start_reuse_only;
    }
    return l10n.incremental_update_start;
  }

  String _modeFootnote(L10n l10n) {
    if (_isSaf) {
      return l10n.incremental_update_mode_new_saf_desc;
    }
    return _mode == GalleryIncrementalUpdateMode.inPlace
        ? l10n.incremental_update_mode_inplace_desc
        : l10n.incremental_update_mode_new_desc;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final text1 = palette.text1.resolveFrom(context);
    final text2 = palette.text2.resolveFrom(context);
    final baseStyle = CupertinoTheme.of(context).textTheme.textStyle;
    final effectiveMode = _isSaf
        ? GalleryIncrementalUpdateMode.newTask
        : _mode;
    final canSubmit = _plan != null && !_loading && !_executing;

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
            const SizedBox(height: 6),
            EhSheetGroup(
              children: <Widget>[
                _TargetVersionRow(
                  versions: widget.newerVersions,
                  currentTitle: widget.oldTask.title,
                  selectedIndex: _selectedVersionIndex,
                  enabled: !_executing,
                  onSelected: _selectTargetVersion,
                ),
              ],
            ),
            const SizedBox(height: 10),
            EhSheetGroup(
              children: <Widget>[
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: _kDiffCardMinHeight,
                  ),
                  child: _DiffSummary(
                    loading: _loading,
                    error: _error,
                    plan: _plan,
                    isSaf: _isSaf,
                    onRetry: _analyze,
                  ),
                ),
              ],
            ),
            EhSheetSectionLabel(l10n.incremental_update_old_version),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CupertinoSlidingSegmentedControl<
                  GalleryIncrementalUpdateMode>(
                groupValue: effectiveMode,
                children: <GalleryIncrementalUpdateMode, Widget>{
                  GalleryIncrementalUpdateMode.inPlace: Opacity(
                    opacity: _isSaf ? 0.38 : 1.0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Text(
                        l10n.incremental_update_mode_inplace,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: baseStyle.copyWith(
                          fontSize: 14,
                          fontWeight:
                              effectiveMode ==
                                  GalleryIncrementalUpdateMode.inPlace
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: _isSaf
                              ? palette.text3.resolveFrom(context)
                              : text1,
                        ),
                      ),
                    ),
                  ),
                  GalleryIncrementalUpdateMode.newTask: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Text(
                      l10n.incremental_update_mode_new,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: baseStyle.copyWith(
                        fontSize: 14,
                        fontWeight:
                            effectiveMode ==
                                GalleryIncrementalUpdateMode.newTask
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: text1,
                      ),
                    ),
                  ),
                },
                onValueChanged: (GalleryIncrementalUpdateMode? value) {
                  if (value == null || _executing) {
                    return;
                  }
                  if (_isSaf && value == GalleryIncrementalUpdateMode.inPlace) {
                    return;
                  }
                  setState(() => _mode = value);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
              child: Text(
                _modeFootnote(l10n),
                style: baseStyle.copyWith(
                  fontSize: 12.5,
                  height: 1.45,
                  letterSpacing: 0,
                  color: text2,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  EhButton(
                    label: _confirmLabel(l10n, _plan),
                    icon: _executing ? null : CupertinoIcons.arrow_down_to_line,
                    style: EhButtonStyle.prominent,
                    size: 50,
                    expand: true,
                    onPressed: canSubmit ? _confirm : null,
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 44,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(44, 44),
                      onPressed: _executing ? null : _openNewerDetail,
                      child: Text(
                        l10n.incremental_update_view_newer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: baseStyle.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                          color: accent,
                        ),
                      ),
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

String _extractVersionMenuLabel(GalleryNewerVersion version) {
  final title = version.title.trim();
  final matches = RegExp(r'\[([^\[\]]+)\]').allMatches(title).toList();
  if (matches.isNotEmpty) {
    final lastTag = matches.last.group(1)?.trim() ?? '';
    if (lastTag.isNotEmpty) {
      return lastTag;
    }
  }
  return title.isNotEmpty ? title : '#${version.gid}';
}

class _TargetVersionRow extends StatelessWidget {
  const _TargetVersionRow({
    required this.versions,
    required this.currentTitle,
    required this.selectedIndex,
    required this.enabled,
    required this.onSelected,
  });

  final List<GalleryNewerVersion> versions;
  final String currentTitle;
  final int selectedIndex;
  final bool enabled;
  final ValueChanged<int> onSelected;

  Future<void> _showFallbackActionSheet(BuildContext context) {
    final l10n = L10n.of(context);
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => EhActionSheet(
        title: Text(l10n.incremental_update_target_version),
        actions: <Widget>[
          for (var i = 0; i < versions.length; i++)
            EhActionSheetAction(
              icon: i == selectedIndex
                  ? CupertinoIcons.checkmark_alt
                  : CupertinoIcons.doc_text,
              systemIcon: i == selectedIndex ? 'checkmark' : 'doc.text',
              onPressed: () {
                Navigator.of(sheetContext).pop();
                onSelected(i);
              },
              child: Text(
                _menuTitle(
                  l10n,
                  versions[i],
                  currentTitle: currentTitle,
                  isLatest: i == 0,
                ),
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(l10n.cancel),
        ),
      ),
    );
  }

  static String _distinguishingLabel(
    GalleryNewerVersion version, {
    required String currentTitle,
  }) {
    final trimmed = formatLineageDistinguishingTitle(
      title: version.title,
      currentTitle: currentTitle,
    );
    if (trimmed.startsWith('…')) {
      return trimmed;
    }
    return _extractVersionMenuLabel(version);
  }

  static String _menuTitle(
    L10n l10n,
    GalleryNewerVersion version, {
    required String currentTitle,
    required bool isLatest,
  }) {
    final tag = _distinguishingLabel(version, currentTitle: currentTitle);
    if (isLatest) {
      return '${l10n.gallery_latest_version} · $tag';
    }
    return tag;
  }

  static String _menuSubtitle(GalleryNewerVersion version) {
    final date = version.shortMonthDay;
    if (date.isNotEmpty) {
      return '$date · #${version.gid}';
    }
    return '#${version.gid}';
  }

  Widget _buildRowBody(
    BuildContext context, {
    required bool multiple,
  }) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final text1 = palette.text1.resolveFrom(context);
    final text2 = palette.text2.resolveFrom(context);
    final text3 = palette.text3.resolveFrom(context);
    final baseStyle = CupertinoTheme.of(context).textTheme.textStyle;
    final current = versions[selectedIndex];
    final date = current.shortMonthDay;
    final primaryValue = selectedIndex == 0
        ? l10n.gallery_latest_version
        : _distinguishingLabel(current, currentTitle: currentTitle);
    final secondarySuffix = date.isNotEmpty
        ? ' · ${l10n.gallery_updated_on(date)}'
        : '';

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 12, 0),
        child: Row(
          children: <Widget>[
            Flexible(
              flex: 2,
              child: Text(
                l10n.incremental_update_target_version,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: baseStyle.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                  color: text1,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: primaryValue,
                      style: baseStyle.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        color: text1,
                      ),
                    ),
                    if (secondarySuffix.isNotEmpty)
                      TextSpan(
                        text: secondarySuffix,
                        style: baseStyle.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0,
                          color: text2,
                        ),
                      ),
                  ],
                ),
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (multiple) ...<Widget>[
              const SizedBox(width: 6),
              EhSvgIcon(
                CupertinoIcons.chevron_up_chevron_down,
                size: 15,
                color: text3,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final multiple = versions.length > 1;
    if (!multiple) {
      return _buildRowBody(context, multiple: false);
    }

    final useActionSheetFallback =
        !PlatformCapabilities.uiKitGlass &&
        ehSheetMaterialOf(context) == EhSheetMaterial.solid;
    if (useActionSheetFallback) {
      return Semantics(
        button: true,
        label: l10n.incremental_update_target_version,
        child: EhPressable(
          onPressed: enabled ? () => _showFallbackActionSheet(context) : null,
          borderRadius: BorderRadius.zero,
          child: _buildRowBody(context, multiple: true),
        ),
      );
    }

    return PullDownButton(
      itemBuilder: (menuContext) => <PullDownMenuEntry>[
        for (var i = 0; i < versions.length; i++)
          PullDownMenuItem.selectable(
            selected: i == selectedIndex,
            title: _menuTitle(
              l10n,
              versions[i],
              currentTitle: currentTitle,
              isLatest: i == 0,
            ),
            subtitle: _menuSubtitle(versions[i]),
            onTap: () => onSelected(i),
          ),
      ],
      buttonBuilder: (buttonContext, showMenu) => Semantics(
        button: true,
        label: l10n.incremental_update_target_version,
        child: EhPressable(
          onPressed: enabled ? showMenu : null,
          borderRadius: BorderRadius.zero,
          child: _buildRowBody(buttonContext, multiple: true),
        ),
      ),
    );
  }
}

class _DiffSummary extends StatelessWidget {
  const _DiffSummary({
    required this.loading,
    required this.error,
    required this.plan,
    required this.isSaf,
    required this.onRetry,
  });

  final bool loading;
  final String? error;
  final GalleryIncrementalPlan? plan;
  final bool isSaf;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final text1 = palette.text1.resolveFrom(context);
    final text2 = palette.text2.resolveFrom(context);
    final text3 = palette.text3.resolveFrom(context);
    final accent = EhPalette.accent.resolveFrom(context);
    final reuseGrey = text3.withValues(alpha: 0.45);
    final trackColor = palette.fillPressed.resolveFrom(context);
    final baseStyle = CupertinoTheme.of(context).textTheme.textStyle;

    if (loading) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: 36,
              child: Row(
                children: <Widget>[
                  const CupertinoActivityIndicator(radius: 9),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.incremental_update_comparing,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: baseStyle.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        color: text1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: trackColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  flex: 38,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: trackColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 30,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: trackColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const Spacer(flex: 32),
              ],
            ),
          ],
        ),
      );
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l10n.incremental_update_compare_failed,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: baseStyle.copyWith(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                color: text1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: baseStyle.copyWith(
                fontSize: 12.5,
                letterSpacing: 0,
                color: text2,
              ),
            ),
            const SizedBox(height: 10),
            EhButton(
              label: l10n.sp_retry,
              icon: CupertinoIcons.arrow_clockwise,
              style: EhButtonStyle.tonal,
              selected: true,
              size: 38,
              onPressed: onRetry,
            ),
          ],
        ),
      );
    }

    final resolvedPlan = plan;
    if (resolvedPlan == null) {
      return const SizedBox.shrink();
    }

    final total = math.max(1, resolvedPlan.totalNewPages);
    final reusedCount = isSaf ? 0 : resolvedPlan.reusedCount;
    final downloadCount = isSaf
        ? resolvedPlan.totalNewPages
        : resolvedPlan.downloadCount;
    final reuseFlex = (reusedCount * 1000 / total).round();
    final downloadFlex = (downloadCount * 1000 / total).round();

    final headlinePhrase = l10n.incremental_update_need_download(downloadCount);
    final countToken = '$downloadCount';
    final tokenIndex = headlinePhrase.indexOf(countToken);
    final prefix = tokenIndex > 0 ? headlinePhrase.substring(0, tokenIndex) : '';
    final suffix = tokenIndex >= 0
        ? headlinePhrase.substring(tokenIndex + countToken.length)
        : ' $headlinePhrase';

    final downloadLegendParts = <String>[
      if (resolvedPlan.addedCount > 0)
        l10n.incremental_update_added_pages(resolvedPlan.addedCount),
      if (resolvedPlan.replacedCount > 0)
        l10n.incremental_update_replaced_approx(resolvedPlan.replacedCount),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Expanded(
                flex: 3,
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      if (prefix.isNotEmpty)
                        TextSpan(
                          text: prefix,
                          style: baseStyle.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                            color: text1,
                          ),
                        ),
                      TextSpan(
                        text: countToken,
                        style: baseStyle.copyWith(
                          fontSize: 30,
                          height: 1.05,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: accent,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                      if (suffix.isNotEmpty)
                        TextSpan(
                          text: suffix,
                          style: baseStyle.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                            color: text1,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: Text(
                  isSaf
                      ? l10n.incremental_update_cannot_reuse
                      : l10n.incremental_update_total_pages(
                          resolvedPlan.totalNewPages,
                        ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: baseStyle.copyWith(
                    fontSize: 13,
                    letterSpacing: 0,
                    color: text2,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 8,
              color: trackColor,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (reuseFlex > 0)
                    Expanded(
                      flex: reuseFlex,
                      child: ColoredBox(
                        color: reuseGrey,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  if (reuseFlex > 0 && downloadFlex > 0)
                    const SizedBox(width: 2),
                  if (downloadFlex > 0)
                    Expanded(
                      flex: downloadFlex,
                      child: ColoredBox(
                        color: accent,
                        child: const SizedBox.expand(),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (isSaf)
                _LegendItem(
                  color: accent,
                  label: l10n.incremental_update_saf_short_note,
                )
              else ...<Widget>[
                _LegendItem(
                  color: reuseGrey,
                  label: l10n.incremental_update_reused_pages(reusedCount),
                ),
                if (downloadCount == 0)
                  Text(
                    l10n.incremental_update_all_reused,
                    style: baseStyle.copyWith(
                      fontSize: 12.5,
                      letterSpacing: 0,
                      color: text2,
                    ),
                  )
                else if (downloadLegendParts.isNotEmpty)
                  _LegendItem(
                    color: accent,
                    label: downloadLegendParts.join(' · '),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final baseStyle = CupertinoTheme.of(context).textTheme.textStyle;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: baseStyle.copyWith(
              fontSize: 12.5,
              letterSpacing: 0,
              color: ehTheme.palette.text2.resolveFrom(context),
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
