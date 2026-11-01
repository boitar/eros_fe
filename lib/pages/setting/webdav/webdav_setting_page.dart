import 'package:eros_fe/common/controller/webdav_controller.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:sliver_tools/sliver_tools.dart';

class WebDavSetting extends GetView<WebdavController> {
  const WebDavSetting({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const String _title = 'WebDAV';
    return Obx(() => SettingScaffold(
          title: _title,
          actions: [
            if (!controller.validAccount)
              NativeNavigationAction(
                id: 'webdav.account',
                title: L10n.of(context).webdav_Account,
                symbol: 'person.badge.plus',
                onPressed: _addAccount,
              ),
          ],
          trailing: _buildListButtons(context),
          child: Obx(() {
            return controller.validAccount
                ? const WebDavSettingView()
                : Container();
          }),
        ));
  }

  Future<void> _addAccount() async {
    final result = await Get.toNamed(
      EHRoutes.loginWebDAV,
      id: detailNavigatorId,
    );
    if (result != null && result is bool && result) {
      Get.back();
    }
  }

  Widget _buildListButtons(BuildContext context) {
    return Obx(() {
      return Container(
        child: controller.validAccount
            ? const SizedBox.shrink()
            : CupertinoButton(
                minSize: 40,
                padding: const EdgeInsets.all(0),
                child: const Icon(
                  CupertinoIcons.person_add,
                  size: 26,
                ),
                onPressed: _addAccount,
              ),
      );
    });
  }
}

class WebDavSettingView extends GetView<WebdavController> {
  const WebDavSettingView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverSafeArea(
          sliver: MultiSliver(
            children: [
              SliverCupertinoListSection.listInsetGrouped(
                children: [
                  EhCupertinoListTile(
                    title: Text(L10n.of(context).webdav_Account),
                    subtitle: Text(controller.webdavProfile.user ?? ''),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () {
                      showCupertinoDialog(
                        context: context,
                        builder: (context) {
                          return EhAlertDialog(
                            title: Text('Logout?'),
                            actions: <Widget>[
                              CupertinoDialogAction(
                                child: Text(L10n.of(context).cancel),
                                onPressed: () {
                                  Get.back();
                                },
                              ),
                              CupertinoDialogAction(
                                child: Text(L10n.of(context).ok),
                                onPressed: () async {
                                  // 登出WebDAV
                                  Global.profile = Global.profile.copyWith(
                                      webdav: const WebdavProfile(url: '').oN);
                                  Global.saveProfile();
                                  controller.initClient();
                                  controller.closeClient();
                                  Get.back();
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
              SliverCupertinoListSection.listInsetGrouped(
                children: [
                  EhCupertinoSwitchListTile(
                    title: Text(L10n.of(context).sync_history),
                    value: controller.syncHistory,
                    onChanged: (val) {
                      controller.syncHistory = val;
                    },
                  ),
                  EhCupertinoSwitchListTile(
                    title: Text(L10n.of(context).sync_read_progress),
                    value: controller.syncReadProgress,
                    onChanged: (val) {
                      controller.syncReadProgress = val;
                    },
                  ),
                  EhCupertinoSwitchListTile(
                    title: Text(L10n.of(context).sync_group),
                    value: controller.syncGroupProfile,
                    onChanged: (val) {
                      controller.syncGroupProfile = val;
                    },
                  ),
                  EhCupertinoSwitchListTile(
                    title: Text(L10n.of(context).sync_quick_search),
                    value: controller.syncQuickSearch,
                    onChanged: (val) {
                      controller.syncQuickSearch = val;
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
