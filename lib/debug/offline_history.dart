import 'dart:io';

import 'package:eros_fe/debug/offline_acceptance.dart';
import 'package:eros_fe/index.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;

const offlineHistoryAcceptanceEnabled =
    offlineAcceptanceEnabled && bool.fromEnvironment('EROS_HISTORY_ACCEPTANCE');

Widget offlineHistorySliver({
  required bool initialized,
  required int count,
  required Widget sliver,
}) {
  if (!offlineHistoryAcceptanceEnabled) {
    return sliver;
  }
  // Native tests must observe a completed real read before asserting an empty
  // list. Absence of a row alone can pass during the initial loading frame.
  return SliverMainAxisGroup(slivers: [
    SliverToBoxAdapter(
      child: Semantics(
        container: true,
        identifier: initialized
            ? 'offline-history-ready-$count'
            : 'offline-history-loading',
        label: initialized
            ? 'Offline history ready $count'
            : 'Offline history loading',
        child: const SizedBox(height: 1, width: 1),
      ),
    ),
    sliver,
  ]);
}

Future<void> initializeOfflineHistory() async {
  if (!offlineHistoryAcceptanceEnabled) {
    return;
  }
  if (Global.profile.user.memberId?.isNotEmpty ?? false) {
    throw StateError('History acceptance requires an isolated empty account');
  }
  Global.profile = Global.profile.copyWith(
    locale: 'zh_CN',
    ehConfig: Global.profile.ehConfig.copyWith(listMode: 'list'),
    tabConfig: TabConfig(
      // Tab initialization may append routes from the current application.
      tabItemList: List<TabItem>.of(const [
        TabItem(name: EHRoutes.history, enable: true),
        TabItem(name: EHRoutes.gallery, enable: false),
        TabItem(name: EHRoutes.favorite, enable: false),
        TabItem(name: EHRoutes.toplist, enable: false),
        TabItem(name: EHRoutes.download, enable: false),
      ]),
    ).oN,
  );
  final marker = File(path.join(Global.appDocPath, 'offline-history-seeded'));
  if (await marker.exists()) {
    return;
  }
  await isarHelper.addHistoriesAsync([
    for (var index = 1; index <= 8; index++)
      GalleryProvider(
        gid: '${9333000 + index}',
        token: 'offline-fixture',
        englishTitle: 'Offline history entry $index - neutral history fixture',
        imgUrl: 'http://127.0.0.1/offline-cover/$index.png',
        imgWidth: 200,
        imgHeight: 280,
        filecount: '1',
        category: 'Non-H',
        lastViewTime: 1767225610000 + index,
      ),
  ]);
  await marker.writeAsString('Only this isolated acceptance installation');
}
