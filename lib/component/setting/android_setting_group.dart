import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show InkWell, Material, MaterialType;

/// Android groups settings as separate rounded blocks with a hairline gap:
/// the group's outer corners are large and the joins between rows small.
const double kAndroidSettingOuterRadius = 24;
const double kAndroidSettingInnerRadius = 4;
const double kAndroidSettingGap = 2;

/// Corners of row [index] in a group of [count] rows.
BorderRadius androidSettingRowRadius(int index, int count) {
  const outer = Radius.circular(kAndroidSettingOuterRadius);
  const inner = Radius.circular(kAndroidSettingInnerRadius);
  final first = index == 0;
  final last = index == count - 1;
  return BorderRadius.only(
    topLeft: first ? outer : inner,
    topRight: first ? outer : inner,
    bottomLeft: last ? outer : inner,
    bottomRight: last ? outer : inner,
  );
}

/// Hands each row its corners, so rows need not know their position.
class AndroidSettingRowShape extends InheritedWidget {
  const AndroidSettingRowShape({
    super.key,
    required this.radius,
    required super.child,
  });

  final BorderRadius radius;

  static BorderRadius of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AndroidSettingRowShape>()
          ?.radius ??
      BorderRadius.circular(kAndroidSettingOuterRadius);

  @override
  bool updateShouldNotify(AndroidSettingRowShape oldWidget) =>
      oldWidget.radius != radius;
}

/// An accent header above rows joined into one rounded group.
class AndroidSettingGroup extends StatelessWidget {
  const AndroidSettingGroup({
    super.key,
    this.header,
    required this.children,
  });

  final String? header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final header = this.header;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Semantics(
                header: true,
                child: Text(
                  header,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: EhPalette.accent.resolveFrom(context),
                  ),
                ),
              ),
            ),
          for (var index = 0; index < children.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(height: kAndroidSettingGap),
            AndroidSettingRowShape(
              radius: androidSettingRowRadius(index, children.length),
              child: children[index],
            ),
          ],
        ],
      ),
    );
  }
}

/// A settings row: tonal icon, title, the current value below it.
class AndroidSettingTile extends StatelessWidget {
  const AndroidSettingTile({
    super.key,
    required this.title,
    this.icon,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.minHeight = 64,
  });

  final IconData? icon;

  /// Replaces the tonal icon, for an avatar.
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final radius = AndroidSettingRowShape.of(context);
    final text1 = palette.text1.resolveFrom(context);
    final text2 = palette.text2.resolveFrom(context);
    final icon = this.icon;
    final Widget? leading = this.leading ??
        (icon == null
            ? null
            : Container(
                width: 40,
                height: 40,
                decoration: ShapeDecoration(
                  color: EhPalette.accentSoft.resolveFrom(context),
                  shape: const CircleBorder(),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: EhPalette.accent.resolveFrom(context),
                ),
              ));
    return Material(
      type: MaterialType.canvas,
      color: palette.surface.resolveFrom(context),
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: <Widget>[
                if (leading != null) ...<Widget>[
                  ExcludeSemantics(child: leading),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      DefaultTextStyle.merge(
                        style: TextStyle(fontSize: 16, color: text1),
                        child: title,
                      ),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: 2),
                        DefaultTextStyle.merge(
                          style: TextStyle(fontSize: 13, color: text2),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          child: subtitle!,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: 12),
                  IconTheme.merge(
                    data: IconThemeData(
                      color: palette.text3.resolveFrom(context),
                    ),
                    child: trailing!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
