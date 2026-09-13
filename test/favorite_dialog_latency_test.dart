import 'dart:async';
import 'package:eros_fe/common/controller/favorite_state_store.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/favcat.dart';
import 'package:eros_fe/pages/controller/fav_controller.dart';
import 'package:eros_fe/pages/controller/favorite_sel_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'favorite_picker_test.dart' show PickerSettings, PickerTheme;

class Categories extends GetxController implements FavoriteSelectorController {
  @override
  List<Favcat> get favcatList => [
        for (var i = 0; i < 10; i++)
          Favcat(favId: '$i', favTitle: 'Category $i')
      ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DelayedNoteController extends FavController {
  final note = Completer<String?>();
  int reads = 0;
  @override
  Future<String?> loadFavoriteNote(String gid, String token) {
    reads++;
    return note.future;
  }
}

void main() {
  tearDown(() => Get.reset());
  for (final picker in [true, false]) {
    testWidgets('dialog opens before note response, picker=$picker',
        (tester) async {
      favoriteStates.setAccount('latency-$picker');
      favoriteStates.commit('42', '6', 'blue');
      final settings = PickerSettings()..isFavPicker.value = picker;
      Get.put<EhSettingService>(settings);
      Get.put<ThemeService>(PickerTheme());
      Get.put<FavoriteSelectorController>(Categories());
      await tester.pumpWidget(GetCupertinoApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          L10n.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalMaterialLocalizations.delegate
        ],
        home: const CupertinoPageScaffold(child: Text('test')),
      ));
      await tester.pumpAndSettle();
      final controller = DelayedNoteController();
      var loading = false;
      final dialog = controller.selectToSave('42', 'token', startLoading: () {
        loading = true;
      });
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(controller.note.isCompleted, false);
      expect(controller.reads, 1);
      expect(loading, false);
      if (picker) {
        final widget =
            tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));
        expect(widget.scrollController!.selectedItem, 6);
        widget.scrollController!.jumpToItem(8);
      }
      await tester.enterText(find.byType(CupertinoTextField), 'my note');
      controller.note.complete('server note');
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<CupertinoTextField>(find.byType(CupertinoTextField))
              .controller!
              .text,
          'my note');
      if (picker) {
        expect(
            tester
                .widget<CupertinoPicker>(find.byType(CupertinoPicker))
                .scrollController!
                .selectedItem,
            8);
      }
      await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Cancel'));
      await tester.pumpAndSettle();
      expect(await dialog, isNull);
    });
  }
}
