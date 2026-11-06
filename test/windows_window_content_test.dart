import 'package:bitsdojo_window/bitsdojo_window.dart';
// ignore: depend_on_referenced_packages
import 'package:bitsdojo_window_platform_interface/bitsdojo_window_platform_interface.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/widget/desktop.dart';
import 'package:eros_fe/widget/windows_window_content.dart';
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
