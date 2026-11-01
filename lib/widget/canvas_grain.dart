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
    final bool flat = opacity <= 0 || MediaQuery.highContrastOf(context);
    // The same widgets with or without grain: switching to pure black must
    // not rebuild what sits below, such as the tabs' navigators and lists.
    return CustomPaint(
      painter: flat
          ? null
          : _GrainPainter(
              onDark: dark,
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
    required this.onDark,
    required this.opacity,
    required this.texel,
  }) : super(repaint: _GrainTexture.of(onDark));

  /// Light grain on a dark canvas, dark grain on a light one.
  final bool onDark;
  final double opacity;

  /// Logical size of one noise sample: one physical pixel.
  final double texel;

  @override
  void paint(Canvas canvas, Size size) {
    final image = _GrainTexture.of(onDark).value;
    if (image == null) {
      _GrainTexture.ensure(onDark);
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
        // The paint's alpha fades the tile as it repeats. A colour filter
        // here made Impeller filter the tile into a copy that lost its edge
        // texels, which left a bare line along every seam.
        ..color = Color.fromRGBO(0, 0, 0, opacity),
    );
  }

  @override
  bool shouldRepaint(_GrainPainter oldDelegate) =>
      oldDelegate.onDark != onDark ||
      oldDelegate.opacity != opacity ||
      oldDelegate.texel != texel;
}

/// The shared noise tiles, one per tint, each built once.
abstract final class _GrainTexture {
  static const int _size = 128;
  static final Map<bool, ValueNotifier<ui.Image?>> _images = {
    true: ValueNotifier<ui.Image?>(null),
    false: ValueNotifier<ui.Image?>(null),
  };

  static ValueNotifier<ui.Image?> of(bool onDark) => _images[onDark]!;

  static final Set<bool> _started = {};

  static void ensure(bool onDark) {
    if (!_started.add(onDark)) {
      return;
    }
    // A fixed seed keeps the texture identical between launches.
    final random = math.Random(0x5eed);
    final pixels = Uint8List(_size * _size * 4);
    for (int i = 0; i < pixels.length; i += 4) {
      final alpha = random.nextInt(256);
      // Premultiplied: white noise carries its alpha in every channel.
      final value = onDark ? alpha : 0;
      pixels[i] = value;
      pixels[i + 1] = value;
      pixels[i + 2] = value;
      pixels[i + 3] = alpha;
    }
    ui.decodeImageFromPixels(
      pixels,
      _size,
      _size,
      ui.PixelFormat.rgba8888,
      (decoded) => of(onDark).value = decoded,
    );
  }
}
