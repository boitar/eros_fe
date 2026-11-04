import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:eros_fe/widget/segmented_rail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Settings extends GetxService implements EhSettingService {
  _Settings(this.liquidGlass);
  @override
  final bool liquidGlass;
  @override
  bool get isPureDarkTheme => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  tearDown(() async => Get.reset());
  for (final host in [
    TargetPlatform.android,
    TargetPlatform.macOS,
    TargetPlatform.windows
  ]) {
    for (final enabled in [true, false]) {
      testWidgets(
          '$host with iOS theme, glass=$enabled never invokes native glass',
          (tester) async {
        Get.put<EhSettingService>(_Settings(enabled));
        expect(Get.isRegistered<EhSettingService>(), isTrue);
        var actionCalls = 0;
        PlatformCapabilities.debugHostPlatformOverride = host;
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final calls = <String>[];
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        for (final name in [
          'flutter/platform_views',
          'eros/accessibility-settings'
        ]) {
          messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
            calls.add('$name/${call.method}');
            return null;
          });
          addTearDown(() =>
              messenger.setMockMethodCallHandler(MethodChannel(name), null));
        }
        final categories = [
          LiquidGlassRailCategory(title: 'Category', onTap: () {})
        ];
        final widgets = <Widget>[
          const LiquidGlassSurface(
              enabled: true, child: SizedBox(width: 100, height: 40)),
          LiquidGlassTabBar(items: const [
            BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.home), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.star), label: 'Favorites')
          ], nativeItems: const [
            LiquidGlassTabItem(
                label: 'Home', codePoint: 0, fallbackSymbol: 'house')
          ]),
          NativeCategoryRail(
              categories: categories,
              selectedIndex: 0,
              followSystemTransparency: true,
              brightness: Brightness.light,
              fontSize: 15,
              layout: LiquidGlassTopBarLayout.twoRow,
              initialOffset: 0,
              onOffset: (_) {},
              opacity: 1,
              interactive: true),
          SegmentedRail(items: categories, selectedIndex: 0),
          LiquidGlassRail(
              title: 'Title',
              safeTop: 0,
              fadeProgress: 0,
              selectedIndex: 0,
              categories: categories),
          EhActionSheet(title: const Text('Title'), actions: [
            CupertinoActionSheetAction(
                onPressed: () {
                  actionCalls++;
                },
                child: const Text('Action'))
          ]),
          const LiquidGlassPopupSurface(child: Text('Popup')),
          const SettingScaffold(
              title: 'Settings', nativeChrome: false, child: SizedBox()),
        ];
        for (final widget in widgets) {
          await tester.pumpWidget(CupertinoApp(home: Center(child: widget)));
          await tester.pump();
          expect(find.byType(UiKitView), findsNothing,
              reason: '$host ${widget.runtimeType}');
          expect(tester.takeException(), isNull,
              reason: '$host ${widget.runtimeType}');
          if (widget is EhActionSheet) {
            expect(find.byType(LiquidGlassPopupSurface),
                enabled ? findsOneWidget : findsNothing);
            expect(find.byType(CupertinoActionSheet),
                enabled ? findsNothing : findsOneWidget);
            await tester.tap(find.text('Action'));
            expect(actionCalls, 1);
          }
        }
        LiquidGlassAccessibilitySettings.watch();
        var feedbackCalled = false;
        liquidGlassFeedback(() async {
          feedbackCalled = true;
        });
        expect(feedbackCalled, isFalse);
        expect(calls, isEmpty);
        expect(SettingGlassBar.isActive, isFalse);
        expect(liquidGlassPopupsEnabled, enabled);
        debugDefaultTargetPlatformOverride = null;
      });
    }
  }
  testWidgets('iOS capability survives Android theme override', (tester) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.iOS;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(PlatformCapabilities.nativeGlassBackend, NativeGlassBackend.uiKit);
    expect(GlassMode.resolve(enabled: true), GlassMode.native);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        SystemChannels.platform_views, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(
        SystemChannels.platform_views, null));
    for (var id = 0; id < 32; id++) {
      for (final kind in ['categories', 'tab-bar', 'popup']) {
        final channel = MethodChannel('eros/liquid-glass-$kind/$id');
        messenger.setMockMethodCallHandler(channel, (_) async => null);
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      }
    }
    final categories = [
      LiquidGlassRailCategory(title: 'Category', onTap: () {})
    ];
    final widgets = <Widget>[
      const SizedBox(
          width: 100, height: 40, child: LiquidGlassSurface(enabled: true)),
      LiquidGlassTabBar(items: const [
        BottomNavigationBarItem(icon: Icon(CupertinoIcons.home)),
        BottomNavigationBarItem(icon: Icon(CupertinoIcons.star))
      ], nativeItems: const [
        LiquidGlassTabItem(
            label: 'Home', codePoint: 0, fallbackSymbol: 'house'),
        LiquidGlassTabItem(
            label: 'Favorites', codePoint: 0, fallbackSymbol: 'star')
      ]),
      NativeCategoryRail(
          categories: categories,
          selectedIndex: 0,
          followSystemTransparency: true,
          brightness: Brightness.light,
          fontSize: 15,
          layout: LiquidGlassTopBarLayout.twoRow,
          initialOffset: 0,
          onOffset: (_) {},
          opacity: 1,
          interactive: true),
      SegmentedRail(items: categories, selectedIndex: 0),
      EhActionSheet(glassEnabled: true, title: const Text('Title'), actions: [
        CupertinoActionSheetAction(
            onPressed: () {}, child: const Text('Action'))
      ]),
    ];
    for (final widget in widgets) {
      await tester.pumpWidget(CupertinoApp(home: Center(child: widget)));
      expect(find.byType(UiKitView), findsWidgets,
          reason: '${widget.runtimeType}');
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.macOS,
    TargetPlatform.windows
  ]) {
    testWidgets('$platform surface uses Flutter without platform views',
        (tester) async {
      PlatformCapabilities.debugHostPlatformOverride = platform;
      debugDefaultTargetPlatformOverride = platform;
      await tester.pumpWidget(const CupertinoApp(
          home: LiquidGlassSurface(
              enabled: true, child: SizedBox(width: 100, height: 50))));
      expect(find.byType(UiKitView), findsNothing);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  }
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    PlatformCapabilities.debugHostPlatformOverride = null;
  });
  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.macOS,
    TargetPlatform.windows
  ]) {
    testWidgets(
        '$platform resolves preference and incomplete component fallback',
        (tester) async {
      PlatformCapabilities.debugHostPlatformOverride = platform;
      debugDefaultTargetPlatformOverride = platform;
      final expected =
          platform == TargetPlatform.iOS ? GlassMode.native : GlassMode.flutter;
      await tester.pumpWidget(GlassPreference(
          enabled: true,
          child: Builder(builder: (context) {
            expect(GlassMode.of(context), expected);
            expect(
                GlassMode.of(context).forComponent(),
                platform == TargetPlatform.iOS
                    ? GlassMode.native
                    : GlassMode.off);
            expect(GlassMode.of(context).forComponent(flutterImplemented: true),
                expected);
            expect(GlassMode.of(context, enabled: false), GlassMode.off);
            expect(GlassMode.of(context, performanceAllowsGlass: false),
                GlassMode.off);
            return const SizedBox();
          })));
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
