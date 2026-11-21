import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

/// The four button levels of the secondary pages.
///
/// * [prominent]: tinted glass, the one main action of a screen.
/// * [glass]: secondary bar and sheet actions such as close.
/// * [tonal]: actions inside the content, accent text on a soft accent fill.
/// * [fill]: neutral content actions; [destructive] only colours the text.
enum EhButtonStyle { prominent, glass, tonal, fill, destructive }

/// A capsule or circular button drawn by Flutter for the non-UIKit paths.
///
/// Give [label] for a capsule; an [icon] alone makes a circle of [size].
class EhButton extends StatelessWidget {
  const EhButton({
    super.key,
    this.icon,
    this.label,
    this.trailingIcon,
    this.caption,
    required this.onPressed,
    this.style = EhButtonStyle.fill,
    this.size = 38,
    this.expand = false,
    this.semanticLabel,
    this.selected = false,
  });

  final IconData? icon;
  final String? label;
  final IconData? trailingIcon;

  /// A second, smaller line under [label].
  final String? caption;
  final VoidCallback? onPressed;
  final EhButtonStyle style;

  /// Height of the button, and width when it is a circle.
  final double size;
  final bool expand;
  final String? semanticLabel;

  /// Tonal buttons double as toggles; unselected ones look like [fill].
  final bool selected;

  bool get _circle => label == null;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final enabled = onPressed != null;
    final effective = style == EhButtonStyle.tonal && !selected
        ? EhButtonStyle.fill
        : style;
    final Color background;
    final Color foreground;
    switch (effective) {
      case EhButtonStyle.prominent:
        background = EhPalette.accent.resolveFrom(context);
        foreground = EhPalette.onAccent.resolveFrom(context);
      case EhButtonStyle.glass:
        background = palette.fillPressed.resolveFrom(context);
        foreground = palette.text1.resolveFrom(context);
      case EhButtonStyle.tonal:
        background = EhPalette.accentSoft.resolveFrom(context);
        foreground = EhPalette.accent.resolveFrom(context);
      case EhButtonStyle.fill:
        background = palette.fill.resolveFrom(context);
        foreground = palette.text2.resolveFrom(context);
      case EhButtonStyle.destructive:
        background = palette.fill.resolveFrom(context);
        foreground = CupertinoDynamicColor.resolve(
          CupertinoColors.systemRed,
          context,
        );
    }
    final textScaler = MediaQuery.textScalerOf(context);
    final fontSize = size >= 48 ? 16.5 : (size >= 40 ? 15.5 : 13.5);
    final iconSize = size >= 48 ? 19.0 : (size >= 36 ? 18.0 : 15.0);
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle.copyWith(
      fontSize: fontSize,
      fontWeight:
          effective == EhButtonStyle.fill ||
              effective == EhButtonStyle.destructive
          ? FontWeight.w500
          : FontWeight.w600,
      letterSpacing: 0,
      height: 1.2,
      color: foreground,
    );

    Widget content;
    if (_circle) {
      content = Icon(icon, size: iconSize, color: foreground);
    } else {
      final text = caption == null
          ? Text(label!, style: textStyle, maxLines: 1)
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: trailingIcon != null && icon == null
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(label!, style: textStyle, maxLines: 1),
                Text(
                  caption!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: foreground.withValues(alpha: .78),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            );
      content = Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: foreground),
            SizedBox(width: size >= 44 ? 8 : 5),
          ],
          Flexible(child: text),
          if (trailingIcon != null) ...[
            SizedBox(width: size >= 44 ? 8 : 5),
            Icon(trailingIcon, size: iconSize, color: foreground),
          ],
        ],
      );
    }

    final minHeight = textScaler.scale(size) > size ? null : size;
    Widget button = Container(
      constraints: BoxConstraints(minWidth: size, minHeight: minHeight ?? size),
      height: _circle ? size : null,
      width: _circle ? size : (expand ? double.infinity : null),
      padding: _circle
          ? EdgeInsets.zero
          : EdgeInsets.symmetric(
              horizontal: size >= 44 ? 20 : (size >= 36 ? 14 : 11),
              vertical: 4,
            ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size / 2),
        boxShadow: effective == EhButtonStyle.prominent && enabled
            ? [
                BoxShadow(
                  color: EhPalette.accent
                      .resolveFrom(context)
                      .withValues(alpha: .28),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: content,
    );
    if (!_circle && !expand) {
      // An aligned Container fills its constraints; size capsules to content.
      button = IntrinsicWidth(child: button);
    }
    button = AnimatedOpacity(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 150),
      opacity: enabled ? 1 : .4,
      child: button,
    );
    if (PlatformCapabilities.hostPlatform == TargetPlatform.android) {
      // Keep the compact visual while giving touch input a 48 dp target.
      button = ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Center(
          widthFactor: expand ? null : 1,
          heightFactor: 1,
          child: button,
        ),
      );
    }
    return Semantics(
      button: true,
      enabled: enabled,
      selected: style == EhButtonStyle.tonal ? selected : null,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      // Excluded children take their tap action with them; restore it.
      onTap: semanticLabel != null ? onPressed : null,
      child: EhPressable(
        onPressed: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: button,
      ),
    );
  }
}

/// Pointer and keyboard interaction shared by the redesigned controls.
class EhPressable extends StatefulWidget {
  const EhPressable({
    super.key,
    required this.onPressed,
    required this.child,
    this.onLongPress,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
  });

  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Widget child;
  final BorderRadius borderRadius;

  @override
  State<EhPressable> createState() => _EhPressableState();
}

class _EhPressableState extends State<EhPressable> {
  bool _down = false;
  bool _hovered = false;
  bool _focused = false;

  static const _activationShortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.enter, includeRepeats: false):
        ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter, includeRepeats: false):
        ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.space, includeRepeats: false):
        ActivateIntent(),
  };

  void _set(bool value) {
    if (_down != value && mounted) {
      setState(() => _down = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null || widget.onLongPress != null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 120);
    return MouseRegion(
      onEnter: (event) {
        if (event.kind == PointerDeviceKind.mouse) {
          setState(() => _hovered = true);
        }
      },
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (_, event) {
          // Do not let a held activation key fall through to an ancestor's
          // default shortcut and repeatedly submit a sheet or open a page.
          final keyboard = HardwareKeyboard.instance;
          if (event is KeyRepeatEvent &&
              !keyboard.isControlPressed &&
              !keyboard.isMetaPressed &&
              !keyboard.isAltPressed &&
              !keyboard.isShiftPressed &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                  event.logicalKey == LogicalKeyboardKey.space)) {
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: FocusableActionDetector(
          enabled: widget.onPressed != null,
          mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          shortcuts: _activationShortcuts,
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed?.call();
                return null;
              },
            ),
          },
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          onFocusChange: (value) {
            if (!value) {
              _set(false);
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled ? (_) => _set(true) : null,
            onTapUp: enabled ? (_) => _set(false) : null,
            onTapCancel: enabled ? () => _set(false) : null,
            onTap: widget.onPressed,
            onLongPress: widget.onLongPress == null
                ? null
                : () {
                    _set(false);
                    widget.onLongPress!();
                  },
            child: AnimatedScale(
              scale: enabled && _down && !reduceMotion ? .96 : 1,
              duration: duration,
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: enabled && _down ? .72 : 1,
                duration: duration,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: widget.borderRadius,
                    color: enabled && _hovered
                        ? CupertinoDynamicColor.resolve(
                            CupertinoColors.label,
                            context,
                          ).withValues(alpha: .06)
                        : null,
                    border: widget.onPressed != null && _focused
                        ? Border.all(
                            color: EhPalette.accent.resolveFrom(context),
                            width: 2,
                          )
                        : null,
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
