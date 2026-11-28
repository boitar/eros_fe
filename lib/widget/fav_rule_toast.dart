import 'dart:async';
import 'dart:math' as math;

import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/common/service/fav_rule_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/fav_rule.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:eros_fe/widget/fav_rule_safe_area.dart';
import 'package:eros_fe/widget/fav_rule_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

const Key kFavRuleBannerCloseButtonKey =
    ValueKey<String>('fav-rule-banner-close');

/// Action button rendered on the trailing side of [showFavRuleFeedbackBanner].
class FavRuleBannerAction {
  const FavRuleBannerAction({
    required this.label,
    required this.onPressed,
    this.isPrimary = true,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
}

class _ActiveBannerController {
  _ActiveBannerController(this.entry, this.forceRemove);
  final OverlayEntry entry;
  final void Function() forceRemove;
}

_ActiveBannerController? _activeBanner;

/// Dismisses any currently visible rule-favorite glass feedback banner.
void dismissFavRuleFeedbackBanner() {
  _activeBanner?.forceRemove();
}

OverlayState? _resolveRootOverlay(BuildContext targetContext) {
  final viaOverlay = Overlay.maybeOf(targetContext, rootOverlay: true);
  if (viaOverlay != null) {
    return viaOverlay;
  }
  if (targetContext is StatefulElement && targetContext.state is OverlayState) {
    return targetContext.state as OverlayState;
  }
  return Navigator.maybeOf(targetContext, rootNavigator: true)?.overlay ??
      Get.key.currentState?.overlay;
}

/// Builds a rich subtitle row (`规则「<ruleName>」` + [FavCategoryBadge.mini])
/// when [hit]'s primary matched condition is a gallery category, or `null` for
/// normal tag hits (which fall back to plain text `subtitle`).
Widget? buildFavRuleHitSubtitleWidget(
  L10n l10n,
  FavRuleHit hit, {
  required bool zh,
}) {
  final firstHit =
      hit.conditionHits.isEmpty ? null : hit.conditionHits.first;
  if (firstHit == null ||
      (!firstHit.condition.isCategory && !firstHit.tag.isCategory)) {
    return null;
  }
  final ruleName = hit.rule.displayName(zh: zh);
  final rawCat = firstHit.tag.rawTitle.isNotEmpty
      ? firstHit.tag.rawTitle
      : firstHit.tag.title;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Flexible(
        child: Text(
          l10n.fav_rule_reason_only(ruleName),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const SizedBox(width: 6),
      FavCategoryBadge.mini(
        category: rawCat,
        negated: firstHit.condition.negated,
      ),
    ],
  );
}

/// Shows a Liquid Glass floating feedback banner at the bottom of the screen
/// explaining which rule matched (or offering a post-pick action) while
/// staying strictly inside a single unobstructed Duo pane.
void showFavRuleFeedbackBanner({
  BuildContext? context,
  required String favcat,
  required String title,
  String? subtitle,
  Widget? subtitleWidget,
  String? secondaryNote,
  IconData? leadingIcon,
  Color? leadingColor,
  List<FavRuleBannerAction> actions = const <FavRuleBannerAction>[],
  VoidCallback? onExplicitClose,
  Duration duration = const Duration(milliseconds: 4500),
  VoidCallback? onDismiss,
}) {
  dismissFavRuleFeedbackBanner();

  final targetContext = context ?? Get.overlayContext ?? Get.context;
  if (targetContext == null) {
    onDismiss?.call();
    return;
  }
  final overlay = _resolveRootOverlay(targetContext);
  if (overlay == null) {
    onDismiss?.call();
    return;
  }

  Rect? preferredAnchor;
  var initialDivisionRects = const <Rect>[];
  if (targetContext.mounted && overlay.context.mounted) {
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    final targetBox = targetContext.findRenderObject() as RenderBox?;
    final overlaySize = MediaQuery.sizeOf(overlay.context);
    initialDivisionRects = <Rect>[
      ...resolvePopupDivisionRects(overlay.context, targetSize: overlaySize),
      ...resolvePopupDivisionRects(targetContext, targetSize: overlaySize),
    ];
    if (overlayBox != null &&
        overlayBox.hasSize &&
        targetBox != null &&
        targetBox.hasSize &&
        !targetBox.size.isEmpty &&
        ((targetBox.size.width - overlayBox.size.width).abs() > 4.0 ||
            (targetBox.size.height - overlayBox.size.height).abs() > 4.0)) {
      final topLeft =
          targetBox.localToGlobal(Offset.zero, ancestor: overlayBox);
      preferredAnchor = topLeft & targetBox.size;
    }
  }

  var inserted = false;
  var removed = false;
  late final OverlayEntry entry;

  void cleanup() {
    if (removed) {
      return;
    }
    removed = true;
    if (inserted) {
      inserted = false;
      entry.remove();
    }
    if (_activeBanner?.entry == entry) {
      _activeBanner = null;
    }
    onDismiss?.call();
  }

  entry = OverlayEntry(
    builder: (overlayContext) => _FavRuleFeedbackOverlay(
      favcat: favcat,
      title: title,
      subtitle: subtitle,
      subtitleWidget: subtitleWidget,
      secondaryNote: secondaryNote,
      leadingIcon: leadingIcon,
      leadingColor: leadingColor,
      actions: actions,
      onExplicitClose: onExplicitClose,
      duration: duration,
      preferredAnchor: preferredAnchor,
      initialDivisionRects: initialDivisionRects,
      onRemoved: cleanup,
    ),
  );

  overlay.insert(entry);
  inserted = true;
  _activeBanner = _ActiveBannerController(entry, cleanup);
}

/// Shows the two-step post-pick "记住" banner (Panel ②B) when the user manually
/// picks a favorite folder for an unmatched gallery whose canonical category is
/// not yet covered by an enabled pure-category rule and has not been dismissed.
///
/// Returns `true` when the banner was displayed, or `false` when skipped.
bool maybeShowRememberCategoryBanner({
  BuildContext? context,
  required FavRuleService ruleService,
  required String? rawCategory,
  required String chosenFavcat,
  String? chosenFavTitle,
}) {
  final canonical = canonicalizeFavRuleCategory(rawCategory);
  if (canonical == null || chosenFavcat.isEmpty) {
    return false;
  }
  if (ruleService.hasEnabledPureCategoryRuleFor(canonical)) {
    return false;
  }
  if (ruleService.isRememberComboDismissed(canonical, chosenFavcat)) {
    return false;
  }

  final targetContext = context ?? Get.overlayContext ?? Get.context;
  if (targetContext == null || !targetContext.mounted) {
    return false;
  }
  final overlay = _resolveRootOverlay(targetContext);
  if (overlay == null) {
    return false;
  }

  final locContext =
      overlay.context.mounted ? overlay.context : targetContext;
  final trimmedTitle = chosenFavTitle?.trim() ?? '';
  final folderName = trimmedTitle.isNotEmpty
      ? trimmedTitle
      : ruleService.favTitleFor(chosenFavcat);
  final l10n = L10n.of(locContext);
  final zh = Localizations.localeOf(locContext).languageCode == 'zh';

  showFavRuleFeedbackBanner(
    context: targetContext,
    favcat: chosenFavcat,
    title: l10n.fav_rule_saved_to_folder(folderName),
    subtitleWidget: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(zh ? '以后 ' : 'Save future '),
        FavCategoryBadge.mini(category: canonical),
        Flexible(
          child: Text(
            zh ? ' 也收进这里？' : ' here too?',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
    actions: <FavRuleBannerAction>[
      FavRuleBannerAction(
        label: l10n.fav_rule_remember_action,
        isPrimary: true,
        onPressed: () {
          unawaited(
            _createRememberedCategoryRule(
              context: context,
              ruleService: ruleService,
              canonical: canonical,
              chosenFavcat: chosenFavcat,
              folderName: folderName,
            ),
          );
        },
      ),
    ],
    onExplicitClose: () => unawaited(
      ruleService.dismissRememberCombo(canonical, chosenFavcat),
    ),
  );
  return true;
}

Future<void> _createRememberedCategoryRule({
  BuildContext? context,
  required FavRuleService ruleService,
  required String canonical,
  required String chosenFavcat,
  required String folderName,
}) async {
  final restoreDisabledOnUndo =
      !ruleService.enabled && ruleService.rules.isEmpty;
  final created = await ruleService.addRule(
    FavRule(
      id: '',
      name: '',
      enabled: true,
      match: FavRuleMatch.any,
      conditions: <FavRuleCondition>[
        FavRuleCondition.category(<String>[canonical]),
      ],
      favcat: chosenFavcat,
    ),
  );
  final rawCtx = (context != null && context.mounted)
      ? context
      : (Get.overlayContext ?? Get.context);
  if (rawCtx == null || !rawCtx.mounted) {
    return;
  }
  final overlay = _resolveRootOverlay(rawCtx);
  final ctx = (overlay != null && overlay.context.mounted)
      ? overlay.context
      : rawCtx;
  final l10n = L10n.of(ctx);
  final zh = Localizations.localeOf(ctx).languageCode == 'zh';

  var undoConsumed = false;
  showFavRuleFeedbackBanner(
    context: ctx,
    leadingColor: EhPalette.accent.resolveFrom(ctx),
    leadingIcon: CupertinoIcons.checkmark_alt,
    favcat: chosenFavcat,
    title: l10n.fav_rule_remember_created_title,
    subtitleWidget: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FavCategoryBadge.mini(category: canonical),
        Flexible(
          child: Text(
            zh ? ' 收进「$folderName」' : ' → "$folderName"',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
    actions: <FavRuleBannerAction>[
      FavRuleBannerAction(
        label: l10n.fav_rule_undo,
        isPrimary: false,
        onPressed: () {
          if (undoConsumed) {
            return;
          }
          undoConsumed = true;
          unawaited(
            ruleService.undoAddedRule(
              created.id,
              restoreDisabled: restoreDisabledOnUndo,
            ),
          );
        },
      ),
    ],
  );
}

class _FavRuleFeedbackOverlay extends StatefulWidget {
  const _FavRuleFeedbackOverlay({
    required this.favcat,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.secondaryNote,
    this.leadingIcon,
    this.leadingColor,
    required this.actions,
    this.onExplicitClose,
    required this.duration,
    this.preferredAnchor,
    this.initialDivisionRects = const <Rect>[],
    required this.onRemoved,
  });

  final String favcat;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final String? secondaryNote;
  final IconData? leadingIcon;
  final Color? leadingColor;
  final List<FavRuleBannerAction> actions;
  final VoidCallback? onExplicitClose;
  final Duration duration;
  final Rect? preferredAnchor;
  final List<Rect> initialDivisionRects;
  final VoidCallback onRemoved;

  @override
  State<_FavRuleFeedbackOverlay> createState() =>
      _FavRuleFeedbackOverlayState();
}

class _FavRuleFeedbackOverlayState extends State<_FavRuleFeedbackOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _opacity = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));

    _anim.forward();
    _timer = Timer(widget.duration, _close);
  }

  Future<void> _close() async {
    if (_closing) {
      return;
    }
    _closing = true;
    _timer?.cancel();
    if (mounted) {
      try {
        await _anim.reverse();
      } catch (_) {
        // Overlay entry may be force-removed before reverse animation finishes.
      }
    }
    widget.onRemoved();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Get.isRegistered<AdaptiveEnvironmentService>()) {
      return Obx(() {
        Get.find<AdaptiveEnvironmentService>().snapshot.value;
        return _buildBanner(context);
      });
    }
    return _buildBanner(context);
  }

  Widget _buildBanner(BuildContext context) {
    final palette = ehTheme.palette;
    final favColor = CupertinoDynamicColor.resolve(
      ThemeColors.favColorFor(widget.favcat),
      context,
    );
    final accent = EhPalette.accent.resolveFrom(context);
    final onAccent = EhPalette.onAccent.resolveFrom(context);
    final fill = palette.fill.resolveFrom(context);
    final text1 = palette.text1.resolveFrom(context);
    final text2 = palette.text2.resolveFrom(context);
    final text3 = palette.text3.resolveFrom(context);
    final resolvedLeadingColor = widget.leadingColor == null
        ? null
        : CupertinoDynamicColor.resolve(widget.leadingColor!, context);
    final size = MediaQuery.sizeOf(context);
    final paneBounds = resolveSinglePaneSafeBounds(
      context,
      preferredAnchor: widget.preferredAnchor,
      extraDivisionRects: widget.initialDivisionRects,
    );
    final leftInset = paneBounds.left + 12.0;
    final rightInset = math.max(0.0, size.width - paneBounds.right) + 12.0;
    final bottomOffset = math.max(0.0, size.height - paneBounds.bottom) + 16.0;
    final hasTrailing =
        widget.actions.isNotEmpty || widget.onExplicitClose != null;

    return Positioned(
      left: leftInset,
      right: rightInset,
      bottom: bottomOffset,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _opacity,
              child: GestureDetector(
                onVerticalDragEnd: (details) {
                  if ((details.primaryVelocity ?? 0) > 120) {
                    _close();
                  }
                },
                child: buildFavRuleGlassOrCardSurface(
                  context: context,
                  borderRadius: const BorderRadius.all(Radius.circular(24)),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      11,
                      widget.onExplicitClose != null ? 8 : 12,
                      11,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: resolvedLeadingColor ??
                                favColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: EhSvgIcon(
                            widget.leadingIcon ??
                                (resolvedLeadingColor != null
                                    ? CupertinoIcons.checkmark_alt
                                    : CupertinoIcons.heart_fill),
                            size: 18,
                            color: resolvedLeadingColor != null
                                ? onAccent
                                : favColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: text1,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              if (widget.subtitleWidget != null) ...<Widget>[
                                const SizedBox(height: 2),
                                DefaultTextStyle(
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: text2,
                                    decoration: TextDecoration.none,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  child: widget.subtitleWidget!,
                                ),
                              ] else if (widget.subtitle != null &&
                                  widget.subtitle!.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 2),
                                Text(
                                  widget.subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: text2,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                              if (widget.secondaryNote != null &&
                                  widget.secondaryNote!.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 2),
                                Text(
                                  widget.secondaryNote!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: text3,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (hasTrailing) ...<Widget>[
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              for (var i = 0;
                                  i < widget.actions.length;
                                  i++) ...<Widget>[
                                if (i > 0) const SizedBox(width: 6),
                                Semantics(
                                  button: true,
                                  label: widget.actions[i].label,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      if (_closing) {
                                        return;
                                      }
                                      final cb = widget.actions[i].onPressed;
                                      _close();
                                      cb();
                                    },
                                    child: Container(
                                      height: 36,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: widget.actions[i].isPrimary
                                            ? accent
                                            : fill,
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        widget.actions[i].label,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight:
                                              widget.actions[i].isPrimary
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                          color: widget.actions[i].isPrimary
                                              ? onAccent
                                              : text1,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              if (widget.onExplicitClose != null) ...<Widget>[
                                if (widget.actions.isNotEmpty)
                                  const SizedBox(width: 2),
                                Semantics(
                                  button: true,
                                  label: L10n.of(context).cancel,
                                  child: GestureDetector(
                                    key: kFavRuleBannerCloseButtonKey,
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      if (_closing) {
                                        return;
                                      }
                                      final cb = widget.onExplicitClose;
                                      cb?.call();
                                      _close();
                                    },
                                    child: SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: Center(
                                        child: Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: fill,
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: EhSvgIcon(
                                            CupertinoIcons.xmark,
                                            size: 12,
                                            color: text3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
