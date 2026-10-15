import 'dart:io';

import 'package:eros_fe/debug/offline_avatar.dart';
import 'package:eros_fe/utils/avatar_store.dart';
import 'package:eros_fe/widget/image/eh_network_image.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// 用户头像显示组件。
/// [url] 为 http(s) 地址时显示网络图，为本地绝对路径时显示文件，
/// 为空或加载失败时显示默认灰色头像图标。
class UserAvatarImage extends StatelessWidget {
  const UserAvatarImage({
    super.key,
    required this.url,
    this.size = 40.0,
  });

  final String? url;
  final double size;

  Widget get _defAvatar => FaIcon(
        FontAwesomeIcons.solidCircleUser,
        size: size,
        color: CupertinoColors.systemGrey,
      );

  @override
  Widget build(BuildContext context) {
    final resolved = AvatarStore.resolveLocalPath(url ?? '');
    return offlineAvatarPreview(resolved, _buildAvatar(context, resolved));
  }

  Widget _buildAvatar(BuildContext context, String url) {
    if (url.isEmpty) {
      return _defAvatar;
    }

    if (url.startsWith('http')) {
      return ClipOval(
        child: EhNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _defAvatar,
          placeholder: (_, __) => _defAvatar,
        ),
      );
    }

    return ClipOval(
      child: ExtendedImage(
        width: size,
        height: size,
        fit: BoxFit.cover,
        image: ExtendedFileImageProvider(File(url)),
        loadStateChanged: (ExtendedImageState state) {
          if (state.extendedImageLoadState == LoadState.failed) {
            return _defAvatar;
          }
          return null;
        },
      ),
    );
  }
}
