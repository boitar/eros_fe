import 'dart:convert';
import 'dart:io';

import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/widget/user_avatar_image.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'support/avatar_fixture.dart';

void main() {
  testWidgets('reopened preview reads the owned copy in the current container',
      (tester) async {
    final support = Global.appSupportPath;
    final dir =
        Directory.systemTemp.createTempSync('avatar-relocated-preview-');
    final owned = Directory('${dir.path}/avatars/avatar_fixture')
      ..createSync(recursive: true);
    final file = File('${owned.path}/avatar.png')
      ..writeAsBytesSync(neutralAvatarPng);
    Global.appSupportPath = dir.path;
    try {
      await tester.pumpWidget(const CupertinoApp(
        home: UserAvatarImage(
            url: '/old/Application/OLD/Library/Application Support/'
                'avatars/avatar_fixture/avatar.png'),
      ));
      final image = tester.widget<ExtendedImage>(find.byType(ExtendedImage));
      expect((image.image as ExtendedFileImageProvider).file.path, file.path);
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      expect(find.byType(FaIcon), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      Global.appSupportPath = support;
      dir.deleteSync(recursive: true);
    }
  });
  for (final dark in [false, true]) {
    testWidgets(
        'local preview and missing/empty fallback at large text, dark=$dark',
        (tester) async {
      final dir = Directory.systemTemp.createTempSync('avatar-preview-');
      final file = File('${dir.path}/avatar.png')
        ..writeAsBytesSync(neutralAvatarPng);
      try {
        await tester.pumpWidget(CupertinoApp(
          theme: CupertinoThemeData(
              brightness: dark ? Brightness.dark : Brightness.light),
          home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: Row(children: [
                UserAvatarImage(url: file.path),
                const UserAvatarImage(url: ''),
                UserAvatarImage(url: '${dir.path}/missing.png'),
              ])),
        ));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
        expect(find.byType(ExtendedImage), findsNWidgets(2));
        expect(find.byType(FaIcon), findsAtLeastNWidgets(2));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        dir.deleteSync(recursive: true);
      }
    });
  }
  test('all six localizations contain only complete avatar key sets', () {
    final english =
        jsonDecode(File('lib/l10n/intl_en.arb').readAsStringSync()) as Map;
    final keys = english.keys
        .where((key) => '$key'.startsWith('avatar_') || key == 'upload_avatar')
        .toSet();
    expect(keys.length, 12);
    for (final locale in ['en', 'ja', 'ko_KR', 'ru', 'zh_CN', 'zh_TW']) {
      final translated =
          jsonDecode(File('lib/l10n/intl_$locale.arb').readAsStringSync())
              as Map;
      for (final key in keys) {
        expect(
            translated[key],
            isA<String>()
                .having((value) => value.isNotEmpty, 'nonempty', true));
      }
    }
  });
}
