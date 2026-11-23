import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/eh_sheet.dart';
import 'package:eros_fe/widget/flutter_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';

/// 浮层玻璃变体：
/// - [clear]：圆形返回钮、封面上的地区胶囊等小控件，高透透镜质感；
/// - [regular]：顶部到期通知、验证浏览器地址栏与底部进度坞，垫薄白保障多行文字可读性。
enum LoginGlassTone {
  clear,
  regular,
}

/// 跟随用户设置自动切换「液态玻璃 / 毛玻璃 / 纯色」三态的浮层容器。
///
/// 判定逻辑直接复用 [ehSheetMaterialOf]，同时监听辅助功能「降低透明度」变化。
class LoginFloatingMaterial extends StatelessWidget {
  const LoginFloatingMaterial({
    super.key,
    required this.child,
    this.radius = 20,
    this.tone = LoginGlassTone.regular,
    this.padding,
  });

  final Widget child;
  final double radius;
  final LoginGlassTone tone;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool?>(
      valueListenable: LiquidGlassAccessibilitySettings.reduceTransparency,
      builder: (context, _, _) => _buildSurface(context),
    );
  }

  Widget _buildSurface(BuildContext context) {
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final material = ehSheetMaterialOf(context);
    final borderRadius = BorderRadius.circular(radius);
    final inner = padding != null ? Padding(padding: padding!, child: child) : child;

    switch (material) {
      case EhSheetMaterial.glass:
        final double fillAlpha = tone == LoginGlassTone.clear
            ? (dark ? 0.28 : 0.24)
            : (dark ? 0.68 : 0.54);
        final baseColor = dark
            ? const Color(0xFF22242B).withValues(alpha: fillAlpha)
            : const Color(0xFFFFFFFF).withValues(alpha: fillAlpha);
        final rimColor =
            dark ? const Color(0x2EFFFFFF) : const Color(0xD9FFFFFF);

        final decorated = DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                dark
                    ? const Color(0x38FFFFFF)
                    : const Color(0xBAFFFFFF),
                baseColor,
              ],
            ),
            border: Border.all(color: rimColor, width: 0.75),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color.fromRGBO(14, 16, 28, dark ? 0.34 : 0.12),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: inner,
        );

        if (FlutterGlassRuntime.available && !PlatformCapabilities.uiKitGlass) {
          return GlassContainer(
            useOwnLayer: true,
            quality: GlassPreference.materialOf(context).quality,
            shape: LiquidRoundedSuperellipse(borderRadius: radius),
            child: decorated,
          );
        }
        return ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: tone == LoginGlassTone.clear ? 8 : 14,
              sigmaY: tone == LoginGlassTone.clear ? 8 : 14,
            ),
            child: decorated,
          ),
        );

      case EhSheetMaterial.frosted:
        final frostedBg = dark
            ? const Color(0xFF1E2026).withValues(alpha: 0.78)
            : const Color(0xFFFFFFFF).withValues(alpha: 0.74);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color.fromRGBO(14, 16, 28, dark ? 0.30 : 0.10),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: EhSheetTokens.frostSigma,
                sigmaY: EhSheetTokens.frostSigma,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: frostedBg,
                  borderRadius: borderRadius,
                  border: Border.all(
                    color: palette.hairline.resolveFrom(context),
                    width: 0.5,
                  ),
                ),
                child: inner,
              ),
            ),
          ),
        );

      case EhSheetMaterial.solid:
        final solidBg = palette.surface.resolveFrom(context);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: solidBg,
            borderRadius: borderRadius,
            border: Border.all(
              color: palette.hairline.resolveFrom(context),
              width: 0.5,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color.fromRGBO(14, 16, 28, dark ? 0.32 : 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: Color.fromRGBO(14, 16, 28, dark ? 0.24 : 0.12),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: inner,
        );
    }
  }
}

/// 浮层内的主操作按钮：液态玻璃下呈现靛蓝染色玻璃高光，毛玻璃与纯色下呈现扎实强调色。
class LoginTintedActionPill extends StatelessWidget {
  const LoginTintedActionPill({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 32,
    this.horizontalPadding = 14,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final material = ehSheetMaterialOf(context);
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final accent = EhPalette.accent.resolveFrom(context);
    final onAccent = EhPalette.onAccent.resolveFrom(context);
    final isLiquid = material == EhSheetMaterial.glass;

    return EhPressable(
      onPressed: onPressed,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          color: isLiquid ? null : accent,
          gradient: isLiquid
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: dark
                      ? <Color>[
                          const Color(0xFFA6B2FF),
                          accent.withValues(alpha: 0.90),
                        ]
                      : <Color>[
                          const Color(0xFF6E7EEB),
                          accent.withValues(alpha: 0.92),
                        ],
                )
              : null,
          border: isLiquid
              ? Border.all(
                  color: const Color(0x80FFFFFF),
                  width: 0.75,
                )
              : null,
          boxShadow: isLiquid
              ? <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.36),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: onAccent,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

/// 左上角圆形三态材质图标按钮（返回、关闭、刷新）
class LoginFloatingCircleButton extends StatelessWidget {
  const LoginFloatingCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 40,
    this.iconSize = 19,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final text1 = ehTheme.palette.text1.resolveFrom(context);
    return Semantics(
      button: true,
      label: tooltip,
      child: EhPressable(
        onPressed: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: LoginFloatingMaterial(
            radius: size / 2,
            tone: LoginGlassTone.clear,
            child: Center(
              child: EhSvgIcon(icon, size: iconSize, color: text1),
            ),
          ),
        ),
      ),
    );
  }
}

/// 方案 B「封面幕布」：柔和瀑布流色块墙，向下或向右渐隐融入画布。
///
/// - 液态玻璃 / 毛玻璃下：当 [breathing] 为 true 时做呼吸动画（液态 2.4s、毛玻璃 4.8s）；
/// - 纯色模式下：切换为静态双色线性渐变色块并关闭呼吸动画。
class CoverMosaicCurtain extends StatefulWidget {
  const CoverMosaicCurtain({
    super.key,
    this.columns = 3,
    this.breathing = false,
    this.fadeDirection = Axis.vertical,
    this.tilted = false,
    this.seed = 23,
  });

  final int columns;
  final bool breathing;
  final Axis fadeDirection;
  final bool tilted;
  final int seed;

  @override
  State<CoverMosaicCurtain> createState() => _CoverMosaicCurtainState();
}

class _CoverMosaicCurtainState extends State<CoverMosaicCurtain>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Duration _currentPeriod = const Duration(milliseconds: 2400);

  static const List<Color> _lightBlocks = <Color>[
    Color(0xFFD5D9EC),
    Color(0xFFC8CFE9),
    Color(0xFFDCE0EA),
    Color(0xFFC5CBE8),
    Color(0xFFE2D9CE),
    Color(0xFFCFE0D9),
    Color(0xFFD8D2EA),
    Color(0xFFD0D9E6),
  ];

  static const List<Color> _darkBlocks = <Color>[
    Color(0xFF1C1F2B),
    Color(0xFF22273A),
    Color(0xFF1A1D26),
    Color(0xFF252A40),
    Color(0xFF242129),
    Color(0xFF1D2626),
    Color(0xFF232030),
    Color(0xFF1E2430),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _currentPeriod);
    if (widget.breathing) {
      _controller!.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant CoverMosaicCurtain oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation(allowMotion: true);
  }

  void _syncAnimation({required bool allowMotion}) {
    final ctrl = _controller;
    if (ctrl == null) {
      return;
    }
    if (widget.breathing && allowMotion) {
      if (!ctrl.isAnimating) {
        ctrl.repeat(reverse: true);
      }
    } else if (ctrl.isAnimating) {
      ctrl.stop();
      ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final material = ehSheetMaterialOf(context);
    final isSolid = material == EhSheetMaterial.solid;
    final disableAnim =
        isSolid || MediaQuery.maybeDisableAnimationsOf(context) == true;
    final targetPeriod = material == EhSheetMaterial.frosted
        ? const Duration(milliseconds: 4800)
        : const Duration(milliseconds: 2400);
    if (_currentPeriod != targetPeriod && _controller != null) {
      _currentPeriod = targetPeriod;
      _controller!.duration = targetPeriod;
      if (_controller!.isAnimating) {
        _controller!.repeat(reverse: true);
      }
    }
    _syncAnimation(allowMotion: !disableAnim);

    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final canvas = palette.canvas.resolveFrom(context);
    final blocks = dark ? _darkBlocks : _lightBlocks;
    final accent = EhPalette.accent.resolveFrom(context);

    int s = widget.seed;
    double nextRand() {
      s = (s * 9301 + 49297) % 233280;
      return s / 233280.0;
    }

    final colWidgets = <Widget>[];
    for (int c = 0; c < widget.columns; c++) {
      final items = <Widget>[];
      if (c.isOdd) {
        items.add(const SizedBox(height: 16));
      }
      for (int r = 0; r < 5; r++) {
        final h = 92.0 + (nextRand() * 58.0).roundToDouble();
        final base = blocks[(nextRand() * blocks.length).floor() % blocks.length];
        items.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _MosaicTile(
              height: h,
              baseColor: base,
              accentColor: accent,
              dark: dark,
              isSolidGradient: isSolid,
              phaseOffset: c * 0.25 + r * 0.1,
              animation: disableAnim ? null : _controller,
            ),
          ),
        );
      }
      colWidgets.add(
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: items,
            ),
          ),
        ),
      );
    }

    Widget grid = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: OverflowBox(
        alignment: Alignment.topCenter,
        maxHeight: 900,
        child: Transform.translate(
          offset: const Offset(0, -28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: colWidgets,
          ),
        ),
      ),
    );

    if (widget.tilted) {
      grid = Transform.rotate(
        angle: -4 * math.pi / 180,
        child: Transform.scale(scale: 1.14, child: grid),
      );
    }

    return ClipRect(
      child: ColoredBox(
        color: canvas,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ExcludeSemantics(child: grid),
            if (widget.fadeDirection == Axis.vertical)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 130,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          canvas.withValues(alpha: 0),
                          canvas,
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: 190,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: <Color>[
                          canvas.withValues(alpha: 0),
                          canvas,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MosaicTile extends StatelessWidget {
  const _MosaicTile({
    required this.height,
    required this.baseColor,
    required this.accentColor,
    required this.dark,
    required this.isSolidGradient,
    required this.phaseOffset,
    this.animation,
  });

  final double height;
  final Color baseColor;
  final Color accentColor;
  final bool dark;
  final bool isSolidGradient;
  final double phaseOffset;
  final Animation<double>? animation;

  @override
  Widget build(BuildContext context) {
    if (isSolidGradient || animation == null) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isSolidGradient ? null : baseColor,
          gradient: isSolidGradient
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color.lerp(
                      baseColor,
                      dark ? const Color(0xFF2F3344) : const Color(0xFFFFFFFF),
                      0.42,
                    )!,
                    baseColor,
                    Color.lerp(baseColor, accentColor, dark ? 0.18 : 0.12)!,
                  ],
                )
              : null,
        ),
      );
    }

    return AnimatedBuilder(
      animation: animation!,
      builder: (context, _) {
        final wave =
            0.5 + 0.5 * math.sin((animation!.value + phaseOffset) * math.pi);
        final pulseColor = Color.lerp(
          baseColor,
          accentColor.withValues(alpha: dark ? 0.35 : 0.28),
          wave * 0.22,
        )!;
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: pulseColor,
            borderRadius: BorderRadius.circular(14),
          ),
        );
      },
    );
  }
}

/// 30 天登录态环形倒计时绘制器（账号页与顶部到期胶囊共用）
class CountdownRingBadge extends StatelessWidget {
  const CountdownRingBadge({
    super.key,
    required this.remainingDays,
    required this.progress,
    required this.status,
    this.size = 64,
    this.strokeWidth = 6,
    this.unitLabel,
    this.compact = false,
  });

  final int remainingDays;
  final double progress;
  final AuthCountdownTone status;
  final double size;
  final double strokeWidth;
  final String? unitLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final Color ringColor;
    switch (status) {
      case AuthCountdownTone.valid:
        ringColor = EhPalette.accent.resolveFrom(context);
      case AuthCountdownTone.expiring:
        ringColor = dark ? const Color(0xFFF0B24C) : const Color(0xFFE39A2A);
      case AuthCountdownTone.expired:
        ringColor = dark ? const Color(0xFFFF6961) : const Color(0xFFC9353B);
    }
    final trackColor = status == AuthCountdownTone.expired
        ? ringColor.withValues(alpha: 0.16)
        : palette.fill.resolveFrom(context);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CustomPaint(
            size: Size.square(size),
            painter: _RingArcPainter(
              progress: progress,
              ringColor: ringColor,
              trackColor: trackColor,
              strokeWidth: strokeWidth,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                compact ? '${remainingDays}d' : '$remainingDays',
                style: TextStyle(
                  fontSize: compact ? size * 0.29 : size * 0.31,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                  color: status == AuthCountdownTone.valid
                      ? palette.text1.resolveFrom(context)
                      : ringColor,
                ),
              ),
              if (!compact && unitLabel != null)
                Text(
                  unitLabel!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                    color: palette.text2.resolveFrom(context),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

enum AuthCountdownTone { valid, expiring, expired }

class _RingArcPainter extends CustomPainter {
  const _RingArcPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color ringColor;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final sweep = 2 * math.pi * progress.clamp(0.02, 1.0);
    final arcPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
