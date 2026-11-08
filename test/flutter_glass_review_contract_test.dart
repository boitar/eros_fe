import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:eros_fe/widget/segmented_rail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class _Settings extends GetxService implements EhSettingService {
  final RxBool _glass = false.obs;
  @override
  bool get liquidGlass => _glass.value;
  @override
  set liquidGlass(bool value) => _glass.value = value;
  @override
  bool get isPureDarkTheme => false;
  @override
  bool get liquidGlassMaterial => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  tearDown(() {
    PlatformCapabilities.debugHostPlatformOverride = null;
    SettingGlassBar.debugActive = null;
    Get.reset();
  });
  for (final host in [
    TargetPlatform.android,
    TargetPlatform.macOS,
    TargetPlatform.windows
  ]) {
    testWidgets(
        '$host settings bar follows the actual preference in both directions',
        (tester) async {
      PlatformCapabilities.debugHostPlatformOverride = host;
      final settings = Get.put<EhSettingService>(_Settings());
      final nativeCalls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      for (final name in [
        'flutter/platform_views',
        'eros/accessibility-settings'
      ]) {
        messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
          nativeCalls.add('$name/${call.method}');
          return null;
        });
        addTearDown(() =>
            messenger.setMockMethodCallHandler(MethodChannel(name), null));
      }
      await tester.pumpWidget(const CupertinoApp(
          home: SettingScaffold(
              title: 'Settings', nativeChrome: false, child: SizedBox())));
      for (final enabled in [false, true, false]) {
        settings.liquidGlass = enabled;
        await tester.pumpAndSettle();
        expect(SettingGlassBar.isActive, enabled);
        expect(find.byType(SettingGlassBar),
            enabled ? findsOneWidget : findsNothing);
        // Off iOS the bar is only the soft scroll edge: no glass slab.
        expect(find.byType(GlassContainer), findsNothing);
        expect(find.byType(CupertinoNavigationBar),
            enabled ? findsNothing : findsOneWidget);
        expect(find.byType(UiKitView), findsNothing);
        expect(tester.takeException(), isNull);
      }
      expect(nativeCalls, isEmpty);
    });
    testWidgets(
        '$host CategoryRail retains disabled interaction and horizontal offset',
        (tester) async {
      PlatformCapabilities.debugHostPlatformOverride = host;
      var taps = 0;
      var holds = 0;
      final offsets = <double>[];
      final items = List.generate(
          20,
          (index) => LiquidGlassRailCategory(
              title: 'Category $index long',
              onTap: () => taps++,
              onLongPress: () => holds++));
      Future<void> pump(
          {required bool interactive, double initialOffset = 80}) async {
        await tester.pumpWidget(CupertinoApp(
            home: Center(
                child: SizedBox(
                    width: 320,
                    height: 52,
                    child: NativeCategoryRail(
                        categories: items,
                        selectedIndex: 0,
                        followSystemTransparency: true,
                        brightness: Brightness.light,
                        fontSize: 15,
                        layout: LiquidGlassTopBarLayout.inline,
                        initialOffset: initialOffset,
                        onOffset: offsets.add,
                        opacity: 1,
                        interactive: interactive)))));
        await tester.pump();
      }

      ScrollController controller() => tester
          .widgetList<SingleChildScrollView>(find.descendant(
              of: find.byType(SegmentedRail),
              matching: find.byType(SingleChildScrollView)))
          .single
          .controller!;
      await pump(interactive: false);
      expect(controller().offset, closeTo(80, .01));
      expect(offsets.last, closeTo(80, .01));
      final segment = find.byKey(const ValueKey('segmented-rail-segment-0'));
      await tester.tap(segment, warnIfMissed: false);
      await tester.longPress(segment, warnIfMissed: false);
      await tester.drag(find.byType(SegmentedRail), const Offset(-100, 0),
          warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(taps, 0);
      expect(holds, 0);
      expect(controller().offset, closeTo(80, .01));
      await pump(interactive: true);
      await tester.tap(segment);
      await tester.longPress(segment);
      expect(taps, 1);
      expect(holds, 1);
      await tester.drag(find.byType(SegmentedRail), const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(controller().offset, greaterThan(80));
      expect(offsets.last, closeTo(controller().offset, .01));
      await pump(interactive: true, initialOffset: 140);
      expect(controller().offset, closeTo(140, .01));
      expect(offsets.last, closeTo(140, .01));
      expect(find.byType(UiKitView), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
