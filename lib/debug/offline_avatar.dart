import 'dart:convert';
import 'dart:io';

import 'package:eros_fe/debug/offline_acceptance.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/store/hive/hive.dart';
import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as path;

const offlineAvatarAcceptanceEnabled =
    offlineAcceptanceEnabled && bool.fromEnvironment('EROS_AVATAR_ACCEPTANCE');

Future<void> initializeOfflineAvatar() async {
  if (!offlineAvatarAcceptanceEnabled) {
    return;
  }
  final user = Global.profile.user;
  if ((user.memberId?.isNotEmpty ?? false) &&
      user.memberId != 'offline-avatar') {
    throw StateError('Avatar acceptance needs a fresh isolated installation');
  }
  final seeded = user.memberId == 'offline-avatar';
  Global.profile = Global.profile.copyWith(
    locale: 'zh_CN',
    user: seeded
        ? user
        : const User(
            memberId: 'offline-avatar',
            passHash: 'offline-fixture-only',
            username: 'Offline',
            nickName: 'Offline',
            avatarUrl: '',
          ),
    ehConfig: Global.profile.ehConfig.copyWith(listMode: 'list'),
    customTabConfig: const CustomTabConfig(lastIndex: 0, profiles: [
      CustomProfile(
          uuid: 'offline-avatar', name: 'Offline', searchText: ['neutral'])
    ]).oN,
  );
  await Hive.box<String>(configBox).put(profileKey, jsonEncode(Global.profile));
  await Hive.box<String>(configBox).flush();
  await File(path.join(Global.appDocPath, 'Avatar Fixture.png')).writeAsBytes(
      base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8'
          '/x8AAwMCAO+ip1sAAAAASUVORK5CYII='));
}

Widget offlineAvatarPreview(String? url, Widget child) {
  if (!offlineAvatarAcceptanceEnabled) {
    return child;
  }
  final local = url != null && url.startsWith('/') && File(url).existsSync();
  return Semantics(
    key: ValueKey<String>(url ?? ''),
    container: true,
    identifier: 'offline-avatar-ready-${local ? "local" : "empty"}',
    label:
        'Offline avatar ${local ? "local file preview" : "no local file"};file=${url ?? ""}',
    child: child,
  );
}
