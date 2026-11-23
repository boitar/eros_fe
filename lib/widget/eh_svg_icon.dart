import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:eros_fe/common/service/theme_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Base primitive inside an [EhSvgSpec] defined in `viewBox` coordinates.
@immutable
sealed class EhSvgShape {
  const EhSvgShape({this.filled = false, this.strokeWidth});

  final bool filled;
  final double? strokeWidth;
}

@immutable
final class EhSvgPath extends EhSvgShape {
  const EhSvgPath(
    this.d, {
    super.filled = false,
    super.strokeWidth,
    this.fillEvenOdd = false,
  });

  final String d;
  final bool fillEvenOdd;
}

@immutable
final class EhSvgCircle extends EhSvgShape {
  const EhSvgCircle(
    this.cx,
    this.cy,
    this.r, {
    super.filled = false,
    super.strokeWidth,
  });

  final double cx;
  final double cy;
  final double r;
}

@immutable
final class EhSvgRect extends EhSvgShape {
  const EhSvgRect(
    this.x,
    this.y,
    this.width,
    this.height, {
    this.rx = 0,
    this.ry = 0,
    super.filled = false,
    super.strokeWidth,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double rx;
  final double ry;
}

@immutable
final class EhSvgLine extends EhSvgShape {
  const EhSvgLine(this.x1, this.y1, this.x2, this.y2, {super.strokeWidth})
    : super(filled: false);

  final double x1;
  final double y1;
  final double x2;
  final double y2;
}

@immutable
final class EhSvgPolyline extends EhSvgShape {
  const EhSvgPolyline(
    this.points, {
    this.closed = false,
    super.filled = false,
    super.strokeWidth,
  });

  final List<double> points;
  final bool closed;
}

/// Complete vector specification for a single SVG icon.
@immutable
class EhSvgSpec {
  const EhSvgSpec(
    this.shapes, {
    this.viewBoxWidth = 24.0,
    this.viewBoxHeight = 24.0,
    this.strokeWidth = 1.75,
  });

  final List<EhSvgShape> shapes;
  final double viewBoxWidth;
  final double viewBoxHeight;
  final double strokeWidth;
}

/// Parses standard SVG path `d` commands (`M/L/H/V/C/S/Q/T/A/Z`) into a [ui.Path]
/// and caches compiled paths by `(d, fillEvenOdd)`.
ui.Path parseEhSvgPathData(String d, {bool fillEvenOdd = false}) {
  final cacheKey = fillEvenOdd ? 'eo:$d' : d;
  final cached = _EhSvgPathParser.cache[cacheKey];
  if (cached != null) {
    return cached;
  }
  final parsed = _EhSvgPathParser(d).parse()
    ..fillType = fillEvenOdd ? ui.PathFillType.evenOdd : ui.PathFillType.nonZero;
  _EhSvgPathParser.cache[cacheKey] = parsed;
  return parsed;
}

class _EhSvgPathParser {
  _EhSvgPathParser(this.d);

  static final Map<String, ui.Path> cache = <String, ui.Path>{};
  final String d;
  int _index = 0;

  bool get _hasMore => _index < d.length;

  void _skipSeparators() {
    while (_hasMore) {
      final code = d.codeUnitAt(_index);
      if (code == 0x20 ||
          code == 0x09 ||
          code == 0x0A ||
          code == 0x0D ||
          code == 0x2C) {
        _index++;
      } else {
        break;
      }
    }
  }

  bool _isCommandChar(int code) {
    return (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A);
  }

  double _readNumber() {
    _skipSeparators();
    final start = _index;
    if (_hasMore &&
        (d.codeUnitAt(_index) == 0x2B || d.codeUnitAt(_index) == 0x2D)) {
      _index++;
    }
    var sawDot = false;
    var sawExp = false;
    while (_hasMore) {
      final code = d.codeUnitAt(_index);
      if (code >= 0x30 && code <= 0x39) {
        _index++;
      } else if (code == 0x2E && !sawDot && !sawExp) {
        sawDot = true;
        _index++;
      } else if ((code == 0x65 || code == 0x45) && !sawExp) {
        sawExp = true;
        _index++;
        if (_hasMore &&
            (d.codeUnitAt(_index) == 0x2B || d.codeUnitAt(_index) == 0x2D)) {
          _index++;
        }
      } else {
        break;
      }
    }
    if (_index == start) {
      throw FormatException('Expected SVG number at $_index in "$d"');
    }
    return double.parse(d.substring(start, _index));
  }

  bool _readFlag() {
    _skipSeparators();
    if (!_hasMore) {
      throw FormatException('Expected SVG arc flag at $_index in "$d"');
    }
    final code = d.codeUnitAt(_index);
    if (code == 0x30 || code == 0x31) {
      _index++;
      return code == 0x31;
    }
    throw FormatException('Invalid SVG arc flag at $_index in "$d"');
  }

  bool _hasNextNumber() {
    _skipSeparators();
    if (!_hasMore) {
      return false;
    }
    final code = d.codeUnitAt(_index);
    return (code >= 0x30 && code <= 0x39) ||
        code == 0x2B ||
        code == 0x2D ||
        code == 0x2E;
  }

  ui.Path parse() {
    final path = ui.Path();
    var cx = 0.0;
    var cy = 0.0;
    var sx = 0.0;
    var sy = 0.0;
    var lastCtrlX = 0.0;
    var lastCtrlY = 0.0;
    var lastCmd = '';
    var cmd = '';

    while (true) {
      _skipSeparators();
      if (!_hasMore) {
        break;
      }
      final code = d.codeUnitAt(_index);
      if (_isCommandChar(code)) {
        cmd = d[_index++];
      } else if (cmd.isEmpty) {
        break;
      } else if (cmd == 'M') {
        cmd = 'L';
      } else if (cmd == 'm') {
        cmd = 'l';
      }

      switch (cmd) {
        case 'M':
        case 'm':
          final nx = _readNumber() + (cmd == 'm' ? cx : 0);
          final ny = _readNumber() + (cmd == 'm' ? cy : 0);
          path.moveTo(nx, ny);
          cx = nx;
          cy = ny;
          sx = nx;
          sy = ny;
          lastCtrlX = cx;
          lastCtrlY = cy;
          lastCmd = cmd;
          while (_hasNextNumber()) {
            final lx = _readNumber() + (cmd == 'm' ? cx : 0);
            final ly = _readNumber() + (cmd == 'm' ? cy : 0);
            path.lineTo(lx, ly);
            cx = lx;
            cy = ly;
            lastCtrlX = cx;
            lastCtrlY = cy;
            lastCmd = cmd == 'm' ? 'l' : 'L';
          }
          break;
        case 'L':
        case 'l':
          do {
            final nx = _readNumber() + (cmd == 'l' ? cx : 0);
            final ny = _readNumber() + (cmd == 'l' ? cy : 0);
            path.lineTo(nx, ny);
            cx = nx;
            cy = ny;
            lastCtrlX = cx;
            lastCtrlY = cy;
            lastCmd = cmd;
          } while (_hasNextNumber());
          break;
        case 'H':
        case 'h':
          do {
            final nx = _readNumber() + (cmd == 'h' ? cx : 0);
            path.lineTo(nx, cy);
            cx = nx;
            lastCtrlX = cx;
            lastCtrlY = cy;
            lastCmd = cmd;
          } while (_hasNextNumber());
          break;
        case 'V':
        case 'v':
          do {
            final ny = _readNumber() + (cmd == 'v' ? cy : 0);
            path.lineTo(cx, ny);
            cy = ny;
            lastCtrlX = cx;
            lastCtrlY = cy;
            lastCmd = cmd;
          } while (_hasNextNumber());
          break;
        case 'C':
        case 'c':
          do {
            final rel = cmd == 'c';
            final x1 = _readNumber() + (rel ? cx : 0);
            final y1 = _readNumber() + (rel ? cy : 0);
            final x2 = _readNumber() + (rel ? cx : 0);
            final y2 = _readNumber() + (rel ? cy : 0);
            final x = _readNumber() + (rel ? cx : 0);
            final y = _readNumber() + (rel ? cy : 0);
            path.cubicTo(x1, y1, x2, y2, x, y);
            lastCtrlX = x2;
            lastCtrlY = y2;
            cx = x;
            cy = y;
            lastCmd = cmd;
          } while (_hasNextNumber());
          break;
        case 'S':
        case 's':
          do {
            final rel = cmd == 's';
            final reflect =
                lastCmd == 'C' ||
                lastCmd == 'c' ||
                lastCmd == 'S' ||
                lastCmd == 's';
            final x1 = reflect ? 2 * cx - lastCtrlX : cx;
            final y1 = reflect ? 2 * cy - lastCtrlY : cy;
            final x2 = _readNumber() + (rel ? cx : 0);
            final y2 = _readNumber() + (rel ? cy : 0);
            final x = _readNumber() + (rel ? cx : 0);
            final y = _readNumber() + (rel ? cy : 0);
            path.cubicTo(x1, y1, x2, y2, x, y);
            lastCtrlX = x2;
            lastCtrlY = y2;
            cx = x;
            cy = y;
            lastCmd = cmd;
          } while (_hasNextNumber());
          break;
        case 'Q':
        case 'q':
          do {
            final rel = cmd == 'q';
            final x1 = _readNumber() + (rel ? cx : 0);
            final y1 = _readNumber() + (rel ? cy : 0);
            final x = _readNumber() + (rel ? cx : 0);
            final y = _readNumber() + (rel ? cy : 0);
            path.quadraticBezierTo(x1, y1, x, y);
            lastCtrlX = x1;
            lastCtrlY = y1;
            cx = x;
            cy = y;
            lastCmd = cmd;
          } while (_hasNextNumber());
          break;
        case 'T':
        case 't':
          do {
            final rel = cmd == 't';
            final reflect =
                lastCmd == 'Q' ||
                lastCmd == 'q' ||
                lastCmd == 'T' ||
                lastCmd == 't';
            final x1 = reflect ? 2 * cx - lastCtrlX : cx;
            final y1 = reflect ? 2 * cy - lastCtrlY : cy;
            final x = _readNumber() + (rel ? cx : 0);
            final y = _readNumber() + (rel ? cy : 0);
            path.quadraticBezierTo(x1, y1, x, y);
            lastCtrlX = x1;
            lastCtrlY = y1;
            cx = x;
            cy = y;
            lastCmd = cmd;
          } while (_hasNextNumber());
          break;
        case 'A':
        case 'a':
          do {
            final rel = cmd == 'a';
            final rx = _readNumber().abs();
            final ry = _readNumber().abs();
            final rot = _readNumber();
            final largeArc = _readFlag();
            final sweep = _readFlag();
            final x = _readNumber() + (rel ? cx : 0);
            final y = _readNumber() + (rel ? cy : 0);
            if (rx == 0 || ry == 0) {
              path.lineTo(x, y);
            } else {
              path.arcToPoint(
                ui.Offset(x, y),
                radius: ui.Radius.elliptical(rx, ry),
                rotation: rot,
                largeArc: largeArc,
                clockwise: sweep,
              );
            }
            cx = x;
            cy = y;
            lastCtrlX = cx;
            lastCtrlY = cy;
            lastCmd = cmd;
          } while (_hasNextNumber());
          break;
        case 'Z':
        case 'z':
          path.close();
          cx = sx;
          cy = sy;
          lastCtrlX = cx;
          lastCtrlY = cy;
          lastCmd = cmd;
          break;
        default:
          throw FormatException('Unsupported SVG path command "$cmd" in "$d"');
      }
    }
    return path;
  }
}

class _EhSvgPainter extends CustomPainter {
  const _EhSvgPainter({
    required this.spec,
    required this.color,
    this.strokeWidthOverride,
    this.blendMode,
    this.shadows,
  });

  final EhSvgSpec spec;
  final Color color;
  final double? strokeWidthOverride;
  final BlendMode? blendMode;
  final List<Shadow>? shadows;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || spec.viewBoxWidth <= 0 || spec.viewBoxHeight <= 0) {
      return;
    }
    final sx = size.width / spec.viewBoxWidth;
    final sy = size.height / spec.viewBoxHeight;
    final scale = math.min(sx, sy);
    final dx = (size.width - spec.viewBoxWidth * scale) / 2;
    final dy = (size.height - spec.viewBoxHeight * scale) / 2;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale, scale);

    final baseStroke = strokeWidthOverride ?? spec.strokeWidth;
    // Keep thin strokes crisp at 12-14px without bloating 24-28px icons.
    final effectiveStroke = math.max(baseStroke, 1.15 / scale);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = effectiveStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (blendMode != null) {
      strokePaint.blendMode = blendMode!;
    }

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    if (blendMode != null) {
      fillPaint.blendMode = blendMode!;
    }

    void drawShape(EhSvgShape shape, Paint sPaint, Paint fPaint) {
      final paint = shape.filled ? fPaint : sPaint;
      if (!shape.filled && shape.strokeWidth != null) {
        paint.strokeWidth = math.max(shape.strokeWidth!, 1.15 / scale);
      } else if (!shape.filled) {
        paint.strokeWidth = effectiveStroke;
      }
      switch (shape) {
        case EhSvgPath(:final d, :final fillEvenOdd):
          canvas.drawPath(
            parseEhSvgPathData(d, fillEvenOdd: fillEvenOdd),
            paint,
          );
        case EhSvgCircle(:final cx, :final cy, :final r):
          canvas.drawCircle(ui.Offset(cx, cy), r, paint);
        case EhSvgRect(:final x, :final y, :final width, :final height, :final rx, :final ry):
          if (rx <= 0 && ry <= 0) {
            canvas.drawRect(ui.Rect.fromLTWH(x, y, width, height), paint);
          } else {
            canvas.drawRRect(
              ui.RRect.fromRectAndRadius(
                ui.Rect.fromLTWH(x, y, width, height),
                ui.Radius.elliptical(rx > 0 ? rx : ry, ry > 0 ? ry : rx),
              ),
              paint,
            );
          }
        case EhSvgLine(:final x1, :final y1, :final x2, :final y2):
          canvas.drawLine(ui.Offset(x1, y1), ui.Offset(x2, y2), paint);
        case EhSvgPolyline(:final points, :final closed):
          if (points.length >= 4) {
            final path = ui.Path()..moveTo(points[0], points[1]);
            for (var i = 2; i + 1 < points.length; i += 2) {
              path.lineTo(points[i], points[i + 1]);
            }
            if (closed) {
              path.close();
            }
            canvas.drawPath(path, paint);
          }
      }
    }

    if (shadows != null && shadows!.isNotEmpty) {
      for (final shadow in shadows!) {
        final sShadow = Paint()
          ..color = shadow.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = effectiveStroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        final fShadow = Paint()
          ..color = shadow.color
          ..style = PaintingStyle.fill;
        if (shadow.blurSigma > 0) {
          final blur = ui.MaskFilter.blur(ui.BlurStyle.normal, shadow.blurSigma);
          sShadow.maskFilter = blur;
          fShadow.maskFilter = blur;
        }
        canvas.save();
        canvas.translate(shadow.offset.dx / scale, shadow.offset.dy / scale);
        for (final shape in spec.shapes) {
          drawShape(shape, sShadow, fShadow);
        }
        canvas.restore();
      }
    }

    for (final shape in spec.shapes) {
      drawShape(shape, strokePaint, fillPaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EhSvgPainter oldDelegate) =>
      spec != oldDelegate.spec ||
      color != oldDelegate.color ||
      strokeWidthOverride != oldDelegate.strokeWidthOverride ||
      blendMode != oldDelegate.blendMode ||
      shadows != oldDelegate.shadows;
}

Widget _buildSvgIconWidget({
  required BuildContext context,
  required EhSvgSpec spec,
  required double? size,
  required Color? color,
  required double? strokeWidth,
  required BlendMode? blendMode,
  required List<Shadow>? shadows,
  required bool? applyTextScaling,
  required String? semanticLabel,
  required TextDirection? textDirection,
  required bool matchTextDirection,
}) {
  final resolvedDirection = textDirection ?? Directionality.maybeOf(context);
  final iconTheme = IconTheme.of(context);
  final shouldScale = applyTextScaling ?? iconTheme.applyTextScaling ?? false;
  final tentativeSize = size ?? iconTheme.size ?? 24.0;
  final iconSize = shouldScale
      ? MediaQuery.textScalerOf(context).scale(tentativeSize)
      : tentativeSize;
  final opacity = iconTheme.opacity ?? 1.0;
  var iconColor = color ?? iconTheme.color ?? const Color(0xFF14161A);
  if (opacity != 1.0) {
    iconColor = iconColor.withValues(alpha: iconColor.a * opacity);
  }

  Widget painted = Center(
    widthFactor: 1.0,
    heightFactor: 1.0,
    child: SizedBox.square(
      dimension: iconSize,
      child: CustomPaint(
        size: Size.square(iconSize),
        painter: _EhSvgPainter(
          spec: spec,
          color: iconColor,
          strokeWidthOverride: strokeWidth,
          blendMode: blendMode,
          shadows: shadows,
        ),
      ),
    ),
  );

  if (matchTextDirection && resolvedDirection == TextDirection.rtl) {
    painted = Transform(
      transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
      alignment: Alignment.center,
      transformHitTests: false,
      child: painted,
    );
  }

  return Semantics(
    label: semanticLabel,
    child: ExcludeSemantics(child: painted),
  );
}

/// Drop-in [Icon] replacement that renders registered UI icons using uniform
/// monochrome linear SVG strokes while preserving `find.byIcon(...)` semantics.
class EhSvgIcon extends Icon {
  const EhSvgIcon(
    super.icon, {
    super.key,
    super.size,
    super.fill,
    super.weight,
    super.grade,
    super.opticalSize,
    super.color,
    super.shadows,
    super.semanticLabel,
    super.textDirection,
    super.applyTextScaling,
    super.blendMode,
    super.fontWeight,
    this.svgSpec,
    this.strokeWidth,
  });

  final EhSvgSpec? svgSpec;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    final resolvedSpec =
        svgSpec ?? (icon != null ? EhSvgRegistry.lookup(icon!) : null);
    if (resolvedSpec == null) {
      return super.build(context);
    }
    return _buildSvgIconWidget(
      context: context,
      spec: resolvedSpec,
      size: size,
      color: color,
      strokeWidth: strokeWidth,
      blendMode: blendMode,
      shadows: shadows,
      applyTextScaling: applyTextScaling,
      semanticLabel: semanticLabel,
      textDirection: textDirection,
      matchTextDirection: icon?.matchTextDirection ?? false,
    );
  }
}

/// Drop-in [FaIcon] replacement rendering UI FontAwesome icons as crisp
/// monochrome SVG vectors while keeping `find.byIcon(...)` compatibility.
class EhSvgFaIcon extends FaIcon {
  const EhSvgFaIcon(
    super.icon, {
    super.key,
    super.size,
    super.fill,
    super.weight,
    super.grade,
    super.opticalSize,
    super.color,
    super.shadows,
    super.semanticLabel,
    super.textDirection,
    super.applyTextScaling,
    super.blendMode,
    super.fontWeight,
    this.svgSpec,
    this.strokeWidth,
  });

  final EhSvgSpec? svgSpec;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    final data = icon;
    final resolvedSpec =
        svgSpec ?? (data != null ? EhSvgRegistry.lookup(data) : null);
    if (resolvedSpec == null) {
      return super.build(context);
    }
    return _buildSvgIconWidget(
      context: context,
      spec: resolvedSpec,
      size: size,
      color: color,
      strokeWidth: strokeWidth,
      blendMode: blendMode,
      shadows: shadows,
      applyTextScaling: applyTextScaling,
      semanticLabel: semanticLabel,
      textDirection: textDirection,
      matchTextDirection: data?.matchTextDirection ?? false,
    );
  }
}

/// Visual variants for [EhFeAppLogo].
enum EhFeLogoStyle {
  minimal,
  monochrome,
  adaptiveSplit,
  lightGlass,
  darkGlass,
  brandSquircle,
}

/// Vector SVG brand logo derived cleanly from the app icon (`Fe` monogram).
class EhFeAppLogo extends StatelessWidget {
  const EhFeAppLogo({
    super.key,
    this.size = 108.0,
    this.style = EhFeLogoStyle.brandSquircle,
    this.color,
    this.semanticLabel,
  });

  final double size;
  final EhFeLogoStyle style;
  final Color? color;
  final String? semanticLabel;

  static const LinearGradient _lightGlassGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Color(0xFFFCFDFF),
      Color(0xFFEEF2F8),
      Color(0xFFDDE3EF),
    ],
    stops: <double>[0.0, 0.52, 1.0],
  );

  static const LinearGradient _darkGlassGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Color(0xFF222631),
      Color(0xFF151821),
      Color(0xFF0C0E14),
    ],
    stops: <double>[0.0, 0.52, 1.0],
  );

  /// Architectural `F` stem and top bar monolith for the Liquid Glass mark.
  static const String _feMonolithPath =
      'M228 294A26 26 0 0 1 254 268H526A26 26 0 0 1 552 294V340A26 26 0 0 1 526 366H348A16 16 0 0 0 332 382V730A26 26 0 0 1 306 756H254A26 26 0 0 1 228 730Z';

  /// Outer geometric `e` C-arc with 18px rounded terminals for the Liquid Glass mark.
  static const String _feArcPath =
      'M795.35 711.26A156 156 0 1 1 841.71 609.54A18 18 0 0 1 820.31 626.11L774.56 617.22A18 18 0 0 1 760.00 599.63A74 74 0 1 0 734.27 656.09A18 18 0 0 1 757.10 655.55L793.82 684.24A18 18 0 0 1 795.35 711.26Z';

  /// Unified architectural geometric `Fe` monogram for [EhFeLogoStyle.minimal].
  static const EhSvgSpec feMarkSpec = EhSvgSpec(
    <EhSvgShape>[
      EhSvgPath(
        'M228 294A26 26 0 0 1 254 268H526A26 26 0 0 1 552 294V340A26 26 0 0 1 526 366H348A16 16 0 0 0 332 382V458A14 14 0 0 0 346 472H486A22 22 0 0 1 508 494V538A22 22 0 0 1 486 560H346A14 14 0 0 0 332 574V730A26 26 0 0 1 306 756H254A26 26 0 0 1 228 730Z',
        filled: true,
      ),
      EhSvgPath(
        'M795.35 711.26A156 156 0 1 1 840.44 621.97A14 14 0 0 1 826.58 634H639.52A10 10 0 0 0 632.26 650.88A74 74 0 0 0 734.27 656.09A18 18 0 0 1 757.10 655.55L793.82 684.24A18 18 0 0 1 795.35 711.26ZM625.07 558A74 74 0 0 1 746.93 558Z',
        filled: true,
        fillEvenOdd: true,
      ),
    ],
    viewBoxWidth: 1024,
    viewBoxHeight: 1024,
  );

  /// Classic rounded `Fe` monogram preserved for [EhFeLogoStyle.brandSquircle].
  static const EhSvgSpec feClassicMarkSpec = EhSvgSpec(
    <EhSvgShape>[
      EhSvgPath(
        'M230 258A56 56 0 0 1 286 202H559A51 51 0 0 1 559 304H360Q352 304 352 312V460Q352 468 360 468H521A51 51 0 0 1 521 570H360Q352 570 352 578V768A54 54 0 0 1 298 822H284A54 54 0 0 1 230 768Z',
        filled: true,
      ),
      EhSvgPath(
        'M608 560A28 28 0 0 1 636 532H762A28 28 0 0 1 762 588H681Q676 588 676 593V639Q676 644 681 644H745A28 28 0 0 1 745 700H681Q676 700 676 705V760Q676 765 681 765H767A28 28 0 0 1 767 821H636A28 28 0 0 1 608 793Z',
        filled: true,
      ),
    ],
    viewBoxWidth: 1024,
    viewBoxHeight: 1024,
  );

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final cornerRadius = BorderRadius.circular(size * 0.225);

    if (style == EhFeLogoStyle.minimal) {
      final fg = color ?? palette.text2.resolveFrom(context);
      return Semantics(
        image: true,
        label: semanticLabel ?? 'Eros-FE',
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            size: Size.square(size),
            painter: _EhSvgPainter(spec: feMarkSpec, color: fg),
          ),
        ),
      );
    }

    if (style == EhFeLogoStyle.adaptiveSplit) {
      final Color borderColor = dark
          ? const Color(0x29FFFFFF)
          : palette.hairline.resolveFrom(context);
      return Semantics(
        image: true,
        label: semanticLabel ?? 'Eros-FE',
        child: SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFFFCFDFF),
                  Color(0xFF0C0E14),
                ],
                stops: <double>[0.5, 0.5],
              ),
              shape: RoundedSuperellipseBorder(
                borderRadius: cornerRadius,
                side: BorderSide(color: borderColor, width: 0.9),
              ),
              shadows: <BoxShadow>[
                BoxShadow(
                  color: Color(dark ? 0x52000000 : 0x24162038),
                  blurRadius: size * 0.22,
                  offset: Offset(0, size * 0.08),
                ),
                BoxShadow(
                  color: Color(dark ? 0x33000000 : 0x14101626),
                  blurRadius: size * 0.04,
                  offset: Offset(0, size * 0.015),
                ),
              ],
            ),
            child: CustomPaint(
              size: Size.square(size),
              painter: _AdaptiveSplitFePainter(
                cornerRadius: cornerRadius,
                borderColor: borderColor,
                tintColor: color,
              ),
            ),
          ),
        ),
      );
    }

    if (style == EhFeLogoStyle.monochrome ||
        style == EhFeLogoStyle.lightGlass ||
        style == EhFeLogoStyle.darkGlass) {
      final bool glassDark = switch (style) {
        EhFeLogoStyle.monochrome => dark,
        EhFeLogoStyle.lightGlass => false,
        EhFeLogoStyle.darkGlass => true,
        _ => dark,
      };
      final LinearGradient glassGradient =
          glassDark ? _darkGlassGradient : _lightGlassGradient;

      return Semantics(
        image: true,
        label: semanticLabel ?? 'Eros-FE',
        child: SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              gradient: glassGradient,
              shape: RoundedSuperellipseBorder(
                borderRadius: cornerRadius,
                side: BorderSide(
                  color: glassDark
                      ? const Color(0x29FFFFFF)
                      : palette.hairline.resolveFrom(context),
                  width: 0.9,
                ),
              ),
              shadows: <BoxShadow>[
                BoxShadow(
                  color: Color(glassDark ? 0x52000000 : 0x24162038),
                  blurRadius: size * 0.22,
                  offset: Offset(0, size * 0.08),
                ),
                BoxShadow(
                  color: Color(glassDark ? 0x33000000 : 0x14101626),
                  blurRadius: size * 0.04,
                  offset: Offset(0, size * 0.015),
                ),
              ],
            ),
            child: CustomPaint(
              size: Size.square(size),
              painter: _LiquidGlassFePainter(
                cornerRadius: cornerRadius,
                isDark: glassDark,
                tintColor: color,
              ),
            ),
          ),
        ),
      );
    }

    final gradientColors = dark
        ? const <Color>[
            Color(0xFF9385BF),
            Color(0xFF8A6BC0),
            Color(0xFF8155C2),
          ]
        : const <Color>[
            Color(0xFFA599CA),
            Color(0xFFA182CF),
            Color(0xFF9D6AD3),
          ];

    return Semantics(
      image: true,
      label: semanticLabel ?? 'Eros-FE',
      child: DecoratedBox(
        decoration: ShapeDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
          shape: RoundedSuperellipseBorder(
            borderRadius: cornerRadius,
            side: BorderSide(
              color: Color(dark ? 0x26FFFFFF : 0x38FFFFFF),
              width: 1.0,
            ),
          ),
          shadows: <BoxShadow>[
            BoxShadow(
              color: Color(dark ? 0x52000000 : 0x245C3E94),
              blurRadius: size * 0.22,
              offset: Offset(0, size * 0.08),
            ),
            BoxShadow(
              color: Color(dark ? 0x33000000 : 0x1214161C),
              blurRadius: size * 0.04,
              offset: Offset(0, size * 0.015),
            ),
          ],
        ),
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            size: Size.square(size),
            painter: _EhSvgPainter(
              spec: feClassicMarkSpec,
              color: color ?? CupertinoColors.white,
              shadows: <Shadow>[
                Shadow(
                  color: const Color(0x28140A2E),
                  offset: Offset(0, size * 0.018),
                  blurRadius: 1.2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidGlassFePainter extends CustomPainter {
  const _LiquidGlassFePainter({
    required this.cornerRadius,
    required this.isDark,
    this.tintColor,
  });

  final BorderRadius cornerRadius;
  final bool isDark;
  final Color? tintColor;

  static final ui.Path _fCrossbarPath = ui.Path()
    ..addRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTRB(280, 472, 508, 560),
        const ui.Radius.circular(22),
      ),
    );

  static final ui.Path _eCrossbarPath = ui.Path()
    ..addRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTRB(604, 558, 834, 634),
        const ui.Radius.circular(20),
      ),
    );

  Color _applyTint(Color base) {
    final tint = tintColor;
    if (tint == null) {
      return base;
    }
    return Color.lerp(base, tint.withValues(alpha: base.a), 0.45) ?? base;
  }

  void _drawGlassPiece(
    Canvas canvas,
    ui.Path path, {
    required ui.Gradient fillGradient,
    required ui.Gradient rimGradient,
    required double rimStrokeWidth,
    bool ambientShadow = false,
    double contactOpacity = 0.30,
  }) {
    if (ambientShadow) {
      final ambientPaint = Paint()
        ..color = isDark
            ? const Color(0x7503050A)
            : const Color.fromRGBO(22, 32, 56, 0.18)
        ..maskFilter = ui.MaskFilter.blur(
          ui.BlurStyle.normal,
          isDark ? 18.0 : 16.0,
        );
      canvas.save();
      canvas.translate(0, isDark ? 20.0 : 18.0);
      canvas.drawPath(path, ambientPaint);
      canvas.restore();
    }

    final contactPaint = Paint()
      ..color = isDark
          ? Color.fromRGBO(3, 5, 10, contactOpacity)
          : Color.fromRGBO(16, 22, 38, contactOpacity)
      ..maskFilter = ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        isDark ? 4.5 : 4.0,
      );
    canvas.save();
    canvas.translate(0, 5.0);
    canvas.drawPath(path, contactPaint);
    canvas.restore();

    canvas.drawPath(path, Paint()..shader = fillGradient);

    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rimStrokeWidth
        ..shader = rimGradient,
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final side = size.shortestSide;
    final scale = side / 1024.0;
    final dx = (size.width - side) / 2;
    final dy = (size.height - side) / 2;

    final outerPath = RoundedSuperellipseBorder(
      borderRadius: cornerRadius,
    ).getOuterPath(ui.Offset.zero & size);

    canvas.save();
    canvas.clipPath(outerPath);

    // Top-center studio radial glow over the obsidian or ceramic silver-pearl base.
    canvas.drawRect(
      ui.Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          ui.Offset(size.width * 0.5, dy + (isDark ? 130.0 : 120.0) * scale),
          760.0 * scale,
          isDark
              ? const <Color>[Color(0x29A0B4E1), Color(0x00A0B4E1)]
              : const <Color>[Color(0x99FFFFFF), Color(0x00FFFFFF)],
          const <double>[0.0, 1.0],
        ),
    );

    // Subtle top specular rim inside the superellipse silhouette.
    canvas.drawPath(
      outerPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, side * 0.045)
        ..shader = ui.Gradient.linear(
          ui.Offset(0, dy),
          ui.Offset(0, dy + side * 0.62),
          isDark
              ? const <Color>[
                  Color(0x5CEBF2FF),
                  Color(0x1CFFFFFF),
                  Color(0x00FFFFFF),
                ]
              : const <Color>[
                  Color(0xD9FFFFFF),
                  Color(0x4DFFFFFF),
                  Color(0x00FFFFFF),
                ],
          const <double>[0.0, 0.42, 1.0],
        ),
    );

    canvas.translate(dx, dy);
    canvas.scale(scale, scale);

    final rimStrokeWidth = math.max(4.8, 1.4 / scale);
    final primaryFill = ui.Gradient.linear(
      const ui.Offset(0, 268),
      const ui.Offset(0, 756),
      isDark
          ? <Color>[
              _applyTint(const Color(0xF0FFFFFF)),
              _applyTint(const Color(0xD4D6E0F2)),
            ]
          : <Color>[
              _applyTint(const Color(0xEE2C3342)),
              _applyTint(const Color(0xF7131721)),
            ],
    );
    final secondaryFill = ui.Gradient.linear(
      const ui.Offset(0, 472),
      const ui.Offset(0, 634),
      isDark
          ? <Color>[
              _applyTint(const Color(0xA6FFFFFF)),
              _applyTint(const Color(0x88C4D2EA)),
            ]
          : <Color>[
              _applyTint(const Color(0x9456627A)),
              _applyTint(const Color(0x80363F52)),
            ],
    );
    final primaryRim = ui.Gradient.linear(
      const ui.Offset(0, 268),
      const ui.Offset(0, 756),
      isDark
          ? const <Color>[
              Color(0xF5FFFFFF),
              Color(0x3DFFFFFF),
              Color(0x14FFFFFF),
            ]
          : const <Color>[
              Color.fromRGBO(255, 255, 255, 0.72),
              Color.fromRGBO(255, 255, 255, 0.24),
              Color.fromRGBO(255, 255, 255, 0.12),
            ],
      const <double>[0.0, 0.45, 1.0],
    );
    final secondaryRim = ui.Gradient.linear(
      const ui.Offset(0, 472),
      const ui.Offset(0, 634),
      isDark
          ? const <Color>[
              Color(0xEBFFFFFF),
              Color(0x33FFFFFF),
              Color(0x14FFFFFF),
            ]
          : const <Color>[
              Color.fromRGBO(255, 255, 255, 0.72),
              Color.fromRGBO(255, 255, 255, 0.22),
              Color.fromRGBO(255, 255, 255, 0.12),
            ],
      const <double>[0.0, 0.45, 1.0],
    );

    final fMonolith = parseEhSvgPathData(EhFeAppLogo._feMonolithPath);
    final eArc = parseEhSvgPathData(EhFeAppLogo._feArcPath);
    final primaryContactOpacity = isDark ? 0.30 : 0.14;
    final secondaryContactOpacity = isDark ? 0.24 : 0.14;

    _drawGlassPiece(
      canvas,
      fMonolith,
      fillGradient: primaryFill,
      rimGradient: primaryRim,
      rimStrokeWidth: rimStrokeWidth,
      ambientShadow: true,
      contactOpacity: primaryContactOpacity,
    );
    _drawGlassPiece(
      canvas,
      eArc,
      fillGradient: primaryFill,
      rimGradient: primaryRim,
      rimStrokeWidth: rimStrokeWidth,
      ambientShadow: true,
      contactOpacity: primaryContactOpacity,
    );

    _drawGlassPiece(
      canvas,
      _fCrossbarPath,
      fillGradient: secondaryFill,
      rimGradient: secondaryRim,
      rimStrokeWidth: rimStrokeWidth,
      contactOpacity: secondaryContactOpacity,
    );
    _drawGlassPiece(
      canvas,
      _eCrossbarPath,
      fillGradient: secondaryFill,
      rimGradient: secondaryRim,
      rimStrokeWidth: rimStrokeWidth,
      contactOpacity: secondaryContactOpacity,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_LiquidGlassFePainter oldDelegate) =>
      cornerRadius != oldDelegate.cornerRadius ||
      isDark != oldDelegate.isDark ||
      tintColor != oldDelegate.tintColor;
}

class _AdaptiveSplitFePainter extends CustomPainter {
  const _AdaptiveSplitFePainter({
    required this.cornerRadius,
    required this.borderColor,
    this.tintColor,
  });

  final BorderRadius cornerRadius;
  final Color borderColor;
  final Color? tintColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final rect = ui.Offset.zero & size;
    final border = RoundedSuperellipseBorder(
      borderRadius: cornerRadius,
      side: BorderSide(color: borderColor, width: 0.9),
    );
    final outerPath = border.getOuterPath(rect);

    canvas.save();
    canvas.clipPath(outerPath);

    // Upper-left diagonal half: Ceramic Silver-Pearl × Smoked Titanium Glass Fe.
    final upperLeftHalf = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(0, size.height)
      ..close();
    canvas.save();
    canvas.clipPath(upperLeftHalf);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset.zero,
          ui.Offset(0, size.height),
          const <Color>[
            Color(0xFFFCFDFF),
            Color(0xFFEEF2F8),
            Color(0xFFDDE3EF),
          ],
          const <double>[0.0, 0.52, 1.0],
        ),
    );
    _LiquidGlassFePainter(
      cornerRadius: cornerRadius,
      isDark: false,
      tintColor: tintColor,
    ).paint(canvas, size);
    canvas.restore();

    // Lower-right diagonal half: Studio Obsidian × Frosted Crystal White Fe.
    final lowerRightHalf = ui.Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.save();
    canvas.clipPath(lowerRightHalf);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset.zero,
          ui.Offset(0, size.height),
          const <Color>[
            Color(0xFF222631),
            Color(0xFF151821),
            Color(0xFF0C0E14),
          ],
          const <double>[0.0, 0.52, 1.0],
        ),
    );
    _LiquidGlassFePainter(
      cornerRadius: cornerRadius,
      isDark: true,
      tintColor: tintColor,
    ).paint(canvas, size);
    canvas.restore();

    // Crisp subtle diagonal glass hairline separating the light and dark halves.
    canvas.drawLine(
      ui.Offset(size.width, 0),
      ui.Offset(0, size.height),
      Paint()
        ..color = const Color.fromRGBO(255, 255, 255, 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..isAntiAlias = true,
    );

    canvas.restore();

    // Re-stroke superellipse border cleanly over the split gradients.
    border.paint(canvas, rect);
  }

  @override
  bool shouldRepaint(_AdaptiveSplitFePainter oldDelegate) =>
      cornerRadius != oldDelegate.cornerRadius ||
      borderColor != oldDelegate.borderColor ||
      tintColor != oldDelegate.tintColor;
}

/// Monochrome SVG replacement for [CupertinoListTileChevron].
class EhSvgListTileChevron extends CupertinoListTileChevron {
  const EhSvgListTileChevron({super.key, this.color, this.size = 14});

  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return EhSvgIcon(
      CupertinoIcons.chevron_right,
      size: size,
      strokeWidth: 2.0,
      color: color ?? ehTheme.palette.text3.resolveFrom(context),
    );
  }
}

@immutable
class _SvgIconKey {
  const _SvgIconKey(this.codePoint, this.fontFamily);

  final int codePoint;
  final String? fontFamily;

  @override
  bool operator ==(Object other) =>
      other is _SvgIconKey &&
      other.codePoint == codePoint &&
      other.fontFamily == fontFamily;

  @override
  int get hashCode => Object.hash(codePoint, fontFamily);
}

/// Global registry mapping every UI icon across Cupertino, FontAwesome,
/// Material, Fluent and EHCupertino sets to uniform 24×24 SVG specs.
abstract final class EhSvgRegistry {
  static final Map<_SvgIconKey, EhSvgSpec> _registry = _buildRegistry();

  static EhSvgSpec? lookup(IconData icon) =>
      _registry[_SvgIconKey(icon.codePoint, icon.fontFamily)];

  static EhSvgSpec? lookupFa(FaIconData icon) => lookup(icon.data);

  static Map<_SvgIconKey, EhSvgSpec> _buildRegistry() {
    final map = <_SvgIconKey, EhSvgSpec>{};
    void reg(IconData icon, EhSvgSpec spec) {
      map[_SvgIconKey(icon.codePoint, icon.fontFamily)] = spec;
    }

    void regFa(FaIconData icon, EhSvgSpec spec) => reg(icon.data, spec);

    // ---- Shared Core SVG Specs ----
    const grid2x2 = EhSvgSpec([
      EhSvgRect(3, 3, 7.5, 7.5, rx: 1.75),
      EhSvgRect(13.5, 3, 7.5, 7.5, rx: 1.75),
      EhSvgRect(3, 13.5, 7.5, 7.5, rx: 1.75),
      EhSvgRect(13.5, 13.5, 7.5, 7.5, rx: 1.75),
    ]);
    const grid3x2 = EhSvgSpec([
      EhSvgRect(3, 4, 5, 6.5, rx: 1.25),
      EhSvgRect(9.5, 4, 5, 6.5, rx: 1.25),
      EhSvgRect(16, 4, 5, 6.5, rx: 1.25),
      EhSvgRect(3, 13.5, 5, 6.5, rx: 1.25),
      EhSvgRect(9.5, 13.5, 5, 6.5, rx: 1.25),
      EhSvgRect(16, 13.5, 5, 6.5, rx: 1.25),
    ]);
    const rectGrid2x2 = EhSvgSpec([
      EhSvgRect(3, 4, 8, 6.5, rx: 1.5),
      EhSvgRect(13, 4, 8, 6.5, rx: 1.5),
      EhSvgRect(3, 13.5, 8, 6.5, rx: 1.5),
      EhSvgRect(13, 13.5, 8, 6.5, rx: 1.5),
    ]);
    const rectGrid1x2 = EhSvgSpec([
      EhSvgRect(3, 4, 18, 6.5, rx: 1.75),
      EhSvgRect(3, 13.5, 18, 6.5, rx: 1.75),
    ]);
    const split1x2 = EhSvgSpec([
      EhSvgRect(3, 4, 18, 16, rx: 2.5),
      EhSvgLine(12, 4, 12, 20),
    ]);
    const layerGroup = EhSvgSpec([
      EhSvgPath('M12 3L3 8l9 5 9-5-9-5z'),
      EhSvgPath('M3 12.5l9 5 9-5'),
      EhSvgPath('M3 17l9 4.5 9-4.5'),
    ]);
    const flame = EhSvgSpec([
      EhSvgPath(
        'M12 3c1.8 3.1 5 4.9 5 8.8a5 5 0 0 1-10 0c0-2 .9-3.7 2.2-5-.1 1.7.8 2.8 1.9 2.8.8 0 1.4-.9.9-2.8z',
      ),
    ]);
    const eye = EhSvgSpec([
      EhSvgPath(
        'M2 12s3.5-6.5 10-6.5S22 12 22 12s-3.5 6.5-10 6.5S2 12 2 12z',
      ),
      EhSvgCircle(12, 12, 3),
    ]);
    const eyeSlash = EhSvgSpec([
      EhSvgPath(
        'M3 3l18 18M10.6 10.6a3 3 0 0 0 4.2 4.2M9.9 5.2A10.7 10.7 0 0 1 12 5c6.5 0 10 7 10 7a16.8 16.8 0 0 1-3.2 4.3M6.6 6.6A17 17 0 0 0 2 12s3.5 7 10 7a9.7 9.7 0 0 0 4.4-1',
      ),
    ]);
    const toplist = EhSvgSpec([
      EhSvgLine(9, 6, 20, 6),
      EhSvgLine(9, 12, 20, 12),
      EhSvgLine(9, 18, 20, 18),
      EhSvgCircle(4.5, 6, 1, filled: true),
      EhSvgCircle(4.5, 12, 1, filled: true),
      EhSvgCircle(4.5, 18, 1, filled: true),
    ]);
    const listIndent = EhSvgSpec([
      EhSvgLine(10, 6, 20, 6),
      EhSvgLine(10, 12, 20, 12),
      EhSvgLine(10, 18, 20, 18),
      EhSvgPath('M4 9l3 3-3 3'),
    ]);
    const heartOutline = EhSvgSpec([
      EhSvgPath(
        'M19.5 12.6L12 20l-7.5-7.4a4.9 4.9 0 0 1 6.9-6.9l.6.6.6-.6a4.9 4.9 0 0 1 6.9 6.9z',
      ),
    ]);
    const heartFilled = EhSvgSpec([
      EhSvgPath(
        'M19.5 12.6L12 20l-7.5-7.4a4.9 4.9 0 0 1 6.9-6.9l.6.6.6-.6a4.9 4.9 0 0 1 6.9 6.9z',
        filled: true,
      ),
    ]);
    const heartSlash = EhSvgSpec([
      EhSvgPath(
        'M19.5 12.6L12 20l-7.5-7.4a4.9 4.9 0 0 1 6.9-6.9l.6.6.6-.6a4.9 4.9 0 0 1 6.9 6.9z',
      ),
      EhSvgLine(4, 4, 20, 20),
    ]);
    const downloadLine = EhSvgSpec([
      EhSvgLine(12, 4, 12, 15),
      EhSvgPolyline([7.5, 10.5, 12, 15, 16.5, 10.5]),
      EhSvgLine(5.5, 19.5, 18.5, 19.5),
    ]);
    const downloadCircle = EhSvgSpec([
      EhSvgCircle(12, 12, 9),
      EhSvgLine(12, 8, 12, 16),
      EhSvgPolyline([8.5, 12.5, 12, 16, 15.5, 12.5]),
    ]);
    const downloadCircleFilled = EhSvgSpec([
      EhSvgCircle(12, 12, 9.5, filled: true),
    ]);
    const clock = EhSvgSpec([
      EhSvgCircle(12, 12, 9),
      EhSvgPolyline([12, 7, 12, 12, 15.5, 14]),
    ]);
    const timer = EhSvgSpec([
      EhSvgCircle(12, 13.5, 7.5),
      EhSvgLine(12, 13.5, 15, 10.5),
      EhSvgLine(10, 3, 14, 3),
      EhSvgLine(12, 3, 12, 6),
    ]);
    const settings = EhSvgSpec([
      EhSvgCircle(12, 12, 2.7),
      EhSvgPath(
        'M17.97 10.34 L20.59 10.64 L20.59 13.36 L17.97 13.66 L17.40 15.05 L19.04 17.11 L17.11 19.04 L15.05 17.40 L13.66 17.97 L13.36 20.59 L10.64 20.59 L10.34 17.97 L8.95 17.40 L6.89 19.04 L4.96 17.11 L6.60 15.05 L6.03 13.66 L3.41 13.36 L3.41 10.64 L6.03 10.34 L6.60 8.95 L4.96 6.89 L6.89 4.96 L8.95 6.60 L10.34 6.03 L10.64 3.41 L13.36 3.41 L13.66 6.03 L15.05 6.60 L17.11 4.96 L19.04 6.89 L17.40 8.95 Z',
      ),
    ]);
    const search = EhSvgSpec([
      EhSvgCircle(11, 11, 7),
      EhSvgLine(20, 20, 16.2, 16.2),
    ]);
    const sidebarLeft = EhSvgSpec([
      EhSvgRect(3, 4, 18, 16, rx: 3),
      EhSvgLine(9, 4, 9, 20),
    ]);
    const book = EhSvgSpec([
      EhSvgPath('M3 5h6a3 3 0 0 1 3 3v11.5a2.5 2.5 0 0 0-2.5-2.5H3z'),
      EhSvgPath('M21 5h-6a3 3 0 0 0-3 3v11.5a2.5 2.5 0 0 1 2.5-2.5H21z'),
    ]);
    const bookFilled = EhSvgSpec([
      EhSvgPath(
        'M3.2 5.2h5.4a2.8 2.8 0 0 1 2.8 2.8v11a2.2 2.2 0 0 0-2-1.5H3.2a.8.8 0 0 1-.8-.8V6a.8.8 0 0 1 .8-.8z',
        filled: true,
      ),
      EhSvgPath(
        'M20.8 5.2h-5.4a2.8 2.8 0 0 0-2.8 2.8v11a2.2 2.2 0 0 1 2-1.5h6.2a.8.8 0 0 0 .8-.8V6a.8.8 0 0 0-.8-.8z',
        filled: true,
      ),
    ]);
    const globe = EhSvgSpec([
      EhSvgCircle(12, 12, 9),
      EhSvgLine(3, 12, 21, 12),
      EhSvgPath('M12 3a14 14 0 0 0 0 18 14 14 0 0 0 0-18'),
    ]);
    const language = EhSvgSpec([
      EhSvgPath('M5 8l6 6'),
      EhSvgPath('M4 14l6-6 2-3'),
      EhSvgLine(2, 5, 14, 5),
      EhSvgLine(7, 2, 8, 2),
      EhSvgPath('M22 22l-5-10-5 10'),
      EhSvgLine(14, 18, 20, 18),
    ]);
    const shield = EhSvgSpec([
      EhSvgPath('M12 21s7-3.5 7-9.5V5.5L12 3 5 5.5v6c0 6 7 9.5 7 9.5z'),
    ]);
    const shieldLock = EhSvgSpec([
      EhSvgPath('M12 21s7-3.5 7-9.5V5.5L12 3 5 5.5v6c0 6 7 9.5 7 9.5z'),
      EhSvgRect(9.5, 11.5, 5, 4, rx: 1),
      EhSvgPath('M10.5 11.5v-1a1.5 1.5 0 0 1 3 0v1'),
    ]);
    const shieldXmark = EhSvgSpec([
      EhSvgPath('M12 21s7-3.5 7-9.5V5.5L12 3 5 5.5v6c0 6 7 9.5 7 9.5z'),
      EhSvgLine(9.5, 9.5, 14.5, 14.5),
      EhSvgLine(14.5, 9.5, 9.5, 14.5),
    ]);
    const lock = EhSvgSpec([
      EhSvgRect(5, 11, 14, 10, rx: 2),
      EhSvgPath('M8 11V7.5a4 4 0 0 1 8 0V11'),
    ]);
    const lockFilled = EhSvgSpec([
      EhSvgRect(5, 11, 14, 10, rx: 2, filled: true),
      EhSvgPath('M8 11V7.5a4 4 0 0 1 8 0V11'),
    ]);
    const sliders = EhSvgSpec([
      EhSvgLine(4, 20, 4, 14),
      EhSvgLine(4, 10, 4, 4),
      EhSvgLine(12, 20, 12, 12),
      EhSvgLine(12, 8, 12, 4),
      EhSvgLine(20, 20, 20, 16),
      EhSvgLine(20, 12, 20, 4),
      EhSvgLine(2, 14, 6, 14),
      EhSvgLine(10, 8, 14, 8),
      EhSvgLine(18, 16, 22, 16),
    ]);
    const infoCircle = EhSvgSpec([
      EhSvgCircle(12, 12, 9),
      EhSvgLine(12, 16, 12, 12),
      EhSvgCircle(12, 8.5, 0.8, filled: true),
    ]);
    const exclamationCircle = EhSvgSpec([
      EhSvgCircle(12, 12, 9),
      EhSvgLine(12, 8, 12, 13),
      EhSvgCircle(12, 16.5, 0.8, filled: true),
    ]);
    const warningTriangle = EhSvgSpec([
      EhSvgPath(
        'M10.3 4.3L2.6 17.6A2 2 0 0 0 4.3 20.5h15.4a2 2 0 0 0 1.7-2.9L13.7 4.3a2 2 0 0 0-3.4 0z',
      ),
      EhSvgLine(12, 9.5, 12, 13.8),
      EhSvgCircle(12, 17, 0.8, filled: true),
    ]);
    const user = EhSvgSpec([
      EhSvgPath('M20 20v-1.5a4.5 4.5 0 0 0-4.5-4.5h-7A4.5 4.5 0 0 0 4 18.5V20'),
      EhSvgCircle(12, 7.5, 3.5),
    ]);
    const userAdd = EhSvgSpec([
      EhSvgPath('M16 20v-1.5a4 4 0 0 0-4-4H6.5a4 4 0 0 0-4 4V20'),
      EhSvgCircle(9.25, 7.5, 3.25),
      EhSvgLine(19, 8, 19, 14),
      EhSvgLine(16, 11, 22, 11),
    ]);
    const userCircle = EhSvgSpec([
      EhSvgCircle(12, 12, 9.5),
      EhSvgCircle(12, 9.5, 3),
      EhSvgPath('M6.8 18.8a6 6 0 0 1 10.4 0'),
    ]);
    const house = EhSvgSpec([
      EhSvgPath('M3 10.5L12 3l9 7.5V20a1.5 1.5 0 0 1-1.5 1.5H4.5A1.5 1.5 0 0 1 3 20z'),
      EhSvgPolyline([9, 21.5, 9, 14, 15, 14, 15, 21.5]),
    ]);
    const chevronRight = EhSvgSpec([EhSvgPolyline([9, 6, 15, 12, 9, 18])]);
    const chevronLeft = EhSvgSpec([EhSvgPolyline([15, 6, 9, 12, 15, 18])]);
    const chevronUp = EhSvgSpec([EhSvgPolyline([6, 15, 12, 9, 18, 15])]);
    const chevronDown = EhSvgSpec([EhSvgPolyline([6, 9, 12, 15, 18, 9])]);
    const chevronUpDown = EhSvgSpec([
      EhSvgPolyline([7, 9, 12, 4, 17, 9]),
      EhSvgPolyline([7, 15, 12, 20, 17, 15]),
    ]);
    const arrowUp = EhSvgSpec([
      EhSvgLine(12, 19, 12, 5),
      EhSvgPolyline([6, 11, 12, 5, 18, 11]),
    ]);
    const arrowDown = EhSvgSpec([
      EhSvgLine(12, 5, 12, 19),
      EhSvgPolyline([6, 13, 12, 19, 18, 13]),
    ]);
    const arrowLeft = EhSvgSpec([
      EhSvgLine(19, 12, 5, 12),
      EhSvgPolyline([11, 6, 5, 12, 11, 18]),
    ]);
    const arrowRight = EhSvgSpec([
      EhSvgLine(5, 12, 19, 12),
      EhSvgPolyline([13, 6, 19, 12, 13, 18]),
    ]);
    const arrowUpLeft = EhSvgSpec([
      EhSvgLine(17, 17, 7, 7),
      EhSvgPolyline([7, 16, 7, 7, 16, 7]),
    ]);
    const arrowUpToLine = EhSvgSpec([
      EhSvgLine(5, 4, 19, 4),
      EhSvgLine(12, 20, 12, 8),
      EhSvgPolyline([7, 13, 12, 8, 17, 13]),
    ]);
    const arrowUpCircle = EhSvgSpec([
      EhSvgCircle(12, 12, 9),
      EhSvgLine(12, 16, 12, 8),
      EhSvgPolyline([8.5, 11.5, 12, 8, 15.5, 11.5]),
    ]);
    const arrowUturnDownCircle = EhSvgSpec([
      EhSvgCircle(12, 12, 9),
      EhSvgPath('M14.5 14.5V10.5a3 3 0 0 0-6 0v2'),
      EhSvgPolyline([12, 12.5, 14.5, 15, 17, 12.5]),
    ]);
    const arrowUpArrowDown = EhSvgSpec([
      EhSvgLine(8, 5, 8, 19),
      EhSvgPolyline([5, 8, 8, 5, 11, 8]),
      EhSvgLine(16, 19, 16, 5),
      EhSvgPolyline([13, 16, 16, 19, 19, 16]),
    ]);
    const arrowLeftRight = EhSvgSpec([
      EhSvgLine(4, 8, 20, 8),
      EhSvgPolyline([16.5, 4.5, 20, 8, 16.5, 11.5]),
      EhSvgLine(20, 16, 4, 16),
      EhSvgPolyline([7.5, 12.5, 4, 16, 7.5, 19.5]),
    ]);
    const returnKey = EhSvgSpec([
      EhSvgPath('M19 6v6a3 3 0 0 1-3 3H6'),
      EhSvgPolyline([10, 11, 6, 15, 10, 19]),
    ]);
    const xmark = EhSvgSpec([
      EhSvgLine(6, 6, 18, 18),
      EhSvgLine(18, 6, 6, 18),
    ]);
    const xmarkCircle = EhSvgSpec([
      EhSvgCircle(12, 12, 9),
      EhSvgLine(9, 9, 15, 15),
      EhSvgLine(15, 9, 9, 15),
    ]);
    const xmarkCircleFilled = EhSvgSpec([
      EhSvgPath(
        'M12 2.5a9.5 9.5 0 1 0 0 19 9.5 9.5 0 1 0 0-19zm-3.2 6.3a.85.85 0 0 1 1.2 0L12 10.8l2-2a.85.85 0 1 1 1.2 1.2L13.2 12l2 2a.85.85 0 1 1-1.2 1.2L12 13.2l-2 2a.85.85 0 1 1-1.2-1.2l2-2-2-2a.85.85 0 0 1 0-1.2z',
        filled: true,
        fillEvenOdd: true,
      ),
    ]);
    const check = EhSvgSpec([EhSvgPolyline([5, 12.5, 9.5, 17, 19, 7])]);
    const checkCircle = EhSvgSpec([
      EhSvgCircle(12, 12, 9),
      EhSvgPolyline([8.5, 12.5, 11, 15, 15.8, 9.5]),
    ]);
    const checkCircleFilled = EhSvgSpec([
      EhSvgPath(
        'M12 2.5a9.5 9.5 0 1 0 0 19 9.5 9.5 0 1 0 0-19zm4.4 7.7l-5.2 5.4a.85.85 0 0 1-1.22 0l-2.4-2.4a.85.85 0 1 1 1.2-1.2l1.8 1.8 4.6-4.8a.85.85 0 1 1 1.22 1.2z',
        filled: true,
        fillEvenOdd: true,
      ),
    ]);
    const plus = EhSvgSpec([
      EhSvgLine(12, 5, 12, 19),
      EhSvgLine(5, 12, 19, 12),
    ]);
    const plusCircle = EhSvgSpec([
      EhSvgCircle(12, 12, 9),
      EhSvgLine(12, 8.5, 12, 15.5),
      EhSvgLine(8.5, 12, 15.5, 12),
    ]);
    const trash = EhSvgSpec([
      EhSvgLine(4, 7, 20, 7),
      EhSvgLine(10, 11, 10, 17),
      EhSvgLine(14, 11, 14, 17),
      EhSvgPath('M6 7l1 12a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-12'),
      EhSvgPath('M9 7V4.5A1.5 1.5 0 0 1 10.5 3h3A1.5 1.5 0 0 1 15 4.5V7'),
    ]);
    const pencil = EhSvgSpec([
      EhSvgPath('M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z'),
      EhSvgLine(14, 6, 18, 10),
    ]);
    const penToSquare = EhSvgSpec([
      EhSvgPath('M11 4H5a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2h13a2 2 0 0 0 2-2v-6'),
      EhSvgPath('M18.5 2.5a2.1 2.1 0 0 1 3 3L12 15l-4 1 1-4z'),
    ]);
    const penRuler = EhSvgSpec([
      EhSvgPath('M15 4l5 5L8 21H3v-5z'),
      EhSvgLine(12, 7, 17, 12),
      EhSvgLine(8, 11, 10, 13),
    ]);
    const folder = EhSvgSpec([
      EhSvgPath(
        'M3 18.5a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V8.5a2 2 0 0 0-2-2h-7l-2-2.5H5a2 2 0 0 0-2 2z',
      ),
    ]);
    const archivebox = EhSvgSpec([
      EhSvgRect(3, 4, 18, 4, rx: 1),
      EhSvgPath('M5 8v10a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8'),
      EhSvgLine(10, 12, 14, 12),
    ]);
    const tray = EhSvgSpec([
      EhSvgPath('M4 13V6a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v7'),
      EhSvgPath('M4 13h4l2 2.5h4L16 13h4v5a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2z'),
    ]);
    const docOnDoc = EhSvgSpec([
      EhSvgRect(9, 9, 11, 12, rx: 2),
      EhSvgPath('M5 15H4a1.5 1.5 0 0 1-1.5-1.5v-9A1.5 1.5 0 0 1 4 3h9a1.5 1.5 0 0 1 1.5 1.5V6'),
    ]);
    const clipboard = EhSvgSpec([
      EhSvgRect(8, 3, 8, 4, rx: 1),
      EhSvgPath('M8 5H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2'),
    ]);
    const fileLines = EhSvgSpec([
      EhSvgPath('M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z'),
      EhSvgPolyline([14, 3, 14, 9, 20, 9]),
      EhSvgLine(8, 13, 16, 13),
      EhSvgLine(8, 17, 14, 17),
    ]);
    const fileZip = EhSvgSpec([
      EhSvgPath('M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z'),
      EhSvgPolyline([14, 3, 14, 9, 20, 9]),
      EhSvgLine(10, 7, 10, 17),
      EhSvgLine(9, 10, 11, 10),
      EhSvgLine(9, 13, 11, 13),
    ]);
    const fileArrowDown = EhSvgSpec([
      EhSvgPath('M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z'),
      EhSvgPolyline([14, 3, 14, 9, 20, 9]),
      EhSvgLine(12, 11, 12, 17),
      EhSvgPolyline([9.5, 14.5, 12, 17, 14.5, 14.5]),
    ]);
    const fileArrowUp = EhSvgSpec([
      EhSvgPath('M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z'),
      EhSvgPolyline([14, 3, 14, 9, 20, 9]),
      EhSvgLine(12, 17, 12, 11),
      EhSvgPolyline([9.5, 13.5, 12, 11, 14.5, 13.5]),
    ]);
    const fileExport = EhSvgSpec([
      EhSvgPath('M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z'),
      EhSvgLine(11, 14, 21, 14),
      EhSvgPolyline([18, 11, 21, 14, 18, 17]),
    ]);
    const fileImport = EhSvgSpec([
      EhSvgPath('M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z'),
      EhSvgLine(21, 14, 11, 14),
      EhSvgPolyline([14, 11, 11, 14, 14, 17]),
    ]);
    const share = EhSvgSpec([
      EhSvgLine(12, 15, 12, 4),
      EhSvgPolyline([8, 8, 12, 4, 16, 8]),
      EhSvgPath('M5 13v5a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-5'),
    ]);
    const signOut = EhSvgSpec([
      EhSvgPath('M9 20H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h4'),
      EhSvgPolyline([16, 17, 21, 12, 16, 7]),
      EhSvgLine(21, 12, 9, 12),
    ]);
    const refresh = EhSvgSpec([
      EhSvgPath('M20 11a8 8 0 0 0-14.9-3'),
      EhSvgPolyline([4, 4, 4, 8, 8, 8]),
      EhSvgPath('M4 13a8 8 0 0 0 14.9 3'),
      EhSvgPolyline([20, 20, 20, 16, 16, 16]),
    ]);
    const rotateCw = EhSvgSpec([
      EhSvgPath('M20 11a8 8 0 1 1-2.3-5.6L20 8'),
      EhSvgPolyline([20, 3, 20, 8, 15, 8]),
    ]);
    const rotateCcw = EhSvgSpec([
      EhSvgPath('M4 11a8 8 0 1 0 2.3-5.6L4 8'),
      EhSvgPolyline([4, 3, 4, 8, 9, 8]),
    ]);
    const ellipsis = EhSvgSpec([
      EhSvgCircle(5.5, 12, 1.3, filled: true),
      EhSvgCircle(12, 12, 1.3, filled: true),
      EhSvgCircle(18.5, 12, 1.3, filled: true),
    ]);
    const ellipsisVert = EhSvgSpec([
      EhSvgCircle(12, 5.5, 1.3, filled: true),
      EhSvgCircle(12, 12, 1.3, filled: true),
      EhSvgCircle(12, 18.5, 1.3, filled: true),
    ]);
    const ellipsisCircle = EhSvgSpec([
      EhSvgCircle(12, 12, 9),
      EhSvgCircle(8, 12, 1, filled: true),
      EhSvgCircle(12, 12, 1, filled: true),
      EhSvgCircle(16, 12, 1, filled: true),
    ]);
    const bars = EhSvgSpec([
      EhSvgLine(4, 6, 20, 6),
      EhSvgLine(4, 12, 20, 12),
      EhSvgLine(4, 18, 20, 18),
    ]);
    const filterDecrease = EhSvgSpec([
      EhSvgLine(4, 6, 20, 6),
      EhSvgLine(7, 12, 17, 12),
      EhSvgLine(10, 18, 14, 18),
    ]);
    const sortDown = EhSvgSpec([
      EhSvgLine(4, 6, 16, 6),
      EhSvgLine(4, 12, 12, 12),
      EhSvgLine(4, 18, 9, 18),
      EhSvgLine(18, 9, 18, 19),
      EhSvgPolyline([15, 16, 18, 19, 21, 16]),
    ]);
    const photo = EhSvgSpec([
      EhSvgRect(3, 4, 18, 16, rx: 2.5),
      EhSvgCircle(8.5, 9.5, 1.5),
      EhSvgPath('M21 16l-4.5-4.5a1.5 1.5 0 0 0-2.1 0L6 20'),
    ]);
    const images = EhSvgSpec([
      EhSvgRect(6, 5, 15, 12, rx: 2),
      EhSvgPath('M3 9v10a2 2 0 0 0 2 2h12'),
      EhSvgCircle(10.5, 9.5, 1.25),
      EhSvgPath('M21 14l-3.5-3.5-5 5'),
    ]);
    const rectangle = EhSvgSpec([EhSvgRect(3, 5, 18, 14, rx: 2.5)]);
    const playOutline = EhSvgSpec([
      EhSvgPath('M7 5.5v13l11-6.5z'),
    ]);
    const playFilled = EhSvgSpec([
      EhSvgPath('M7 5.5v13l11-6.5z', filled: true),
    ]);
    const pauseOutline = EhSvgSpec([
      EhSvgRect(6, 5, 4, 14, rx: 1),
      EhSvgRect(14, 5, 4, 14, rx: 1),
    ]);
    const pauseFilled = EhSvgSpec([
      EhSvgRect(6, 5, 4, 14, rx: 1, filled: true),
      EhSvgRect(14, 5, 4, 14, rx: 1, filled: true),
    ]);
    const stopOutline = EhSvgSpec([EhSvgRect(6, 6, 12, 12, rx: 2)]);
    const backwardEnd = EhSvgSpec([
      EhSvgLine(6, 6, 6, 18),
      EhSvgPath('M18 6l-9 6 9 6z'),
    ]);
    const forwardEnd = EhSvgSpec([
      EhSvgLine(18, 6, 18, 18),
      EhSvgPath('M6 6l9 6-9 6z'),
    ]);
    const fullscreen = EhSvgSpec([
      EhSvgPolyline([8, 4, 4, 4, 4, 8]),
      EhSvgPolyline([16, 4, 20, 4, 20, 8]),
      EhSvgPolyline([4, 16, 4, 20, 8, 20]),
      EhSvgPolyline([20, 16, 20, 20, 16, 20]),
    ]);
    const fullscreenExit = EhSvgSpec([
      EhSvgPolyline([4, 8, 8, 8, 8, 4]),
      EhSvgPolyline([20, 8, 16, 8, 16, 4]),
      EhSvgPolyline([4, 16, 8, 16, 8, 20]),
      EhSvgPolyline([20, 16, 16, 16, 16, 20]),
    ]);
    const tag = EhSvgSpec([
      EhSvgPath(
        'M12 3H5a2 2 0 0 0-2 2v7l8.3 8.3a2 2 0 0 0 2.8 0l6.2-6.2a2 2 0 0 0 0-2.8z',
      ),
      EhSvgCircle(7.5, 7.5, 1, filled: true),
    ]);
    const tags = EhSvgSpec([
      EhSvgPath(
        'M11 4H5a2 2 0 0 0-2 2v6l6.8 6.8a1.8 1.8 0 0 0 2.5 0l5-5a1.8 1.8 0 0 0 0-2.5z',
      ),
      EhSvgPath('M15 4l5.5 5.5a2 2 0 0 1 0 2.8l-5.5 5.5'),
      EhSvgCircle(7, 8, 0.9, filled: true),
    ]);
    const starOutline = EhSvgSpec([
      EhSvgPath(
        'M12 3l2.7 5.5 6.1.9-4.4 4.3 1 6.1-5.4-2.9-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z',
      ),
    ]);
    const starFilled = EhSvgSpec([
      EhSvgPath(
        'M12 3l2.7 5.5 6.1.9-4.4 4.3 1 6.1-5.4-2.9-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z',
        filled: true,
      ),
    ]);
    const thumbsUp = EhSvgSpec([
      EhSvgPath('M7 10v10H4a1 1 0 0 1-1-1v-8a1 1 0 0 1 1-1z'),
      EhSvgPath(
        'M7 10l4-6.5a1.5 1.5 0 0 1 2.8.8V9h5.3a2 2 0 0 1 1.9 2.5l-1.4 6.5a2 2 0 0 1-2 1.5H7',
      ),
    ]);
    const thumbsDown = EhSvgSpec([
      EhSvgPath('M7 14V4H4a1 1 0 0 0-1 1v8a1 1 0 0 0 1 1z'),
      EhSvgPath(
        'M7 14l4 6.5a1.5 1.5 0 0 0 2.8-.8V15h5.3a2 2 0 0 0 1.9-2.5l-1.4-6.5a2 2 0 0 0-2-1.5H7',
      ),
    ]);
    const link = EhSvgSpec([
      EhSvgPath('M10 13a5 5 0 0 0 7.1.4l2.4-2.4a5 5 0 0 0-7.1-7.1L11 5.3'),
      EhSvgPath('M14 11a5 5 0 0 0-7.1-.4L4.5 13a5 5 0 0 0 7.1 7.1L13 18.7'),
    ]);
    const magnet = EhSvgSpec([
      EhSvgPath('M6 5v7a6 6 0 0 0 12 0V5'),
      EhSvgLine(6, 8, 9.5, 8),
      EhSvgLine(14.5, 8, 18, 8),
      EhSvgPath('M9.5 5v7a2.5 2.5 0 0 0 5 0V5'),
    ]);
    const reply = EhSvgSpec([
      EhSvgPolyline([9, 14, 4, 9, 9, 4]),
      EhSvgPath('M20 19v-4a6 6 0 0 0-6-6H4'),
    ]);
    const atSign = EhSvgSpec([
      EhSvgCircle(12, 12, 3.8),
      EhSvgPath('M15.8 8.2v5.3a2.4 2.4 0 0 0 4.7.5A9 9 0 1 0 16 19.8'),
    ]);
    const message = EhSvgSpec([
      EhSvgPath(
        'M20 15a2 2 0 0 1-2 2H8l-4 4V6a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2z',
      ),
    ]);
    const bell = EhSvgSpec([
      EhSvgPath('M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9'),
      EhSvgPath('M10.3 20a2 2 0 0 0 3.4 0'),
    ]);
    const calendar = EhSvgSpec([
      EhSvgRect(3, 5, 18, 16, rx: 2.5),
      EhSvgLine(3, 10, 21, 10),
      EhSvgLine(8, 3, 8, 7),
      EhSvgLine(16, 3, 16, 7),
    ]);
    const tickets = EhSvgSpec([
      EhSvgPath(
        'M3 9a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v1.5a1.5 1.5 0 0 0 0 3V15a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-1.5a1.5 1.5 0 0 0 0-3z',
      ),
      EhSvgLine(14, 7, 14, 17),
    ]);
    const database = EhSvgSpec([
      EhSvgPath('M4 6c0 1.66 3.58 3 8 3s8-1.34 8-3-3.58-3-8-3-8 1.34-8 3z'),
      EhSvgPath('M4 6v12c0 1.66 3.58 3 8 3s8-1.34 8-3V6'),
      EhSvgPath('M4 12c0 1.66 3.58 3 8 3s8-1.34 8-3'),
    ]);
    const cloud = EhSvgSpec([
      EhSvgPath(
        'M17.5 19H8a5 5 0 0 1-.8-9.9A6 6 0 0 1 18.8 11 4 4 0 0 1 17.5 19z',
      ),
    ]);
    const floppy = EhSvgSpec([
      EhSvgPath(
        'M19 20H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h11l5 5v9a2 2 0 0 1-2 2z',
      ),
      EhSvgPolyline([7, 4, 7, 9, 15, 9, 15, 4]),
      EhSvgRect(8, 14, 8, 6, rx: 1),
    ]);
    const hourglass = EhSvgSpec([
      EhSvgLine(6, 4, 18, 4),
      EhSvgLine(6, 20, 18, 20),
      EhSvgPath('M7 4c0 4 5 6 5 8s-5 4-5 8'),
      EhSvgPath('M17 4c0 4-5 6-5 8s5 4 5 8'),
    ]);
    const textFormat = EhSvgSpec([
      EhSvgPath('M4 19L9 5l5 14'),
      EhSvgLine(5.8, 14, 12.2, 14),
      EhSvgPath('M16 14.5c0-1.5 1-2.5 2.5-2.5s2.5 1 2.5 2.5V19'),
      EhSvgCircle(18.5, 16.5, 2.2),
    ]);
    const heading = EhSvgSpec([
      EhSvgLine(6, 5, 6, 19),
      EhSvgLine(18, 5, 18, 19),
      EhSvgLine(6, 12, 18, 12),
    ]);
    const circleOutline = EhSvgSpec([EhSvgCircle(12, 12, 8.5)]);
    const circleDot = EhSvgSpec([
      EhSvgCircle(12, 12, 8.5),
      EhSvgCircle(12, 12, 3, filled: true),
    ]);
    const ant = EhSvgSpec([
      EhSvgCircle(12, 7, 2.2),
      EhSvgCircle(12, 12, 2.4),
      EhSvgCircle(12, 17.5, 2.8),
      EhSvgPath('M7 10l3 1M17 10l-3 1M6 13.5l4-.5M18 13.5l-4-.5M7 17.5l3-1M17 17.5l-3-1'),
    ]);
    const adRect = EhSvgSpec([
      EhSvgRect(3, 5, 18, 14, rx: 2.5),
      EhSvgLine(7, 15, 9.5, 9),
      EhSvgLine(12, 15, 9.5, 9),
      EhSvgLine(8, 13, 11, 13),
      EhSvgPath('M14 9h2a2 2 0 0 1 0 6h-2z'),
    ]);
    const roadBarrier = EhSvgSpec([
      EhSvgRect(3, 6, 18, 7, rx: 1.5),
      EhSvgLine(7, 6, 10, 13),
      EhSvgLine(13, 6, 16, 13),
      EhSvgLine(6, 13, 6, 20),
      EhSvgLine(18, 13, 18, 20),
    ]);
    const fillDrop = EhSvgSpec([
      EhSvgPath('M12 3.5C9 7.5 6 11 6 14.5a6 6 0 0 0 12 0c0-3.5-3-7-6-11z'),
    ]);
    const keyboardDismiss = EhSvgSpec([
      EhSvgRect(3, 5, 18, 10, rx: 2),
      EhSvgLine(7, 9, 17, 9),
      EhSvgLine(9, 12, 15, 12),
      EhSvgPolyline([8, 18, 12, 21, 16, 18]),
    ]);
    const winMinimize = EhSvgSpec([EhSvgLine(5, 12, 19, 12)]);
    const winMaximize = EhSvgSpec([EhSvgRect(5, 5, 14, 14, rx: 1.5)]);
    const winRestore = EhSvgSpec([
      EhSvgRect(4, 7, 12, 12, rx: 1.5),
      EhSvgPath('M8 7V5a1.5 1.5 0 0 1 1.5-1.5h9A1.5 1.5 0 0 1 20 5v9a1.5 1.5 0 0 1-1.5 1.5H16'),
    ]);
    const hippoLine = EhSvgSpec([
      EhSvgPath('M6 12c0-3.3 2.7-6 6-6s6 2.7 6 6v3.5a3.5 3.5 0 0 1-3.5 3.5h-5A3.5 3.5 0 0 1 6 15.5z'),
      EhSvgCircle(8, 6.5, 1.5),
      EhSvgCircle(16, 6.5, 1.5),
      EhSvgCircle(9.5, 10.5, 0.8, filled: true),
      EhSvgCircle(14.5, 10.5, 0.8, filled: true),
      EhSvgCircle(9.5, 15.2, 0.9, filled: true),
      EhSvgCircle(14.5, 15.2, 0.9, filled: true),
    ]);
    const catLine = EhSvgSpec([
      EhSvgPath('M5 10L6 4l4 2.8h4L18 4l1 6v4a7 7 0 0 1-14 0z'),
      EhSvgCircle(9.5, 12, 0.85, filled: true),
      EhSvgCircle(14.5, 12, 0.85, filled: true),
      EhSvgPath('M11 15l1 1 1-1'),
    ]);

    // ---- Register CupertinoIcons ----
    reg(CupertinoIcons.square_grid_2x2, grid2x2);
    reg(CupertinoIcons.square_grid_3x2, grid3x2);
    reg(CupertinoIcons.rectangle_grid_2x2, rectGrid2x2);
    reg(CupertinoIcons.rectangle_grid_1x2, rectGrid1x2);
    reg(CupertinoIcons.square_split_1x2, split1x2);
    reg(CupertinoIcons.collections, images);
    reg(CupertinoIcons.flame, flame);
    reg(CupertinoIcons.eye, eye);
    reg(CupertinoIcons.eye_slash, eyeSlash);
    reg(CupertinoIcons.list_bullet, toplist);
    reg(CupertinoIcons.list_bullet_indent, listIndent);
    reg(CupertinoIcons.heart, heartOutline);
    reg(CupertinoIcons.heart_fill, heartFilled);
    reg(CupertinoIcons.heart_slash, heartSlash);
    reg(CupertinoIcons.arrow_down_to_line, downloadLine);
    reg(CupertinoIcons.arrow_down_circle, downloadCircle);
    reg(CupertinoIcons.arrow_down_circle_fill, downloadCircleFilled);
    reg(CupertinoIcons.clock, clock);
    reg(CupertinoIcons.timer, timer);
    reg(CupertinoIcons.settings, settings);
    reg(CupertinoIcons.search, search);
    reg(CupertinoIcons.sidebar_left, sidebarLeft);
    reg(CupertinoIcons.book, book);
    reg(CupertinoIcons.book_fill, bookFilled);
    reg(CupertinoIcons.globe, globe);
    reg(CupertinoIcons.shield, shield);
    reg(CupertinoIcons.shield_lefthalf_fill, shield);
    reg(CupertinoIcons.lock_shield, shieldLock);
    reg(CupertinoIcons.xmark_shield_fill, shieldXmark);
    reg(CupertinoIcons.lock, lock);
    reg(CupertinoIcons.lock_fill, lockFilled);
    reg(CupertinoIcons.slider_horizontal_3, sliders);
    reg(CupertinoIcons.info_circle, infoCircle);
    reg(CupertinoIcons.exclamationmark_circle, exclamationCircle);
    reg(CupertinoIcons.exclamationmark_triangle, warningTriangle);
    reg(CupertinoIcons.person, user);
    reg(CupertinoIcons.person_add, userAdd);
    reg(CupertinoIcons.person_crop_circle, userCircle);
    reg(CupertinoIcons.house, house);
    reg(CupertinoIcons.chevron_right, chevronRight);
    reg(CupertinoIcons.chevron_forward, chevronRight);
    reg(CupertinoIcons.forward, chevronRight);
    reg(CupertinoIcons.chevron_left, chevronLeft);
    reg(CupertinoIcons.chevron_back, chevronLeft);
    reg(CupertinoIcons.back, chevronLeft);
    reg(CupertinoIcons.chevron_up, chevronUp);
    reg(CupertinoIcons.chevron_down, chevronDown);
    reg(CupertinoIcons.keyboard_chevron_compact_down, keyboardDismiss);
    reg(CupertinoIcons.chevron_up_chevron_down, chevronUpDown);
    reg(CupertinoIcons.arrow_up, arrowUp);
    reg(CupertinoIcons.arrow_down, arrowDown);
    reg(CupertinoIcons.arrow_left, arrowLeft);
    reg(CupertinoIcons.arrow_right, arrowRight);
    reg(CupertinoIcons.arrow_up_left, arrowUpLeft);
    reg(CupertinoIcons.arrow_up_to_line, arrowUpToLine);
    reg(CupertinoIcons.arrow_up_circle, arrowUpCircle);
    reg(CupertinoIcons.arrow_uturn_down_circle, arrowUturnDownCircle);
    reg(CupertinoIcons.arrow_up_arrow_down, arrowUpArrowDown);
    reg(CupertinoIcons.arrow_up_arrow_down_square_fill, arrowUpArrowDown);
    reg(CupertinoIcons.arrow_right_arrow_left, arrowLeftRight);
    reg(CupertinoIcons.arrow_left_right, arrowLeftRight);
    reg(CupertinoIcons.return_icon, returnKey);
    reg(CupertinoIcons.xmark, xmark);
    reg(CupertinoIcons.xmark_circle, xmarkCircle);
    reg(CupertinoIcons.xmark_circle_fill, xmarkCircleFilled);
    reg(CupertinoIcons.checkmark, check);
    reg(CupertinoIcons.checkmark_alt, check);
    reg(CupertinoIcons.check_mark, check);
    reg(CupertinoIcons.checkmark_circle, checkCircle);
    reg(CupertinoIcons.check_mark_circled, checkCircle);
    reg(CupertinoIcons.checkmark_circle_fill, checkCircleFilled);
    reg(CupertinoIcons.check_mark_circled_solid, checkCircleFilled);
    reg(CupertinoIcons.add, plus);
    reg(CupertinoIcons.plus, plus);
    reg(CupertinoIcons.plus_circle, plusCircle);
    reg(CupertinoIcons.trash, trash);
    reg(CupertinoIcons.delete, trash);
    reg(CupertinoIcons.pencil, pencil);
    reg(CupertinoIcons.pencil_ellipsis_rectangle, penToSquare);
    reg(CupertinoIcons.folder, folder);
    reg(CupertinoIcons.archivebox, archivebox);
    reg(CupertinoIcons.tray, tray);
    reg(CupertinoIcons.doc_on_doc, docOnDoc);
    reg(CupertinoIcons.square_on_square, docOnDoc);
    reg(CupertinoIcons.doc_on_clipboard, clipboard);
    reg(CupertinoIcons.arrow_down_doc, fileArrowDown);
    reg(CupertinoIcons.share, share);
    reg(CupertinoIcons.square_arrow_right, signOut);
    reg(CupertinoIcons.refresh, refresh);
    reg(CupertinoIcons.arrow_2_circlepath, refresh);
    reg(CupertinoIcons.arrow_clockwise, rotateCw);
    reg(CupertinoIcons.ellipsis, ellipsis);
    reg(CupertinoIcons.ellipsis_circle, ellipsisCircle);
    reg(CupertinoIcons.bars, bars);
    reg(CupertinoIcons.line_horizontal_3, bars);
    reg(CupertinoIcons.line_horizontal_3_decrease, filterDecrease);
    reg(CupertinoIcons.sort_down, sortDown);
    reg(CupertinoIcons.photo, photo);
    reg(CupertinoIcons.photo_on_rectangle, images);
    reg(CupertinoIcons.rectangle, rectangle);
    reg(CupertinoIcons.play_fill, playFilled);
    reg(CupertinoIcons.pause_fill, pauseFilled);
    reg(CupertinoIcons.backward_end, backwardEnd);
    reg(CupertinoIcons.forward_end, forwardEnd);
    reg(CupertinoIcons.fullscreen, fullscreen);
    reg(CupertinoIcons.fullscreen_exit, fullscreenExit);
    reg(CupertinoIcons.tag, tag);
    reg(CupertinoIcons.tags, tags);
    reg(CupertinoIcons.star, starOutline);
    reg(CupertinoIcons.star_fill, starFilled);
    reg(CupertinoIcons.link, link);
    reg(CupertinoIcons.bell, bell);
    reg(CupertinoIcons.calendar, calendar);
    reg(CupertinoIcons.tickets, tickets);
    reg(CupertinoIcons.textformat, textFormat);
    reg(CupertinoIcons.circle, circleOutline);
    reg(CupertinoIcons.ant, ant);

    // ---- Register Material Icons ----
    reg(Icons.arrow_back, arrowLeft);
    reg(Icons.delete, trash);
    reg(Icons.error, exclamationCircle);
    reg(Icons.more_vert, ellipsisVert);
    reg(Icons.panorama, photo);
    reg(Icons.refresh, refresh);
    reg(Icons.share_outlined, share);

    // ---- Register FluentIcons (Windows titlebar buttons) ----
    reg(FluentIcons.line_horizontal_1_20_regular, winMinimize);
    reg(FluentIcons.maximize_16_regular, winMaximize);
    reg(FluentIcons.square_multiple_16_regular, winRestore);
    reg(FluentIcons.dismiss_16_regular, xmark);

    // ---- Register FontAwesomeIcons ----
    regFa(FontAwesomeIcons.solidHeart, heartFilled);
    regFa(FontAwesomeIcons.heart, heartOutline);
    regFa(FontAwesomeIcons.heartBroken, heartSlash);
    regFa(FontAwesomeIcons.fire, flame);
    regFa(FontAwesomeIcons.solidEye, eye);
    regFa(FontAwesomeIcons.eye, eye);
    regFa(FontAwesomeIcons.eyeSlash, eyeSlash);
    regFa(FontAwesomeIcons.layerGroup, layerGroup);
    regFa(FontAwesomeIcons.jira, grid2x2);
    regFa(FontAwesomeIcons.listOl, toplist);
    regFa(FontAwesomeIcons.history, clock);
    regFa(FontAwesomeIcons.solidClock, clock);
    regFa(FontAwesomeIcons.download, downloadLine);
    regFa(FontAwesomeIcons.solidCircleDown, downloadCircle);
    regFa(FontAwesomeIcons.fileArrowDown, fileArrowDown);
    regFa(FontAwesomeIcons.fileArrowUp, fileArrowUp);
    regFa(FontAwesomeIcons.fileExport, fileExport);
    regFa(FontAwesomeIcons.fileImport, fileImport);
    regFa(FontAwesomeIcons.solidFileLines, fileLines);
    regFa(FontAwesomeIcons.solidFileZipper, fileZip);
    regFa(FontAwesomeIcons.cog, settings);
    regFa(FontAwesomeIcons.magnifyingGlass, search);
    regFa(FontAwesomeIcons.language, language);
    regFa(FontAwesomeIcons.earthAmericas, globe);
    regFa(FontAwesomeIcons.play, playOutline);
    regFa(FontAwesomeIcons.pause, pauseOutline);
    regFa(FontAwesomeIcons.stop, stopOutline);
    regFa(FontAwesomeIcons.circleCheck, checkCircle);
    regFa(FontAwesomeIcons.solidCircleCheck, checkCircle);
    regFa(FontAwesomeIcons.check, check);
    regFa(FontAwesomeIcons.circleXmark, xmarkCircle);
    regFa(FontAwesomeIcons.circleDot, circleDot);
    regFa(FontAwesomeIcons.plusCircle, plusCircle);
    regFa(FontAwesomeIcons.solidImages, images);
    regFa(FontAwesomeIcons.images, images);
    regFa(FontAwesomeIcons.solidStar, starFilled);
    regFa(FontAwesomeIcons.star, starOutline);
    regFa(FontAwesomeIcons.solidTrashCan, trash);
    regFa(FontAwesomeIcons.trashCan, trash);
    regFa(FontAwesomeIcons.share, share);
    regFa(FontAwesomeIcons.squareShareNodes, share);
    regFa(FontAwesomeIcons.arrowRotateLeft, rotateCcw);
    regFa(FontAwesomeIcons.rotateRight, rotateCw);
    regFa(FontAwesomeIcons.redo, rotateCw);
    regFa(FontAwesomeIcons.redoAlt, rotateCw);
    regFa(FontAwesomeIcons.arrowsRotate, refresh);
    regFa(FontAwesomeIcons.chevronLeft, chevronLeft);
    regFa(FontAwesomeIcons.bars, bars);
    regFa(FontAwesomeIcons.arrowDownWideShort, sortDown);
    regFa(FontAwesomeIcons.ellipsis, ellipsis);
    regFa(FontAwesomeIcons.tag, tag);
    regFa(FontAwesomeIcons.tags, tags);
    regFa(FontAwesomeIcons.thumbsUp, thumbsUp);
    regFa(FontAwesomeIcons.solidThumbsUp, thumbsUp);
    regFa(FontAwesomeIcons.thumbsDown, thumbsDown);
    regFa(FontAwesomeIcons.solidThumbsDown, thumbsDown);
    regFa(FontAwesomeIcons.penToSquare, penToSquare);
    regFa(FontAwesomeIcons.penRuler, penRuler);
    regFa(FontAwesomeIcons.bookOpen, book);
    regFa(FontAwesomeIcons.solidCircleUser, userCircle);
    regFa(FontAwesomeIcons.lock, lock);
    regFa(FontAwesomeIcons.roadBarrier, roadBarrier);
    regFa(FontAwesomeIcons.rectangleAd, adRect);
    regFa(FontAwesomeIcons.fill, fillDrop);
    regFa(FontAwesomeIcons.magnet, magnet);
    regFa(FontAwesomeIcons.reply, reply);
    regFa(FontAwesomeIcons.at, atSign);
    regFa(FontAwesomeIcons.message, message);
    regFa(FontAwesomeIcons.solidFloppyDisk, floppy);
    regFa(FontAwesomeIcons.hourglassHalf, hourglass);
    regFa(FontAwesomeIcons.heading, heading);
    regFa(FontAwesomeIcons.database, database);
    regFa(FontAwesomeIcons.cloud, cloud);
    regFa(FontAwesomeIcons.clipboard, clipboard);
    regFa(FontAwesomeIcons.hippo, hippoLine);
    regFa(FontAwesomeIcons.cat, catLine);

    return map;
  }
}
