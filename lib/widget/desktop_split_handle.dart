import 'package:eros_fe/common/service/desktop_ui_preferences.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/widget/desktop_browse_style.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class DesktopSplitHandle extends StatefulWidget {
  const DesktopSplitHandle({
    super.key,
    required this.availableWidth,
    required this.listWidth,
    required this.preferences,
  });
  final double availableWidth, listWidth;
  final DesktopUiPreferences preferences;
  @override
  State<DesktopSplitHandle> createState() => _DesktopSplitHandleState();
}

class _DesktopSplitHandleState extends State<DesktopSplitHandle> {
  bool _hover = false, _focus = false, _dragging = false;
  void _adjust(double delta) {
    final space = widget.availableWidth - DesktopBrowseStyle.inset * 2;
    if (space < 840) return;
    widget.preferences.setSplitRatio(
      (widget.listWidth + delta).clamp(
            DesktopBrowseStyle.minimumListWidth,
            space - DesktopBrowseStyle.minimumDetailWidth,
          ) /
          space,
    );
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: L10n.of(context).desktop_resize_panes,
    value: '${widget.listWidth.round()}',
    onIncrease: () => _adjust(24),
    onDecrease: () => _adjust(-24),
    child: FocusableActionDetector(
      mouseCursor: SystemMouseCursors.resizeLeftRight,
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      onShowFocusHighlight: (v) => setState(() => _focus = v),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowLeft): _ResizeIntent(-24),
        SingleActivator(LogicalKeyboardKey.arrowRight): _ResizeIntent(24),
        SingleActivator(LogicalKeyboardKey.home): _ResetIntent(),
      },
      actions: {
        _ResizeIntent: CallbackAction<_ResizeIntent>(
          onInvoke: (intent) {
            _adjust(intent.delta);
            return null;
          },
        ),
        _ResetIntent: CallbackAction<_ResetIntent>(
          onInvoke: (_) {
            widget.preferences.setSplitRatio(.44);
            return null;
          },
        ),
      },
      child: GestureDetector(
        key: const ValueKey('desktop-split-handle'),
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () => widget.preferences.setSplitRatio(.44),
        onHorizontalDragStart: (_) => setState(() => _dragging = true),
        onHorizontalDragUpdate: (d) => _adjust(d.delta.dx),
        onHorizontalDragEnd: (_) => setState(() => _dragging = false),
        onHorizontalDragCancel: () => setState(() => _dragging = false),
        child: Center(
          child: AnimatedOpacity(
            opacity: _hover || _focus || _dragging ? 1 : 0,
            duration: DesktopBrowseStyle.motion(context, 100),
            child: Container(
              width: 2,
              height: 40,
              decoration: BoxDecoration(
                color: ehTheme.palette.text2.resolveFrom(context),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ResizeIntent extends Intent {
  const _ResizeIntent(this.delta);
  final double delta;
}

class _ResetIntent extends Intent {
  const _ResetIntent();
}
