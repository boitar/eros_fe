import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
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

class _GlassSettings extends PickerSettings {
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
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await LiquidGlassAccessibilitySettings.stopWatching();
    Get.reset();
  });

  for (final picker in [true, false]) {
    testWidgets(
        'glass favorite selection and note remain intact, picker=$picker',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = _GlassSettings()..isFavPicker.value = picker;
      Get.put<EhSettingService>(settings);
      Get.put<ThemeService>(PickerTheme());
      await tester.pumpWidget(GetCupertinoApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          L10n.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const CupertinoPageScaffold(child: Text('Host')),
      ));
      await tester.pumpAndSettle();
      final controller = FavController();
      final result = controller.showFavListDialog(Get.context!, [
        for (var i = 0; i < 10; i++)
          Favcat(
              favId: '$i',
              favTitle: 'Category $i with a long title',
              totNum: i),
      ]);
      await tester.pumpAndSettle();
      expect(find.byType(EhAlertDialog), findsOneWidget);
      expect(find.byType(LiquidGlassPopupSurface), findsOneWidget);
      await tester.ensureVisible(find.byType(CupertinoTextField));
      await tester.enterText(
          find.byType(CupertinoTextField), 'my favorite note');
      if (picker) {
        final wheel =
            tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));
        wheel.scrollController!.jumpToItem(7);
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
      } else {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final outer = find
            .ancestor(
              of: find.byType(FavCatAddListItem).first,
              matching: find.byType(SingleChildScrollView),
            )
            .first;
        final target = find.text('Category 7 with a long title');
        final delta = tester.getTopLeft(target).dy < tester.getRect(outer).top
            ? -100.0
            : 100.0;
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
      }
      await tester.pumpAndSettle();
      final selected = await result;
      expect(selected?.favId, '7');
      expect(selected?.note, 'my favorite note');
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
