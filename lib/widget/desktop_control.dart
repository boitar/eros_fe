import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/widget/desktop_browse_style.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/services.dart';

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
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.tooltip = true,
    this.autofocus = false,
  });
  final String label;
  final Widget child;
  final VoidCallback? onPressed;
  final bool selected;
  final bool? expanded;
  final FocusNode? focusNode;
  final GestureTapDownCallback? onSecondaryTapDown;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool tooltip;
  final bool autofocus;

  @override
  State<DesktopControl> createState() => _DesktopControlState();
}

class _DesktopControlState extends State<DesktopControl> {
  bool _hover = false;
  bool _focus = false;
  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final active = widget.onPressed != null;
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
        mouseCursor: active
            ? SystemMouseCursors.click
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
          onSecondaryTapDown: widget.onSecondaryTapDown,
          child: AnimatedContainer(
            duration: DesktopBrowseStyle.motion(context, 120),
            constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
            padding: widget.padding,
            decoration: BoxDecoration(
              color: widget.selected
                  ? EhPalette.accentSoft.resolveFrom(context)
                  : _hover
                  ? palette.text1
                        .resolveFrom(context)
                        .withValues(alpha: dark ? .09 : .05)
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(widget.radius),
              border: Border.all(
                color: _focus
                    ? EhPalette.accent.resolveFrom(context)
                    : const Color(0x00000000),
                width: 1.5,
              ),
            ),
            child: IconTheme.merge(
              data: IconThemeData(
                size: 18,
                color: palette.text1
                    .resolveFrom(context)
                    .withValues(alpha: active ? 1 : .4),
              ),
              child: widget.child,
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
