import 'package:eros_fe/pages/tab/view/download_page.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('eros/accessibility-settings'),
      (_) async => null,
    );
    (LiquidGlassAccessibilitySettings.reduceTransparency
            as ValueNotifier<bool?>)
        .value = false;
  });

  tearDown(() async {
    await LiquidGlassAccessibilitySettings.stopWatching();
  });

  Widget host(Widget child,
          {double scale = 1,
          double keyboard = 0,
          bool dark = false,
          bool contrast = false}) =>
      CupertinoApp(
        theme: CupertinoThemeData(
          brightness: dark ? Brightness.dark : Brightness.light,
        ),
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(320, 600),
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
            highContrast: contrast,
          ),
          child: child,
        ),
      );

  testWidgets('disabled preserves Cupertino dialog and sheet', (tester) async {
    await tester.pumpWidget(host(const EhAlertDialog(
      glassEnabled: false,
      title: Text('Original'),
    )));
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    await tester.pumpWidget(host(const EhActionSheet(
      glassEnabled: false,
      actions: [],
    )));
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('form scrolls with large text and keyboard, dark=$dark',
        (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final input = TextEditingController();
      addTearDown(input.dispose);
      var cancelled = 0;
      await tester.pumpWidget(host(
        EhAlertDialog(
          glassEnabled: true,
          title: const Text('Choose a favorite category'),
          content: Column(children: [
            for (var index = 0; index < 10; index++)
              Text('Category $index with a long readable label'),
            CupertinoTextField(controller: input),
          ]),
          actions: [
            CupertinoDialogAction(
              onPressed: () => cancelled++,
              child: const Text('Cancel'),
            ),
          ],
        ),
        scale: 2.4,
        keyboard: 280,
        dark: dark,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(CupertinoTextField), findsOneWidget);
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      expect(cancelled, 1);
      await tester.ensureVisible(find.byType(CupertinoTextField));
      await tester.enterText(find.byType(CupertinoTextField), 'saved note');
      expect(input.text, 'saved note');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sheet retains actions, cancel and destructive semantics',
      (tester) async {
    tester.view.physicalSize = const Size(320, 380);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var deleted = false;
    var cancelled = false;
    await tester.pumpWidget(host(
        Align(
          alignment: Alignment.bottomCenter,
          child: EhActionSheet(
            glassEnabled: true,
            title: const Text('Actions for a card'),
            actions: [
              for (var index = 0; index < 8; index++)
                CupertinoActionSheetAction(
                  onPressed: () {},
                  child: Text('Choice $index'),
                ),
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () => deleted = true,
                child: const Text('Delete'),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => cancelled = true,
              child: const Text('Cancel'),
            ),
          ),
        ),
        scale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    expect(cancelled, isTrue);
    await tester.ensureVisible(find.text('Delete'));
    await tester.tap(find.text('Delete'));
    expect(deleted, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('regular form surface becomes opaque for accessibility',
      (tester) async {
    const surface = LiquidGlassPopupSurface(
      enabled: true,
      child: Text('Readable foreground'),
    );
    await tester.pumpWidget(host(surface));
    expect(find.byType(BackdropFilter), findsOneWidget);
    (LiquidGlassAccessibilitySettings.reduceTransparency
            as ValueNotifier<bool?>)
        .value = true;
    await tester.pump();
    expect(find.byType(BackdropFilter), findsNothing);
    (LiquidGlassAccessibilitySettings.reduceTransparency
            as ValueNotifier<bool?>)
        .value = false;
    await tester.pumpWidget(host(surface, contrast: true));
    expect(find.byType(BackdropFilter), findsNothing);
  });

  for (final layout in LiquidGlassTopBarLayout.values) {
    testWidgets('download header keeps category actions, layout=$layout',
        (tester) async {
      var selected = -1;
      var exported = false;
      await tester.pumpWidget(host(Align(
        alignment: Alignment.topCenter,
        child: DownloadGlassHeader(
          title: 'Downloads',
          galleryLabel: 'Gallery',
          archiverLabel: 'Archive',
          safeTop: 59,
          layout: layout,
          selectedIndex: 0,
          onSelected: (value) => selected = value,
          onExport: () => exported = true,
        ),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      expect(selected, 1);
      await tester.tap(find.byIcon(CupertinoIcons.arrow_up_arrow_down));
      expect(exported, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  for (final dark in [false, true]) {
    testWidgets(
        'primary form text contrast survives extreme backdrops, dark=$dark',
        (tester) async {
      await tester.pumpWidget(host(
        const LiquidGlassPopupSurface(
          enabled: true,
          child: Text('Contrast sample'),
        ),
        dark: dark,
      ));
      final foreground = DefaultTextStyle.of(
        tester.element(find.text('Contrast sample')),
      ).style.color!;
      final decorations =
          tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
      final fill = decorations
          .map((widget) => widget.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((value) => value.color != null)
          .color!;
      for (final backdrop in [CupertinoColors.black, CupertinoColors.white]) {
        final background = Color.alphaBlend(fill, backdrop);
        final luminance = [
          foreground.computeLuminance(),
          background.computeLuminance()
        ]..sort();
        final ratio = (luminance.last + .05) / (luminance.first + .05);
        expect(ratio, greaterThanOrEqualTo(4.5));
      }
    });
  }
}
