import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdaptiveEnvironmentSnapshot', () {
    test('classifies usable rather than full-window aspect ratio', () {
      const snapshot = AdaptiveEnvironmentSnapshot(
        size: Size(800, 750),
        safeArea: EdgeInsets.only(right: 100),
      );
      expect(snapshot.layoutKind, AdaptiveLayoutKind.expandedGrid);
    });

    test('does not squeeze an undersized reserved pane into split layout', () {
      const snapshot = AdaptiveEnvironmentSnapshot(
        size: Size(960, 650),
        reservedRegions: [
          AdaptiveRegion(
            frame: Rect.fromLTWH(290, 0, 24, 650),
            kind: AdaptiveRegionKind.division,
          ),
        ],
      );
      expect(snapshot.isSplit, isFalse);
      expect(snapshot.canUseReaderDoublePage, isFalse);
    });

    test('ignores inactive and off-window division regions', () {
      const snapshot = AdaptiveEnvironmentSnapshot(
        size: Size(900, 650),
        reservedRegions: [
          AdaptiveRegion(
            frame: Rect.fromLTWH(0, 800, 900, 24),
            kind: AdaptiveRegionKind.division,
          ),
          AdaptiveRegion(
            frame: Rect.fromLTWH(420, 0, 24, 650),
            kind: AdaptiveRegionKind.division,
            active: false,
          ),
        ],
      );
      expect(snapshot.isTabletop, isFalse);
      expect(snapshot.isBookFolded, isFalse);
      expect(snapshot.paneRects, [snapshot.contentRect]);
      expect(snapshot.isSplit, isTrue);
    });

    test('flat zero-area and invalid regions never create phantom folds', () {
      for (final frame in [
        const Rect.fromLTWH(0, 450, 669, 0),
        const Rect.fromLTWH(330, 0, 0, 951),
        const Rect.fromLTWH(330, 0, -1, 951),
        const Rect.fromLTWH(double.nan, 0, 24, 951),
        const Rect.fromLTWH(0, 450, double.infinity, 24),
      ]) {
        final snapshot = AdaptiveEnvironmentSnapshot(
          size: const Size(669, 951),
          reservedRegions: [
            AdaptiveRegion(frame: frame, kind: AdaptiveRegionKind.division),
            AdaptiveRegion(frame: frame, kind: AdaptiveRegionKind.occlusion),
          ],
        );
        expect(snapshot.layoutKind, AdaptiveLayoutKind.expandedGrid);
        expect(snapshot.isBookFolded, isFalse);
        expect(snapshot.activeOcclusionRegions, isEmpty);
        expect(snapshot.paneRects, [snapshot.contentRect]);
      }
    });

    test('projects pane-local coordinates without double safe-area insets', () {
      const snapshot = AdaptiveEnvironmentSnapshot(
        size: Size(900, 700),
        safeArea: EdgeInsets.fromLTRB(12, 20, 84, 16),
        reservedRegions: [
          AdaptiveRegion(
            frame: Rect.fromLTWH(420, 0, 24, 700),
            kind: AdaptiveRegionKind.division,
          ),
          AdaptiveRegion(
            frame: Rect.fromLTWH(760, 20, 20, 20),
            kind: AdaptiveRegionKind.occlusion,
          ),
        ],
      );
      final pane = snapshot.inRect(const Rect.fromLTWH(444, 0, 372, 700));
      expect(pane.safeArea, const EdgeInsets.only(top: 20, bottom: 16));
      expect(pane.activeDivisionRegions, isEmpty);
      expect(pane.activeOcclusionRegions.single.frame,
          const Rect.fromLTWH(316, 20, 20, 20));
    });

    test('tabletop uses reliable horizontal panes, not hinge angles', () {
      const snapshot = AdaptiveEnvironmentSnapshot(
        size: Size(900, 700),
        reservedRegions: [
          AdaptiveRegion(
            frame: Rect.fromLTWH(0, 310, 900, 32),
            kind: AdaptiveRegionKind.division,
          ),
        ],
      );
      expect(snapshot.isTabletop, isTrue);
      expect(snapshot.paneRects.first.bottom, 310);
      expect(snapshot.paneRects.last.top, 342);
      expect(snapshot.canUseReaderDoublePage, isTrue);
    });

    test('control avoidance does not apply reserved margins twice', () {
      const snapshot = AdaptiveEnvironmentSnapshot(
        size: Size(900, 700),
        reservedRegions: [
          AdaptiveRegion(
            frame: Rect.fromLTWH(800, 0, 100, 80),
            kind: AdaptiveRegionKind.occlusion,
          ),
        ],
      );
      final rect =
          snapshot.unoccludedControlRect(const Rect.fromLTWH(0, 0, 900, 56));
      expect(rect, const Rect.fromLTWH(0, 0, 800, 56));
    });
    test('uses available width instead of device idiom', () {
      const compact = AdaptiveEnvironmentSnapshot(size: Size(390, 844));
      const innerPortrait = AdaptiveEnvironmentSnapshot(size: Size(669, 772));
      const innerLandscape = AdaptiveEnvironmentSnapshot(size: Size(867, 669));

      expect(compact.layoutKind, AdaptiveLayoutKind.compact);
      expect(innerPortrait.layoutKind, AdaptiveLayoutKind.expandedGrid);
      expect(innerPortrait.canUseReaderDoublePage, isTrue);
      expect(innerLandscape.layoutKind, AdaptiveLayoutKind.split);
      expect(innerLandscape.canUseReaderDoublePage, isTrue);
    });

    test('keeps asymmetric safe-area edges and splits around a fold', () {
      const snapshot = AdaptiveEnvironmentSnapshot(
        size: Size(867, 669),
        safeArea: EdgeInsets.only(right: 84),
        reservedRegions: <AdaptiveRegion>[
          AdaptiveRegion(
            frame: Rect.fromLTWH(421, 0, 25, 669),
            kind: AdaptiveRegionKind.division,
          ),
        ],
      );

      expect(snapshot.contentRect.right, 783);
      expect(snapshot.paneRects, hasLength(2));
      expect(snapshot.paneRects[0].width, 421);
      expect(snapshot.paneRects[1].left, 446);
      expect(snapshot.isBookFolded, isTrue);
    });

    test('drops stale native regions after a live resize', () {
      const snapshot = AdaptiveEnvironmentSnapshot(
        size: Size(867, 669),
        reservedRegions: <AdaptiveRegion>[
          AdaptiveRegion(
            frame: Rect.fromLTWH(421, 0, 25, 669),
            kind: AdaptiveRegionKind.division,
          ),
        ],
      );

      final resized = snapshot.copyWithGeometry(size: const Size(390, 844));
      expect(resized.reservedRegions, isEmpty);
    });
  });

  test('rejects non-geometry and out-of-order native publications', () {
    final service = AdaptiveEnvironmentService();
    service.acceptNativeSnapshot({
      'width': 900,
      'height': 700,
      'layoutVersion': 9,
    });
    service.acceptNativeSnapshot({'navigationState': {}});
    service.acceptNativeSnapshot({
      'width': 390,
      'height': 844,
      'layoutVersion': 8,
    });
    expect(service.snapshot.value.size, const Size(900, 700));
    expect(service.snapshot.value.layoutVersion, 9);
  });

  test('serialises native navigation state without owning a route stack', () {
    const state = NativeNavigationState(
      tabId: '/gallery',
      selectedTabId: '/gallery',
      title: 'Gallery',
      tabs: <NativeNavigationTab>[
        NativeNavigationTab(
          id: '/gallery',
          title: 'Gallery',
          symbol: 'square.grid.2x2.fill',
        ),
      ],
      canGoBack: true,
      actions: <NativeNavigationAction>[
        NativeNavigationAction(
          id: 'search',
          title: 'Search',
          symbol: 'magnifyingglass',
        ),
      ],
    );

    expect(state.toMap()['canGoBack'], isTrue);
    expect(state.toMap()['tabs'], hasLength(1));
    final actions = state.toMap()['actions'] as List<Object>;
    expect(actions.single, containsPair('id', 'search'));
  });

  test('stable safe area ignores app bars but follows the window', () {
    final native = AdaptiveEnvironmentSnapshot.fromMap(const {
      'width': 900.0,
      'height': 640.0,
      'safeLeft': 0.0,
      'safeTop': 0.0,
      'safeRight': 0.0,
      'safeBottom': 0.0,
      'windowSafeLeft': 0.0,
      'windowSafeTop': 0.0,
      'windowSafeRight': 62.0,
      'windowSafeBottom': 20.0,
      'layoutVersion': 3,
    });
    expect(native.windowSafeArea, const EdgeInsets.fromLTRB(0, 0, 62, 20));
    expect(native.toMap()['windowSafeRight'], 62);
    // Reader bars visible: the vertical bar widens the live inset.
    final shown = native.copyWithGeometry(
        safeArea: const EdgeInsets.fromLTRB(0, 0, 118, 20));
    expect(shown.stableSafeArea, const EdgeInsets.fromLTRB(0, 0, 62, 20));
    // Immersive: nothing may exceed what the view reports.
    final hidden = native.copyWithGeometry(safeArea: EdgeInsets.zero);
    expect(hidden.stableSafeArea, EdgeInsets.zero);
    // Without the bridge the live inset is all there is.
    const flutterOnly = AdaptiveEnvironmentSnapshot(
        size: Size(400, 800), safeArea: EdgeInsets.only(top: 59));
    expect(flutterOnly.stableSafeArea, const EdgeInsets.only(top: 59));
    expect(shown.inRect(const Rect.fromLTWH(450, 0, 450, 640)).windowSafeArea,
        const EdgeInsets.fromLTRB(0, 0, 62, 20));
  });
}
