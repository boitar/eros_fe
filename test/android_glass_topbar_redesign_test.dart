import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/flutter_glass.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:eros_fe/widget/scroll_edge_effect.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

const double _safeTop = 32;

Widget _host(
  Widget child, {
  GlassMaterial material = GlassMaterial.liquid,
  Brightness brightness = Brightness.light,
  double width = 390,
}) => CupertinoApp(
  theme: CupertinoThemeData(brightness: brightness),
  home: GlassPreference(
    enabled: true,
    material: material,
    child: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(width: width, child: child),
    ),
  ),
);

LiquidGlassRail _androidRail({
  required LiquidGlassTopBarLayout layout,
  int selectedIndex = 0,
  int categoryCount = 8,
  double fadeProgress = 0,
  bool hasLeading = true,
  void Function(String)? onEvent,
}) => LiquidGlassRail(
  title: '画廊',
  safeTop: _safeTop,
  fadeProgress: fadeProgress,
  selectedIndex: selectedIndex,
  layout: layout,
  leading: hasLeading
      ? LiquidGlassRailAction(
          icon: CupertinoIcons.clock,
          label: 'History',
          onPressed: () => onEvent?.call('history'),
        )
      : null,
  search: LiquidGlassRailSearch(
    label: '搜索',
    onTap: () => onEvent?.call('search'),
  ),
  trailing: <LiquidGlassRailAction>[
    LiquidGlassRailAction(
      icon: CupertinoIcons.arrow_uturn_down_circle,
      label: 'Jump',
      onPressed: () => onEvent?.call('jump'),
    ),
  ],
  categoryTrailing: <LiquidGlassRailAction>[
    LiquidGlassRailAction(
      icon: CupertinoIcons.line_horizontal_3,
      label: 'Groups',
      onPressed: () => onEvent?.call('groups'),
    ),
  ],
  categories: List<LiquidGlassRailCategory>.generate(
    categoryCount,
    (index) => LiquidGlassRailCategory(
      id: 'cat-$index',
      title: index == 0
          ? '热门'
          : index == 1
          ? '画廊'
          : index == 2
          ? '订阅'
          : index == 3
          ? '汉语'
          : 'Anthology $index',
      onTap: () => onEvent?.call('cat-$index'),
    ),
  ),
);

void _expectUnobstructedBackdropGroup(WidgetTester tester) {
  final group = find.byType(GlassBackdropGroup);
  expect(group, findsOneWidget);
  final boundary = tester.renderObject(group);
  final panels = tester.elementList(find.byType(GlassContainer)).toList();
  expect(panels.length, greaterThan(1));
  BackdropKey? sharedKey;
  for (final panel in panels) {
    final key = GlassBackdropGroup.keyOf(panel);
    expect(key, isNotNull);
    sharedKey ??= key;
    expect(key, same(sharedKey));
    RenderObject? node = panel.findRenderObject();
    while (node != null && node != boundary) {
      expect(node, isNot(isA<RenderOpacity>()));
      expect(node, isNot(isA<RenderShaderMask>()));
      expect(node, isNot(isA<RenderBackdropFilter>()));
      node = node.parent;
    }
    expect(node, same(boundary));
  }
}

void main() {
  setUp(() {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    PlatformCapabilities.debugHostPlatformOverride = null;
    FlutterGlassRuntime.debugAvailable = null;
  });

  testWidgets('Option A (inline) uses 40pt single row and fused action capsule', (
    tester,
  ) async {
    final events = <String>[];
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        _androidRail(
          layout: LiquidGlassTopBarLayout.inline,
          onEvent: events.add,
        ),
      ),
    );

    final railRect = tester.getRect(find.byType(LiquidGlassRail));
    expect(railRect.height, _safeTop + 40);

    // Search, Groups, and Jump fuse into one glass capsule to save width and
    // GPU refraction passes while keeping every action independently tappable.
    final fused = find.byKey(const ValueKey('liquid-glass-rail-fused-actions'));
    expect(fused, findsOneWidget);
    expect(tester.getRect(fused).height, 40);
    // Leading + Category track + Fused right capsule = 3 glass surfaces total.
    expect(find.byType(GlassContainer), findsNWidgets(3));

    final categoryRect = tester.getRect(
      find.byKey(const ValueKey('liquid-glass-category-selection')),
    );
    expect(categoryRect.top, _safeTop);
    expect(categoryRect.height, 40);

    await tester.tap(find.bySemanticsLabel('搜索').first);
    await tester.tap(find.bySemanticsLabel('Groups').first);
    await tester.tap(find.bySemanticsLabel('Jump').first);
    await tester.pump();
    expect(events, <String>['search', 'groups', 'jump']);
    handle.dispose();
  });

  testWidgets('Option B (twoRow) uses compact 38 + 6 + 30 = 74pt layout', (
    tester,
  ) async {
    final events = <String>[];
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        _androidRail(
          layout: LiquidGlassTopBarLayout.twoRow,
          onEvent: events.add,
        ),
      ),
    );

    final railRect = tester.getRect(find.byType(LiquidGlassRail));
    expect(railRect.height, _safeTop + 74);

    final searchRect = tester.getRect(
      find.byKey(const ValueKey('liquid-glass-rail-search')),
    );
    expect(searchRect.top, _safeTop);
    expect(searchRect.height, 38);

    final categoryRect = tester.getRect(
      find.byKey(const ValueKey('liquid-glass-category-selection')),
    );
    expect(categoryRect.top, _safeTop + 44);
    expect(categoryRect.height, 30);

    // The group menu button strictly matches the 30pt category track height.
    final groupsRect = tester.getRect(find.bySemanticsLabel('Groups').first);
    expect(groupsRect.height, 30);
    expect(groupsRect.center.dy, closeTo(categoryRect.center.dy, 0.5));

    // Concentric selection pill: inset=2.5 -> height=25, radius=12.5.
    final indicator = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(
          const ValueKey('liquid-glass-category-selection-indicator'),
        ),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = indicator.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(12.5));

    await tester.tap(find.text('搜索'));
    await tester.tap(find.bySemanticsLabel('Groups').first);
    await tester.pump();
    expect(events, <String>['search', 'groups']);
    handle.dispose();
  });

  for (final material in GlassMaterial.values) {
    for (final layout in LiquidGlassTopBarLayout.values) {
      for (final brightness in Brightness.values) {
        testWidgets(
          '$material $layout $brightness keeps single unobstructed backdrop group',
          (tester) async {
            await tester.pumpWidget(
              _host(
                _androidRail(layout: layout, fadeProgress: 0.35),
                material: material,
                brightness: brightness,
              ),
            );
            _expectUnobstructedBackdropGroup(tester);
            for (final container in tester.widgetList<GlassContainer>(
              find.byType(GlassContainer),
            )) {
              expect(container.quality, material.quality);
            }
            // Overflowing categories mount the internal edge fade mask inside
            // GlassContainer without obstructing the outer GlassBackdropGroup.
            expect(
              find.byKey(const ValueKey('android-glass-category-edge-fade')),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('non-overflowing categories skip edge fade ShaderMask', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _androidRail(layout: LiquidGlassTopBarLayout.twoRow, categoryCount: 3),
      ),
    );
    expect(
      find.byKey(const ValueKey('android-glass-category-edge-fade')),
      findsNothing,
    );
  });

  testWidgets('tapping a category runs KF-C lifted lens glide and settles', (
    tester,
  ) async {
    var selected = 0;
    late StateSetter rebuild;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return _host(
            _androidRail(
              layout: LiquidGlassTopBarLayout.inline,
              selectedIndex: selected,
              categoryCount: 6,
            ),
          );
        },
      ),
    );

    final indicatorFinder = find.byKey(
      const ValueKey('liquid-glass-category-selection-indicator'),
    );
    final restHeight = tester.getRect(indicatorFinder).height;
    expect(restHeight, 34); // 40 - 2 * 3

    rebuild(() => selected = 2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    // Mid-flight KF-C1/C2: optical lens lifts and expands vertically.
    final midHeight = tester.getRect(indicatorFinder).height;
    expect(midHeight, greaterThan(restHeight));

    await tester.pumpAndSettle();
    // Settled KF-C3: returns cleanly to exact concentric resting height.
    expect(tester.getRect(indicatorFinder).height, closeTo(restHeight, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Android uses seamless canvas without solid white mask or corners',
    (tester) async {
      final edge = ValueNotifier<double>(0);
      addTearDown(edge.dispose);
      await tester.pumpWidget(
        CupertinoApp(
          home: Stack(
            children: <Widget>[
              LiquidGlassSafeAreaBase(
                safeTop: _safeTop,
                layout: LiquidGlassTopBarLayout.twoRow,
                edgeProgress: edge,
              ),
              const LiquidGlassSolidMask(
                progressListenable: AlwaysStoppedAnimation<double>(1),
                safeTop: _safeTop,
                height: _safeTop + 74,
              ),
              LiquidGlassTopScrim(
                safeTop: _safeTop,
                layout: LiquidGlassTopBarLayout.twoRow,
                edgeProgress: edge,
              ),
              LiquidGlassTopSoftEdge(
                safeTop: _safeTop,
                layout: LiquidGlassTopBarLayout.twoRow,
                edgeProgress: edge,
              ),
            ],
          ),
        ),
      );

      // Rest state (KF-A0): zero white mask, zero inverse corners, zero soft edge.
      expect(
        find.byKey(const ValueKey('liquid-glass-solid-mask')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('liquid-glass-content-corners')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('liquid-glass-safe-area-base')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('liquid-glass-top-scrim')),
        findsNothing,
      );
      expect(find.byType(SoftScrollEdgeEffect), findsNothing);

      // Scrolled state (KF-A2): airy soft edge fades in without BackdropFilter.
      edge.value = 1.0;
      await tester.pump();
      expect(find.byType(SoftScrollEdgeEffect), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
      final soft = tester.widget<SoftScrollEdgeEffect>(
        find.byType(SoftScrollEdgeEffect),
      );
      expect(soft.bars, 74);
      expect(soft.tail, 20);
    },
  );

  test('non-Android platforms retain exact legacy geometry untouched', () {
    for (final platform in <TargetPlatform>[
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    ]) {
      PlatformCapabilities.debugHostPlatformOverride = platform;
      expect(
        LiquidGlassTopBarLayout.twoRow.expandedHeight(TextScaler.noScaling),
        94,
        reason: '$platform twoRow',
      );
      expect(
        LiquidGlassTopBarLayout.inline.expandedHeight(TextScaler.noScaling),
        44,
        reason: '$platform inline',
      );
    }
  });
}
