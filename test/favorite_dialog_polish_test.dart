import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/favcat.dart';
import 'package:eros_fe/pages/controller/fav_controller.dart';
import 'package:eros_fe/pages/gallery/view/favorite_form_widgets.dart';
import 'package:eros_fe/pages/gallery/view/gallery_favcat.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/glass_favorite_fixture.dart' show PickerSettings, PickerTheme;

class _GlassSettings extends PickerSettings {
  @override
  bool get liquidGlass => true;
}

Widget _host(Widget child,
        {bool dark = false, bool contrast = false, double scale = 1}) =>
    GetCupertinoApp(
      locale: const Locale('en'),
      supportedLocales: L10n.delegate.supportedLocales,
      localizationsDelegates: const [
        L10n.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
      ],
      theme: CupertinoThemeData(
        textTheme: ehTextTheme,
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          highContrast: contrast,
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: CupertinoPageScaffold(child: child),
    );

BoxDecoration _groupDecoration(WidgetTester tester, Finder group) => tester
    .widgetList<DecoratedBox>(
      find.descendant(of: group, matching: find.byType(DecoratedBox)),
    )
    .map((widget) => widget.decoration)
    .whereType<BoxDecoration>()
    .firstWhere((decoration) => decoration.color != null);

void main() {
  void glassTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

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
    debugDefaultTargetPlatformOverride = null;
    await LiquidGlassAccessibilitySettings.stopWatching();
    Get.reset();
  });

  Finder outerForm(Finder categories) => find
      .ancestor(of: categories, matching: find.byType(SingleChildScrollView))
      .first;

  void expectExpanded(WidgetTester tester, Finder categories) {
    expect(find.descendant(of: categories, matching: find.byType(Scrollable)),
        findsNothing);
    expect(
        find.descendant(
            of: categories, matching: find.byType(CupertinoScrollbar)),
        findsNothing);
    expect(
        tester
            .widgetList<FavCatAddListItem>(find.byType(FavCatAddListItem))
            .every((row) => row.grouped),
        isTrue);
  }

  glassTest('one grouped category keeps a compact inset form', (tester) async {
    Get.put<EhSettingService>(_GlassSettings()..isFavPicker.value = false);
    Get.put<ThemeService>(PickerTheme());
    await tester.pumpWidget(_host(const Text('Host')));
    await tester.pumpAndSettle();
    final result = FavController().showFavListDialog(Get.context!, [
      const Favcat(favId: 'l', favTitle: 'Local favorites', totNum: 28),
    ]);
    await tester.pumpAndSettle();
    expect(tester.widget<EhAlertDialog>(find.byType(EhAlertDialog)).insetForm,
        isTrue);
    final categories = find.byType(FavoriteCategoryList);
    expectExpanded(tester, categories);
    expect(tester.getSize(categories).height, inInclusiveRange(44, 80));
    final outer = tester.widget<SingleChildScrollView>(outerForm(categories));
    expect(outer.controller!.position.maxScrollExtent, 0);
    await tester.tap(find.text('Local favorites'));
    await tester.pumpAndSettle();
    expect((await result)?.favId, 'l');
    expect(tester.takeException(), isNull);
  });

  for (final stress in [false, true]) {
    glassTest(
        'portrait shows all eleven categories without scrolling, stress=$stress',
        (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(top: 62, bottom: 34);
      tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);
      Get.put<EhSettingService>(_GlassSettings()..isFavPicker.value = false);
      Get.put<ThemeService>(PickerTheme());
      await tester.pumpWidget(_host(const Text('Host')));
      await tester.pumpAndSettle();
      final result = FavController().showFavListDialog(Get.context!, [
        const Favcat(favId: 'a', favTitle: 'All'),
        for (var index = 0; index < 10; index++)
          Favcat(
              favId: '$index',
              favTitle: stress && index == 6
                  ? '长标题收藏夹 / Illustrations and character designs'
                  : 'Folder $index',
              totNum: stress && index == 8 ? 1234567 : 126 + index),
        const Favcat(favId: 'l', favTitle: 'Local favorites', totNum: 28),
      ]);
      await tester.pumpAndSettle();
      final categories = find.byType(FavoriteCategoryList);
      expectExpanded(tester, categories);
      expect(find.text('All'), findsNothing);
      final outerFinder = outerForm(categories);
      final outer = tester.widget<SingleChildScrollView>(outerFinder);
      final viewport = tester.getRect(outerFinder);
      expect(outer.controller!.offset, 0);
      // Built nodes alone do not prove visibility: check the full hit-target rects.
      for (final row in find.byType(FavCatAddListItem).evaluate()) {
        final rowFinder = find.byWidget(row.widget);
        final rect = tester.getRect(rowFinder);
        expect(rect.height, greaterThanOrEqualTo(44));
        expect(rect.top, greaterThanOrEqualTo(viewport.top));
        expect(rect.bottom, lessThanOrEqualTo(viewport.bottom));
        expect(rowFinder.hitTestable(), findsOneWidget);
      }
      if (!stress) {
        expect(outer.controller!.position.maxScrollExtent, 0);
        expect(find.byType(CupertinoTextField).hitTestable(), findsOneWidget);
      }
      await tester.tap(find.text('Folder 9'));
      await tester.pumpAndSettle();
      expect((await result)?.favId, '9');
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(320, 600), const Size(600, 320)]) {
    glassTest('small or large-type form scrolls as one surface, size=$size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Get.put<EhSettingService>(_GlassSettings()..isFavPicker.value = false);
      Get.put<ThemeService>(PickerTheme());
      await tester.pumpWidget(
          _host(const Text('Host'), scale: size.height > size.width ? 2 : 1));
      await tester.pumpAndSettle();
      final result = FavController().showFavListDialog(Get.context!, [
        for (var index = 0; index < 10; index++)
          Favcat(favId: '$index', favTitle: 'Folder $index', totNum: index),
      ]);
      await tester.pumpAndSettle();
      final categories = find.byType(FavoriteCategoryList);
      expectExpanded(tester, categories);
      final outer = outerForm(categories);
      final outerView = tester.widget<SingleChildScrollView>(outer);
      final outerThumb = tester.widget<CupertinoScrollbar>(find
          .ancestor(of: categories, matching: find.byType(CupertinoScrollbar))
          .first);
      expect(outerView.controller, same(outerThumb.controller));
      expect(outerThumb.thumbVisibility, isTrue);
      expect(outerView.controller!.position.maxScrollExtent, greaterThan(0));
      final outerScrollable =
          find.descendant(of: outer, matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(
          find.byType(CupertinoTextField).hitTestable(), 120,
          scrollable: outerScrollable);
      await tester.enterText(find.byType(CupertinoTextField), 'Unified note');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final lastFolder = find.text('Folder 9');
      final delta = tester.getTopLeft(lastFolder).dy < tester.getRect(outer).top
          ? -120.0
          : 120.0;
      await tester.scrollUntilVisible(
          lastFolder.hitTestable(at: Alignment.topLeft), delta,
          scrollable: outerScrollable);
      await tester.tapAt(tester.getTopLeft(lastFolder) + const Offset(8, 8));
      await tester.pumpAndSettle();
      final selected = await result;
      expect(selected?.favId, '9');
      expect(selected?.note, 'Unified note');
      expect(tester.takeException(), isNull);
    });
  }

  for (final safeArea in [false, true]) {
    glassTest('keyboard preserves expanded group and note, safeArea=$safeArea',
        (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      if (safeArea) {
        tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 20);
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewInsets);
      Get.put<EhSettingService>(_GlassSettings()..isFavPicker.value = false);
      Get.put<ThemeService>(PickerTheme());
      await tester.pumpWidget(_host(const Text('Host')));
      await tester.pumpAndSettle();
      final result = FavController().showFavListDialog(Get.context!, [
        for (var index = 0; index < 10; index++)
          Favcat(favId: '$index', favTitle: 'Folder $index', totNum: index),
      ]);
      await tester.pumpAndSettle();
      final categories = find.byType(FavoriteCategoryList);
      final initialHeight = tester.getSize(categories).height;
      final outerFinder = outerForm(categories);
      final initialController =
          tester.widget<SingleChildScrollView>(outerFinder).controller!;
      final initialExtent = initialController.position.maxScrollExtent;
      await tester.ensureVisible(find.byType(CupertinoTextField));
      await tester.enterText(find.byType(CupertinoTextField), 'Keyboard note');
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      if (safeArea) {
        tester.view.padding = const FakeViewPadding(top: 24);
      }
      await tester.pumpAndSettle();
      expectExpanded(tester, categories);
      expect(tester.getSize(categories).height, initialHeight);
      expect(tester.widget<SingleChildScrollView>(outerFinder).controller,
          same(initialController));
      expect(initialController.position.maxScrollExtent,
          greaterThan(initialExtent));
      await tester.ensureVisible(find.byType(CupertinoTextField));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoTextField).hitTestable(), findsOneWidget);
      expect(
          tester
              .widget<CupertinoTextField>(find.byType(CupertinoTextField))
              .controller!
              .text,
          'Keyboard note');
      expect(tester.takeException(), isNull);
      FocusManager.instance.primaryFocus?.unfocus();
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expectExpanded(tester, categories);
      Get.back();
      await tester.pumpAndSettle();
      expect(await result, isNull);
    });
  }

  for (final rowHeight in [54.0, 150.0]) {
    glassTest('category group never imposes a height cap, rowHeight=$rowHeight',
        (tester) async {
      final rowCount = rowHeight == 54 ? 6 : 3;
      await tester.pumpWidget(_host(Center(
        child: SizedBox(
          width: 280,
          height: 320,
          child: SingleChildScrollView(
              child: FavoriteCategoryList(children: [
            for (var index = 0; index < rowCount; index++)
              SizedBox(height: rowHeight, child: Text('Folder $index')),
          ])),
        ),
      )));
      await tester.pumpAndSettle();
      final categories = find.byType(FavoriteCategoryList);
      expectExpanded(tester, categories);
      expect(tester.getSize(categories).height,
          rowCount * rowHeight + (rowCount - 1) * .5 + 1);
      expect(tester.getSize(categories).height, greaterThan(320));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  glassTest('note label persists while focus ring and draft update',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var draft = '';
    await tester.pumpWidget(_host(Center(
      child: SizedBox(
        width: 280,
        child: FavoriteNoteField(
          controller: controller,
          onChanged: (value) => draft = value,
        ),
      ),
    )));
    await tester.pumpAndSettle();

    final group = find.descendant(
        of: find.byType(FavoriteNoteField),
        matching: find.byType(FavoriteFormGroup));
    expect(find.text('Note (optional)'), findsOneWidget);
    expect(tester.widget<FavoriteFormGroup>(group).focusColor, isNull);
    expect((_groupDecoration(tester, group).border! as Border).top.width, .5);
    final field =
        tester.widget<CupertinoTextField>(find.byType(CupertinoTextField));
    expect(field.minLines, 1);
    expect(field.maxLines, 3);
    expect(field.maxLength, isNull);
    expect(tester.getSize(find.byType(CupertinoTextField)).height,
        greaterThanOrEqualTo(44));
    expect(field.placeholder, isNull);
    expect(
        find.descendant(
            of: find.byType(CupertinoTextField),
            matching: find.text('Note (optional)')),
        findsNothing);

    await tester.tap(find.byType(CupertinoTextField));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(CupertinoTextField), 'A note\nwith details');
    await tester.pump();
    expect(controller.text, 'A note\nwith details');
    expect(draft, controller.text);
    expect(find.text('Note (optional)'), findsOneWidget);
    expect(tester.widget<FavoriteFormGroup>(group).focusColor, isNotNull);
    final focused = _groupDecoration(tester, group);
    expect((focused.border! as Border).top.width, 1.5);
    expect((focused.border! as Border).top.color,
        tester.widget<FavoriteFormGroup>(group).focusColor);
    expect(
        tester.widgetList<Semantics>(find.byType(Semantics)).where(
            (semantics) => semantics.properties.label == 'Note (optional)'),
        hasLength(1));

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(tester.widget<FavoriteFormGroup>(group).focusColor, isNull);
    expect((_groupDecoration(tester, group).border! as Border).top.width, .5);
    expect(controller.text, 'A note\nwith details');
    expect(find.text('Note (optional)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final dark in [false, true]) {
    glassTest('note focus ring contrasts with the inset fill, dark=$dark',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(
        Center(
          child: SizedBox(
            width: 280,
            child: LiquidGlassPopupSurface(
              enabled: true,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: FavoriteNoteField(controller: controller),
              ),
            ),
          ),
        ),
        dark: dark,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CupertinoTextField));
      await tester.pumpAndSettle();

      final group = find.byType(FavoriteFormGroup);
      final decoration = _groupDecoration(tester, group);
      final ring = (decoration.border! as Border).top;
      final surfaceFill =
          _groupDecoration(tester, find.byType(LiquidGlassPopupSurface)).color!;
      expect(ring.width, 1.5);
      expect(ring.color.a, 1);
      for (final backdrop in [CupertinoColors.black, CupertinoColors.white]) {
        final outerFill = Color.alphaBlend(surfaceFill, backdrop);
        final insetFill = Color.alphaBlend(decoration.color!, outerFill);
        final luminance = [
          ring.color.computeLuminance(),
          insetFill.computeLuminance(),
        ]..sort();
        expect((luminance.last + .05) / (luminance.first + .05),
            greaterThanOrEqualTo(3));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    for (final accessibility in [
      'regular',
      'reduce transparency',
      'contrast'
    ]) {
      glassTest('inset groups add no blur, $accessibility dark=$dark',
          (tester) async {
        (LiquidGlassAccessibilitySettings.reduceTransparency
                as ValueNotifier<bool?>)
            .value = accessibility == 'reduce transparency';
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(_host(
          EhAlertDialog(
            glassEnabled: true,
            insetForm: true,
            title: const Text('Favorite form'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FavoriteCategoryList(
                  children: [SizedBox(height: 54, child: Text('Folder'))],
                ),
                const SizedBox(height: 16),
                FavoriteNoteField(controller: controller),
              ],
            ),
          ),
          dark: dark,
          contrast: accessibility == 'contrast',
        ));
        await tester.pumpAndSettle();
        final groups = find.byType(FavoriteFormGroup);
        expect(groups, findsNWidgets(2));
        expect(
            find.descendant(of: groups, matching: find.byType(BackdropFilter)),
            findsNothing);
        expect(find.byType(BackdropFilter),
            accessibility == 'regular' ? findsOneWidget : findsNothing);
        for (final element in groups.evaluate()) {
          final fill =
              _groupDecoration(tester, find.byWidget(element.widget)).color!;
          expect(fill.a, accessibility == 'regular' ? lessThan(1) : 1);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  glassTest('inset form opt-in leaves standard alert and sheet roles intact',
      (tester) async {
    expect(const EhAlertDialog().insetForm, isFalse);
    await tester.pumpWidget(_host(const EhAlertDialog(
      glassEnabled: true,
      title: Text('Standard alert'),
      content: Column(children: [Text('Unchanged body')]),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(FavoriteFormGroup), findsNothing);
    final title =
        DefaultTextStyle.of(tester.element(find.text('Standard alert')));
    expect(title.style.fontSize, 19);
    expect(title.style.fontWeight, FontWeight.w600);
    expect(title.textAlign, TextAlign.center);

    var added = 0;
    await tester.pumpWidget(_host(Align(
      alignment: Alignment.bottomCenter,
      child: EhActionSheet(
        glassEnabled: true,
        title: const Text('Existing gallery metadata'),
        actions: [
          EhActionSheetAction(
            onPressed: () => added++,
            icon: CupertinoIcons.heart,
            systemIcon: 'heart',
            child: const Text('Add to favorites'),
          ),
        ],
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(FavoriteFormGroup), findsNothing);
    final metadata = DefaultTextStyle.of(
        tester.element(find.text('Existing gallery metadata')));
    expect(metadata.style.fontSize, 15);
    expect(metadata.style.fontWeight, FontWeight.w500);
    expect(metadata.textAlign, TextAlign.start);
    final action =
        DefaultTextStyle.of(tester.element(find.text('Add to favorites')));
    expect(action.style.fontSize, 17);
    expect(action.style.fontWeight, FontWeight.w400);
    expect(action.textAlign, TextAlign.start);
    expect(find.byIcon(CupertinoIcons.heart), findsOneWidget);
    await tester.tap(find.text('Add to favorites'));
    expect(added, 1);
    expect(tester.takeException(), isNull);
  });
}
