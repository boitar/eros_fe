import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/adaptive/tab_navigation.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/gallery/view/sliver/gallery_hero.dart';
import 'package:eros_fe/pages/gallery/view/sliver/gallery_page.dart';
import 'package:eros_fe/pages/tab/view/home_page_small.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _floating({required bool showRead}) => MaterialApp(
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: GlassPreference(
        enabled: false,
        child: GalleryFloatingNavigation(
          title: 'Non-H fixture',
          showTitle: true,
          showRead: showRead,
          enableRead: true,
          onBack: () {},
          onMore: () {},
          onShare: () {},
          onRead: () {},
        ),
      ),
    );

void main() {
  tearDown(() => PlatformCapabilities.debugHostPlatformOverride = null);

  for (final host in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.windows,
  ]) {
    for (final enabled in [true, false]) {
      testWidgets('$host glass=$enabled action dock', (tester) async {
        PlatformCapabilities.debugHostPlatformOverride = host;
        bool? dock;
        await tester.pumpWidget(
          GlassPreference(
            enabled: enabled,
            child: CupertinoApp(
              home: Builder(builder: (context) {
                dock = usesGalleryActionDock(context);
                return const SizedBox();
              }),
            ),
          ),
        );
        expect(dock, enabled && host == TargetPlatform.android);
      });
    }
  }

  testWidgets('docked pages drop the collapsed Read button', (tester) async {
    await tester.pumpWidget(_floating(showRead: false));
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.book), findsNothing);

    await tester.pumpWidget(_floating(showRead: true));
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.book), findsOneWidget);
  });

  testWidgets('floating glass icons are monochrome', (tester) async {
    await tester.pumpWidget(_floating(showRead: true));
    await tester.pumpAndSettle();
    final colors = tester
        .widgetList<Icon>(find.byType(Icon))
        .map((icon) => icon.color)
        .toSet();
    expect(colors, hasLength(1));
    expect(colors.single, isNotNull);
  });

  testWidgets('Android back uses the Material arrow', (tester) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(_floating(showRead: false));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.back), findsNothing);

    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.macOS;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_floating(showRead: false));
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.back), findsOneWidget);
  });

  group('tab bar on pushed pages', () {
    late TabNavigationRegistry registry;
    late TabNavigationStack stack;
    final primaryKey = GlobalKey<NavigatorState>();
    final detailKey = GlobalKey<NavigatorState>();
    // Observers are shared per navigator id; fresh ids keep tests apart.
    var nextId = 9000;

    setUp(() {
      registry = TabNavigationRegistry(allocateNavigatorId: () => nextId++);
      stack = registry.select('gallery');
    });
    tearDown(() => registry.dispose());

    Future<void> mount(WidgetTester tester) => tester.pumpWidget(
          CupertinoApp(
            home: Row(
              children: [
                Expanded(
                  child: Navigator(
                    key: primaryKey,
                    observers: [stack.primaryObserver],
                    onGenerateRoute: (_) => CupertinoPageRoute<void>(
                      builder: (_) => const SizedBox(),
                    ),
                  ),
                ),
                Expanded(
                  child: Navigator(
                    key: detailKey,
                    observers: [stack.detailObserver],
                    onGenerateRoute: (_) => CupertinoPageRoute<void>(
                      builder: (_) => const SizedBox(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

    Route<void> page() =>
        CupertinoPageRoute<void>(builder: (_) => const SizedBox());

    testWidgets('Android hides the bar for a detail or a list page',
        (tester) async {
      PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
      await mount(tester);
      expect(hidesTabBarForPushedPage(stack, layoutLarge: false), isFalse);

      detailKey.currentState!.push(page());
      await tester.pumpAndSettle();
      expect(hidesTabBarForPushedPage(stack, layoutLarge: false), isTrue);
      // A split keeps the bar under its list column.
      expect(hidesTabBarForPushedPage(stack, layoutLarge: true), isFalse);

      detailKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(hidesTabBarForPushedPage(stack, layoutLarge: false), isFalse);

      primaryKey.currentState!.push(page());
      await tester.pumpAndSettle();
      expect(hidesTabBarForPushedPage(stack, layoutLarge: false), isTrue);
      primaryKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(hidesTabBarForPushedPage(stack, layoutLarge: false), isFalse);
    });

    testWidgets('other hosts keep the bar', (tester) async {
      await mount(tester);
      detailKey.currentState!.push(page());
      await tester.pumpAndSettle();
      for (final host in [
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ]) {
        PlatformCapabilities.debugHostPlatformOverride = host;
        expect(hidesTabBarForPushedPage(stack, layoutLarge: false), isFalse,
            reason: '$host');
      }
      expect(hidesTabBarForPushedPage(null, layoutLarge: false), isFalse);
    });
  });
}
