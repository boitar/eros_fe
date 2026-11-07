import 'package:eros_fe/widget/android_navigation_rail.dart';
import 'package:eros_fe/widget/android_solid_top_bar.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

const _items = <BottomNavigationBarItem>[
  BottomNavigationBarItem(
    icon: Icon(CupertinoIcons.square_grid_2x2),
    label: 'Gallery',
  ),
  BottomNavigationBarItem(icon: Icon(CupertinoIcons.heart), label: 'Favorites'),
  BottomNavigationBarItem(icon: Icon(CupertinoIcons.gear), label: 'Settings'),
];

void main() {
  testWidgets('M3 bar marks one destination and reports taps', (tester) async {
    final taps = <int>[];
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      CupertinoApp(
        home: Align(
          alignment: Alignment.bottomCenter,
          child: AndroidNavigationBar(
            items: _items,
            currentIndex: 2,
            onTap: taps.add,
          ),
        ),
      ),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('android-navigation-bar')))
          .height,
      AndroidNavigationBar.barHeight,
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Settings')),
      matchesSemantics(
        label: 'Settings',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.text('Favorites'));
    expect(taps, [1]);
    handle.dispose();
  });

  test('M3 bar copies keep its type, so the shell can update it', () {
    final bar = AndroidNavigationBar(items: _items, onTap: (_) {});
    final copy = bar.copyWith(currentIndex: 1);
    expect(copy, isA<AndroidNavigationBar>());
    expect(copy.currentIndex, 1);
    expect(copy.onTap, same(bar.onTap));
    expect(bar.opaque(_FakeContext()), isTrue);
  });

  testWidgets('solid header searches, selects and manages groups', (
    tester,
  ) async {
    var searches = 0, jumps = 0, manage = 0, held = 0;
    final selected = <int>[];
    final handle = tester.ensureSemantics();
    Widget bar(int index) => CupertinoApp(
      home: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 412,
          child: AndroidSolidTopBar(
            selectedIndex: index,
            search: LiquidGlassRailSearch(
              label: 'Search',
              onTap: () => searches++,
            ),
            trailing: <LiquidGlassRailAction>[
              LiquidGlassRailAction(
                icon: CupertinoIcons.arrow_uturn_down_circle,
                label: 'Jump',
                onPressed: () => jumps++,
              ),
            ],
            categoryTrailing: LiquidGlassRailAction(
              icon: CupertinoIcons.line_horizontal_3,
              label: 'Groups',
              onPressed: () => manage++,
            ),
            categories: <LiquidGlassRailCategory>[
              for (var i = 0; i < 8; i++)
                LiquidGlassRailCategory(
                  title: 'Group $i',
                  onTap: () => selected.add(i),
                  onLongPress: () => held++,
                ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpWidget(bar(0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('android-solid-search')));
    await tester.tap(find.bySemanticsLabel('Jump'));
    await tester.tap(find.bySemanticsLabel('Groups'));
    expect([searches, jumps, manage], [1, 1, 1]);

    expect(find.byIcon(CupertinoIcons.checkmark_alt), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Group 0')),
      matchesSemantics(
        label: 'Group 0',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
        hasLongPressAction: true,
      ),
    );
    await tester.tap(find.text('Group 1'));
    await tester.longPress(find.text('Group 2'));
    expect(selected, [1]);
    expect(held, 1);

    // Swiping to a far group scrolls its chip into view.
    await tester.pumpWidget(bar(7));
    await tester.pumpAndSettle();
    final header = tester.getRect(find.byType(AndroidSolidTopBar));
    final chip = tester.getRect(find.text('Group 7'));
    expect(chip.right, lessThanOrEqualTo(header.right));
    expect(chip.left, greaterThanOrEqualTo(header.left));
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}

class _FakeContext extends Fake implements BuildContext {}
