import 'package:eros_fe/common/service/theme_service.dart';
import 'package:flutter/cupertino.dart';

/// Semantic health tone for soft optical status indicators.
enum SoftStatusTone {
  ok,
  warn,
  err,
  idle,
}

/// Low-saturation, refined semantic color tokens tuned for both Light and
/// Dark Graphite / OLED canvases.
class SoftStatusPalette {
  const SoftStatusPalette._();

  static Color coreColor(BuildContext context, SoftStatusTone tone) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return switch (tone) {
      SoftStatusTone.ok =>
        dark ? const Color(0xFF6DC098) : const Color(0xFF52A67C),
      SoftStatusTone.warn =>
        dark ? const Color(0xFFD1A96A) : const Color(0xFFC4924A),
      SoftStatusTone.err =>
        dark ? const Color(0xFFD47E7A) : const Color(0xFFC96A66),
      SoftStatusTone.idle =>
        dark ? const Color(0xFF686E78) : const Color(0xFF9CA3AE),
    };
  }

  static Color textColor(BuildContext context, SoftStatusTone tone) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return switch (tone) {
      SoftStatusTone.ok =>
        dark ? const Color(0xFF7CC6A1) : const Color(0xFF438564),
      SoftStatusTone.warn =>
        dark ? const Color(0xFFD1A96A) : const Color(0xFF9E7334),
      SoftStatusTone.err =>
        dark ? const Color(0xFFD47E7A) : const Color(0xFFA95350),
      SoftStatusTone.idle => ehTheme.palette.text3.resolveFrom(context),
    };
  }

  static double haloAlpha(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return dark ? 0.50 : 0.44;
  }
}

/// Optical indicator LED with a soft, feathered edge and gentle diffused halo.
///
/// Always occupies a fixed [size] square (default 12pt) so indicator dots across
/// multiple list sections align along one vertical axis.
class SoftStatusLed extends StatelessWidget {
  const SoftStatusLed({
    super.key,
    required this.tone,
    this.testing = false,
    this.size = 12.0,
  });

  final SoftStatusTone tone;
  final bool testing;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (testing) {
      return SizedBox.square(
        dimension: size,
        child: const Center(
          child: CupertinoActivityIndicator(radius: 5.5),
        ),
      );
    }

    final core = SoftStatusPalette.coreColor(context, tone);
    final haloAlpha =
        tone == SoftStatusTone.idle ? 0.0 : SoftStatusPalette.haloAlpha(context);

    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _SoftStatusLedPainter(
          coreColor: core,
          haloAlpha: haloAlpha,
          isIdle: tone == SoftStatusTone.idle,
        ),
      ),
    );
  }
}

class _SoftStatusLedPainter extends CustomPainter {
  const _SoftStatusLedPainter({
    required this.coreColor,
    required this.haloAlpha,
    required this.isIdle,
  });

  final Color coreColor;
  final double haloAlpha;
  final bool isIdle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    if (!isIdle && haloAlpha > 0) {
      final haloPaint = Paint()
        ..color = coreColor.withValues(alpha: haloAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      canvas.drawCircle(center, size.shortestSide * 0.31, haloPaint);
    }

    final coreRadius = size.shortestSide * (isIdle ? 0.25 : 0.34);
    final highlight = Color.lerp(coreColor, const Color(0xFFFFFFFF), 0.30)!;
    final coreRect = Rect.fromCircle(center: center, radius: coreRadius);
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: isIdle
            ? <Color>[
                coreColor.withValues(alpha: 0.72),
                coreColor.withValues(alpha: 0.36),
                coreColor.withValues(alpha: 0.0),
              ]
            : <Color>[
                highlight.withValues(alpha: 0.98),
                coreColor.withValues(alpha: 0.95),
                coreColor.withValues(alpha: 0.44),
                coreColor.withValues(alpha: 0.0),
              ],
        stops: isIdle
            ? const <double>[0.0, 0.65, 1.0]
            : const <double>[0.0, 0.46, 0.78, 1.0],
      ).createShader(coreRect);

    canvas.drawCircle(center, coreRadius, corePaint);
  }

  @override
  bool shouldRepaint(covariant _SoftStatusLedPainter oldDelegate) {
    return oldDelegate.coreColor != coreColor ||
        oldDelegate.haloAlpha != haloAlpha ||
        oldDelegate.isIdle != isIdle;
  }
}

/// Fixed-width right-side metric rail keeping every [SoftStatusLed] vertically
/// aligned on a single pixel axis across DoH and diagnostic sections.
///
/// Layout: `[12pt LED] + [7pt gap] + [58pt right-aligned tabular text] + [8pt gap] + [15pt trailing slot]`
class AlignedStatusMetric extends StatelessWidget {
  const AlignedStatusMetric({
    super.key,
    required this.tone,
    required this.label,
    this.testing = false,
    this.trailingSlot,
  });

  static const double kLedSize = 12.0;
  static const double kLedToTextGap = 7.0;
  static const double kReadoutWidth = 58.0;
  static const double kTextToSlotGap = 8.0;
  static const double kTrailingSlotWidth = 15.0;

  final SoftStatusTone tone;
  final String label;
  final bool testing;

  /// Optional 15pt-wide trailing widget (e.g. selection checkmark or chevron).
  /// Pass null to keep the 15pt placeholder slot empty so LEDs stay aligned.
  final Widget? trailingSlot;

  @override
  Widget build(BuildContext context) {
    final labelColor = testing
        ? ehTheme.palette.text3.resolveFrom(context)
        : SoftStatusPalette.textColor(context, tone);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SoftStatusLed(
          tone: tone,
          testing: testing,
          size: kLedSize,
        ),
        const SizedBox(width: kLedToTextGap),
        SizedBox(
          width: kReadoutWidth,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.w500,
              color: labelColor,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: kTextToSlotGap),
        SizedBox(
          width: kTrailingSlotWidth,
          child: Center(
            child: trailingSlot ?? const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
