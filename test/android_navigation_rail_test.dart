import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/pages/tab/view/home_page_small.dart';
import 'package:eros_fe/widget/android_navigation_rail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

const _items = <BottomNavigationBarItem>[
  BottomNavigationBarItem(
    icon: Icon(CupertinoIcons.square_grid_2x2),
    label: 'Gallery',
  ),
  BottomNavigationBarItem(icon: Icon(CupertinoIcons.heart), label: 'Favorites'),
  BottomNavigationBarItem(
    icon: Icon(CupertinoIcons.arrow_down),
    label: 'Downloads',
  ),
  BottomNavigationBarItem(icon: Icon(CupertinoIcons.gear), label: 'Settings'),
];

Widget _rail({
  required bool glass,
  int current = 0,
  ValueChanged<int>? onTap,
}) => GlassPreference(
  enabled: glass,
  child: CupertinoApp(
    home: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: AndroidNavigationRail.reservedWidth(glass: glass),
          child: AndroidNavigationRail(
            items: _items,
            currentIndex: current,
            glass: glass,
            onTap: onTap ?? (_) {},
          ),
        ),
        const Expanded(child: SizedBox()),
      ],
    ),
  ),
);

void main() {
  tearDown(() => PlatformCapabilities.debugHostPlatformOverride = null);

  for (final glass in [true, false]) {
    testWidgets('glass=$glass rail lists every destination and selects one', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.reset);
      final taps = <int>[];
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_rail(glass: glass, current: 1, onTap: taps.add));
      await tester.pumpAndSettle();

      for (final item in _items) {
        expect(find.text(item.label!), findsOneWidget);
      }
      expect(
        tester.getSemantics(find.bySemanticsLabel('Favorites')),
        matchesSemantics(
          label: 'Favorites',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.text('Settings'));
      expect(taps, [3]);

      // Destinations stack top to bottom inside the rail's width.
      final gallery = tester.getRect(find.text('Gallery'));
      final settings = tester.getRect(find.text('Settings'));
      expect(settings.top, greaterThan(gallery.bottom));
      expect(
        gallery.right,
        lessThanOrEqualTo(AndroidNavigationRail.reservedWidth(glass: glass)),
      );
      expect(tester.takeException(), isNull);
      handle.dispose();
    });
  }

  testWidgets('the glass capsule stays below the status bar', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.padding = const FakeViewPadding(top: 24, left: 30);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GlassPreference(
        enabled: true,
        child: CupertinoApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: AndroidNavigationRail.reservedWidth(
                glass: true,
                leftInset: 30,
              ),
              height: 800,
              child: AndroidNavigationRail(
                items: _items,
                currentIndex: 0,
                glass: true,
                onTap: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gallery = tester.getRect(find.text('Gallery'));
    expect(gallery.top, greaterThan(24 + AndroidNavigationRail.margin));
    expect(gallery.left, greaterThan(30));
    expect(tester.takeException(), isNull);
  });

  test('a glass rail floats with margins; a solid rail is flush', () {
    expect(
      AndroidNavigationRail.reservedWidth(glass: true),
      AndroidNavigationRail.railWidth + AndroidNavigationRail.margin * 2,
    );
    expect(
      AndroidNavigationRail.reservedWidth(glass: false),
      AndroidNavigationRail.railWidth,
    );
  });

  test('only an Android split layout uses the rail', () {
    const wide = AdaptiveEnvironmentSnapshot(size: Size(1280, 800));
    const narrow = AdaptiveEnvironmentSnapshot(size: Size(412, 915));
    expect(wide.isSplit, isTrue);
    expect(narrow.isSplit, isFalse);
    for (final host in TargetPlatform.values) {
      PlatformCapabilities.debugHostPlatformOverride = host;
      final android = host == TargetPlatform.android;
      expect(
        usesAndroidNavigationRail(split: true, environment: wide),
        android,
        reason: '$host',
      );
      expect(
        usesAndroidNavigationRail(split: false, environment: wide),
        isFalse,
      );
      expect(
        usesAndroidNavigationRail(split: true, environment: narrow),
        isFalse,
      );
    }
  });
}
