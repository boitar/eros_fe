import 'dart:convert';
import 'dart:io';

import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/debug/offline_acceptance.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/store/hive/hive.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as path;

const offlineHapticsAcceptanceEnabled =
    offlineAcceptanceEnabled && bool.fromEnvironment('EROS_HAPTICS_ACCEPTANCE');

String _probeIdentifier = 'offline-haptics-pending';
String _probeLabel = 'Offline haptics pending';

Widget offlineHapticsControl(Widget child) => !offlineHapticsAcceptanceEnabled
    ? child
    : Semantics(identifier: 'offline-haptics-toggle', child: child);

Widget offlineHapticsOverlay(Widget child) {
  if (!offlineHapticsAcceptanceEnabled) {
    return child;
  }
  return Stack(textDirection: TextDirection.ltr, children: [
    child,
    Positioned(
        top: 0,
        left: 0,
        child: Semantics(
            textDirection: TextDirection.ltr,
            container: true,
            identifier: _probeIdentifier,
            label: _probeLabel,
            child: const SizedBox(width: 1, height: 1)))
  ]);
}

Future<void> initializeOfflineHaptics() async {
  if (!offlineHapticsAcceptanceEnabled) {
    return;
  }
  if (Global.profile.user.memberId?.isNotEmpty ?? false) {
    throw StateError('Haptics acceptance requires an empty isolated account');
  }
  final marker = File(path.join(Global.appDocPath, 'offline-haptics-seeded'));
  final seeded = await marker.exists();
  Global.profile = Global.profile.copyWith(
      locale: 'zh_CN',
      ehConfig: Global.profile.ehConfig
          .copyWith(listMode: 'list', vibrate: seeded ? null : true.oN),
      customTabConfig: const CustomTabConfig(lastIndex: 0, profiles: [
        CustomProfile(
            uuid: 'offline-haptics', name: 'Offline', searchText: ['neutral'])
      ]).oN,
      tabConfig: TabConfig(
          tabItemList: List<TabItem>.of(const [
        TabItem(name: EHRoutes.gallery, enable: true),
        TabItem(name: EHRoutes.favorite, enable: false),
        TabItem(name: EHRoutes.toplist, enable: false),
        TabItem(name: EHRoutes.download, enable: false),
        TabItem(name: EHRoutes.history, enable: false),
      ])).oN);
  if (!seeded) {
    await Hive.box<String>(configBox)
        .put(profileKey, jsonEncode(Global.profile));
    await Hive.box<String>(configBox).flush();
    await marker.writeAsString('Only this isolated acceptance installation');
  }
}

Future<void> probeOfflineHaptics() async {
  if (!offlineHapticsAcceptanceEnabled) {
    return;
  }
  const bridge = MethodChannel('eros/haptics');
  try {
    final enabled = Get.find<EhSettingService>().vibrate.value;
    final before = await bridge.invokeMapMethod<String, dynamic>('debugState');
    await vibrateUtil.impact();
    await vibrateUtil.light();
    await vibrateUtil.medium();
    await vibrateUtil.heavy();
    await vibrateUtil.success();
    await vibrateUtil.error();
    await vibrateUtil.prepareHaptics();
    await vibrateUtil.pullTick(.2);
    await vibrateUtil.pullTick(.8);
    final after = await bridge.invokeMapMethod<String, dynamic>('debugState');
    final prepares = (after!['acceptedPrepares'] as int) -
        (before!['acceptedPrepares'] as int);
    final ticks =
        (after['acceptedTicks'] as int) - (before['acceptedTicks'] as int);
    final feedback = (after['acceptedFeedback'] as int) -
        (before['acceptedFeedback'] as int);
    final expectedFeedback = enabled ? 6 : 0;
    final expectedPrepares = enabled ? 1 : 0;
    final expectedTicks = enabled ? 2 : 0;
    if (prepares != expectedPrepares ||
        ticks != expectedTicks ||
        feedback != expectedFeedback) {
      throw StateError(
          'Unexpected bridge deltas $prepares/$ticks, enabled=$enabled');
    }
    _probeIdentifier = 'offline-haptics-ready-${enabled ? 'on' : 'off'}';
    _probeLabel =
        'Offline haptics ready: enabled=$enabled; accepted prepare=$prepares; '
        'accepted tick=$ticks; accepted feedback=$feedback; hardware=${after['supportsHaptics']}';
  } catch (error) {
    _probeIdentifier = 'offline-haptics-probe-error';
    _probeLabel = 'Offline haptics probe error: $error';
  }
}
