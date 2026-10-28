import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';

import '../utils/liquid_glass.dart';

enum SoftEdge { top, bottom }

/// App surfaces fade into the page colour; media (the reader) dims toward
/// black like the system photo viewer.
enum SoftEdgeTone { surface, media }

/// Opacity of a soft edge at five control points, from the screen edge
/// inwards: the edge, the middle of the bars, their inner edge, half the tail
/// and the end of the tail.
@immutable
class SoftEdgeCurve {
  const SoftEdgeCurve(this.alphas, {required this.maxSigma});

  final List<double> alphas;

  /// Blur at the screen edge in logical pixels; zero disables the blur.
  final double maxSigma;

  static const SoftEdgeCurve light =
      SoftEdgeCurve(<double>[0.80, 0.55, 0.38, 0.12, 0], maxSigma: 12);
  static const SoftEdgeCurve dark =
      SoftEdgeCurve(<double>[0.86, 0.61, 0.44, 0.15, 0], maxSigma: 12);
  static const SoftEdgeCurve reducedTransparency =
      SoftEdgeCurve(<double>[0.97, 0.94, 0.88, 0.35, 0], maxSigma: 0);
  // Media keeps more of the page readable: dimming carries legibility and
  // the blur stays light so bright pages do not turn foggy.
  static const SoftEdgeCurve media =
      SoftEdgeCurve(<double>[0.50, 0.30, 0.15, 0.05, 0], maxSigma: 6);

  static List<double> positions({
    required double inset,
    required double bars,
    required double tail,
  }) =>
      <double>[
        0,
        inset + bars / 2,
        inset + bars,
        inset + bars + tail / 2,
        inset + bars + tail,
      ];

  /// Samples a monotone cubic through the control points at [count] evenly
  /// spaced stops, so the fade never plateaus and then drops off a cliff.
  List<double> sample({
    required double inset,
    required double bars,
    required double tail,
    int count = 16,
  }) {
    final xs = <double>[];
    final ys = <double>[];
    final raw = positions(inset: inset, bars: bars, tail: tail);
    for (var i = 0; i < raw.length; i++) {
      // A collapsed rail or a missing inset folds control points together.
      if (xs.isEmpty || raw[i] > xs.last + 1e-6) {
        xs.add(raw[i]);
        ys.add(alphas[i]);
      }
    }
    final extent = raw.last;
    if (xs.length < 2 || extent <= 0) {
      return List<double>.filled(count, 0);
    }
    final slopes = _monotoneSlopes(xs, ys);
    return List<double>.generate(count, (index) {
      final x = extent * index / (count - 1);
      return _evaluate(xs, ys, slopes, x).clamp(0.0, 1.0);
    });
  }

  // Fritsch–Carlson tangents keep the interpolation monotone between points.
  static List<double> _monotoneSlopes(List<double> xs, List<double> ys) {
    final n = xs.length;
    final secants = List<double>.generate(
        n - 1, (i) => (ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]));
    final slopes = List<double>.filled(n, 0);
    slopes[0] = secants.first;
    slopes[n - 1] = secants.last;
    for (var i = 1; i < n - 1; i++) {
      slopes[i] = secants[i - 1] * secants[i] <= 0
          ? 0
          : (secants[i - 1] + secants[i]) / 2;
    }
    for (var i = 0; i < n - 1; i++) {
      if (secants[i] == 0) {
        slopes[i] = 0;
        slopes[i + 1] = 0;
        continue;
      }
      final a = slopes[i] / secants[i];
      final b = slopes[i + 1] / secants[i];
      final h = a * a + b * b;
      if (h > 9) {
        final tau = 3 / math.sqrt(h);
        slopes[i] = tau * a * secants[i];
        slopes[i + 1] = tau * b * secants[i];
      }
    }
    return slopes;
  }

  static double _evaluate(
      List<double> xs, List<double> ys, List<double> slopes, double x) {
    if (x <= xs.first) return ys.first;
    if (x >= xs.last) return ys.last;
    var i = 0;
    while (x > xs[i + 1]) {
      i++;
    }
    final h = xs[i + 1] - xs[i];
    final t = (x - xs[i]) / h;
    final t2 = t * t;
    final t3 = t2 * t;
    return (2 * t3 - 3 * t2 + 1) * ys[i] +
        (t3 - 2 * t2 + t) * h * slopes[i] +
        (-2 * t3 + 3 * t2) * ys[i + 1] +
        (t3 - t2) * h * slopes[i + 1];
  }
}

/// A Flutter counterpart of UIKit's soft scroll edge effect for bars Flutter
/// cannot hand to a native scroll view: content sliding under the bars blurs
/// progressively and fades into the background without a visible boundary.
///
/// The effect is [extentOf] tall; position it against [edge] of the screen.
class SoftScrollEdgeEffect extends StatefulWidget {
  const SoftScrollEdgeEffect({
    super.key,
    required this.edge,
    required this.inset,
    required this.bars,
    this.tail = defaultTail,
    this.tone = SoftEdgeTone.surface,
  });

  static const double defaultTail = 36;

  final SoftEdge edge;

  /// System inset at the edge (status bar, home indicator); blur is full here.
  final double inset;

  /// Height of the controls between the inset and the content.
  final double bars;

  /// Fade beyond the bars.
  final double tail;
  final SoftEdgeTone tone;

  static double extentOf({
    required double inset,
    required double bars,
    double tail = defaultTail,
  }) =>
      math.max(0, inset + bars + tail);

  @override
  State<SoftScrollEdgeEffect> createState() => _SoftScrollEdgeEffectState();
}

class _SoftScrollEdgeEffectState extends State<SoftScrollEdgeEffect> {
  ui.FragmentShader? _horizontal;
  ui.FragmentShader? _vertical;
  ui.ImageFilter? _filter;
  Object? _filterKey;

  @override
  void initState() {
    super.initState();
    _SoftEdgeBlurProgram.ensureLoaded();
    _SoftEdgeBlurProgram.ready.addListener(_rebuild);
    LiquidGlassAccessibilitySettings.reduceTransparency.addListener(_rebuild);
  }

  @override
  void dispose() {
    _SoftEdgeBlurProgram.ready.removeListener(_rebuild);
    LiquidGlassAccessibilitySettings.reduceTransparency
        .removeListener(_rebuild);
    _disposeShaders();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _disposeShaders() {
    _horizontal?.dispose();
    _vertical?.dispose();
    _horizontal = null;
    _vertical = null;
    _filter = null;
    _filterKey = null;
  }

  SoftEdgeCurve _curve(BuildContext context) {
    if (widget.tone == SoftEdgeTone.media) return SoftEdgeCurve.media;
    if (LiquidGlassAccessibilitySettings.reduceTransparency.value ?? false) {
      return SoftEdgeCurve.reducedTransparency;
    }
    return CupertinoTheme.brightnessOf(context) == Brightness.dark
        ? SoftEdgeCurve.dark
        : SoftEdgeCurve.light;
  }

  ui.ImageFilter? _shaderFilter(double maxSigma, double extent, double dpr) {
    final program = _SoftEdgeBlurProgram.program;
    if (program == null) return null;
    final key = Object.hash(
        maxSigma, widget.inset, extent, dpr, widget.edge, widget.tone);
    if (key == _filterKey && _filter != null) return _filter;
    _disposeShaders();
    ui.FragmentShader pass(double dx, double dy) => program.fragmentShader()
      // Floats 0-1 are u_size, which the engine fills in.
      ..setFloat(2, dx)
      ..setFloat(3, dy)
      ..setFloat(4, maxSigma * dpr)
      ..setFloat(5, widget.inset * dpr)
      ..setFloat(6, extent * dpr)
      ..setFloat(7, widget.edge == SoftEdge.bottom ? 1 : 0);
    _horizontal = pass(1, 0);
    _vertical = pass(0, 1);
    _filterKey = key;
    return _filter = ui.ImageFilter.compose(
      outer: ui.ImageFilter.shader(_vertical!),
      inner: ui.ImageFilter.shader(_horizontal!),
    );
  }

  // Without shader filters (Skia, tests) nested bands approximate the ramp;
  // each band blurs what the wider band below it already softened.
  Widget _bandedBlur(double maxSigma, double extent) {
    const fractions = <double>[0.85, 0.6, 0.35];
    const sigmas = <double>[0.25, 0.45, 0.75];
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        for (var i = 0; i < fractions.length; i++)
          Align(
            alignment: widget.edge == SoftEdge.top
                ? Alignment.topCenter
                : Alignment.bottomCenter,
            child: SizedBox(
              height: extent * fractions[i],
              child: ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: maxSigma * sigmas[i],
                    sigmaY: maxSigma * sigmas[i],
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final extent = SoftScrollEdgeEffect.extentOf(
        inset: widget.inset, bars: widget.bars, tail: widget.tail);
    if (extent <= 0) return const SizedBox.shrink();
    final curve = _curve(context);
    final alphas =
        curve.sample(inset: widget.inset, bars: widget.bars, tail: widget.tail);
    final base = widget.tone == SoftEdgeTone.media
        ? CupertinoColors.black
        : CupertinoDynamicColor.resolve(
            CupertinoTheme.of(context).scaffoldBackgroundColor, context);
    final top = widget.edge == SoftEdge.top;
    Widget? blur;
    if (curve.maxSigma > 0) {
      final filter = _shaderFilter(
          curve.maxSigma, extent, MediaQuery.devicePixelRatioOf(context));
      blur = filter == null
          ? _bandedBlur(curve.maxSigma, extent)
          : ClipRect(
              child: BackdropFilter(
                  filter: filter, child: const SizedBox.expand()));
    } else if (_filter != null) {
      _disposeShaders();
    }
    return IgnorePointer(
      child: SizedBox(
        height: extent,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (blur != null) blur,
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: top ? Alignment.topCenter : Alignment.bottomCenter,
                  end: top ? Alignment.bottomCenter : Alignment.topCenter,
                  colors: <Color>[
                    for (final alpha in alphas) base.withValues(alpha: alpha),
                  ],
                  stops: <double>[
                    for (var i = 0; i < alphas.length; i++)
                      i / (alphas.length - 1),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftEdgeBlurProgram {
  _SoftEdgeBlurProgram._();

  static ui.FragmentProgram? program;
  static final ValueNotifier<bool> ready = ValueNotifier<bool>(false);
  static bool _requested = false;

  static void ensureLoaded() {
    if (_requested || !ui.ImageFilter.isShaderFilterSupported) return;
    _requested = true;
    ui.FragmentProgram.fromAsset('shaders/soft_edge_blur.frag').then(
      (loaded) {
        program = loaded;
        ready.value = true;
      },
      onError: (Object error) {
        // The banded fallback keeps the edge soft without the shader.
        debugPrint('soft edge blur shader unavailable: $error');
      },
    );
  }
}
