import 'dart:ui' as ui;

import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:eros_fe/widget/liquid_glass_scroll_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart' show Material;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void _useIPhone18ProMaxView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1320, 2868);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<List<int>> _pixelAt(
  WidgetTester tester,
  Finder repaintBoundary,
  int x,
  int y,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(repaintBoundary);
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
  if (image == null) {
    throw StateError('Could not capture the scrim test surface.');
  }
  final int imageWidth = image.width;
  final ByteData? data = await tester.runAsync<ByteData>(
    () async =>
        await image.toByteData(format: ui.ImageByteFormat.rawRgba) ??
        (throw StateError('Could not read the scrim test pixels.')),
  );
  image.dispose();
  if (data == null) {
    throw StateError('Could not read the scrim test pixels.');
  }
  final int offset = (y * imageWidth + x) * 4;
  return <int>[
    data.getUint8(offset),
    data.getUint8(offset + 1),
    data.getUint8(offset + 2),
  ];
}

int _rgbDistance(List<int> first, List<int> second) =>
    (first[0] - second[0]).abs() +
    (first[1] - second[1]).abs() +
    (first[2] - second[2]).abs();

bool _pixelNearColor(List<int> pixel, Color color, {int tolerance = 2}) =>
    (pixel[0] - (color.r * 255).round()).abs() <= tolerance &&
    (pixel[1] - (color.g * 255).round()).abs() <= tolerance &&
    (pixel[2] - (color.b * 255).round()).abs() <= tolerance;

void main() {
  Widget scrimHarness({
    required Brightness brightness,
    required LiquidGlassTopBarLayout layout,
  }) {
    const Color contentColor = Color(0xffc33623);
    return CupertinoApp(
      theme: CupertinoThemeData(brightness: brightness),
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(440, 956),
          devicePixelRatio: 3,
        ),
        child: RepaintBoundary(
          key: const ValueKey<String>('scrim-capture'),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const ColoredBox(color: contentColor),
              Align(
                alignment: Alignment.topCenter,
                child: LiquidGlassTopScrim(
                  safeTop: 59,
                  layout: layout,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  for (final layout in LiquidGlassTopBarLayout.values) {
    for (final count in [0, 1, 4, 10, 20]) {
      testWidgets(
        '$layout exposes all $count categories; browsing never selects',
        (tester) async {
          var callbacks = 0;
          await tester.pumpWidget(
            CupertinoApp(
              home: Center(
                child: SizedBox(
                  width: 390,
                  child: LiquidGlassRail(
                    title: 'Rail',
                    safeTop: 0,
                    fadeProgress: 0,
                    selectedIndex: 0,
                    layout: layout,
                    categories: List.generate(
                      count,
                      (i) => LiquidGlassRailCategory(
                        id: '$i',
                        title: '分类 $i English 🌿',
                        onTap: () => callbacks++,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (var i = 0; i < count; i++) {
            expect(find.text('分类 $i English 🌿'), findsOneWidget);
          }
          if (count > 4) {
            final scroll = find.byType(SingleChildScrollView);
            await tester.drag(scroll, const Offset(-600, 0));
            await tester.pumpAndSettle();
            expect(callbacks, 0);
            final controller =
                tester.widget<SingleChildScrollView>(scroll).controller!;
            expect(controller.offset, greaterThan(0));
            await tester.ensureVisible(find.text('分类 ${count - 1} English 🌿'));
            await tester.tap(find.text('分类 ${count - 1} English 🌿'));
            expect(callbacks, 1);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('long Chinese category titles keep their measured width', (
    tester,
  ) async {
    const title = '这是一个很长的中文分类标题用于验证横向滚动时不会被压缩成省略号';
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 240,
            child: LiquidGlassRail(
              title: 'Rail',
              safeTop: 0,
              fadeProgress: 0,
              selectedIndex: 0,
              layout: LiquidGlassTopBarLayout.inline,
              categories: <LiquidGlassRailCategory>[
                LiquidGlassRailCategory(title: title, onTap: () {}),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final paragraph = tester.renderObject<RenderParagraph>(find.text(title));
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(tester.getSize(find.text(title)).width, greaterThan(240));
    final scroll = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(scroll.controller!.position.maxScrollExtent, greaterThan(0));
  });

  testWidgets(
      'fitted category items keep natural widths and fill the rail evenly',
      (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 390,
            child: LiquidGlassRail(
              title: 'Rail',
              safeTop: 0,
              fadeProgress: 0,
              selectedIndex: 0,
              layout: LiquidGlassTopBarLayout.inline,
              categories: <LiquidGlassRailCategory>[
                LiquidGlassRailCategory(title: 'A', onTap: () {}),
                LiquidGlassRailCategory(title: 'Longer', onTap: () {}),
                LiquidGlassRailCategory(title: 'C', onTap: () {}),
                LiquidGlassRailCategory(title: 'D', onTap: () {}),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rail = tester.getRect(
      find.byKey(const ValueKey<String>('liquid-glass-category-selection')),
    );
    final slots = List<Rect>.generate(
      4,
      (index) => tester.getRect(
        find.byKey(ValueKey<String>('liquid-glass-category-slot-$index')),
      ),
    );
    final gaps = List<double>.generate(
      slots.length - 1,
      (index) => slots[index + 1].left - slots[index].right,
    );

    expect(slots.first.left, closeTo(rail.left, 0.01));
    expect(slots.last.right, closeTo(rail.right, 0.01));
    for (final gap in gaps.skip(1)) {
      expect(gap, closeTo(gaps.first, 0.01));
    }
  });

  testWidgets('top rail follows shared progress linearly in place', (
    tester,
  ) async {
    final motion = LiquidGlassBarMotion();
    addTearDown(motion.dispose);

    Widget app({bool enabled = true, bool reduceMotion = false}) =>
        CupertinoApp(
          home: Center(
            child: SizedBox(
              width: 320,
              child: MediaQuery(
                data: MediaQueryData(
                  size: const Size(400, 800),
                  devicePixelRatio: 1,
                  disableAnimations: reduceMotion,
                ),
                child: LiquidGlassBarMotionScope(
                  motion: motion,
                  child: LiquidGlassBarMotionBuilder(
                    enabled: enabled,
                    builder: (context, progress) => LiquidGlassRail(
                      title: 'Rail',
                      safeTop: 59,
                      fadeProgress: progress,
                      selectedIndex: 0,
                      leading: LiquidGlassRailAction(
                        icon: CupertinoIcons.time,
                        label: 'History',
                        onPressed: () {},
                      ),
                      categories: <LiquidGlassRailCategory>[
                        LiquidGlassRailCategory(title: '分类', onTap: () {}),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

    await tester.pumpWidget(app());
    final Offset leadingStart = tester.getTopLeft(find.byType(LiquidGlassRail));
    motion.value = 0.5;
    await tester.pump();

    final rail = find.byType(LiquidGlassRail);
    final Offset leadingAtHalf = tester.getTopLeft(rail);
    expect(leadingAtHalf, leadingStart);
    expect(
      tester
          .widgetList<Opacity>(
            find.descendant(of: rail, matching: find.byType(Opacity)),
          )
          .map((opacity) => opacity.opacity),
      everyElement(closeTo(0.5, 0.001)),
    );

    motion.value = 1.0;
    await tester.pump();
    expect(find.text('分类'), findsNothing);

    await tester.pumpWidget(app(enabled: false));
    motion.value = 1.0;
    await tester.pump();
    expect(find.text('分类'), findsOneWidget);

    await tester.pumpWidget(app(reduceMotion: true));
    motion.value = 0.5;
    await tester.pump();
    expect(
      tester
          .widgetList<Opacity>(
            find.descendant(of: rail, matching: find.byType(Opacity)),
          )
          .map((opacity) => opacity.opacity),
      everyElement(closeTo(1.0, 0.001)),
    );
    expect(find.text('分类'), findsOneWidget);

    motion.value = 0.8;
    await tester.pump();
    expect(find.text('分类'), findsNothing);

    motion.value = 0.5;
    await tester.pump();
    expect(find.text('分类'), findsOneWidget);
  });

  testWidgets('dark top scrim spans the safe area without a color seam', (
    tester,
  ) async {
    _useIPhone18ProMaxView(tester);
    await tester.pumpWidget(
      scrimHarness(
        brightness: Brightness.dark,
        layout: LiquidGlassTopBarLayout.twoRow,
      ),
    );

    const captureKey = ValueKey<String>('scrim-capture');
    const scrimKey = ValueKey<String>('liquid-glass-top-scrim');
    const contentColor = Color(0xffc33623);
    final context = tester.element(find.byKey(scrimKey));
    final systemBackground = CupertinoDynamicColor.resolve(
      CupertinoColors.systemBackground,
      context,
    );
    final decoratedBox = tester.widget<DecoratedBox>(find.byKey(scrimKey));
    final gradient =
        (decoratedBox.decoration as BoxDecoration).gradient! as LinearGradient;
    final Rect scrimRect = tester.getRect(find.byKey(scrimKey));

    expect(gradient.colors, hasLength(4));
    expect(gradient.colors.first, systemBackground.withValues(alpha: 0.37));
    expect(gradient.colors[1], systemBackground.withValues(alpha: 0.37 * 0.55));
    expect(gradient.colors[2], systemBackground.withValues(alpha: 0.37 * 0.22));
    expect(gradient.colors.last, systemBackground.withValues(alpha: 0));
    expect(gradient.stops, <double>[0.0, 0.35, 0.70, 1.0]);
    expect(gradient.begin, Alignment.topCenter);
    expect(gradient.end, Alignment.bottomCenter);
    expect(scrimRect.top, 0);
    expect(scrimRect.left, 0);
    expect(scrimRect.width, 440);
    expect(scrimRect.height, closeTo(956 * 0.17, 0.001));
    expect(
      find.byKey(const ValueKey<String>('liquid-glass-status-background')),
      findsNothing,
    );
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.byType(Material), findsNothing);

    final List<List<int>> safeAreaPixels = <List<int>>[];
    for (int y = 57; y <= 61; y++) {
      safeAreaPixels
          .add(await _pixelAt(tester, find.byKey(captureKey), 220, y));
    }
    for (int index = 1; index < safeAreaPixels.length; index++) {
      expect(
        _rgbDistance(safeAreaPixels[index - 1], safeAreaPixels[index]),
        lessThanOrEqualTo(4),
        reason:
            'Adjacent pixels remain continuous at safeTop=59 (y=${56 + index}).',
      );
    }
    final int beforeEdgeStep =
        _rgbDistance(safeAreaPixels[1], safeAreaPixels[2]);
    final int afterEdgeStep =
        _rgbDistance(safeAreaPixels[2], safeAreaPixels[3]);
    expect((beforeEdgeStep - afterEdgeStep).abs(), lessThanOrEqualTo(3));

    final List<int> topPixel =
        await _pixelAt(tester, find.byKey(captureKey), 220, 0);
    final Color expectedTopColor = Color.alphaBlend(
      systemBackground.withValues(alpha: 0.37),
      contentColor,
    );
    expect(
      _pixelNearColor(topPixel, expectedTopColor),
      isTrue,
      reason:
          'Top pixel $topPixel should be near $expectedTopColor and retain visible content.',
    );
    expect(
      _pixelNearColor(
        await _pixelAt(tester, find.byKey(captureKey), 220, 165),
        contentColor,
      ),
      isTrue,
      reason: 'The gradient is fully transparent after fadeEnd.',
    );
  });

  testWidgets('light top scrim spans the safe area without a color seam', (
    tester,
  ) async {
    _useIPhone18ProMaxView(tester);
    await tester.pumpWidget(
      scrimHarness(
        brightness: Brightness.light,
        layout: LiquidGlassTopBarLayout.inline,
      ),
    );

    const captureKey = ValueKey<String>('scrim-capture');
    const scrimKey = ValueKey<String>('liquid-glass-top-scrim');
    const contentColor = Color(0xffc33623);
    final context = tester.element(find.byKey(scrimKey));
    final systemBackground = CupertinoDynamicColor.resolve(
      CupertinoColors.systemBackground,
      context,
    );
    final decoratedBox = tester.widget<DecoratedBox>(find.byKey(scrimKey));
    final gradient =
        (decoratedBox.decoration as BoxDecoration).gradient! as LinearGradient;
    final Rect scrimRect = tester.getRect(find.byKey(scrimKey));

    expect(gradient.colors, hasLength(4));
    expect(gradient.colors.first, systemBackground.withValues(alpha: 0.32));
    expect(gradient.colors[1], systemBackground.withValues(alpha: 0.32 * 0.55));
    expect(gradient.colors[2], systemBackground.withValues(alpha: 0.32 * 0.22));
    expect(gradient.colors.last, systemBackground.withValues(alpha: 0));
    expect(gradient.stops, <double>[0.0, 0.35, 0.70, 1.0]);
    expect(gradient.begin, Alignment.topCenter);
    expect(gradient.end, Alignment.bottomCenter);
    expect(scrimRect.top, 0);
    expect(scrimRect.left, 0);
    expect(scrimRect.width, 440);
    expect(scrimRect.height, closeTo(956 * 0.17, 0.001));
    expect(
      find.byKey(const ValueKey<String>('liquid-glass-status-background')),
      findsNothing,
    );
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.byType(Material), findsNothing);

    final List<List<int>> safeAreaPixels = <List<int>>[];
    for (int y = 57; y <= 61; y++) {
      safeAreaPixels
          .add(await _pixelAt(tester, find.byKey(captureKey), 220, y));
    }
    for (int index = 1; index < safeAreaPixels.length; index++) {
      expect(
        _rgbDistance(safeAreaPixels[index - 1], safeAreaPixels[index]),
        lessThanOrEqualTo(4),
        reason:
            'Adjacent pixels remain continuous at safeTop=59 (y=${56 + index}).',
      );
    }
    final int beforeEdgeStep =
        _rgbDistance(safeAreaPixels[1], safeAreaPixels[2]);
    final int afterEdgeStep =
        _rgbDistance(safeAreaPixels[2], safeAreaPixels[3]);
    expect((beforeEdgeStep - afterEdgeStep).abs(), lessThanOrEqualTo(3));

    final List<int> topPixel =
        await _pixelAt(tester, find.byKey(captureKey), 220, 0);
    final Color expectedTopColor = Color.alphaBlend(
      systemBackground.withValues(alpha: 0.32),
      contentColor,
    );
    expect(
      _pixelNearColor(topPixel, expectedTopColor),
      isTrue,
      reason:
          'Top pixel $topPixel should be near $expectedTopColor and retain visible content.',
    );
    expect(
      _pixelNearColor(
        await _pixelAt(tester, find.byKey(captureKey), 220, 165),
        contentColor,
      ),
      isTrue,
      reason: 'The gradient is fully transparent after fadeEnd.',
    );
  });

  testWidgets('top scrim never ends above the active rail', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(400, 300),
            devicePixelRatio: 2,
          ),
          child: Center(
            child: LiquidGlassTopScrim(
              safeTop: 59,
              layout: LiquidGlassTopBarLayout.twoRow,
            ),
          ),
        ),
      ),
    );
    // The 17% screen target is only 51pt here, so the scrim must still cover
    // the complete 153pt expanded rail.
    expect(tester.getSize(find.byType(LiquidGlassTopScrim)).height, 153);
  });

  testWidgets(
    'top scrim ignores the accessibility callback and never blurs',
    (tester) async {
      final previousTargetPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = previousTargetPlatform;
      });
      addTearDown(LiquidGlassAccessibilitySettings.stopWatching);

      MockStreamHandlerEventSink? settings;
      tester.binding.defaultBinaryMessenger.setMockStreamHandler(
        const EventChannel('eros/accessibility-settings'),
        MockStreamHandler.inline(
          onListen: (Object? _, MockStreamHandlerEventSink events) {
            settings = events;
          },
        ),
      );

      await tester.pumpWidget(
        const CupertinoApp(
          home: Center(
            child: LiquidGlassTopScrim(
              safeTop: 59,
              layout: LiquidGlassTopBarLayout.twoRow,
            ),
          ),
        ),
      );
      await tester.pump();

      const scrimKey = ValueKey<String>('liquid-glass-top-scrim');
      List<Color> gradientColors() =>
          ((tester.widget<DecoratedBox>(find.byKey(scrimKey)).decoration
                      as BoxDecoration)
                  .gradient! as LinearGradient)
              .colors;
      final initial = gradientColors();

      // The scrim itself never subscribes to the bridge; the test subscribes
      // so arriving values prove the gradient does not react to them.
      LiquidGlassAccessibilitySettings.watch();
      await tester.pump();
      await tester.pump();
      expect(settings, isNotNull);

      // Regular transparency: no blur appears and the gradient is untouched.
      settings!.success(false);
      await tester.pump();
      await tester.pump();
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(ShaderMask), findsNothing);
      expect(gradientColors(), initial);
      expect(find.byKey(scrimKey), findsOneWidget);

      // Reduce Transparency: the fixed gradient is likewise untouched.
      settings!.success(true);
      await tester.pump();
      await tester.pump();
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(ShaderMask), findsNothing);
      expect(gradientColors(), initial);
      expect(find.byKey(scrimKey), findsOneWidget);
      debugDefaultTargetPlatformOverride = previousTargetPlatform;
    },
  );

  testWidgets(
    'geometry update preserves half collapse and deep reading offset',
    (tester) async {
      final controller = LiquidGlassScrollController()..headerExtent = 94;
      addTearDown(controller.dispose);
      Widget page() => CupertinoApp(
            home: ListView.builder(
              controller: controller,
              itemExtent: 80,
              itemCount: 50,
              itemBuilder: (_, i) => Text('$i'),
            ),
          );
      await tester.pumpWidget(page());
      controller.jumpTo(47);
      controller.headerExtent = 44;
      await tester.pumpWidget(page());
      expect(controller.offset, 22);
      controller.jumpTo(400);
      controller.headerExtent = 94;
      await tester.pumpWidget(page());
      expect(controller.offset, 450);
    },
  );
}
