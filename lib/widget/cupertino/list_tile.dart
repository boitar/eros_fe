import 'dart:async';

import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:eros_fe/widget/desktop_browse_style.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

const double _kLeadingSize = 28.0;
const double _kNotchedLeadingSize = 30.0;
const double _kMinHeight = _kLeadingSize + 2 * 8.0;
const double _kMinHeightWithSubtitle = _kLeadingSize + 2 * 10.0;
const double _kNotchedMinHeight = _kNotchedLeadingSize + 2 * 12.0;
const double _kNotchedMinHeightWithoutLeading = _kNotchedLeadingSize + 2 * 10.0;
const EdgeInsetsDirectional _kPadding =
    EdgeInsetsDirectional.only(start: 16.0, end: 16.0, top: 6.0, bottom: 6.0);
const EdgeInsetsDirectional _kPaddingWithSubtitle =
    EdgeInsetsDirectional.only(start: 16.0, end: 16.0, top: 10.0, bottom: 10.0);

/// Row height of the system Settings app on iOS 26.
const double kSettingRowMinHeight = 52.0;
const EdgeInsets _kNotchedPadding = EdgeInsets.symmetric(horizontal: 14.0);
const EdgeInsetsDirectional _kNotchedPaddingWithoutLeading =
    EdgeInsetsDirectional.fromSTEB(28.0, 10.0, 14.0, 10.0);
const double _kLeadingToTitle = 16.0;
const double _kNotchedLeadingToTitle = 12.0;
const double _kNotchedTitleToSubtitle = 3.0;
const double _kAdditionalInfoToTrailing = 6.0;
const double _kNotchedTitleWithSubtitleFontSize = 16.0;
const double _kSubtitleFontSize = 12.0;
const double _kNotchedSubtitleFontSize = 14.0;

class EhCupertinoListTile extends StatefulWidget {
  const EhCupertinoListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.additionalInfo,
    this.leading,
    this.trailing,
    this.onTap,
    this.backgroundColor,
    this.backgroundColorActivated,
    this.padding,
    this.leadingSize = _kLeadingSize,
    this.leadingToTitle = _kLeadingToTitle,
  });

  /// A [title] is used to convey the central information. Usually a [Text].
  final Widget title;

  /// A [subtitle] is used to display additional information. It is located
  /// below [title]. Usually a [Text] widget.
  final Widget? subtitle;

  /// Similar to [subtitle], an [additionalInfo] is used to display additional
  /// information. However, instead of being displayed below [title], it is
  /// displayed on the right, before [trailing]. Usually a [Text] widget.
  final Widget? additionalInfo;

  /// A widget displayed at the start of the [CupertinoListTile]. This is
  /// typically an `Icon` or an `Image`.
  final Widget? leading;

  /// A widget displayed at the end of the [CupertinoListTile]. This is usually
  /// a right chevron icon (e.g. `CupertinoListTileChevron`), or an `Icon`.
  final Widget? trailing;

  /// The [onTap] function is called when a user taps on [CupertinoListTile]. If
  /// left `null`, the [CupertinoListTile] will not react on taps. If this is a
  /// `Future<void> Function()`, then the [CupertinoListTile] remains activated
  /// until the returned future is awaited. This is according to iOS behavior.
  /// However, if this function is a `void Function()`, then the tile is active
  /// only for the duration of invocation.
  final FutureOr<void> Function()? onTap;

  /// The [backgroundColor] of the tile in normal state. Once the tile is
  /// tapped, the background color switches to [backgroundColorActivated]. It is
  /// set to match the iOS look by default.
  final Color? backgroundColor;

  /// The [backgroundColorActivated] is the background color of the tile after
  /// the tile was tapped. It is set to match the iOS look by default.
  final Color? backgroundColorActivated;

  /// Padding of the content inside [CupertinoListTile].
  final EdgeInsetsGeometry? padding;

  /// The [leadingSize] is used to constrain the width and height of [leading]
  /// widget.
  final double leadingSize;

  /// The horizontal space between [leading] widget and [title].
  final double leadingToTitle;

  @override
  State<EhCupertinoListTile> createState() => _EhCupertinoListTileState();
}

class _EhCupertinoListTileState extends State<EhCupertinoListTile>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _pointerDown = false;
  int _pressEpoch = 0;

  late final AnimationController _pressController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 85),
    reverseDuration: const Duration(milliseconds: 190),
  );

  @override
  void didUpdateWidget(covariant EhCupertinoListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onTap == null) {
      _hovered = false;
      _pointerDown = false;
      _pressEpoch++;
      _pressController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handlePressDown() {
    _pressEpoch++;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pressController.value = 1.0;
    } else {
      _pressController.forward();
    }
  }

  void _handlePressUp() {
    final int epoch = ++_pressEpoch;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pressController.value = 0.0;
      return;
    }
    if (_pressController.value < 0.65) {
      _pressController
          .animateTo(
            1.0,
            duration: const Duration(milliseconds: 55),
            curve: Curves.easeOut,
          )
          .then((_) {
            if (mounted && _pressEpoch == epoch) {
              _pressController.reverse();
            }
          });
    } else {
      _pressController.reverse();
    }
  }

  void _handlePressCancel() {
    _pressEpoch++;
    if (!_pressController.isAnimating && _pressController.value == 0.0) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _pressController.value = 0.0;
    } else {
      _pressController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final Color secondary = palette.text2.resolveFrom(context);
    // Keep the value readable at accessibility sizes instead of allowing the
    // CupertinoListTile row to overflow horizontally.
    final bool largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
    final bool stackAdditionalInfo =
        largeText &&
        widget.additionalInfo != null &&
        widget.additionalInfo is! Flexible;
    final Widget? effectiveSubtitle;
    final Widget? effectiveAdditionalInfo;
    if (stackAdditionalInfo) {
      effectiveSubtitle = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.subtitle != null) widget.subtitle!,
          if (widget.subtitle != null) const SizedBox(height: 3),
          DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 17),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            child: widget.additionalInfo!,
          ),
        ],
      );
      effectiveAdditionalInfo = null;
    } else {
      effectiveSubtitle = widget.subtitle;
      effectiveAdditionalInfo = widget.additionalInfo;
    }

    EdgeInsetsGeometry? _padding = widget.padding;
    _padding ??= effectiveSubtitle == null ? _kPadding : _kPaddingWithSubtitle;

    Widget? resolvedLeading = widget.leading;
    if (resolvedLeading is Icon &&
        resolvedLeading is! EhSvgIcon &&
        resolvedLeading is! FaIcon &&
        resolvedLeading.icon != null) {
      resolvedLeading = EhSvgIcon(
        resolvedLeading.icon,
        key: resolvedLeading.key,
        size: resolvedLeading.size,
        fill: resolvedLeading.fill,
        weight: resolvedLeading.weight,
        grade: resolvedLeading.grade,
        opticalSize: resolvedLeading.opticalSize,
        color: resolvedLeading.color,
        shadows: resolvedLeading.shadows,
        semanticLabel: resolvedLeading.semanticLabel,
        textDirection: resolvedLeading.textDirection,
        applyTextScaling: resolvedLeading.applyTextScaling,
        blendMode: resolvedLeading.blendMode,
        fontWeight: resolvedLeading.fontWeight,
      );
    }

    Widget? resolvedTrailing = widget.trailing;
    if (resolvedTrailing is CupertinoListTileChevron &&
        resolvedTrailing is! EhSvgListTileChevron) {
      resolvedTrailing = const EhSvgListTileChevron();
    }

    final bool desktopInteractive =
        PlatformCapabilities.isDesktop && widget.onTap != null;

    // Titles and summaries wrap like the system Settings app; the stock
    // tile would cut both to one line.
    Widget buildTile(Color? bgColor, Color activatedColor) => ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kSettingRowMinHeight),
      child: CupertinoListTile(
        title: _Wrapping(child: widget.title),
        subtitle: effectiveSubtitle == null
            ? null
            : _Wrapping(
                style: TextStyle(fontSize: 13, color: secondary),
                child: effectiveSubtitle,
              ),
        additionalInfo: switch (effectiveAdditionalInfo) {
          null => null,
          // A flexible value must stay a direct child of the tile's row.
          final Flexible flexible => Flexible(
            key: flexible.key,
            flex: flexible.flex,
            fit: flexible.fit,
            child: DefaultTextStyle.merge(
              style: TextStyle(color: secondary),
              child: flexible.child,
            ),
          ),
          final Widget info => DefaultTextStyle.merge(
            style: TextStyle(color: secondary),
            child: info,
          ),
        },
        leading: resolvedLeading,
        trailing: resolvedTrailing,
        onTap: widget.onTap,
        backgroundColor: bgColor,
        backgroundColorActivated: activatedColor,
        padding: _padding,
        leadingSize: widget.leadingSize,
        leadingToTitle: widget.leadingToTitle,
      ),
    );

    if (!desktopInteractive) {
      return buildTile(
        widget.backgroundColor,
        widget.backgroundColorActivated ??
            palette.fillPressed.resolveFrom(context),
      );
    }

    final Color hoverColor = DesktopBrowseStyle.listRowHover(context);
    final Color transparentHover = hoverColor.withValues(alpha: 0);
    final Color targetHoverColor = _hovered ? hoverColor : transparentHover;
    final Color pressedColor = DesktopBrowseStyle.listRowPressed(context);

    return MouseRegion(
      cursor: DesktopBrowseStyle.interactionCursor,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) {
        if (_hovered) {
          setState(() => _hovered = false);
        }
        _pointerDown = false;
        _handlePressCancel();
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          if ((event.buttons & kPrimaryButton) != 0 ||
              event.kind != PointerDeviceKind.mouse) {
            _pointerDown = true;
            _handlePressDown();
          }
        },
        onPointerUp: (_) {
          if (_pointerDown) {
            _pointerDown = false;
            _handlePressUp();
          }
        },
        onPointerCancel: (_) {
          if (_pointerDown) {
            _pointerDown = false;
            _handlePressCancel();
          }
        },
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(begin: transparentHover, end: targetHoverColor),
          duration: DesktopBrowseStyle.hoverDuration(
            context,
            entering: _hovered,
          ),
          curve: _hovered
              ? DesktopBrowseStyle.hoverEnterCurve
              : DesktopBrowseStyle.hoverExitCurve,
          builder: (context, animatedHover, _) => AnimatedBuilder(
            animation: _pressController,
            builder: (context, _) {
              final double t = Curves.easeOutCubic.transform(
                _pressController.value,
              );
              final Color? blended = t > 0
                  ? Color.lerp(
                      animatedHover ?? transparentHover,
                      pressedColor,
                      t,
                    )
                  : animatedHover;
              final Color? effectiveBg =
                  widget.backgroundColor ??
                  ((blended == null || blended.a == 0) ? null : blended);
              return buildTile(
                effectiveBg,
                widget.backgroundColorActivated ??
                    effectiveBg ??
                    const Color(0x00000000),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Lifts the one-line limit [CupertinoListTile] puts on its text.
class _Wrapping extends StatelessWidget {
  const _Wrapping({required this.child, this.style});

  final Widget child;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final inherited = DefaultTextStyle.of(context);
    return DefaultTextStyle(
      style: style == null ? inherited.style : inherited.style.merge(style),
      textAlign: inherited.textAlign,
      child: child,
    );
  }
}

class EhCupertinoSwitchListTile extends StatefulWidget {
  const EhCupertinoSwitchListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.value = false,
    this.onChanged,
  });

  /// A [title] is used to convey the central information. Usually a [Text].
  final Widget title;

  /// A [subtitle] is used to display additional information. It is located
  /// below [title]. Usually a [Text] widget.
  final Widget? subtitle;

  final bool value;

  final ValueChanged<bool>? onChanged;

  @override
  State<EhCupertinoSwitchListTile> createState() =>
      _EhCupertinoSwitchListTileState();
}

class _EhCupertinoSwitchListTileState extends State<EhCupertinoSwitchListTile> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return EhCupertinoListTile(
      title: widget.title,
      subtitle: widget.subtitle,
      trailing: CupertinoSwitch(
        value: _value,
        onChanged: (bool value) {
          vibrateUtil.selection();
          setState(() {
            _value = value;
          });
          widget.onChanged?.call(value);
        },
      ),
    );
  }
}
