import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/controller/tag_trans_controller.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/fav_rule_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/models/fav_rule.dart';
import 'package:eros_fe/pages/gallery/controller/taginfo_controller.dart';
import 'package:eros_fe/pages/setting/controller/eh_mytags_controller.dart';
import 'package:eros_fe/pages/setting/fav_rule/fav_rule_edit_page.dart';
import 'package:eros_fe/store/db/entity/tag_translat.dart';
import 'package:eros_fe/widget/fav_rule_safe_area.dart';
import 'package:eros_fe/widget/fav_rule_widgets.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

const Key kCategoryInfoPopoverSurfaceKey =
    ValueKey<String>('category-info-popover-surface');
const Key kCategoryInfoPopoverArrowKey =
    ValueKey<String>('category-info-popover-arrow');

bool _isZhLocale(BuildContext context) {
  if (Get.isRegistered<LocaleService>()) {
    return Get.find<LocaleService>().isLanguageCodeZh;
  }
  final locale = Localizations.maybeLocaleOf(context) ?? Get.locale;
  if (locale != null) {
    return locale.languageCode.toLowerCase().startsWith('zh');
  }
  return ui.PlatformDispatcher.instance.locale.languageCode
      .toLowerCase()
      .startsWith('zh');
}

Rect? _tryMeasureElementAnchor(BuildContext context) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize || box.size.isEmpty) {
    return null;
  }
  final screenSize = MediaQuery.maybeOf(context)?.size;
  if (screenSize != null &&
      !screenSize.isEmpty &&
      box.size.width >= screenSize.width * 0.8 &&
      box.size.height >= screenSize.height * 0.5) {
    return null;
  }
  final topLeft = (overlayBox != null && overlayBox.hasSize)
      ? box.localToGlobal(Offset.zero, ancestor: overlayBox)
      : box.localToGlobal(Offset.zero);
  return topLeft & box.size;
}

/// Shows an anchored single-pane category info popover with a 46pt category
/// color swatch, localized subtitle, 2-column action tiles (`搜索此分类` and
/// `新建规则`), and conditional rule-usage footer.
Future<void> showCategoryInfoPopover(
  BuildContext context, {
  required String category,
  Rect? anchorRect,
}) {
  final measuredAnchor = anchorRect ?? _tryMeasureElementAnchor(context);
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: const Color(0x00000000),
      transitionDuration: const Duration(milliseconds: 190),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (routeContext, animation, _) {
        final screenSize = MediaQuery.sizeOf(routeContext);
        final paneBounds = resolveSinglePaneSafeBounds(
          routeContext,
          preferredAnchor: measuredAnchor,
        );
        final effectiveAnchor = measuredAnchor ??
            Rect.fromCenter(
              center: Offset(
                paneBounds.center.dx,
                paneBounds.top + math.min(180.0, paneBounds.height * 0.28),
              ),
              width: 72,
              height: 28,
            );

        final maxAllowedWidth = math.max(0.0, paneBounds.width - 28.0);
        final cardWidth = maxAllowedWidth < 240.0
            ? maxAllowedWidth
            : math.min(354.0, maxAllowedWidth);
        final minLeft = paneBounds.left + 14.0;
        final maxLeft = math.max(minLeft, paneBounds.right - 14.0 - cardWidth);
        final cardLeft = (effectiveAnchor.center.dx - cardWidth / 2.0)
            .clamp(minLeft, maxLeft)
            .toDouble();

        final spaceBelow = paneBounds.bottom - effectiveAnchor.bottom;
        final spaceAbove = effectiveAnchor.top - paneBounds.top;
        final placeBelow = spaceBelow >= 220.0 || spaceBelow >= spaceAbove;

        final cardTop = placeBelow
            ? math.max(paneBounds.top + 10.0, effectiveAnchor.bottom + 10.0)
            : null;
        final cardBottom = placeBelow
            ? null
            : math.min(paneBounds.bottom - 10.0, effectiveAnchor.top - 10.0);

        final minArrowLeft = cardLeft + 22.0;
        final maxArrowLeft =
            math.max(minArrowLeft, cardLeft + cardWidth - 36.0);
        final arrowGlobalLeft = (effectiveAnchor.center.dx - 7.0)
            .clamp(minArrowLeft, maxArrowLeft)
            .toDouble();
        final arrowLocalLeft = arrowGlobalLeft - cardLeft;

        final alignX = cardWidth > 0
            ? (((arrowGlobalLeft + 7.0 - cardLeft) / cardWidth) * 2.0 - 1.0)
                .clamp(-0.85, 0.85)
                .toDouble()
            : 0.0;

        final scaleAnim = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        final fadeAnim = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );

        final l10n = L10n.of(routeContext);
        final isZh = _isZhLocale(routeContext);
        final canonical =
            canonicalizeFavRuleCategory(category) ?? category.trim();
        final meta = favRuleCategoryMetaFor(canonical);
        final subtitle = isZh
            ? (meta?.zhPopoverSubtitle ?? canonical)
            : (meta?.enPopoverSubtitle ?? canonical);
        final ruleCount = Get.isRegistered<FavRuleService>()
            ? Get.find<FavRuleService>().countRulesUsingCategory(canonical)
            : 0;

        final palette = ehTheme.palette;
        final dark = CupertinoTheme.brightnessOf(routeContext) == Brightness.dark;
        final accent = EhPalette.accent.resolveFrom(routeContext);
        final accentSoft = EhPalette.accentSoft.resolveFrom(routeContext);
        final tileBg = palette.fill.resolveFrom(routeContext);
        final text1 = palette.text1.resolveFrom(routeContext);
        final text2 = palette.text2.resolveFrom(routeContext);
        final hairline = palette.hairline.resolveFrom(routeContext);

        final glassActive = liquidGlassPopupsEnabled &&
            GlassMode.of(routeContext).forComponent(flutterImplemented: true) !=
                GlassMode.off;
        final raised = CupertinoDynamicColor.resolve(palette.raised, routeContext);
        final arrowColor = glassActive
            ? CupertinoDynamicColor.resolve(
                CupertinoColors.secondarySystemBackground,
                routeContext,
              ).withValues(alpha: dark ? 0.90 : 0.88)
            : raised;
        final arrowBorderColor = dark
            ? CupertinoDynamicColor.resolve(palette.edgeLight, routeContext)
            : hairline;

        final arrowStrip = SizedBox(
          width: cardWidth,
          height: 10.0,
          child: ClipRect(
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned(
                  left: arrowLocalLeft,
                  top: placeBelow ? 3.0 : -7.0,
                  width: 14.0,
                  height: 14.0,
                  child: Transform.rotate(
                    angle: math.pi / 4,
                    child: Container(
                      key: kCategoryInfoPopoverArrowKey,
                      width: 14.0,
                      height: 14.0,
                      decoration: BoxDecoration(
                        color: arrowColor,
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: arrowBorderColor, width: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        final maxCardHeight = placeBelow
            ? math.max(120.0, paneBounds.bottom - 8.0 - cardTop!)
            : math.max(120.0, cardBottom! - (paneBounds.top + 8.0));

        final cardSurface = ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxCardHeight),
          child: buildFavRuleGlassOrCardSurface(
            key: kCategoryInfoPopoverSurfaceKey,
            context: routeContext,
            borderRadius: const BorderRadius.all(Radius.circular(26)),
            child: DefaultTextStyle(
              style: EhPopupTextStyles.body(routeContext),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        FavCategorySwatchSquare(
                          category: canonical,
                          size: 46,
                          borderRadius: 14,
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                canonical,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                  height: 1.15,
                                  color: text1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.25,
                                  color: text2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 46,
                          child: Align(
                            alignment: Alignment.topRight,
                            widthFactor: 1.0,
                            child: Container(
                              height: 22,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: tileBg,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                l10n.fav_rule_category_badge,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  height: 1.1,
                                  color: text2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _TagActionTile(
                            cupertinoIcon: CupertinoIcons.search,
                            iconSize: 20,
                            label: l10n.fav_rule_search_this_category,
                            fill: tileBg,
                            foreground: text1,
                            minHeight: 64,
                            borderRadius: 18,
                            fontSize: 13,
                            onPressed: () {
                              Navigator.of(routeContext).pop();
                              NavigatorUtil.goSearchPageWithParam(
                                simpleSearch: 'category:"$canonical"',
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _TagActionTile(
                            cupertinoIcon: CupertinoIcons.plus,
                            iconSize: 20,
                            label: l10n.fav_rule_create_from_tag_short,
                            fill: accentSoft,
                            foreground: accent,
                            borderColor: accent.withValues(alpha: 0.40),
                            minHeight: 64,
                            borderRadius: 18,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            onPressed: () {
                              final editArgs = FavRuleEditArgs(
                                initialConditions: <FavRuleCondition>[
                                  FavRuleCondition.category(
                                    <String>[canonical],
                                  ),
                                ],
                              );
                              Navigator.of(routeContext).pop();
                              Get.toNamed<dynamic>(
                                EHRoutes.favRuleEdit,
                                arguments: editArgs,
                                id: detailNavigatorId,
                                preventDuplicates: false,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    if (ruleCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.only(top: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: hairline, width: 0.5),
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              EhSvgIcon(
                                CupertinoIcons.slider_horizontal_3,
                                size: 14,
                                color: text2,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  l10n.fav_rule_category_used_count(ruleCount),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: text2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );

        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: AnimatedBuilder(
                animation: fadeAnim,
                builder: (context, child) {
                  final sigma = 8.0 * fadeAnim.value;
                  return BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                    child: Opacity(
                      opacity: fadeAnim.value,
                      child: child,
                    ),
                  );
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(routeContext).pop(),
                  child: const ColoredBox(color: Color(0x26000000)),
                ),
              ),
            ),
            Positioned(
              left: cardLeft,
              top: placeBelow ? cardTop! - 10.0 : null,
              bottom: placeBelow
                  ? null
                  : (screenSize.height - cardBottom!) - 10.0,
              width: cardWidth,
              child: FadeTransition(
                opacity: fadeAnim,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1.0).animate(scaleAnim),
                  alignment: Alignment(alignX, placeBelow ? -1.0 : 1.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: placeBelow
                        ? <Widget>[arrowStrip, cardSurface]
                        : <Widget>[cardSurface, arrowStrip],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

Future<void> showTagInfoDialog(
  BuildContext context,
  String text, {
  required String type,
  required String translate,
  int vote = 0,
}) {
  vibrateUtil.medium();
  Get.lazyPut(() => TagInfoController(), tag: pageCtrlTag);
  final TagInfoController controller = Get.find(tag: pageCtrlTag);

  return showCupertinoDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return _TagInfoCardDialog(
        text: text,
        type: type,
        translate: translate,
        vote: vote,
        controller: controller,
      );
    },
  );
}

class _TagInfoCardDialog extends StatelessWidget {
  const _TagInfoCardDialog({
    required this.text,
    required this.type,
    required this.translate,
    required this.vote,
    required this.controller,
  });

  final String text;
  final String type;
  final String translate;
  final int vote;
  final TagInfoController controller;

  Future<void> _tapAddToMyTags(BuildContext dialogContext) async {
    Navigator.of(dialogContext).pop();
    final myTagsController = Get.find<EhMyTagsController>();
    await myTagsController.showAddNewTagDialog(
      Get.context!,
      userTag: EhUsertag(
        title: '$type:$text',
        defaultColor: true,
        watch: true,
        tagWeight: '10',
      ),
    );
  }

  void _tapCreateFavRule(BuildContext dialogContext) {
    final ns = type.trim().toLowerCase();
    final condition = FavRuleCondition(
      namespace: ns.isEmpty ? null : ns,
      op: FavRuleOp.equals,
      value: text.trim(),
    );
    final editArgs = FavRuleEditArgs(
      initialConditions: <FavRuleCondition>[condition],
    );
    Navigator.of(dialogContext).pop();
    Get.toNamed<dynamic>(
      EHRoutes.favRuleEdit,
      arguments: editArgs,
      id: detailNavigatorId,
      preventDuplicates: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final isZh = _isZhLocale(context);
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final accent = EhPalette.accent.resolveFrom(context);
    final accentSoft = EhPalette.accentSoft.resolveFrom(context);
    final tileBg = dark
        ? palette.fill.resolveFrom(context)
        : palette.surface.resolveFrom(context);
    final hairline = palette.hairline.resolveFrom(context);
    final defaultBorder = dark ? null : hairline;
    final text1 = palette.text1.resolveFrom(context);
    final text2 = palette.text2.resolveFrom(context);
    final size = MediaQuery.sizeOf(context);
    final pane = resolveSinglePaneSafeBounds(context);
    final hasTranslatedTitle = translate.isNotEmpty && translate != text && isZh;

    final nsLabel = isZh
        ? '${favRuleNamespaceLabel(type, zh: true)} · $type'
        : type;

    final actionButtons = <Widget>[
      if (vote == 0) ...<Widget>[
        _TagActionTile(
          faIcon: FontAwesomeIcons.thumbsUp,
          label: l10n.tag_vote_up,
          fill: tileBg,
          foreground: text1,
          borderColor: defaultBorder,
          onPressed: () {
            Navigator.of(context).pop();
            controller.tagVoteUp('$type:$text');
          },
        ),
        _TagActionTile(
          faIcon: FontAwesomeIcons.thumbsDown,
          label: l10n.tag_vote_down,
          fill: tileBg,
          foreground: text1,
          borderColor: defaultBorder,
          onPressed: () {
            Navigator.of(context).pop();
            controller.tagVoteDown('$type:$text');
          },
        ),
      ] else if (vote == 1)
        _TagActionTile(
          faIcon: FontAwesomeIcons.arrowRotateLeft,
          label: l10n.tag_withdraw_vote,
          fill: tileBg,
          foreground: text1,
          borderColor: defaultBorder,
          onPressed: () {
            Navigator.of(context).pop();
            controller.tagVoteDown('$type:$text');
          },
        )
      else if (vote == -1)
        _TagActionTile(
          faIcon: FontAwesomeIcons.arrowRotateLeft,
          label: l10n.tag_withdraw_vote,
          fill: tileBg,
          foreground: text1,
          borderColor: defaultBorder,
          onPressed: () {
            Navigator.of(context).pop();
            controller.tagVoteUp('$type:$text');
          },
        ),
      _TagActionTile(
        faIcon: FontAwesomeIcons.tags,
        label: l10n.fav_rule_my_tags_short,
        fill: tileBg,
        foreground: text1,
        borderColor: defaultBorder,
        onPressed: () => _tapAddToMyTags(context),
      ),
      _TagActionTile(
        faIcon: FontAwesomeIcons.solidHeart,
        label: l10n.fav_rule_create_from_tag_short,
        fill: accentSoft,
        foreground: accent,
        borderColor: accent.withValues(alpha: 0.45),
        onPressed: () => _tapCreateFavRule(context),
      ),
    ];

    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          pane.left + 16,
          pane.top + 20,
          math.max(0.0, size.width - pane.right) + 16,
          math.max(0.0, size.height - pane.bottom) + 20,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 360,
              maxHeight: math.max(220, pane.height - 40),
            ),
            child: buildFavRuleGlassOrCardSurface(
              context: context,
              borderRadius: const BorderRadius.all(Radius.circular(26)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Namespace capsule
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accentSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          nsLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Tag name + original text
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            hasTranslatedTitle ? translate : text,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: text1,
                            ),
                          ),
                        ),
                        if (hasTranslatedTitle) ...<Widget>[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              text,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: text2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    if (isZh) ...<Widget>[
                      const SizedBox(height: 10),
                      Flexible(
                        child: SingleChildScrollView(
                          child: TagDialogView(text: text, type: type),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Bottom action icon tile row
                    Row(
                      children: <Widget>[
                        for (var i = 0; i < actionButtons.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(child: actionButtons[i]),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TagActionTile extends StatelessWidget {
  const _TagActionTile({
    this.faIcon,
    this.cupertinoIcon,
    required this.label,
    required this.fill,
    required this.foreground,
    required this.onPressed,
    this.borderColor,
    this.minHeight,
    this.fontSize = 11.5,
    this.borderRadius = 14,
    this.iconSize = 17,
    this.fontWeight = FontWeight.w500,
  }) : assert(
         (faIcon != null) ^ (cupertinoIcon != null),
         'Provide either faIcon or cupertinoIcon',
       );

  final FaIconData? faIcon;
  final IconData? cupertinoIcon;
  final String label;
  final Color fill;
  final Color foreground;
  final Color? borderColor;
  final VoidCallback onPressed;
  final double? minHeight;
  final double fontSize;
  final double borderRadius;
  final double iconSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    final Widget iconWidget = faIcon != null
        ? EhSvgFaIcon(faIcon!, size: iconSize, color: foreground)
        : EhSvgIcon(cupertinoIcon, size: iconSize, color: foreground);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        constraints:
            minHeight == null ? null : BoxConstraints(minHeight: minHeight!),
        padding: EdgeInsets.symmetric(
          vertical: minHeight == null ? 11 : 8,
          horizontal: minHeight == null ? 4 : 8,
        ),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(borderRadius),
          border: borderColor == null
              ? null
              : Border.all(color: borderColor!, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            iconWidget,
            SizedBox(height: minHeight == null ? 5 : 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: fontWeight,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TagDialogView extends StatefulWidget {
  const TagDialogView({Key? key, required this.type, required this.text})
      : super(key: key);

  final String type;
  final String text;

  @override
  _TagDialogViewState createState() => _TagDialogViewState();
}

class _TagDialogViewState extends State<TagDialogView> {
  late Future<TagTranslat?> _future;

  Future<TagTranslat?> _getTagInfo() async {
    final TagTranslat? _tagInfo =
        await Get.find<TagTransController>().getTagTranslate(
      widget.text,
      widget.type,
    );
    return _tagInfo;
  }

  @override
  void initState() {
    super.initState();
    _future = _getTagInfo();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TagTranslat?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasError) {
              return CupertinoButton(
                padding: const EdgeInsets.all(0),
                child: const EhSvgIcon(
                  Icons.refresh,
                  size: 30,
                  color: Colors.red,
                ),
                onPressed: () {
                  setState(() {
                    _future = _getTagInfo();
                  });
                },
              );
            } else {
              final TagTranslat? _taginfo = snapshot.data;
              final intro = _taginfo?.introMdImage ?? '';
              final links = _taginfo?.links ?? '';
              if (intro.isEmpty && links.isEmpty) {
                return const SizedBox.shrink();
              }
              final CupertinoThemeData theme = CupertinoTheme.of(context);
              final CupertinoThemeData lTheme = theme.copyWith(
                  textTheme: theme.textTheme.copyWith(
                      textStyle: theme.textTheme.textStyle.copyWith(
                fontSize: 14,
              )));

              return CupertinoTheme(
                data: lTheme,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (intro.isNotEmpty)
                      MarkdownBody(
                        data: intro,
                        selectable: true,
                        onTapLink: (String text, String? href, String title) {
                          onOpenUrl(url: href);
                        },
                        styleSheetTheme: MarkdownStyleSheetBaseTheme.cupertino,
                        styleSheet: MarkdownStyleSheet(
                          code: theme.textTheme.textStyle.copyWith(
                              backgroundColor: Colors.transparent,
                              color: CupertinoColors.systemPink,
                              fontSize:
                                  theme.textTheme.textStyle.fontSize! * 0.8,
                              fontFamilyFallback:
                                  EHConst.monoFontFamilyFallback),
                        ),
                        imageBuilder: (Uri uri, String? title, String? alt) {
                          return EhNetworkImage(
                            imageUrl: uri.toString(),
                            placeholder: (_, __) {
                              return const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CupertinoActivityIndicator(),
                              );
                            },
                          );
                        },
                      ),
                    if (intro.isNotEmpty && links.isNotEmpty)
                      const SizedBox(height: 10),
                    if (links.isNotEmpty)
                      MarkdownBody(
                        data: links,
                        selectable: true,
                        onTapLink: (String text, String? href, String title) {
                          onOpenUrl(url: href);
                        },
                        styleSheet: MarkdownStyleSheet(
                          a: const TextStyle(
                            color: CupertinoColors.activeBlue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        styleSheetTheme: MarkdownStyleSheetBaseTheme.cupertino,
                      ),
                  ],
                ),
              );
            }
          } else {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: const CupertinoActivityIndicator(),
            );
          }
        });
  }
}
