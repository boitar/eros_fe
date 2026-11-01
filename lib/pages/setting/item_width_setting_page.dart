import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/setting/card_size_preview.dart';
import 'package:eros_fe/pages/setting/setting_items/selector_Item.dart';
import 'package:eros_fe/pages/tab/view/list/card_size.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:sliver_tools/sliver_tools.dart';

/// 卡片大小: five steps for each list style that lays cards out in columns,
/// with the columns each gives on this device drawn underneath.
class ItemWidthSettingPage extends StatefulWidget {
  const ItemWidthSettingPage({super.key, this.screen});

  /// The screen the preview draws; the current display when null.
  final Size? screen;

  @override
  State<ItemWidthSettingPage> createState() => _ItemWidthSettingPageState();
}

class _ItemWidthSettingPageState extends State<ItemWidthSettingPage> {
  EhSettingService get _ehSettingService => Get.find();
  late ListModeEnum _mode;

  @override
  void initState() {
    super.initState();
    final mode = _ehSettingService.listMode.value;
    _mode = CardSize.modes.contains(mode) ? mode : ListModeEnum.waterfallLarge;
  }

  int _step(BuildContext context) =>
      CardSize.of(_mode, _ehSettingService.getItemConfig(_mode),
          phone: context.isPhone);

  void _pick(BuildContext context, int step) {
    if (step == _step(context)) {
      return;
    }
    vibrateUtil.selection();
    _ehSettingService.setItemConfig(
        _mode, (ItemConfig config) => config.copyWith(cardSize: step.oN));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final step = _step(context);
    final divider = Get.isRegistered<LayoutServices>()
        ? Get.find<LayoutServices>().sideProportion
        : 0.0;
    return SettingScaffold(
      title: l10n.card_size,
      child: CustomScrollView(
        slivers: [
          SliverSafeArea(
            left: false,
            right: false,
            sliver: MultiSliver(
              children: [
                SliverCupertinoListSection.listInsetGrouped(children: [
                  _buildListModeItem(
                    context,
                    initMode: _mode,
                    onValueChanged: (mode) => setState(() => _mode = mode),
                  ),
                ]),
                SliverCupertinoListSection.listInsetGrouped(
                  footer: Text(l10n.card_size_footer),
                  children: [
                    CardSizeSlider(
                      step: step,
                      onChanged: (step) => _pick(context, step),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                      child: CardSizePreview(
                        mode: _mode,
                        step: step,
                        divider: divider,
                        immersive: _mode == ListModeEnum.waterfallLarge &&
                            _ehSettingService.immersiveLargeCards,
                        screen: widget.screen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 列表模式切换
Widget _buildListModeItem(
  BuildContext context, {
  required ListModeEnum initMode,
  ValueChanged<ListModeEnum>? onValueChanged,
}) {
  final String _title = L10n.of(context).list_mode;

  final Map<ListModeEnum, String> modeMap = <ListModeEnum, String>{
    ListModeEnum.waterfallLarge: L10n.of(context).listmode_waterfall_large,
    ListModeEnum.waterfall: L10n.of(context).listmode_waterfall,
    ListModeEnum.grid: L10n.of(context).listmode_grid,
    ListModeEnum.gridTags: L10n.of(context).listmode_grid_tags,
  };
  return SelectorCupertinoListTile<ListModeEnum>(
    title: _title,
    actionMap: modeMap,
    initVal: initMode,
    onValueChanged: onValueChanged,
  );
}
