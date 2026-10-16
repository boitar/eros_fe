import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/favcat.dart';
import 'package:eros_fe/pages/controller/fav_controller.dart';
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

class _Settings extends PickerSettings {
  @override
  bool get liquidGlass => true;
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('eros/accessibility-settings'),
      (_) async => null,
    );
  });

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

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await LiquidGlassAccessibilitySettings.stopWatching();
    Get.reset();
  });

  Widget host(Widget child, {double scale = 1, bool dark = false}) =>
      GetCupertinoApp(
        locale: const Locale('zh', 'CN'),
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
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: CupertinoPageScaffold(child: child),
      );

  for (final scale in [1.0, 2.4, 3.2]) {
    glassTest('category alignment and count reflow at scale=$scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Get.put<EhSettingService>(_Settings());
      await tester.pumpWidget(host(
        Center(
          child: SizedBox(
            width: 280,
            child: DefaultTextStyle.merge(
              textAlign: TextAlign.center,
              child: FavCatAddListItem(
                onTap: () {},
                text: '收藏夹 / Favorites',
                favcat: '1',
                totNum: 1234,
              ),
            ),
          ),
        ),
        scale: scale,
      ));
      await tester.pumpAndSettle();
      final text = tester.widget<Text>(find.text('收藏夹 / Favorites'));
      expect(text.textAlign, TextAlign.start);
      expect(text.style?.fontFamily, 'CupertinoSystemText');
      expect(text.style?.fontWeight, FontWeight.w400);
      expect(text.style?.letterSpacing, 0);
      expect(text.style?.fontSize, 17);
      final label = tester.getRect(find.text('收藏夹 / Favorites'));
      final count = tester.getRect(find.text('1234'));
      if (scale == 1) {
        expect(count.left, greaterThanOrEqualTo(label.right));
      } else {
        expect(count.top, greaterThanOrEqualTo(label.bottom));
        expect(count.left, label.left);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final picker in [false, true]) {
    for (final size in [const Size(320, 600), const Size(600, 320)]) {
      for (final dark in [false, true]) {
        glassTest('favorite form picker=$picker size=$size dark=$dark',
            (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          final settings = _Settings()..isFavPicker.value = picker;
          Get.put<EhSettingService>(settings);
          Get.put<ThemeService>(PickerTheme());
          await tester
              .pumpWidget(host(const Text('Host'), scale: 3.2, dark: dark));
          await tester.pumpAndSettle();
          final controller = FavController();
          final result = controller.showFavListDialog(Get.context!, [
            const Favcat(favId: 'a', favTitle: 'All'),
            for (var i = 0; i < 10; i++)
              Favcat(
                  favId: '$i', favTitle: '收藏夹 $i / Favorite $i', totNum: 1234),
          ]);
          await tester.pumpAndSettle();
          expect(find.text('All'), findsNothing);
          expect(find.text('备注（可选）'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.byType(CupertinoTextField));
          await tester.enterText(find.byType(CupertinoTextField), '保留备注');
          if (!picker) {
            FocusManager.instance.primaryFocus?.unfocus();
            await tester.pumpAndSettle();
            final outer = find
                .ancestor(
                  of: find.byType(FavCatAddListItem).first,
                  matching: find.byType(SingleChildScrollView),
                )
                .first;
            final target = find.text('收藏夹 9 / Favorite 9');
            final delta =
                tester.getTopLeft(target).dy < tester.getRect(outer).top
                    ? -150.0
                    : 150.0;
            await tester.scrollUntilVisible(
              target.hitTestable(at: Alignment.topLeft),
              delta,
              scrollable: find
                  .descendant(of: outer, matching: find.byType(Scrollable))
                  .first,
            );
            await tester.tapAt(
              tester.getTopLeft(target) + const Offset(8, 8),
            );
          } else {
            final wheel =
                tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));
            wheel.scrollController!.jumpToItem(9);
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('确定'));
            await tester.tap(find.text('确定'));
          }
          await tester.pumpAndSettle();
          final selected = await result;
          expect(selected?.favId, '9');
          expect(selected?.note, '保留备注');
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  glassTest('sheet title is metadata and actions retain icons and callbacks',
      (tester) async {
    Get.put<EhSettingService>(_Settings());
    var added = 0;
    await tester.pumpWidget(host(Align(
      alignment: Alignment.bottomCenter,
      child: EhActionSheet(
        title: const Text('[Artist] 很长的画廊标题 / Gallery title'),
        actions: [
          EhActionSheetAction(
            onPressed: () => added++,
            icon: CupertinoIcons.heart,
            systemIcon: 'heart',
            child: const Text('添加收藏夹'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () {},
          child: const Text('取消'),
        ),
      ),
    )));
    await tester.pumpAndSettle();
    final metadata = DefaultTextStyle.of(
        tester.element(find.text('[Artist] 很长的画廊标题 / Gallery title')));
    expect(metadata.style.fontSize, 15);
    expect(metadata.style.fontWeight, FontWeight.w500);
    expect(metadata.textAlign, TextAlign.start);
    final action = DefaultTextStyle.of(tester.element(find.text('添加收藏夹')));
    expect(action.style.fontSize, 17);
    expect(action.style.fontWeight, FontWeight.w400);
    expect(action.textAlign, TextAlign.start);
    expect(find.byIcon(CupertinoIcons.heart), findsOneWidget);
    await tester.tap(find.text('添加收藏夹'));
    expect(added, 1);
    expect(tester.getSize(find.byType(CupertinoButton).first).height,
        greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    glassTest('secondary text contrast on glass, dark=$dark', (tester) async {
      Get.put<EhSettingService>(_Settings());
      (LiquidGlassAccessibilitySettings.reduceTransparency
              as ValueNotifier<bool?>)
          .value = false;
      await tester.pumpWidget(host(
        LiquidGlassPopupSurface(
          enabled: true,
          child: Builder(
              builder: (context) => Text('Secondary text',
                  style: EhPopupTextStyles.secondary(context))),
        ),
        dark: dark,
      ));
      final foreground =
          tester.widget<Text>(find.text('Secondary text')).style!.color!;
      final fill = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((widget) => widget.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((decoration) => decoration.color != null)
          .color!;
      for (final backdrop in [CupertinoColors.black, CupertinoColors.white]) {
        final background = Color.alphaBlend(fill, backdrop);
        final text = Color.alphaBlend(foreground, background);
        final values = [text.computeLuminance(), background.computeLuminance()]
          ..sort();
        expect((values.last + .05) / (values.first + .05),
            greaterThanOrEqualTo(4.5));
      }
    });
  }

  glassTest('legacy icon action retains its callback', (tester) async {
    var presses = 0;
    await tester.pumpWidget(host(Align(
      alignment: Alignment.bottomCenter,
      child: EhActionSheet(
        glassEnabled: false,
        actions: [
          EhActionSheetAction(
            onPressed: () => presses++,
            icon: CupertinoIcons.heart,
            systemIcon: 'heart',
            child: const Text('添加收藏夹'),
          ),
        ],
      ),
    )));
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.heart), findsOneWidget);
    await tester.tap(find.text('添加收藏夹'));
    expect(presses, 1);
    expect(tester.takeException(), isNull);
  });

  glassTest('a single folder does not reserve an empty list viewport',
      (tester) async {
    Get.put<EhSettingService>(_Settings()..isFavPicker.value = false);
    Get.put<ThemeService>(PickerTheme());
    await tester.pumpWidget(host(const Text('Host')));
    await tester.pumpAndSettle();
    final result = FavController().showFavListDialog(Get.context!, [
      const Favcat(favId: 'l', favTitle: '本地收藏', totNum: 28),
    ]);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(FavCatAddListItem)).height, lessThan(80));
    await tester.tap(find.text('本地收藏'));
    await tester.pumpAndSettle();
    expect((await result)?.favId, 'l');
    expect(tester.takeException(), isNull);
  });
}
