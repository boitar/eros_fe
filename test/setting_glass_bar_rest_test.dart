import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _bar({required bool edgeVisible}) => GlassPreference(
      enabled: true,
      child: CupertinoApp(
        home: CupertinoPageScaffold(
          navigationBar: SettingGlassBar(
            title: 'Settings',
            titleVisible: edgeVisible,
            edgeVisible: edgeVisible,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );

double _surfaceOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
        find.byKey(const ValueKey('setting-glass-bar-surface')))
    .opacity;

void main() {
  tearDown(() => PlatformCapabilities.debugHostPlatformOverride = null);

  for (final host in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
  ]) {
    testWidgets('$host Flutter glass bar shows no surface at rest',
        (tester) async {
      PlatformCapabilities.debugHostPlatformOverride = host;
      await tester.pumpWidget(_bar(edgeVisible: false));
      await tester.pumpAndSettle();
      expect(_surfaceOpacity(tester), 0);

      await tester.pumpWidget(_bar(edgeVisible: true));
      await tester.pumpAndSettle();
      expect(_surfaceOpacity(tester), 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Android shows only the soft edge, never a glass slab',
      (tester) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
    for (final scrolled in [false, true]) {
      await tester.pumpWidget(_bar(edgeVisible: scrolled));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('setting-glass-bar-surface')),
          findsNothing);
      expect(find.text('Settings'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('iOS keeps its own bar treatment', (tester) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(_bar(edgeVisible: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('setting-glass-bar-surface')),
        findsNothing);
  });
}
