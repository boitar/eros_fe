import 'package:eros_fe/common/controller/base_controller.dart';
import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/component/exception/error.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/extension.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/index.dart';
import 'package:eros_fe/network/api.dart';
import 'package:eros_fe/network/request.dart';
import 'package:eros_fe/pages/tab/controller/favorite/favorite_tabbar_controller.dart';
import 'package:eros_fe/utils/avatar_store.dart';
import 'package:eros_fe/utils/logger.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:get/get.dart';
import 'package:webview_cookie_manager_plus/webview_cookie_manager_plus.dart';

class UserController extends ProfileController {
  UserController({
    Future<User?> Function(String)? loadAvatarProfile,
    Future<String> Function(String, String)? saveAvatarFile,
    Future<bool> Function(String, void Function())? uploadAvatar,
  })  : _loadAvatarProfile = loadAvatarProfile ?? getUserInfo,
        _saveAvatarFile = saveAvatarFile ??
            ((path, owner) => AvatarStore.saveFromFile(path, memberId: owner)),
        _uploadAvatar = uploadAvatar ??
            ((path, check) => uploadAvatarToForum(path, checkAccount: check));

  final Future<User?> Function(String) _loadAvatarProfile;
  final Future<String> Function(String, String) _saveAvatarFile;
  final Future<bool> Function(String, void Function()) _uploadAvatar;
  (String?, String?)? _avatarIdentity;
  int _avatarRevision = 0;
  int _avatarOperation = 0;
  bool _avatarClosed = false;
  User _lastUserForFavorites = kDefUser;
  bool _updatingAvatarMetadata = false;

  void _observeAvatarIdentity() {
    final identity = (user.value.memberId, user.value.passHash);
    if (_avatarIdentity != identity) {
      _avatarIdentity = identity;
      _avatarRevision++;
      _avatarOperation++;
    }
  }

  AvatarAccountToken captureAvatarAccount() {
    _observeAvatarIdentity();
    if (_avatarClosed || !isLogin) {
      throw EhError(error: 'Not logged in');
    }
    return AvatarAccountToken(user.value.memberId!, _avatarRevision);
  }

  void checkAvatarAccount(AvatarAccountToken account) {
    _observeAvatarIdentity();
    if (_avatarClosed ||
        !isLogin ||
        account.revision != _avatarRevision ||
        account.memberId != user.value.memberId) {
      throw EhError(error: 'Account changed; choose the avatar again');
    }
  }

  bool get isLogin =>
      (user.value.memberId?.isNotEmpty ?? false) &&
      (user.value.passHash?.isNotEmpty ?? false);

  // bool get isLogin => user.value.username?.isNotEmpty ?? false;

  Rx<User> user = kDefUser.obs;

  final EhSettingService _ehSettingService = Get.find();

  void _logOut() {
    user(kDefUser);
    final WebviewCookieManager cookieManager = WebviewCookieManager();
    cookieManager.clearCookies();
  }

  @override
  void onInit() {
    super.onInit();
    final stored = Global.profile.user;
    final avatar = stored.avatarUrl;
    user(avatar == null
        ? stored
        : stored.copyWith(avatarUrl: AvatarStore.resolveLocalPath(avatar).oN));
    _observeAvatarIdentity();
    _lastUserForFavorites = user.value;
    // logger.d('${user.toJson()}');
    everProfile<User>(
      user,
      (User value) {
        final previous = _lastUserForFavorites;
        _lastUserForFavorites = value;
        final accountChanged = previous.memberId != value.memberId ||
            previous.passHash != value.passHash;
        final favoriteCategoriesChanged =
            !listEquals(previous.favcat, value.favcat);
        _observeAvatarIdentity();
        Global.profile = Global.profile.copyWith(user: value);
        if ((accountChanged ||
                (!_updatingAvatarMetadata && favoriteCategoriesChanged)) &&
            Get.isRegistered<FavoriteTabBarController>()) {
          logger.d('everProfile User  => update FavoriteTabBarController');
          Get.find<FavoriteTabBarController>().onInit();
          Get.find<FavoriteTabBarController>().update();
        }
      },
    );
  }

  Future<void> showLogOutDialog(BuildContext context) async {
    return showCupertinoDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text('Logout'),
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
                (await Api.cookieJar).deleteAll();
                // userController.user(User());
                _logOut();
                _ehSettingService.isSiteEx.value = false;
                Get.back();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> removeIgneous() async {
    user(user.value.copyWith(igneous: ''.oN));
    final cookieJar = await Api.cookieJar;
    final uri = Uri.parse(Api.getBaseUrl());
    final cookies = await cookieJar.loadForRequest(uri);
    cookies.removeWhere((element) {
      return element.name == 'igneous';
    });
    logger.d('removeIgneous: $cookies');
    await cookieJar.deleteAll();
    await cookieJar.saveFromResponse(uri, cookies);
  }

  void _setAvatarUser(User value) {
    final stored = Global.profile.user;
    if (stored.memberId == value.memberId &&
        stored.passHash == value.passHash) {
      // Folder names/counts may have been persisted by FavoriteSelectorController
      // since this controller last changed; an avatar edit must preserve them.
      value = value.copyWith(favcat: stored.favcat.oN);
    }
    _updatingAvatarMetadata = true;
    try {
      user(value);
    } finally {
      _updatingAvatarMetadata = false;
    }
  }

  /// 刷新当前登录用户的论坛昵称与头像
  Future<void> refreshOwnUserInfo() async {
    if (!isLogin) {
      return;
    }
    final account = captureAvatarAccount();
    final operation = ++_avatarOperation;
    final User? info = await _loadAvatarProfile(account.memberId);
    checkAvatarAccount(account);
    if (info != null && operation == _avatarOperation) {
      _setAvatarUser(user.value.copyWith(
        nickName: info.nickName?.oN,
        avatarUrl: info.avatarUrl?.oN,
      ));
    }
  }

  /// 设置本地头像：复制图片到应用头像目录并指向它
  Future<void> setLocalAvatar(String sourcePath) async {
    final account = captureAvatarAccount();
    final operation = ++_avatarOperation;
    final String savedPath =
        await _saveAvatarFile(sourcePath, account.memberId);
    checkAvatarAccount(account);
    if (operation == _avatarOperation) {
      setLocalAvatarPath(savedPath, account: account);
    }
  }

  /// 直接指向已存放于头像目录的本地文件
  void setLocalAvatarPath(String path, {AvatarAccountToken? account}) {
    checkAvatarAccount(account ?? captureAvatarAccount());
    _avatarOperation++;
    _setAvatarUser(user.value.copyWith(avatarUrl: path.oN));
  }

  /// 上传头像到 EH 论坛，成功后刷新论坛资料（新头像 URL 自动持久化）
  Future<void> uploadForumAvatar(String filePath,
      {AvatarAccountToken? account}) async {
    final expected = account ?? captureAvatarAccount();
    checkAvatarAccount(expected);
    final operation = ++_avatarOperation;
    final confirmed =
        await _uploadAvatar(filePath, () => checkAvatarAccount(expected));
    checkAvatarAccount(expected);
    if (!confirmed) {
      throw EhError(error: 'Avatar upload was not confirmed');
    }
    try {
      final info = await _loadAvatarProfile(expected.memberId);
      checkAvatarAccount(expected);
      if (info != null && operation == _avatarOperation) {
        _setAvatarUser(user.value.copyWith(
          nickName: info.nickName?.oN,
          avatarUrl: info.avatarUrl?.oN,
        ));
      }
    } catch (e) {
      // 上传已成功，资料刷新失败不作为整体失败
      logger.e('refresh user info after avatar upload failed: $e');
    }
    checkAvatarAccount(expected);
  }

  @override
  void onClose() {
    _avatarClosed = true;
    _avatarRevision++;
    _avatarOperation++;
    super.onClose();
  }
}

class AvatarAccountToken {
  const AvatarAccountToken(this.memberId, this.revision);

  final String memberId;
  final int revision;
}
