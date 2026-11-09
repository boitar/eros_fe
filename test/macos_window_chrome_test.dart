import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/appkit_glass.dart';
import 'package:eros_fe/widget/canvas_grain.dart';
import 'package:eros_fe/widget/detail_window_backdrop.dart';
import 'package:eros_fe/widget/macos_window_chrome.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Settings extends EhSettingService {
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  tearDown(() {
    PlatformCapabilities.debugHostPlatformOverride = null;
    PlatformCapabilities.appKitAvailable.value = false;
    MacOSWindowChrome.controls.value = const MacOSWindowControls();
    DetailWindowBackdrop.active.value = false;
    Get.reset();
  });
  const message = {
    'buttons': [
      {'x': 8.0, 'y': 10.0, 'width': 14.0, 'height': 14.0},
      {'x': 28.0, 'y': 10.0, 'width': 14.0, 'height': 14.0},
      {'x': 48.0, 'y': 10.0, 'width': 14.0, 'height': 14.0},
    ],
  };
  test('window controls union derives safe band from actual frames', () {
    final controls = MacOSWindowControls.fromMessage(message);
    expect(controls.bounds, const Rect.fromLTRB(8, 10, 62, 24));
    expect(controls.leading, 69);
    expect(controls.top, 31);
    expect(
      MacOSWindowControls.fromMessage(const {...message, 'fullscreen': true})
          .top,
      0,
    );
    expect(
      MacOSWindowControls.fromMessage(const {
        'buttons': [
          {'x': 8, 'y': 10, 'width': 14, 'height': 14, 'hidden': true},
        ],
      }).top,
      0,
    );
    expect(
      MacOSWindowControls.fromMessage(const {
        'buttons': [
          {'x': double.nan, 'y': 0, 'width': 10, 'height': 10},
        ],
      }).top,
      0,
    );
  });
  testWidgets(
    'safe band protects every glass mode and vanishes in fullscreen',
    (tester) async {
      for (final mode in ['native', 'flutter', 'off']) {
        PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.macOS;
        PlatformCapabilities.appKitAvailable.value = mode == 'native';
        MacOSWindowChrome.controls.value = MacOSWindowControls.fromMessage(
          message,
        );
        await tester.pumpWidget(
          CupertinoApp(
            home: GlassPreference(
              enabled: mode != 'off',
              child: MacOSWindowContent(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Builder(
                    builder: (context) => Text(
                      GlassMode.of(context).name,
                      key: const ValueKey('header'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text(mode), findsOneWidget);
        expect(tester.getTopLeft(find.byKey(const ValueKey('header'))).dy, 31);
        MacOSWindowChrome.controls.value = MacOSWindowControls.fromMessage(
          const {...message, 'fullscreen': true},
        );
        await tester.pump();
        expect(tester.getTopLeft(find.byKey(const ValueKey('header'))).dy, 0);
      }
      MacOSWindowChrome.controls.value = const MacOSWindowControls();
    },
  );
  test('controls equality and hashCode depend only on effective bounds', () {
    final first = MacOSWindowControls.fromMessage(message);
    final same = MacOSWindowControls.fromMessage(const {
      ...message,
      'fullscreen': false,
    });
    expect(first, same);
    expect(first.hashCode, same.hashCode);
    expect(first, isNot(const MacOSWindowControls()));
    expect(
      MacOSWindowControls.fromMessage(const {...message, 'fullscreen': true}),
      const MacOSWindowControls(),
    );
  });

  for (final (name, palette, brightness) in [
    ('light', EhPalette.graphite, Brightness.light),
    ('graphite', EhPalette.graphite, Brightness.dark),
    ('OLED', EhPalette.oled, Brightness.dark),
  ]) {
    testWidgets('$name titlebar shares canvas in every glass and sidebar mode',
        (tester) async {
      PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.macOS;
      tester.view.physicalSize = const Size(400, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Get.testMode = true;
      Get.put<LocaleService>(LocaleService());
      final settings = Get.put<EhSettingService>(_Settings());
      final capture = GlobalKey();
      final canvas = EhPalette.pick(palette.canvas,
          dark: brightness == Brightness.dark);
      var sidebar = true;
      var dragStarts = 0;
      MacOSWindowChrome.controls.value =
          MacOSWindowControls.fromMessage(message);
      for (final mode in ['native', 'flutter', 'off']) {
        PlatformCapabilities.appKitAvailable.value = mode == 'native';
        settings.liquidGlass = mode != 'off';
        await tester.pumpWidget(CupertinoApp(
          theme: palette.themeData(
              brightness, const CupertinoTextThemeData()),
          home: RepaintBoundary(
            key: capture,
            child: MacOSWindowContent(
              dragRegion: Listener(
                key: const ValueKey('window-drag-region'),
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => dragStarts++,
                child: const SizedBox.expand(),
              ),
              child: StatefulBuilder(builder: (context, setState) {
                return ColoredBox(
                  color: canvas,
                  child: CanvasGrain(
                    child: Row(children: [
                      if (sidebar)
                        const SizedBox(
                            key: ValueKey('sidebar'), width: 120),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: CupertinoButton(
                            onPressed: () =>
                                setState(() => sidebar = !sidebar),
                            child: const Text('Toggle sidebar'),
                          ),
                        ),
                      ),
                    ]),
                  ),
                );
              }),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.byType(AppKitGlassView), findsNothing);
        expect(find.byType(AppKitView), findsNothing);
        expect(find.byType(LiquidGlassSurface), findsNothing);
        final background = find.byKey(const ValueKey('macos-window-canvas'));
        expect(background, findsOneWidget);
        expect(tester.widget<ColoredBox>(background).color.toARGB32(),
            canvas.toARGB32());
        final grain = find.descendant(
            of: background, matching: find.byType(CustomPaint));
        expect(grain, findsOneWidget);
        expect(tester.widget<CustomPaint>(grain).painter,
            name == 'OLED' ? isNull : isNotNull);
        final drag = find.byKey(const ValueKey('window-drag-region'));
        expect(tester.getRect(drag), const Rect.fromLTWH(69, 0, 331, 31));
        final oldStarts = dragStarts;
        await tester.tapAt(const Offset(60, 15));
        expect(dragStarts, oldStarts);
        await tester.tapAt(const Offset(180, 15));
        expect(dragStarts, oldStarts + 1);
        for (var i = 0; i < 2; i++) {
          await _expectCanvasPixels(tester, capture, canvas);
          await tester.tap(find.text('Toggle sidebar'));
          await tester.pump();
        }
        MacOSWindowChrome.controls.value = const MacOSWindowControls();
        await tester.pump();
        expect(drag, findsNothing);
        await _expectCanvasPixels(tester, capture, canvas);
        MacOSWindowChrome.controls.value =
            MacOSWindowControls.fromMessage(message);
        await tester.pump();
        expect(tester.getRect(drag), const Rect.fromLTWH(69, 0, 331, 31));
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('detail backdrops retain the measured controls inset without a slab',
      (tester) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.macOS;
    MacOSWindowChrome.controls.value =
        MacOSWindowControls.fromMessage(message);
    DetailWindowBackdrop.active.value = true;
    late MediaQueryData contentMedia;
    await tester.pumpWidget(CupertinoApp(
      home: MacOSWindowContent(
        child: Builder(builder: (context) {
          contentMedia = MediaQuery.of(context);
          return const SizedBox.expand(key: ValueKey('detail-backdrop'));
        }),
      ),
    ));
    expect(tester.getTopLeft(find.byKey(const ValueKey('detail-backdrop'))).dy,
        0);
    expect(contentMedia.padding.top, 31);
    expect(contentMedia.viewPadding.top, 31);
    expect(find.byType(AppKitGlassView), findsNothing);
    expect(find.byType(LiquidGlassSurface), findsNothing);
  });

  testWidgets(
    'duplicate channel messages neither notify nor rebuild; fullscreen transitions still update',
    (tester) async {
      PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.macOS;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        MacOSWindowChrome.channel,
        (_) async => message,
      );
      addTearDown(
        () =>
            messenger.setMockMethodCallHandler(MacOSWindowChrome.channel, null),
      );
      await MacOSWindowChrome.initialize();
      var notifications = 0;
      var builds = 0;
      void changed() {
        notifications++;
      }

      MacOSWindowChrome.controls.addListener(changed);
      addTearDown(() => MacOSWindowChrome.controls.removeListener(changed));
      await tester.pumpWidget(
        CupertinoApp(
          home: MacOSWindowContent(
            child: Builder(
              builder: (context) {
                MediaQuery.of(context);
                builds++;
                return const Align(
                  alignment: Alignment.topLeft,
                  child: Text('Header', key: ValueKey('geometry-header')),
                );
              },
            ),
          ),
        ),
      );
      final initialBuilds = builds;
      Future<void> send(Object value) async {
        await messenger.handlePlatformMessage(
          'eros/window-chrome',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('changed', value),
          ),
          (_) {},
        );
        await tester.pump();
      }

      for (var i = 0; i < 5; i++) {
        await send({...message, 'fullscreen': false});
      }
      expect(notifications, 0);
      expect(builds, initialBuilds);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('geometry-header'))).dy,
        31,
      );
      await send({...message, 'fullscreen': true});
      expect(notifications, 1);
      expect(builds, greaterThan(initialBuilds));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('geometry-header'))).dy,
        0,
      );
      final fullscreenBuilds = builds;
      await send({...message, 'fullscreen': true});
      expect(notifications, 1);
      expect(builds, fullscreenBuilds);
      await send(message);
      expect(notifications, 2);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('geometry-header'))).dy,
        31,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}

Future<void> _expectCanvasPixels(
    WidgetTester tester, GlobalKey capture, Color canvas) async {
  final render =
      capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final samples = await tester.runAsync(() async {
    final image = await render.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData())!;
    List<double> average(int top) {
      final sums = List<double>.filled(3, 0);
      for (var y = top; y < top + 14; y++) {
        for (var x = 200; x < 260; x++) {
          final offset = (y * image.width + x) * 4;
          for (var c = 0; c < 3; c++) {
            sums[c] += bytes.getUint8(offset + c);
          }
        }
      }
      return [for (final sum in sums) sum / (60 * 14)];
    }
    final result = [average(8), average(70)];
    image.dispose();
    return result;
  });
  final expected = [canvas.r * 255, canvas.g * 255, canvas.b * 255];
  for (var c = 0; c < 3; c++) {
    expect(samples![0][c], closeTo(expected[c], 5));
    expect(samples[0][c], closeTo(samples[1][c], 1));
  }
}
