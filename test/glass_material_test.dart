import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/flutter_glass.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:eros_fe/widget/segmented_rail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// The bottom bar used to refract while every other Flutter-drawn surface
/// (the top search capsule, round buttons, category rail, popups) drew the
/// lightweight frosted shader. One material now drives them all.
void main() {
  tearDown(() {
    PlatformCapabilities.debugHostPlatformOverride = null;
    FlutterGlassRuntime.debugAvailable = null;
  });

  test('materials map to the refractive or the frosted shader', () {
    expect(GlassMaterial.liquid.quality, GlassQuality.premium);
    expect(GlassMaterial.frosted.quality, GlassQuality.standard);
    for (final material in GlassMaterial.values) {
      final theme = FlutterGlassRuntime.themeFor(material);
      expect(theme.light.quality, material.quality);
      expect(theme.dark.quality, material.quality);
      // Only the quality changes; the optics stay the package defaults.
      expect(theme.light.settings, GlassThemeVariant.light.settings);
      expect(theme.dark.settings, GlassThemeVariant.dark.settings);
    }
  });

  for (final host in [TargetPlatform.android, TargetPlatform.windows]) {
    for (final material in GlassMaterial.values) {
      testWidgets('$host $material reaches every Flutter glass surface',
          (tester) async {
        PlatformCapabilities.debugHostPlatformOverride = host;
        FlutterGlassRuntime.debugAvailable = true;
        Future<void> pump(Widget child) async {
          await tester.pumpWidget(CupertinoApp(
              home: FlutterGlassRuntime.wrap(Center(child: child),
                  material: material)));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }

        Iterable<GlassQuality?> containerQualities() => tester
            .widgetList<GlassContainer>(find.byType(GlassContainer))
            .map((container) => container.quality);

        // Top bar capsules and round buttons.
        await pump(const LiquidGlassSurface(
            enabled: true, child: SizedBox(width: 160, height: 40)));
        expect(containerQualities(), [material.quality]);

        // Category rail.
        await pump(SegmentedRail(items: [
          LiquidGlassRailCategory(title: 'First', onTap: () {}),
          LiquidGlassRailCategory(title: 'Second', onTap: () {}),
        ], selectedIndex: 0));
        expect(containerQualities(), [material.quality]);

        // Popups and menus.
        await pump(const LiquidGlassPopupSurface(
            enabled: true, child: SizedBox(width: 120, height: 80)));
        expect(containerQualities(), [material.quality]);

        // Bottom tab bar.
        await pump(LiquidGlassTabBar(
          items: const [
            BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.home), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.star), label: 'Favorites'),
          ],
          onSearch: () {},
        ));
        expect(tester.widget<GlassTabBar>(find.byType(GlassTabBar)).quality,
            material.quality);
      });
    }
  }

  testWidgets('a surface without a preference keeps Liquid Glass',
      (tester) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(const CupertinoApp(
        home: Center(
            child: LiquidGlassSurface(
                enabled: true, child: SizedBox(width: 100, height: 40)))));
    expect(tester.widget<GlassContainer>(find.byType(GlassContainer)).quality,
        GlassQuality.premium);
  });

  testWidgets('switching the material rebuilds mounted surfaces',
      (tester) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
    final material = ValueNotifier(GlassMaterial.liquid);
    addTearDown(material.dispose);
    await tester.pumpWidget(CupertinoApp(
        home: ValueListenableBuilder<GlassMaterial>(
            valueListenable: material,
            builder: (context, value, _) => GlassPreference(
                enabled: true,
                material: value,
                child: const Center(
                    child: LiquidGlassSurface(
                        enabled: true,
                        child: SizedBox(width: 100, height: 40)))))));
    GlassQuality? quality() =>
        tester.widget<GlassContainer>(find.byType(GlassContainer)).quality;
    expect(quality(), GlassQuality.premium);
    material.value = GlassMaterial.frosted;
    await tester.pump();
    expect(quality(), GlassQuality.standard);
    material.value = GlassMaterial.liquid;
    await tester.pump();
    expect(quality(), GlassQuality.premium);
  });

  testWidgets('switching the material keeps the category rail scrolled',
      (tester) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
    FlutterGlassRuntime.debugAvailable = true;
    final material = ValueNotifier(GlassMaterial.liquid);
    addTearDown(material.dispose);
    final items = [
      for (var i = 0; i < 16; i++)
        LiquidGlassRailCategory(title: 'Category $i', onTap: () {}),
    ];
    await tester.pumpWidget(CupertinoApp(
        home: ValueListenableBuilder<GlassMaterial>(
            valueListenable: material,
            builder: (context, value, _) => GlassPreference(
                enabled: true,
                material: value,
                child: Center(
                    child: SizedBox(
                        width: 360,
                        child: SegmentedRail(
                            items: items, selectedIndex: 12)))))));
    await tester.pump();
    double offset() => tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    await tester.drag(find.byType(SingleChildScrollView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    final scrolled = offset();
    expect(scrolled, greaterThan(100));
    // The test renderer has no Impeller shaders, so premium falls back to the
    // same subtree as standard here. On a device the two differ, and only the
    // GlobalKey around the content carries the scroll view across.
    expect(
        find.ancestor(
            of: find.byType(SingleChildScrollView),
            matching: find.byWidgetPredicate(
                (widget) => widget is KeyedSubtree && widget.key is GlobalKey)),
        findsOneWidget);
    material.value = GlassMaterial.frosted;
    await tester.pumpAndSettle();
    expect(offset(), scrolled);
    material.value = GlassMaterial.liquid;
    await tester.pumpAndSettle();
    expect(offset(), scrolled);
    expect(tester.takeException(), isNull);
  });
}
