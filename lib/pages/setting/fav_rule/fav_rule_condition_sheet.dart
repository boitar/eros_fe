import 'dart:async';
import 'dart:ui' as ui;

import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/fav_rule.dart';
import 'package:eros_fe/store/db/entity/tag_translat.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:eros_fe/widget/fav_rule_safe_area.dart';
import 'package:eros_fe/widget/fav_rule_widgets.dart';
import 'package:flutter/cupertino.dart';

const Key kFavRuleConditionSheetCloseKey =
    ValueKey<String>('fav_rule_condition_sheet_close');
const Key kFavRuleConditionSheetSaveKey =
    ValueKey<String>('fav_rule_condition_sheet_save');
const Key kFavRuleConditionSheetOperatorKey =
    ValueKey<String>('fav_rule_condition_sheet_operator');
const Key kFavRuleConditionSheetDeleteKey =
    ValueKey<String>('fav_rule_condition_sheet_delete');

typedef FavRuleTagPreviewQuery = Future<(List<TagTranslat>, int)> Function({
  required String value,
  String? namespace,
  required String opName,
  required bool matchTranslation,
  required int limit,
});

enum _ConditionMode {
  tag,
  category,
}

/// Opens the Liquid Glass Add/Edit Condition bottom sheet (Panel ④).
Future<FavRuleCondition?> showFavRuleConditionSheet(
  BuildContext context, {
  FavRuleCondition? initial,
  VoidCallback? onDelete,
  @visibleForTesting FavRuleTagPreviewQuery? debugQueryOverride,
  @visibleForTesting Future<int> Function()? debugCountOverride,
}) {
  return showCupertinoModalPopup<FavRuleCondition>(
    context: context,
    barrierColor: const Color(0x70000000),
    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
    builder: (sheetContext) => _FavRuleConditionSheet(
      initial: initial,
      onDelete: onDelete,
      debugQueryOverride: debugQueryOverride,
      debugCountOverride: debugCountOverride,
    ),
  );
}

class _FavRuleConditionSheet extends StatefulWidget {
  const _FavRuleConditionSheet({
    this.initial,
    this.onDelete,
    this.debugQueryOverride,
    this.debugCountOverride,
  });

  final FavRuleCondition? initial;
  final VoidCallback? onDelete;
  final FavRuleTagPreviewQuery? debugQueryOverride;
  final Future<int> Function()? debugCountOverride;

  @override
  State<_FavRuleConditionSheet> createState() => _FavRuleConditionSheetState();
}

class _FavRuleConditionSheetState extends State<_FavRuleConditionSheet> {
  late _ConditionMode _mode = (widget.initial?.isCategory ?? false)
      ? _ConditionMode.category
      : _ConditionMode.tag;

  late final List<String> _selectedCategories = List<String>.of(
    widget.initial?.categoryValues ?? const <String>[],
  );
  late bool _negated = widget.initial?.negated ?? false;

  late String? _namespace = (widget.initial?.isCategory ?? false)
      ? null
      : widget.initial?.namespace;
  late FavRuleOp _op = (widget.initial?.isCategory ?? false)
      ? FavRuleOp.equals
      : (widget.initial?.op ?? FavRuleOp.equals);
  late bool _matchTranslation = (widget.initial?.isCategory ?? false)
      ? false
      : (widget.initial?.matchTranslation ?? false);
  late final TextEditingController _valueController = TextEditingController(
    text: (widget.initial?.isCategory ?? false)
        ? ''
        : (widget.initial?.value ?? ''),
  );
  bool _showMoreNamespaces = false;

  Timer? _debounce;
  int _searchSeq = 0;
  bool _searching = false;
  bool _dbChecked = false;
  bool _hasTagDb = true;
  List<TagTranslat> _matches = const <TagTranslat>[];
  int _totalMatchCount = 0;

  @override
  void initState() {
    super.initState();
    if (_namespace != null && kFavRuleExtraNamespaces.contains(_namespace)) {
      _showMoreNamespaces = true;
    }
    _valueController.addListener(_onInputChanged);
    _checkTagDbAndSearch();
  }

  Future<void> _checkTagDbAndSearch() async {
    try {
      final count = widget.debugCountOverride != null
          ? await widget.debugCountOverride!()
          : await isarHelper.countTagTranslates();
      if (!mounted) {
        return;
      }
      setState(() {
        _dbChecked = true;
        _hasTagDb = count > 0;
      });
      if (_hasTagDb && _valueController.text.trim().isNotEmpty) {
        await _runSearch();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _dbChecked = true;
        _hasTagDb = false;
      });
    }
  }

  void _onInputChanged() {
    setState(() {});
    _scheduleSearch();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    // Immediately bump generation so any earlier in-flight query is discarded.
    final seq = ++_searchSeq;
    if (!_hasTagDb || _valueController.text.trim().isEmpty) {
      setState(() {
        _searching = false;
        _matches = const <TagTranslat>[];
        _totalMatchCount = 0;
      });
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 180),
      () => _runSearch(seq: seq),
    );
  }

  Future<void> _runSearch({int? seq}) async {
    final requestSeq = seq ?? ++_searchSeq;
    final text = _valueController.text.trim();
    if (text.isEmpty || !_hasTagDb) {
      return;
    }
    final candidate = _tagCondition;
    if (!candidate.isValidRegex) {
      if (mounted && requestSeq == _searchSeq) {
        setState(() {
          _searching = false;
          _matches = const <TagTranslat>[];
          _totalMatchCount = 0;
        });
      }
      return;
    }
    setState(() => _searching = true);
    try {
      final queryFn = widget.debugQueryOverride ??
          isarHelper.findTagTranslatesForRuleCondition;
      final (items, total) = await queryFn(
        value: text,
        namespace: candidate.namespace,
        opName: candidate.op.name,
        matchTranslation: candidate.matchTranslation,
        limit: 40,
      );
      if (!mounted ||
          requestSeq != _searchSeq ||
          _tagCondition != candidate) {
        return;
      }
      setState(() {
        _searching = false;
        _matches = items;
        _totalMatchCount = total;
      });
    } catch (_) {
      if (!mounted ||
          requestSeq != _searchSeq ||
          _tagCondition != candidate) {
        return;
      }
      setState(() {
        _searching = false;
        _matches = const <TagTranslat>[];
        _totalMatchCount = 0;
      });
    }
  }

  FavRuleCondition get _tagCondition => FavRuleCondition(
        namespace: _namespace,
        op: _op,
        value: _valueController.text.trim(),
        matchTranslation: _matchTranslation,
      );

  FavRuleCondition get _currentCondition => _mode == _ConditionMode.category
      ? FavRuleCondition.category(_selectedCategories, negated: _negated)
      : _tagCondition;

  bool _isCategorySelected(String canonical) {
    final target = canonical.toLowerCase();
    return _selectedCategories.any((c) => c.toLowerCase() == target);
  }

  void _toggleCategory(String canonical) {
    unawaited(vibrateUtil.selection());
    final target = canonical.toLowerCase();
    setState(() {
      final idx = _selectedCategories.indexWhere(
        (c) => c.toLowerCase() == target,
      );
      if (idx >= 0) {
        _selectedCategories.removeAt(idx);
      } else {
        _selectedCategories.add(canonical);
      }
    });
  }

  void _removeCategory(String canonical) {
    unawaited(vibrateUtil.selection());
    final target = canonical.toLowerCase();
    setState(() {
      _selectedCategories.removeWhere((c) => c.toLowerCase() == target);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _valueController.removeListener(_onInputChanged);
    _valueController.dispose();
    super.dispose();
  }

  void _confirm() {
    final condition = _currentCondition;
    if (!condition.hasValidValue) {
      return;
    }
    unawaited(vibrateUtil.selection());
    Navigator.of(context).pop(condition);
  }

  void _handleDelete() {
    final onDelete = widget.onDelete;
    if (onDelete == null) {
      return;
    }
    unawaited(vibrateUtil.selection());
    Navigator.of(context).pop();
    onDelete();
  }

  Future<void> _openCategoryOperatorMenu(BuildContext anchorContext) async {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final chosen = await showFavRulePullDownMenu<bool>(
      anchorContext: anchorContext,
      selectedValue: _negated,
      width: 236,
      items: <FavRulePullDownItem<bool>>[
        FavRulePullDownItem<bool>(
          value: false,
          title: zh ? '是' : 'is',
          subtitle: zh ? '属于所选分类时匹配' : 'Match selected categories',
        ),
        FavRulePullDownItem<bool>(
          value: true,
          title: zh ? '不是' : 'is not',
          subtitle: zh ? '排除所选分类' : 'Exclude selected categories',
          destructive: true,
        ),
      ],
    );
    if (chosen != null && mounted && chosen != _negated) {
      setState(() => _negated = chosen);
    }
  }

  Future<void> _openTagOperatorMenu(BuildContext anchorContext) async {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final chosen = await showFavRulePullDownMenu<FavRuleOp>(
      anchorContext: anchorContext,
      selectedValue: _op,
      width: 236,
      items: <FavRulePullDownItem<FavRuleOp>>[
        FavRulePullDownItem<FavRuleOp>(
          value: FavRuleOp.equals,
          title: favRuleOpShortLabel(FavRuleOp.equals, zh: zh),
          subtitle: zh ? '与标签完全一致' : 'Exact tag match',
        ),
        FavRulePullDownItem<FavRuleOp>(
          value: FavRuleOp.contains,
          title: favRuleOpShortLabel(FavRuleOp.contains, zh: zh),
          subtitle: zh ? '标签中包含该词' : 'Substring match',
        ),
        FavRulePullDownItem<FavRuleOp>(
          value: FavRuleOp.regex,
          title: favRuleOpShortLabel(FavRuleOp.regex, zh: zh),
          subtitle: zh ? '使用正则表达式匹配' : 'Regular expression match',
        ),
      ],
    );
    if (chosen != null && mounted && chosen != _op) {
      setState(() => _op = chosen);
      _scheduleSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final accent = EhPalette.accent.resolveFrom(context);
    final onAccent = EhPalette.onAccent.resolveFrom(context);
    final fill = palette.fill.resolveFrom(context);
    final text1 = palette.text1.resolveFrom(context);
    final text3 = palette.text3.resolveFrom(context);
    final hairline = palette.hairline.resolveFrom(context);

    final cond = _currentCondition;
    final canSave = cond.hasValidValue;
    final showDeleteRow = widget.initial != null && widget.onDelete != null;

    return buildSafeFloatingSheet(
      context: context,
      maxWidth: 500,
      heightFactor: 0.88,
      child: DefaultTextStyle(
        style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              color: text1,
              decoration: TextDecoration.none,
            ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: text3.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
            child: Row(
              children: <Widget>[
                _CircleHeaderButton(
                  key: kFavRuleConditionSheetCloseKey,
                  background: fill,
                  icon: CupertinoIcons.xmark,
                  iconColor: text1,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    widget.initial == null
                        ? l10n.fav_rule_add_condition
                        : l10n.fav_rule_edit_condition,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: text1,
                    ),
                  ),
                ),
                _CircleHeaderButton(
                  key: kFavRuleConditionSheetSaveKey,
                  background: canSave ? accent : fill,
                  icon: CupertinoIcons.checkmark_alt,
                  iconColor: canSave ? onAccent : text3,
                  onPressed: canSave ? _confirm : null,
                ),
              ],
            ),
          ),
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 20),
              child: AnimatedSize(
                duration: disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Top Segmented Mode Switch (`标签` | `画廊分类`)
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoSlidingSegmentedControl<_ConditionMode>(
                        groupValue: _mode,
                        children: <_ConditionMode, Widget>{
                          _ConditionMode.tag: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Text(
                              l10n.fav_rule_mode_tag,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _mode == _ConditionMode.tag
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          _ConditionMode.category: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Text(
                              l10n.fav_rule_mode_category,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _mode == _ConditionMode.category
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        },
                        onValueChanged: (next) {
                          if (next == null || next == _mode) {
                            return;
                          }
                          unawaited(vibrateUtil.selection());
                          FocusScope.of(context).unfocus();
                          setState(() => _mode = next);
                          if (next == _ConditionMode.tag &&
                              _hasTagDb &&
                              _valueController.text.trim().isNotEmpty) {
                            _scheduleSearch();
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Unboxed Live Condition Sentence ("句子优先、色卡说话")
                    if (_mode == _ConditionMode.category)
                      _buildCategorySentence(context, zh: zh, dark: dark)
                    else
                      _buildTagSentence(context, zh: zh),

                    // Bottom 0.5px hairline divider separating sentence from controls
                    Padding(
                      padding: const EdgeInsets.only(top: 14, bottom: 16),
                      child: Container(height: 0.5, color: hairline),
                    ),

                    // Mode-specific controls
                    if (_mode == _ConditionMode.category)
                      _buildCategoryControls(context, dark: dark)
                    else
                      _buildTagControls(context, zh: zh, dark: dark),

                    // Optional bottom destructive delete button when editing
                    if (showDeleteRow) ...<Widget>[
                      const SizedBox(height: 16),
                      GestureDetector(
                        key: kFavRuleConditionSheetDeleteKey,
                        behavior: HitTestBehavior.opaque,
                        onTap: _handleDelete,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: dark
                                ? fill
                                : palette.surface.resolveFrom(context),
                            borderRadius: BorderRadius.circular(14),
                            border: dark
                                ? null
                                : Border.all(color: hairline, width: 0.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            l10n.fav_rule_delete_condition,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w500,
                              color: CupertinoColors.systemRed
                                  .resolveFrom(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildCategorySentence(
    BuildContext context, {
    required bool zh,
    required bool dark,
  }) {
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final accentSoft = EhPalette.accentSoft.resolveFrom(context);
    final text2 = palette.text2.resolveFrom(context);
    final text3 = palette.text3.resolveFrom(context);
    final hairline = palette.hairline.resolveFrom(context);
    final sysRed = CupertinoColors.systemRed.resolveFrom(context);

    final count = _selectedCategories.length;
    final String opLabel;
    if (_negated) {
      opLabel = zh ? '不是 ▾' : 'is not ▾';
    } else if (count >= 2) {
      opLabel = zh ? '是其中之一 ▾' : 'is one of ▾';
    } else {
      opLabel = zh ? '是 ▾' : 'is ▾';
    }

    final Color opBg = _negated
        ? sysRed.withValues(alpha: dark ? 0.22 : 0.12)
        : accentSoft;
    final Color opFg = _negated ? sysRed : accent;

    final String hintText;
    if (count == 0) {
      hintText = zh ? '至少选择一个分类' : 'Select at least one category';
    } else if (_negated) {
      hintText = zh
          ? '属于所选分类的画廊不会匹配这条规则'
          : 'Galleries in selected categories will not match this rule';
    } else if (count == 1) {
      hintText = zh ? '属于该分类就算匹配' : 'Matches galleries in this category';
    } else {
      hintText =
          zh ? '属于任一所选分类就算匹配' : 'Matches galleries in any selected category';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              zh ? '画廊分类' : 'Category',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: text2,
              ),
            ),
            Builder(
              builder: (pillContext) => GestureDetector(
                key: kFavRuleConditionSheetOperatorKey,
                behavior: HitTestBehavior.opaque,
                onTap: () => _openCategoryOperatorMenu(pillContext),
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: opBg,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        opLabel,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: opFg,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (count == 0)
          _DashedOutlinePill(
            height: 34,
            text: zh ? '在下方选择分类' : 'Select categories below',
            textColor: text3,
            borderColor: hairline,
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final cat in _selectedCategories)
                _AnimatedCategoryBadge(
                  key: ValueKey<String>('cat_tok_$cat'),
                  child: FavCategoryBadge(
                    category: cat,
                    height: 34,
                    borderRadius: 10,
                    fontSize: 15,
                    negated: _negated,
                    onRemove: () => _removeCategory(cat),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 10),
        Text(
          hintText,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: text2,
          ),
        ),
      ],
    );
  }

  Widget _buildTagSentence(BuildContext context, {required bool zh}) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final accentSoft = EhPalette.accentSoft.resolveFrom(context);
    final fillPressed = palette.fillPressed.resolveFrom(context);
    final text1 = palette.text1.resolveFrom(context);
    final text2 = palette.text2.resolveFrom(context);
    final text3 = palette.text3.resolveFrom(context);
    final hairline = palette.hairline.resolveFrom(context);
    final sysRed = CupertinoColors.systemRed.resolveFrom(context);

    final query = _valueController.text.trim();
    final tagCond = _tagCondition;
    final regexError =
        _op == FavRuleOp.regex && query.isNotEmpty && !tagCond.isValidRegex;

    final String line2Text;
    final Color line2Color;
    if (regexError) {
      line2Text = l10n.fav_rule_invalid_regex;
      line2Color = sysRed;
    } else if (query.isEmpty) {
      line2Text = zh ? '在下方输入标签或关键词' : 'Enter a tag or keyword below';
      line2Color = text2;
    } else if (_dbChecked && !_hasTagDb) {
      line2Text = zh ? '保存后按此条件匹配画廊标签' : 'Matches gallery tags once saved';
      line2Color = text2;
    } else if (_searching) {
      line2Text = zh ? '正在查询标签库…' : 'Searching tag database…';
      line2Color = text2;
    } else if (_op == FavRuleOp.equals) {
      line2Text = zh
          ? '标签库里有 $_totalMatchCount 个标签与此一致'
          : '$_totalMatchCount exact match(es) in tag database';
      line2Color = text2;
    } else {
      line2Text = zh
          ? '标签库里有 $_totalMatchCount 个匹配的标签'
          : '$_totalMatchCount matching tag(s) in tag database';
      line2Color = text2;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            // Namespace pill
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: fillPressed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    favRuleNamespaceLabel(_namespace, zh: zh),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: text1,
                    ),
                  ),
                ],
              ),
            ),
            // Tappable operator pill -> pull-down menu
            Builder(
              builder: (pillContext) => GestureDetector(
                key: kFavRuleConditionSheetOperatorKey,
                behavior: HitTestBehavior.opaque,
                onTap: () => _openTagOperatorMenu(pillContext),
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: accentSoft,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '${favRuleOpShortLabel(_op, zh: zh)} ▾',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Value pill (accentSoft pill with value or outline placeholder `输入标签`)
            if (query.isEmpty)
              _DashedOutlinePill(
                height: 32,
                text: zh ? '输入标签' : 'Enter tag',
                textColor: text3,
                borderColor: hairline,
              )
            else
              Container(
                height: 32,
                constraints: const BoxConstraints(maxWidth: 260),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        query,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          line2Text,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: line2Color,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryControls(
    BuildContext context, {
    required bool dark,
  }) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final text2 = palette.text2.resolveFrom(context);
    const metas = kFavRuleCategoryMetas;
    final rowCount = (metas.length + 1) ~/ 2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.fav_rule_select_category,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: text2,
                ),
              ),
            ),
            if (_selectedCategories.isNotEmpty)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  unawaited(vibrateUtil.selection());
                  setState(_selectedCategories.clear);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Text(
                    l10n.fav_rule_clear_selection,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: accent,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        for (var row = 0; row < rowCount; row++) ...<Widget>[
          if (row > 0) const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: _CategoryGridTile(
                  key: ValueKey<String>(
                    'fav_rule_cat_tile_${metas[row * 2].canonical}',
                  ),
                  meta: metas[row * 2],
                  selected: _isCategorySelected(metas[row * 2].canonical),
                  negated: _negated,
                  dark: dark,
                  onTap: () => _toggleCategory(metas[row * 2].canonical),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: (row * 2 + 1 < metas.length)
                    ? _CategoryGridTile(
                        key: ValueKey<String>(
                          'fav_rule_cat_tile_${metas[row * 2 + 1].canonical}',
                        ),
                        meta: metas[row * 2 + 1],
                        selected: _isCategorySelected(
                          metas[row * 2 + 1].canonical,
                        ),
                        negated: _negated,
                        dark: dark,
                        onTap: () => _toggleCategory(
                          metas[row * 2 + 1].canonical,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTagControls(
    BuildContext context, {
    required bool zh,
    required bool dark,
  }) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final fill = palette.fill.resolveFrom(context);
    final field = palette.field.resolveFrom(context);
    final text1 = palette.text1.resolveFrom(context);
    final text3 = palette.text3.resolveFrom(context);
    final hairline = palette.hairline.resolveFrom(context);
    final insetBg = dark ? fill : palette.surface.resolveFrom(context);

    final tagCond = _tagCondition;
    final regexError = _op == FavRuleOp.regex &&
        _valueController.text.trim().isNotEmpty &&
        !tagCond.isValidRegex;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildNamespacePills(context, zh: zh, dark: dark),
        const SizedBox(height: 16),

        // 46pt search CupertinoTextField
        SizedBox(
          height: 46,
          child: CupertinoTextField(
            controller: _valueController,
            autofocus: widget.initial == null,
            placeholder: _op == FavRuleOp.regex
                ? l10n.fav_rule_regex_placeholder
                : l10n.fav_rule_value_placeholder,
            placeholderStyle: TextStyle(fontSize: 15.5, color: text3),
            style: TextStyle(fontSize: 16, color: text1),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            prefix: Padding(
              padding: const EdgeInsets.only(left: 14),
              child: EhSvgIcon(
                CupertinoIcons.search,
                size: 16,
                color: text3,
              ),
            ),
            clearButtonMode: OverlayVisibilityMode.editing,
            decoration: BoxDecoration(
              color: dark ? field : fill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: regexError
                    ? CupertinoColors.systemRed.resolveFrom(context)
                    : (dark ? const Color(0x00000000) : hairline),
                width: regexError ? 1.2 : 0.5,
              ),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _confirm(),
          ),
        ),
        const SizedBox(height: 10),

        // Grouped row for `同时匹配中文翻译` (`CupertinoSwitch`)
        Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: insetBg,
            borderRadius: BorderRadius.circular(16),
            border: dark ? null : Border.all(color: hairline, width: 0.5),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.fav_rule_match_translation_hint,
                  style: TextStyle(
                    fontSize: 15,
                    color: text1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CupertinoSwitch(
                value: _matchTranslation,
                onChanged: (val) {
                  setState(() => _matchTranslation = val);
                  _scheduleSearch();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Known tags preview
        _buildKnownTagsSection(context, zh: zh),
      ],
    );
  }

  Widget _buildNamespacePills(
    BuildContext context, {
    required bool zh,
    required bool dark,
  }) {
    final l10n = L10n.of(context);
    final items = <String?>[
      null,
      ...kFavRulePrimaryNamespaces.where(
        (ns) => ns != kFavRuleCategoryNamespace,
      ),
      if (_showMoreNamespaces)
        ...kFavRuleExtraNamespaces.where(
          (ns) => ns != kFavRuleCategoryNamespace,
        ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final ns in items)
          _NamespacePill(
            key: ValueKey<String>('fav_rule_ns_chip_${ns ?? "any"}'),
            label: ns == null
                ? l10n.fav_rule_namespace_any
                : favRuleNamespaceLabel(ns, zh: zh),
            selected: _namespace == ns,
            dark: dark,
            onTap: () {
              unawaited(vibrateUtil.selection());
              setState(() => _namespace = ns);
              _scheduleSearch();
            },
          ),
        if (!_showMoreNamespaces)
          _NamespacePill(
            key: const ValueKey<String>('fav_rule_ns_chip_more'),
            label: '${l10n.fav_rule_namespace_more} ▾',
            selected: false,
            dark: dark,
            onTap: () {
              unawaited(vibrateUtil.selection());
              setState(() => _showMoreNamespaces = true);
            },
          ),
      ],
    );
  }

  Widget _buildKnownTagsSection(BuildContext context, {required bool zh}) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final text1 = palette.text1.resolveFrom(context);
    final text2 = palette.text2.resolveFrom(context);
    final text3 = palette.text3.resolveFrom(context);
    final accent = EhPalette.accent.resolveFrom(context);
    final insetBg = dark
        ? palette.fill.resolveFrom(context)
        : palette.surface.resolveFrom(context);
    final hairline = palette.hairline.resolveFrom(context);

    final query = _valueController.text.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.fav_rule_matched_known_tags,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: text2,
                ),
              ),
            ),
            if (_searching)
              const CupertinoActivityIndicator(radius: 7)
            else if (_totalMatchCount > 0)
              Text(
                l10n.fav_rule_total_count(_totalMatchCount),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: accent,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_dbChecked && !_hasTagDb)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: insetBg,
              borderRadius: BorderRadius.circular(16),
              border: dark ? null : Border.all(color: hairline, width: 0.5),
            ),
            child: Text(
              l10n.fav_rule_no_tag_db_hint,
              style: TextStyle(fontSize: 13, color: text2),
            ),
          )
        else if (query.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: insetBg,
              borderRadius: BorderRadius.circular(16),
              border: dark ? null : Border.all(color: hairline, width: 0.5),
            ),
            child: Text(
              l10n.fav_rule_type_to_preview_tags,
              style: TextStyle(fontSize: 13, color: text3),
            ),
          )
        else if (_matches.isEmpty && !_searching)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: insetBg,
              borderRadius: BorderRadius.circular(16),
              border: dark ? null : Border.all(color: hairline, width: 0.5),
            ),
            child: Text(
              l10n.fav_rule_no_known_tag_matches,
              style: TextStyle(fontSize: 13, color: text2),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: insetBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: hairline, width: 0.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var i = 0; i < _matches.length; i++) ...<Widget>[
                  if (i > 0) Container(height: 0.5, color: hairline),
                  _KnownTagRow(
                    tag: _matches[i],
                    query: query,
                    op: _op,
                    accentColor: accent,
                    text1: text1,
                    text2: text2,
                    onTap: () {
                      unawaited(vibrateUtil.selection());
                      setState(() {
                        _valueController.text = _matches[i].key;
                        _valueController.selection = TextSelection.collapsed(
                          offset: _matches[i].key.length,
                        );
                        if (_namespace == null &&
                            kFavRuleAllNamespaces
                                .contains(_matches[i].namespace)) {
                          _namespace = _matches[i].namespace;
                          if (kFavRuleExtraNamespaces.contains(_namespace)) {
                            _showMoreNamespaces = true;
                          }
                        }
                      });
                      _scheduleSearch();
                    },
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _CircleHeaderButton extends StatelessWidget {
  const _CircleHeaderButton({
    super.key,
    required this.background,
    required this.icon,
    required this.iconColor,
    required this.onPressed,
  });

  final Color background;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: EhSvgIcon(icon, size: 17, color: iconColor),
          ),
        ),
      ),
    );
  }
}

class _AnimatedCategoryBadge extends StatelessWidget {
  const _AnimatedCategoryBadge({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 180),
      builder: (context, t, body) {
        final scale = 0.86 + 0.14 * Curves.easeOutBack.transform(t);
        final opacity = Curves.easeOut.transform(t).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: body,
          ),
        );
      },
      child: child,
    );
  }
}

class _CategoryGridTile extends StatelessWidget {
  const _CategoryGridTile({
    super.key,
    required this.meta,
    required this.selected,
    required this.negated,
    required this.dark,
    required this.onTap,
  });

  final FavRuleCategoryMeta meta;
  final bool selected;
  final bool negated;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final tileBg = palette.fill.resolveFrom(context);
    final text1 = palette.text1.resolveFrom(context);
    final text2 = palette.text2.resolveFrom(context);
    final catColor = favRuleCategoryColor(context, meta.canonical);
    final onCatColor = favRuleOnCategoryColor(catColor);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    final Color bgColor;
    final Color borderColor;
    if (!selected) {
      bgColor = tileBg;
      borderColor = const Color(0x00000000);
    } else if (negated) {
      bgColor = tileBg;
      borderColor = catColor;
    } else {
      bgColor = Color.alphaBlend(
        catColor.withValues(alpha: dark ? 0.20 : 0.11),
        tileBg,
      );
      borderColor = catColor;
    }

    final Widget swatchGlyph = !selected
        ? const SizedBox.shrink(key: ValueKey<String>('none'))
        : EhSvgIcon(
            negated ? CupertinoIcons.minus : CupertinoIcons.checkmark_alt,
            key: ValueKey<String>(negated ? 'minus' : 'check'),
            size: 15,
            color: onCatColor,
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: <Widget>[
            FavCategorySwatchSquare(
              category: meta.canonical,
              size: 28,
              borderRadius: 9,
              child: disableAnimations
                  ? swatchGlyph
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      transitionBuilder: (child, anim) {
                        final scaleAnim = Tween<double>(
                          begin: 0.6,
                          end: 1.0,
                        ).animate(
                          CurvedAnimation(
                            parent: anim,
                            curve: Curves.easeOutBack,
                          ),
                        );
                        return FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(
                            scale: scaleAnim,
                            child: child,
                          ),
                        );
                      },
                      child: swatchGlyph,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    meta.zhLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                      color: text1,
                      decoration: (selected && negated)
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: catColor,
                      decorationThickness: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta.gridSubLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.15,
                      color: text2,
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

class _NamespacePill extends StatelessWidget {
  const _NamespacePill({
    super.key,
    required this.label,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final fill = palette.fill.resolveFrom(context);
    final hairline = palette.hairline.resolveFrom(context);
    final text1 = palette.text1.resolveFrom(context);
    final canvas = palette.canvas.resolveFrom(context);

    final bgColor = selected ? text1 : fill;
    final fgColor = selected
        ? (dark ? canvas : const Color(0xFFFFFFFF))
        : text1;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(17),
          border: (!selected && !dark)
              ? Border.all(color: hairline, width: 0.5)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: fgColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedOutlinePill extends StatelessWidget {
  const _DashedOutlinePill({
    required this.height,
    required this.text,
    required this.textColor,
    required this.borderColor,
  });

  final double height;
  final String text;
  final Color textColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(
        color: borderColor,
        radius: 10,
      ),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  static const double _strokeWidth = 1.25;
  static const double _dashLength = 4.5;
  static const double _gapLength = 3.5;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(_strokeWidth / 2),
      Radius.circular(radius),
    );
    final sourcePath = Path()..addRRect(rrect);
    final dashedPath = Path();
    for (final metric in sourcePath.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + _dashLength).clamp(0.0, metric.length);
        dashedPath.addPath(metric.extractPath(distance, end), Offset.zero);
        distance += _dashLength + _gapLength;
      }
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(_DashedRRectPainter oldDelegate) =>
      color != oldDelegate.color || radius != oldDelegate.radius;
}

class _KnownTagRow extends StatelessWidget {
  const _KnownTagRow({
    required this.tag,
    required this.query,
    required this.op,
    required this.accentColor,
    required this.text1,
    required this.text2,
    required this.onTap,
  });

  final TagTranslat tag;
  final String query;
  final FavRuleOp op;
  final Color accentColor;
  final Color text1;
  final Color text2;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cleanTrans = (tag.name ?? '')
        .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '')
        .trim();
    final subLine =
        cleanTrans.isNotEmpty ? '${tag.namespace} · $cleanTrans' : tag.namespace;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _HighlightedText(
              text: tag.key,
              query: query,
              op: op,
              baseStyle: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: text1,
              ),
              highlightColor: accentColor,
            ),
            const SizedBox(height: 2),
            _HighlightedText(
              text: subLine,
              query: query,
              op: op,
              baseStyle: TextStyle(fontSize: 12, color: text2),
              highlightColor: accentColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.query,
    required this.op,
    required this.baseStyle,
    required this.highlightColor,
  });

  final String text;
  final String query;
  final FavRuleOp op;
  final TextStyle baseStyle;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    RegExp? pattern;
    try {
      if (op == FavRuleOp.regex) {
        pattern = RegExp(query, caseSensitive: false);
      } else {
        pattern = RegExp(RegExp.escape(query), caseSensitive: false);
      }
    } catch (_) {
      return Text(
        text,
        style: baseStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final matches = pattern.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final spans = <TextSpan>[];
    var cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start)));
      }
      if (m.end > m.start) {
        spans.add(
          TextSpan(
            text: text.substring(m.start, m.end),
            style: TextStyle(
              color: highlightColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
