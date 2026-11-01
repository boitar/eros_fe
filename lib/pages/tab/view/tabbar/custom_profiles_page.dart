import 'package:eros_fe/common/controller/webdav_controller.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/debug/offline_group_index.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/tab/controller/group/custom_tabbar_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:reorderables/reorderables.dart';

class CustomProfilesPage extends GetView<CustomTabbarController> {
  const CustomProfilesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Widget shortDivider = Container(
      margin: const EdgeInsetsDirectional.only(start: 20),
      color: CupertinoColors.separator.resolveFrom(context),
      height: 0.5,
    );

    Widget buildNormalItem(CustomProfile element, {bool isLast = false}) {
      Widget buildTile({Key? key}) => EhCupertinoListTile(
            key: key,
            title: Text(element.name),
            trailing: const CupertinoListTileChevron(),
            onTap: () {
              controller.toEditPage(uuid: element.uuid);
            },
          );

      return Slidable(
        key: ValueKey(element.uuid),
        endActionPane: ActionPane(
          extentRatio: 0.25,
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => controller.deleteProfile(uuid: element.uuid),
              backgroundColor: CupertinoDynamicColor.resolve(
                  CupertinoColors.systemRed, context),
              foregroundColor: Colors.white,
              icon: CupertinoIcons.delete,
              // label: L10n.of(context).delete,
            ),
          ],
        ),
        child: isLast
            ? buildTile(key: ValueKey(element.uuid))
            : Column(
                key: ValueKey(element.uuid),
                children: [
                  buildTile(),
                  shortDivider,
                ],
              ),
      );
    }

    Widget buildReorderableItem(CustomProfile element, {bool isLast = false}) {
      Widget _tile({Key? key}) => EhCupertinoListTile(
            key: key,
            trailing: const Icon(CupertinoIcons.bars),
            title: Text(element.name),
          );

      if (isLast) {
        return _tile(key: ValueKey(element.uuid));
      } else {
        return Column(
          key: ValueKey(element.uuid),
          children: [
            _tile(),
            shortDivider,
          ],
        );
      }
    }

    Widget normalView = Obx(() {
      return Column(
        children: () {
          final List<Widget> _list = <Widget>[];
          for (var i = 0; i < controller.profiles.length; i++) {
            _list.add(buildNormalItem(controller.profiles[i],
                isLast: i == controller.profiles.length - 1));
          }
          return _list;
        }(),
      );
    });

    Widget reorderableView = Obx(() {
      return ReorderableColumn(
        onReorder: controller.onReorder,
        children: () {
          final List<Widget> _list = <Widget>[];
          for (var i = 0; i < controller.profiles.length; i++) {
            _list.add(buildReorderableItem(controller.profiles[i],
                isLast: i == controller.profiles.length - 1));
          }
          return _list;
        }(),
      );
    });

    return WillPopScope(
      onWillPop: () async {
        controller.reorderable = false;
        return true;
      },
      child: SettingScaffold(
        title: L10n.of(context).group,
        // Beside an open group the list keeps its own buttons.
        nativeChrome: false,
        trailing: Obx(() {
          final reorderable = controller.reorderable;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (Get.find<WebdavController>().syncGroupProfile && !reorderable)
                CupertinoButton(
                  minSize: 40,
                  padding: EdgeInsets.zero,
                  onPressed: controller.syncProfiles,
                  child:
                      const Icon(CupertinoIcons.arrow_2_circlepath, size: 22),
                ),
              offlineGroupControl(
                'reorder',
                CupertinoButton(
                  minSize: 40,
                  padding: EdgeInsets.zero,
                  onPressed: () => controller.reorderable = !reorderable,
                  child: Icon(
                    reorderable
                        ? CupertinoIcons.checkmark
                        : CupertinoIcons.arrow_up_arrow_down,
                    size: 22,
                  ),
                ),
              ),
              if (!reorderable)
                CupertinoButton(
                  minSize: 40,
                  padding: EdgeInsets.zero,
                  onPressed: controller.toEditPage,
                  child: const Icon(CupertinoIcons.add, size: 22),
                ),
            ],
          );
        }),
        child: CustomScrollView(
          slivers: [
            SliverSafeArea(
              sliver: SliverCupertinoListSection.listInsetGrouped(children: [
                Obx(() {
                  return Column(
                    children: [
                      AnimatedCrossFade(
                        secondChild: normalView,
                        firstChild: reorderableView,
                        crossFadeState: controller.reorderable
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                        duration: 300.milliseconds,
                      ),
                    ],
                  );
                }),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
