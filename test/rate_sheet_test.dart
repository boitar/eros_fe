import 'package:eros_fe/adaptive/native_sheet.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/gallery/view/rate_dialog.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Settings extends GetxService implements EhSettingService {
  @override
  bool get liquidGlass => false;
  @override
  final RxBool vibrate = false.obs;
  @override
  bool get isPureDarkTheme => false;
  @override
  RxBool get pureDarkThemeObs => false.obs;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected setting $invocation');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
    Global.profile = kDefProfile;
    Get.put<EhSettingService>(_Settings());
    Get.put(ThemeService());
    NativeSheet.debugAvailable = false;
  });

  tearDown(() {
    NativeSheet.debugAvailable = null;
    Get.reset();
  });

  for (final dark in [false, true]) {
    testWidgets('rating submits only a changed half-star value, dark=$dark', (
      tester,
    ) async {
      double? selected;
      var returned = false;
      await tester.pumpWidget(
        GetCupertinoApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: L10n.delegate.supportedLocales,
          localizationsDelegates: const [
            L10n.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          theme: CupertinoThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
          home: CupertinoPageScaffold(
            child: Builder(
              builder: (context) {
                return CupertinoButton(
                  onPressed: () async {
                    selected = await presentRateSheet(context, initial: 3.5);
                    returned = true;
                  },
                  child: const Text('open'),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final submit = find.byWidgetPredicate(
        (widget) => widget is EhButton && widget.label == '提交评分',
      );
      expect(tester.widget<EhButton>(submit).onPressed, isNull);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(returned, isFalse);

      final stars = tester.widget<RatingBar>(find.byType(RatingBar));
      stars.onRatingUpdate(4.0);
      await tester.pumpAndSettle();
      expect(tester.widget<EhButton>(submit).onPressed, isNotNull);

      stars.onRatingUpdate(3.5);
      await tester.pumpAndSettle();
      expect(tester.widget<EhButton>(submit).onPressed, isNull);

      stars.onRatingUpdate(4.5);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(returned, isTrue);
      expect(selected, 4.5);
    });
  }
}
