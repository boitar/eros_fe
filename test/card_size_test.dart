import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/item_config.dart';
import 'package:eros_fe/pages/setting/card_size_preview.dart';
import 'package:eros_fe/pages/tab/view/list/card_size.dart';
import 'package:eros_fe/pages/tab/view/list/waterfall_flow.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const large = ListModeEnum.waterfallLarge;

  group('columns', () {
    test('standard is the automatic count every style had', () {
      for (var pane = 300.0; pane < 1400; pane += 13) {
        expect(
            CardSize.columns(large, CardSize.standard, pane),
            LargeWaterfallDelegate.columnsFor(pane - 24,
                gap: EHConst.waterfallFlowLargeCrossAxisSpacing),
            reason: 'pane $pane');
      }
      expect(CardSize.maxCrossAxisExtent(ListModeEnum.grid, CardSize.standard),
          EHConst.gridMaxCrossAxisExtent);
      expect(
          CardSize.maxCrossAxisExtent(ListModeEnum.gridTags, CardSize.standard),
          EHConst.gridMaxCrossAxisExtent);
      expect(
          CardSize.maxCrossAxisExtent(ListModeEnum.waterfall, CardSize.standard,
              phone: true),
          EHConst.waterfallFlowMaxCrossAxisExtent);
      expect(
          CardSize.maxCrossAxisExtent(ListModeEnum.waterfall, CardSize.standard,
              phone: false),
          EHConst.waterfallFlowMaxCrossAxisExtentTablet);
    });

    test('the large waterfall on each iPhone Duo pane', () {
      // Outer display beside its side column, inner portrait, iPad portrait.
      expect(CardSize.columns(large, CardSize.standard, 382), 2);
      expect(CardSize.columns(large, CardSize.standard, 669), 3);
      expect(CardSize.columns(large, CardSize.standard, 834), 4);
      // The split list pane, from the narrowest to the widest divider.
      expect(CardSize.columns(large, CardSize.standard, 320), 2);
      expect(CardSize.columns(large, CardSize.standard, 546), 2);
      // The point of the setting: two on the outer display no longer pins
      // the inner one to two.
      expect(CardSize.columns(large, 0, 382), 3);
      expect(CardSize.columns(large, 0, 669), 5);
      expect(CardSize.columns(large, 4, 669), 2);
    });

    test('bigger steps never add columns', () {
      for (final mode in CardSize.modes) {
        for (var pane = 300.0; pane < 1400; pane += 17) {
          for (var step = 1; step < CardSize.steps; step++) {
            expect(CardSize.columns(mode, step, pane),
                lessThanOrEqualTo(CardSize.columns(mode, step - 1, pane)),
                reason: '$mode step $step pane $pane');
          }
        }
      }
    });
  });

  group('stored step', () {
    test('defaults to standard and clamps what it reads', () {
      expect(CardSize.of(large, null), CardSize.standard);
      expect(CardSize.of(large, const ItemConfig(type: 'waterfallLarge')),
          CardSize.standard);
      expect(
          CardSize.of(large, const ItemConfig(type: 'x', cardSize: 9)), 4);
      expect(
          CardSize.of(large, const ItemConfig(type: 'x', cardSize: -1)), 0);
    });

    test('an old custom width becomes the nearest step', () {
      ItemConfig old(int width, {bool on = true}) =>
          ItemConfig(type: 'x', enableCustomWidth: on, customWidth: width);
      // The large waterfall's old slider started at 220.
      expect(CardSize.of(large, old(220)), CardSize.standard);
      expect(CardSize.of(large, old(140)), 0);
      expect(CardSize.of(large, old(320)), 4);
      expect(CardSize.of(large, old(320, on: false)), CardSize.standard);
      expect(CardSize.of(ListModeEnum.grid, old(220)), 4);
      expect(CardSize.of(ListModeEnum.grid, old(100)), 0);
      // A step chosen since wins over the old width.
      expect(
          CardSize.of(
              large,
              const ItemConfig(
                  type: 'x', enableCustomWidth: true, customWidth: 320,
                  cardSize: 1)),
          1);
    });

    test('survives serialization', () {
      const config = ItemConfig(type: 'grid', cardSize: 3);
      expect(ItemConfig.fromJson(config.toJson()), config);
      expect(config.copyWith().cardSize, 3);
    });
  });

  test('the preview device follows the screen shape', () {
    expect(previewDeviceFor(const Size(466, 678)), PreviewDevice.duoOuter);
    expect(previewDeviceFor(const Size(678, 466)), PreviewDevice.duoOuter);
    expect(previewDeviceFor(const Size(669, 951)), PreviewDevice.duoInner);
    expect(previewDeviceFor(const Size(951, 669)), PreviewDevice.duoInner);
    expect(previewDeviceFor(const Size(402, 874)), PreviewDevice.iphone);
    expect(previewDeviceFor(const Size(375, 667)),
        PreviewDevice.iphoneHomeButton);
    expect(previewDeviceFor(const Size(834, 1194)), PreviewDevice.ipad);
    expect(previewDeviceFor(const Size(744, 1133)), PreviewDevice.ipad);
  });

  group('preview', () {
    Future<void> show(WidgetTester tester, Widget child,
        {double width = 420}) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(CupertinoApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: L10n.delegate.supportedLocales,
        localizationsDelegates: const [
          L10n.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: CupertinoPageScaffold(child: Center(child: child)),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('iPhone Duo shows both displays and their columns',
        (tester) async {
      await show(
          tester,
          const CardSizePreview(
              mode: ListModeEnum.waterfallLarge,
              step: CardSize.standard,
              screen: Size(466, 678)));
      expect(find.text('外屏'), findsOneWidget);
      expect(find.bySemanticsLabel('竖屏，2 列'), findsOneWidget);
      expect(find.bySemanticsLabel('横屏，3 列'), findsOneWidget);

      await tester.tap(find.text('内屏'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('竖屏，3 列'), findsOneWidget);
      expect(find.bySemanticsLabel('横屏 · 分栏随分割条，2 列'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('iPad shows the range the divider allows', (tester) async {
      await show(
          tester,
          const CardSizePreview(
              mode: ListModeEnum.waterfallLarge,
              step: CardSize.standard,
              screen: Size(834, 1194)),
          width: 700);
      expect(find.text('外屏'), findsNothing);
      expect(find.bySemanticsLabel('竖屏，4 列'), findsOneWidget);
      expect(find.bySemanticsLabel('横屏 · 分栏随分割条，2–4 列'), findsOneWidget);
    });

    testWidgets('each style counts by its own rules', (tester) async {
      await show(
          tester,
          const CardSizePreview(
              mode: ListModeEnum.grid,
              step: CardSize.standard,
              screen: Size(402, 874)));
      // 402 wide: three 150 pt grid cards; landscape splits beside the island.
      expect(find.bySemanticsLabel('竖屏，3 列'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^横屏 · 分栏随分割条')), findsOneWidget);
    });
  });

  group('slider', () {
    testWidgets('names and the track both pick a step', (tester) async {
      var step = CardSize.standard;
      await tester.pumpWidget(CupertinoApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: L10n.delegate.supportedLocales,
        localizationsDelegates: const [
          L10n.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: CupertinoPageScaffold(
          child: Center(
            child: StatefulBuilder(
              builder: (context, setState) => CardSizeSlider(
                step: step,
                onChanged: (value) => setState(() => step = value),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('较小'));
      await tester.pumpAndSettle();
      expect(step, 1);

      final semantics = tester.ensureSemantics();
      final slider = find.bySemanticsLabel('卡片大小');
      expect(tester.getSemantics(slider).value, '较小');
      tester.semantics.performAction(
          find.semantics.byLabel('卡片大小'), SemanticsAction.increase);
      await tester.pumpAndSettle();
      expect(step, 2);
      semantics.dispose();

      final track = tester.getRect(slider);
      await tester.dragFrom(
          track.centerLeft + const Offset(4, 0), Offset(track.width - 8, 0));
      await tester.pumpAndSettle();
      expect(step, CardSize.steps - 1);
    });
  });
}
