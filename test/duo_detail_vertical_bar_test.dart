import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/browse_layout.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/pages/gallery/view/sliver/gallery_hero.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'iPhone Duo vertical-bar split extends detail background under bar while keeping foreground in safe area',
      (tester) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => PlatformCapabilities.debugHostPlatformOverride = null);

    const windowSize = Size(1024, 720);
    const barInsets = EdgeInsets.only(right: 92);
    const env = AdaptiveEnvironmentSnapshot(
      size: windowSize,
      safeArea: barInsets,
      viewPadding: barInsets,
      systemBarEdge: 'right',
      duoVerticalBar: true,
      nativeSupported: true,
    );

    const bgKey = ValueKey<String>('detail-bg');
    const fgKey = ValueKey<String>('detail-fg');
    const primaryKey = ValueKey<String>('primary-pane');
    late MediaQueryData detailMedia;
    late AdaptiveEnvironmentSnapshot detailEnv;

    await tester.pumpWidget(
      CupertinoApp(
        home: AdaptiveBrowseLayout(
          environment: env,
          split: true,
          sideProportion: 0.5,
          detailActive: true,
          primary: const ColoredBox(
            key: primaryKey,
            color: CupertinoColors.systemGrey6,
          ),
          detail: Builder(
            builder: (context) {
              detailMedia = MediaQuery.of(context);
              detailEnv = AdaptiveEnvironment.of(context);
              return const Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ColoredBox(key: bgKey, color: CupertinoColors.systemBackground),
                  SafeArea(
                    child: SizedBox.expand(
                      key: fgKey,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final primaryRect = tester.getRect(find.byKey(primaryKey));
    final bgRect = tester.getRect(find.byKey(bgKey));
    final fgRect = tester.getRect(find.byKey(fgKey));

    // Primary split width is still computed from safe content width (1024 - 92 = 932).
    expect(primaryRect.left, 0);
    expect(primaryRect.right,
        closeTo(AdaptiveBrowseLayout.primaryPaneWidth(932, 0.5), 0.01));

    // Detail background extends seamlessly to window right edge (under vertical bar).
    expect(bgRect.left, closeTo(primaryRect.right + 1, 0.01));
    expect(bgRect.right, windowSize.width);

    // Local safe area keeps right padding so foreground content never enters the bar.
    expect(detailMedia.padding.right, 92);
    expect(detailEnv.safeArea.right, 92);
    expect(fgRect.left, closeTo(bgRect.left, 0.01));
    expect(fgRect.right, windowSize.width - 92);
  });

  testWidgets(
      'non-Duo iOS and other platforms keep detail clipped inside safeArea.right',
      (tester) async {
    const windowSize = Size(1024, 720);
    const barInsets = EdgeInsets.only(right: 92);
    const bgKey = ValueKey<String>('detail-bg');

    for (final testCase in <({
      TargetPlatform platform,
      bool duoVerticalBar,
      String? barEdge,
    })>[
      (
        platform: TargetPlatform.iOS,
        duoVerticalBar: false,
        barEdge: 'right',
      ),
      (
        platform: TargetPlatform.iOS,
        duoVerticalBar: false,
        barEdge: 'top',
      ),
      (
        platform: TargetPlatform.android,
        duoVerticalBar: true,
        barEdge: 'right',
      ),
      (
        platform: TargetPlatform.macOS,
        duoVerticalBar: true,
        barEdge: 'right',
      ),
      (
        platform: TargetPlatform.windows,
        duoVerticalBar: true,
        barEdge: 'right',
      ),
    ]) {
      PlatformCapabilities.debugHostPlatformOverride = testCase.platform;
      final env = AdaptiveEnvironmentSnapshot(
        size: windowSize,
        safeArea: barInsets,
        viewPadding: barInsets,
        systemBarEdge: testCase.barEdge,
        duoVerticalBar: testCase.duoVerticalBar,
        nativeSupported: testCase.platform == TargetPlatform.iOS,
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: AdaptiveBrowseLayout(
            environment: env,
            split: true,
            sideProportion: 0.5,
            detailActive: true,
            primary: const SizedBox.expand(),
            detail: const ColoredBox(
              key: bgKey,
              color: CupertinoColors.systemBackground,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bgRect = tester.getRect(find.byKey(bgKey));
      expect(bgRect.right, windowSize.width - 92,
          reason:
              'platform=${testCase.platform}, duoVerticalBar=${testCase.duoVerticalBar}');
    }
    PlatformCapabilities.debugHostPlatformOverride = null;
  });

  test('GalleryDetailColumns uses usable safe width on Duo vertical bar', () {
    // 703pt total includes 92pt vertical bar -> usable safe width is 611pt (< 700pt).
    const duoDetailEnv = AdaptiveEnvironmentSnapshot(
      size: Size(703, 720),
      safeArea: EdgeInsets.only(right: 92),
      systemBarEdge: 'right',
      duoVerticalBar: true,
      nativeSupported: true,
    );
    expect(
      GalleryDetailColumns.resolve(
        width: 703,
        environment: duoDetailEnv,
        split: true,
      ),
      isNull,
    );

    // Non-Duo wide pane still enters 2 columns cleanly.
    const ipadDetailEnv = AdaptiveEnvironmentSnapshot(
      size: Size(703, 720),
      nativeSupported: true,
    );
    expect(
      GalleryDetailColumns.resolve(
        width: 703,
        environment: ipadDetailEnv,
        split: true,
      ),
      const GalleryDetailColumns(leading: 320, gap: 0),
    );
  });
}
