import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/setting/controller/eh_mytags_controller.dart';
import 'package:eros_fe/pages/setting/webview/eh_tagset_edit_dialog.dart';
import 'package:eros_fe/pages/setting/webview/mytags_in.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:sliver_tools/sliver_tools.dart';

class EhMyTagsPage extends GetView<EhMyTagsController> {
  const EhMyTagsPage({super.key});

  @override
  Widget build(BuildContext context) {
    void openWebsite() => Get.to(() => InWebMyTags());

    Future<void> addTagset() async {
      final newName = await showCupertinoDialog<String>(
          context: context,
          barrierDismissible: true,
          builder: (context) {
            return const EhTagSetEditDialog(
              text: '',
              title: 'New Tagset',
            );
          });
      if (newName != null && newName.isNotEmpty) {
        controller.crtNewTagset(name: newName);
      }
    }

    return SettingScaffold(
      title: L10n.of(context).ehentai_my_tags,
      actions: [
        NativeNavigationAction(
          id: 'mytags.website',
          title: L10n.of(context).mytags_on_website,
          symbol: 'globe',
          onPressed: openWebsite,
        ),
        NativeNavigationAction(
          id: 'mytags.add',
          title: L10n.of(context).add,
          symbol: 'plus',
          onPressed: addTagset,
        ),
      ],
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CupertinoButton(
            padding: const EdgeInsets.all(0),
            minSize: 40,
            child: const FaIcon(
              FontAwesomeIcons.earthAmericas,
              size: 22,
            ),
            onPressed: openWebsite,
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(0),
            minSize: 40,
            child: const Icon(
              CupertinoIcons.plus_circle,
              size: 28,
            ),
            onPressed: addTagset,
          ),
        ],
      ),
      child: CustomScrollView(
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: EhCupertinoSliverRefreshControl(
              onRefresh: controller.reloadData,
            ),
          ),
          SliverSafeArea(
            top: false,
            sliver: MultiSliver(
              children: [
                controller.obx(
                  (state) {
                    if (state == null) {
                      return const SizedBox.shrink();
                    }

                    return SliverCupertinoListSection.insetGrouped(
                      itemBuilder: (context, index) {
                        final e = state[index];

                        return EhCupertinoListTile(
                          title: Text(e.name),
                          additionalInfo: Text('${e.tagCount}'),
                          trailing: const CupertinoListTileChevron(),
                          onTap: () async {
                            if (controller.currSelected != e.value) {
                              controller.currSelected = e.value ?? '';
                              // await controller.reloadData();
                            }
                            Get.toNamed(
                              EHRoutes.userTags,
                              id: detailNavigatorId,
                            );
                          },
                        );
                        // return _list[index];
                      },
                      itemCount: state.length,
                    );
                  },
                  onLoading: const SliverFillRemaining(
                    child: Center(
                      child: CupertinoActivityIndicator(
                        radius: 16,
                      ),
                    ),
                  ),
                  onEmpty: CustomScrollView(
                    slivers: [
                      EhCupertinoSliverRefreshControl(
                        onRefresh: controller.reloadData,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
