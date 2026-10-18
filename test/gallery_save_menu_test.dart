import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/image_view/view/view_widget.dart';
import 'package:eros_fe/utils/gallery_image_export.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  tearDown(Get.reset);
  for (final original in [false, true]) {
    testWidgets(
        'menu captures selected page before navigation, original=$original',
        (tester) async {
      var page = 1;
      GalleryImageSource? saved;
      bool? choice;
      await tester.pumpWidget(GetCupertinoApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: const [
          L10n.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate
        ],
        supportedLocales: L10n.delegate.supportedLocales,
        home: Builder(
            builder: (context) => CupertinoPageScaffold(
                child: CupertinoButton(
                    child: const Text('Open'),
                    onPressed: () {
                      showSaveActionSheet(context,
                          gid: '10',
                          ser: page,
                          imageUrl: 'https://current/$page',
                          origImageUrl: 'https://original/$page',
                          cacheKey: 'page-$page',
                          tempPath: 'temp-$page',
                          saveImage: (source, original) async {
                        saved = source;
                        choice = original;
                      });
                    }))),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('重采样图片'), findsNothing);
      expect(find.text('保存当前图片'), findsOneWidget);
      expect(find.text('保存原图'), findsOneWidget);
      page = 2;
      await tester.tap(find.text(original ? '保存原图' : '保存当前图片'));
      await tester.pumpAndSettle();
      expect(saved!.ser, 1);
      expect(saved!.url, 'https://current/1');
      expect(saved!.cacheKey, 'page-1');
      expect(saved!.tempPath, 'temp-1');
      expect(choice, original);
      expect(tester.takeException(), isNull);
    });
  }
  for (final mode in ['local', 'same', 'no-original']) {
    testWidgets('$mode offers only current image and cancel does not save',
        (tester) async {
      var calls = 0;
      await tester.pumpWidget(GetCupertinoApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          L10n.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate
        ],
        supportedLocales: L10n.delegate.supportedLocales,
        home: Builder(
            builder: (context) => CupertinoPageScaffold(
                child: CupertinoButton(
                    child: const Text('Open'),
                    onPressed: () {
                      showSaveActionSheet(context,
                          gid: '10',
                          ser: 1,
                          imageUrl: 'https://current/1',
                          isLocal: mode == 'local',
                          origImageUrl: mode == 'no-original'
                              ? null
                              : mode == 'same'
                                  ? 'https://current/1'
                                  : 'https://original/1',
                          saveImage: (_, __) async {
                        calls++;
                      });
                    }))),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Save original image'), findsNothing);
      expect(find.text('Save current image'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, 0);
    });
  }
}
