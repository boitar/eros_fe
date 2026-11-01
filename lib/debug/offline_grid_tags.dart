import 'dart:convert';
import 'dart:io';

import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/debug/offline_acceptance.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/tab/view/list/card_size.dart';
import 'package:eros_fe/store/hive/hive.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as path;

const offlineGridTagsAcceptanceEnabled = offlineAcceptanceEnabled &&
    bool.fromEnvironment('EROS_GRID_TAGS_ACCEPTANCE');

Future<void> initializeOfflineGridTags() async {
  if (!offlineGridTagsAcceptanceEnabled) {
    return;
  }
  if (Global.profile.user.memberId?.isNotEmpty ?? false) {
    throw StateError('Grid acceptance requires an empty isolated account');
  }
  final marker = File(path.join(Global.appDocPath, 'offline-grid-tags-seeded'));
  final seeded = await marker.exists();
  Global.profile = Global.profile.copyWith(
    locale: 'zh_CN',
    ehConfig:
        Global.profile.ehConfig.copyWith(listMode: seeded ? null : 'gridTags'),
    customTabConfig: const CustomTabConfig(lastIndex: 0, profiles: [
      CustomProfile(
          uuid: 'offline-grid-tags', name: 'Offline', searchText: ['neutral'])
    ]).oN,
  );
  await Hive.box<String>(configBox).put(profileKey, jsonEncode(Global.profile));
  await Hive.box<String>(configBox).flush();
  if (!seeded) {
    await marker.writeAsString('Only this isolated acceptance installation');
  }
}

Widget offlineGridTagsOverlay(Widget child) {
  if (!offlineGridTagsAcceptanceEnabled) {
    return child;
  }
  return Stack(textDirection: TextDirection.ltr, children: [
    child,
    Positioned(
        top: 0,
        left: 0,
        child: Obx(() {
          final settings = Get.find<EhSettingService>();
          final mode = settings.listMode.value;
          final size = CardSize.of(mode, settings.getItemConfig(mode));
          final custom = size != CardSize.standard;
          return Semantics(
              key: ValueKey<String>('${mode.name}:$size'),
              textDirection: TextDirection.ltr,
              container: true,
              identifier:
                  'offline-grid-ready-${mode.name}-${custom ? "custom" : "default"}',
              label:
                  'Offline grid mode=${mode.name} custom=$custom size=$size',
              child: const SizedBox(width: 1, height: 1));
        })),
  ]);
}
