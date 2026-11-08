import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

const double _safeTop = 24;

Widget _rail({
  LiquidGlassRailSearch? search,
  LiquidGlassTopBarLayout layout = LiquidGlassTopBarLayout.twoRow,
  int categories = 4,
  VoidCallback? onMenu,
  VoidCallback? onJump,
}) {
  return CupertinoApp(
    home: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: 390,
        child: LiquidGlassRail(
          title: 'Rail',
          safeTop: _safeTop,
          fadeProgress: 0,
          selectedIndex: 0,
          layout: layout,
          search: search,
          leading: LiquidGlassRailAction(
            icon: CupertinoIcons.clock,
            label: 'History',
            onPressed: () {},
          ),
          trailing: <LiquidGlassRailAction>[
            LiquidGlassRailAction(
              icon: CupertinoIcons.arrow_uturn_down_circle,
              label: 'Jump',
              onPressed: onJump ?? () {},
            ),
          ],
          categoryTrailing: <LiquidGlassRailAction>[
            LiquidGlassRailAction(
              icon: CupertinoIcons.line_horizontal_3,
              label: 'Groups',
              onPressed: onMenu ?? () {},
            ),
          ],
          categories: List.generate(
            categories,
            (i) => LiquidGlassRailCategory(
              id: '$i',
              title: 'Group $i',
              onTap: () {},
            ),
          ),
        ),
      ),
    ),
  );
}

Rect _rectOfLabel(WidgetTester tester, String label) =>
    tester.getRect(find.bySemanticsLabel(label).first);

void main() {
  testWidgets('two-row rail puts the search capsule in the first row',
      (tester) async {
    var searches = 0;
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_rail(
      search: LiquidGlassRailSearch(label: 'Search', onTap: () => searches++),
    ));

    final capsule = find.byKey(const ValueKey('liquid-glass-rail-search'));
    expect(capsule, findsOneWidget);
    final capsuleRect = tester.getRect(capsule);
    expect(capsuleRect.top, _safeTop);
    expect(capsuleRect.height, LiquidGlassRail.controlSize);

    // The capsule fills the space between History and Jump.
    final history = _rectOfLabel(tester, 'History');
    final jump = _rectOfLabel(tester, 'Jump');
    expect(capsuleRect.left, greaterThan(history.right));
    expect(capsuleRect.right, lessThan(jump.left));
    expect(jump.top, _safeTop);

    // The group menu moves down beside the categories.
    final groups = _rectOfLabel(tester, 'Groups');
    expect(groups.top, greaterThanOrEqualTo(_safeTop + 50));
    expect(find.text('Group 0'), findsOneWidget);
    final firstGroup = tester.getRect(find.text('Group 0'));
    expect(firstGroup.center.dy, closeTo(groups.center.dy, 1));

    await tester.tap(find.text('Search'));
    expect(searches, 1);
    handle.dispose();
  });

  testWidgets('search capsule trailing action is its own button',
      (tester) async {
    var searches = 0;
    var history = 0;
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_rail(
      search: LiquidGlassRailSearch(
        label: 'Search',
        onTap: () => searches++,
        trailing: LiquidGlassRailAction(
          icon: CupertinoIcons.time,
          label: 'Recent',
          onPressed: () => history++,
        ),
      ),
    ));

    await tester.tap(find.bySemanticsLabel('Recent'));
    expect(history, 1);
    expect(searches, 0);
    handle.dispose();
  });

  testWidgets('without search, the group menu stays in the first row',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_rail());

    expect(find.byKey(const ValueKey('liquid-glass-rail-search')),
        findsNothing);
    expect(_rectOfLabel(tester, 'Groups').top, _safeTop);
    handle.dispose();
  });

  testWidgets('without the search row, search is a round button on the right',
      (tester) async {
    var searches = 0;
    final handle = tester.ensureSemantics();
    final search =
        LiquidGlassRailSearch(label: 'Search', onTap: () => searches++);
    for (final rail in <Widget>[
      _rail(search: search, layout: LiquidGlassTopBarLayout.inline),
      _rail(search: search, categories: 0),
    ]) {
      await tester.pumpWidget(rail);
      expect(find.byKey(const ValueKey('liquid-glass-rail-search')),
          findsNothing);
      final button = _rectOfLabel(tester, 'Search');
      expect(button.top, _safeTop);
      expect(button.height, LiquidGlassRail.controlSize);
      // It leads the right-hand buttons and stays clear of them.
      expect(button.right,
          lessThanOrEqualTo(_rectOfLabel(tester, 'Groups').left));
      await tester.tap(find.bySemanticsLabel('Search').first);
      await tester.pump();
    }
    expect(searches, 2);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  test('only Android moves search into the top capsule', () {
    addTearDown(() => PlatformCapabilities.debugHostPlatformOverride = null);
    for (final platform in TargetPlatform.values) {
      PlatformCapabilities.debugHostPlatformOverride = platform;
      expect(PlatformCapabilities.topSearchCapsule,
          platform == TargetPlatform.android,
          reason: '$platform');
    }
  });
}
