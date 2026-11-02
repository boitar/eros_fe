// analyzer is supplied by flutter_test; keep this test-only parser dependency local.
// ignore_for_file: depend_on_referenced_packages

import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:eros_fe/common/controller/avatar_controller.dart';
import 'package:eros_fe/common/controller/cache_controller.dart';
import 'package:eros_fe/common/service/dns_service.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/setting/advanced_setting_page.dart';
import 'package:eros_fe/widget/cupertino/list_tile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'support/waterfall_fixture.dart';

void main() {
  test('lib uses the shared sliver list sections', () {
    final nativeSection =
        RegExp(r'(?<![\w])CupertinoListSection\s*(?:\.insetGrouped\s*)?\(');
    final violations = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) =>
            nativeSection.hasMatch(_codeOnly(file.readAsStringSync())))
        .map((file) => file.path)
        .toList();
    expect(violations, isEmpty);
  });

  testWidgets('dark language and WebDAV groups share card geometry',
      (tester) async {
    registerWaterfallFixture();
    addTearDown(Get.reset);
    Get.put<DnsService>(_Dns());
    Get.put<AvatarController>(_Avatar());
    Get.put<CacheController>(_Cache());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(CupertinoApp(
      locale: const Locale('en'),
      supportedLocales: L10n.delegate.supportedLocales,
      localizationsDelegates: const [
        L10n.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate
      ],
      theme: const CupertinoThemeData(brightness: Brightness.dark),
      home: const CupertinoPageScaffold(
        child: CustomScrollView(slivers: [ListViewAdvancedSetting()]),
      ),
    ));
    final language = find.text(L10n.current.language);
    final webdav = find.text(L10n.current.webdav_max_connections);
    for (final title in [language, webdav]) {
      final row = find
          .ancestor(of: title, matching: find.byType(EhCupertinoListTile))
          .first;
      final rect = tester.getRect(row);
      expect(rect.left, 16);
      expect(rect.right, 386);
    }
    expect(tester.getTopLeft(language).dx, tester.getTopLeft(webdav).dx);
    final cards = tester
        .widgetList<DecoratedSliver>(find.byType(DecoratedSliver))
        .where((card) => card.decoration is ShapeDecoration);
    expect(cards, isNotEmpty);
    for (final card in cards.take(1)) {
      final decoration = card.decoration as ShapeDecoration;
      expect(decoration.color, isNot(const Color(0xFF000000)));
      expect((decoration.shape as RoundedSuperellipseBorder).borderRadius,
          BorderRadius.circular(24));
    }
    expect(find.byType(CupertinoListSection), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

// The parser scanner omits comments; mask complete string AST nodes as well.
String _codeOnly(String source) {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  final strings = _Strings();
  unit.accept(strings);
  final chars = List.filled(source.length, ' ');
  var token = unit.beginToken;
  while (!token.isEof) {
    if (!strings.ranges
        .any((range) => token.offset >= range.$1 && token.offset < range.$2)) {
      for (var i = token.offset; i < token.end; i++) {
        chars[i] = source[i];
      }
    }
    token = token.next!;
  }
  return chars.join();
}

class _Strings extends RecursiveAstVisitor<void> {
  final ranges = <(int, int)>[];
  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    ranges.add((node.offset, node.end));
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    ranges.add((node.offset, node.end));
  }
}

class _Dns extends DnsService {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Avatar extends AvatarController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Cache extends CacheController {
  @override
  // ignore: must_call_super
  void onInit() {
    change('0 B', status: RxStatus.success());
  }
}
