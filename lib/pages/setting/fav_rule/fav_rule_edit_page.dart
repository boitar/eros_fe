import 'dart:async';
import 'dart:math' as math;

import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/common/service/fav_rule_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/fav_rule.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/pages/setting/fav_rule/fav_rule_condition_sheet.dart';
import 'package:eros_fe/utils/toast.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:eros_fe/widget/fav_rule_safe_area.dart';
import 'package:eros_fe/widget/fav_rule_widgets.dart';
import 'package:eros_fe/widget/image/eh_network_image.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';

/// Arguments passed when opening [FavRuleEditPage].
class FavRuleEditArgs {
  const FavRuleEditArgs({
    this.existingRule,
    this.initialConditions = const <FavRuleCondition>[],
    this.initialName,
    this.initialFavcat,
  });

  final FavRule? existingRule;
  final List<FavRuleCondition> initialConditions;
  final String? initialName;
  final String? initialFavcat;
}

class FavRuleEditPage extends StatefulWidget {
  const FavRuleEditPage({super.key, this.args});

  final FavRuleEditArgs? args;

  @override
  State<FavRuleEditPage> createState() => _FavRuleEditPageState();
}

class _FavRuleEditPageState extends State<FavRuleEditPage> {
  final FavRuleService _service = Get.find<FavRuleService>();

  FavRule? _editingRule;
  late final TextEditingController _nameController;
  late final FocusNode _nameFocusNode;
  FavRuleMatch _match = FavRuleMatch.any;
  List<FavRuleCondition> _conditions = <FavRuleCondition>[];
  String _favcat = '';
  bool _routeArgsResolved = false;

  void _applyArgs(FavRuleEditArgs? resolved) {
    _editingRule = resolved?.existingRule;
    _nameController.text = _editingRule?.name ?? resolved?.initialName ?? '';
    _match = _editingRule?.match ?? FavRuleMatch.any;
    _conditions = List<FavRuleCondition>.of(
      _editingRule?.conditions ??
          resolved?.initialConditions ??
          const <FavRuleCondition>[],
    );
    _favcat = _editingRule?.favcat ?? resolved?.initialFavcat ?? '';
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _nameFocusNode = FocusNode();
    if (widget.args != null) {
      _applyArgs(widget.args);
      _routeArgsResolved = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeArgsResolved) {
      return;
    }
    _routeArgsResolved = true;
    final modalRoute = ModalRoute.of(context);
    final routeArgs = modalRoute?.settings.arguments;
    if (routeArgs is FavRuleEditArgs) {
      _applyArgs(routeArgs);
      return;
    }
    if ((modalRoute == null || routeArgs == null) &&
        Get.arguments is FavRuleEditArgs) {
      _applyArgs(Get.arguments as FavRuleEditArgs);
      return;
    }
    _applyArgs(null);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _conditions.isNotEmpty &&
      _conditions.every((c) => c.hasValidValue) &&
      _favcat.isNotEmpty;

  FavRule _buildDraftRule() {
    return FavRule(
      id: _editingRule?.id ?? '',
      name: _nameController.text.trim(),
      enabled: _editingRule?.enabled ?? true,
      match: _match,
      conditions: List<FavRuleCondition>.unmodifiable(_conditions),
      favcat: _favcat,
      hitCount: _editingRule?.hitCount ?? 0,
      lastHitAt: _editingRule?.lastHitAt,
    );
  }

  Future<void> _save() async {
    final l10n = L10n.of(context);
    if (_conditions.isEmpty) {
      showToast(l10n.fav_rule_need_condition);
      await vibrateUtil.error();
      return;
    }
    if (_conditions.any((c) => !c.hasValidValue)) {
      showToast(l10n.fav_rule_invalid_condition);
      await vibrateUtil.error();
      return;
    }
    if (_favcat.isEmpty) {
      showToast(l10n.fav_rule_pick_one_folder_hint);
      await vibrateUtil.error();
      return;
    }

    final draft = _buildDraftRule();
    if (_editingRule == null) {
      await _service.addRule(draft);
    } else {
      await _service.updateRule(draft);
    }
    await vibrateUtil.success();
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _confirmDelete() async {
    final editing = _editingRule;
    if (editing == null) {
      return;
    }
    final l10n = L10n.of(context);
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => EhAlertDialog(
        title: Text(l10n.fav_rule_delete_title),
        content: Text(l10n.fav_rule_delete_confirm),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteRule(editing.id);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  Future<void> _addCondition() async {
    final added = await showFavRuleConditionSheet(context);
    if (added != null && mounted) {
      setState(() => _conditions.add(added));
    }
  }

  Future<void> _editCondition(int index) async {
    if (index < 0 || index >= _conditions.length) {
      return;
    }
    var deleted = false;
    final updated = await showFavRuleConditionSheet(
      context,
      initial: _conditions[index],
      onDelete: () {
        deleted = true;
        _removeCondition(index);
      },
    );
    if (!deleted &&
        updated != null &&
        mounted &&
        index >= 0 &&
        index < _conditions.length) {
      setState(() => _conditions[index] = updated);
    }
  }

  void _removeCondition(int index) {
    if (!mounted || index < 0 || index >= _conditions.length) {
      return;
    }
    setState(() => _conditions.removeAt(index));
  }

  Future<void> _openMatchModeMenu(
    BuildContext anchorContext, {
    required bool zh,
  }) async {
    final selected = await showFavRulePullDownMenu<FavRuleMatch>(
      anchorContext: anchorContext,
      selectedValue: _match,
      width: 240,
      items: <FavRulePullDownItem<FavRuleMatch>>[
        FavRulePullDownItem<FavRuleMatch>(
          value: FavRuleMatch.all,
          title: zh ? '全部' : 'All',
          subtitle: zh ? '每个条件都要满足' : 'Every condition must match',
        ),
        FavRulePullDownItem<FavRuleMatch>(
          value: FavRuleMatch.any,
          title: zh ? '任一' : 'Any',
          subtitle: zh ? '满足其中一个就算' : 'Any single condition matches',
        ),
      ],
    );
    if (selected != null && mounted && selected != _match) {
      setState(() => _match = selected);
    }
  }

  void _showHistoryMatchesSheet(List<GalleryProvider> matches) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final text1 = palette.text1.resolveFrom(context);
    final text2 = palette.text2.resolveFrom(context);
    final text3 = palette.text3.resolveFrom(context);
    final hairline = palette.hairline.resolveFrom(context);

    showCupertinoModalPopup<void>(
      context: context,
      barrierColor: const Color(0x70000000),
      builder: (sheetContext) {
        return buildSafeFloatingSheet(
          context: sheetContext,
          maxWidth: 500,
          heightFactor: 0.72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: text3.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 14, 10),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l10n.fav_rule_history_hits_matched(matches.length),
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w600,
                          color: text1,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(32, 32),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: EhSvgIcon(
                        CupertinoIcons.xmark_circle_fill,
                        size: 23,
                        color: text3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 0.5, color: hairline),
              if (matches.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    l10n.fav_rule_history_empty_save_ok,
                    style: TextStyle(fontSize: 14, color: text2),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: matches.length,
                    separatorBuilder: (_, _) => Container(
                      height: 0.5,
                      margin: const EdgeInsets.only(left: 72),
                      color: hairline,
                    ),
                    itemBuilder: (ctx, idx) {
                      final g = matches[idx];
                      final title = (g.japaneseTitle?.isNotEmpty ?? false)
                          ? g.japaneseTitle!
                          : (g.englishTitle ?? '');
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: <Widget>[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 44,
                                height: 60,
                                child: (g.imgUrl?.isNotEmpty ?? false)
                                    ? EhNetworkImage(
                                        imageUrl: g.imgUrl!,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        color: palette.fill.resolveFrom(ctx),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: text1,
                                    ),
                                  ),
                                  if (g.category?.isNotEmpty ?? false) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      g.category!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: text2,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatLastHit(BuildContext context, int? epochMs) {
    if (epochMs == null) {
      return '';
    }
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(epochMs),
    );
    if (diff.inMinutes < 1) {
      return zh ? '刚刚' : 'just now';
    }
    if (diff.inHours < 1) {
      return zh ? '${diff.inMinutes} 分钟前' : '${diff.inMinutes}m ago';
    }
    if (diff.inDays < 1) {
      return zh ? '${diff.inHours} 小时前' : '${diff.inHours}h ago';
    }
    return zh ? '${diff.inDays} 天前' : '${diff.inDays}d ago';
  }

  Widget _buildSubtitleRow(
    BuildContext context, {
    required L10n l10n,
    required Color text2,
  }) {
    final editingRule = _editingRule;
    if (editingRule == null) {
      return Text(
        l10n.fav_rule_new_subtitle,
        style: TextStyle(fontSize: 13.5, color: text2),
      );
    }
    if (editingRule.hitCount <= 0) {
      return Text(
        l10n.fav_rule_no_hits_yet,
        style: TextStyle(fontSize: 13.5, color: text2),
      );
    }
    final statsText = editingRule.lastHitAt != null
        ? l10n.fav_rule_hit_stats_with_time(
            editingRule.hitCount,
            _formatLastHit(context, editingRule.lastHitAt),
          )
        : l10n.fav_rule_hit_stats(editingRule.hitCount);
    return Row(
      children: <Widget>[
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: Color(0xFF4FB98A),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            statsText,
            style: TextStyle(fontSize: 13.5, color: text2),
          ),
        ),
      ],
    );
  }

  Widget _buildConditionLeadHeader({
    required bool zh,
    required Color text2,
    required Color accent,
    required Color accentSoft,
  }) {
    if (_conditions.length <= 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 30),
          alignment: Alignment.centerLeft,
          child: Text(
            zh ? '满足这个条件时' : 'When this condition matches',
            style: TextStyle(fontSize: 15, color: text2),
          ),
        ),
      );
    }

    final pillText = _match == FavRuleMatch.all
        ? (zh ? '全部 ▾' : 'All ▾')
        : (zh ? '任一 ▾' : 'Any ▾');

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 30),
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 7,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              zh ? '满足' : 'Match',
              style: TextStyle(fontSize: 15, color: text2),
            ),
            Builder(
              builder: (pillContext) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openMatchModeMenu(pillContext, zh: zh),
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
                        pillText,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Text(
              zh ? '条件时' : 'conditions',
              style: TextStyle(fontSize: 15, color: text2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCoverStrip(
    List<GalleryProvider> historyHits, {
    required Color fill,
    required Color text2,
  }) {
    final overflowCount = historyHits.length > 5 ? historyHits.length - 4 : 0;
    final coverSlots = overflowCount > 0 ? 4 : historyHits.length;

    return Row(
      children: <Widget>[
        for (var slot = 0; slot < 5; slot++) ...<Widget>[
          if (slot > 0) const SizedBox(width: 7),
          Expanded(
            child: slot < coverSlots
                ? AspectRatio(
                    aspectRatio: 3 / 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: (historyHits[slot].imgUrl?.isNotEmpty ?? false)
                          ? EhNetworkImage(
                              imageUrl: historyHits[slot].imgUrl!,
                              fit: BoxFit.cover,
                            )
                          : ColoredBox(color: fill),
                    ),
                  )
                : (slot == 4 && overflowCount > 0)
                    ? AspectRatio(
                        aspectRatio: 3 / 4,
                        child: Container(
                          decoration: BoxDecoration(
                            color: fill,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '+$overflowCount',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: text2,
                              fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final onAccent = EhPalette.onAccent.resolveFrom(context);
    final accentSoft = EhPalette.accentSoft.resolveFrom(context);
    final surface = palette.surface.resolveFrom(context);
    final fill = palette.fill.resolveFrom(context);
    final text1 = palette.text1.resolveFrom(context);
    final text2 = palette.text2.resolveFrom(context);
    final text3 = palette.text3.resolveFrom(context);
    final hairline = palette.hairline.resolveFrom(context);

    final draft = _buildDraftRule();
    final autoTitlePlaceholder = _conditions.isEmpty
        ? l10n.fav_rule_new_title
        : draft.copyWith(name: '').displayName(zh: zh);
    final historyHits = _service.matchHistoryGalleries(draft);
    final canSave = _canSave;
    final joinerLabel = _match == FavRuleMatch.all
        ? (zh ? '且' : 'AND')
        : (zh ? '或' : 'OR');

    final actions = <NativeNavigationAction>[
      NativeNavigationAction(
        id: 'favRule.save',
        title: l10n.save,
        symbol: 'checkmark',
        enabled: canSave,
        prominent: canSave,
        onPressed: canSave ? _save : null,
      ),
    ];

    final trailing = CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      minimumSize: const Size(36, 36),
      onPressed: canSave ? _save : null,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: canSave ? accent : fill,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: EhSvgIcon(
          CupertinoIcons.checkmark_alt,
          size: 19,
          color: canSave ? onAccent : text3,
        ),
      ),
    );

    final cardDecoration = groupedSectionDecoration(context);

    return SettingScaffold(
      title: '',
      actions: actions,
      trailing: trailing,
      child: Builder(
        builder: (bodyContext) {
          final safe = resolvePopupSafeInsets(bodyContext);
          final leftPad = math.max(16.0, safe.left + 8.0);
          final rightPad = math.max(16.0, safe.right + 8.0);

          return CustomScrollView(
            slivers: <Widget>[
              SliverSafeArea(
                left: false,
                right: false,
                sliver: SliverPadding(
                  padding: EdgeInsets.fromLTRB(leftPad, 8, rightPad, 34),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(<Widget>[
                      // Unboxed Page-Title Rule Name (26pt w700) + Subtitle
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: CupertinoTextField(
                                    controller: _nameController,
                                    focusNode: _nameFocusNode,
                                    placeholder: autoTitlePlaceholder,
                                    placeholderStyle: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                      color: text3,
                                    ),
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                      color: text1,
                                    ),
                                    padding: EdgeInsets.zero,
                                    decoration: null,
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _nameFocusNode.requestFocus,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: EhSvgIcon(
                                      CupertinoIcons.pencil,
                                      size: 16,
                                      color: text3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            _buildSubtitleRow(
                              bodyContext,
                              l10n: l10n,
                              text2: text2,
                            ),
                          ],
                        ),
                      ),

                      // Conditions sentence header
                      _buildConditionLeadHeader(
                        zh: zh,
                        text2: text2,
                        accent: accent,
                        accentSoft: accentSoft,
                      ),

                      // Conditions card with Slidable delete & 且/或 joiners
                      Container(
                        decoration: cardDecoration,
                        clipBehavior: Clip.antiAlias,
                        child: SlidableAutoCloseBehavior(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              for (var i = 0;
                                  i < _conditions.length;
                                  i++) ...<Widget>[
                                if (i > 0)
                                  _ConditionJoiner(
                                    label: joinerLabel,
                                    surface: surface,
                                    hairline: hairline,
                                    text2: text2,
                                  ),
                                Slidable(
                                  key: ValueKey<String>(
                                    'cond-$i-${_conditions[i].hashCode}',
                                  ),
                                  endActionPane: ActionPane(
                                    extentRatio: 0.24,
                                    motion: const ScrollMotion(),
                                    children: <Widget>[
                                      SlidableAction(
                                        onPressed: (_) => _removeCondition(i),
                                        backgroundColor:
                                            CupertinoDynamicColor.resolve(
                                          CupertinoColors.systemRed,
                                          bodyContext,
                                        ),
                                        foregroundColor: CupertinoColors.white,
                                        label: l10n.delete,
                                      ),
                                    ],
                                  ),
                                  child: _ConditionRow(
                                    condition: _conditions[i],
                                    zh: zh,
                                    fill: fill,
                                    text1: text1,
                                    text2: text2,
                                    text3: text3,
                                    onTap: () => _editCondition(i),
                                  ),
                                ),
                              ],
                              if (_conditions.isNotEmpty)
                                Container(
                                  height: 0.5,
                                  margin: const EdgeInsets.only(left: 16),
                                  color: hairline,
                                ),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _addCondition,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minHeight: 52,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        EhSvgIcon(
                                          CupertinoIcons.plus,
                                          size: 17,
                                          color: accent,
                                        ),
                                        const SizedBox(width: 9),
                                        Text(
                                          l10n.fav_rule_add_condition,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: accent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Target folder section (`收进` + shared 2-column grid)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 26, 4, 10),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                l10n.fav_rule_save_into_lead,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: text2,
                                ),
                              ),
                            ),
                            if (_favcat.isEmpty)
                              Text(
                                l10n.fav_rule_pick_one_folder_hint,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: text3,
                                ),
                              ),
                          ],
                        ),
                      ),
                      FavFolderTwoColumnGrid(
                        choices: _service.availableFavcats(includeLocal: true),
                        selectedFavcat: _favcat,
                        useSurfaceCards: true,
                        onSelect: (fav) {
                          unawaited(vibrateUtil.selection());
                          setState(() => _favcat = fav.favId);
                        },
                      ),

                      // History hit preview card (5-slot 3:4 cover strip or empty note)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 26, 4, 8),
                        child: Text(
                          l10n.fav_rule_preview,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: text2,
                          ),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: historyHits.isNotEmpty
                            ? () => _showHistoryMatchesSheet(historyHits)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                          decoration: cardDecoration,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      l10n.fav_rule_history_hits_matched(
                                        historyHits.length,
                                      ),
                                      style: TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w600,
                                        color: text1,
                                      ),
                                    ),
                                  ),
                                  if (historyHits.isNotEmpty)
                                    EhSvgIcon(
                                      CupertinoIcons.chevron_forward,
                                      size: 14,
                                      color: text3,
                                    ),
                                ],
                              ),
                              if (historyHits.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 12),
                                _buildHistoryCoverStrip(
                                  historyHits,
                                  fill: fill,
                                  text2: text2,
                                ),
                              ] else ...<Widget>[
                                const SizedBox(height: 6),
                                Text(
                                  l10n.fav_rule_history_empty_save_ok,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    height: 1.4,
                                    color: text2,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Bottom independent Delete Rule card when editing
                      if (_editingRule != null) ...<Widget>[
                        const SizedBox(height: 22),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _confirmDelete,
                          child: Container(
                            height: 52,
                            decoration: cardDecoration,
                            alignment: Alignment.center,
                            child: Text(
                              l10n.fav_rule_delete_title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: CupertinoDynamicColor.resolve(
                                  CupertinoColors.systemRed,
                                  bodyContext,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ConditionJoiner extends StatelessWidget {
  const _ConditionJoiner({
    required this.label,
    required this.surface,
    required this.hairline,
    required this.text2,
  });

  final String label;
  final Color surface;
  final Color hairline;
  final Color text2;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: <Widget>[
          Container(
            height: 0.5,
            margin: const EdgeInsets.only(left: 16),
            color: hairline,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Container(
              height: 20,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: hairline, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.0,
                      color: text2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConditionRow extends StatelessWidget {
  const _ConditionRow({
    required this.condition,
    required this.zh,
    required this.fill,
    required this.text1,
    required this.text2,
    required this.text3,
    required this.onTap,
  });

  final FavRuleCondition condition;
  final bool zh;
  final Color fill;
  final Color text1;
  final Color text2;
  final Color text3;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final List<Widget> valueChildren;
    if (condition.isCategory) {
      final cats = condition.categoryValues;
      final opWord = condition.negated
          ? (zh ? '不是' : 'is not')
          : (cats.length >= 2
              ? (zh ? '是其中之一' : 'in')
              : (zh ? '是' : 'is'));
      final opColor = condition.negated
          ? CupertinoDynamicColor.resolve(CupertinoColors.systemRed, context)
          : text2;
      valueChildren = <Widget>[
        Text(
          opWord,
          style: TextStyle(
            fontSize: 14,
            fontWeight: condition.negated ? FontWeight.w500 : FontWeight.w400,
            color: opColor,
          ),
        ),
        for (final cat in cats)
          FavCategoryBadge(
            category: cat,
            height: 28,
            borderRadius: 9,
            fontSize: 14,
            negated: condition.negated,
          ),
      ];
    } else {
      final displayValue = condition.op == FavRuleOp.regex
          ? '/${condition.value}/'
          : condition.value;
      valueChildren = <Widget>[
        Text(
          favRuleOpShortLabel(condition.op, zh: zh),
          style: TextStyle(fontSize: 14, color: text2),
        ),
        Text(
          displayValue,
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w600,
            color: text1,
          ),
        ),
        if (condition.matchTranslation)
          Container(
            height: 20,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  zh ? '译' : 'TR',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                    color: text2,
                  ),
                ),
              ],
            ),
          ),
      ];
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 44,
                child: Text(
                  favRuleNamespaceShortLabel(condition.namespace, zh: zh),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: text2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: valueChildren,
                ),
              ),
              const SizedBox(width: 10),
              EhSvgIcon(
                CupertinoIcons.chevron_forward,
                size: 14,
                color: text3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
