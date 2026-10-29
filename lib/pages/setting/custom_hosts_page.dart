import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/common/service/dns_service.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/component/setting_base.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/widget/cupertino/list_tile.dart';
import 'package:eros_fe/widget/cupertino/sliver_list_section.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:sliver_tools/sliver_tools.dart';

class CustomHostsPage extends StatelessWidget {
  const CustomHostsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String _title = L10n.of(context).custom_hosts;
    final DnsService dnsConfigController = Get.find();

    return SettingScaffold(
      title: _title,
      actions: [
        NativeNavigationAction(
          id: 'customHosts.add',
          title: L10n.of(context).add,
          symbol: 'plus',
          onPressed: () => showCustomHostEditer(context),
        ),
      ],
      trailing: _buildListBtns(context),
      child: CustomScrollView(slivers: [
        SliverSafeArea(
          sliver: MultiSliver(children: [
            SliverCupertinoListSection.listInsetGrouped(children: [
              EhCupertinoListTile(
                title: Text(_title),
                trailing: Obx(() => CupertinoSwitch(
                      value: dnsConfigController.enableCustomHosts,
                      onChanged: (bool value) =>
                          dnsConfigController.enableCustomHosts = value,
                    )),
              ),
            ]),
            CustomHostsListView(),
          ]),
        ),
      ]),
    );
  }

  Widget _buildListBtns(BuildContext context) {
    return CupertinoButton(
        minSize: 40,
        padding: const EdgeInsets.only(right: 20),
        child: const FaIcon(
          FontAwesomeIcons.plusCircle,
          size: 20,
        ),
        onPressed: () {
          showCustomHostEditer(context);
        });
  }
}

/// The hosts as one section; swipe a row to delete it.
class CustomHostsListView extends StatelessWidget {
  final DnsService dnsConfigController = Get.find();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final List<DnsCache> hosts = dnsConfigController.hosts.toList();
      if (hosts.isEmpty) {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }
      return SliverCupertinoListSection.listInsetGrouped(children: [
        for (int index = 0; index < hosts.length; index++)
          Slidable(
            key: ValueKey<String>('host_${hosts[index].host}_$index'),
            endActionPane: ActionPane(
              motion: const ScrollMotion(),
              extentRatio: 0.25,
              children: [
                SlidableAction(
                  onPressed: (_) =>
                      dnsConfigController.removeCustomHostAt(index),
                  backgroundColor: CupertinoDynamicColor.resolve(
                      CupertinoColors.systemRed, context),
                  foregroundColor: Colors.white,
                  icon: Icons.delete,
                  label: L10n.of(context).delete,
                ),
              ],
            ),
            child: CuttomHostItem(
              index: index,
              host: hosts[index].host ?? '',
              addr: hosts[index].addr ?? '',
            ),
          ),
      ]);
    });
  }
}

class CuttomHostItem extends StatelessWidget {
  const CuttomHostItem({
    Key? key,
    required this.host,
    required this.addr,
    required this.index,
  }) : super(key: key);
  final String host;
  final String addr;
  final int index;

  @override
  Widget build(BuildContext context) {
    return EhCupertinoListTile(
      title: Text(host),
      subtitle: addr.isEmpty ? null : Text(addr),
      trailing: const CupertinoListTileChevron(),
      onTap: () {
        showCustomHostEditer(context, index: index);
      },
    );
  }
}
