import 'dart:math' as math;

import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/tab/view/list/card_size.dart';
import 'package:flutter/cupertino.dart';

/// The device a preview draws, told apart by the shape of the screen, which
/// is all the system says about it.
enum PreviewDevice { iphone, iphoneHomeButton, duoOuter, duoInner, ipad }

/// Picks the device for a screen size in points, in either orientation.
PreviewDevice previewDeviceFor(Size screen) {
  final short = screen.shortestSide;
  final ratio = screen.longestSide / math.max(1.0, short);
  if (short < 600 && ratio < 1.6) {
    return PreviewDevice.duoOuter;
  }
  if (short >= 600 && short < 720 && ratio < 1.55) {
    return PreviewDevice.duoInner;
  }
  if (short >= 600) {
    return PreviewDevice.ipad;
  }
  return ratio >= 2 ? PreviewDevice.iphone : PreviewDevice.iphoneHomeButton;
}

/// The five steps as a slider with tick marks and their names underneath,
/// each name also choosing its step.
class CardSizeSlider extends StatelessWidget {
  const CardSizeSlider(
      {super.key, required this.step, required this.onChanged});

  final int step;
  final ValueChanged<int> onChanged;

  static List<String> labels(L10n l10n) => [
        l10n.card_size_small,
        l10n.card_size_smaller,
        l10n.card_size_standard,
        l10n.card_size_larger,
        l10n.card_size_large,
      ];

  void _pickAt(double dx, double width) {
    final slot = width / CardSize.steps;
    onChanged((dx / slot).floor().clamp(0, CardSize.steps - 1));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final names = labels(l10n);
    final secondary =
        CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    final label = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 11),
            child: CustomPaint(
                size: const Size.square(22),
                painter: _SizeGlyph(large: false, color: secondary)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Column(
                children: [
                  Semantics(
                    container: true,
                    slider: true,
                    label: l10n.card_size,
                    value: names[step],
                    increasedValue:
                        step < CardSize.steps - 1 ? names[step + 1] : null,
                    decreasedValue: step > 0 ? names[step - 1] : null,
                    onIncrease: step < CardSize.steps - 1
                        ? () => onChanged(step + 1)
                        : null,
                    onDecrease: step > 0 ? () => onChanged(step - 1) : null,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) =>
                          _pickAt(details.localPosition.dx, width),
                      onHorizontalDragStart: (details) =>
                          _pickAt(details.localPosition.dx, width),
                      onHorizontalDragUpdate: (details) =>
                          _pickAt(details.localPosition.dx, width),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: step.toDouble()),
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        builder: (context, position, _) => CustomPaint(
                          size: Size(width, 44),
                          painter: _TrackPainter(
                            position: position,
                            step: step,
                            accent: CupertinoTheme.of(context).primaryColor,
                            track: CupertinoDynamicColor.resolve(
                                _trackColor, context),
                            tick: CupertinoDynamicColor.resolve(
                                _tickColor, context),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < CardSize.steps; i++)
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: i == step,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onChanged(i),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  names[i],
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: i == step
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: i == step ? label : secondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            }),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(top: 11),
            child: CustomPaint(
                size: const Size.square(22),
                painter: _SizeGlyph(large: true, color: secondary)),
          ),
        ],
      ),
    );
  }
}

const _trackColor = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFE3E3E8), darkColor: Color(0xFF3A3A3C));
const _tickColor = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFC7C7CC), darkColor: Color(0xFF545458));

class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.position,
    required this.step,
    required this.accent,
    required this.track,
    required this.tick,
  });

  /// Where the thumb is, in steps, while it slides to [step].
  final double position;
  final int step;
  final Color accent;
  final Color track;
  final Color tick;

  @override
  void paint(Canvas canvas, Size size) {
    final slot = size.width / CardSize.steps;
    double x(double at) => slot * (at + 0.5);
    const top = 20.0;
    final line = Rect.fromLTRB(x(0), top, x(CardSize.steps - 1.0), top + 4);
    canvas.drawRRect(RRect.fromRectAndRadius(line, const Radius.circular(2)),
        Paint()..color = track);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(x(0), top, x(position), top + 4),
            const Radius.circular(2)),
        Paint()..color = accent);
    for (var i = 0; i < CardSize.steps; i++) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(x(i.toDouble()), 22), width: 4, height: 12),
              const Radius.circular(2)),
          Paint()..color = i <= step ? accent : tick);
    }
    final thumb = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x(position), 22), width: 40, height: 26),
        const Radius.circular(13));
    canvas.drawRRect(
        thumb.shift(const Offset(0, 3)),
        Paint()
          ..color = const Color(0x29000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawRRect(thumb, Paint()..color = const Color(0xFFFFFFFF));
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.position != position ||
      old.step != step ||
      old.accent != accent ||
      old.track != track ||
      old.tick != tick;
}

/// Six small cards at the small end, two tall ones at the large end.
class _SizeGlyph extends CustomPainter {
  _SizeGlyph({required this.large, required this.color});

  final bool large;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final cards = large
        ? const [
            Rect.fromLTWH(2.5, 2.5, 7.5, 17),
            Rect.fromLTWH(12, 2.5, 7.5, 17)
          ]
        : [
            for (final y in const [3.0, 12.5])
              for (final x in const [2.5, 8.75, 15.0])
                Rect.fromLTWH(x, y, 4.5, 6.5),
          ];
    for (final card in cards) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(card, Radius.circular(large ? 2 : 1.2)),
          paint);
    }
  }

  @override
  bool shouldRepaint(_SizeGlyph old) =>
      old.large != large || old.color != color;
}

/// Under the slider: this device in portrait and landscape, each with the
/// columns the chosen step gives there. On iPhone Duo a control switches
/// between its outer and inner displays.
class CardSizePreview extends StatefulWidget {
  const CardSizePreview({
    super.key,
    required this.mode,
    required this.step,
    this.divider = 0,
    this.immersive = false,
    this.screen,
  });

  final ListModeEnum mode;
  final int step;

  /// Where the split divider sits, from 0 to 1.
  final double divider;
  final bool immersive;

  /// The screen to draw, in points; the display the app is on when null.
  final Size? screen;

  @override
  State<CardSizePreview> createState() => _CardSizePreviewState();
}

class _CardSizePreviewState extends State<CardSizePreview> {
  bool? _inner;

  Size _screen(BuildContext context) {
    if (widget.screen != null) {
      return widget.screen!;
    }
    final view = View.maybeOf(context);
    if (view == null) {
      return MediaQuery.sizeOf(context);
    }
    // An iPad window can be any size, so take its display. iPhone Duo
    // reports the outer display even while open, so take the window there,
    // which fills whichever display is in use.
    final display = view.display;
    final screen = display.size / display.devicePixelRatio;
    if (screen.shortestSide >= 720) {
      return screen;
    }
    return view.physicalSize / view.devicePixelRatio;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final screen = _screen(context);
    final current = previewDeviceFor(screen);
    final duo =
        current == PreviewDevice.duoOuter || current == PreviewDevice.duoInner;
    final inner = _inner ?? current == PreviewDevice.duoInner;
    final device = _Device.of(
        duo
            ? (inner ? PreviewDevice.duoInner : PreviewDevice.duoOuter)
            : current,
        screen);
    final colors = CupertinoTheme.brightnessOf(context) == Brightness.dark
        ? _Colors.dark
        : _Colors.light;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (duo) ...[
          CupertinoSlidingSegmentedControl<bool>(
            groupValue: inner,
            children: {
              false: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(l10n.outer_display),
              ),
              true: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(l10n.inner_display),
              ),
            },
            onValueChanged: (value) => setState(() => _inner = value),
          ),
          const SizedBox(height: 16),
        ],
        LayoutBuilder(builder: (context, constraints) {
          const gap = 28.0;
          final body = device.hardware.bodySize;
          final room = constraints.maxWidth - gap - 16;
          final tallest = constraints.maxWidth >= 600 ? 230.0 : 190.0;
          final scale = math.min(
              tallest / body.height, room / (body.width + body.height));
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final portrait in const [true, false]) ...[
                if (!portrait) const SizedBox(width: gap),
                _Mini(
                  device: device,
                  portrait: portrait,
                  scale: scale,
                  mode: widget.mode,
                  step: widget.step,
                  divider: widget.divider,
                  immersive: widget.immersive,
                  colors: colors,
                ),
              ],
            ],
          );
        }),
      ],
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({
    required this.device,
    required this.portrait,
    required this.scale,
    required this.mode,
    required this.step,
    required this.divider,
    required this.immersive,
    required this.colors,
  });

  final _Device device;
  final bool portrait;
  final double scale;
  final ListModeEnum mode;
  final int step;
  final double divider;
  final bool immersive;
  final _Colors colors;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final pose = portrait ? device.portrait : device.landscape;
    final frame = device.hardware.frame(portrait, scale, colors);
    final screen = _screenContent(pose, portrait,
        mode: mode,
        step: step,
        divider: divider,
        immersive: immersive,
        colors: colors);
    final count = screen.fewest == screen.most
        ? l10n.column_count(screen.columns)
        : l10n.column_range(screen.fewest, screen.most);
    final caption = [
      if (portrait) l10n.portrait else l10n.landscape,
      if (screen.split) l10n.split_follows_divider,
    ].join(' · ');
    return Semantics(
      label: '$caption，$count',
      image: true,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: frame.bounds.size * scale,
            painter: _MiniPainter(
                frame: frame,
                shapes: screen.shapes,
                scale: scale,
                screenColor: colors.screen),
          ),
          const SizedBox(height: 10),
          Text(
            count,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
              color:
                  CupertinoDynamicColor.resolve(CupertinoColors.label, context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: TextStyle(
              fontSize: 12,
              color: CupertinoDynamicColor.resolve(
                  CupertinoColors.secondaryLabel, context),
            ),
          ),
        ],
      ),
    );
  }
}

class _Colors {
  const _Colors({
    required this.body,
    required this.screen,
    required this.card,
    required this.chip,
    required this.chipOn,
    required this.detail,
    required this.placeholder,
    required this.divider,
    required this.chrome,
    required this.dot,
    required this.mark,
    required this.fold,
    required this.spine,
    required this.nub,
    required this.tick,
  });

  final Color body;
  final Color screen;
  final Color card;
  final Color chip;
  final Color chipOn;
  final Color detail;
  final Color placeholder;
  final Color divider;
  final Color chrome;
  final Color dot;
  final Color mark;
  final Color fold;
  final Color spine;
  final Color nub;
  final Color tick;

  static const light = _Colors(
    body: Color(0xFFC7C7CC),
    screen: Color(0xFFE5E5EA),
    card: Color(0xFFA1A1A7),
    chip: Color(0xFFD1D1D6),
    chipOn: Color(0xFF8E8E93),
    detail: Color(0xFFF2F2F7),
    placeholder: Color(0xFFD1D1D6),
    divider: Color(0xFFC7C7CC),
    chrome: Color(0xF0FFFFFF),
    dot: Color(0xFFAEAEB2),
    mark: Color(0xFF3A3A3C),
    fold: Color(0x0F000000),
    spine: Color(0xFFA5A5AB),
    nub: Color(0xFFB4B4B9),
    tick: Color(0xFF8E8E93),
  );

  static const dark = _Colors(
    body: Color(0xFF48484A),
    screen: Color(0xFF2C2C2E),
    card: Color(0xFF6E6E73),
    chip: Color(0xFF48484A),
    chipOn: Color(0xFF8E8E93),
    detail: Color(0xFF232325),
    placeholder: Color(0xFF48484A),
    divider: Color(0xFF3A3A3C),
    chrome: Color(0xEB48484A),
    dot: Color(0xFF8E8E93),
    mark: Color(0xFF000000),
    fold: Color(0x12FFFFFF),
    spine: Color(0xFF5E5E62),
    nub: Color(0xFF3A3A3C),
    tick: Color(0xFF98989D),
  );
}

/// A rounded rect with its own corners, top-left first, clockwise.
class _Part {
  const _Part(this.rect, this.radii, this.color);

  _Part.round(this.rect, double radius, this.color)
      : radii = [radius, radius, radius, radius];

  final Rect rect;
  final List<double> radii;
  final Color color;

  RRect rrect(Offset origin, double scale) {
    final r = rect.shift(-origin);
    Radius corner(double v) => Radius.circular(v * scale);
    return RRect.fromRectAndCorners(
      Rect.fromLTWH(
          r.left * scale, r.top * scale, r.width * scale, r.height * scale),
      topLeft: corner(radii[0]),
      topRight: corner(radii[1]),
      bottomRight: corner(radii[2]),
      bottomLeft: corner(radii[3]),
    );
  }
}

enum _Edge { top, right, bottom, left }

class _Frame {
  const _Frame(this.behind, this.screen, this.over, this.bounds);

  /// Buttons, the body and marks on it, drawn under the screen.
  final List<_Part> behind;
  final _Part screen;

  /// Marks over the screen's content: camera, island, crease.
  final List<_Part> over;
  final Rect bounds;
}

/// The hardware in portrait, in screen points with the screen's corner at the
/// origin. Bezels and radii run top, right, bottom, left.
class _Hardware {
  const _Hardware({
    required this.screen,
    required this.clockwise,
    required this.screenRadii,
    required this.bezel,
    this.bodyRadii,
    this.spine = 0,
    this.nubs = const [],
    this.camera,
    this.island = false,
    this.fold,
    this.bezelCamera = false,
    this.homeButton = false,
  });

  final Size screen;

  /// Which way the device turns from portrait to its landscape pose.
  final bool clockwise;
  final List<double> screenRadii;
  final List<double> bezel;
  final List<double>? bodyRadii;
  final double spine;
  final List<(_Edge, double, double)> nubs;

  /// A front camera on the screen: its centre and diameter.
  final (Offset, double)? camera;
  final bool island;
  final double? fold;
  final bool bezelCamera;
  final bool homeButton;

  Size get bodySize => Size(
      screen.width + bezel[1] + bezel[3], screen.height + bezel[0] + bezel[2]);

  _Part _turn(_Part part) {
    final r = part.rect;
    final c = part.radii;
    return clockwise
        ? _Part(
            Rect.fromLTWH(
                screen.height - r.top - r.height, r.left, r.height, r.width),
            [c[3], c[0], c[1], c[2]],
            part.color)
        : _Part(
            Rect.fromLTWH(
                r.top, screen.width - r.left - r.width, r.height, r.width),
            [c[1], c[2], c[3], c[0]],
            part.color);
  }

  _Frame frame(bool portrait, double scale, _Colors colors) {
    final [top, right, bottom, left] = bezel;
    final w = screen.width;
    final h = screen.height;
    final behind = <_Part>[];
    final over = <_Part>[];
    // Buttons stand proud of the frame, at least a pixel and a half.
    final nub = math.max(3.0, 1.6 / scale);
    for (final (edge, from, to) in nubs) {
      final rect = switch (edge) {
        _Edge.top => Rect.fromLTWH(from, -top - nub, to - from, nub + 2),
        _Edge.bottom => Rect.fromLTWH(from, h + bottom - 2, to - from, nub + 2),
        _Edge.left => Rect.fromLTWH(-left - nub, from, nub + 2, to - from),
        _Edge.right => Rect.fromLTWH(w + right - 2, from, nub + 2, to - from),
      };
      behind.add(_Part.round(rect, 1 / scale, colors.nub));
    }
    final radii = bodyRadii ??
        [
          for (var i = 0; i < 4; i++)
            screenRadii[i] + math.min(bezel[i], bezel[(i + 3) % 4]),
        ];
    behind.add(_Part(
        Rect.fromLTRB(-left, -top, w + right, h + bottom), radii, colors.body));
    if (spine > 0) {
      behind.add(_Part(Rect.fromLTWH(-left, -top, spine, h + top + bottom),
          [radii[0], 0, 0, radii[3]], colors.spine));
    }
    if (fold case final fold?) {
      final line = 1.2 / scale;
      behind
        ..add(_Part.round(
            Rect.fromLTWH(-left, fold - line / 2, left, line), 0, colors.tick))
        ..add(_Part.round(
            Rect.fromLTWH(w, fold - line / 2, right, line), 0, colors.tick));
      over.add(_Part.round(
          Rect.fromLTWH(0, fold - line / 2, w, line), 0, colors.fold));
    }
    if (bezelCamera) {
      final d = math.max(8.0, 3 / scale);
      behind.add(_Part.round(
          Rect.fromCircle(center: Offset(-left / 2, h / 2), radius: d / 2),
          d / 2,
          colors.mark));
    }
    if (homeButton) {
      behind
        ..add(_Part.round(
            Rect.fromCircle(center: Offset(w / 2, h + bottom / 2), radius: 33),
            33,
            colors.nub))
        ..add(_Part.round(
            Rect.fromCenter(
                center: Offset(w / 2, -top / 2), width: 48, height: 6),
            3,
            colors.nub));
    }
    if (camera case (final centre, final size)?) {
      final d = math.max(size, 4 / scale);
      over.add(_Part.round(
          Rect.fromCircle(center: centre, radius: d / 2), d / 2, colors.mark));
    }
    if (island) {
      over.add(_Part.round(
          Rect.fromLTWH(w / 2 - 63, 11, 126, 37), 18.5, colors.mark));
    }
    var display = _Part(Offset.zero & screen, screenRadii, colors.screen);
    var under = behind;
    var marks = over;
    if (!portrait) {
      display = _turn(display);
      under = behind.map(_turn).toList();
      marks = over.map(_turn).toList();
    }
    final bounds = under.fold(
        display.rect, (Rect bounds, part) => bounds.expandToInclude(part.rect));
    return _Frame(under, display, marks, bounds);
  }
}

enum _Bar { bottom, side, top }

/// A pose's screen: its size and where the app's bars and content sit.
class _Pose {
  const _Pose(
    this.size, {
    this.left = 0,
    this.right = 0,
    required this.top,
    required this.bar,
    this.camera = false,
    this.cameraAtBottom = false,
  });

  final Size size;
  final double left;
  final double right;

  /// Where the cards start.
  final double top;
  final _Bar bar;

  /// A camera sits at one end of the side column.
  final bool camera;
  final bool cameraAtBottom;
}

class _Device {
  const _Device(this.hardware, this.portrait, this.landscape);

  factory _Device.of(PreviewDevice kind, Size screen) {
    final w = screen.shortestSide;
    final h = screen.longestSide;
    switch (kind) {
      // The Duo comes from the simulator's own artwork: closed, the hinge
      // spine runs down the leading edge, whose corners are nearly square,
      // and the camera sits in the free top corner, centred on the 84 pt
      // side column in both orientations. Open, it has one even bezel and
      // its camera is under the display.
      case PreviewDevice.duoOuter:
        return const _Device(
          _Hardware(
            screen: Size(466, 678),
            clockwise: true,
            screenRadii: [8, 59, 59, 8],
            bezel: [12, 12, 12, 22],
            bodyRadii: [8, 71, 71, 8],
            spine: 10,
            nubs: [
              (_Edge.top, 210, 276),
              (_Edge.top, 290, 356),
              (_Edge.right, 188, 301),
            ],
            camera: (Offset(424, 42), 16),
          ),
          _Pose(Size(466, 678),
              right: 84, top: 56, bar: _Bar.side, camera: true),
          _Pose(Size(678, 466),
              right: 84,
              top: 56,
              bar: _Bar.side,
              camera: true,
              cameraAtBottom: true),
        );
      case PreviewDevice.duoInner:
        return const _Device(
          _Hardware(
            screen: Size(669, 951),
            clockwise: true,
            screenRadii: [55, 55, 55, 55],
            bezel: [12, 12, 12, 12],
            nubs: [
              (_Edge.left, 104, 171),
              (_Edge.left, 183, 250),
              (_Edge.top, 191, 305),
            ],
            fold: 475.5,
          ),
          _Pose(Size(669, 951), top: 96, bar: _Bar.bottom),
          _Pose(Size(951, 669), right: 84, top: 64, bar: _Bar.side),
        );
      case PreviewDevice.ipad:
        return _Device(
          _Hardware(
            screen: Size(w, h),
            clockwise: true,
            screenRadii: const [18, 18, 18, 18],
            bezel: const [26, 26, 26, 26],
            nubs: [
              (_Edge.top, w - 134, w - 74),
              (_Edge.right, 100, 160),
              (_Edge.right, 172, 232),
            ],
            bezelCamera: true,
          ),
          _Pose(Size(w, h), top: 96, bar: _Bar.top),
          _Pose(Size(h, w), top: 96, bar: _Bar.top),
        );
      case PreviewDevice.iphoneHomeButton:
        final k = w / 375;
        return _Device(
          _Hardware(
            screen: Size(w, h),
            clockwise: false,
            screenRadii: const [0, 0, 0, 0],
            bezel: [110 * k, 28 * k, 110 * k, 28 * k],
            bodyRadii: [64 * k, 64 * k, 64 * k, 64 * k],
            nubs: [
              (_Edge.left, -62 * k, -40 * k),
              (_Edge.left, 20 * k, 80 * k),
              (_Edge.left, 100 * k, 160 * k),
              (_Edge.right, 20 * k, 100 * k),
            ],
            homeButton: true,
          ),
          _Pose(Size(w, h), top: 96, bar: _Bar.bottom),
          _Pose(Size(h, w), top: 56, bar: _Bar.bottom),
        );
      case PreviewDevice.iphone:
        final k = h / 874;
        final corner = math.min(62.0, w * 0.155);
        return _Device(
          _Hardware(
            screen: Size(w, h),
            clockwise: false,
            screenRadii: [corner, corner, corner, corner],
            bezel: const [9, 9, 9, 9],
            nubs: [
              (_Edge.left, 150 * k, 180 * k),
              (_Edge.left, 220 * k, 282 * k),
              (_Edge.left, 298 * k, 360 * k),
              (_Edge.right, 250 * k, 350 * k),
            ],
            island: true,
          ),
          _Pose(Size(w, h), top: 112, bar: _Bar.bottom),
          _Pose(Size(h, w), left: 62, right: 62, top: 56, bar: _Bar.bottom),
        );
    }
  }

  final _Hardware hardware;
  final _Pose portrait;
  final _Pose landscape;
}

class _Shape {
  const _Shape(this.rect, this.radius, this.color, {this.shadow = false});

  final Rect rect;
  final double radius;
  final Color color;
  final bool shadow;
}

class _ScreenContent {
  const _ScreenContent({
    required this.shapes,
    required this.columns,
    required this.fewest,
    required this.most,
    required this.split,
  });

  final List<_Shape> shapes;
  final int columns;

  /// The columns with the divider all the way to either side.
  final int fewest;
  final int most;
  final bool split;
}

const _ratios = [
  1.38,
  1.0,
  1.42,
  0.78,
  1.3,
  1.12,
  1.45,
  0.9,
  1.25,
  1.4,
  0.84,
  1.2
];

/// What the list looks like on a pose's screen, by the same split and column
/// rules the app uses there.
_ScreenContent _screenContent(
  _Pose pose,
  bool portrait, {
  required ListModeEnum mode,
  required int step,
  required double divider,
  required bool immersive,
  required _Colors colors,
}) {
  final shapes = <_Shape>[];
  void add(Rect rect, double radius, Color color, {bool shadow = false}) =>
      shapes.add(_Shape(rect, radius, color, shadow: shadow));
  final width = pose.size.width;
  final height = pose.size.height;
  final available = width - pose.left - pose.right;
  final split = available >= 720 && available > height * 1.05;
  double paneAt(double proportion) => split
      ? 320 + math.max(0, available - 641) * proportion.clamp(0.0, 1.0)
      : available;
  final phone = pose.size.shortestSide < 600;
  int columnsAt(double pane) =>
      CardSize.columns(mode, step, pane, phone: phone, immersive: immersive);
  final pane = paneAt(divider);
  final n = columnsAt(pane);

  add(Rect.fromLTWH(pose.left + 12, pose.top - 40, 70, 28), 14, colors.chipOn);
  add(Rect.fromLTWH(pose.left + 90, pose.top - 40, 56, 28), 14, colors.chip);
  add(Rect.fromLTWH(pose.left + 154, pose.top - 40, 84, 28), 14, colors.chip);

  final (gap, margin, radius) = switch (mode) {
    ListModeEnum.waterfallLarge => (immersive ? 6.0 : 10.0, 12.0, 10.0),
    ListModeEnum.waterfall => (4.0, 4.0, 6.0),
    _ => (6.0, 6.0, 6.0),
  };
  final columnWidth = (pane - margin * 2 - (n - 1) * gap) / n;
  for (var i = 0; i < n; i++) {
    final x = pose.left + margin + i * (columnWidth + gap);
    var y = pose.top;
    var k = i * 5 + 1;
    while (y < height) {
      final h = columnWidth *
          switch (mode) {
            ListModeEnum.grid => 1.8,
            ListModeEnum.gridTags => 2.0,
            _ => _ratios[k % _ratios.length],
          };
      add(Rect.fromLTWH(x, y, columnWidth, h), radius, colors.card);
      y += h + gap;
      k++;
    }
  }

  if (split) {
    final dx = pose.left + pane + 1;
    final dw = width - pose.right - dx;
    add(Rect.fromLTWH(pose.left + pane, 0, 1, height), 0, colors.divider);
    add(Rect.fromLTWH(dx, 0, dw, height), 0, colors.detail);
    final cover = math.min(180.0, dw * 0.34);
    final text = dx + 44 + cover;
    add(Rect.fromLTWH(dx + 24, pose.top - 30, cover, cover * 1.42), 12,
        colors.placeholder);
    add(Rect.fromLTWH(text, pose.top - 24, dw * 0.4, 18), 9,
        colors.placeholder);
    add(Rect.fromLTWH(text, pose.top + 8, dw * 0.28, 14), 7,
        colors.placeholder);
    add(Rect.fromLTWH(text, pose.top + 34, dw * 0.18, 14), 7,
        colors.placeholder);
    add(Rect.fromLTWH(dx + 24, pose.top + cover * 1.42, dw - 48, 14), 7,
        colors.placeholder);
    add(Rect.fromLTWH(dx + 24, pose.top + cover * 1.42 + 26, dw * 0.6, 14), 7,
        colors.placeholder);
  }

  switch (pose.bar) {
    case _Bar.bottom:
      final bw = math.min(width * 0.62, 360.0);
      final y = height - (portrait ? 34 : 22) - 58;
      add(Rect.fromLTWH((width - bw) / 2, y, bw, 58), 29, colors.chrome,
          shadow: true);
      for (var i = 0; i < 4; i++) {
        add(
            Rect.fromLTWH(
                (width - bw) / 2 + bw * (0.14 + 0.24 * i) - 9, y + 20, 18, 18),
            9,
            colors.dot);
      }
    case _Bar.side:
      // The trailing column: status, toolbar, then tabs, counted from the
      // camera's end, which is the bottom once the closed phone turns.
      final cx = width - 42;
      final k = height < 600 ? 32.0 : 40.0;
      final dot = k * 0.45;
      double at(double y, double h) => pose.cameraAtBottom ? height - y - h : y;
      void column(double y, int items) {
        final h = items * k + 12;
        add(Rect.fromLTWH(cx - 24, at(y, h), 48, h), 24, colors.chrome,
            shadow: true);
        for (var i = 0; i < items; i++) {
          add(
              Rect.fromLTWH(cx - dot / 2,
                  at(y + 6 + k * i + (k - dot) / 2, dot), dot, dot),
              dot / 2,
              colors.dot);
        }
      }
      final status = pose.camera ? 74.0 : 20.0;
      add(Rect.fromLTWH(cx - 17, at(status, 11), 34, 11), 5.5, colors.dot);
      column(status + 34, 3);
      column(height - 24 - (5 * k + 12), 5);
    case _Bar.top:
      final bw = math.min(width * 0.42, 420.0);
      add(Rect.fromLTWH((width - bw) / 2, 22, bw, 46), 23, colors.chrome,
          shadow: true);
      for (var i = 0; i < 4; i++) {
        add(
            Rect.fromLTWH(
                (width - bw) / 2 + bw * (0.14 + 0.24 * i) - 8, 37, 16, 16),
            8,
            colors.dot);
      }
  }

  return _ScreenContent(
    shapes: shapes,
    columns: n,
    fewest: split ? columnsAt(paneAt(0)) : n,
    most: split ? columnsAt(paneAt(1)) : n,
    split: split,
  );
}

class _MiniPainter extends CustomPainter {
  _MiniPainter({
    required this.frame,
    required this.shapes,
    required this.scale,
    required this.screenColor,
  });

  final _Frame frame;
  final List<_Shape> shapes;
  final double scale;
  final Color screenColor;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = frame.bounds.topLeft;
    for (final part in frame.behind) {
      canvas.drawRRect(part.rrect(origin, scale), Paint()..color = part.color);
    }
    final screen = frame.screen.rrect(origin, scale);
    canvas
      ..save()
      ..clipRRect(screen)
      ..drawRRect(screen, Paint()..color = screenColor)
      ..translate(screen.left, screen.top);
    for (final shape in shapes) {
      final rect = Rect.fromLTWH(
          shape.rect.left * scale,
          shape.rect.top * scale,
          shape.rect.width * scale,
          shape.rect.height * scale);
      final rrect =
          RRect.fromRectAndRadius(rect, Radius.circular(shape.radius * scale));
      if (shape.shadow) {
        canvas.drawRRect(
            rrect.shift(const Offset(0, 1)),
            Paint()
              ..color = const Color(0x2E000000)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
      }
      canvas.drawRRect(rrect, Paint()..color = shape.color);
    }
    canvas.restore();
    for (final part in frame.over) {
      canvas.drawRRect(part.rrect(origin, scale), Paint()..color = part.color);
    }
  }

  @override
  bool shouldRepaint(_MiniPainter old) =>
      old.frame != frame ||
      old.shapes != shapes ||
      old.scale != scale ||
      old.screenColor != screenColor;
}
