import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  test('category slots keep a fitting prefix and truncate only the last item',
      () {
    expect(
      LiquidGlassRail.visibleCategoryCount(
        preferredWidths: <double>[40, 40, 40, 40],
        availableWidth: 280,
      ),
      4,
    );
    expect(
      LiquidGlassRail.visibleCategoryCount(
        preferredWidths: <double>[40, 40, 150, 40],
        availableWidth: 280,
      ),
      3,
    );
    expect(
      LiquidGlassRail.visibleCategoryCount(
        preferredWidths: <double>[120, 120, 40, 40],
        availableWidth: 280,
      ),
      2,
    );
  });
}
