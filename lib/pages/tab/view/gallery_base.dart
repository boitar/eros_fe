import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// 列表加载异常时的默认页面
/// 包含一个点击回调 可用于触发重载
class GalleryErrorPage extends StatelessWidget {
  const GalleryErrorPage({Key? key, this.onTap, this.error}) : super(key: key);
  final VoidCallback? onTap;
  final String? error;

  static const List<FaIconData> _faces = [
    FontAwesomeIcons.faceGrinBeamSweat,
    FontAwesomeIcons.faceSadTear,
    FontAwesomeIcons.faceTired,
    FontAwesomeIcons.faceSurprise,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CupertinoButton(
          onPressed: onTap,
          child: FaIcon(
            // Picked by the error, not at random: a page transition builds
            // this several times, and the face would change each frame.
            _faces[(error ?? '').hashCode % _faces.length],
            size: 50,
            color: CupertinoDynamicColor.resolve(
                CupertinoColors.systemGrey, context),
          ),
        ),
        Text(
          error ?? '',
          textScaler: const TextScaler.linear(0.9),
        ),
      ],
    );
  }
}
