import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/flutter_glass.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:eros_fe/widget/segmented_rail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  tearDown(() {
    PlatformCapabilities.debugHostPlatformOverride = null;
    FlutterGlassRuntime.debugAvailable = null;
  });
  for (final host in [
    TargetPlatform.android,
    TargetPlatform.macOS,
    TargetPlatform.windows
  ]) {
    for (final enabled in [true, false]) {
      testWidgets(
          '$host glass=$enabled surfaces, tab callbacks and category gestures',
          (tester) async {
        PlatformCapabilities.debugHostPlatformOverride = host;
        final calls = <String>[];
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        for (final channel in [
          'flutter/platform_views',
          'eros/accessibility-settings'
        ]) {
          messenger.setMockMethodCallHandler(MethodChannel(channel),
              (call) async {
            calls.add('$channel/${call.method}');
            return null;
          });
          addTearDown(() =>
              messenger.setMockMethodCallHandler(MethodChannel(channel), null));
        }
        Future<void> pump(Widget child) async {
          await tester.pumpWidget(CupertinoApp(
              home: GlassPreference(
                  enabled: enabled, child: Center(child: child))));
          await tester.pump();
          expect(find.byType(UiKitView), findsNothing);
          expect(tester.takeException(), isNull);
        }

        await pump(const LiquidGlassSurface(
            enabled: true, child: SizedBox(width: 160, height: 40)));
        expect(find.byType(GlassContainer),
            enabled ? findsOneWidget : findsNothing);
        var selected = -1;
        var searched = false;
        await pump(LiquidGlassTabBar(
          items: const [
            BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.home), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.star), label: 'Favorites')
          ],
          onTap: (value) => selected = value,
          onSearch: () => searched = true,
          searchLabel: 'Search',
        ));
        expect(
            find.byType(GlassTabBar), enabled ? findsOneWidget : findsNothing);
        await tester.tap(find.text('Favorites').first);
        expect(selected, 1);
        if (enabled) {
          await tester.tap(find.byIcon(CupertinoIcons.search));
          expect(searched, isTrue);
        }
        var tapped = false;
        var held = false;
        final items = [
          LiquidGlassRailCategory(title: 'First', onTap: () {}),
          LiquidGlassRailCategory(
              title: 'Second',
              onTap: () => tapped = true,
              onLongPress: () => held = true)
        ];
        await pump(SegmentedRail(items: items, selectedIndex: 0));
        expect(find.byType(GlassContainer),
            enabled ? findsOneWidget : findsNothing);
        await tester.tap(find.text('Second'));
        await tester.longPress(find.text('Second'));
        expect(tapped, isTrue);
        expect(held, isTrue);
        await pump(NativeCategoryRail(
            categories: items,
            selectedIndex: 0,
            followSystemTransparency: true,
            brightness: Brightness.light,
            fontSize: 15,
            layout: LiquidGlassTopBarLayout.inline,
            initialOffset: 0,
            onOffset: (_) {},
            opacity: 1,
            interactive: true));
        expect(find.byType(GlassContainer),
            enabled ? findsOneWidget : findsNothing);
        await pump(EhActionSheet(
            glassEnabled: enabled,
            title: const Text('Title'),
            actions: [
              CupertinoActionSheetAction(
                  onPressed: () {}, child: const Text('Action'))
            ]));
        expect(find.byType(GlassContainer),
            enabled ? findsOneWidget : findsNothing);
        expect(calls, isEmpty);
      });
    }
  }
  testWidgets('nested surfaces share one refractive panel', (tester) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(const CupertinoApp(
        home: Center(
            child: LiquidGlassSurface(
                enabled: true,
                child: LiquidGlassSurface(
                    enabled: true, child: SizedBox(width: 100, height: 40))))));
    expect(find.byType(GlassContainer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('high contrast popup uses an opaque surface without shader blur',
      (tester) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(const CupertinoApp(
        home: MediaQuery(
            data: MediaQueryData(highContrast: true),
            child: LiquidGlassPopupSurface(
                enabled: true, child: Text('Readable')))));
    expect(find.byType(GlassContainer), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('Readable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('shader initialization failure retains lightweight blur renderer',
      (tester) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
    FlutterGlassRuntime.debugAvailable = false;
    await tester.pumpWidget(const CupertinoApp(
        home: LiquidGlassSurface(
            enabled: true, child: SizedBox(width: 100, height: 40))));
    expect(find.byType(GlassContainer), findsNothing);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(UiKitView), findsNothing);
  });
}
