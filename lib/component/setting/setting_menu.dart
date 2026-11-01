import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One choice in a setting's pull-down menu.
@immutable
class SettingMenuOption<T> {
  const SettingMenuOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.symbol,
    this.child,
  });

  final T value;

  /// Plain text for the native menu and for VoiceOver.
  final String label;

  /// A second line explaining the choice.
  final String? subtitle;

  /// SF Symbol shown at the trailing edge of the native menu item.
  final String? symbol;

  /// Richer Flutter rendering of the choice; falls back to [label].
  final Widget? child;
}

/// Presents UIKit menus for Flutter rows through `eros/menu`.
abstract final class NativeSettingMenu {
  static const MethodChannel _channel = MethodChannel('eros/menu');
  static final Map<int, ValueChanged<int>> _pending =
      <int, ValueChanged<int>>{};
  static int _token = 0;
  static bool _unavailable = false;

  /// Shows a native menu whose source is [rect], in the Flutter view's
  /// logical coordinates. Returns false when Flutter has to draw the menu.
  static Future<bool> show({
    required Rect rect,
    required List<Map<String, Object?>> items,
    required ValueChanged<int> onSelected,
  }) async {
    if (_unavailable || kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    _channel.setMethodCallHandler(_handle);
    final token = ++_token;
    _pending[token] = onSelected;
    try {
      final shown = await _channel.invokeMethod<bool>('show', <String, Object>{
        'token': token,
        'rect': <String, double>{
          'x': rect.left,
          'y': rect.top,
          'width': rect.width,
          'height': rect.height,
        },
        'items': items,
      });
      if (shown ?? false) {
        return true;
      }
    } on MissingPluginException {
      _unavailable = true;
    } on PlatformException {
      // Draw the menu in Flutter instead.
    }
    _pending.remove(token);
    return false;
  }

  static Future<void> _handle(MethodCall call) async {
    final arguments = call.arguments;
    if (arguments is! Map) {
      return;
    }
    final token = arguments['token'];
    switch (call.method) {
      case 'selected':
        final index = arguments['index'];
        if (index is int) {
          _pending.remove(token)?.call(index);
        }
      case 'dismissed':
        // UIKit may deliver the chosen action after the menu starts closing.
        Future<void>.delayed(const Duration(milliseconds: 500), () {
          _pending.remove(token);
        });
    }
  }
}

/// A setting's current value with the up-down chevron of a pull-down button.
/// [SettingMenuButtonState.open] shows the choices: as a UIMenu on iOS
/// 17.4+, otherwise as a [CupertinoMenuAnchor] drawn by Flutter.
class SettingMenuButton<T> extends StatefulWidget {
  const SettingMenuButton({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<SettingMenuOption<T>> options;
  final T? selected;
  final ValueChanged<T> onSelected;

  @override
  State<SettingMenuButton<T>> createState() => SettingMenuButtonState<T>();
}

class SettingMenuButtonState<T> extends State<SettingMenuButton<T>> {
  final MenuController _controller = MenuController();

  // Neither menu ticks on its own; a pick answers like the bar's menus.
  void _pick(T value) {
    vibrateUtil.selection();
    widget.onSelected(value);
  }

  Future<void> open() async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return;
    }
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final options = widget.options;
    final shown = await NativeSettingMenu.show(
      rect: rect,
      items: <Map<String, Object?>>[
        for (final option in options)
          <String, Object?>{
            'title': option.label,
            'checked': option.value == widget.selected,
            if (option.subtitle != null) 'subtitle': option.subtitle,
            if (option.symbol != null) 'symbol': option.symbol,
          },
      ],
      onSelected: (index) {
        if (index >= 0 && index < options.length) {
          _pick(options[index].value);
        }
      },
    );
    if (!shown && mounted) {
      _controller.open();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final valueColor = palette.text2.resolveFrom(context);
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    return CupertinoMenuAnchor(
      controller: _controller,
      menuChildren: <Widget>[
        for (final option in widget.options)
          CupertinoMenuItem(
            leading: option.value == widget.selected
                ? const Icon(CupertinoIcons.checkmark_alt)
                : null,
            onPressed: () => _pick(option.value),
            subtitle: option.subtitle == null ? null : Text(option.subtitle!),
            child: option.child ?? Text(option.label),
          ),
      ],
      // One text run, so the value wraps with its chevron at large sizes and
      // keeps its natural width inside the row.
      child: Text.rich(
        TextSpan(
          text: widget.label,
          children: <InlineSpan>[
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 5),
                // Inline widgets already scale with the text.
                child: Icon(
                  CupertinoIcons.chevron_up_chevron_down,
                  size: 14,
                  color: valueColor,
                ),
              ),
            ),
          ],
        ),
        textAlign: TextAlign.end,
        style: textStyle.copyWith(color: valueColor),
      ),
    );
  }
}
