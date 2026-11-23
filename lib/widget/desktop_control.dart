import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/widget/desktop_browse_style.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/services.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';

/// Pointer, keyboard and assistive activation share one callback. This keeps
/// focus feedback distinct from hover and selection throughout desktop chrome.
class DesktopControl extends StatefulWidget {
  const DesktopControl({
    super.key,
    required this.label,
    required this.child,
    required this.onPressed,
    this.selected = false,
    this.expanded,
    this.focusNode,
    this.onSecondaryTapDown,
    this.radius = 10,
    this.minSize = 32,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.tooltip = true,
    this.autofocus = false,
    this.selectedColor,
    this.selectedHoverColor,
    this.pressedColor,
    this.hoverColor,
    this.idleColor,
    this.cursor,
  });
  final String label;
  final Widget child;
  final VoidCallback? onPressed;
  final bool selected;
  final bool? expanded;
  final FocusNode? focusNode;
  final GestureTapDownCallback? onSecondaryTapDown;
  final double radius;
  final double minSize;
  final EdgeInsetsGeometry padding;
  final bool tooltip;
  final bool autofocus;
  final Color? selectedColor;
  final Color? selectedHoverColor;
  final Color? pressedColor;
  final Color? hoverColor;
  final Color? idleColor;
  final MouseCursor? cursor;

  @override
  State<DesktopControl> createState() => _DesktopControlState();
}

class _DesktopControlState extends State<DesktopControl>
    with SingleTickerProviderStateMixin {
  bool _hover = false;
  bool _focus = false;
  int _pressEpoch = 0;

  late final AnimationController _pressController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 85),
    reverseDuration: const Duration(milliseconds: 190),
  );

  @override
  void didUpdateWidget(covariant DesktopControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onPressed == null) {
      _hover = false;
      _pressEpoch++;
      _pressController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handlePressDown() {
    _pressEpoch++;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pressController.value = 1.0;
    } else {
      _pressController.forward();
    }
  }

  void _handlePressUp() {
    final int epoch = ++_pressEpoch;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pressController.value = 0.0;
      return;
    }
    if (_pressController.value < 0.65) {
      _pressController
          .animateTo(
            1.0,
            duration: const Duration(milliseconds: 55),
            curve: Curves.easeOut,
          )
          .then((_) {
            if (mounted && _pressEpoch == epoch) {
              _pressController.reverse();
            }
          });
    } else {
      _pressController.reverse();
    }
  }

  void _handlePressCancel() {
    _pressEpoch++;
    if (!_pressController.isAnimating && _pressController.value == 0.0) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _pressController.value = 0.0;
    } else {
      _pressController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final active = widget.onPressed != null;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final Color defaultHover = palette.text1
        .resolveFrom(context)
        .withValues(alpha: dark ? .11 : .07);
    final Color hoverFill = widget.hoverColor ?? defaultHover;
    final Color baseSelected =
        widget.selectedColor ?? EhPalette.accentSoft.resolveFrom(context);
    final Color effectiveSelectedHover =
        widget.selectedHoverColor ??
        Color.alphaBlend(
          palette.text1
              .resolveFrom(context)
              .withValues(alpha: dark ? .06 : .05),
          baseSelected,
        );
    final Color effectivePressed = widget.selected
        ? (widget.selectedColor != null
              ? DesktopBrowseStyle.capsuleSelectedPressed(context)
              : Color.alphaBlend(
                  dark ? const Color(0x10FFFFFF) : const Color(0x0C14161C),
                  baseSelected,
                ))
        : (widget.pressedColor ?? DesktopBrowseStyle.capsulePressed(context));
    final Color baseBackground;
    if (widget.selected) {
      baseBackground = _hover && active ? effectiveSelectedHover : baseSelected;
    } else if (_hover && active) {
      baseBackground = hoverFill;
    } else {
      baseBackground = widget.idleColor ?? hoverFill.withValues(alpha: 0);
    }

    final Color focusBorderColor = _focus
        ? EhPalette.accent.resolveFrom(context)
        : const Color(0x00000000);
    final BorderRadius borderRadius = BorderRadius.circular(widget.radius);
    final BoxConstraints constraints = BoxConstraints(
      minHeight: widget.minSize,
      minWidth: widget.minSize,
    );
    final Widget content = IconTheme.merge(
      data: IconThemeData(
        size: 18,
        color: palette.text1
            .resolveFrom(context)
            .withValues(alpha: active ? 1 : .4),
      ),
      child: widget.child,
    );

    final child = Semantics(
      button: true,
      enabled: active,
      selected: widget.selected,
      expanded: widget.expanded,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        enabled: active,
        mouseCursor: MouseCursor.defer,
        onShowFocusHighlight: (value) => setState(() => _focus = value),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: active
              ? (widget.cursor ?? DesktopBrowseStyle.interactionCursor)
              : SystemMouseCursors.basic,
          onEnter: (_) {
            if (active && !_hover) {
              setState(() => _hover = true);
            }
          },
          onExit: (_) {
            if (_hover) {
              setState(() => _hover = false);
            }
            _handlePressCancel();
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: active ? (_) => _handlePressDown() : null,
            onTapUp: active ? (_) => _handlePressUp() : null,
            onTapCancel: active ? _handlePressCancel : null,
            onTap: widget.onPressed,
            onSecondaryTapDown: widget.onSecondaryTapDown,
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: baseBackground),
              duration: DesktopBrowseStyle.hoverDuration(
                context,
                entering: _hover,
              ),
              curve: _hover
                  ? DesktopBrowseStyle.hoverEnterCurve
                  : DesktopBrowseStyle.hoverExitCurve,
              child: content,
              builder: (context, animatedBase, innerChild) => AnimatedBuilder(
                animation: _pressController,
                child: innerChild,
                builder: (context, child) {
                  final double t = Curves.easeOutCubic.transform(
                    _pressController.value,
                  );
                  final Color resolvedBase = animatedBase ?? baseBackground;
                  final Color fill = active && t > 0
                      ? (Color.lerp(resolvedBase, effectivePressed, t) ??
                            effectivePressed)
                      : resolvedBase;
                  return Transform.scale(
                    scale: disableAnimations ? 1.0 : 1.0 - 0.01 * t,
                    child: AnimatedContainer(
                      duration: Duration.zero,
                      constraints: constraints,
                      padding: widget.padding,
                      decoration: BoxDecoration(
                        color: fill,
                        borderRadius: borderRadius,
                        border: Border.all(
                          color: focusBorderColor,
                          width: 1.5,
                        ),
                      ),
                      child: child,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    return widget.tooltip
        ? Tooltip(message: widget.label, child: child)
        : child;
  }
}

/// Visual tone for a compact 30px pill action inside desktop pane headers.
enum DesktopPillTone { subtle, tonal, prominent }

/// Compact desktop action button matching the 30px height and 8px radius of
/// desktop toolbar controls while carrying an explicit label.
class DesktopToolbarPill extends StatefulWidget {
  const DesktopToolbarPill({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconSize = 14,
    this.tone = DesktopPillTone.subtle,
    this.padding = const EdgeInsets.symmetric(horizontal: 10),
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double iconSize;
  final DesktopPillTone tone;
  final EdgeInsetsGeometry padding;

  @override
  State<DesktopToolbarPill> createState() => _DesktopToolbarPillState();
}

class _DesktopToolbarPillState extends State<DesktopToolbarPill> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final active = widget.onPressed != null;
    final accent = EhPalette.accent.resolveFrom(context);
    final onAccent = EhPalette.onAccent.resolveFrom(context);
    final Color background;
    final Color foreground;
    final Color idleBorder;
    switch (widget.tone) {
      case DesktopPillTone.prominent:
        background = _hover
            ? Color.alphaBlend(
                onAccent.withValues(alpha: dark ? .14 : .10),
                accent,
              )
            : accent;
        foreground = onAccent;
        idleBorder = const Color(0x00000000);
      case DesktopPillTone.tonal:
        final base = EhPalette.accentSoft.resolveFrom(context);
        background = _hover
            ? Color.alphaBlend(
                accent.withValues(alpha: dark ? .16 : .10),
                base,
              )
            : base;
        foreground = accent;
        idleBorder = accent.withValues(alpha: dark ? .28 : .20);
      case DesktopPillTone.subtle:
        background = _hover
            ? palette.fill.resolveFrom(context)
            : const Color(0x00000000);
        foreground = palette.text2.resolveFrom(context);
        idleBorder = palette.hairline.resolveFrom(context);
    }

    return Semantics(
      button: true,
      enabled: active,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: FocusableActionDetector(
        enabled: active,
        mouseCursor: active
            ? DesktopBrowseStyle.interactionCursor
            : SystemMouseCursors.basic,
        onShowHoverHighlight: (value) => setState(() => _hover = value),
        onShowFocusHighlight: (value) => setState(() => _focus = value),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: DesktopBrowseStyle.motion(context, 180),
            curve: Curves.easeOutQuart,
            height: 30,
            padding: widget.padding,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? background : background.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _focus
                    ? (widget.tone == DesktopPillTone.prominent
                          ? palette.text1.resolveFrom(context)
                          : accent)
                    : idleBorder,
                width: _focus ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  EhSvgIcon(
                    widget.icon,
                    size: widget.iconSize,
                    color: foreground.withValues(alpha: active ? 1 : .45),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: widget.tone == DesktopPillTone.subtle
                        ? FontWeight.w500
                        : FontWeight.w600,
                    color: foreground.withValues(alpha: active ? 1 : .45),
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

/// A 48px pane-local header matching [DesktopGalleryToolbar] with a bottom
/// hairline divider and optional macOS window-drag strip.
class DesktopPaneHeader extends StatelessWidget {
  const DesktopPaneHeader({
    super.key,
    required this.title,
    this.leading = const <Widget>[],
    this.badge,
    this.trailing = const <Widget>[],
  });

  final String title;
  final List<Widget> leading;
  final Widget? badge;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final mac = PlatformCapabilities.hostPlatform == TargetPlatform.macOS;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: palette.hairline.resolveFrom(context)),
        ),
      ),
      child: SizedBox(
        height: DesktopBrowseStyle.toolbarHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 10, 0),
          child: Row(
            children: [
              ...leading,
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    if (mac)
                      Positioned.fill(
                        child: MoveWindow(child: const SizedBox.expand()),
                      ),
                    Padding(
                      padding: EdgeInsets.only(left: leading.isEmpty ? 6 : 2),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: palette.text1.resolveFrom(context),
                                ),
                              ),
                            ),
                            if (badge != null) ...[
                              const SizedBox(width: 6),
                              badge!,
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing.isNotEmpty) ...[
                const SizedBox(width: 8),
                ...trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Localized labels for [ListModeEnum] without requiring [EhSettingService].
Map<ListModeEnum, String> desktopListModeLabels(
  L10n l10n, {
  bool includeDebug = false,
}) => <ListModeEnum, String>{
  ListModeEnum.list: l10n.listmode_medium,
  ListModeEnum.simpleList: l10n.listmode_small,
  ListModeEnum.waterfall: l10n.listmode_waterfall,
  ListModeEnum.waterfallLarge: l10n.listmode_waterfall_large,
  ListModeEnum.grid: l10n.listmode_grid,
  ListModeEnum.gridTags: l10n.listmode_grid_tags,
  if (includeDebug) ListModeEnum.debugSimple: 'debugSimple',
};
