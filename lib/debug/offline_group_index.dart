import 'dart:convert';
import 'dart:io';

import 'package:eros_fe/debug/offline_acceptance.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/store/hive/hive.dart';
import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as path;

const offlineGroupIndexAcceptanceEnabled = offlineAcceptanceEnabled &&
    bool.fromEnvironment('EROS_GROUP_INDEX_ACCEPTANCE');

Widget offlineGroupControl(String name, Widget child) =>
    !offlineGroupIndexAcceptanceEnabled
        ? child
        : Semantics(identifier: 'offline-group-control-$name', child: child);

Widget offlineGroupSelection(
    {required String uuid, required int index, required Widget child}) {
  if (!offlineGroupIndexAcceptanceEnabled) {
    return child;
  }
  return Stack(children: [
    child,
    Positioned(
        top: 0,
        left: 0,
        child: Semantics(
            container: true,
            identifier: 'offline-group-selection-$uuid-$index',
            label: 'Offline group selection $uuid $index',
            child: const SizedBox(width: 1, height: 1)))
  ]);
}

Future<void> initializeOfflineGroupIndex() async {
  if (!offlineGroupIndexAcceptanceEnabled) {
    return;
  }
  if (Global.profile.user.memberId?.isNotEmpty ?? false) {
    throw StateError('Group acceptance requires an isolated empty account');
  }
  final marker = File(path.join(Global.appDocPath, 'offline-group-seeded'));
  Global.profile = Global.profile.copyWith(
      locale: 'zh_CN',
      ehConfig: Global.profile.ehConfig.copyWith(listMode: 'list'),
      tabConfig: TabConfig(
          tabItemList: List<TabItem>.of(const [
        TabItem(name: EHRoutes.gallery, enable: true),
        TabItem(name: EHRoutes.favorite, enable: false),
        TabItem(name: EHRoutes.toplist, enable: false),
        TabItem(name: EHRoutes.download, enable: false),
        TabItem(name: EHRoutes.history, enable: false),
      ])).oN);
  if (await marker.exists()) {
    return;
  }
  Global.profile = Global.profile.copyWith(
      customTabConfig: CustomTabConfig(lastIndex: 1, profiles: [
    for (final id in ['a', 'b', 'c', 'd'])
      CustomProfile(
          uuid: 'offline-$id',
          name: 'Group ${id.toUpperCase()}',
          hideTab: id == 'b',
          searchText: ['offline_group_$id']),
  ]).oN);
  // Persist once. Later launches must restore actual mutations and lastIndex.
  await Hive.box<String>(configBox).put(profileKey, jsonEncode(Global.profile));
  await Hive.box<String>(configBox).flush();
  await marker.writeAsString('Only this isolated acceptance installation');
}
