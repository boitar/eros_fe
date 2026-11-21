import 'package:bitsdojo_window/bitsdojo_window.dart';
// ignore: depend_on_referenced_packages
import 'package:bitsdojo_window_platform_interface/bitsdojo_window_platform_interface.dart';
import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/browse_layout.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/widget/canvas_grain.dart';
import 'package:eros_fe/widget/desktop.dart';
import 'package:eros_fe/widget/desktop_browse_style.dart';
import 'package:eros_fe/widget/desktop_sidebar.dart';
import 'package:eros_fe/widget/detail_window_backdrop.dart';
import 'package:eros_fe/widget/windows_window_content.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    PlatformCapabilities.debugHostPlatformOverride = null;
  });

  testWidgets('Desktop reserves titlebar and wires caption button actions', (
    tester,
  ) async {
    final oldPlatform = BitsdojoWindowPlatform.instance;
    final fake = _WindowPlatform();
    BitsdojoWindowPlatform.instance = fake;
    addTearDown(() => BitsdojoWindowPlatform.instance = oldPlatform);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => Desktop(child: child!),
        home: const Scaffold(
          body: Align(alignment: Alignment.topLeft, child: Text('page header')),
        ),
      ),
    );
    expect(tester.getTopLeft(find.text('page header')).dy, 32);
    final buttons = find.byType(WindowButton);
    expect(buttons, findsNWidgets(3));
    for (var index = 0; index < 3; index++) {
      tester.widget<WindowButton>(buttons.at(index)).onPressed!();
      await tester.pump();
    }
    expect(fake.window.calls, ['minimize', 'maximize', 'close']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Windows titlebar canvas follows light and dark themes', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.windows;
    final oldPlatform = BitsdojoWindowPlatform.instance;
    BitsdojoWindowPlatform.instance = _WindowPlatform();
    addTearDown(() => BitsdojoWindowPlatform.instance = oldPlatform);

    for (final brightness in [Brightness.light, Brightness.dark]) {
      final canvas = brightness == Brightness.light
          ? const Color(0xFFF2F3F6)
          : const Color(0xFF0E0F12);
      await tester.pumpWidget(
        CupertinoApp(
          theme: CupertinoThemeData(
            brightness: brightness,
            scaffoldBackgroundColor: canvas,
          ),
          builder: (context, child) => Desktop(child: child!),
          home: const CupertinoPageScaffold(child: Text('page')),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ColoredBox>(
              find.byKey(const ValueKey('windows-window-canvas')),
            )
            .color,
        canvas,
      );
      expect(
        tester.widget<WindowButton>(find.byType(WindowButton).first).colors,
        same(brightness == Brightness.dark ? darkButtonColors : buttonColors),
      );
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
    PlatformCapabilities.debugHostPlatformOverride = null;
  });

  testWidgets('Windows light browse canvas matches the toolbar tone', (
    tester,
  ) async {
    for (final (platform, emphasis) in [
      (TargetPlatform.windows, 0.0),
      (TargetPlatform.macOS, .10),
    ]) {
      PlatformCapabilities.debugHostPlatformOverride = platform;
      await tester.pumpWidget(
        CupertinoApp(
          key: ValueKey(platform),
          theme: const CupertinoThemeData(brightness: Brightness.light),
          home: Builder(
            builder: (context) => ColoredBox(
              key: const ValueKey('browse-canvas'),
              color: DesktopBrowseStyle.canvas(context),
            ),
          ),
        ),
      );
      final color = tester
          .widget<ColoredBox>(find.byKey(const ValueKey('browse-canvas')))
          .color;
      expect(
        color.toARGB32(),
        Color.alphaBlend(
          const Color(0xFF14161A).withValues(alpha: emphasis),
          const Color(0xFFF2F3F6),
        ).toARGB32(),
        reason: '$platform browse canvas tone',
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('desktop canvases stay flat behind their toolbars', (
    tester,
  ) async {
    for (final platform in [TargetPlatform.windows, TargetPlatform.macOS]) {
      PlatformCapabilities.debugHostPlatformOverride = platform;
      await tester.pumpWidget(
        const CupertinoApp(home: CanvasGrain(child: SizedBox.expand())),
      );
      final grain = find.descendant(
        of: find.byType(CanvasGrain),
        matching: find.byType(CustomPaint),
      );
      expect(grain, findsOneWidget);
      expect(tester.widget<CustomPaint>(grain).painter, isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Windows detail backdrop remains visible behind titlebar', (
    tester,
  ) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.windows;
    final oldPlatform = BitsdojoWindowPlatform.instance;
    BitsdojoWindowPlatform.instance = _WindowPlatform();
    addTearDown(() {
      BitsdojoWindowPlatform.instance = oldPlatform;
      DetailWindowBackdrop.active.value = false;
    });
    const cover = Color(0xFF235B89);
    await tester.pumpWidget(
      CupertinoApp(
        builder: (_, child) => Desktop(child: child!),
        home: const ColoredBox(
          key: ValueKey('detail-route-canvas'),
          color: cover,
          child: SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    final detailCanvas = find.byKey(const ValueKey('detail-route-canvas'));
    expect(tester.getTopLeft(detailCanvas).dy, 32);
    DetailWindowBackdrop.active.value = true;
    await tester.pump();
    expect(tester.getTopLeft(detailCanvas).dy, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Windows content and navigator overlays stay below titlebar', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.windows;
    final navigator = GlobalKey<NavigatorState>();
    for (final width in [320.0, 1000.0]) {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      var clicks = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (context, child) => Stack(
            children: [
              Positioned.fill(
                child: WindowsWindowContent(titleBarHeight: 32, child: child!),
              ),
              Positioned(
                top: 0,
                right: 0,
                width: 40,
                height: 32,
                child: GestureDetector(
                  key: const ValueKey('caption'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => clicks++,
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
          home: Builder(
            builder: (context) {
              expect(MediaQuery.paddingOf(context).top, 0);
              expect(MediaQuery.sizeOf(context), Size(width, 668));
              return const Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: Text('custom header', key: ValueKey('header')),
                ),
              );
            },
          ),
        ),
      );
      expect(tester.getTopLeft(find.byKey(const ValueKey('header'))).dy, 32);
      await tester.tap(find.byKey(const ValueKey('caption')));
      expect(clicks, 1);
      final context = navigator.currentContext!;
      showDialog<void>(
        context: context,
        builder: (_) => const Dialog(
          child: SizedBox(width: 150, height: 100, child: Text('dialog')),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byType(Dialog)).dy,
        greaterThanOrEqualTo(32),
      );
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => const SizedBox(height: 200, child: Text('sheet')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('sheet')).dy,
        greaterThanOrEqualTo(32),
      );
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    debugDefaultTargetPlatformOverride = null;
  });

  test('desktop sidebar activates at the shipped Windows window width', () {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.windows;
    for (final (width, expected) in [
      (799.0, false),
      (800.0, true),
      (899.0, true),
      (900.0, true),
    ]) {
      expect(
        usesDesktopSidebar(
          environment: AdaptiveEnvironmentSnapshot(size: Size(width, 600)),
        ),
        expected,
        reason: 'Windows window width $width',
      );
    }
  });

  testWidgets(
    'desktop split layout wraps both primary and detail panes with platform pane radii',
    (tester) async {
      addTearDown(() {
        PlatformCapabilities.debugHostPlatformOverride = null;
      });
      for (final (platform, expectedRadius) in [
        (TargetPlatform.windows, 10.0),
        (TargetPlatform.macOS, 16.0),
      ]) {
        PlatformCapabilities.debugHostPlatformOverride = platform;
        expect(DesktopBrowseStyle.paneRadius, expectedRadius);

        await tester.pumpWidget(
          CupertinoApp(
            key: ValueKey(platform),
            home: const SizedBox(
              width: 1000,
              height: 700,
              child: AdaptiveBrowseLayout(
                environment: AdaptiveEnvironmentSnapshot(
                  size: Size(1000, 700),
                ),
                split: true,
                desktop: true,
                detailActive: false,
                primary: Text('primary pane'),
                detail: Text('detail pane'),
              ),
            ),
          ),
        );
        await tester.pump();

        final surfaces = find.byType(DesktopPaneSurface);
        expect(surfaces, findsNWidgets(2));
        for (var i = 0; i < 2; i++) {
          final clip = tester.widget<ClipRRect>(
            find.descendant(
              of: surfaces.at(i),
              matching: find.byType(ClipRRect),
            ),
          );
          expect(clip.borderRadius, BorderRadius.circular(expectedRadius));
        }
        expect(find.text('primary pane'), findsOneWidget);
        expect(find.text('detail pane'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _WindowPlatform extends BitsdojoWindowPlatform {
  final window = _Window();
  @override
  DesktopWindow get appWindow => window;
}

class _Window extends NotImplementedWindow {
  final calls = <String>[];
  @override
  double get titleBarHeight => 32;
  @override
  Size get size => const Size(800, 600);
  @override
  bool get isMaximized => false;
  @override
  void minimize() => calls.add('minimize');
  @override
  void maximizeOrRestore() => calls.add('maximize');
  @override
  void close() => calls.add('close');
}
