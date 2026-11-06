import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/pages/image_view/view/reader_chrome.dart';
import 'package:eros_fe/pages/image_view/view/reader_layout.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

const _phone = AdaptiveEnvironmentSnapshot(
  size: Size(412, 915),
  safeArea: EdgeInsets.only(top: 24, bottom: 24),
);

Widget _layout({required bool showBars, bool glass = true}) => CupertinoApp(
      home: MediaQuery(
        data: MediaQueryData(size: _phone.size, padding: _phone.safeArea),
        child: ReaderSurfaceLayout(
          environment: _phone,
          content: const SizedBox.expand(key: ValueKey('page')),
          topBar: const SizedBox(key: ValueKey('top'), height: 56),
          bottomBar: const SizedBox(key: ValueKey('bottom'), height: 120),
          showBars: showBars,
          topBarHeight: 56,
          bottomBarHeight: 120,
          glassChrome: glass,
        ),
      ),
    );

void main() {
  testWidgets('glass chrome floats without the blurred slab', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = _phone.size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_layout(showBars: true));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderChromeBackground), findsNothing);
    expect(find.byKey(const ValueKey('top')), findsOneWidget);
    expect(find.byKey(const ValueKey('bottom')), findsOneWidget);
    // The page itself still fills the whole screen behind the controls.
    expect(tester.getSize(find.byKey(const ValueKey('page'))).height,
        greaterThanOrEqualTo(_phone.size.height - 48));

    await tester.pumpWidget(_layout(showBars: true, glass: false));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderChromeBackground), findsOneWidget);
  });

  testWidgets('hidden glass controls fade out and leave the tree',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = _phone.size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_layout(showBars: true));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_layout(showBars: false));
    // Mid-fade the controls are still drawn but take no input.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('top')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('top')), findsNothing);
    expect(find.byKey(const ValueKey('bottom')), findsNothing);

    await tester.pumpWidget(_layout(showBars: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('top')), findsOneWidget);
  });

  testWidgets('only Android with glass on uses the glass reader',
      (tester) async {
    addTearDown(() => PlatformCapabilities.debugHostPlatformOverride = null);
    for (final host in [
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    ]) {
      for (final enabled in [true, false]) {
        PlatformCapabilities.debugHostPlatformOverride = host;
        bool? glass;
        await tester.pumpWidget(GlassPreference(
          enabled: enabled,
          child: CupertinoApp(
            home: Builder(builder: (context) {
              glass = usesGlassReaderChrome(context);
              return const SizedBox();
            }),
          ),
        ));
        expect(glass, enabled && host == TargetPlatform.android,
            reason: '$host glass=$enabled');
      }
    }
  });

  test('glass bottom height covers the toolbar only on narrow screens', () {
    final narrow =
        ReaderGlassBottomBar.heightFor(thumbnails: false, wide: false);
    final wide = ReaderGlassBottomBar.heightFor(thumbnails: false, wide: true);
    final thumbs =
        ReaderGlassBottomBar.heightFor(thumbnails: true, wide: false);
    expect(narrow - wide,
        ReaderGlassBottomBar.gap + ReaderGlassBottomBar.toolbarHeight);
    expect(thumbs - narrow,
        greaterThan(ReaderGlassBottomBar.sliderHeight));
  });
}
