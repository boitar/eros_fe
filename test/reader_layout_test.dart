import 'dart:ui' as ui;

import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/pages/image_view/common.dart';
import 'package:eros_fe/pages/image_view/view/reader_layout.dart';
import 'package:eros_fe/widget/scroll_edge_effect.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const left = ValueKey('left-image');
  const right = ValueKey('right-image');
  const book = AdaptiveEnvironmentSnapshot(
    size: Size(900, 700),
    safeArea: EdgeInsets.only(right: 60),
    reservedRegions: [
      AdaptiveRegion(
        frame: Rect.fromLTWH(400, 0, 32, 700),
        kind: AdaptiveRegionKind.division,
      ),
    ],
  );

  testWidgets('book pages fit independent asymmetric panes in either direction',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = book.size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final reverse in [false, true]) {
      await tester.pumpWidget(CupertinoApp(
        home: ReaderSpreadLayout(
          environment: book,
          reverse: reverse,
          pages: const [
            ReaderSpreadPage(
                slot: 0, aspectRatio: 0.7, child: SizedBox.expand(key: left)),
            ReaderSpreadPage(
                slot: 1, aspectRatio: 1.6, child: SizedBox.expand(key: right)),
          ],
        ),
      ));
      final leftRect = tester.getRect(find.byKey(left));
      final rightRect = tester.getRect(find.byKey(right));
      expect(
          leftRect.overlaps(book.activeDivisionRegions.single.frame), isFalse);
      expect(
          rightRect.overlaps(book.activeDivisionRegions.single.frame), isFalse);
      expect(leftRect.right <= 840 && rightRect.right <= 840, isTrue);
      expect(leftRect.center.dx < rightRect.center.dx, !reverse);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('a cover occupies only its own book side, never a duplicate',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = book.size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const CupertinoApp(
      home: ReaderSpreadLayout(
        environment: book,
        pages: [
          ReaderSpreadPage(
              slot: 1, aspectRatio: 0.7, child: SizedBox.expand(key: right)),
        ],
      ),
    ));
    expect(find.byKey(right), findsOneWidget);
    expect(tester.getRect(find.byKey(right)).left, greaterThan(432));
  });

  testWidgets('tabletop uses actual division for content and controls',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 700);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const environment = AdaptiveEnvironmentSnapshot(
      size: Size(900, 700),
      reservedRegions: [
        AdaptiveRegion(
          frame: Rect.fromLTWH(0, 310, 900, 32),
          kind: AdaptiveRegionKind.division,
        ),
      ],
    );
    const contentKey = ValueKey('reading-content');
    const topKey = ValueKey('reading-toolbar');
    const bottomKey = ValueKey('reading-progress');
    await tester.pumpWidget(const CupertinoApp(
      home: ReaderSurfaceLayout(
        environment: environment,
        content: SizedBox.expand(key: contentKey),
        topBar: SizedBox(height: 56, key: topKey),
        bottomBar: SizedBox(height: 204, key: bottomKey),
        showBars: false,
        topBarHeight: 56,
        bottomBarHeight: 204,
      ),
    ));
    expect(tester.getRect(find.byKey(contentKey)).bottom, 310);
    expect(tester.getRect(find.byKey(topKey)).top, greaterThanOrEqualTo(342));
    expect(
        tester.getRect(find.byKey(bottomKey)).top, greaterThanOrEqualTo(342));
    expect(find.byKey(bottomKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no tabletop is inferred without divisions; manual is explicit',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 700);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const contentKey = ValueKey('reading-content');
    for (final preference in [
      ReaderSurfacePreference.automatic,
      ReaderSurfacePreference.tabletop,
    ]) {
      await tester.pumpWidget(CupertinoApp(
        home: ReaderSurfaceLayout(
          environment: const AdaptiveEnvironmentSnapshot(size: Size(900, 700)),
          preference: preference,
          content: const SizedBox.expand(key: contentKey),
          topBar: const SizedBox(height: 56),
          bottomBar: const SizedBox(height: 204),
          showBars: false,
          topBarHeight: 56,
          bottomBarHeight: 204,
        ),
      ));
      expect(tester.getSize(find.byKey(contentKey)).height,
          preference == ReaderSurfacePreference.tabletop ? lessThan(700) : 700);
    }
  });

  testWidgets('fill screen ignores the safe area for images, not for bars',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 720);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const contentKey = ValueKey('reading-content');
    const topKey = ValueKey('reading-toolbar');
    const environment = AdaptiveEnvironmentSnapshot(
      size: Size(1024, 720),
      safeArea: EdgeInsets.fromLTRB(0, 24, 120, 20),
    );
    for (final fill in [false, true]) {
      await tester.pumpWidget(CupertinoApp(
        home: ReaderSurfaceLayout(
          environment: environment,
          fillScreen: fill,
          content: const SizedBox.expand(key: contentKey),
          topBar: const SizedBox(height: 56, key: topKey),
          bottomBar: const SizedBox(height: 120),
          showBars: true,
          topBarHeight: 56,
          bottomBarHeight: 120,
        ),
      ));
      expect(
        tester.getRect(find.byKey(contentKey)),
        fill
            ? const Rect.fromLTWH(0, 0, 1024, 720)
            : const Rect.fromLTRB(0, 24, 904, 700),
      );
      expect(tester.getRect(find.byKey(topKey)).top, 24);
      expect(tester.getRect(find.byKey(topKey)).right, lessThanOrEqualTo(904));
    }
  });

  testWidgets('full-screen chrome joins every safe edge without double tint',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundaryKey = GlobalKey();
    const contentKey = ValueKey('chrome-content');
    const topKey = ValueKey('chrome-top');
    const bottomKey = ValueKey('chrome-bottom');
    var taps = 0;
    for (final insets in [
      const EdgeInsets.fromLTRB(0, 0, 60, 24),
      const EdgeInsets.fromLTRB(60, 24, 0, 0),
      const EdgeInsets.fromLTRB(0, 44, 0, 24),
    ]) {
      for (final visible in [true, false]) {
        await tester.pumpWidget(CupertinoApp(
          home: RepaintBoundary(
            key: boundaryKey,
            child: ReaderSurfaceLayout(
              environment: AdaptiveEnvironmentSnapshot(
                  size: const Size(400, 300), safeArea: insets),
              fillScreen: true,
              showBars: visible,
              topBarHeight: 44,
              bottomBarHeight: 64,
              topBar: const SizedBox.expand(key: topKey),
              bottomBar: const SizedBox(height: 64, key: bottomKey),
              content: GestureDetector(
                key: contentKey,
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const ColoredBox(color: CupertinoColors.white),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byKey(contentKey)),
            const Rect.fromLTWH(0, 0, 400, 300));
        if (visible) {
          expect(tester.getRect(find.byKey(topKey)).top, insets.top);
          expect(tester.getRect(find.byKey(bottomKey)).bottom,
              300 - insets.bottom);
        }
        final image = await tester.runAsync(() async =>
            (boundaryKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage());
        final bytes = await tester.runAsync(
            () => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
        int red(int x, int y) => bytes!.getUint8((y * 400 + x) * 4);
        // All corners include the bar or an inset, sometimes both. They
        // must get one 50% material, never zero layers or two layers.
        for (final point in [(8, 8), (391, 8), (8, 291), (391, 291)]) {
          expect(red(point.$1, point.$2), closeTo(visible ? 127 : 255, 2));
        }
        expect(red(200, 150), 255, reason: 'the reading center stays clear');
        image!.dispose();
        final before = taps;
        await tester.tapAt(const Offset(391, 150));
        expect(taps, before + 1, reason: 'the edge material cannot eat taps');
        expect(tester.takeException(), isNull);
      }
    }
  });

  group('native chrome', () {
    const content = ValueKey('content');
    const dock = ValueKey('dock');
    // Duo outer display: the vertical bar adds 56pt beside the window inset.
    AdaptiveEnvironmentSnapshot duo({required bool barsShown}) =>
        AdaptiveEnvironmentSnapshot(
          size: const Size(900, 640),
          safeArea: EdgeInsets.only(right: barsShown ? 118 : 62, bottom: 20),
          windowSafeArea: const EdgeInsets.only(right: 62, bottom: 20),
        );

    Future<void> pump(WidgetTester tester, AdaptiveEnvironmentSnapshot env,
        {required bool showBars, bool fillScreen = false}) async {
      await tester.pumpWidget(CupertinoApp(
        home: ReaderSurfaceLayout(
          environment: env,
          nativeChrome: true,
          showBars: showBars,
          fillScreen: fillScreen,
          topBarHeight: 0,
          bottomBarHeight: 60,
          topBar: const SizedBox.shrink(),
          bottomBar:
              const SizedBox(key: dock, width: double.infinity, height: 60),
          content: const SizedBox.expand(key: content),
        ),
      ));
    }


    testWidgets('content stays put while the native bars come and go',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(tester, duo(barsShown: true), showBars: true);
      await tester.pumpAndSettle();
      final shown = tester.getRect(find.byKey(content));
      expect(shown, const Rect.fromLTRB(0, 0, 838, 620));
      expect(find.byType(ReaderChromeBackground), findsNothing);
      expect(find.byType(SoftScrollEdgeEffect), findsOneWidget);
      final dockShown = tester.getRect(find.byKey(dock));
      expect(dockShown.right, 900 - 118);

      await pump(tester, duo(barsShown: false), showBars: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getRect(find.byKey(content)), shown);
      // The fading dock keeps the geometry it was shown with.
      expect(tester.getRect(find.byKey(dock)).right, dockShown.right);
      await tester.pumpAndSettle();
      expect(find.byKey(dock), findsNothing);
      expect(find.byType(SoftScrollEdgeEffect), findsNothing);
    });

    testWidgets('filled images ignore every inset under native bars',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(tester, duo(barsShown: true),
          showBars: true, fillScreen: true);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(content)),
          const Rect.fromLTWH(0, 0, 900, 640));
    });

    testWidgets('a top inset adds a dark top edge for the navigation bar',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(402, 874);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(
        tester,
        const AdaptiveEnvironmentSnapshot(
          size: Size(402, 874),
          safeArea: EdgeInsets.only(top: 106, bottom: 83),
          windowSafeArea: EdgeInsets.only(top: 62, bottom: 34),
        ),
        showBars: true,
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(content)).top, 62);
      final edges = tester
          .widgetList<SoftScrollEdgeEffect>(find.byType(SoftScrollEdgeEffect))
          .toList();
      expect(edges.map((edge) => edge.edge),
          containsAll(<SoftEdge>[SoftEdge.top, SoftEdge.bottom]));
      expect(edges.every((edge) => edge.tone == SoftEdgeTone.media), isTrue);
    });
  });
}
