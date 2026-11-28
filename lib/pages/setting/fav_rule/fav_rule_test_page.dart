import 'package:eros_fe/common/controller/history_controller.dart';
import 'package:eros_fe/common/service/fav_rule_matcher.dart';
import 'package:eros_fe/common/service/fav_rule_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/fav_rule.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/widget/cupertino/sliver_list_section.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:eros_fe/widget/fav_rule_safe_area.dart';
import 'package:eros_fe/widget/image/eh_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

/// Interactive Rule Test page reachable from the flask action in ②.
class FavRuleTestPage extends StatefulWidget {
  const FavRuleTestPage({super.key});

  @override
  State<FavRuleTestPage> createState() => _FavRuleTestPageState();
}

class _FavRuleTestPageState extends State<FavRuleTestPage> {
  final FavRuleService _service = Get.find<FavRuleService>();
  final TextEditingController _customTagController = TextEditingController();
  int _mode = 0; // 0 = history gallery, 1 = manual tag input
  GalleryProvider? _selectedGallery;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<HistoryController>()) {
      final histories = Get.find<HistoryController>().histories;
      if (histories.isNotEmpty) {
        _selectedGallery = histories.first;
      }
    }
  }

  @override
  void dispose() {
    _customTagController.dispose();
    super.dispose();
  }

  FavRuleEvalResult _evaluateCurrent() {
    if (_mode == 1) {
      final tags = FavRuleMatcher.parseFreeformTags(_customTagController.text);
      return FavRuleMatcher.evaluate(_service.rules, tags);
    }
    final gallery = _selectedGallery;
    if (gallery == null) {
      return FavRuleEvalResult.miss;
    }
    return _service.evaluateGallerySync(gallery);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final palette = ehTheme.palette;
    final field = palette.field.resolveFrom(context);
    final fill = palette.fill.resolveFrom(context);
    final accent = EhPalette.accent.resolveFrom(context);
    final text1 = palette.text1.resolveFrom(context);
    final text2 = palette.text2.resolveFrom(context);
    final text3 = palette.text3.resolveFrom(context);
    final hairline = palette.hairline.resolveFrom(context);
    final cardDecoration = groupedSectionDecoration(context);

    final histories = Get.isRegistered<HistoryController>()
        ? Get.find<HistoryController>().histories.take(40).toList()
        : const <GalleryProvider>[];
    final eval = _evaluateCurrent();

    return SettingScaffold(
      title: l10n.fav_rule_test_title,
      child: CustomScrollView(
        slivers: <Widget>[
          SliverSafeArea(
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate(<Widget>[
                  CupertinoSlidingSegmentedControl<int>(
                    groupValue: _mode,
                    children: <int, Widget>{
                      0: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(l10n.fav_rule_test_from_history),
                      ),
                      1: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(l10n.fav_rule_test_custom_tags),
                      ),
                    },
                    onValueChanged: (val) {
                      if (val != null) {
                        setState(() => _mode = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Result card
                  _TestResultCard(
                    eval: eval,
                    service: _service,
                    zh: zh,
                  ),
                  const SizedBox(height: 18),

                  if (_mode == 1) ...<Widget>[
                    Text(
                      l10n.fav_rule_test_input_label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: text2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: _customTagController,
                      minLines: 2,
                      maxLines: 4,
                      placeholder: l10n.fav_rule_test_input_placeholder,
                      placeholderStyle: TextStyle(color: text3),
                      style: TextStyle(fontSize: 14.5, color: text1),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: field,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: hairline, width: 0.6),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ] else ...<Widget>[
                    Text(
                      l10n.fav_rule_test_pick_gallery,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: text2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (histories.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: cardDecoration,
                        child: Text(
                          l10n.fav_rule_test_no_history,
                          style: TextStyle(fontSize: 14, color: text2),
                        ),
                      )
                    else
                      Container(
                        decoration: cardDecoration,
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: <Widget>[
                            for (var i = 0; i < histories.length; i++) ...<Widget>[
                              if (i > 0)
                                Container(
                                  height: 0.5,
                                  margin: const EdgeInsets.only(left: 72),
                                  color: hairline,
                                ),
                              _HistoryPickRow(
                                gallery: histories[i],
                                selected:
                                    _selectedGallery?.gid == histories[i].gid,
                                accent: accent,
                                fill: fill,
                                text1: text1,
                                text2: text2,
                                onTap: () => setState(
                                  () => _selectedGallery = histories[i],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TestResultCard extends StatelessWidget {
  const _TestResultCard({
    required this.eval,
    required this.service,
    required this.zh,
  });

  final FavRuleEvalResult eval;
  final FavRuleService service;
  final bool zh;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final text1 = palette.text1.resolveFrom(context);
    final text2 = palette.text2.resolveFrom(context);
    final text3 = palette.text3.resolveFrom(context);

    final primary = eval.primary;
    if (primary == null) {
      final fallbackLabel = switch (service.config.fallback) {
        FavRuleFallback.picker => l10n.fav_rule_fallback_picker,
        FavRuleFallback.last => l10n.fav_rule_fallback_last,
        FavRuleFallback.fixed =>
          '${l10n.fav_rule_fallback_fixed} (${service.favTitleFor(service.config.fallbackFavcat)})',
      };
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: groupedSectionDecoration(context),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: palette.fill.resolveFrom(context),
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: EhSvgIcon(
                CupertinoIcons.question_circle,
                size: 20,
                color: text2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.fav_rule_miss_title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: text1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l10n.fav_rule_test_fallback_desc(fallbackLabel),
                    style: TextStyle(fontSize: 13, color: text2),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final favColor = CupertinoDynamicColor.resolve(
      ThemeColors.favColorFor(primary.rule.favcat),
      context,
    );
    final favTitle = service.favTitleFor(primary.rule.favcat);
    final matchedSummary = primary.matchedTags
        .map((t) => t.displayLabel())
        .take(3)
        .join(', ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: favColor.withValues(alpha: dark ? 0.18 : 0.11),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(kInsetGroupedSectionRadius),
          side: BorderSide(
            color: favColor.withValues(alpha: dark ? 0.40 : 0.30),
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: favColor.withValues(alpha: dark ? 0.28 : 0.18),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: EhSvgIcon(
                  CupertinoIcons.heart_fill,
                  size: 19,
                  color: favColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.fav_rule_save_to_folder(favTitle),
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: text1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.fav_rule_reason_with_tag(
                        primary.rule.displayName(zh: zh),
                        matchedSummary,
                      ),
                      style: TextStyle(fontSize: 13, color: text2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (eval.others.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              l10n.fav_rule_other_hits_note(
                eval.others.map((h) => h.rule.displayName(zh: zh)).join('、'),
              ),
              style: TextStyle(fontSize: 12, color: text3),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryPickRow extends StatelessWidget {
  const _HistoryPickRow({
    required this.gallery,
    required this.selected,
    required this.accent,
    required this.fill,
    required this.text1,
    required this.text2,
    required this.onTap,
  });

  final GalleryProvider gallery;
  final bool selected;
  final Color accent;
  final Color fill;
  final Color text1;
  final Color text2;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = (gallery.japaneseTitle?.isNotEmpty ?? false)
        ? gallery.japaneseTitle!
        : (gallery.englishTitle ?? '');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 58,
                child: (gallery.imgUrl?.isNotEmpty ?? false)
                    ? EhNetworkImage(
                        imageUrl: gallery.imgUrl!,
                        fit: BoxFit.cover,
                      )
                    : Container(color: fill),
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
                  if (gallery.category?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 3),
                    Text(
                      gallery.category!,
                      style: TextStyle(fontSize: 12, color: text2),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              EhSvgIcon(
                CupertinoIcons.checkmark_alt,
                size: 18,
                color: accent,
              ),
          ],
        ),
      ),
    );
  }
}
