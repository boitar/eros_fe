import 'dart:async';

import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/component/setting/setting_menu.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/appkit_glass.dart';
import 'package:eros_fe/widget/flutter_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as glass;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.macOS;
    PlatformCapabilities.appKitAvailable.value = false;
  });
  tearDown(() {
    PlatformCapabilities.debugHostPlatformOverride = null;
    PlatformCapabilities.appKitAvailable.value = false;
    PlatformCapabilities.appKitMenuAvailable = false;
    NativeSettingMenu.resetForTesting();
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(AppKitGlassRuntime.channel, null);
  });
  test(
    'old macOS and unavailable plugin keep Flutter mode; off stays off',
    () async {
      for (final response in [
        null,
        {'backend': 'none', 'apiVersion': 1},
        {'backend': 'appKit', 'apiVersion': 99},
      ]) {
        messenger.setMockMethodCallHandler(
          AppKitGlassRuntime.channel,
          (_) async => response,
        );
        await AppKitGlassRuntime.initialize();
        expect(GlassMode.resolve(enabled: true), GlassMode.flutter);
        expect(GlassMode.resolve(enabled: false), GlassMode.off);
      }
      messenger.setMockMethodCallHandler(
        AppKitGlassRuntime.channel,
        (_) async => throw PlatformException(code: 'unavailable'),
      );
      await AppKitGlassRuntime.initialize();
      expect(GlassMode.resolve(enabled: true), GlassMode.flutter);
    },
  );
  test(
    'negotiated AppKit is component specific and never becomes UIKit',
    () async {
      messenger.setMockMethodCallHandler(
        AppKitGlassRuntime.channel,
        (_) async => {'backend': 'appKit', 'apiVersion': 1},
      );
      await AppKitGlassRuntime.initialize();
      expect(
        PlatformCapabilities.nativeGlassBackend,
        NativeGlassBackend.appKit,
      );
      expect(PlatformCapabilities.uiKitGlass, isFalse);
      final mode = GlassMode.resolve(enabled: true);
      expect(mode, GlassMode.native);
      expect(mode.forComponent(flutterImplemented: true), GlassMode.flutter);
      expect(mode.forComponent(), GlassMode.off);
      expect(
        mode.forComponent(
          flutterImplemented: true,
          nativeBackends: {NativeGlassBackend.appKit},
        ),
        GlassMode.native,
      );
      expect(GlassMode.resolve(enabled: false), GlassMode.off);
    },
  );
  test('iOS never negotiates AppKit and retains UIKit backend', () async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.iOS;
    var calls = 0;
    messenger.setMockMethodCallHandler(AppKitGlassRuntime.channel, (_) async {
      calls++;
      return null;
    });
    await AppKitGlassRuntime.initialize();
    expect(calls, 0);
    expect(PlatformCapabilities.nativeGlassBackend, NativeGlassBackend.uiKit);
    expect(GlassMode.resolve(enabled: true), GlassMode.native);
    expect(GlassMode.resolve(enabled: false), GlassMode.off);
  });
  testWidgets('unavailable and off bottom bar never creates native view', (
    tester,
  ) async {
    for (final enabled in [true, false]) {
      await tester.pumpWidget(
        CupertinoApp(
          home: GlassPreference(
            enabled: enabled,
            child: Center(
              child: SizedBox(
                height: 80,
                child: LiquidGlassTabBar(
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(CupertinoIcons.home),
                      label: 'Home',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(CupertinoIcons.star),
                      label: 'Star',
                    ),
                  ],
                  nativeItems: const [
                    LiquidGlassTabItem(
                      label: 'Home',
                      codePoint: 0,
                      fallbackSymbol: 'house',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(AppKitView), findsNothing);
      expect(find.byType(UiKitView), findsNothing);
    }
  });
  testWidgets(
    'native settings decoration preserves Flutter actions and off removes it',
    (tester) async {
      PlatformCapabilities.appKitAvailable.value = true;
      final channels = <String>[];
      final created = <String>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final args = call.arguments as Map;
          created.add(args['viewType'] as String);
          final channel = 'eros/appkit-glass/${args['id']}';
          channels.add(channel);
          messenger.setMockMethodCallHandler(
            MethodChannel(channel),
            (_) async => null,
          );
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in channels) {
          messenger.setMockMethodCallHandler(MethodChannel(channel), null);
        }
      });
      var actions = 0;
      Widget page(bool enabled) => CupertinoApp(
        home: GlassCapabilityScope(
          child: GlassPreference(
            enabled: enabled,
            child: Center(
              child: SizedBox(
                height: 60,
                child: SettingGlassBar(
                  title: 'Settings',
                  trailing: CupertinoButton(
                    onPressed: () => actions++,
                    child: const Text('Done'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(page(true));
      await tester.pump();
      expect(find.byType(AppKitView), findsOneWidget);
      expect(created, ['eros/appkit-glass-view']);
      expect(find.byType(FlutterGlassPanel), findsNothing);
      await tester.tap(find.text('Done'));
      expect(actions, 1);
      expect(find.byType(UiKitView), findsNothing);
      await tester.pumpWidget(page(false));
      await tester.pump();
      expect(find.byType(AppKitView), findsNothing);
      expect(find.text('Settings'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('NSMenu negotiates independently of glass version and handles selection once', () async {
    NativeSettingMenu.resetForTesting();
    messenger.setMockMethodCallHandler(
      AppKitGlassRuntime.channel,
      (_) async => {'apiVersion': 1, 'backend': 'none', 'menu': true},
    );
    await AppKitGlassRuntime.initialize();
    expect(GlassMode.resolve(enabled: true), GlassMode.flutter);
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(const MethodChannel('eros/menu'), (
      call,
    ) async {
      calls.add(call);
      return true;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        const MethodChannel('eros/menu'),
        null,
      ),
    );
    final selected = <int>[];
    expect(
      await NativeSettingMenu.show(
        rect: const Rect.fromLTWH(10, 20, 80, 30),
        items: [
          {'title': 'Choice', 'checked': true},
        ],
        onSelected: selected.add,
      ),
      isTrue,
    );
    final token = (calls.single.arguments as Map)['token'];
    for (var i = 0; i < 2; i++) {
      await messenger.handlePlatformMessage(
        'eros/menu',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('selected', {'token': token, 'index': 0}),
        ),
        (_) {},
      );
    }
    expect(selected, [0]);
    messenger.setMockMethodCallHandler(
      const MethodChannel('eros/menu'),
      (_) async => throw PlatformException(code: 'failed'),
    );
    expect(
      await NativeSettingMenu.show(
        rect: const Rect.fromLTWH(0, 0, 50, 20),
        items: [
          {'title': 'Choice'},
        ],
        onSelected: selected.add,
      ),
      isFalse,
    );
  });
  testWidgets(
    'native bottom bar sends selection and failure returns to Flutter',
    (tester) async {
      PlatformCapabilities.appKitAvailable.value = true;
      final channels = <String>[];
      int? viewId;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          viewId = (call.arguments as Map)['id'] as int;
          final name = 'eros/appkit-glass/$viewId';
          channels.add(name);
          messenger.setMockMethodCallHandler(
            MethodChannel(name),
            (_) async => null,
          );
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in channels) {
          messenger.setMockMethodCallHandler(MethodChannel(channel), null);
        }
      });
      final selections = <int>[];
      await tester.pumpWidget(
        CupertinoApp(
          home: GlassCapabilityScope(
            child: GlassPreference(
              enabled: true,
              child: Center(
                child: SizedBox(
                  height: 80,
                  child: LiquidGlassTabBar(
                    onTap: selections.add,
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(CupertinoIcons.home),
                        label: 'Home',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(CupertinoIcons.star),
                        label: 'Star',
                      ),
                    ],
                    nativeItems: const [
                      LiquidGlassTabItem(
                        label: 'Home',
                        codePoint: 0,
                        fallbackSymbol: 'house',
                      ),
                      LiquidGlassTabItem(
                        label: 'Star',
                        codePoint: 0,
                        fallbackSymbol: 'star',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AppKitView), findsOneWidget);
      expect(viewId, isNotNull);
      await messenger.handlePlatformMessage(
        'eros/appkit-glass/$viewId',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('select', 1),
        ),
        (_) {},
      );
      expect(selections, [1]);
      AppKitGlassRuntime.disable();
      await tester.pump();
      await tester.pump();
      expect(find.byType(AppKitView), findsNothing);
      expect(find.byType(UiKitView), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  Widget bottomBar({int selected = 0}) => CupertinoApp(
    home: GlassCapabilityScope(
      child: GlassPreference(
        enabled: true,
        child: Center(
          child: SizedBox(
            height: 80,
            child: LiquidGlassTabBar(
              currentIndex: selected,
              onTap: (_) {},
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.star),
                  label: 'Star',
                ),
              ],
              // Deliberately allocate fresh nested lists/maps on each parent rebuild.
              nativeItems: ['Home', 'Star']
                  .map(
                    (label) => LiquidGlassTabItem(
                      label: label,
                      codePoint: 0,
                      fallbackSymbol: label == 'Home' ? 'house' : 'star',
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    ),
  );

  for (final hangs in [false, true]) {
    testWidgets(
      'created view update ${hangs ? 'hang' : 'exception'} restores Flutter bar',
      (tester) async {
        PlatformCapabilities.appKitAvailable.value = true;
        final pending = Completer<Object?>();
        final channels = <String>[];
        var updates = 0;
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
          call,
        ) async {
          if (call.method == 'create') {
            final id = (call.arguments as Map)['id'];
            final name = 'eros/appkit-glass/$id';
            channels.add(name);
            messenger.setMockMethodCallHandler(MethodChannel(name), (
              call,
            ) async {
              expect(call.method, 'update');
              updates++;
              return pending.future;
            });
          }
          return null;
        });
        addTearDown(() {
          messenger.setMockMethodCallHandler(
            SystemChannels.platform_views,
            null,
          );
          for (final channel in channels) {
            messenger.setMockMethodCallHandler(MethodChannel(channel), null);
          }
        });
        await tester.pumpWidget(bottomBar());
        await tester.pump();
        expect(updates, 1);
        expect(find.byType(AppKitView), findsOneWidget);
        expect(PlatformCapabilities.appKitGlass, isTrue);
        if (hangs) {
          // Keep the actual channel response future unresolved past its deadline.
          await tester.pump(const Duration(seconds: 3));
          expect(pending.isCompleted, isFalse);
        } else {
          pending.completeError(PlatformException(code: 'update_failed'));
          await tester.pump();
        }
        await tester.pump();
        await tester.pump();
        expect(PlatformCapabilities.appKitGlass, isFalse);
        expect(find.byType(AppKitView), findsNothing);
        expect(find.byType(glass.GlassTabBar), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        if (!pending.isCompleted) {
          pending.complete(null);
        }
      },
    );
  }

  testWidgets(
    'equivalent nested configuration rebuild skips update; selection changes send it',
    (tester) async {
      PlatformCapabilities.appKitAvailable.value = true;
      final channels = <String>[];
      var updates = 0;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final name = 'eros/appkit-glass/${(call.arguments as Map)['id']}';
          channels.add(name);
          messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
            updates++;
            return null;
          });
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in channels) {
          messenger.setMockMethodCallHandler(MethodChannel(channel), null);
        }
      });
      await tester.pumpWidget(bottomBar());
      await tester.pump();
      expect(updates, 1);
      await tester.pumpWidget(bottomBar());
      await tester.pump();
      expect(updates, 1);
      await tester.pumpWidget(bottomBar(selected: 1));
      await tester.pump();
      expect(updates, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
