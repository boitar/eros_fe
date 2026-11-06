import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';

/// Place inside a horizontal scrollable so it can compete for wheel signals
/// before the surrounding vertical scrollable receives them.
class HorizontalMouseWheel extends StatelessWidget {
  const HorizontalMouseWheel({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent ||
            event.kind != PointerDeviceKind.mouse ||
            event.scrollDelta.dx != 0 ||
            event.scrollDelta.dy == 0 ||
            !controller.hasClients) {
          return;
        }
        final position = controller.position;
        final delta = axisDirectionIsReversed(position.axisDirection)
            ? -event.scrollDelta.dy
            : event.scrollDelta.dy;
        final target = (position.pixels + delta).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        if (target == position.pixels) {
          return;
        }
        GestureBinding.instance.pointerSignalResolver.register(event, (signal) {
          position.pointerScroll(delta);
          (signal as PointerScrollEvent).respond(allowPlatformDefault: false);
        });
      },
      child: child,
    );
  }
}

/// A mouse-only highlight that leaves the child's touch handling unchanged.
class NavigationHover extends StatefulWidget {
  const NavigationHover({
    super.key,
    required this.child,
    this.enabled = true,
    this.borderRadius = BorderRadius.zero,
  });

  final Widget child;
  final bool enabled;
  final BorderRadius borderRadius;

  @override
  State<NavigationHover> createState() => _NavigationHoverState();
}

class _NavigationHoverState extends State<NavigationHover> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.enabled && _hovered;
    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (event) {
        if (event.kind == PointerDeviceKind.mouse) {
          setState(() => _hovered = true);
        }
      },
      onExit: (_) => setState(() => _hovered = false),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          color: highlighted
              ? CupertinoDynamicColor.resolve(
                  CupertinoColors.label,
                  context,
                ).withValues(alpha: 0.07)
              : const Color(0x00000000),
          borderRadius: widget.borderRadius,
        ),
        child: widget.child,
      ),
    );
  }
}
