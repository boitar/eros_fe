import 'dart:math' as math;

import 'package:eros_fe/common/service/fav_rule_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/models/fav_rule.dart';
import 'package:eros_fe/pages/setting/fav_rule/fav_rule_edit_page.dart';
import 'package:eros_fe/pages/setting/setting_items/selector_Item.dart';
import 'package:eros_fe/widget/fav_rule_safe_area.dart';
import 'package:eros_fe/widget/fav_rule_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Material, MaterialType, ReorderableListView;
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:sliver_tools/sliver_tools.dart';

/// Main Rule Favorites configuration page (prototype ②).
class FavRuleSettingPage extends StatelessWidget {
  const FavRuleSettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Get.find<FavRuleService>();
    final l10n = L10n.of(context);
    final zh = Localizations.localeOf(context).languageCode == 'zh';

    void openNewRule() {
      Get.toNamed<dynamic>(
        EHRoutes.favRuleEdit,
        arguments: const FavRuleEditArgs(),
        id: detailNavigatorId,
        preventDuplicates: false,
      );
    }

    void openTestPage() {
      Get.toNamed<dynamic>(
        EHRoutes.favRuleTest,
        id: detailNavigatorId,
      );
    }

    return SettingScaffold(
      title: l10n.fav_rule_title,
      actions: <NativeNavigationAction>[
        NativeNavigationAction(
          id: 'favRule.new',
          title: l10n.fav_rule_new_title,
          symbol: 'plus',
          onPressed: openNewRule,
        ),
        NativeNavigationAction(
          id: 'favRule.test',
          title: l10n.fav_rule_test_title,
          symbol: 'flask',
          onPressed: openTestPage,
        ),
      ],
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(36, 36),
            onPressed: openNewRule,
            child: const EhSvgIcon(CupertinoIcons.plus, size: 22),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(36, 36),
            onPressed: openTestPage,
            child: const EhSvgIcon(CupertinoIcons.lab_flask, size: 20),
          ),
        ],
      ),
      child: Builder(
        builder: (bodyContext) {
          final safe = resolvePopupSafeInsets(bodyContext);
          final leftPad = math.max(16.0, safe.left + 8.0);
          final rightPad = math.max(16.0, safe.right + 8.0);

          // Child grouped sections already carry a 16pt horizontal margin so
          // their headers align with row text; add the extra Duo rail clearance
          // here so outer card edges land at exact `leftPad` / `rightPad`.
          return CustomScrollView(
            slivers: <Widget>[
              SliverSafeArea(
                left: false,
                right: false,
                sliver: SliverPadding(
                  padding: EdgeInsets.only(
                    left: leftPad - 16.0,
                    right: rightPad - 16.0,
                  ),
                  sliver: Obx(() {
                    final cfg = service.config;
                    final favMap = <String, String>{
                      for (final f
                          in service.availableFavcats(includeLocal: true))
                        f.favId: f.favTitle,
                    };
                    final fallbackFavVal =
                        favMap.containsKey(cfg.fallbackFavcat)
                            ? cfg.fallbackFavcat
                            : (favMap.keys.isNotEmpty ? favMap.keys.first : '0');

                    return MultiSliver(
                      children: <Widget>[
                        if (cfg.showMigrationBanner)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            sliver: SliverToBoxAdapter(
                              child: _MigrationNoticeCard(
                                onDismiss: service.dismissMigrationBanner,
                              ),
                            ),
                          ),

                        // Master toggle
                        SliverCupertinoListSection.listInsetGrouped(
                          children: <Widget>[
                            EhCupertinoListTile(
                              title: Text(l10n.fav_rule_enable),
                              subtitle: Text(l10n.fav_rule_enable_desc),
                              trailing: CupertinoSwitch(
                                value: cfg.enabled,
                                onChanged: service.setEnabled,
                              ),
                            ),
                          ],
                        ),

                        // Trigger & Fallback section
                        SliverCupertinoListSection.listInsetGrouped(
                          header: Text(l10n.fav_rule_section_trigger),
                          children: <Widget>[
                            SelectorCupertinoListTile<FavRuleTrigger>(
                              title: l10n.fav_rule_trigger,
                              initVal: cfg.trigger,
                              actionMap: <FavRuleTrigger, String>{
                                FavRuleTrigger.tap: l10n.fav_rule_trigger_tap,
                                FavRuleTrigger.longPress:
                                    l10n.fav_rule_trigger_long_press,
                              },
                              onValueChanged: service.setTrigger,
                            ),
                            SelectorCupertinoListTile<FavRuleFallback>(
                              title: l10n.fav_rule_fallback,
                              initVal: cfg.fallback,
                              actionMap: <FavRuleFallback, String>{
                                FavRuleFallback.picker:
                                    l10n.fav_rule_fallback_picker,
                                FavRuleFallback.last:
                                    l10n.fav_rule_fallback_last,
                                FavRuleFallback.fixed:
                                    l10n.fav_rule_fallback_fixed,
                              },
                              onValueChanged: service.setFallback,
                            ),
                            if (cfg.fallback == FavRuleFallback.fixed &&
                                favMap.isNotEmpty)
                              SelectorCupertinoListTile<String>(
                                title: l10n.fav_rule_fallback_folder,
                                initVal: fallbackFavVal,
                                actionMap: favMap,
                                onValueChanged: service.setFallbackFavcat,
                              ),
                            SelectorCupertinoListTile<FavRuleExisting>(
                              title: l10n.fav_rule_existing,
                              initVal: cfg.existing,
                              actionMap: <FavRuleExisting, String>{
                                FavRuleExisting.move:
                                    l10n.fav_rule_existing_move,
                                FavRuleExisting.keep:
                                    l10n.fav_rule_existing_keep,
                              },
                              onValueChanged: service.setExisting,
                            ),
                          ],
                        ),

                        // Presentation styles section (user-configurable ⑥ and ⑦)
                        SliverCupertinoListSection.listInsetGrouped(
                          header: Text(l10n.fav_rule_section_ui_style),
                          children: <Widget>[
                            SelectorCupertinoListTile<FavListMenuStyle>(
                              title: l10n.fav_rule_list_menu_style,
                              initVal: cfg.listMenuStyle,
                              actionMap: <FavListMenuStyle, String>{
                                FavListMenuStyle.contextMenu:
                                    l10n.fav_rule_list_menu_context,
                                FavListMenuStyle.actionSheet:
                                    l10n.fav_rule_list_menu_sheet,
                              },
                              onValueChanged: service.setListMenuStyle,
                            ),
                            SelectorCupertinoListTile<FavPickerStyle>(
                              title: l10n.fav_rule_picker_style,
                              initVal: cfg.pickerStyle,
                              actionMap: <FavPickerStyle, String>{
                                FavPickerStyle.grid: l10n.fav_rule_picker_grid,
                                FavPickerStyle.list: l10n.fav_rule_picker_list,
                                FavPickerStyle.wheel:
                                    l10n.fav_rule_picker_wheel,
                              },
                              onValueChanged: service.setPickerStyle,
                            ),
                          ],
                        ),

                        // Rules list section
                        SliverToBoxAdapter(
                          child: _RulesSectionCard(
                            rules: cfg.rules,
                            service: service,
                            zh: zh,
                            onNewRule: openNewRule,
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 28)),
                      ],
                    );
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MigrationNoticeCard extends StatelessWidget {
  const _MigrationNoticeCard({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final accent = EhPalette.accent.resolveFrom(context);
    final accentSoft = EhPalette.accentSoft.resolveFrom(context);
    final text1 = ehTheme.palette.text1.resolveFrom(context);
    final text2 = ehTheme.palette.text2.resolveFrom(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: accentSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accent.withValues(alpha: 0.30),
          width: 0.75,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: EhSvgIcon(
              CupertinoIcons.sparkles,
              size: 18,
              color: accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.fav_rule_migrated_title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: text1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.fav_rule_migrated_desc,
                  style: TextStyle(fontSize: 12.5, color: text2, height: 1.35),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(4),
            minimumSize: const Size(28, 28),
            onPressed: onDismiss,
            child: EhSvgIcon(CupertinoIcons.xmark, size: 15, color: text2),
          ),
        ],
      ),
    );
  }
}

class _RulesSectionCard extends StatelessWidget {
  const _RulesSectionCard({
    required this.rules,
    required this.service,
    required this.zh,
    required this.onNewRule,
  });

  final List<FavRule> rules;
  final FavRuleService service;
  final bool zh;
  final VoidCallback onNewRule;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final text2 = palette.text2.resolveFrom(context);
    final text3 = palette.text3.resolveFrom(context);
    final hairline = palette.hairline.resolveFrom(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.fav_rule_section_rules,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: text2,
                    ),
                  ),
                ),
                Text(
                  l10n.fav_rule_order_hint,
                  style: TextStyle(fontSize: 12, color: text3),
                ),
              ],
            ),
          ),
          Container(
            decoration: groupedSectionDecoration(context),
            clipBehavior: Clip.antiAlias,
            child: SlidableAutoCloseBehavior(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (rules.isNotEmpty)
                    Material(
                      type: MaterialType.transparency,
                      child: ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: rules.length,
                        onReorderItem: (oldIndex, newIndex) =>
                            service.reorderRules(
                          oldIndex,
                          newIndex,
                          adjustNewIndex: false,
                        ),
                        proxyDecorator: (child, index, animation) {
                          return Material(
                            type: MaterialType.transparency,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: palette.raised.resolveFrom(context),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: const <BoxShadow>[
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 18,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: child,
                            ),
                          );
                        },
                        itemBuilder: (ctx, index) {
                          final rule = rules[index];
                          return Column(
                            key: ValueKey<String>(rule.id),
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (index > 0)
                                Container(
                                  height: 0.5,
                                  margin: const EdgeInsets.only(left: 64),
                                  color: hairline,
                                ),
                              Slidable(
                                key: ValueKey<String>('slidable-${rule.id}'),
                                endActionPane: ActionPane(
                                  extentRatio: 0.25,
                                  motion: const ScrollMotion(),
                                  children: <Widget>[
                                    SlidableAction(
                                      onPressed: (_) =>
                                          service.deleteRule(rule.id),
                                      backgroundColor:
                                          CupertinoDynamicColor.resolve(
                                        CupertinoColors.systemRed,
                                        ctx,
                                      ),
                                      foregroundColor: CupertinoColors.white,
                                      icon: CupertinoIcons.delete,
                                    ),
                                  ],
                                ),
                                child: ReorderableDelayedDragStartListener(
                                  index: index,
                                  child: _FavRuleListRow(
                                    rule: rule,
                                    favTitle: service.favTitleFor(rule.favcat),
                                    zh: zh,
                                    onTap: () {
                                      Get.toNamed<dynamic>(
                                        EHRoutes.favRuleEdit,
                                        arguments: FavRuleEditArgs(
                                          existingRule: rule,
                                        ),
                                        id: detailNavigatorId,
                                        preventDuplicates: false,
                                      );
                                    },
                                    onToggle: (val) =>
                                        service.toggleRule(rule.id, val),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  if (rules.isNotEmpty)
                    Container(
                      height: 0.5,
                      margin: const EdgeInsets.only(left: 16),
                      color: hairline,
                    ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onNewRule,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 52),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: <Widget>[
                            EhSvgIcon(
                              CupertinoIcons.plus,
                              size: 17,
                              color: accent,
                            ),
                            const SizedBox(width: 9),
                            Text(
                              l10n.fav_rule_new_title,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(
              l10n.fav_rule_list_footer,
              style: TextStyle(fontSize: 12.5, color: text3),
            ),
          ),
        ],
      ),
    );
  }
}

class _FavRuleListRow extends StatelessWidget {
  const _FavRuleListRow({
    required this.rule,
    required this.favTitle,
    required this.zh,
    required this.onTap,
    required this.onToggle,
  });

  final FavRule rule;
  final String favTitle;
  final bool zh;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  List<Widget> _buildConditionSummaryItems({
    required Color fill,
    required Color text1,
    required Color text3,
    required String joiner,
  }) {
    final items = <Widget>[];
    final shown = rule.conditions.take(3).toList(growable: false);
    for (var i = 0; i < shown.length; i++) {
      if (i > 0) {
        items.add(
          Text(
            joiner,
            style: TextStyle(
              fontSize: 11.5,
              color: text3,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }
      final c = shown[i];
      if (c.isCategory) {
        final cats = c.categoryValues;
        if (cats.isEmpty) {
          items.add(
            _TagSummaryPill(
              text: favRuleNamespaceShortLabel(c.namespace, zh: zh),
              fill: fill,
              text1: text1,
            ),
          );
        } else {
          for (final cat in cats.take(2)) {
            items.add(
              FavCategoryBadge.compact(
                category: cat,
                negated: c.negated,
              ),
            );
          }
          if (cats.length > 2) {
            items.add(
              Text(
                '+${cats.length - 2}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: text3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }
        }
      } else {
        final valText = c.op == FavRuleOp.regex ? '/${c.value}/' : c.value;
        items.add(
          _TagSummaryPill(
            text: '${favRuleNamespaceShortLabel(c.namespace, zh: zh)} $valText',
            fill: fill,
            text1: text1,
          ),
        );
      }
    }
    if (rule.conditions.length > 3) {
      items.add(
        Text(
          '+${rule.conditions.length - 3}',
          style: TextStyle(
            fontSize: 11.5,
            color: text3,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final favColor = CupertinoDynamicColor.resolve(
      ThemeColors.favColorFor(rule.favcat),
      context,
    );
    final fill = palette.fill.resolveFrom(context);
    final text1 = palette.text1.resolveFrom(context);
    final text2 = palette.text2.resolveFrom(context);
    final text3 = palette.text3.resolveFrom(context);
    final joiner = rule.match == FavRuleMatch.all
        ? (zh ? '且' : 'AND')
        : (zh ? '或' : 'OR');

    return Opacity(
      opacity: rule.enabled ? 1.0 : 0.50,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: favColor.withValues(alpha: dark ? 0.22 : 0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: EhSvgIcon(
                    CupertinoIcons.heart_fill,
                    size: 18,
                    color: favColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        rule.displayName(zh: zh),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: text1,
                        ),
                      ),
                      if (rule.conditions.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: _buildConditionSummaryItems(
                            fill: fill,
                            text1: text1,
                            text3: text3,
                            joiner: joiner,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text.rich(
                        zh
                            ? TextSpan(
                                style: TextStyle(fontSize: 13, color: text2),
                                children: <InlineSpan>[
                                  const TextSpan(text: '收进「'),
                                  TextSpan(
                                    text: favTitle,
                                    style: TextStyle(
                                      color: favColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const TextSpan(text: '」'),
                                ],
                              )
                            : TextSpan(
                                style: TextStyle(fontSize: 13, color: text2),
                                children: <InlineSpan>[
                                  const TextSpan(text: 'Save to "'),
                                  TextSpan(
                                    text: favTitle,
                                    style: TextStyle(
                                      color: favColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const TextSpan(text: '"'),
                                ],
                              ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                CupertinoSwitch(
                  value: rule.enabled,
                  onChanged: onToggle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TagSummaryPill extends StatelessWidget {
  const _TagSummaryPill({
    required this.text,
    required this.fill,
    required this.text1,
  });

  final String text;
  final Color fill;
  final Color text1;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.1,
                color: text1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
