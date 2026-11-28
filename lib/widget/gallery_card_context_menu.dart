import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/common/service/fav_rule_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/fav_rule.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:eros_fe/widget/fav_rule_safe_area.dart';
import 'package:eros_fe/widget/fav_rule_widgets.dart';
import 'package:eros_fe/widget/image/eh_network_image.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';

const Key kGalleryContextMenuBackdropKey =
    ValueKey<String>('gallery-context-menu-backdrop');
const Key kGalleryContextMenuLiftedCardKey =
    ValueKey<String>('gallery-context-menu-lifted-card');
const Key kGalleryContextMenuSurfaceKey =
    ValueKey<String>('gallery-context-menu-surface');
const Key kGalleryContextMenuQuickBarKey =
    ValueKey<String>('gallery-context-menu-quick-bar');
const Key kGalleryContextMenuRuleBannerKey =
    ValueKey<String>('gallery-context-menu-rule-banner');
const Key kGalleryContextMenuCreateRuleRowKey =
    ValueKey<String>('gallery-context-menu-create-rule-row');

/// Exposes a gallery card's live press-compression scale (`0.97` while held)
/// so [showGalleryCardContextMenu] can launch the spring lift seamlessly from
/// the exact compressed bounds without any visual snap.
class GalleryCardPressScope extends InheritedWidget {
  const GalleryCardPressScope({
    super.key,
    required this.scale,
    required super.child,
  });

  final double scale;

  static double scaleOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<GalleryCardPressScope>()?.scale ??
      1.0;

  @override
  bool updateShouldNotify(GalleryCardPressScope oldWidget) =>
      scale != oldWidget.scale;
}

/// Shared iOS 26 tactile hold-anticipation wrapper for gallery cards.
///
/// Compresses the card smoothly to `0.97` while pressed, prewarms the Taptic
/// Engine on touch-down, and preserves the compressed scale at the moment
/// [onLongPress] fires so the floating context menu springs outward from the
/// held tension without a discontinuity.
class GalleryCardPressFeedback extends StatefulWidget {
  const GalleryCardPressFeedback({
    super.key,
    required this.child,
    this.onTap,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.onLongPress,
  });

  final Widget child;
  final VoidCallback? onTap;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final VoidCallback? onTapCancel;
  final ValueChanged<BuildContext>? onLongPress;

  @override
  State<GalleryCardPressFeedback> createState() =>
      _GalleryCardPressFeedbackState();
}

class _GalleryCardPressFeedbackState extends State<GalleryCardPressFeedback> {
  static const Cubic _kReleaseSpring = Cubic(0.20, 1.15, 0.36, 1.0);
  bool _pressed = false;
  bool _previewTickSent = false;

  void _setPressed(bool value) {
    if (!value) {
      _previewTickSent = false;
    }
    if (_pressed != value && mounted) {
      setState(() => _pressed = value);
    }
  }

  void _handleScaleEnd() {
    if (_pressed && !_previewTickSent && widget.onLongPress != null) {
      _previewTickSent = true;
      unawaited(vibrateUtil.contextMenuPreviewTick());
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final activeScale = _pressed && !reduceMotion ? 0.97 : 1.0;

    return GalleryCardPressScope(
      scale: activeScale,
      child: Builder(
        builder: (scopedContext) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            _previewTickSent = false;
            _setPressed(true);
            unawaited(vibrateUtil.prepareHaptics());
            widget.onTapDown?.call(details);
          },
          onTapUp: (details) {
            _setPressed(false);
            widget.onTapUp?.call(details);
          },
          onTapCancel: () {
            _setPressed(false);
            widget.onTapCancel?.call();
          },
          onTap: widget.onTap,
          onLongPress: widget.onLongPress == null
              ? null
              : () {
                  widget.onLongPress!(scopedContext);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _setPressed(false);
                  });
                },
          child: AnimatedScale(
            scale: activeScale,
            duration: Duration(milliseconds: _pressed ? 135 : 240),
            curve: _pressed ? Curves.easeOutCubic : _kReleaseSpring,
            onEnd: _handleScaleEnd,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Async state for evaluating rule-favorite match inside a list menu.
enum RuleMenuEvalState {
  idle,
  loading,
  hit,
  miss,
  error,
}

@immutable
class RuleMenuEvalSnapshot {
  const RuleMenuEvalSnapshot({
    required this.state,
    this.evalResult,
  });

  const RuleMenuEvalSnapshot.idle() : this(state: RuleMenuEvalState.idle);
  const RuleMenuEvalSnapshot.loading() : this(state: RuleMenuEvalState.loading);
  const RuleMenuEvalSnapshot.miss() : this(state: RuleMenuEvalState.miss);
  const RuleMenuEvalSnapshot.error() : this(state: RuleMenuEvalState.error);
  const RuleMenuEvalSnapshot.hit(FavRuleEvalResult result)
      : this(state: RuleMenuEvalState.hit, evalResult: result);

  final RuleMenuEvalState state;
  final FavRuleEvalResult? evalResult;
}

/// Compact top-bar quick action cell (`[icon + short label]`) inside the
/// iOS 26 Liquid Glass context menu.
@immutable
class GalleryContextQuickAction {
  const GalleryContextQuickAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.accentColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? accentColor;
}

/// Leading-icon or custom-swatch action row (`[leading/icon]  [15pt label]`)
/// inside the iOS 26 Liquid Glass context menu.
@immutable
class GalleryContextMenuEntry {
  const GalleryContextMenuEntry({
    required this.label,
    this.icon = CupertinoIcons.circle,
    this.leading,
    required this.onPressed,
    this.trailing,
    this.showChevron = false,
    this.destructive = false,
    this.sectionBreakBefore = false,
  });

  final String label;
  final IconData icon;
  final Widget? leading;
  final VoidCallback onPressed;
  final String? trailing;
  final bool showChevron;
  final bool destructive;
  final bool sectionBreakBefore;
}

/// Formats the localized rule-creation menu or action-sheet label for [provider]:
/// `按「Non-H」新建规则` when [provider.category] maps to a canonical E-Hentai
/// category, or `用这个画廊新建规则` when no category is available.
String formatCreateRuleFromGalleryLabel(
  BuildContext context,
  GalleryProvider provider,
) {
  final l10n = L10n.of(context);
  final canonicalCat = canonicalizeFavRuleCategory(provider.category);
  if (canonicalCat != null) {
    return l10n.fav_rule_create_by_category(canonicalCat);
  }
  return l10n.fav_rule_create_from_gallery;
}

/// Dispose-safe [ValueNotifier] for async tag-rule evaluation while a menu is open.
class RuleMenuEvalController extends ValueNotifier<RuleMenuEvalSnapshot> {
  RuleMenuEvalController(super._value);

  bool _disposed = false;
  bool get isDisposed => _disposed;

  void setSnapshotSafely(RuleMenuEvalSnapshot next) {
    if (!_disposed) {
      value = next;
    }
  }

  @override
  void addListener(VoidCallback listener) {
    if (_disposed) {
      return;
    }
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    if (_disposed) {
      return;
    }
    super.removeListener(listener);
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    super.dispose();
  }
}

/// Evaluates rule matches for a gallery card and publishes updates to a
/// [RuleMenuEvalController] so both floating context menus and action sheets
/// can react without risking use-after-dispose when closed mid-fetch.
RuleMenuEvalController createRuleEvalNotifier(
  GalleryProvider provider,
) {
  if (!Get.isRegistered<FavRuleService>()) {
    return RuleMenuEvalController(const RuleMenuEvalSnapshot.idle());
  }
  final service = Get.find<FavRuleService>();
  if (!service.enabled || service.config.enabledRuleCount == 0) {
    return RuleMenuEvalController(const RuleMenuEvalSnapshot.idle());
  }

  if (!service.needsAsyncTagFetch(provider)) {
    final res = service.evaluateGallerySync(provider);
    return RuleMenuEvalController(
      res.isHit
          ? RuleMenuEvalSnapshot.hit(res)
          : const RuleMenuEvalSnapshot.miss(),
    );
  }

  final notifier = RuleMenuEvalController(
    const RuleMenuEvalSnapshot.loading(),
  );
  unawaited(() async {
    try {
      final res = await service.evaluateGalleryWithFetch(provider);
      notifier.setSnapshotSafely(
        res.isHit
            ? RuleMenuEvalSnapshot.hit(res)
            : const RuleMenuEvalSnapshot.miss(),
      );
    } catch (_) {
      notifier.setSnapshotSafely(const RuleMenuEvalSnapshot.error());
    }
  }());
  return notifier;
}

/// Builds the flat tinted rule-favorite strip shared by both the floating card
/// context menu and the bottom `EhActionSheet` (zero nested boxes).
Widget buildRuleFavMenuBanner({
  required BuildContext context,
  required RuleMenuEvalSnapshot snapshot,
  required bool isAlreadyFav,
  required String currentFavcat,
  required ValueChanged<FavRuleEvalResult> onApplyRule,
  bool insetPadding = true,
}) {
  final l10n = L10n.of(context);
  final zh = Localizations.localeOf(context).languageCode == 'zh';
  final palette = ehTheme.palette;
  final text2 = CupertinoDynamicColor.resolve(palette.text2, context);
  final text3 = CupertinoDynamicColor.resolve(palette.text3, context);
  final horizontalPad = insetPadding ? 16.0 : 18.0;

  if (snapshot.state == RuleMenuEvalState.loading) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: 12),
      child: Row(
        children: <Widget>[
          const SizedBox(
            width: 18,
            height: 18,
            child: Center(child: CupertinoActivityIndicator(radius: 8)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.fav_rule_matching_tags,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EhPopupTextStyles.body(context).copyWith(
                fontSize: 13.5,
                color: text2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  if (snapshot.state == RuleMenuEvalState.error) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: 12),
      child: Row(
        children: <Widget>[
          EhSvgIcon(
            CupertinoIcons.exclamationmark_circle,
            size: 18,
            color: text3,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.fav_rule_fetch_tags_failed,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EhPopupTextStyles.body(context).copyWith(
                fontSize: 13,
                color: text3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  final eval = snapshot.evalResult;
  final hit = eval?.primary;
  if (snapshot.state != RuleMenuEvalState.hit || eval == null || hit == null) {
    return const SizedBox.shrink();
  }

  final service = Get.find<FavRuleService>();
  final favcat = hit.rule.favcat;
  final favTitle = service.favTitleFor(favcat);
  final favColor = CupertinoDynamicColor.resolve(
    ThemeColors.favColorFor(favcat),
    context,
  );
  final text1 = CupertinoDynamicColor.resolve(palette.text1, context);

  final sameFolder = isAlreadyFav && currentFavcat == favcat;
  final keepExisting = isAlreadyFav &&
      !sameFolder &&
      service.config.existing == FavRuleExisting.keep;
  final currentTitle =
      currentFavcat.isNotEmpty ? service.favTitleFor(currentFavcat) : favTitle;
  final headline = sameFolder
      ? l10n.fav_rule_already_in_folder(favTitle)
      : keepExisting
          ? l10n.fav_rule_kept_in_folder(currentTitle)
          : isAlreadyFav
              ? l10n.fav_rule_move_to_folder(favTitle)
              : l10n.fav_rule_save_to_folder(favTitle);

  final firstHit = hit.conditionHits.firstOrNull;
  final primaryTag = hit.primaryTag;
  final tagText = primaryTag?.displayLabel() ?? '';
  final ruleTitle = hit.rule.displayName(zh: zh);
  final reasonOnlyText = l10n.fav_rule_reason_only(ruleTitle);
  final reason = tagText.isEmpty
      ? reasonOnlyText
      : l10n.fav_rule_reason_with_tag(ruleTitle, tagText);

  Widget? reasonWidget;
  if (firstHit != null &&
      (firstHit.condition.isCategory || firstHit.tag.isCategory)) {
    final rawCat = firstHit.tag.rawTitle.isNotEmpty
        ? firstHit.tag.rawTitle
        : firstHit.tag.title;
    final reasonStyle = EhPopupTextStyles.secondary(context).copyWith(
      fontSize: 11.5,
      color: text2,
    );
    reasonWidget = LayoutBuilder(
      builder: (context, constraints) {
        final badge = FavCategoryBadge.mini(
          category: rawCat,
          negated: firstHit.condition.negated,
        );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                reasonOnlyText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: reasonStyle,
              ),
            ),
            const SizedBox(width: 6),
            if (constraints.maxWidth < 76)
              Flexible(child: badge)
            else
              badge,
          ],
        );
      },
    );
  }

  return _RuleHitBannerStrip(
    key: kGalleryContextMenuRuleBannerKey,
    headline: headline,
    reason: reason,
    reasonWidget: reasonWidget,
    favColor: favColor,
    text1: text1,
    text2: text2,
    horizontalPadding: horizontalPad,
    onTap: () => onApplyRule(eval),
  );
}

class _RuleHitBannerStrip extends StatefulWidget {
  const _RuleHitBannerStrip({
    super.key,
    required this.headline,
    required this.reason,
    this.reasonWidget,
    required this.favColor,
    required this.text1,
    required this.text2,
    required this.horizontalPadding,
    required this.onTap,
  });

  final String headline;
  final String reason;
  final Widget? reasonWidget;
  final Color favColor;
  final Color text1;
  final Color text2;
  final double horizontalPadding;
  final VoidCallback onTap;

  @override
  State<_RuleHitBannerStrip> createState() => _RuleHitBannerStripState();
}

class _RuleHitBannerStripState extends State<_RuleHitBannerStrip> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final startAlpha = _pressed
        ? (dark ? 0.30 : 0.22)
        : (dark ? 0.22 : 0.15);
    final endAlpha = _pressed
        ? (dark ? 0.14 : 0.09)
        : (dark ? 0.08 : 0.04);
    final iconBadgeAlpha = dark ? 0.25 : 0.17;

    return Semantics(
      button: true,
      label: '${widget.headline}, ${widget.reason}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          _setPressed(true);
          unawaited(vibrateUtil.selection());
        },
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                widget.favColor.withValues(alpha: startAlpha),
                widget.favColor.withValues(alpha: endAlpha),
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.horizontalPadding - 2,
              vertical: 11,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: widget.favColor.withValues(alpha: iconBadgeAlpha),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: EhSvgIcon(
                    CupertinoIcons.heart_fill,
                    size: 15,
                    color: widget.favColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EhPopupTextStyles.action(context).copyWith(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: widget.text1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (widget.reasonWidget != null)
                        widget.reasonWidget!
                      else
                        Text(
                          widget.reason,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: EhPopupTextStyles.secondary(context).copyWith(
                            fontSize: 11.5,
                            color: widget.text2,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

({RenderRepaintBoundary? boundary, RenderBox? box}) _resolveCardRenderTargets(
  BuildContext cardContext,
) {
  final rootObj = cardContext.findRenderObject();
  if (rootObj is! RenderBox || !rootObj.hasSize || rootObj.size.isEmpty) {
    return (boundary: null, box: null);
  }
  if (rootObj is RenderRepaintBoundary) {
    return (boundary: rootObj, box: rootObj);
  }

  final minW = rootObj.size.width * 0.6;
  final minH = rootObj.size.height * 0.5;
  RenderRepaintBoundary? foundDescendant;
  final queue = <RenderObject>[rootObj];
  var head = 0;
  while (head < queue.length && queue.length < 64) {
    final current = queue[head++];
    current.visitChildren((child) {
      if (foundDescendant != null) {
        return;
      }
      if (child is RenderRepaintBoundary &&
          child.hasSize &&
          child.size.width >= minW &&
          child.size.height >= minH) {
        foundDescendant = child;
        return;
      }
      queue.add(child);
    });
    if (foundDescendant != null) {
      return (boundary: foundDescendant, box: foundDescendant);
    }
  }

  RenderObject? anc = rootObj.parent;
  for (var depth = 0; depth < 3 && anc != null; depth++) {
    if (anc is RenderRepaintBoundary &&
        anc.hasSize &&
        (anc.size.width - rootObj.size.width).abs() <= 4.0 &&
        (anc.size.height - rootObj.size.height).abs() <= 4.0) {
      return (boundary: anc, box: anc);
    }
    anc = anc.parent;
  }

  return (boundary: null, box: rootObj);
}

/// Shows the iOS 26 in-place lifted real card + Liquid Glass context menu
/// anchored below, above, or beside the pressed gallery card (prototype ⑥ v3).
Future<void> showGalleryCardContextMenu({
  required BuildContext cardContext,
  required GalleryProvider provider,
  required bool isAlreadyFav,
  required String currentFavcat,
  required ValueNotifier<RuleMenuEvalSnapshot> evalNotifier,
  required ValueChanged<FavRuleEvalResult> onApplyRule,
  required List<GalleryContextMenuEntry> entries,
  List<GalleryContextQuickAction> quickActions =
      const <GalleryContextQuickAction>[],
  VoidCallback? onCreateRuleFromGallery,
  @visibleForTesting ui.Image? debugCapturedImage,
  @visibleForTesting Future<ui.Image?> Function()? debugCaptureImage,
}) async {
  // Capture press-compression scale, render targets, and any card-scoped safe
  // geometry synchronously BEFORE awaiting `toImage`, because `cardContext`
  // may reset its press state or unmount across an async frame boundary.
  final sampledPressScale = cardContext.mounted
      ? GalleryCardPressScope.scaleOf(cardContext)
      : 1.0;
  final targets = cardContext.mounted
      ? _resolveCardRenderTargets(cardContext)
      : (boundary: null, box: null);
  final overlayContext = Get.overlayContext ?? cardContext;
  if (!overlayContext.mounted) {
    return;
  }
  final overlayBox = overlayContext.findRenderObject() as RenderBox?;
  final screenSize = MediaQuery.sizeOf(overlayContext);
  final overlaySafe = resolvePopupSafeInsets(overlayContext);
  final cardSameWindowSpace = cardContext.mounted &&
      (MediaQuery.sizeOf(cardContext).width - screenSize.width).abs() < 2.0 &&
      (MediaQuery.sizeOf(cardContext).height - screenSize.height).abs() < 2.0;
  final cardSafe = cardSameWindowSpace
      ? resolvePopupSafeInsets(cardContext)
      : EdgeInsets.zero;
  final safePadding = EdgeInsets.fromLTRB(
    math.max(overlaySafe.left, cardSafe.left),
    math.max(overlaySafe.top, cardSafe.top),
    math.max(overlaySafe.right, cardSafe.right),
    math.max(overlaySafe.bottom, cardSafe.bottom),
  );
  final initialDivisionRects = <Rect>[
    ...resolvePopupDivisionRects(overlayContext, targetSize: screenSize),
    if (cardContext.mounted)
      ...resolvePopupDivisionRects(cardContext, targetSize: screenSize),
  ];

  Rect anchorRect;
  final targetBox = targets.box;
  if (targetBox != null && targetBox.hasSize && !targetBox.size.isEmpty) {
    final center = targetBox.localToGlobal(
      targetBox.size.center(Offset.zero),
      ancestor: overlayBox,
    );
    anchorRect = Rect.fromCenter(
      center: center,
      width: targetBox.size.width,
      height: targetBox.size.height,
    );
  } else {
    anchorRect = Rect.fromCenter(
      center: Offset(screenSize.width / 2, screenSize.height * 0.35),
      width: math.min(240, screenSize.width - 48),
      height: 180,
    );
  }

  ui.Image? capturedImage = debugCapturedImage;
  final boundary = targets.boundary;
  if (capturedImage == null && debugCaptureImage != null) {
    try {
      capturedImage = await debugCaptureImage();
    } catch (_) {
      capturedImage = null;
    }
  } else if (capturedImage == null &&
      boundary != null &&
      boundary.attached &&
      !boundary.debugNeedsPaint &&
      boundary.size.width > 0 &&
      boundary.size.height > 0 &&
      WidgetsBinding.instance is WidgetsFlutterBinding) {
    try {
      final dpr = MediaQuery.devicePixelRatioOf(overlayContext)
          .clamp(1.0, 3.0)
          .toDouble();
      capturedImage = await boundary.toImage(pixelRatio: dpr);
    } catch (_) {
      capturedImage = null;
    }
  }

  if (!overlayContext.mounted) {
    if (debugCapturedImage == null) {
      capturedImage?.dispose();
    }
    return;
  }

  final ownsImage = debugCapturedImage == null && capturedImage != null;
  var transferredToOverlay = false;
  final reduceMotion = MediaQuery.disableAnimationsOf(overlayContext);
  final initialCardScale = reduceMotion
      ? 1.0
      : sampledPressScale.clamp(0.92, 1.0).toDouble();

  try {
    await Navigator.of(overlayContext, rootNavigator: true).push<void>(
      _GalleryContextMenuRoute(
        barrierLabel: L10n.of(overlayContext).cancel,
        reduceMotion: reduceMotion,
        builder: (dialogContext, animation) {
          return _FloatingGalleryContextMenuOverlay(
            animation: animation,
            anchorRect: anchorRect,
            initialCardScale: initialCardScale,
            reduceMotion: reduceMotion,
            safePadding: safePadding,
            initialDivisionRects: initialDivisionRects,
            provider: provider,
            capturedImage: capturedImage,
            disposeImageOnClose: ownsImage,
            onImageAdopted: () => transferredToOverlay = true,
            isAlreadyFav: isAlreadyFav,
            currentFavcat: currentFavcat,
            evalNotifier: evalNotifier,
            onApplyRule: (eval) {
              Navigator.of(dialogContext).pop();
              onApplyRule(eval);
            },
            onCreateRuleFromGallery: onCreateRuleFromGallery == null
                ? null
                : () {
                    Navigator.of(dialogContext).pop();
                    onCreateRuleFromGallery();
                  },
            quickActions: quickActions
                .map(
                  (action) => GalleryContextQuickAction(
                    label: action.label,
                    icon: action.icon,
                    accentColor: action.accentColor,
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      action.onPressed();
                    },
                  ),
                )
                .toList(),
            entries: entries
                .map(
                  (entry) => GalleryContextMenuEntry(
                    label: entry.label,
                    icon: entry.icon,
                    leading: entry.leading,
                    trailing: entry.trailing,
                    showChevron: entry.showChevron,
                    destructive: entry.destructive,
                    sectionBreakBefore: entry.sectionBreakBefore,
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      entry.onPressed();
                    },
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  } finally {
    if (ownsImage && !transferredToOverlay) {
      capturedImage.dispose();
    }
  }
}

class _GalleryContextMenuRoute extends PopupRoute<void> {
  _GalleryContextMenuRoute({
    required this.barrierLabel,
    required this.reduceMotion,
    required this.builder,
  });

  @override
  final String barrierLabel;

  final bool reduceMotion;
  final Widget Function(BuildContext context, Animation<double> animation)
      builder;

  @override
  bool get barrierDismissible => true;

  @override
  Color? get barrierColor => const Color(0x00000000);

  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 460);

  @override
  Duration get reverseTransitionDuration =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 250);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context, animation);
  }
}

/// Evaluates an underdamped `flutter/physics.dart` [SpringSimulation] across
/// normalized progress `0.0..1.0`, blending the final settle tail cleanly into
/// bit-exact `1.0` so layout bounds match resting metrics with zero drift.
class _BoundedSpring {
  _BoundedSpring({
    required double mass,
    required double stiffness,
    required double damping,
    double initialVelocity = 0.0,
    required this.durationSeconds,
  }) : _sim = SpringSimulation(
          SpringDescription(
            mass: mass,
            stiffness: stiffness,
            damping: damping,
          ),
          0.0,
          1.0,
          initialVelocity,
        );

  final SpringSimulation _sim;
  final double durationSeconds;

  double transform(double u) {
    if (u <= 0.0) {
      return 0.0;
    }
    if (u >= 1.0) {
      return 1.0;
    }
    final raw = _sim.x(u * durationSeconds);
    if (u > 0.84) {
      final tail = (u - 0.84) / 0.16;
      final blend = tail * tail * (3.0 - 2.0 * tail);
      return ui.lerpDouble(raw, 1.0, blend)!;
    }
    return raw;
  }
}

@immutable
class _ContextMenuLayout {
  const _ContextMenuLayout({
    required this.liftedRect,
    required this.menuLeft,
    required this.menuWidth,
    required this.menuMaxHeight,
    required this.popAlignment,
    this.showLiftedCard = true,
    this.compactMenu = false,
    this.menuTop,
    this.menuBottom,
  });

  final Rect liftedRect;
  final double menuLeft;
  final double menuWidth;
  final double menuMaxHeight;
  final Alignment popAlignment;
  final bool showLiftedCard;
  final bool compactMenu;
  final double? menuTop;
  final double? menuBottom;
}

_ContextMenuLayout _computeContextMenuLayout({
  required Size screen,
  required Rect safeBounds,
  required Rect anchorRect,
  required bool isRtl,
  required bool hasRuleSlot,
  required bool hasQuickBar,
  required List<GalleryContextMenuEntry> entries,
  bool hasCreateRuleRow = false,
}) {
  final rawSafeLeft = safeBounds.left.clamp(0.0, screen.width).toDouble();
  final rawSafeRight =
      safeBounds.right.clamp(rawSafeLeft, screen.width).toDouble();
  final rawSafeWidth = rawSafeRight - rawSafeLeft;
  final hMargin =
      rawSafeWidth >= 120.0 ? 12.0 : math.max(0.0, rawSafeWidth * 0.08);
  final minLeft = rawSafeLeft + hMargin;
  final maxRight = math.max(minLeft, rawSafeRight - hMargin);
  final availWidth = math.max(1.0, maxRight - minLeft);

  final rawSafeTop = safeBounds.top.clamp(0.0, screen.height).toDouble();
  final rawSafeBottom =
      safeBounds.bottom.clamp(rawSafeTop, screen.height).toDouble();
  final rawSafeHeight = rawSafeBottom - rawSafeTop;
  final vMargin =
      rawSafeHeight >= 120.0 ? 12.0 : math.max(0.0, rawSafeHeight * 0.08);
  final minTop = rawSafeTop + vMargin;
  final maxBottom = math.max(minTop, rawSafeBottom - vMargin);
  final safeHeight = math.max(1.0, maxBottom - minTop);

  final menuWidth = math.min(252.0, availWidth);
  final compactMenu = menuWidth < 176.0;
  final sectionBreaks = entries.where((e) => e.sectionBreakBefore).length;
  final extraCreateRowHeight = hasCreateRuleRow
      ? (44.5 + ((entries.isNotEmpty || hasQuickBar) ? 6.0 : 0.0))
      : 0.0;
  final estimatedMenuHeight = (hasRuleSlot ? 76.0 : 0.0) +
      (hasQuickBar ? (compactMenu ? 46.5 : 62.5) : 0.0) +
      entries.length * 44.5 +
      sectionBreaks * 5.5 +
      extraCreateRowHeight +
      4.0;

  // Compact menu-only fallback when safe width or safe height cannot fit both
  // a lifted card preview and an interactive menu without intruding into rails.
  if (availWidth < 160.0 || safeHeight < 240.0) {
    final desiredMenuH = math.min(estimatedMenuHeight, safeHeight);
    final menuLeft = (anchorRect.center.dx - menuWidth / 2)
        .clamp(minLeft, math.max(minLeft, maxRight - menuWidth))
        .toDouble();
    final menuTop = (anchorRect.center.dy - desiredMenuH / 2)
        .clamp(minTop, math.max(minTop, maxBottom - desiredMenuH))
        .toDouble();
    final menuMaxHeight = math.max(1.0, maxBottom - menuTop);
    return _ContextMenuLayout(
      liftedRect: anchorRect,
      menuLeft: menuLeft,
      menuWidth: menuWidth,
      menuMaxHeight: menuMaxHeight,
      menuTop: menuTop,
      showLiftedCard: false,
      compactMenu: compactMenu,
      popAlignment: Alignment.center,
    );
  }

  final anchorW = math.max(1.0, anchorRect.width);
  final anchorH = math.max(1.0, anchorRect.height);
  const liftScale = 1.035;
  const verticalGap = 10.0;
  const sideGap = 12.0;

  final sideScale = math.min(
    liftScale,
    math.min(availWidth / anchorW, (0.86 * safeHeight) / anchorH),
  );
  final sideCardW = anchorW * sideScale;
  final sideCardH = anchorH * sideScale;
  final sideNatLeft = (anchorRect.center.dx - sideCardW / 2)
      .clamp(minLeft, math.max(minLeft, maxRight - sideCardW))
      .toDouble();
  final sideNatTop = (anchorRect.center.dy - sideCardH / 2)
      .clamp(minTop, math.max(minTop, maxBottom - sideCardH))
      .toDouble();

  final naturalBelow = maxBottom - (sideNatTop + sideCardH);
  final naturalAbove = sideNatTop - minTop;
  final verticalTight = naturalBelow < estimatedMenuHeight + verticalGap &&
      naturalAbove < estimatedMenuHeight + verticalGap;

  final rightSpaceAtNat = maxRight - (sideNatLeft + sideCardW);
  final leftSpaceAtNat = sideNatLeft - minLeft;
  final fitsRightDirectly = rightSpaceAtNat >= menuWidth + 14.0;
  final fitsLeftDirectly = leftSpaceAtNat >= menuWidth + 14.0;
  final fitsBesideInSafe = availWidth >= sideCardW + menuWidth + 14.0;

  if (verticalTight &&
      (fitsRightDirectly || fitsLeftDirectly || fitsBesideInSafe)) {
    final bool menuOnRight;
    if (fitsRightDirectly) {
      menuOnRight = true;
    } else if (fitsLeftDirectly) {
      menuOnRight = false;
    } else {
      menuOnRight = anchorRect.center.dx <= (minLeft + maxRight) / 2;
    }

    final double cardLeft;
    final double menuLeft;
    if (menuOnRight) {
      cardLeft = math
          .min(sideNatLeft, maxRight - menuWidth - sideGap - sideCardW)
          .clamp(minLeft, math.max(minLeft, maxRight - sideCardW))
          .toDouble();
      menuLeft = (cardLeft + sideCardW + sideGap)
          .clamp(minLeft, math.max(minLeft, maxRight - menuWidth))
          .toDouble();
    } else {
      cardLeft = math
          .max(sideNatLeft, minLeft + menuWidth + sideGap)
          .clamp(minLeft, math.max(minLeft, maxRight - sideCardW))
          .toDouble();
      menuLeft = (cardLeft - sideGap - menuWidth)
          .clamp(minLeft, math.max(minLeft, maxRight - menuWidth))
          .toDouble();
    }

    final cardTop = sideNatTop;
    final desiredMenuH = math.min(estimatedMenuHeight, safeHeight);
    final menuTop = cardTop
        .clamp(minTop, math.max(minTop, maxBottom - desiredMenuH))
        .toDouble();
    final menuMaxHeight = math.max(1.0, maxBottom - menuTop);

    return _ContextMenuLayout(
      liftedRect: Rect.fromLTWH(cardLeft, cardTop, sideCardW, sideCardH),
      menuLeft: menuLeft,
      menuWidth: menuWidth,
      menuMaxHeight: menuMaxHeight,
      menuTop: menuTop,
      compactMenu: compactMenu,
      popAlignment: menuOnRight ? Alignment.topLeft : Alignment.topRight,
    );
  }

  final stackScale = math.min(
    liftScale,
    math.min(availWidth / anchorW, (0.62 * safeHeight) / anchorH),
  );
  final stackCardW = anchorW * stackScale;
  final stackCardH = anchorH * stackScale;
  final cardLeft = (anchorRect.center.dx - stackCardW / 2)
      .clamp(minLeft, math.max(minLeft, maxRight - stackCardW))
      .toDouble();
  final stackNatTop = (anchorRect.center.dy - stackCardH / 2)
      .clamp(minTop, math.max(minTop, maxBottom - stackCardH))
      .toDouble();

  final preferredMenuLeft =
      isRtl ? (cardLeft + stackCardW - menuWidth) : cardLeft;
  final menuLeft = preferredMenuLeft
      .clamp(minLeft, math.max(minLeft, maxRight - menuWidth))
      .toDouble();

  final belowAtNat = maxBottom - (stackNatTop + stackCardH);
  final aboveAtNat = stackNatTop - minTop;
  final menuBelow =
      belowAtNat >= estimatedMenuHeight + verticalGap || belowAtNat >= aboveAtNat;

  final double cardTop;
  double? menuTop;
  double? menuBottom;
  final double menuMaxHeight;
  final availStackMenuSpace =
      math.max(80.0, safeHeight - stackCardH - verticalGap);

  if (menuBelow) {
    if (belowAtNat >= estimatedMenuHeight + verticalGap) {
      cardTop = stackNatTop;
    } else {
      final targetMenuH = math.min(estimatedMenuHeight, availStackMenuSpace);
      cardTop = (maxBottom - targetMenuH - verticalGap - stackCardH)
          .clamp(minTop, math.max(minTop, maxBottom - stackCardH))
          .toDouble();
    }
    menuTop = math.min(maxBottom, cardTop + stackCardH + verticalGap);
    menuMaxHeight = math.max(1.0, maxBottom - menuTop);
  } else {
    if (aboveAtNat >= estimatedMenuHeight + verticalGap) {
      cardTop = stackNatTop;
    } else {
      final targetMenuH = math.min(estimatedMenuHeight, availStackMenuSpace);
      cardTop = (minTop + targetMenuH + verticalGap)
          .clamp(minTop, math.max(minTop, maxBottom - stackCardH))
          .toDouble();
    }
    final menuBottomEdge = math.max(minTop, cardTop - verticalGap);
    menuBottom = screen.height - menuBottomEdge;
    menuMaxHeight = math.max(1.0, menuBottomEdge - minTop);
  }

  final alignX = (((cardLeft + stackCardW * 0.35 - menuLeft) /
              math.max(1.0, menuWidth)) *
          2.0 -
      1.0)
      .clamp(-0.85, 0.85)
      .toDouble();

  return _ContextMenuLayout(
    liftedRect: Rect.fromLTWH(cardLeft, cardTop, stackCardW, stackCardH),
    menuLeft: menuLeft,
    menuWidth: menuWidth,
    menuMaxHeight: menuMaxHeight,
    menuTop: menuTop,
    menuBottom: menuBottom,
    compactMenu: compactMenu,
    popAlignment: Alignment(alignX, menuBelow ? -1.0 : 1.0),
  );
}

class _FloatingGalleryContextMenuOverlay extends StatefulWidget {
  const _FloatingGalleryContextMenuOverlay({
    required this.animation,
    required this.anchorRect,
    required this.initialCardScale,
    required this.reduceMotion,
    required this.safePadding,
    required this.initialDivisionRects,
    required this.provider,
    required this.capturedImage,
    required this.disposeImageOnClose,
    required this.onImageAdopted,
    required this.isAlreadyFav,
    required this.currentFavcat,
    required this.evalNotifier,
    required this.onApplyRule,
    required this.quickActions,
    required this.entries,
    this.onCreateRuleFromGallery,
  });

  final Animation<double> animation;
  final Rect anchorRect;
  final double initialCardScale;
  final bool reduceMotion;
  final EdgeInsets safePadding;
  final List<Rect> initialDivisionRects;
  final GalleryProvider provider;
  final ui.Image? capturedImage;
  final bool disposeImageOnClose;
  final VoidCallback onImageAdopted;
  final bool isAlreadyFav;
  final String currentFavcat;
  final ValueNotifier<RuleMenuEvalSnapshot> evalNotifier;
  final ValueChanged<FavRuleEvalResult> onApplyRule;
  final List<GalleryContextQuickAction> quickActions;
  final List<GalleryContextMenuEntry> entries;
  final VoidCallback? onCreateRuleFromGallery;

  @override
  State<_FloatingGalleryContextMenuOverlay> createState() =>
      _FloatingGalleryContextMenuOverlayState();
}

class _FloatingGalleryContextMenuOverlayState
    extends State<_FloatingGalleryContextMenuOverlay> {
  // Underdamped iOS 26 / Dynamic Island springs:
  // 1) Card detachment carries initial release velocity and ~3.8% subtle lift overshoot.
  static final _BoundedSpring _kCardLiftSpring = _BoundedSpring(
    mass: 1.0,
    stiffness: 390.0,
    damping: 26.0,
    initialVelocity: 1.4,
    durationSeconds: 0.46,
  );

  // 2) Horizontal capsule expansion leads vertical unfurling by ~16ms, snapping
  //    open from a compact pill with ~3% liquid bloom before settling.
  static final _BoundedSpring _kCapsuleWidthSpring = _BoundedSpring(
    mass: 1.0,
    stiffness: 430.0,
    damping: 27.5,
    initialVelocity: 2.0,
    durationSeconds: 0.46,
  );

  // 3) Vertical unfurl follows just behind width, revealing the inner glass rows.
  static final _BoundedSpring _kCapsuleHeightSpring = _BoundedSpring(
    mass: 1.0,
    stiffness: 350.0,
    damping: 24.8,
    initialVelocity: 0.6,
    durationSeconds: 0.46,
  );

  late final bool _initialHasRuleSlot;
  final GlobalKey _menuContentKey = GlobalKey();
  bool _dismissHapticPlayed = false;

  @override
  void initState() {
    super.initState();
    widget.onImageAdopted();
    final initialState = widget.evalNotifier.value.state;
    _initialHasRuleSlot = initialState == RuleMenuEvalState.hit ||
        initialState == RuleMenuEvalState.loading ||
        initialState == RuleMenuEvalState.error;
    widget.animation.addStatusListener(_handleAnimationStatus);
    // Fire the compound Core Haptics detachment pop on the exact mount frame!
    unawaited(vibrateUtil.contextMenuPop());
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.reverse && !_dismissHapticPlayed) {
      _dismissHapticPlayed = true;
      unawaited(vibrateUtil.contextMenuDismiss());
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_handleAnimationStatus);
    if (widget.disposeImageOnClose) {
      widget.capturedImage?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Get.isRegistered<AdaptiveEnvironmentService>()) {
      return Obx(() {
        Get.find<AdaptiveEnvironmentService>().snapshot.value;
        return _buildOverlayScene(context);
      });
    }
    return _buildOverlayScene(context);
  }

  Widget _buildOverlayScene(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final resolvedSafe = resolvePopupSafeInsets(context);
    final safe = EdgeInsets.fromLTRB(
      math.max(widget.safePadding.left, resolvedSafe.left),
      math.max(widget.safePadding.top, resolvedSafe.top),
      math.max(widget.safePadding.right, resolvedSafe.right),
      math.max(
        math.max(widget.safePadding.bottom, resolvedSafe.bottom),
        viewInsets.bottom,
      ),
    );
    final rawSafeLeft = safe.left.clamp(0.0, screen.width).toDouble();
    final rawSafeTop = safe.top.clamp(0.0, screen.height).toDouble();
    final rawSafeRight =
        (screen.width - safe.right).clamp(rawSafeLeft, screen.width).toDouble();
    final rawSafeBottom = (screen.height - safe.bottom)
        .clamp(rawSafeTop, screen.height)
        .toDouble();
    final rawSafeBounds = Rect.fromLTRB(
      rawSafeLeft,
      rawSafeTop,
      rawSafeRight,
      rawSafeBottom,
    );
    final liveDivisions =
        resolvePopupDivisionRects(context, targetSize: screen);
    final allDivisions = liveDivisions.isNotEmpty
        ? liveDivisions
        : widget.initialDivisionRects;
    final paneSafeBounds = constrainBoundsToAnchorPane(
      safeBounds: rawSafeBounds,
      anchorRect: widget.anchorRect,
      divisionRects: allDivisions,
    );
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    final layout = _computeContextMenuLayout(
      screen: screen,
      safeBounds: paneSafeBounds,
      anchorRect: widget.anchorRect,
      isRtl: isRtl,
      hasRuleSlot: _initialHasRuleSlot,
      hasQuickBar: widget.quickActions.isNotEmpty,
      entries: widget.entries,
      hasCreateRuleRow:
          !_initialHasRuleSlot && widget.onCreateRuleFromGallery != null,
    );

    final backdropTint =
        dark ? const Color(0x45000000) : const Color(0x22000000);
    final pageSlotColor =
        CupertinoDynamicColor.resolve(ehTheme.palette.canvas, context);
    final sectionBandColor =
        dark ? const Color(0x33000000) : const Color(0x0D14161C);
    final separatorColor = CupertinoDynamicColor.resolve(
      CupertinoColors.separator,
      context,
    );

    final pressedAnchorRect = widget.initialCardScale == 1.0
        ? widget.anchorRect
        : Rect.fromCenter(
            center: widget.anchorRect.center,
            width: widget.anchorRect.width * widget.initialCardScale,
            height: widget.anchorRect.height * widget.initialCardScale,
          );

    final menuScrollContent = SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ValueListenableBuilder<RuleMenuEvalSnapshot>(
            valueListenable: widget.evalNotifier,
            builder: (ctx, snap, _) {
              final hasBanner = snap.state == RuleMenuEvalState.hit ||
                  snap.state == RuleMenuEvalState.loading ||
                  snap.state == RuleMenuEvalState.error;
              if (!hasBanner) {
                return const SizedBox.shrink();
              }
              final hasContentBelow = widget.quickActions.isNotEmpty ||
                  widget.entries.isNotEmpty ||
                  (widget.onCreateRuleFromGallery != null &&
                      snap.state == RuleMenuEvalState.error);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  buildRuleFavMenuBanner(
                    context: ctx,
                    snapshot: snap,
                    isAlreadyFav: widget.isAlreadyFav,
                    currentFavcat: widget.currentFavcat,
                    onApplyRule: widget.onApplyRule,
                  ),
                  if (hasContentBelow)
                    Container(height: 6, color: sectionBandColor),
                ],
              );
            },
          ),
          if (widget.quickActions.isNotEmpty) ...<Widget>[
            _ContextQuickActionBar(
              key: kGalleryContextMenuQuickBarKey,
              actions: widget.quickActions,
              compact: layout.compactMenu,
            ),
            if (widget.entries.isNotEmpty)
              Container(height: 0.5, color: separatorColor),
          ],
          for (var i = 0; i < widget.entries.length; i++) ...<Widget>[
            if (i > 0)
              Container(
                height: widget.entries[i].sectionBreakBefore ? 6 : 0.5,
                margin: widget.entries[i].sectionBreakBefore
                    ? EdgeInsets.zero
                    : EdgeInsetsDirectional.only(
                        start: layout.compactMenu ? 34 : 46,
                      ),
                color: widget.entries[i].sectionBreakBefore
                    ? sectionBandColor
                    : separatorColor,
              ),
            _ContextMenuRow(
              entry: widget.entries[i],
              compact: layout.compactMenu,
            ),
          ],
          if (widget.onCreateRuleFromGallery != null)
            ValueListenableBuilder<RuleMenuEvalSnapshot>(
              valueListenable: widget.evalNotifier,
              builder: (ctx, snap, _) {
                if (snap.state == RuleMenuEvalState.hit ||
                    snap.state == RuleMenuEvalState.loading) {
                  return const SizedBox.shrink();
                }
                final canonicalCat =
                    canonicalizeFavRuleCategory(widget.provider.category);
                final createLabel =
                    formatCreateRuleFromGalleryLabel(ctx, widget.provider);
                final hasContentAbove = widget.entries.isNotEmpty ||
                    widget.quickActions.isNotEmpty;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (hasContentAbove)
                      Container(height: 6, color: sectionBandColor),
                    _ContextMenuRow(
                      key: kGalleryContextMenuCreateRuleRowKey,
                      compact: layout.compactMenu,
                      entry: GalleryContextMenuEntry(
                        label: createLabel,
                        icon: CupertinoIcons.plus_square,
                        leading: canonicalCat != null
                            ? FavCategorySwatchSquare(
                                category: canonicalCat,
                                size: 22,
                                borderRadius: 7,
                              )
                            : null,
                        showChevron: true,
                        onPressed: widget.onCreateRuleFromGallery!,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );

    return AnimatedBuilder(
      animation: widget.animation,
      child: menuScrollContent,
      builder: (context, cachedMenuChild) {
        final u = widget.animation.value.clamp(0.0, 1.0).toDouble();
        final isReversing =
            widget.animation.status == AnimationStatus.reverse;

        final double backdropT;
        final double cardLiftT;
        final Rect startCardRect;
        final double widthFactor;
        final double heightFactor;
        final double overshootX;
        final double overshootY;
        final double shellOpacity;
        final double contentOpacity;
        final double contentBlurSigma;
        final double contentSlide;
        final double surfaceRadius;
        final double slotMaskOpacity;

        if (widget.reduceMotion || u >= 1.0) {
          backdropT = u;
          cardLiftT = u;
          startCardRect = widget.anchorRect;
          widthFactor = 1.0;
          heightFactor = 1.0;
          overshootX = 1.0;
          overshootY = 1.0;
          shellOpacity = u;
          contentOpacity = u;
          contentBlurSigma = 0.0;
          contentSlide = 0.0;
          surfaceRadius = 24.0;
          slotMaskOpacity = u;
        } else if (!isReversing) {
          // Forward: Dynamic Island pressurized capsule unfurl + underdamped spring bloom
          backdropT = Curves.easeOutQuart.transform(
            (u / 0.58).clamp(0.0, 1.0).toDouble(),
          );
          cardLiftT = _kCardLiftSpring.transform(u);
          startCardRect = pressedAnchorRect;

          final uHeight = ((u - 0.035) / 0.965).clamp(0.0, 1.0).toDouble();
          final rawW =
              ui.lerpDouble(0.44, 1.0, _kCapsuleWidthSpring.transform(u))!;
          final rawH = ui.lerpDouble(
            0.18,
            1.0,
            _kCapsuleHeightSpring.transform(uHeight),
          )!;

          widthFactor = rawW.clamp(0.18, 1.0).toDouble();
          heightFactor = rawH.clamp(0.14, 1.0).toDouble();
          overshootX = rawW > 1.0 ? rawW : 1.0;
          overshootY = rawH > 1.0 ? rawH : 1.0;

          // Solid glass body materializes within ~48ms (never ghostly half-alpha!)
          shellOpacity = Curves.easeOutCubic.transform(
            (u / 0.11).clamp(0.0, 1.0).toDouble(),
          );
          // Inner rows crystallize into sharp focus slightly behind the shell
          final contentProgress = Curves.easeOutCubic.transform(
            ((u - 0.05) / 0.34).clamp(0.0, 1.0).toDouble(),
          );
          contentOpacity = contentProgress;
          contentBlurSigma = 4.5 * (1.0 - contentProgress);
          contentSlide = 8.0 * (1.0 - contentProgress);
          surfaceRadius = ui.lerpDouble(
            32.0,
            24.0,
            heightFactor.clamp(0.0, 1.0).toDouble(),
          )!;
          slotMaskOpacity = (backdropT * 2.2).clamp(0.0, 1.0).toDouble();
        } else {
          // Reverse: Critically-damped vacuum fold back into card edge
          backdropT = Curves.easeInOutCubic.transform(u);
          cardLiftT = Curves.easeInOutCubic.transform(u);
          startCardRect = widget.anchorRect;

          widthFactor =
              ui.lerpDouble(0.48, 1.0, Curves.easeOutCubic.transform(u))!;
          heightFactor =
              ui.lerpDouble(0.20, 1.0, Curves.easeInOutCubic.transform(u))!;
          overshootX = 1.0;
          overshootY = 1.0;

          shellOpacity = Curves.easeOut.transform(
            (u / 0.32).clamp(0.0, 1.0).toDouble(),
          );
          final revContent = Curves.easeOut.transform(
            ((u - 0.28) / 0.72).clamp(0.0, 1.0).toDouble(),
          );
          contentOpacity = revContent;
          contentBlurSigma = 3.2 * (1.0 - revContent);
          contentSlide = 5.0 * (1.0 - revContent);
          surfaceRadius = ui.lerpDouble(32.0, 24.0, heightFactor)!;
          slotMaskOpacity = (u / 0.24).clamp(0.0, 1.0).toDouble();
        }

        final currentCardRect =
            Rect.lerp(startCardRect, layout.liftedRect, cardLiftT) ??
                layout.liftedRect;
        final shadowProgress = cardLiftT.clamp(0.0, 1.15).toDouble();

        final slideDirectionY = layout.popAlignment.y > 0.2
            ? contentSlide
            : (layout.popAlignment.y < -0.2 ? -contentSlide : 0.0);
        final slideDirectionX = layout.popAlignment.y.abs() <= 0.2
            ? (layout.popAlignment.x < 0 ? -contentSlide : contentSlide)
            : 0.0;

        final innerAlign = Alignment(
          0.0,
          layout.popAlignment.y.clamp(-1.0, 1.0).toDouble(),
        );

        Widget crystallizedContent = ConstrainedBox(
          key: _menuContentKey,
          constraints: BoxConstraints(
            minWidth: layout.menuWidth,
            maxWidth: layout.menuWidth,
            maxHeight: layout.menuMaxHeight,
          ),
          child: cachedMenuChild,
        );

        if (contentSlide > 0.01) {
          crystallizedContent = Transform.translate(
            offset: Offset(slideDirectionX, slideDirectionY),
            child: crystallizedContent,
          );
        }
        if (contentBlurSigma > 0.08) {
          crystallizedContent = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: contentBlurSigma,
              sigmaY: contentBlurSigma,
            ),
            child: crystallizedContent,
          );
        }
        if (contentOpacity < 0.999) {
          crystallizedContent = Opacity(
            opacity: contentOpacity,
            child: crystallizedContent,
          );
        }

        Widget unfurlingBody = crystallizedContent;
        if (widthFactor < 0.999 || heightFactor < 0.999) {
          unfurlingBody = ClipRect(
            child: Align(
              alignment: innerAlign,
              widthFactor: widthFactor,
              heightFactor: heightFactor,
              child: crystallizedContent,
            ),
          );
        }

        Widget menuPanel = buildFavRuleGlassOrCardSurface(
          key: kGalleryContextMenuSurfaceKey,
          context: context,
          borderRadius: BorderRadius.all(Radius.circular(surfaceRadius)),
          child: unfurlingBody,
        );

        if (overshootX != 1.0 || overshootY != 1.0) {
          menuPanel = Transform(
            alignment: layout.popAlignment,
            transform: Matrix4.diagonal3Values(overshootX, overshootY, 1.0),
            child: menuPanel,
          );
        }
        if (shellOpacity < 0.999) {
          menuPanel = Opacity(
            opacity: shellOpacity,
            child: menuPanel,
          );
        }

        return Stack(
          children: <Widget>[
            // Occlude the original card slot underneath BackdropFilter so no
            // duplicate ghost appears behind the lifted preview card.
            if (layout.showLiftedCard && slotMaskOpacity > 0.005)
              Positioned.fromRect(
                rect: widget.anchorRect.inflate(1.0),
                child: IgnorePointer(
                  child: Opacity(
                    opacity: slotMaskOpacity,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: pageSlotColor,
                        shape: RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: 18.0 * backdropT,
                    sigmaY: 18.0 * backdropT,
                  ),
                  child: ColoredBox(
                    key: kGalleryContextMenuBackdropKey,
                    color: backdropTint.withValues(
                      alpha: backdropTint.a * backdropT,
                    ),
                  ),
                ),
              ),
            ),
            if (layout.showLiftedCard)
              Positioned(
                left: currentCardRect.left,
                top: currentCardRect.top,
                width: math.max(1.0, currentCardRect.width),
                height: math.max(1.0, currentCardRect.height),
                child: _LiftedGalleryCardView(
                  key: kGalleryContextMenuLiftedCardKey,
                  capturedImage: widget.capturedImage,
                  provider: widget.provider,
                  liftProgress: shadowProgress.clamp(0.0, 1.0).toDouble(),
                  cardSize: currentCardRect.size,
                  reduceMotion: widget.reduceMotion,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            Positioned(
              left: layout.menuLeft,
              top: layout.menuTop,
              bottom: layout.menuBottom,
              width: layout.menuWidth,
              child: Align(
                alignment: layout.popAlignment,
                child: menuPanel,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LiftedGalleryCardView extends StatefulWidget {
  const _LiftedGalleryCardView({
    super.key,
    required this.capturedImage,
    required this.provider,
    required this.liftProgress,
    required this.cardSize,
    required this.reduceMotion,
    required this.onTap,
  });

  final ui.Image? capturedImage;
  final GalleryProvider provider;
  final double liftProgress;
  final Size cardSize;
  final bool reduceMotion;
  final VoidCallback onTap;

  @override
  State<_LiftedGalleryCardView> createState() => _LiftedGalleryCardViewState();
}

class _LiftedGalleryCardViewState extends State<_LiftedGalleryCardView> {
  static const double _kDismissDragThreshold = 44.0;
  static const double _kMaxRubberPull = 28.0;

  Offset _rawDrag = Offset.zero;
  bool _dragging = false;
  bool _crossedDismissThreshold = false;

  static double _rubberBand(double delta) {
    final abs = delta.abs();
    final sign = delta < 0 ? -1.0 : 1.0;
    return sign *
        (1.0 - (1.0 / ((abs * 0.55 / _kMaxRubberPull) + 1.0))) *
        _kMaxRubberPull;
  }

  void _onPanStart(DragStartDetails _) {
    if (widget.reduceMotion) {
      return;
    }
    setState(() {
      _dragging = true;
      _rawDrag = Offset.zero;
      _crossedDismissThreshold = false;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_dragging || widget.reduceMotion) {
      return;
    }
    final next = _rawDrag + details.delta;
    final crossed = next.distance >= _kDismissDragThreshold;
    if (crossed != _crossedDismissThreshold) {
      unawaited(vibrateUtil.selection());
    }
    setState(() {
      _rawDrag = next;
      _crossedDismissThreshold = crossed;
    });
  }

  void _onPanEnd(DragEndDetails _) {
    if (!_dragging) {
      return;
    }
    final shouldDismiss = _crossedDismissThreshold;
    setState(() {
      _dragging = false;
      _rawDrag = Offset.zero;
      _crossedDismissThreshold = false;
    });
    if (shouldDismiss) {
      widget.onTap();
    }
  }

  void _onPanCancel() {
    if (!_dragging) {
      return;
    }
    setState(() {
      _dragging = false;
      _rawDrag = Offset.zero;
      _crossedDismissThreshold = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final liftProgress = widget.liftProgress;
    final radius = Radius.circular(
      (widget.cardSize.shortestSide * 0.11).clamp(12.0, 18.0).toDouble(),
    );
    final borderRadius = BorderRadius.all(radius);
    final borderColor = dark
        ? CupertinoColors.white.withValues(alpha: 0.18 * liftProgress)
        : CupertinoDynamicColor.resolve(ehTheme.palette.hairline, context)
            .withValues(alpha: liftProgress);

    final Widget content = widget.capturedImage != null
        ? RawImage(
            image: widget.capturedImage,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
          )
        : _FallbackLiftedCard(provider: widget.provider);

    final targetOffset = _dragging
        ? Offset(_rubberBand(_rawDrag.dx), _rubberBand(_rawDrag.dy))
        : Offset.zero;
    final dragScale = _dragging
        ? (1.0 - (_rawDrag.distance / 320.0).clamp(0.0, 0.03))
        : 1.0;

    final cardVisual = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, (dark ? 0.46 : 0.25) * liftProgress),
            blurRadius: 34 * liftProgress,
            offset: Offset(0, 16 * liftProgress),
          ),
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, (dark ? 0.22 : 0.10) * liftProgress),
            blurRadius: 9 * liftProgress,
            offset: Offset(0, 3 * liftProgress),
          ),
        ],
      ),
      child: ClipRSuperellipse(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            content,
            IgnorePointer(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: RoundedSuperellipseBorder(
                    borderRadius: borderRadius,
                    side: BorderSide(color: borderColor, width: 0.65),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onPanCancel: _onPanCancel,
      child: TweenAnimationBuilder<Offset>(
        tween: Tween<Offset>(begin: Offset.zero, end: targetOffset),
        duration: _dragging
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: const Cubic(0.20, 1.15, 0.36, 1.0),
        builder: (context, offset, child) {
          if (offset == Offset.zero && dragScale == 1.0) {
            return child!;
          }
          return Transform.translate(
            offset: offset,
            child: Transform.scale(
              scale: dragScale,
              child: child,
            ),
          );
        },
        child: cardVisual,
      ),
    );
  }
}

/// Non-clipping, aspect-adaptive fallback card used only when live
/// `RenderRepaintBoundary.toImage` is unavailable (e.g. headless widget tests).
class _FallbackLiftedCard extends StatelessWidget {
  const _FallbackLiftedCard({required this.provider});

  final GalleryProvider provider;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final surface = CupertinoDynamicColor.resolve(palette.surface, context);
    final fill = CupertinoDynamicColor.resolve(palette.fill, context);
    final text1 = CupertinoDynamicColor.resolve(palette.text1, context);
    final text2 = CupertinoDynamicColor.resolve(palette.text2, context);
    final title = (provider.japaneseTitle?.isNotEmpty ?? false)
        ? provider.japaneseTitle!
        : (provider.englishTitle ?? '');
    final category = provider.category ?? '';
    final hasImg = provider.imgUrl != null && provider.imgUrl!.isNotEmpty;

    return ColoredBox(
      color: surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          if (h < 84 || w < 96) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: <Widget>[
                  EhSvgIcon(
                    CupertinoIcons.photo,
                    size: 16,
                    color: text2,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: text1,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final isPortrait = h >= w * 0.95;
          if (isPortrait) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: ColoredBox(
                    color: fill,
                    child: hasImg
                        ? EhNetworkImage(
                            imageUrl: provider.imgUrl!,
                            fit: BoxFit.cover,
                          )
                        : Center(
                            child: EhSvgIcon(
                              CupertinoIcons.photo,
                              size: 24,
                              color: text2,
                            ),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (category.isNotEmpty && h >= 160)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: EhPalette.accent.resolveFrom(context),
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      Text(
                        title,
                        maxLines: h >= 210 ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                          color: text1,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          final coverWidth = (w * 0.34).clamp(64.0, 120.0).toDouble();
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                width: coverWidth,
                child: ColoredBox(
                  color: fill,
                  child: hasImg
                      ? EhNetworkImage(
                          imageUrl: provider.imgUrl!,
                          fit: BoxFit.cover,
                        )
                      : Center(
                          child: EhSvgIcon(
                            CupertinoIcons.photo,
                            size: 22,
                            color: text2,
                          ),
                        ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (category.isNotEmpty && h >= 110)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: EhPalette.accent.resolveFrom(context),
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      Flexible(
                        child: Text(
                          title,
                          maxLines: h >= 132 ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.28,
                            fontWeight: FontWeight.w600,
                            color: text1,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
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

class _ContextQuickActionBar extends StatelessWidget {
  const _ContextQuickActionBar({
    super.key,
    required this.actions,
    this.compact = false,
  });

  final List<GalleryContextQuickAction> actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6, vertical: 4),
      child: Row(
        children: <Widget>[
          for (final action in actions)
            Expanded(
              child: _QuickActionCell(action: action, compact: compact),
            ),
        ],
      ),
    );
  }
}

class _QuickActionCell extends StatefulWidget {
  const _QuickActionCell({
    required this.action,
    this.compact = false,
  });

  final GalleryContextQuickAction action;
  final bool compact;

  @override
  State<_QuickActionCell> createState() => _QuickActionCellState();
}

class _QuickActionCellState extends State<_QuickActionCell> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labelColor =
        CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final fillColor = _pressed
        ? CupertinoDynamicColor.resolve(
            CupertinoColors.tertiarySystemFill,
            context,
          )
        : const Color(0x00000000);
    final fg = widget.action.accentColor ?? labelColor;

    return Semantics(
      button: true,
      label: widget.action.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          _setPressed(true);
          unawaited(vibrateUtil.selection());
        },
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.action.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: Duration(milliseconds: _pressed ? 80 : 180),
          curve: Curves.easeOutCubic,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: widget.compact ? 38 : 54),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? 2 : 6,
                  vertical: widget.compact ? 6 : 7,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    EhSvgIcon(
                      widget.action.icon,
                      size: widget.compact ? 17 : 18.5,
                      color: fg,
                    ),
                    if (!widget.compact) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        widget.action.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: EhPopupTextStyles.body(context).copyWith(
                          fontSize: 11.5,
                          height: 1.15,
                          fontWeight: FontWeight.w500,
                          color: fg,
                        ),
                      ),
                    ],
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

class _ContextMenuRow extends StatefulWidget {
  const _ContextMenuRow({
    super.key,
    required this.entry,
    this.compact = false,
  });

  final GalleryContextMenuEntry entry;
  final bool compact;

  @override
  State<_ContextMenuRow> createState() => _ContextMenuRowState();
}

class _ContextMenuRowState extends State<_ContextMenuRow> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final compact = widget.compact;
    final textColor = entry.destructive
        ? CupertinoDynamicColor.resolve(CupertinoColors.systemRed, context)
        : CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final iconColor = entry.destructive
        ? CupertinoDynamicColor.resolve(CupertinoColors.systemRed, context)
        : CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final fillColor = _pressed
        ? CupertinoDynamicColor.resolve(
            CupertinoColors.tertiarySystemFill,
            context,
          )
        : const Color(0x00000000);

    return Semantics(
      button: true,
      label: entry.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          _setPressed(true);
          unawaited(vibrateUtil.selection());
        },
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: entry.onPressed,
        child: ColoredBox(
          color: fillColor,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 16,
                vertical: 11,
              ),
              child: Row(
                children: <Widget>[
                  if (entry.leading != null)
                    entry.leading!
                  else
                    EhSvgIcon(
                      entry.icon,
                      size: compact ? 16 : 18,
                      color: iconColor,
                    ),
                  SizedBox(width: compact ? 8 : 12),
                  Expanded(
                    child: Text(
                      entry.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                      style: EhPopupTextStyles.action(context).copyWith(
                        fontSize: compact ? 13.5 : 15,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (!compact &&
                      entry.trailing != null &&
                      entry.trailing!.isNotEmpty) ...<Widget>[
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 88),
                      child: Text(
                        entry.trailing!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: EhPopupTextStyles.secondary(context).copyWith(
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                  if (!compact && entry.showChevron) ...<Widget>[
                    const SizedBox(width: 6),
                    EhSvgIcon(
                      CupertinoIcons.chevron_forward,
                      size: 13,
                      color: CupertinoDynamicColor.resolve(
                        CupertinoColors.tertiaryLabel,
                        context,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
