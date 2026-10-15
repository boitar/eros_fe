import 'dart:async';

import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/extension.dart';
import 'package:eros_fe/models/index.dart';
import 'package:eros_fe/pages/tab/controller/favorite/favorite_tabbar_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class Settings extends GetxService implements EhSettingService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('$invocation');
}

class FavoriteTabs extends GetxController implements FavoriteTabBarController {
  int initializations = 0;
  @override
  void onInit() {
    initializations++;
    super.onInit();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('$invocation');
}

class AccountController extends UserController {
  AccountController(
      {super.loadAvatarProfile, super.saveAvatarFile, super.uploadAvatar});
  @override
  Worker everProfile<T>(RxInterface<T> listener, ValueChanged<T> onChange) =>
      ever(listener, onChange);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final original = Global.profile;
  const a =
      User(memberId: 'fixture-a', passHash: 'offline-a', avatarUrl: 'a.png');
  const b =
      User(memberId: 'fixture-b', passHash: 'offline-b', avatarUrl: 'b.png');
  setUp(() {
    Get.testMode = true;
    Get.put<EhSettingService>(Settings());
    Global.profile = kDefProfile.copyWith(user: a);
  });
  tearDown(() async {
    Get.reset();
    Global.profile = original;
  });
  AccountController mount(AccountController controller) => Get.put(controller);

  test(
      'avatar metadata keeps cached favorite pages; an account change resets them',
      () {
    final tabs = FavoriteTabs();
    Get.put<FavoriteTabBarController>(tabs);
    final c = mount(AccountController());
    final before = tabs.initializations;
    c.setLocalAvatarPath('new-local.png');
    expect(tabs.initializations, before);
    c.user(b);
    expect(tabs.initializations, before + 1);
  });

  test('avatar metadata preserves newer persisted favorite categories', () {
    final tabs = FavoriteTabs();
    Get.put<FavoriteTabBarController>(tabs);
    final c = mount(AccountController());
    final before = tabs.initializations;
    final latest = [
      const Favcat(favId: '2', favTitle: 'Updated neutral folder', totNum: 7)
    ];
    Global.profile = Global.profile
        .copyWith(user: Global.profile.user.copyWith(favcat: latest.oN));
    c.setLocalAvatarPath('new-local.png');
    expect(Global.profile.user.favcat, latest);
    expect(c.user.value.favcat, latest);
    expect(tabs.initializations, before);
  });

  test('late copied avatar cannot replace another account', () async {
    final copy = Completer<String>();
    String? owner;
    final c = mount(AccountController(saveAvatarFile: (path, id) {
      owner = id;
      return copy.future;
    }));
    final pending = c.setLocalAvatar('chosen.png');
    final rejected = expectLater(pending, throwsA(anything));
    c.user(b);
    copy.complete('stored-a.png');
    await rejected;
    expect(owner, 'fixture-a');
    expect(c.user.value.avatarUrl, 'b.png');
  });
  test('late profile refresh cannot overwrite a changed account', () async {
    final load = Completer<User?>();
    final c = mount(AccountController(loadAvatarProfile: (_) => load.future));
    final pending = c.refreshOwnUserInfo();
    final rejected = expectLater(pending, throwsA(anything));
    c.user(b);
    load.complete(const User(avatarUrl: 'late-a.png'));
    await rejected;
    expect(c.user.value.avatarUrl, 'b.png');
  });
  test('switch away and back invalidates an open picker token', () {
    final c = mount(AccountController());
    final token = c.captureAvatarAccount();
    c.user(b);
    c.user(a);
    expect(() => c.setLocalAvatarPath('stale.png', account: token),
        throwsA(anything));
    expect(c.user.value.avatarUrl, 'a.png');
  });
  test('newer local choice wins over an earlier remote refresh', () async {
    final load = Completer<User?>();
    final c = mount(AccountController(loadAvatarProfile: (_) => load.future));
    final pending = c.refreshOwnUserInfo();
    c.setLocalAvatarPath('new-local.png');
    load.complete(const User(avatarUrl: 'old-remote.png'));
    await pending;
    expect(c.user.value.avatarUrl, 'new-local.png');
  });
  test('newer copy wins when two local saves complete out of order', () async {
    final old = Completer<String>();
    final recent = Completer<String>();
    final c = mount(AccountController(
        saveAvatarFile: (path, _) =>
            path == 'old' ? old.future : recent.future));
    final first = c.setLocalAvatar('old');
    final second = c.setLocalAvatar('new');
    recent.complete('new.png');
    await second;
    old.complete('old.png');
    await first;
    expect(c.user.value.avatarUrl, 'new.png');
  });
  test('account checks run inside an upload before further requests', () async {
    final block = Completer<void>();
    final c = mount(AccountController(uploadAvatar: (path, check) async {
      await block.future;
      check();
      return true;
    }));
    final upload = c.uploadForumAvatar('chosen.png');
    final rejected = expectLater(upload, throwsA(anything));
    c.user(b);
    block.complete();
    await rejected;
    expect(c.user.value.avatarUrl, 'b.png');
  });
  test('unconfirmed upload does not refresh or claim success', () async {
    var loads = 0;
    final c = mount(AccountController(
        uploadAvatar: (_, __) async => false,
        loadAvatarProfile: (_) async {
          loads++;
          return null;
        }));
    await expectLater(c.uploadForumAvatar('chosen.png'), throwsA(anything));
    expect(loads, 0);
    expect(c.user.value.avatarUrl, 'a.png');
  });
  test('logout and controller disposal reject previously captured work', () {
    final c = mount(AccountController());
    final token = c.captureAvatarAccount();
    c.user(kDefUser);
    expect(() => c.checkAvatarAccount(token), throwsA(anything));
    c.user(a);
    final current = c.captureAvatarAccount();
    c.onClose();
    expect(() => c.checkAvatarAccount(current), throwsA(anything));
  });
}
