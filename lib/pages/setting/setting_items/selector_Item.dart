import 'package:eros_fe/component/setting/setting_menu.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../../component/setting_base.dart';

class SelectorItem<T> extends StatefulWidget {
  const SelectorItem({
    Key? key,
    required this.title,
    this.actionTitle,
    this.hideDivider = false,
    required this.actionMap,
    this.simpleActionMap,
    required this.initVal,
    this.onValueChanged,
    this.actionWidgetMap,
    this.titleFlex = 1,
    this.valueFlex = 0,
  }) : super(key: key);
  final String title;
  final String? actionTitle;
  final bool hideDivider;
  final Map<T, String> actionMap;
  final Map<T, String>? simpleActionMap;
  final T initVal;
  final ValueChanged<T>? onValueChanged;
  final Map<T, Widget>? actionWidgetMap;
  final int titleFlex;
  final int valueFlex;

  @override
  _SelectorItemState<T> createState() => _SelectorItemState<T>();
}

class _SelectorItemState<T> extends State<SelectorItem<T>> {
  String selector = '';

  @override
  void initState() {
    super.initState();
    selector = widget.simpleActionMap?[widget.initVal] ??
        widget.actionMap[widget.initVal] ??
        '';
  }

  List<Widget> _getActionList() {
    if (widget.actionWidgetMap == null) {
      return List<Widget>.from(widget.actionMap.keys.map((T element) {
        return CupertinoActionSheetAction(
            onPressed: () {
              Get.back(result: element);
            },
            child: Text(widget.actionMap[element] ?? ''));
      }).toList());
    } else {
      return List<Widget>.from(widget.actionWidgetMap!.keys.map((T element) {
        return CupertinoActionSheetAction(
            onPressed: () {
              Get.back(result: element);
            },
            child: widget.actionWidgetMap![element] ?? const SizedBox());
      }).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    Future<T?> _showDialog(BuildContext context) {
      return showCupertinoModalPopup<T>(
          context: context,
          builder: (BuildContext context) {
            final EhActionSheet dialog = EhActionSheet(
              title: Text(widget.actionTitle ?? widget.title),
              cancelButton: CupertinoActionSheetAction(
                  onPressed: () {
                    Get.back();
                  },
                  child: Text(L10n.of(context).cancel)),
              actions: _getActionList(),
            );
            return dialog;
          });
    }

    return SelectorSettingItem(
      title: widget.title,
      hideDivider: widget.hideDivider,
      selector: selector,
      titleFlex: widget.titleFlex,
      valueFlex: widget.valueFlex,
      // maxLines: 3,
      onTap: () async {
        // 显示dialog 选择选项
        final T? _result = await _showDialog(context);
        if (_result != null) {
          // 结果回调
          setState(() {
            selector = widget.simpleActionMap?[_result] ??
                widget.actionMap[_result] ??
                '';
          });
          widget.onValueChanged?.call(_result);
        }
      },
    );
  }
}

class SelectorCupertinoListTile<T> extends StatefulWidget {
  const SelectorCupertinoListTile({
    super.key,
    required this.title,
    this.actionTitle,
    required this.actionMap,
    this.simpleActionMap,
    required this.initVal,
    this.onValueChanged,
    this.actionWidgetMap,
    this.subtitleMap,
  });
  final String title;
  final String? actionTitle;
  final Map<T, String> actionMap;
  final Map<T, String>? simpleActionMap;

  /// A second line under each choice in the menu.
  final Map<T, String>? subtitleMap;
  final T initVal;
  final ValueChanged<T>? onValueChanged;

  /// Choices that need a preview keep the action sheet; plain choices open a
  /// pull-down menu from the value.
  final Map<T, Widget>? actionWidgetMap;

  @override
  _SelectorCupertinoListTileState<T> createState() =>
      _SelectorCupertinoListTileState<T>();
}

class _SelectorCupertinoListTileState<T>
    extends State<SelectorCupertinoListTile<T>> {
  final GlobalKey<SettingMenuButtonState<T>> _menu =
      GlobalKey<SettingMenuButtonState<T>>();
  late T _value;

  String get selector =>
      widget.simpleActionMap?[_value] ?? widget.actionMap[_value] ?? '';

  @override
  void initState() {
    super.initState();
    _value = widget.initVal;
  }

  @override
  void didUpdateWidget(SelectorCupertinoListTile<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initVal != widget.initVal) {
      _value = widget.initVal;
    }
  }

  void _select(T value) {
    setState(() => _value = value);
    widget.onValueChanged?.call(value);
  }

  List<Widget> _getActionList() {
    return List<Widget>.from(widget.actionWidgetMap!.keys.map((T element) {
      return CupertinoActionSheetAction(
          onPressed: () {
            Get.back(result: element);
          },
          child: widget.actionWidgetMap![element] ?? const SizedBox());
    }).toList());
  }

  Future<void> _showSheet(BuildContext context) async {
    final T? result = await showCupertinoModalPopup<T>(
        context: context,
        builder: (BuildContext context) {
          return EhActionSheet(
            title: Text(widget.actionTitle ?? widget.title),
            cancelButton: CupertinoActionSheetAction(
                onPressed: () {
                  Get.back();
                },
                child: Text(L10n.of(context).cancel)),
            actions: _getActionList(),
          );
        });
    if (result != null) {
      _select(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.actionWidgetMap != null) {
      return Semantics(
        button: true,
        label: widget.title,
        value: selector,
        excludeSemantics: true,
        onTap: () => _showSheet(context),
        child: EhCupertinoListTile(
          title: Text(widget.title),
          additionalInfo: Text(selector, textAlign: TextAlign.right),
          trailing: const CupertinoListTileChevron(),
          onTap: () => _showSheet(context),
        ),
      );
    }
    return Semantics(
      button: true,
      label: widget.title,
      value: selector,
      excludeSemantics: true,
      onTap: () => _menu.currentState?.open(),
      child: EhCupertinoListTile(
        title: Text(widget.title),
        additionalInfo: SettingMenuButton<T>(
          key: _menu,
          label: selector,
          selected: _value,
          onSelected: _select,
          options: [
            for (final entry in widget.actionMap.entries)
              SettingMenuOption<T>(
                value: entry.key,
                label: entry.value,
                subtitle: widget.subtitleMap?[entry.key],
              ),
          ],
        ),
        onTap: () => _menu.currentState?.open(),
      ),
    );
  }
}
