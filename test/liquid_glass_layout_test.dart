import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('landscape retains the window top safe area without cutout docking', () {
    for (final top in [0.0, 24.0, 59.0]) {
      final layout = LiquidGlassTopLayout.fromMediaQuery(MediaQueryData(
        size: const Size(1194, 834),
        viewPadding: EdgeInsets.only(top: top, left: 24, bottom: 20),
      ));
      expect(layout.safeTop, top);
      expect(layout.cutout, LiquidGlassCutout.none);
      expect(layout.canDockTopRail, isFalse);
    }
  });

  test('classifies dynamic-island, notch, and unobstructed top insets', () {
    expect(
      LiquidGlassTopLayout.fromTopInset(59).cutout,
      LiquidGlassCutout.dynamicIsland,
    );
    expect(
      LiquidGlassTopLayout.fromTopInset(47).cutout,
      LiquidGlassCutout.notch,
    );
    expect(
      LiquidGlassTopLayout.fromTopInset(20).cutout,
      LiquidGlassCutout.none,
    );
    expect(LiquidGlassTopLayout.fromTopInset(20).canDockTopRail, isFalse);
    expect(LiquidGlassTopLayout.fromTopInset(47).canDockTopRail, isTrue);
    expect(LiquidGlassTopLayout.fromTopInset(double.nan).safeTop, 0);
  });

  test('docking geometry keeps the rail below the obstruction', () {
    final dynamicIsland = LiquidGlassTopLayout.fromTopInset(59);
    final notch = LiquidGlassTopLayout.fromTopInset(47);

    expect(dynamicIsland.dockingTranslation, 22);
    expect(notch.dockingTranslation, 3);
    expect(dynamicIsland.collapsedHeaderHeight, 59);
    expect(notch.collapsedHeaderHeight, 47);
  });

  test('collapse progress is clamped to the sliver range', () {
    final layout = LiquidGlassTopLayout.fromTopInset(59);

    expect(layout.collapseProgress(-10, 100), 0);
    expect(layout.collapseProgress(50, 100), 0.5);
    expect(layout.collapseProgress(120, 100), 1);
    expect(layout.collapseProgress(10, 0), 0);
  });

  test('both layouts share scaled geometry and default parsing', () {
    expect(LiquidGlassTopBarLayout.parse(null), LiquidGlassTopBarLayout.twoRow);
    expect(LiquidGlassTopBarLayout.parse('unknown'),
        LiquidGlassTopBarLayout.twoRow);
    expect(LiquidGlassTopBarLayout.parse('inline'),
        LiquidGlassTopBarLayout.inline);
    expect(LiquidGlassTopBarLayout.twoRow.expandedHeight(TextScaler.noScaling),
        94);
    expect(LiquidGlassTopBarLayout.inline.expandedHeight(TextScaler.noScaling),
        44);
    expect(
        LiquidGlassTopBarLayout.twoRow
            .expandedHeight(const TextScaler.linear(3)),
        120);
  });
}
