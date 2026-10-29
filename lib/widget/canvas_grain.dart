import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';

/// Fine grain on the page canvas, so glass at rest has texture to sample
/// instead of a flat grey: 3% in light, 2.5% in graphite, none on pure black.
///
/// It paints behind [child]; cards and covers drawn by the child stay clean.
class CanvasGrain extends StatelessWidget {
  const CanvasGrain({super.key, required this.child});

  final Widget child;

  /// Grain strength for a canvas; zero turns it off.
  static double opacityFor(Color canvas, {required bool dark}) {
    if (!dark) {
      return 0.03;
    }
    // Pure black stays black on OLED panels.
    return canvas.computeLuminance() < 0.001 ? 0 : 0.025;
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color canvas = CupertinoDynamicColor.maybeResolve(
            theme.scaffoldBackgroundColor, context) ??
        theme.scaffoldBackgroundColor;
    final double opacity = opacityFor(canvas, dark: dark);
    // Increased contrast asks for flat surfaces.
    if (opacity <= 0 || MediaQuery.highContrastOf(context)) {
      return child;
    }
    return CustomPaint(
      painter: _GrainPainter(
        tint: dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
        opacity: opacity,
        texel: 1 / MediaQuery.devicePixelRatioOf(context),
      ),
      // Scrolling content repaints on its own layer, not over the grain.
      child: RepaintBoundary(child: child),
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter({
    required this.tint,
    required this.opacity,
    required this.texel,
  }) : super(repaint: _GrainTexture.image);

  final Color tint;
  final double opacity;

  /// Logical size of one noise sample: one physical pixel.
  final double texel;

  @override
  void paint(Canvas canvas, Size size) {
    final image = _GrainTexture.image.value;
    if (image == null) {
      _GrainTexture.ensure();
      return;
    }
    final matrix = Matrix4.diagonal3Values(texel, texel, 1);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ImageShader(
          image,
          TileMode.repeated,
          TileMode.repeated,
          matrix.storage,
          filterQuality: FilterQuality.none,
        )
        // Tints the noise and scales its alpha to [opacity] in one pass.
        ..colorFilter = ColorFilter.matrix(<double>[
          0, 0, 0, 0, tint.r * 255, //
          0, 0, 0, 0, tint.g * 255, //
          0, 0, 0, 0, tint.b * 255, //
          0, 0, 0, opacity, 0, //
        ]),
    );
  }

  @override
  bool shouldRepaint(_GrainPainter oldDelegate) =>
      oldDelegate.tint != tint ||
      oldDelegate.opacity != opacity ||
      oldDelegate.texel != texel;
}

/// One shared tile of white noise, decoded once.
abstract final class _GrainTexture {
  static const int _size = 128;
  static final ValueNotifier<ui.Image?> image = ValueNotifier<ui.Image?>(null);
  static bool _started = false;

  static void ensure() {
    if (_started) {
      return;
    }
    _started = true;
    // A fixed seed keeps the texture identical between launches.
    final random = math.Random(0x5eed);
    final pixels = Uint8List(_size * _size * 4);
    for (int i = 0; i < pixels.length; i += 4) {
      pixels[i] = 0xFF;
      pixels[i + 1] = 0xFF;
      pixels[i + 2] = 0xFF;
      pixels[i + 3] = random.nextInt(256);
    }
    ui.decodeImageFromPixels(
      pixels,
      _size,
      _size,
      ui.PixelFormat.rgba8888,
      (decoded) => image.value = decoded,
    );
  }
}
