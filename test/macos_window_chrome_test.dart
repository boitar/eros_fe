import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/widget/macos_window_chrome.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    PlatformCapabilities.debugHostPlatformOverride = null;
    PlatformCapabilities.appKitAvailable.value = false;
    MacOSWindowChrome.controls.value = const MacOSWindowControls();
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
