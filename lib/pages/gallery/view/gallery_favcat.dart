import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_fav_controller.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

/// 收藏操作处理类
class GalleryFavButton extends StatelessWidget {
  const GalleryFavButton({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final _favController =
        Get.find<GalleryFavController>(tag: pageCtrlTagOf(context));
    const double iconSize = 28.0;
    // 收藏按钮图标
    final Widget favIcon = Obx(() {
      return MouseRegionClick(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              height: 14,
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                _favController.isFav ? _favController.favTitle : '',
                style: const TextStyle(
                  fontSize: 11,
                ),
              ),
            ),
            if (_favController.isFav)
              FaIcon(
                FontAwesomeIcons.solidHeart,
                color: ThemeColors.favColorFor(_favController.favcat),
                size: iconSize,
              )
            else
              const FaIcon(
                FontAwesomeIcons.heart,
                color: CupertinoColors.systemGrey,
                size: iconSize,
              ),
          ],
        ),
      );
    });

    final Widget _loadIcon = Row(
      children: <Widget>[
        Container(
          height: 16,
          padding: const EdgeInsets.only(right: 4),
          child: const Text(
            // L10n.of(context).processing,
            '',
            style: TextStyle(
              fontSize: 11,
            ),
          ),
        ),
        const CupertinoActivityIndicator(
          radius: 10.0,
        ),
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: Obx(() => Container(
            margin: const EdgeInsets.only(right: 10, left: 10),
            child: _favController.isLoading ? _loadIcon : favIcon,
          )),
      onTap: () => _favController.tapFav(),
      onLongPress: () => _favController.longTapFav(),
    );
  }
}

class FavCatAddListItem extends StatefulWidget {
  const FavCatAddListItem({
    Key? key,
    required VoidCallback onTap,
    required this.text,
    this.favcat,
    this.totNum,
    this.grouped = false,
  })  : _onTap = onTap,
        super(key: key);

  final VoidCallback _onTap;
  final String text;
  final String? favcat;
  final int? totNum;
  final bool grouped;

  @override
  _FavCatAddListItemState createState() => _FavCatAddListItemState();
}

class _FavCatAddListItemState extends State<FavCatAddListItem> {
  Color? _color;

  @override
  Widget build(BuildContext context) {
    if (liquidGlassPopupsEnabled) {
      final count = '${widget.totNum ?? 0}';
      final labelStyle = EhPopupTextStyles.action(context);
      final countStyle = EhPopupTextStyles.secondary(context).copyWith(
        fontSize: 13,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
      return Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() => _color = null);
            widget._onTap();
          },
          onTapDown: (_) => setState(() => _color =
              CupertinoDynamicColor.resolve(
                  CupertinoColors.tertiarySystemFill, context)),
          onTapCancel: () => setState(() => _color = null),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: widget.grouped ? 44 : 52),
            padding: EdgeInsets.symmetric(
                horizontal: widget.grouped ? 16 : 12,
                vertical: widget.grouped ? 8 : 12),
            decoration: BoxDecoration(
              color: _color,
              borderRadius: widget.grouped
                  ? BorderRadius.zero
                  : const BorderRadius.all(Radius.circular(12)),
            ),
            child: LayoutBuilder(builder: (context, constraints) {
              final countBelow =
                  MediaQuery.textScalerOf(context).scale(17) > 27 ||
                      constraints.maxWidth < 200 ||
                      count.length > 6;
              return Row(
                children: [
                  ExcludeSemantics(
                    child: SizedBox(
                      width: 20,
                      child: FaIcon(
                        FontAwesomeIcons.solidHeart,
                        color: CupertinoDynamicColor.resolve(
                            ThemeColors.favColorFor(widget.favcat), context),
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.text,
                            textAlign: TextAlign.start, style: labelStyle),
                        if (countBelow) ...[
                          const SizedBox(height: 4),
                          Text(count,
                              textAlign: TextAlign.start, style: countStyle),
                        ],
                      ],
                    ),
                  ),
                  if (!countBelow) ...[
                    const SizedBox(width: 16),
                    Text(count, style: countStyle),
                  ],
                ],
              );
            }),
          ),
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: _color,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              FontAwesomeIcons.solidHeart,
              color: CupertinoDynamicColor.resolve(
                  ThemeColors.favColorFor(widget.favcat), context),
              size: 18,
            ).paddingOnly(left: 8, right: 8, bottom: 4),
            Text(widget.text, style: const TextStyle(fontSize: 18)),
            const Spacer(),
            Text(
              '${widget.totNum ?? 0}',
              style: const TextStyle(
                fontSize: 14,
              ),
            ).paddingOnly(right: 4),
          ],
        ),
      ),
      onTap: () {
        widget._onTap();
      },
      onTapDown: (_) {
        setState(() {
          _color = CupertinoDynamicColor.resolve(
              CupertinoColors.systemGrey3, context);
        });
      },
      onTapCancel: () {
        setState(() {
          _color = null;
        });
      },
    );
  }
}
