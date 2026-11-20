import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/flutter_glass.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

Widget _rail({
  double fade = 0,
  LiquidGlassTopBarLayout layout = LiquidGlassTopBarLayout.twoRow,
  bool search = true,
  int categories = 12,
  void Function(String)? onAction,
}) => LiquidGlassRail(
  title: 'Gallery',
  showsTitle: true,
  safeTop: 24,
  fadeProgress: fade,
  selectedIndex: 0,
  layout: layout,
  search: search
      ? LiquidGlassRailSearch(
          label: 'Search',
          onTap: () => onAction?.call('search'),
          trailing: LiquidGlassRailAction(
            icon: CupertinoIcons.time,
            label: 'Recent',
            onPressed: () => onAction?.call('recent'),
          ),
        )
      : null,
  leading: LiquidGlassRailAction(
    icon: CupertinoIcons.back,
    label: 'Back',
    onPressed: () => onAction?.call('back'),
  ),
  trailing: [
    LiquidGlassRailAction(
      icon: CupertinoIcons.arrow_down,
      label: 'Jump',
      onPressed: () => onAction?.call('jump'),
    ),
  ],
  categoryTrailing: [
    LiquidGlassRailAction(
      icon: CupertinoIcons.line_horizontal_3,
      label: 'Groups',
      onPressed: () => onAction?.call('groups'),
    ),
  ],
  categories: List.generate(
    categories,
    (i) => LiquidGlassRailCategory(
      id: '$i',
      title: 'Category $i',
      onTap: () => onAction?.call('category-$i'),
      onLongPress: () => onAction?.call('hold-$i'),
    ),
  ),
);

Widget _app(
  Widget child, {
  GlassMaterial material = GlassMaterial.liquid,
  bool enabled = true,
  bool highContrast = false,
}) => CupertinoApp(
  home: MediaQuery(
    data: MediaQueryData(highContrast: highContrast),
    child: GlassPreference(
      enabled: enabled,
      material: material,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: 390, child: child),
      ),
    ),
  ),
);

void _expectUnobstructedGroup(WidgetTester tester) {
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
    debugDefaultTargetPlatformOverride = null;
  });

  for (final layout in LiquidGlassTopBarLayout.values) {
    for (final search in [true, false]) {
      testWidgets('$layout search=$search shares non-overlapping surfaces', (
        tester,
      ) async {
        await tester.pumpWidget(_app(_rail(layout: layout, search: search)));
        await tester.pumpAndSettle();
        _expectUnobstructedGroup(tester);
        for (final panel in tester.widgetList<GlassContainer>(
          find.byType(GlassContainer),
        )) {
          expect(panel.quality, GlassQuality.premium);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('fade keeps group and category state until hidden', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final actions = <String>[];
    Future<void> pump(double fade) async {
      await tester.pumpWidget(_app(_rail(fade: fade, onAction: actions.add)));
      await tester.pumpAndSettle();
    }

    await pump(0);
    final scroll = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!;
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-240, 0),
    );
    await tester.pumpAndSettle();
    final offset = scroll.offset;
    expect(offset, greaterThan(0));
    for (final fade in [0.01, 0.5, 0.99, 0.0]) {
      await pump(fade);
      _expectUnobstructedGroup(tester);
      expect(scroll.offset, closeTo(offset, 0.01));
    }
    await pump(0.5);
    await tester.tap(find.text('Search'));
    await tester.tap(find.bySemanticsLabel('Recent'));
    await tester.tap(find.bySemanticsLabel('Groups'));
    await tester.tap(find.bySemanticsLabel('Jump'));
    final visible = find.text('Category 3').hitTestable();
    await tester.ensureVisible(find.text('Category 3'));
    await tester.tap(visible);
    await tester.longPress(visible);
    expect(actions, [
      'search',
      'recent',
      'groups',
      'jump',
      'category-3',
      'hold-3',
    ]);
    final restoredOffset = scroll.offset;
    await pump(1);
    expect(find.byType(LiquidGlassSurface), findsNothing);
    await pump(0);
    expect(scroll.offset, closeTo(restoredOffset, 0.01));
    _expectUnobstructedGroup(tester);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('each rail keeps its own backdrop key', (tester) async {
    await tester.pumpWidget(_app(Column(children: [_rail(), _rail()])));
    await tester.pumpAndSettle();
    final rails = tester.elementList(find.byType(LiquidGlassRail)).toList();
    final keys = <BackdropKey?>[];
    for (final rail in rails) {
      final panel = tester.element(
        find
            .descendant(
              of: find.byWidget(rail.widget),
              matching: find.byType(GlassContainer),
            )
            .first,
      );
      keys.add(GlassBackdropGroup.keyOf(panel));
    }
    expect(keys, hasLength(2));
    expect(keys.first, isNotNull);
    expect(keys.last, isNot(same(keys.first)));
  });

  for (final host in TargetPlatform.values) {
    testWidgets('$host uses host platform rather than theme platform', (
      tester,
    ) async {
      PlatformCapabilities.debugHostPlatformOverride = host;
      debugDefaultTargetPlatformOverride = host == TargetPlatform.android
          ? TargetPlatform.iOS
          : TargetPlatform.android;
      await tester.pumpWidget(_app(_rail(fade: 0.5), enabled: false));
      await tester.pumpAndSettle();
      expect(
        find.byType(GlassBackdropGroup),
        host == TargetPlatform.android ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('title without categories fades once', (tester) async {
    await tester.pumpWidget(_app(_rail(fade: 0.5, categories: 0)));
    final opacities = find.ancestor(
      of: find.text('Gallery'),
      matching: find.byType(Opacity),
    );
    expect(opacities, findsOneWidget);
    expect(tester.widget<Opacity>(opacities).opacity, 0.5);
  });

  testWidgets('material and accessibility fallbacks keep actions usable', (
    tester,
  ) async {
    var taps = 0;
    for (final variant in [
      'frosted',
      'disabled',
      'contrast',
      'shader-failure',
    ]) {
      FlutterGlassRuntime.debugAvailable = variant != 'shader-failure';
      await tester.pumpWidget(
        _app(
          _rail(fade: 0.5, onAction: (_) => taps++),
          material: GlassMaterial.frosted,
          enabled: variant != 'disabled',
          highContrast: variant == 'contrast',
        ),
      );
      await tester.pumpAndSettle();
      if (variant == 'frosted') {
        for (final panel in tester.widgetList<GlassContainer>(
          find.byType(GlassContainer),
        )) {
          expect(panel.quality, GlassQuality.standard);
        }
      } else {
        expect(find.byType(GlassContainer), findsNothing);
      }
      await tester.tap(find.text('Search'));
      expect(tester.takeException(), isNull);
    }
    expect(taps, 4);
  });
}
