// import 'package:cached_network_image/cached_network_image.dart';
import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/component/setting_base.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/widget/user_avatar_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

class UserItem extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _UserItem();
}

class _UserItem extends State<UserItem> {
  Color? _color;
  Color? _pBackgroundColor;

  final UserController _userController = Get.find();

  @override
  void initState() {
    super.initState();
    _color = CupertinoDynamicColor.resolve(
        ehTheme.itemBackgroundColor!, Get.context!);
    _pBackgroundColor = _color;
  }

  @override
  Widget build(BuildContext context) {
    final Color color =
        CupertinoDynamicColor.resolve(ehTheme.itemBackgroundColor!, context);
    if (_pBackgroundColor?.value != color.value) {
      _color = color;
      _pBackgroundColor = color;
    }

    void _tapItem() {
      if (_userController.isLogin) {
        _userController.showLogOutDialog(context);
      } else {
        // NavigatorUtil.jump(context, EHRoutes.login, rootNavigator: true);
        Get.toNamed(EHRoutes.login);
      }
    }

    Widget _buildText() {
      return Obx(() {
        if (_userController.isLogin) {
          final String _userName = _userController.user().username ?? '';
          return Text(_userName);
        } else {
          return Text(L10n.of(context).login);
        }
      });
    }

    Widget _buildAvastat() {
      return Obx(() {
        final String avatarUrl = _userController.user().avatarUrl ?? '';
        return UserAvatarImage(url: avatarUrl, size: 55.0);
      });
    }

    final Widget row = Container(
      color: _color,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      child: Row(children: <Widget>[
        _buildAvastat(),
        // 头像右侧信息
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: _buildText(),
        )
      ]),
    );

    return GestureDetector(
      child: row,
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _tapItem();
      },
      onTapDown: (_) => _updatePressedColor(),
      onTapUp: (_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _updateNormalColor();
        });
      },
      onTapCancel: () => _updateNormalColor(),
    );
  }

  void _updateNormalColor() {
    setState(() {
      _color = CupertinoDynamicColor.resolve(
          ehTheme.itemBackgroundColor!, Get.context!);
    });
  }

  void _updatePressedColor() {
    setState(() {
      _color = getPressedColor(context);
    });
  }
}

const double kAvatarSize = 40.0;
const double kNameTextSize = 13.0;

class UserWidget extends GetView<UserController> {
  Widget _buildAvastat() {
    // avatarUrl 需在 Obx 内读取，user() 更新后头像才会刷新
    return Obx(() {
      final String avatarUrl = controller.user().avatarUrl ?? '';
      return UserAvatarImage(url: avatarUrl, size: kAvatarSize);
    });
  }

  Widget _buildText() {
    return Obx(() {
      if (controller.isLogin) {
        final String? _userName = controller.user().username;
        final String? _nickName = controller.user().nickName;
        return Text(
          _nickName ?? _userName ?? '',
          style: TextStyle(
              fontSize: kNameTextSize,
              fontWeight: FontWeight.normal,
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.label,
                Get.context!,
              )),
        ).paddingOnly(right: 6);
      } else {
        return const SizedBox();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (controller.isLogin) {
          controller.showLogOutDialog(context);
        } else {
          Get.toNamed(EHRoutes.login);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildText(),
          _buildAvastat(),
        ],
      ),
    );
  }
}
