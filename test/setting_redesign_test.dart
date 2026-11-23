import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/adaptive/native_top_header.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/component/setting/android_setting_group.dart';
import 'package:eros_fe/component/setting/setting_menu.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/setting/setting_items/selector_Item.dart';
import 'package:eros_fe/pages/setting/setting_items/single_input_page.dart';
import 'package:eros_fe/pages/tab/controller/setting_controller.dart';
import 'package:eros_fe/pages/tab/view/setting_page.dart';
import 'package:eros_fe/widget/cupertino/list_tile.dart';
import 'package:eros_fe/widget/cupertino/sliver_list_section.dart';
import 'package:eros_fe/widget/scroll_edge_effect.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'support/waterfall_fixture.dart';

const MethodChannel _menuChannel = MethodChannel('eros/menu');

void _surface(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = Size(width * 3, 874 * 3);
  addTearDown(tester.view.reset);
}

Widget _app(List<Widget> slivers, {double textScale = 1}) {
  return CupertinoApp(
    locale: const Locale('en'),
    supportedLocales: L10n.delegate.supportedLocales,
    localizationsDelegates: const [
      L10n.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: CupertinoPageScaffold(child: CustomScrollView(slivers: slivers)),
    ),
  );
}

Widget _themeRow({
  ValueChanged<String>? onChanged,
  Map<String, String>? subtitles,
}) {
  return SelectorCupertinoListTile<String>(
    title: 'Theme',
    actionMap: const {
      'system': 'Follow System',
      'light': 'Light',
      'dark': 'Dark',
    },
    subtitleMap: subtitles,
    initVal: 'system',
    onValueChanged: onChanged,
  );
}

void main() {
  setUp(registerWaterfallFixture);
  tearDown(() {
    NativeNavigationBridge.enabled.value = false;
    Get.reset();
  });

  group('section', () {
    testWidgets('is a 24pt continuous-corner group 16pt from the edge', (
      tester,
    ) async {
      _surface(tester, 402);
      await tester.pumpWidget(
        _app([
          SliverCupertinoListSection.listInsetGrouped(
            header: const Text('Browsing'),
            children: const [
              EhCupertinoListTile(title: Text('Read')),
              EhCupertinoListTile(title: Text('Search')),
            ],
          ),
        ]),
      );

      final decorated = tester
          .widgetList<DecoratedSliver>(find.byType(DecoratedSliver))
          .map((sliver) => sliver.decoration)
          .whereType<ShapeDecoration>()
          .single;
      final shape = decorated.shape as RoundedSuperellipseBorder;
      expect(shape.borderRadius, BorderRadius.circular(24));
      expect(kInsetGroupedSectionRadius, 24);

      final row = tester.getRect(find.byType(EhCupertinoListTile).first);
      expect(row.left, 16);
      expect(row.right, 402 - 16);
      // Header text lines up with the row text: 16pt margin + 16pt padding.
      expect(tester.getTopLeft(find.text('Browsing')).dx, 32);
      expect(tester.getTopLeft(find.text('Read')).dx, 32);
    });

    testWidgets('rows are 52pt and wrap long titles instead of cutting them', (
      tester,
    ) async {
      const long = 'Show the uploader comment pinned above the others';
      _surface(tester, 320);
      await tester.pumpWidget(
        _app([
          SliverCupertinoListSection.listInsetGrouped(
            children: [
              const EhCupertinoListTile(title: Text('Read')),
              EhCupertinoListTile(
                title: const Text(long),
                trailing: CupertinoSwitch(value: true, onChanged: (_) {}),
              ),
            ],
          ),
        ]),
      );

      final rows = find.byType(EhCupertinoListTile);
      expect(tester.getSize(rows.first).height, 52);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.text(long), matching: find.byType(RichText)),
      );
      expect(paragraph.maxLines, isNull);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.getSize(rows.last).height, greaterThan(52));
      expect(tester.takeException(), isNull);
    });
  });

  group('menu row', () {
    testWidgets('reads as one button with its value', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app([
          SliverCupertinoListSection.listInsetGrouped(children: [_themeRow()]),
        ]),
      );

      expect(
        tester.getSemantics(find.byType(SelectorCupertinoListTile<String>)),
        matchesSemantics(
          label: 'Theme',
          value: 'Follow System',
          isButton: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('draws the menu in Flutter when UIKit is unavailable', (
      tester,
    ) async {
      final picked = <String>[];
      await tester.pumpWidget(
        _app([
          SliverCupertinoListSection.listInsetGrouped(
            children: [_themeRow(onChanged: picked.add)],
          ),
        ]),
      );
      expect(
        find.byIcon(CupertinoIcons.chevron_up_chevron_down),
        findsOneWidget,
      );

      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoMenuItem), findsNWidgets(3));
      // Only the current choice carries the checkmark.
      expect(
        find.descendant(
          of: find.widgetWithText(CupertinoMenuItem, 'Follow System'),
          matching: find.byIcon(CupertinoIcons.checkmark_alt),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(CupertinoIcons.checkmark_alt), findsOneWidget);

      await tester.tap(find.widgetWithText(CupertinoMenuItem, 'Dark'));
      await tester.pumpAndSettle();
      expect(picked, ['dark']);
      expect(find.byType(CupertinoMenuItem), findsNothing);
      expect(find.textContaining('Dark'), findsOneWidget);
    });

    testWidgets('presents a native UIMenu from the value on iOS', (
      tester,
    ) async {
      PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => PlatformCapabilities.debugHostPlatformOverride = null);
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _menuChannel,
        (call) async {
          calls.add(call);
          return true;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _menuChannel,
          null,
        ),
      );

      final ticks = _countTicks(tester);
      final picked = <String>[];
      await tester.pumpWidget(
        _app([
          SliverCupertinoListSection.listInsetGrouped(
            children: [
              _themeRow(
                onChanged: picked.add,
                subtitles: const {'light': 'Always light'},
              ),
            ],
          ),
        ]),
      );
      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoMenuItem), findsNothing);
      final show = calls.single;
      expect(show.method, 'show');
      final arguments = show.arguments as Map;
      final items = (arguments['items'] as List).cast<Map>();
      expect(items.map((item) => item['title']), [
        'Follow System',
        'Light',
        'Dark',
      ]);
      expect(items.map((item) => item['checked']), [true, false, false]);
      expect(items[1]['subtitle'], 'Always light');
      // The menu grows out of the value at the trailing edge of the row.
      final rect = arguments['rect'] as Map;
      final value = tester.getRect(find.byType(SettingMenuButton<String>));
      expect(rect['x'], value.left);
      expect(rect['width'], value.width);

      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'eros/menu',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('selected', {'token': arguments['token'], 'index': 2}),
        ),
        (_) {},
      );
      await tester.pump();
      expect(picked, ['dark']);
      expect(ticks(), 1);
      expect(find.textContaining('Dark'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('falls back to Flutter when UIKit declines', (tester) async {
      PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => PlatformCapabilities.debugHostPlatformOverride = null);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _menuChannel,
        (call) async => false,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _menuChannel,
          null,
        ),
      );

      final ticks = _countTicks(tester);
      await tester.pumpWidget(
        _app([
          SliverCupertinoListSection.listInsetGrouped(children: [_themeRow()]),
        ]),
      );
      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoMenuItem), findsNWidgets(3));
      expect(ticks(), 0);
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      // A pick ticks once.
      expect(ticks(), 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('choices with previews keep the action sheet', (tester) async {
      await tester.pumpWidget(
        _app([
          SliverCupertinoListSection.listInsetGrouped(
            children: const [
              SelectorCupertinoListTile<int>(
                title: 'Double Page',
                actionMap: {0: 'Off', 1: 'Model A'},
                actionWidgetMap: {0: Text('Off'), 1: Text('Model A preview')},
                initVal: 0,
              ),
            ],
          ),
        ]),
      );
      expect(find.bySubtype<CupertinoListTileChevron>(), findsOneWidget);
      await tester.tap(find.text('Double Page'));
      await tester.pumpAndSettle();
      expect(find.text('Model A preview'), findsOneWidget);
      expect(find.byType(CupertinoMenuItem), findsNothing);
    });

    testWidgets('moves the value under the title at accessibility sizes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app([
          SliverCupertinoListSection.listInsetGrouped(children: [_themeRow()]),
        ], textScale: 3.1),
      );
      expect(tester.takeException(), isNull);
      final title = tester.getRect(find.text('Theme'));
      final value = tester.getRect(find.byType(SettingMenuButton<String>));
      expect(value.top, greaterThanOrEqualTo(title.bottom));
      expect(value.left, title.left);
    });
  });

  group('home', () {
    setUp(() {
      Global.packageInfo = PackageInfo(
        appName: 'Eros-FE',
        packageName: 'cn.honjow.fehv',
        version: '1.9.2',
        buildNumber: '566',
      );
      Get.put(SettingViewController());
    });

    Future<void> pumpHome(
      WidgetTester tester, {
      double textScale = 1,
      bool native = false,
      double safeTop = 0,
    }) async {
      final home = MediaQuery(
        data: MediaQueryData(
          size: const Size(402, 874),
          padding: EdgeInsets.only(top: safeTop),
          viewPadding: EdgeInsets.only(top: safeTop),
          textScaler: TextScaler.linear(textScale),
        ),
        child: const SettingTab(),
      );
      await tester.pumpWidget(
        CupertinoApp(
          locale: const Locale('en'),
          supportedLocales: L10n.delegate.supportedLocales,
          localizationsDelegates: const [
            L10n.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: native ? NativeNavigationScope(child: home) : home,
        ),
      );
      await tester.pump();
    }

    testWidgets('native home edge follows the large-title scroll view', (
      tester,
    ) async {
      _surface(tester, 402);
      NativeNavigationBridge.enabled.value = true;
      addTearDown(() => NativeNavigationBridge.enabled.value = false);
      await pumpHome(tester, native: true);

      expect(find.byType(SoftScrollEdgeEffect), findsOneWidget);
      expect(
        tester
            .widget<SoftScrollEdgeEffect>(find.byType(SoftScrollEdgeEffect))
            .strength,
        0,
      );
      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      scrollable.position.jumpTo(24);
      await tester.pump();
      expect(scrollable.position.pixels, 24);
      expect(
        tester
            .widget<SoftScrollEdgeEffect>(find.byType(SoftScrollEdgeEffect))
            .strength,
        1,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('native home large title starts at the live safe-area inset', (
      tester,
    ) async {
      _surface(tester, 402);
      NativeNavigationBridge.enabled.value = true;
      addTearDown(() => NativeNavigationBridge.enabled.value = false);
      await pumpHome(tester, native: true, safeTop: 50);

      final pageContext = tester.element(find.byType(SettingTab));
      final title = find.byType(SettingLargeTitle);
      final titleRect = tester.getRect(title);
      final titleTextRect = tester.getRect(
        find.descendant(of: title, matching: find.byType(Text)),
      );
      expect(
        titleRect.top,
        closeTo(MediaQuery.viewPaddingOf(pageContext).top, 0.5),
      );
      expect(titleTextRect.top, closeTo(titleRect.top + 4, 0.5));
      expect(
        tester
            .widget<SoftScrollEdgeEffect>(find.byType(SoftScrollEdgeEffect))
            .inset,
        closeTo(MediaQuery.viewPaddingOf(pageContext).top, 0.5),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('single input does not scroll at its standard one-line size', (
      tester,
    ) async {
      _surface(tester, 402);
      NativeNavigationBridge.enabled.value = true;
      addTearDown(() => NativeNavigationBridge.enabled.value = false);
      await tester.pumpWidget(
        CupertinoApp(
          home: NativeNavigationScope(
            child: const SingleInputPage(title: 'Input', initValue: 'value'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(scrollable.position.maxScrollExtent, 0);
      expect(find.byType(SoftScrollEdgeEffect), findsOneWidget);
      final pageContext = tester.element(find.byType(SingleInputPage));
      expect(
        tester
            .widget<SoftScrollEdgeEffect>(find.byType(SoftScrollEdgeEffect))
            .surfaceColor,
        CupertinoDynamicColor.resolve(
          CupertinoColors.secondarySystemBackground,
          pageContext,
        ),
      );
      expect(
        tester
            .widget<SoftScrollEdgeEffect>(find.byType(SoftScrollEdgeEffect))
            .strength,
        0,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('long multiline input can scroll under the native bar', (
      tester,
    ) async {
      _surface(tester, 402);
      NativeNavigationBridge.enabled.value = true;
      addTearDown(() => NativeNavigationBridge.enabled.value = false);
      const inset = 50.0;
      await tester.pumpWidget(
        CupertinoApp(
          home: NativeNavigationScope(
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(402, 874),
                padding: EdgeInsets.only(top: inset),
                viewPadding: EdgeInsets.only(top: inset),
              ),
              child: SingleInputPage(
                title: 'Input',
                maxLines: 1000,
                initValue: List<String>.generate(
                  80,
                  (index) => 'line $index',
                ).join(String.fromCharCode(10)),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final pageContext = tester.element(find.byType(SingleInputPage));
      expect(
        tester.getTopLeft(find.byType(CupertinoTextField)).dy +
            scrollable.position.pixels,
        inset + NativeTopTabHeader.contentGapFor(pageContext),
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      expect(find.byType(SoftScrollEdgeEffect), findsOneWidget);
      scrollable.position.jumpTo(16);
      await tester.pump();
      expect(
        tester
            .widget<SoftScrollEdgeEffect>(find.byType(SoftScrollEdgeEffect))
            .strength,
        1,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('groups pages under Browsing, Content and System', (
      tester,
    ) async {
      _surface(tester, 402);
      await pumpHome(tester);
      final l10n = L10n.current;
      expect(find.text(l10n.login), findsOneWidget);
      for (final header in [
        l10n.setting_group_browse,
        l10n.setting_group_content,
        l10n.setting_group_system,
      ]) {
        await tester.scrollUntilVisible(find.text(header), 200);
        expect(find.text(header), findsOneWidget);
      }
      await tester.scrollUntilVisible(find.text(l10n.about), 200);
      expect(find.text('1.9.2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rows follow the setting they open', (tester) async {
      final EhSettingService settings = Get.find();
      settings.isSiteEx.value = false;
      await pumpHome(tester);
      await tester.scrollUntilVisible(
        find.text(L10n.current.setting_site),
        200,
      );
      expect(find.text('E-Hentai'), findsOneWidget);
      settings.isSiteEx.value = true;
      await tester.pump();
      expect(find.text('ExHentai'), findsOneWidget);
    });

    testWidgets('safe mode hides the account', (tester) async {
      final EhSettingService settings = Get.find();
      settings.isSafeMode.value = true;
      await pumpHome(tester);
      expect(find.text(L10n.current.login), findsNothing);
      settings.isSafeMode.value = false;
      await tester.pump();
      expect(find.text(L10n.current.login), findsOneWidget);
    });

    testWidgets('fits accessibility sizes without overflow', (tester) async {
      _surface(tester, 402);
      await pumpHome(tester, textScale: 3.1);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    group('Android', () {
      setUp(
        () => PlatformCapabilities.debugHostPlatformOverride =
            TargetPlatform.android,
      );
      tearDown(() => PlatformCapabilities.debugHostPlatformOverride = null);

      testWidgets('uses separate rounded rows with the value as a subtitle', (
        tester,
      ) async {
        _surface(tester, 412);
        final EhSettingService settings = Get.find();
        settings.isSiteEx.value = false;
        await pumpHome(tester);
        final l10n = L10n.current;
        expect(find.byType(AndroidSettingGroup), findsWidgets);
        expect(find.byType(SliverCupertinoListSection), findsNothing);
        expect(find.bySubtype<CupertinoListTileChevron>(), findsNothing);

        await tester.scrollUntilVisible(find.text(l10n.setting_site), 200);
        final site = tester.getRect(find.text(l10n.setting_site));
        final value = tester.getRect(find.text('E-Hentai'));
        // The current value sits under its title, not at the row's end.
        expect(value.top, greaterThan(site.bottom - 1));
        expect(value.left, site.left);

        for (final header in [
          l10n.setting_group_browse,
          l10n.setting_group_content,
          l10n.setting_group_system,
        ]) {
          await tester.scrollUntilVisible(find.text(header), 200);
          expect(find.text(header), findsOneWidget);
        }
        await tester.scrollUntilVisible(find.text(l10n.about), 200);
        expect(find.text('1.9.2'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('rows open their page and keep the account first', (
        tester,
      ) async {
        _surface(tester, 412);
        await pumpHome(tester);
        expect(find.text(L10n.current.login), findsOneWidget);
        final tiles = tester
            .widgetList<AndroidSettingTile>(find.byType(AndroidSettingTile))
            .toList();
        expect(tiles, isNotEmpty);
        expect(tiles.every((tile) => tile.onTap != null), isTrue);
      });

      testWidgets('fits accessibility sizes without overflow', (tester) async {
        _surface(tester, 412);
        await pumpHome(tester, textScale: 3.1);
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -2000),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('large title fades out once the bar shows the title', (
        tester,
      ) async {
        SettingGlassBar.debugActive = true;
        addTearDown(() => SettingGlassBar.debugActive = null);
        _surface(tester, 412);
        await pumpHome(tester);
        double opacity() => tester
            .widget<AnimatedOpacity>(
              find.byKey(
                const ValueKey('setting-large-title-fade'),
                skipOffstage: false,
              ),
            )
            .opacity;
        expect(opacity(), 1);
        // Hold the drag: a short page bounces back once released.
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(CustomScrollView)),
        );
        await gesture.moveBy(const Offset(0, -40));
        await gesture.moveBy(const Offset(0, -120));
        await tester.pump(const Duration(milliseconds: 300));
        expect(opacity(), 0);
        await gesture.moveBy(const Offset(0, 160));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(opacity(), 1);
        expect(tester.takeException(), isNull);
      });
    });
  });

  test('Android rows round only the outer corners of their group', () {
    const outer = Radius.circular(kAndroidSettingOuterRadius);
    const inner = Radius.circular(kAndroidSettingInnerRadius);
    expect(androidSettingRowRadius(0, 1), const BorderRadius.all(outer));
    expect(
      androidSettingRowRadius(0, 3),
      const BorderRadius.only(
        topLeft: outer,
        topRight: outer,
        bottomLeft: inner,
        bottomRight: inner,
      ),
    );
    expect(androidSettingRowRadius(1, 3), const BorderRadius.all(inner));
    expect(
      androidSettingRowRadius(2, 3),
      const BorderRadius.only(
        topLeft: inner,
        topRight: inner,
        bottomLeft: outer,
        bottomRight: outer,
      ),
    );
  });
}

/// Counts haptic ticks on whichever path the shared haptics helper takes in
/// this test run.
ValueGetter<int> _countTicks(WidgetTester tester) {
  var ticks = 0;
  final messenger = tester.binding.defaultBinaryMessenger;
  for (final channel in const [
    MethodChannel('eros/haptics'),
    MethodChannel('vibration'),
    SystemChannels.platform,
  ]) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (const [
        'selection',
        'vibrate',
        'HapticFeedback.vibrate',
      ].contains(call.method)) {
        ticks++;
      }
      return call.method.startsWith('has') ? false : null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }
  return () => ticks;
}
