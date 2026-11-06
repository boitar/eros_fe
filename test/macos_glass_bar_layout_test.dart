import 'package:eros_fe/adaptive/browse_layout.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as glass;

void main() {
  tearDown(() {
    PlatformCapabilities.debugHostPlatformOverride = null;
    PlatformCapabilities.appKitAvailable.value = false;
  });
  test('split bottom bar shares the primary pane calculation', () {
    expect(AdaptiveBrowseLayout.primaryPaneWidth(1000, 0), 320);
    expect(AdaptiveBrowseLayout.primaryPaneWidth(1000, 1), 679);
  });
  testWidgets(
    'macOS native and Flutter bars share content width and honor narrow panes',
    (tester) async {
      PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.macOS;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final channels = <String>[];
      final selected = <int>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final name = 'eros/appkit-glass/${(call.arguments as Map)['id']}';
          channels.add(name);
          messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
            selected.add((call.arguments as Map)['selectedIndex'] as int);
            return null;
          });
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in channels) {
          messenger.setMockMethodCallHandler(MethodChannel(channel), null);
        }
      });
      final widths = <double>[];
      for (final native in [true, false]) {
        PlatformCapabilities.appKitAvailable.value = native;
        for (final width in [750.0, 330.0]) {
          await tester.pumpWidget(
            CupertinoApp(
              home: Center(
                child: SizedBox(
                  width: width,
                  height: 80,
                  child: LiquidGlassTabBar(
                    currentIndex: 1,
                    onTap: (_) {},
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(CupertinoIcons.home),
                        label: 'Home',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(CupertinoIcons.star),
                        label: 'Favorites',
                      ),
                    ],
                    nativeItems: const [
                      LiquidGlassTabItem(
                        label: 'Home',
                        codePoint: 0,
                        fallbackSymbol: 'house',
                      ),
                      LiquidGlassTabItem(
                        label: 'Favorites',
                        codePoint: 0,
                        fallbackSymbol: 'star',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          final surface = native
              ? find.byType(AppKitView)
              : find.byType(glass.GlassTabBar);
          expect(surface, findsOneWidget);
          final actual = tester.getSize(surface).width;
          expect(actual, lessThanOrEqualTo(560));
          expect(actual, lessThanOrEqualTo(width - 24));
          widths.add(actual);
          await tester.pumpWidget(const SizedBox());
        }
      }
      expect(widths[0], widths[2]);
      expect(widths[1], widths[3]);
      expect(selected, isNotEmpty);
    expect(selected, everyElement(1));
    },
  );
}
