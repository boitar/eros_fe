import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
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

/// A quiet section header above rows joined into one rounded group.
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
    final palette = ehTheme.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
              child: Semantics(
                header: true,
                child: Text(
                  header,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: palette.text2.resolveFrom(context),
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

/// A settings row: monochrome squircle SVG icon, title, current value below
/// it, and a subtle trailing chevron affordance when navigable.
class AndroidSettingTile extends StatelessWidget {
  const AndroidSettingTile({
    super.key,
    required this.title,
    this.icon,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.minHeight = 62,
  });

  final IconData? icon;

  /// Replaces the icon badge, for an avatar.
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final radius = AndroidSettingRowShape.of(context);
    final text1 = palette.text1.resolveFrom(context);
    final text2 = palette.text2.resolveFrom(context);
    final icon = this.icon;
    final Widget? leading = this.leading ??
        (icon == null
            ? null
            : Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: dark
                      ? const Color(0xFF262830)
                      : const Color(0xFFF2F3F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: EhSvgIcon(
                  icon,
                  size: 19,
                  strokeWidth: 1.8,
                  color: text1,
                ),
              ));
    final Widget? effectiveTrailing =
        trailing ??
        (onTap == null
            ? null
            : EhSvgIcon(
                CupertinoIcons.chevron_right,
                size: 14,
                strokeWidth: 1.9,
                color: palette.text3.resolveFrom(context),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              children: <Widget>[
                if (leading != null) ...<Widget>[
                  ExcludeSemantics(child: leading),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      DefaultTextStyle.merge(
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w500,
                          color: text1,
                        ),
                        child: title,
                      ),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: 2),
                        DefaultTextStyle.merge(
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: text2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          child: subtitle!,
                        ),
                      ],
                    ],
                  ),
                ),
                if (effectiveTrailing != null) ...<Widget>[
                  const SizedBox(width: 12),
                  IconTheme.merge(
                    data: IconThemeData(
                      color: palette.text3.resolveFrom(context),
                    ),
                    child: effectiveTrailing,
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
