import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/favcat.dart';
import 'package:eros_fe/pages/controller/fav_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class PickerSettings extends GetxService implements EhSettingService {
  @override
  RxBool isFavPicker = true.obs;
  @override
  bool get isPureDarkTheme => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PickerTheme extends GetxService implements ThemeService {
  @override
  ThemesModeEnum get themeModel => ThemesModeEnum.lightMode;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  tearDown(() => Get.reset());
  for (final index in [0, 9]) {
    testWidgets('picker visible category $index equals submitted category', (tester) async {
      Get.put<EhSettingService>(PickerSettings());
      Get.put<ThemeService>(PickerTheme());
      await tester.pumpWidget(GetCupertinoApp(
        locale: const Locale('en'),
        localizationsDelegates: const [L10n.delegate,
          GlobalCupertinoLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
          GlobalMaterialLocalizations.delegate],
        home: const CupertinoPageScaffold(child: Text('test')),
      ));
      await tester.pumpAndSettle();
      final controller = FavController();
      final categories = [const Favcat(favId:'a', favTitle:'All'),
        for (var i = 0; i < 10; i++) Favcat(favId:'$i', favTitle:'Category $i'),
        const Favcat(favId:'l', favTitle:'Local')];
      final result = controller.showFavListDialog(tester.element(find.text('test')), categories);
      await tester.pumpAndSettle();
      final picker = tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));
      picker.scrollController!.jumpToItem(index);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CupertinoDialogAction).last);
      await tester.pumpAndSettle();
      expect((await result)?.favId, '$index');
    });
  }
}
